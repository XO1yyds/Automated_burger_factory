$ErrorActionPreference = 'Stop'
$parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) 'preview-save-bridge.ps1'), [ref]$null, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
. ./preview-save-bridge.ps1
$testRoot = Join-Path (Get-Location) ('.tmp/v06-savebridge-' + [guid]::NewGuid().ToString('N'))
$native = Join-Path $testRoot 'native'
$backup = Join-Path $testRoot 'backup'
$restored = Join-Path $testRoot 'restored'
$null = New-Item -ItemType Directory -Path $native -Force
$payload = '{"root":{"ref":1},"nodes":[[]]}'
[long]$hash = 2166136261
foreach ($b in [Text.Encoding]::UTF8.GetBytes($payload)) { $hash = (($hash -bxor [long]$b) * 16777619) -band 4294967295L }
$record = @{version=6; sequence=1; payload=$payload; hash=$hash.ToString('x8')}
$bytes = [Text.Encoding]::UTF8.GetBytes(($record | ConvertTo-Json -Compress) + [char]0)
Write-BurgerSlot (Join-Path $native 'burger-v06-a.json') $bytes
if (-not (Read-BurgerSlot (Join-Path $native 'burger-v06-a.json'))) { throw 'native fixture invalid' }
Sync-BurgerSlots $native $backup
Sync-BurgerSlots $restored $backup -Restore
if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $restored 'burger-v06-a.json'))) -ne [Convert]::ToBase64String($bytes)) { throw 'restore differs' }
[IO.File]::WriteAllText((Join-Path $native 'burger-v06-b.json'), '{"version":6,"sequence":99,"payload":"broken","hash":"00000000"}')
Sync-BurgerSlots $native $backup
if (Test-Path -LiteralPath (Join-Path $backup 'burger-v06-b.json')) { throw 'corrupt data copied' }
[IO.File]::WriteAllText((Join-Path $backup 'burger-v06-b.json'), '{"version":99}')
[IO.File]::WriteAllBytes((Join-Path $native 'burger-v06-b.json'), $bytes)
$protected = $false
try { Sync-BurgerSlots $native $backup } catch { $protected = $true }
if (-not $protected -or [IO.File]::ReadAllText((Join-Path $backup 'burger-v06-b.json')) -ne '{"version":99}') { throw 'future slot overwritten' }
@{passed=5; failed=0; scope='Host bridge fixture validation, exact-byte roundtrip, corrupt slot rejection, future slot preservation, PowerShell parse'} | ConvertTo-Json | Set-Content docs/v06-savebridge-evidence.json -Encoding UTF8
Write-Output 'Save bridge checks: 5 passed'
