# Creates the Google Play upload key and android/key.properties (both gitignored).
# Run once from mobile/:   .\tools\create_upload_key.ps1
# You type the password yourself; it is never printed or sent anywhere.
# BACK UP android\upload-keystore.jks and the password (password manager). If you lose
# the upload key you must ask Google to reset it.

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) { $keytool = "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" }
$dir = Join-Path $PSScriptRoot "..\android"
$jks = Join-Path $dir "upload-keystore.jks"
if (Test-Path $jks) { Write-Host "upload-keystore.jks already exists - not overwriting."; exit 1 }

$secure = Read-Host "Choose a keystore password (min 6 chars)" -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

& $keytool -genkeypair -v -keystore $jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload -storepass $plain -keypass $plain -dname "CN=Habit Zone, O=ILM HUB, C=UZ"

@"
storeFile=upload-keystore.jks
storePassword=$plain
keyAlias=upload
keyPassword=$plain
"@ | Set-Content -Encoding ascii (Join-Path $dir "key.properties")

Write-Host "Done. Now back up android\upload-keystore.jks and your password."
Write-Host "For GitHub Actions: base64 of the .jks ->  [Convert]::ToBase64String([IO.File]::ReadAllBytes('$jks'))"
