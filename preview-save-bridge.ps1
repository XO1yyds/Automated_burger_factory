param([switch]$Watch)

# Windows Maker 0.0.36 manifest previews discard their per-run TEMP cache,
# including native savedata. This host-side companion preserves only our two
# validated campaign slots; it does not patch Maker, change its service, or
# bypass the game's File sandbox. Android uses native storage without it.
$ErrorActionPreference = 'Stop'
$script:BurgerSlotCache = @{}

function Read-BurgerSlot {
    param([string]$Path)
    try {
        $info = Get-Item -LiteralPath $Path
        $fingerprint = "$($info.Length)/$($info.LastWriteTimeUtc.Ticks)"
        $cached = $script:BurgerSlotCache[$Path]
        if ($cached -and $cached.Fingerprint -eq $fingerprint) { return $cached.Record }
        $bytes = [IO.File]::ReadAllBytes($Path)
        $text = [Text.Encoding]::UTF8.GetString($bytes).TrimEnd([char]0)
        $record = $text | ConvertFrom-Json
        if ($record.version -ne 6 -or $record.sequence -lt 1 -or $record.payload -isnot [string]) { return $null }
        [long]$hash = 2166136261
        foreach ($b in [Text.Encoding]::UTF8.GetBytes($record.payload)) {
            $hash = (($hash -bxor [long]$b) * 16777619) -band 4294967295L
        }
        if ($record.hash -ne $hash.ToString('x8')) { return $null }
        $null = $record.payload | ConvertFrom-Json
        $result = @{ Bytes = $bytes; Sequence = [long]$record.sequence }
        $script:BurgerSlotCache[$Path] = @{ Fingerprint = $fingerprint; Record = $result }
        return $result
    } catch { return $null }
}

function Write-BurgerSlot {
    param([string]$Path, [byte[]]$Bytes)
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    $pending = $Path + '.pending'
    [IO.File]::WriteAllBytes($pending, $Bytes)
    if (-not (Read-BurgerSlot $pending)) { throw 'Slot validation failed before durable replace.' }
    Move-Item -LiteralPath $pending -Destination $Path -Force
}

function Sync-BurgerSlots {
    param([string]$NativeDirectory, [string]$BackupDirectory, [switch]$Restore)
    # Native paths are derived from this project's verified Runtime command line.
    # Refuse links instead of writing outside the selected native save directory.
    foreach ($directory in @($NativeDirectory, $BackupDirectory)) {
        $cursor = [IO.Path]::GetFullPath($directory)
        while ($cursor) {
            if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Save bridge refuses linked directories.'
            }
            $parent = [IO.Path]::GetDirectoryName($cursor)
            if ($parent -eq $cursor) { break }
            $cursor = $parent
        }
    }
    foreach ($name in @('burger-v06-a.json', 'burger-v06-b.json')) {
        $native = Join-Path $NativeDirectory $name
        $backup = Join-Path $BackupDirectory $name
        foreach ($file in @($native, $backup)) {
            if ((Test-Path -LiteralPath $file) -and ((Get-Item -LiteralPath $file -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw 'Save bridge refuses linked files.'
            }
        }
        $n = Read-BurgerSlot $native
        $b = Read-BurgerSlot $backup
        if ($Restore -and -not (Test-Path -LiteralPath $native) -and $b) {
            Write-BurgerSlot $native $b.Bytes
            $n = $b
        }
        if ($n -and (-not $b -or $n.Sequence -gt $b.Sequence)) {
            # Do not overwrite an unrecognized future/corrupt durable file.
            if (-not $b -and (Test-Path -LiteralPath $backup)) { throw 'Durable slot is unrecognized; preserving it.' }
            Write-BurgerSlot $backup $n.Bytes
        }
    }
}

if ($Watch) {
    $projectDirectory = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
    $hasher = [Security.Cryptography.SHA256]::Create()
    $projectHash = ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($projectDirectory)))).Replace('-', '').ToLowerInvariant()
    $hasher.Dispose()
    $mutex = [Threading.Mutex]::new($false, ('Local\BurgerPreviewSaveBridge-' + $projectHash))
    if (-not $mutex.WaitOne(0)) { $mutex.Dispose(); exit 0 }
    $durableDirectory = Join-Path $projectDirectory '.local-saves\v06'
    $null = [IO.Directory]::CreateDirectory($durableDirectory)
    $sessionFile = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('.taptap-maker\preview\' + $projectHash + '\session.json')
    $statusFile = Join-Path $durableDirectory 'bridge-status.json'
    $currentKey = ''
    $nativeDirectory = $null
    $lastSeen = [DateTime]::UtcNow
    $lastSync = [DateTime]::MinValue
    try {
        while (([DateTime]::UtcNow - $lastSeen).TotalMinutes -lt 10) {
            try {
                $bridgeStage = 'session'
                $record = Get-Content -LiteralPath $sessionFile -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($record.project_realpath -ne $projectDirectory) { throw 'Project mismatch.' }
                $key = "$($record.session_id)/$($record.reload_id)/$($record.runtime_pid)"
                if ($key -ne $currentKey -and $record.runtime_pid -gt 0) {
                    $bridgeStage = 'process_identity'
                    $process = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$([int]$record.runtime_pid)"
                    if ($process -and $process.ExecutablePath -eq $record.executable -and $process.CommandLine -match '-game_path=("[^"]+"|\S+)') {
                        $cacheRoot = [IO.Path]::GetFullPath($Matches[1].Trim('"'))
                        $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
                        if (-not $cacheRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
                            [IO.Path]::GetFileName($cacheRoot) -notlike 'maker-cache-*') { throw 'Unexpected preview cache.' }
                        if ($process.CommandLine -notmatch '(?:^|\s)-skip_login(?:\s|$)') { throw 'Only anonymous local previews are supported.' }
                        if ($process.CommandLine -notmatch '-game_url=(http://127\.0\.0\.1:\d+/[a-f0-9]{64}/)') { throw 'Unexpected asset endpoint.' }
                        $url = [Uri]$Matches[1]
                        $nativeDirectory = Join-Path (Join-Path (Join-Path (Join-Path $cacheRoot ($url.Host + '_' + $url.Port)) $url.AbsolutePath.Trim('/')) 'savedata') '0'
                        $bridgeStage = 'restore'
                        Sync-BurgerSlots $nativeDirectory $durableDirectory -Restore
                        $currentKey = $key
                    }
                }
                if ($nativeDirectory -and (Get-Process -Id ([int]$record.runtime_pid) -ErrorAction SilentlyContinue)) {
                    $bridgeStage = 'backup'
                    Sync-BurgerSlots $nativeDirectory $durableDirectory
                    $lastSeen = [DateTime]::UtcNow
                    if (($lastSeen - $lastSync).TotalSeconds -ge 3) {
                        @{ state = 'watching'; date = $lastSeen.ToString('o'); reload = $record.reload_id; pid = $PID } |
                            ConvertTo-Json -Compress | Set-Content -LiteralPath $statusFile -Encoding UTF8
                        $lastSync = $lastSeen
                    }
                }
            } catch {
                # Do not write command lines, URLs, session tokens or save content.
                @{ state = 'waiting_or_error'; stage = $bridgeStage; kind = $_.Exception.GetType().Name; date = [DateTime]::UtcNow.ToString('o'); pid = $PID } |
                    ConvertTo-Json -Compress | Set-Content -LiteralPath $statusFile -Encoding UTF8
            }
            Start-Sleep -Milliseconds 400
        }
    } finally {
        $mutex.ReleaseMutex(); $mutex.Dispose()
    }
}
