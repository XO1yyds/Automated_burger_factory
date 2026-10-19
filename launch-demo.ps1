param([switch]$NoPause)

$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$nodeExecutable = 'C:\Program Files\nodejs\node.exe'
$makerExecutable = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.taptap-maker\mcp-runtime\0.0.36\dist\maker.js'

function Invoke-LocalPreview {
    param([ValidateSet('status', 'start')][string]$Action)

    $outputLines = & $nodeExecutable $makerExecutable preview $Action --target-dir $projectDirectory --json
    $commandExitCode = $LASTEXITCODE
    $outputText = $outputLines -join [Environment]::NewLine
    try {
        $result = $outputText | ConvertFrom-Json
    }
    catch {
        throw "Maker 未返回可识别的启动结果。`n$outputText"
    }
    if ($commandExitCode -ne 0 -or $result.ok -eq $false) {
        throw "Maker 本地预览失败：$($result.error)`n$($result.message)"
    }
    return $result
}

try {
    foreach ($requiredPath in @($nodeExecutable, $makerExecutable, (Join-Path $projectDirectory 'scripts\main.lua'))) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            throw "启动所需文件不存在：$requiredPath"
        }
    }

    Write-Host '正在检查自动化汉堡店 Demo……'
    # Keep native campaign files across Maker's disposable Windows preview cache.
    # A named mutex makes repeated desktop launches reuse one hidden companion.
    $bridgeScript = Join-Path $projectDirectory 'preview-save-bridge.ps1'
    if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) { throw "存档启动组件缺失：$bridgeScript" }
    $bridgeHost = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $bridgeHost)) { $bridgeHost = Join-Path $PSHOME 'pwsh.exe' }
    $null = Start-Process -FilePath $bridgeHost -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $bridgeScript + '"'), '-Watch') -WindowStyle Hidden -PassThru
    $previewState = Invoke-LocalPreview -Action status
    if ($previewState.process_alive -eq $true) {
        Write-Host 'Demo 已在运行，请切换到 UrhoXRuntime 游戏窗口。' -ForegroundColor Green
    }
    elseif ($previewState.process_alive -eq $false) {
        Write-Host '正在启动本地游戏，首次准备可能需要一些时间……'
        $launchResult = Invoke-LocalPreview -Action start
        if ($launchResult.process_alive -ne $true) {
            throw "启动结果尚未确认游戏进程运行，请保留此信息，不要重复启动：`n$($launchResult | ConvertTo-Json -Depth 4)"
        }
        Write-Host 'Demo 进程已启动。' -ForegroundColor Green
    }
    else {
        throw '当前预览进程状态无法确认。为避免重复启动，请先检查 Maker 本地预览状态。'
    }
    exit 0
}
catch {
    Write-Host "`n启动未完成：$($_.Exception.Message)" -ForegroundColor Red
    if (-not $NoPause) {
        [void](Read-Host '按回车关闭窗口')
    }
    exit 1
}
