<#
.SYNOPSIS
    Builds the signed release AAB (and a matching release APK for device QA).

.DESCRIPTION
    Injects the local release keystore path and its placeholder password into a
    temporary copy of export_presets.cfg, exports build/the-tree.aab with the
    "Android Release" preset, then exports build/the-tree-release.apk with the
    same release signature for LDPlayer installation. The committed preset is
    restored afterwards, so no keystore path or password ever reaches git.

    The password lives only in tools/keystore/README.md (placeholder) or in the
    THE_TREE_KEYSTORE_PASSWORD environment variable. See docs/ANDROID.md.

.EXAMPLE
    pwsh -NoProfile -File tools/export_release.ps1

.EXAMPLE
    $env:THE_TREE_KEYSTORE_PASSWORD = '...'; pwsh -NoProfile -File tools/export_release.ps1
#>
[CmdletBinding()]
param(
    [string]$GodotBin = $env:GODOT_BIN,
    [string]$JdkHome = $(if ($env:JAVA_HOME) { $env:JAVA_HOME } else { "C:\Tools\jdk-17" }),
    [string]$AndroidSdk = $(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "C:\Android\Sdk" }),
    [string]$Preset = "Android Release",
    [string]$AabPath = "build/the-tree.aab",
    [string]$ApkPath = "build/the-tree-release.apk",
    [int]$VersionCode = 8,
    [string]$VersionName = "1.0.0",
    [switch]$SkipApk
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$presetFile = Join-Path $repo 'export_presets.cfg'
$keystore = Join-Path $repo 'tools/keystore/release.keystore'
$readme = Join-Path $repo 'tools/keystore/README.md'
$aab = Join-Path $repo $AabPath
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

$env:JAVA_HOME = $JdkHome
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:PATH = "$JdkHome\bin;$AndroidSdk\platform-tools;$AndroidSdk\cmdline-tools\latest\bin;$env:PATH"

# Password: environment first, then the documented placeholder line in README.
$password = $env:THE_TREE_KEYSTORE_PASSWORD
if (-not $password -and (Test-Path $readme)) {
    $match = Select-String -Path $readme -Pattern '\*\*Password:\*\*\s*`([^`]+)`'
    if ($match) { $password = $match.Matches[0].Groups[1].Value }
}
if (-not $password) {
    Write-Host "[export] release keystore password not found (README or THE_TREE_KEYSTORE_PASSWORD)" -ForegroundColor Red
    exit 3
}

if (-not (Test-Path $keystore)) {
    Write-Host "[export] generating release keystore at $keystore" -ForegroundColor Yellow
    New-Item -ItemType Directory -Force (Split-Path -Parent $keystore) | Out-Null
    & "$JdkHome\bin\keytool.exe" -genkeypair -v -keystore $keystore `
        -storepass $password -keypass $password -alias thetree `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -dname "CN=The Tree, OU=Games, O=Entertainment, L=Kyiv, C=UA" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[export] keytool failed with exit code $LASTEXITCODE" -ForegroundColor Red
        exit 3
    }
}

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
    Set-Content -Path (Join-Path $androidDir '.build_version') -Value '4.7.2.stable' -NoNewline
    Set-Content -Path (Join-Path $androidDir '.gdignore') -Value '' -NoNewline
}

$originalPreset = Get-Content $presetFile -Raw
$keystoreValue = $keystore.Replace('\', '/')
New-Item -ItemType Directory -Force (Split-Path -Parent $aab) | Out-Null
if (Test-Path $aab) { Remove-Item $aab -Force }
if (-not $SkipApk -and (Test-Path $apk)) { Remove-Item $apk -Force }

function Set-ReleasePreset([string]$text, [int]$format) {
    $patched = $text
    $patched = $patched -replace 'keystore/release="[^"]*"', "keystore/release=`"$keystoreValue`""
    $patched = $patched -replace 'keystore/release_user="[^"]*"', 'keystore/release_user="thetree"'
    $patched = $patched -replace 'keystore/release_password="[^"]*"', "keystore/release_password=`"$password`""
    $patched = $patched -replace 'version/code=\d+', "version/code=$VersionCode"
    $patched = $patched -replace 'version/name="[^"]*"', "version/name=`"$VersionName`""
    $patched = $patched -replace 'gradle_build/export_format=\d+', "gradle_build/export_format=$format"
    return $patched
}

Write-Host "[export] godot:  $GodotBin" -ForegroundColor DarkGray
Write-Host "[export] java:   $JdkHome" -ForegroundColor DarkGray
Write-Host "[export] sdk:    $AndroidSdk" -ForegroundColor DarkGray
Write-Host "[export] release keystore: $keystore" -ForegroundColor DarkGray

$code = 0
try {
    Set-Content -Path $presetFile -Value (Set-ReleasePreset $originalPreset 1) -NoNewline -Encoding UTF8
    Write-Host "[export] AAB: $Preset -> $AabPath" -ForegroundColor Cyan
    & $GodotBin --headless --path $repo --export-release $Preset $aab 2>&1 | ForEach-Object {
        if ($_ -match 'ERROR|error|Export|export|Gradle|gradle|BUILD|fail') { Write-Host $_ }
    }
    $code = $LASTEXITCODE

    if ($code -eq 0 -and -not $SkipApk) {
        Set-Content -Path $presetFile -Value (Set-ReleasePreset $originalPreset 0) -NoNewline -Encoding UTF8
        Write-Host "[export] APK: $Preset -> $ApkPath" -ForegroundColor Cyan
        & $GodotBin --headless --path $repo --export-release $Preset $apk 2>&1 | ForEach-Object {
            if ($_ -match 'ERROR|error|Export|export|Gradle|gradle|BUILD|fail') { Write-Host $_ }
        }
        $code = $LASTEXITCODE
    }
} finally {
    Set-Content -Path $presetFile -Value $originalPreset -NoNewline -Encoding UTF8
}

if ($code -ne 0) {
    Write-Host "[export] Godot export failed with exit code $code" -ForegroundColor Red
    exit 5
}
foreach ($artifact in @($aab, $apk)) {
    if ($SkipApk -and $artifact -eq $apk) { continue }
    if (-not (Test-Path $artifact) -or (Get-Item $artifact).Length -le 0) {
        Write-Host "[export] missing or empty artifact: $artifact" -ForegroundColor Red
        exit 6
    }
    Write-Host ("[export] OK - {0} ({1:N1} MB)" -f $artifact, ((Get-Item $artifact).Length / 1MB)) -ForegroundColor Green
}
exit 0
