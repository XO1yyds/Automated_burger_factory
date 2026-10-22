$ErrorActionPreference='Stop'
$projectRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $projectRoot 'preview-save-bridge.ps1')
$fixture=Join-Path $projectRoot '.tmp/v07-audio-bridge-check'
$native=Join-Path $fixture 'native';$backup=Join-Path $fixture 'backup'
$null=New-Item -ItemType Directory -Force -Path $native,$backup
$name='burger-ui-v03.json';$np=Join-Path $native $name;$bp=Join-Path $backup $name
$results=@()
function Check-AudioBridge([string]$Name,[bool]$Condition) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $script:results+=@{name=$Name;passed=$true}
}
$legacy='{"display":"both","joystick":"fixed","uiScale":1,"sensitivity":1,"tutorials":{}}'
[IO.File]::WriteAllText($np,$legacy)
Check-AudioBridge 'Legacy UI preferences remain valid' ($null -ne (Read-BurgerPreferences $np))
$updated='{"display":"both","joystick":"fixed","uiScale":1,"sensitivity":1,"tutorials":{},"masterVolume":0.4,"musicVolume":0.2,"effectsVolume":0.7,"muted":true}'
[IO.File]::WriteAllText($np,$updated)
# Boundary checks are exactly those used by the watcher before preferences sync.
Sync-BurgerSlots $native $backup
Sync-BurgerPreferences $native $backup
Check-AudioBridge 'Changed audio preferences backed up as exact bytes' ([Convert]::ToBase64String([IO.File]::ReadAllBytes($np)) -eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($bp)))
Remove-Item -LiteralPath $np
Sync-BurgerSlots $native $backup -Restore
Sync-BurgerPreferences $native $backup -Restore
Check-AudioBridge 'Fresh preview restores audio preferences' ([IO.File]::ReadAllText($np) -eq $updated)
[IO.File]::WriteAllText($np,$updated.Replace('0.4','99'))
Sync-BurgerPreferences $native $backup
Check-AudioBridge 'Invalid native audio settings cannot replace backup' ([IO.File]::ReadAllText($bp) -eq $updated)
[IO.File]::WriteAllText($np,$updated);[IO.File]::WriteAllText($bp,'{"future":"unknown"}')
$protected=$false
try { Sync-BurgerPreferences $native $backup } catch { $protected=$true }
Check-AudioBridge 'Unrecognized backup preserved' ($protected -and [IO.File]::ReadAllText($bp) -eq '{"future":"unknown"}')
[IO.File]::WriteAllText($bp,$updated)
$tokens=$null;$parseErrors=$null
$null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $projectRoot 'preview-save-bridge.ps1'),[ref]$tokens,[ref]$parseErrors)
Check-AudioBridge 'PowerShell helper parses' ($parseErrors.Count -eq 0)
$report=@{passed=$results.Count;failed=0;checks=$results;scope='Host fixture preference backup/restore and preservation, not Android IO'}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $projectRoot 'docs/v07-audio-bridge-evidence.json') -Encoding utf8
$report | Select-Object passed,failed,scope | ConvertTo-Json -Compress
