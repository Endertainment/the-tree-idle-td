<#
.SYNOPSIS
    Installs and launches the debug APK on the LDPlayer emulator over adb.

.DESCRIPTION
    Connects adb to 127.0.0.1:5555 (retries while the emulator boots), installs the
    APK with `adb install -r`, and launches the Godot activity. Handles the common
    signature-mismatch case by uninstalling the old package once and retrying.
    Optionally captures a PNG screenshot after launch.

    LDPlayer must have ADB debugging enabled:
    Settings -> Other settings -> ADB debugging -> Open local connection
    (or set "basicSettings.adbDebug": 1 in
     E:\LDPlayer\LDPlayer14\vms\config\leidian0.config while the emulator is off).

.EXAMPLE
    pwsh -NoProfile -File tools/install_ldplayer.ps1

.EXAMPLE
    pwsh -NoProfile -File tools/install_ldplayer.ps1 -Screenshot docs/preview/m6_device.png
#>
[CmdletBinding()]
param(
    [string]$ApkPath = "build/the-tree.apk",
    [string]$Adb = $(if ($env:ADB) { $env:ADB } else { "E:\LDPlayer\LDPlayer14\adb.exe" }),
    [string]$Serial = $(if ($env:ADB_SERIAL) { $env:ADB_SERIAL } else { "127.0.0.1:5555" }),
    [string]$Package = "com.endertainment.thetree",
    [string]$Activity = "com.godot.game.GodotAppLauncher",
    [string]$Screenshot = "",
    [int]$ConnectRetries = 15,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $repo $ApkPath

if (-not (Test-Path $Adb)) {
    Write-Host "[ldplayer] adb not found at $Adb (set ADB or pass -Adb)" -ForegroundColor Red
    exit 2
}
if (-not (Test-Path $apk)) {
    Write-Host "[ldplayer] APK not found: $apk - run tools/export_android.ps1 first" -ForegroundColor Red
    exit 2
}

function Invoke-Adb {
    param([string[]]$Arguments)
    & $Adb -s $Serial @Arguments
}

$connected = $false
for ($i = 1; $i -le $ConnectRetries; $i++) {
    & $Adb connect $Serial | Out-Null
    $state = (& $Adb -s $Serial get-state 2>$null | Out-String).Trim()
    if ($state -eq "device") { $connected = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $connected) {
    Write-Host "[ldplayer] no device at $Serial. Start LDPlayer (dnplayer.exe) and enable ADB debugging." -ForegroundColor Red
    exit 3
}

$installOutput = (Invoke-Adb -Arguments @("install","-r",$apk) 2>&1 | Out-String)
if ($installOutput -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE") {
    Write-Host "[ldplayer] signature mismatch, uninstalling the old package once" -ForegroundColor Yellow
    Invoke-Adb -Arguments @("uninstall",$Package) | Out-Null
    $installOutput = (Invoke-Adb -Arguments @("install","-r",$apk) 2>&1 | Out-String)
}
if ($installOutput -notmatch "Success") {
    Write-Host "[ldplayer] install failed:" -ForegroundColor Red
    Write-Host $installOutput
    exit 4
}
Write-Host "[ldplayer] installed $Package" -ForegroundColor Green

if (-not $NoLaunch) {
    Invoke-Adb -Arguments @("shell","am","force-stop",$Package) | Out-Null
    Invoke-Adb -Arguments @("shell","am","start","-n","$Package/$Activity") | Out-Null
    Write-Host "[ldplayer] launched $Package/$Activity" -ForegroundColor Green
    Start-Sleep -Seconds 8
}

if ($Screenshot) {
    $target = Join-Path $repo $Screenshot
    New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
    $remote = "/sdcard/m6_screenshot.png"
    Invoke-Adb -Arguments @("shell","screencap","-p",$remote) | Out-Null
    Invoke-Adb -Arguments @("pull",$remote,$target) | Out-Null
    Invoke-Adb -Arguments @("shell","rm",$remote) | Out-Null
    Write-Host "[ldplayer] screenshot: $target" -ForegroundColor Green
}

exit 0
