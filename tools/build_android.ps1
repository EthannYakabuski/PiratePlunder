param(
    [string]$Godot = 'godot',
    [string]$TemplateDirectory = "$env:APPDATA/Godot/export_templates/4.5.1.stable",
    [string]$JavaSdk = $env:JAVA_HOME,
    [string]$AndroidSdk = $env:ANDROID_HOME,
    [ValidateSet('APK', 'AAB')][string]$Format = 'APK',
    [switch]$Release
)

$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory 'android/build'))
if (-not $buildDirectory.StartsWith($projectDirectory + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The Android build directory must remain inside the project.'
}
if (-not (Test-Path -LiteralPath (Join-Path $projectDirectory 'project.godot'))) {
    throw 'Run this helper from a complete PiratePlunder checkout.'
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

# The stock 4.5.1 template compiles against API35. The current phone publishing
# target is API36, so use the already installed API36 platform for compilation.
$gradleConfigPath = Join-Path $buildDirectory 'config.gradle'
$gradleConfig = Get-Content -LiteralPath $gradleConfigPath -Raw
$gradleConfig = [regex]::Replace($gradleConfig, '(?m)^(\s*compileSdk\s*:\s*)\d+', '${1}36')
Set-Content -LiteralPath $gradleConfigPath -Value $gradleConfig -NoNewline

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

Write-Host "Building PiratePlunder $variant $Format for Android API36."
Write-Host 'Configure Java SDK and Android SDK paths in Godot Editor Settings if export validation requires them.'
Push-Location $projectDirectory
try {
    & $Godot --headless --path $projectDirectory --log-file $logPath $mode $preset $artifactPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $artifactPath) -or (Get-Item -LiteralPath $artifactPath).LastWriteTime -lt $buildStartedAt) {
        throw "Android export failed. Inspect $logPath."
    }
    Write-Host "Created $artifactPath"
} finally {
    Pop-Location
}
