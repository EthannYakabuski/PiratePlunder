param([Parameter(Mandatory=$true)][string]$GodotExe, [string]$PythonExe='python', [switch]$Render)
$ErrorActionPreference='Stop'
$projectRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $projectRoot
try {
    New-Item -ItemType Directory -Force -Path 'tests/output' | Out-Null
    & $PythonExe tools/validate_data.py
    if ($LASTEXITCODE -ne 0) { throw 'Data validation failed' }
    foreach ($suite in @('progression','ads','ad_flow','game','balance','ui')) {
        & $GodotExe --headless --path . --log-file "tests/output/$suite.log" --script "tests/test_$suite.gd"
        if ($LASTEXITCODE -ne 0) { throw "$suite suite failed" }
    }
    if ($Render) {
        & $GodotExe --path . --resolution 540x960 --log-file tests/output/ui-rendered.log --script tests/test_ui.gd
        if ($LASTEXITCODE -ne 0) { throw 'Rendered UI suite failed' }
        & $GodotExe --path . --resolution 540x960 --log-file tests/output/render.log --script tests/test_render.gd
        if ($LASTEXITCODE -ne 0) { throw 'Renderer benchmark failed' }
    }
} finally { Pop-Location }
