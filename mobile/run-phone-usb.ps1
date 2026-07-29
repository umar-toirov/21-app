# Run the real Android app on a USB-connected phone.
# Requires: USB debugging enabled, backend on port 8001.
$ErrorActionPreference = "Stop"

$env:Path = "C:\src\flutter\bin;" + $env:Path
$env:FLUTTER_ROOT = "C:\src\flutter"
Set-Location $PSScriptRoot

$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    Write-Host "ADB not found. Install Android Studio and platform-tools." -ForegroundColor Red
    exit 1
}

Write-Host "Checking for USB phone..." -ForegroundColor Cyan
$lines = & $adb devices
$phone = $lines | Where-Object { $_ -match "`tdevice$" }
if (-not $phone) {
    Write-Host ""
    Write-Host "No phone detected. On your Galaxy S22:" -ForegroundColor Yellow
    Write-Host "  1. Settings -> About phone -> tap Build number 7 times"
    Write-Host "  2. Settings -> Developer options -> USB debugging ON"
    Write-Host "  3. Connect USB cable (use a data cable, not charge-only)"
    Write-Host "  4. On phone tap Allow when asked for USB debugging"
    Write-Host "  5. Run this script again"
    Write-Host ""
    & $adb devices
    exit 1
}

Write-Host "Phone found: $phone" -ForegroundColor Green
Write-Host "Forwarding phone localhost:8001 -> PC backend..." -ForegroundColor Cyan
& $adb reverse tcp:8001 tcp:8001

Write-Host "Building and installing app (first run may take several minutes)..." -ForegroundColor Cyan
flutter run -d android --dart-define-from-file=env.android.usb.json
