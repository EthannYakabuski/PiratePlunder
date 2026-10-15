param(
    [Parameter(Mandatory = $true)][string]$GodotExe,
    [string]$PythonExe = 'C:/Users/swimr/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',
    [string[]]$Families = @('phone', 'tablet7', 'tablet10'),
    [string[]]$Scenes = @('ships', 'chart', 'combat', 'boss', 'logbook')
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$captureRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot 'store/screenshots'))
$resolvedGodot = (Resolve-Path -LiteralPath $GodotExe).Path
$resolvedPython = (Resolve-Path -LiteralPath $PythonExe).Path
if (-not $captureRoot.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Capture destination must remain inside this project.'
}
$sizes = @{
    phone = @(1080, 1920)
    tablet7 = @(1200, 1920)
    tablet10 = @(1600, 2560)
}
$engineVersion = (& $resolvedGodot --version | Out-String).Trim()
$records = @()
$manifestPath = Join-Path $captureRoot 'manifest.json'
if (Test-Path -LiteralPath $manifestPath) {
    $previousManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $records = @($previousManifest.files | Where-Object { -not ($_.family -in $Families -and $_.scene -in $Scenes) })
}
foreach ($family in $Families) {
    if (-not $sizes.ContainsKey($family)) { throw "Unknown screenshot family: $family" }
    $width, $height = $sizes[$family]
    foreach ($scene in $Scenes) {
        if ($scene -notin @('ships', 'chart', 'combat', 'boss', 'logbook')) { throw "Unknown capture scene: $scene" }
        $relativeDirectory = "store/screenshots/$family/$scene"
        $destination = [IO.Path]::GetFullPath((Join-Path $projectRoot $relativeDirectory))
        if (-not $destination.StartsWith($captureRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Capture directory escaped the intended screenshots directory.'
        }
        New-Item -ItemType Directory -Force -Path $destination | Out-Null
        $png = Join-Path $destination 'capture.png'
        $stdoutLog = Join-Path $destination 'render.log'
        $stderrLog = Join-Path $destination 'render-error.log'
        $runtimeLog = Join-Path $destination 'godot-runtime.log'
        $arguments = @('--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $runtimeLog + '"'), '--resolution', '540x800', '--position', '40,40', '--rendering-method', 'gl_compatibility', '--fixed-fps', '60', '--script', 'res://tools/capture_viewport.gd', '--', "--capture=$scene", "--capture-dir=res://$relativeDirectory", "--capture-size=${width}x${height}")
        $started = [DateTime]::UtcNow
        Write-Output "Rendering $family/$scene at ${width}x${height}"
        $process = Start-Process -FilePath $resolvedGodot -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
        if (-not $process.WaitForExit(45000)) {
            Stop-Process -Id $process.Id
            throw "Godot did not finish capture: $family/$scene"
        }
        $process.Refresh()
        if ($process.ExitCode -ne 0) { throw "Godot exited with $($process.ExitCode): $family/$scene. Read render-error.log." }
        if (-not (Test-Path -LiteralPath $png)) { throw "Godot produced no image: $family/$scene" }
        if ((Get-Item -LiteralPath $png).LastWriteTimeUtc -lt $started) { throw "Capture was not refreshed: $family/$scene" }
        $errors = Get-Content -LiteralPath $stderrLog -Raw
        if ($errors -match 'SCRIPT ERROR|Parse Error|Failed loading resource') { throw "Godot reported a resource/script error: $family/$scene" }
        # Strip an all-opaque alpha channel only. No resize, recolor, composition,
        # or added captions: pixels remain genuine output from the game viewport.
        & $resolvedPython -c 'import sys; from PIL import Image; p=sys.argv[1]; im=Image.open(p); w,h=map(int,sys.argv[2:4]); assert im.size==(w,h),(im.size,(w,h)); assert "A" not in im.getbands() or im.getchannel("A").getextrema()==(255,255),"unexpected transparency"; im.convert("RGB").save(p,optimize=True)' $png $width $height
        if ($LASTEXITCODE -ne 0) { throw "PNG verification failed for $family/$scene" }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $png).Hash.ToLowerInvariant()
        $records += [ordered]@{
            family = $family
            scene = $scene
            file = "$relativeDirectory/capture.png"
            width = $width
            height = $height
            mode = 'RGB'
            bytes = (Get-Item -LiteralPath $png).Length
            sha256 = $hash
            capture_source = 'Godot desktop SubViewport render at requested native resolution'
            physical_android_device = $false
            resized = $false
            composite = $false
            alpha_removal_only = $true
            captured_utc = [DateTime]::UtcNow.ToString('o')
        }
    }
}
$manifest = [ordered]@{
    engine = $engineVersion
    capture_tool = 'tools/capture_screenshots.ps1 and tools/capture_viewport.gd'
    description = 'Actual application renders at phone and tablet portrait viewports. Desktop captures are not evidence of Android hardware or cloud integration testing.'
    scene_note = 'Ships/chart/logbook use the current local profile. Combat/boss capture modes stage pickups and encountered enemies, automate 75 physics frames, then freeze genuine game output without claiming live hardware play or fabricated scores.'
    files = $records
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output "Verified $($records.Count) actual game screenshots. Manifest: store/screenshots/manifest.json"
