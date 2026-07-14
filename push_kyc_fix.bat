@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/screens/kyc_screen.dart"
git add "lib/screens/profile_screen.dart"

git commit -m "Fix: KYC screen blank + status always viewable from profile

- kyc_screen.dart: check Firestore kycStatus on open — show verified/
  pending/rejected screen instead of blank form for returning users
- kyc_screen.dart: added cloud_firestore import
- kyc_screen.dart: back buttons return to Profile instead of Home
- profile_screen.dart: KYC banner always tappable to view status
- profile_screen.dart: stripped null bytes, chevron always visible"

git push

echo.
echo === KYC fix pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
