@echo off
cd /d "%~dp0"
echo Working in: %CD%

echo Removing git lock if present...
del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/screens/notification_detail_screen.dart"
git add "lib/screens/support_ticket_chat_screen.dart"
git add "lib/screens/goouts_plus_unlocked_screen.dart"
git add "lib/screens/partner_offer_screen.dart"
git add "lib/screens/food_order_tracking_screen.dart"

git commit -m "Fix: restore Flutter imports deleted by snackbar script (iOS build fix)"

git push

echo.
echo === iOS build fixes pushed! ===
echo 5 files fixed - Flutter imports restored
echo.
echo NEXT: Go to https://codemagic.io/apps and trigger a new build
echo.
pause
