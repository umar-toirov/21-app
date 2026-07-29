# Phone-sized Chrome window for side-by-side coding (Cursor left, app right).
$env:Path = "C:\src\flutter\bin;" + $env:Path
$env:FLUTTER_ROOT = "C:\src\flutter"
Set-Location $PSScriptRoot

flutter run -d chrome `
  --dart-define-from-file=env.json `
  --web-browser-flag "--window-size=420,900" `
  --web-browser-flag "--window-position=1280,40" `
  --web-browser-flag "--app=http://localhost"
