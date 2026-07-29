# Helps set DATABASE_URL for Supabase Postgres (does not print the password).
# Run from anywhere:
#   powershell -File mobile/../backend/tools/set_supabase_db_url.ps1
# Or:
#   cd backend; .\tools\set_supabase_db_url.ps1

$ErrorActionPreference = "Stop"
$backendRoot = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $backendRoot ".env"

Write-Host ""
Write-Host "Opening Supabase Database settings..." -ForegroundColor Cyan
Start-Process "https://supabase.com/dashboard/project/jnwylgvmvwcbidouxpez/settings/database"

Write-Host ""
Write-Host "In the browser:" -ForegroundColor Yellow
Write-Host "  1. Scroll to 'Connection string'"
Write-Host "  2. Type: URI"
Write-Host "  3. Method: Session pooler (recommended)"
Write-Host "  4. Click Copy"
Write-Host "  5. Replace [YOUR-PASSWORD] with your database password"
Write-Host "     (If unknown: same page -> Reset database password)"
Write-Host ""
Write-Host "Paste the full URI below (it will be saved only to backend/.env)." -ForegroundColor Cyan
$uri = Read-Host "DATABASE URI"

if ([string]::IsNullOrWhiteSpace($uri)) {
    Write-Host "No URI pasted. Cancelled." -ForegroundColor Red
    exit 1
}

$uri = $uri.Trim().Trim('"').Trim("'")
if ($uri -notmatch "^postgres(ql)?(\+asyncpg)?://") {
    Write-Host "That does not look like a postgres URI. Cancelled." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $envFile)) {
    Write-Host "Missing $envFile" -ForegroundColor Red
    exit 1
}

$lines = Get-Content $envFile
$found = $false
$newLines = foreach ($line in $lines) {
    if ($line -match '^\s*DATABASE_URL\s*=') {
        $found = $true
        "DATABASE_URL=$uri"
    } else {
        $line
    }
}
if (-not $found) {
    $newLines = @($newLines) + @("DATABASE_URL=$uri")
}

Set-Content -Path $envFile -Value $newLines -Encoding UTF8
Write-Host "Saved DATABASE_URL to backend/.env" -ForegroundColor Green
Write-Host "Testing connection..." -ForegroundColor Cyan
Set-Location $backendRoot
python -m tools.test_db
