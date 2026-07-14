@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/screens/notifications_screen.dart"
git add "lib/screens/refer_friend_screen.dart"
git add "lib/screens/partner_details_screen.dart"
git add "pubspec.yaml"

git commit -m "Fix: restore truncated file tails + missing goouts_sheet imports + intl dep

- notifications_screen.dart: restored missing closing brackets
- refer_friend_screen.dart: added goouts_sheet import + restored 13 missing lines
- partner_details_screen.dart: added goouts_sheet import + restored _socialChip method (54 lines)
- pubspec.yaml: added intl: ^0.19.0 (used by food_order_tracking_screen)"

git push

echo.
echo === Final fixes pushed! ===
echo 3 dart files + pubspec.yaml fixed
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
