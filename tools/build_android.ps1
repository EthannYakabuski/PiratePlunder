param(
    [string]$Godot = 'godot',
    [string]$TemplateDirectory = "$env:APPDATA/Godot/export_templates/4.5.1.stable",
    [string]$JavaSdk = $env:JAVA_HOME,
    [string]$AndroidSdk = $env:ANDROID_HOME,
    [ValidateSet('APK', 'AAB')][string]$Format = 'APK',
    [switch]$Release,
    [switch]$PrepareOnly
)

$ErrorActionPreference = 'Stop'
$projectDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectSettingsPath = Join-Path $projectDirectory 'project.godot'
$buildDirectory = [IO.Path]::GetFullPath((Join-Path $projectDirectory 'android/build'))
if (-not $buildDirectory.StartsWith($projectDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The Android build directory must remain inside the project.'
}
if (-not (Test-Path -LiteralPath $projectSettingsPath)) {
    throw 'Run this helper from a complete PiratePlunder checkout.'
}
$initialProjectSettings = [IO.File]::ReadAllText($projectSettingsPath)

# Use .NET directly so Windows PowerShell installations without the optional
# Get-FileHash wrapper can still verify the vendored binaries.
function Get-ArtifactSha256([string]$path) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($path)
    try { return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $algorithm.Dispose() }
}

# This fallback repairs only plugin autoloads that an editor removed. It merges
# into the latest file and never restores a stale full project/settings snapshot.
function Restore-PluginAutoloads([string]$originalSettings) {
    $currentSettings = [IO.File]::ReadAllText($projectSettingsPath)
    $sectionPattern = '(?ms)^\[autoload\]\r?\n(.*?)(?=^\[|\z)'
    $originalSection = [regex]::Match($originalSettings, $sectionPattern)
    $currentSection = [regex]::Match($currentSettings, $sectionPattern)
    if (-not $originalSection.Success -or -not $currentSection.Success) {
        throw 'The autoload section changed during export; inspect project.godot before running the game.'
    }
    $lineEnding = if ($currentSettings.Contains("`r`n")) { "`r`n" } else { "`n" }
    $currentBody = $currentSection.Groups[1].Value
    $originalLines = @([regex]::Matches($originalSection.Groups[1].Value, '(?m)^(\w+)=[^\r\n]+'))
    foreach ($pluginName in @('GodotPlayGameServices', 'Ads')) {
        $originalEntry = $originalLines | Where-Object { $_.Groups[1].Value -eq $pluginName } | Select-Object -First 1
        if (-not $originalEntry) { continue }
        if ([regex]::IsMatch($currentBody, '(?m)^' + [regex]::Escape($pluginName) + '=')) { continue }
        $entryIndex = [Array]::IndexOf($originalLines, $originalEntry)
        $insertionPoint = -1
        for ($nextIndex = $entryIndex + 1; $nextIndex -lt $originalLines.Count; $nextIndex++) {
            $nextName = $originalLines[$nextIndex].Groups[1].Value
            $nextEntry = [regex]::Match($currentBody, '(?m)^' + [regex]::Escape($nextName) + '=')
            if ($nextEntry.Success) { $insertionPoint = $nextEntry.Index; break }
        }
        $restoredLine = $originalEntry.Value + $lineEnding
        if ($insertionPoint -ge 0) {
            $currentBody = $currentBody.Insert($insertionPoint, $restoredLine)
        } else {
            $currentBody = $currentBody.TrimEnd([char[]]"`r`n") + $lineEnding + $restoredLine + $lineEnding
        }
        Write-Warning "Restored the missing authored $pluginName autoload without replacing unrelated settings."
    }
    if ($currentBody -ne $currentSection.Groups[1].Value) {
        $body = $currentSection.Groups[1]
        $currentSettings = $currentSettings.Remove($body.Index, $body.Length).Insert($body.Index, $currentBody)
        [IO.File]::WriteAllText($projectSettingsPath, $currentSettings, [Text.UTF8Encoding]::new($false))
    }
}

