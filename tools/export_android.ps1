<#
.SYNOPSIS
    Builds the debug Android APK for The Tree: Idle Tower Defense.

.DESCRIPTION
    Sets JAVA_HOME (JDK 17), ANDROID_HOME/ANDROID_SDK_ROOT and PATH, generates the
    debug keystore when missing, injects its absolute path into export_presets.cfg
    for the duration of the export (the committed preset keeps it empty, because
    keystores are never committed), then runs:
        godot --headless --path . --export-debug "Android" build/the-tree.apk

    Exits 0 only when the APK exists and is non-empty.

.EXAMPLE
    pwsh -NoProfile -File tools/export_android.ps1

.EXAMPLE
    pwsh -NoProfile -File tools/export_android.ps1 -GodotBin "C:\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
#>
[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [string]$JdkHome = $(if ($env:JAVA_HOME) { $env:JAVA_HOME } else { "C:\Tools\jdk-17" }),
    [string]$AndroidSdk = $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "C:\Android\Sdk" }),
    [string]$Preset = "Android",
    [string]$ApkPath = "build/the-tree.apk",
    [switch]$SkipKeystore
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$presetFile = Join-Path $repo 'export_presets.cfg'
$keystore = Join-Path $repo 'tools/keystore/debug.keystore'
$apk = Join-Path $repo $ApkPath

if (-not $GodotBin) {
    $pathFile = Join-Path $PSScriptRoot 'godot_path.txt'
    if (Test-Path $pathFile) { $GodotBin = (Get-Content $pathFile -Raw).Trim() }
}
if (-not $GodotBin -or -not (Test-Path $GodotBin)) {
    Write-Host "[export] Godot binary not found. Set GODOT_BIN or edit tools/godot_path.txt" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path $JdkHome)) {
    Write-Host "[export] JDK not found at $JdkHome (set JAVA_HOME or -JdkHome)" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path $AndroidSdk)) {
    Write-Host "[export] Android SDK not found at $AndroidSdk (set ANDROID_HOME or -AndroidSdk)" -ForegroundColor Red
    exit 2
}

# Toolchain environment: JDK 17 (not the JDK 8 on PATH) and the Android SDK.
$env:JAVA_HOME = $JdkHome
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:PATH = "$JdkHome\bin;$AndroidSdk\platform-tools;$AndroidSdk\cmdline-tools\latest\bin;$env:PATH"

# Debug keystore: generated once, never committed (.gitignore covers *.keystore).
if (-not $SkipKeystore -and -not (Test-Path $keystore)) {
    Write-Host "[export] generating debug keystore at $keystore" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force (Split-Path -Parent $keystore) | Out-Null
    & "$JdkHome\bin\keytool.exe" -genkeypair -v -keystore $keystore `
        -storepass android -keypass android -alias androiddebugkey `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -dname "CN=Android Debug,O=Android,C=US" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[export] keytool failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 3
    }
}

# The Android build template is installed from the export templates on first run
# (extract android_source.zip into ./android). It is gitignored.
$androidBuild = Join-Path $repo 'android/build'
if (-not (Test-Path $androidBuild)) {
    $templates = Join-Path $env:APPDATA 'Godot/export_templates/4.7.2.stable'
    $sourceZip = Join-Path $templates 'android_source.zip'
    if (-not (Test-Path $sourceZip)) {
        Write-Host "[export] android_source.zip not found in $templates" -ForegroundColor Red
        exit 4
    }
    Write-Host "[export] installing Android build template from $sourceZip" -ForegroundColor Yellow
    $androidDir = Join-Path $repo 'android'
    New-Item -ItemType Directory -Force (Join-Path $androidDir 'build') | Out-Null
    Expand-Archive -Path $sourceZip -DestinationPath (Join-Path $androidDir 'build') -Force
    # Godot refuses a gradle-built template without the engine version marker
    # (it lives next to res://android/build, not inside it).
    Set-Content -Path (Join-Path $androidDir '.build_version') -Value '4.7.2.stable' -NoNewline
    # Keep the template out of the Godot import scan.
    Set-Content -Path (Join-Path $androidDir '.gdignore') -Value '' -NoNewline
}

# Inject the absolute debug keystore path for the export, then always restore the
# committed preset (empty keystore path) even if the export fails.
$originalPreset = Get-Content $presetFile -Raw
$keystoreValue = $keystore.Replace('\', '/')
$patchedPreset = $originalPreset -replace 'keystore/debug="[^"]*"', "keystore/debug=`"$keystoreValue`""
New-Item -ItemType Directory -Force (Split-Path -Parent $apk) | Out-Null
if (Test-Path $apk) { Remove-Item $apk -Force }

Write-Host "[export] godot:  $GodotBin" -ForegroundColor DarkGray
Write-Host "[export] java:   $JdkHome" -ForegroundColor DarkGray
Write-Host "[export] sdk:    $AndroidSdk" -ForegroundColor DarkGray
Write-Host "[export] preset: $Preset -> $ApkPath" -ForegroundColor DarkGray

try {
    Set-Content -Path $presetFile -Value $patchedPreset -NoNewline -Encoding UTF8
    & $GodotBin --headless --path $repo --export-debug $Preset $apk 2>&1 | ForEach-Object {
        # Keep the useful export lines without flooding the console.
        if ($_ -match 'ERROR|error|Export|export|Gradle|gradle|BUILD|fail') { Write-Host $_ }
    }
    $code = $LASTEXITCODE
} finally {
    Set-Content -Path $presetFile -Value $originalPreset -NoNewline -Encoding UTF8
}

if ($code -ne 0) {
    Write-Host "[export] Godot export failed with exit code $code" -ForegroundColor Red
    exit 5
}
if (-not (Test-Path $apk)) {
    Write-Host "[export] Godot reported success but $apk does not exist" -ForegroundColor Red
    exit 6
}
$size = (Get-Item $apk).Length
if ($size -le 0) {
    Write-Host "[export] APK is empty: $apk" -ForegroundColor Red
    exit 6
}
Write-Host ("[export] OK - {0} ({1:N1} MB)" -f $apk, ($size / 1MB)) -ForegroundColor Green
exit 0
