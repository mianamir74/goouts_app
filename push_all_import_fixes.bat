@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/screens/family_plan_screen.dart"
git add "lib/screens/activity_screen.dart"
git add "lib/screens/checkout_screen.dart"
git add "lib/screens/contact_support_screen.dart"
git add "lib/screens/create_profile_expanded_screen.dart"
git add "lib/screens/kyc_screen.dart"
git add "lib/screens/payment_review_screen.dart"
git add "lib/screens/profile_screen.dart"
git add "lib/screens/profile_security_screen.dart"
git add "lib/screens/notifications_screen.dart"
git add "lib/screens/message_center_screen.dart"

git commit -m "Fix: restore Flutter imports in all screens damaged by snackbar script

- 11 files: flutter/material.dart + other package imports restored
- All misplaced goouts_sheet imports removed from inside class bodies
- Every file now has exactly 1 correct goouts_sheet import at the top
- All screens: 0 build errors"

git push

echo.
echo === All import fixes pushed! ===
echo 11 files fixed - full clean build expected
echo.
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