if (-not [string]::IsNullOrWhiteSpace($JavaSdk)) { $env:JAVA_HOME = $JavaSdk }
if (-not [string]::IsNullOrWhiteSpace($AndroidSdk)) { $env:ANDROID_HOME = $AndroidSdk }
if ([string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
    $env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android/Sdk'
}
if (-not (Test-Path -LiteralPath (Join-Path $env:ANDROID_HOME 'platforms/android-36/android.jar'))) {
    throw 'Android SDK Platform 36 is required. Install it using Android Studio or sdkmanager.'
}

if (-not (Test-Path -LiteralPath (Join-Path $buildDirectory 'build.gradle'))) {
    $sourceTemplate = Join-Path $TemplateDirectory 'android_source.zip'
    if (-not (Test-Path -LiteralPath $sourceTemplate)) {
        throw 'Install the Godot 4.5.1 export templates, or pass -TemplateDirectory.'
    }
    New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
    Expand-Archive -LiteralPath $sourceTemplate -DestinationPath $buildDirectory -Force
    Set-Content -LiteralPath (Join-Path $buildDirectory '.gdignore') -Value '' -NoNewline
    Set-Content -LiteralPath (Join-Path $projectDirectory 'android/.build_version') -Value '4.5.1.stable' -NoNewline
}

# Stock Godot 4.5.1 compiles against API35. Compile against the installed API36
# platform to match both tracked export presets' target API.
$gradleConfigPath = Join-Path $buildDirectory 'config.gradle'
$gradleConfig = [IO.File]::ReadAllText($gradleConfigPath)
$updatedGradleConfig = [regex]::Replace($gradleConfig, '(?m)^(\s*compileSdk\s*:\s*)\d+', '${1}36')
if ($updatedGradleConfig -ne $gradleConfig) {
    [IO.File]::WriteAllText($gradleConfigPath, $updatedGradleConfig, [Text.UTF8Encoding]::new($false))
}

# Permissions are also tracked in export_presets.cfg. Recreate them when a fresh
# Android template is installed instead of relying on a local ignored manifest.
$manifestPath = Join-Path $buildDirectory 'AndroidManifest.xml'
$manifest = New-Object System.Xml.XmlDocument
$manifest.PreserveWhitespace = $true
$manifest.Load($manifestPath)
$androidNamespace = 'http://schemas.android.com/apk/res/android'
$manifestModified = $false
foreach ($permission in @('android.permission.INTERNET', 'android.permission.ACCESS_NETWORK_STATE', 'com.google.android.gms.permission.AD_ID')) {
    $present = $false
    foreach ($node in $manifest.DocumentElement.SelectNodes('uses-permission')) {
        if ($node.GetAttribute('name', $androidNamespace) -eq $permission) { $present = $true; break }
    }
    if (-not $present) {
        $node = $manifest.CreateElement('uses-permission')
        $attribute = $manifest.CreateAttribute('android', 'name', $androidNamespace)
        $attribute.Value = $permission
        [void]$node.Attributes.Append($attribute)
        [void]$manifest.DocumentElement.InsertBefore($node, $manifest.DocumentElement.SelectSingleNode('application'))
        $manifestModified = $true
    }
}
if ($manifestModified) { $manifest.Save($manifestPath) }

# AdMob's native libraries are vendored, version-pinned public dependencies.
$admobConfigPath = Join-Path $projectDirectory 'config/admob.json'
$admobConfig = [IO.File]::ReadAllText($admobConfigPath) | ConvertFrom-Json
if ($admobConfig.enabled) {
    $activeAppId = if ($admobConfig.use_test_ads) { $admobConfig.test_app_id } else { $admobConfig.production_app_id }
    if ($activeAppId -notmatch '^ca-app-pub-\d{16}~\d{10}$') { throw 'Configure a valid AdMob app ID in config/admob.json.' }
    $authoredAppId = [regex]::Match($initialProjectSettings, '(?m)^general/android/app_id="([^"]+)"')
    if (-not $authoredAppId.Success -or $authoredAppId.Groups[1].Value -ne $activeAppId) {
        throw 'The authored admob/general/android/app_id in project.godot must match the active test/production app ID in config/admob.json.'
    }
    if (-not $admobConfig.use_test_ads) {
        foreach ($unitName in @('banner_unit_id', 'interstitial_unit_id', 'rewarded_unit_id')) {
            if ($admobConfig.$unitName -notmatch '^ca-app-pub-\d{16}/\d{10}$') { throw "Configure $unitName before exporting production ads." }
        }
    }
    $nativeManifest = [IO.File]::ReadAllText((Join-Path $projectDirectory 'addons/admob/VENDOR_ANDROID.json')) | ConvertFrom-Json
    foreach ($nativeFile in $nativeManifest.files | Where-Object { $_.path -like 'ads/libs/*.aar' }) {
        $nativePath = Join-Path $projectDirectory ('addons/admob/android/bin/' + $nativeFile.path)
        if (-not (Test-Path -LiteralPath $nativePath) -or (Get-ArtifactSha256 $nativePath) -ne $nativeFile.sha256) {
            throw "The pinned AdMob native dependency is missing or modified: $($nativeFile.path)."
        }
    }
    Write-Host ('AdMob native preflight passed; test ads: ' + $admobConfig.use_test_ads)
}
if ($PrepareOnly) {
    Write-Host 'Android template, permissions, API36, and native dependency preflight complete; no export started.'
    return
}

if ($Release) {
    foreach ($credentialName in @('GODOT_ANDROID_KEYSTORE_RELEASE_PATH', 'GODOT_ANDROID_KEYSTORE_RELEASE_USER', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD')) {
        if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($credentialName))) {
            throw "Set $credentialName outside the repository before a release export."
        }
    }
} elseif ([string]::IsNullOrWhiteSpace($env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH)) {
    $debugKeyPath = Join-Path $env:USERPROFILE '.android/debug.keystore'
    if (Test-Path -LiteralPath $debugKeyPath) {
        $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $debugKeyPath
        $env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
        $env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
    }
}

