$ErrorActionPreference = "Stop"
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Working in: $appDir" -ForegroundColor Cyan

Set-Location $appDir

# Remove git lock if present
$lockFile = ".git\index.lock"
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force
    Write-Host "Removed git index.lock" -ForegroundColor Yellow
}

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

# Stage only the iOS files changed
git add "ios/Runner/Info.plist"
git add "ios/Runner/GoogleService-Info.plist"

git commit -m "Fix iOS Phone Auth crash: add UIBackgroundModes, CLIENT_ID, REVERSED_CLIENT_ID URL scheme"
git push

Write-Host ""
Write-Host "=== All fixes pushed! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Changes made:" -ForegroundColor Cyan
Write-Host "  ios/Runner/Info.plist          - Added UIBackgroundModes + CFBundleURLTypes (REVERSED_CLIENT_ID URL scheme)"
Write-Host "  ios/Runner/GoogleService-Info.plist - Added CLIENT_ID + REVERSED_CLIENT_ID"
Write-Host ""
Write-Host "NEXT STEP: Trigger a new Codemagic build" -ForegroundColor Green
Write-Host "  https://codemagic.io/apps" -ForegroundColor White

Read-Host "Press Enter to close"
