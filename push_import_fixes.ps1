$ErrorActionPreference = "Stop"
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Working in: $appDir" -ForegroundColor Cyan
Set-Location $appDir

$lockFile = ".git\index.lock"
if (Test-Path $lockFile) {
    Remove-Item $lockFile -Force
    Write-Host "Removed git index.lock" -ForegroundColor Yellow
}

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

# The 5 files that had imports wrongly placed inside class bodies
git add "lib/screens/notification_detail_screen.dart"
git add "lib/screens/support_ticket_chat_screen.dart"
git add "lib/screens/goouts_plus_unlocked_screen.dart"
git add "lib/screens/partner_offer_screen.dart"
git add "lib/screens/food_order_tracking_screen.dart"

git commit -m "Fix: restore Flutter imports deleted by snackbar script (iOS build fix)

- notification_detail_screen.dart: restored flutter/material + flutter/services imports
- support_ticket_chat_screen.dart: restored dart:io, cloud_firestore, firebase_storage,
  flutter/material, google_fonts, image_picker imports
- goouts_plus_unlocked_screen.dart: restored flutter/material, google_fonts, confetti,
  dart:math, user_service imports
- partner_offer_screen.dart: restored flutter/material, flutter/services, google_fonts,
  user_service, transaction_service imports
- food_order_tracking_screen.dart: restored dart:async, flutter/material, cloud_firestore,
  cloud_functions, google_fonts imports
- All 5 files: removed duplicate import inserted inside class body (line 387/750/680/1175/2209)
- Each file now has exactly 1 goouts_sheet import, correctly at the top"

git push

Write-Host ""
Write-Host "=== iOS build fixes pushed! ===" -ForegroundColor Green
Write-Host "5 files fixed — Flutter imports restored, stray imports removed" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT: Trigger a new Codemagic build" -ForegroundColor Green
Write-Host "  https://codemagic.io/apps" -ForegroundColor White

Read-Host "Press Enter to close"