$artifactDirectory = Join-Path $projectDirectory 'builds'
New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
Set-Content -LiteralPath (Join-Path $artifactDirectory '.gdignore') -Value '' -NoNewline
$variant = if ($Release) { 'release' } else { 'debug' }
$extension = $Format.ToLowerInvariant()
$artifactPath = Join-Path $artifactDirectory "PiratePlunder-$variant.$extension"
$logPath = Join-Path $artifactDirectory "android-$variant-$extension.log"
$mode = if ($Release) { '--export-release' } else { '--export-debug' }
$preset = "Android $Format"
$buildStartedAt = Get-Date
$exportExecutable = (Get-Command $Godot -ErrorAction Stop).Source
# Windows' console shim can outlive a successful export. Prefer its actual
# engine sibling so the owned process exit code is the exporter exit code.
if ($exportExecutable -match '_console\.exe$') {
    $engineExecutable = $exportExecutable -replace '_console\.exe$', '.exe'
    if (Test-Path -LiteralPath $engineExecutable) { $exportExecutable = $engineExecutable }
}
Write-Host "Building PiratePlunder $variant $Format for Android API36."
Write-Host 'Configure Java SDK and Android SDK paths in Godot Editor Settings if export validation requires them.'
Push-Location $projectDirectory
try {
    $arguments = @('--headless', '--quit', '--path', ('"' + $projectDirectory + '"'), '--log-file', ('"' + $logPath + '"'), $mode, ('"' + $preset + '"'), ('"' + $artifactPath + '"'))
    $process = Start-Process -FilePath $exportExecutable -ArgumentList $arguments -WorkingDirectory $projectDirectory -WindowStyle Hidden -PassThru
    Write-Host ('Owned Godot exporter PID: ' + $process.Id)
    $process.WaitForExit()
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $artifactPath) -or (Get-Item -LiteralPath $artifactPath).LastWriteTime -lt $buildStartedAt) {
        throw "Android export failed. Inspect $logPath."
    }
    Write-Host "Created $artifactPath"
} finally {
    Restore-PluginAutoloads $initialProjectSettings
    Pop-Location
}
