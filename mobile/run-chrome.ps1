$env:Path = "C:\src\flutter\bin;" + $env:Path
$env:FLUTTER_ROOT = "C:\src\flutter"
Set-Location $PSScriptRoot

# Real Chrome window (not web-server). Disable web security for local API CORS edge cases.
flutter run -d chrome `
  --web-browser-flag="--disable-web-security" `
  --web-browser-flag="--user-data-dir=$env:TEMP\ilm-mode-chrome" `
  --dart-define-from-file=env.json
