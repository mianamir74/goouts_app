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

# ── Core bug fixes ──────────────────────────────────────────────────────────
git add "lib/screens/add_funds_screen.dart"
git add "lib/screens/create_profile_screen.dart"
git add "lib/screens/home_screen.dart"
git add "lib/screens/explore_screen.dart"
git add "lib/screens/partner_details_screen.dart"
git add "lib/screens/refer_friend_screen.dart"
git add "lib/screens/login_screen.dart"
git add "lib/screens/signup_screen.dart"
git add "lib/screens/notifications_screen.dart"
git add "lib/screens/message_center_screen.dart"
git add "ios/Runner/Info.plist"

# ── New widget files ─────────────────────────────────────────────────────────
git add "lib/widgets/goouts_sheet.dart"
git add "lib/widgets/goouts_loading_overlay.dart"

# ── Snackbar-replaced screens ────────────────────────────────────────────────
git add "lib/screens/activity_screen.dart"
git add "lib/screens/checkout_screen.dart"
git add "lib/screens/contact_support_screen.dart"
git add "lib/screens/create_profile_expanded_screen.dart"
git add "lib/screens/family_plan_screen.dart"
git add "lib/screens/food_order_tracking_screen.dart"
git add "lib/screens/goouts_plus_unlocked_screen.dart"
git add "lib/screens/kyc_screen.dart"
git add "lib/screens/notification_detail_screen.dart"
git add "lib/screens/partner_offer_screen.dart"
git add "lib/screens/payment_review_screen.dart"
git add "lib/screens/profile_screen.dart"
git add "lib/screens/profile_security_screen.dart"
git add "lib/screens/otp_screen.dart"
git add "lib/screens/support_ticket_chat_screen.dart"
git add "lib/screens/transfer_screen.dart"

git commit -m "UX: branded GoOuts sheet system, loading overlay, photo fixes, WhatsApp share, UI polish

- New GoOutsSheet widget: replaces all snackbars with elegant branded bottom sheets
  (success/error/info/warning types + iOS-style delete confirmation)
- New GoOutsLoadingOverlay: full-screen branded loading covers blank flash during OTP/reCAPTCHA
- Fixed iOS freeze on Add Funds: deferred second Navigator.pop via addPostFrameCallback
- Fixed registration photo not saving: now uploads to Firebase Storage on Continue
- Added photo edit button on home screen avatar (camera/gallery picker)
- Fixed Restaurants label cut off: increased service item width to 80px
- Explore categories: replaced 3-row grid with single-row PageView + animated dots
- Partner share button: now opens WhatsApp with partner info deeplink
- Refer Friend share button: now opens WhatsApp with invite code
- Delete confirmations: notifications + messages now use GoOutsSheet.confirm()
- iOS Info.plist: added whatsapp to LSApplicationQueriesSchemes"

git push

Write-Host ""
Write-Host "=== All fixes pushed! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Summary of changes:" -ForegroundColor Cyan
Write-Host "  lib/widgets/goouts_sheet.dart         NEW - Branded sheet system (replaces all snackbars)"
Write-Host "  lib/widgets/goouts_loading_overlay.dart NEW - OTP/reCAPTCHA loading screen"
Write-Host "  add_funds_screen.dart                 Fixed iOS freeze after Wallet Topped Up"
Write-Host "  create_profile_screen.dart            Photo now uploads to Firebase on Continue"
Write-Host "  home_screen.dart                      Edit button on avatar + Restaurants label fix"
Write-Host "  explore_screen.dart                   Categories: single-row scroll + page dots"
Write-Host "  partner_details_screen.dart           Share -> WhatsApp with partner link"
Write-Host "  refer_friend_screen.dart              Share -> WhatsApp with invite code"
Write-Host "  login_screen.dart                     GoOuts loading overlay during OTP send"
Write-Host "  signup_screen.dart                    GoOuts loading overlay during OTP send"
Write-Host "  notifications_screen.dart             Delete: GoOutsSheet.confirm() + all snackbars replaced"
Write-Host "  message_center_screen.dart            Delete: GoOutsSheet.confirm() + all snackbars replaced"
Write-Host "  + 16 other screens                    All snackbars replaced with GoOutsSheet"
Write-Host "  ios/Runner/Info.plist                 Added whatsapp to LSApplicationQueriesSchemes"
Write-Host ""
Write-Host "NEXT: Trigger a new Codemagic build" -ForegroundColor Green
Write-Host "  https://codemagic.io/apps" -ForegroundColor White

Read-Host "Press Enter to close"
