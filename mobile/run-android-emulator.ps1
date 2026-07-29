# Start Pixel emulator + install Flutter app (API via 10.0.2.2 → PC backend :8001)
$ErrorActionPreference = "Stop"
$env:Path = "C:\src\flutter\bin;" + $env:Path
$env:FLUTTER_ROOT = "C:\src\flutter"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\sdk"
$env:Path = "$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\emulator;" + $env:Path
Set-Location $PSScriptRoot

# Ensure backend is reachable on 8001
try {
    $null = Invoke-WebRequest -Uri "http://127.0.0.1:8001/v1/health" -UseBasicParsing -TimeoutSec 3
    Write-Host "Backend OK on :8001" -ForegroundColor Green
} catch {
    Write-Host "Backend not running on :8001. Start it first:" -ForegroundColor Yellow
    Write-Host "  cd ..\backend"
    Write-Host "  python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001"
    exit 1
}

$adb = "$env:ANDROID_HOME\platform-tools\adb.exe"
$devices = & $adb devices | Where-Object { $_ -match "emulator-.*\tdevice" }
if (-not $devices) {
    Write-Host "Launching Pixel_9_Pro emulator..." -ForegroundColor Cyan
    flutter emulators --launch Pixel_9_Pro
    Write-Host "Waiting for emulator to boot..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddMinutes(4)
    do {
        Start-Sleep -Seconds 5
        $boot = & $adb shell getprop sys.boot_completed 2>$null
        $devices = & $adb devices | Where-Object { $_ -match "emulator-.*\tdevice" }
        if ((Get-Date) -gt $deadline) {
            Write-Host "Emulator boot timed out." -ForegroundColor Red
            exit 1
        }
    } while (-not $devices -or ($boot -notmatch "1"))
    Write-Host "Emulator ready." -ForegroundColor Green
} else {
    Write-Host "Emulator already running." -ForegroundColor Green
}

flutter run -d android --dart-define-from-file=env.android.json
