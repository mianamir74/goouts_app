@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/screens/partner_details_screen.dart"
git add "lib/screens/message_center_screen.dart"
git add "lib/screens/login_screen.dart"
git add "lib/screens/signup_screen.dart"
git add "lib/screens/add_funds_screen.dart"
git add "lib/screens/otp_screen.dart"
git add "lib/screens/create_profile_screen.dart"
git add "lib/screens/explore_screen.dart"
git add "lib/screens/home_screen.dart"
git add "lib/screens/slide1_screen.dart"
git add "lib/screens/slide2_screen.dart"
git add "lib/screens/slide2a_screen.dart"
git add "lib/screens/slide3_screen.dart"
git add "lib/screens/transfer_screen.dart"

git commit -m "Fix: repair 14 dart files corrupted by snackbar/import scripts

- partner_details_screen.dart: added missing ), to close SizedBox in _buildVerified
- message_center_screen.dart: removed 2615 null bytes
- login_screen.dart: restored missing closing } for build() and class
- signup_screen.dart: restored missing closing } for build() and class
- add_funds_screen.dart: removed 559 null bytes
- otp_screen.dart: removed 42 null bytes
- create_profile_screen.dart: restored 45 missing lines from git
- explore_screen.dart: restored 63 missing lines from git
- home_screen.dart: restored 106 missing lines from git
- slide1/2/2a/3_screen.dart: restored 4 missing lines each from git
- transfer_screen.dart: restored 9 missing lines from git"

git push

echo.
echo === All corruption fixes pushed! ===
echo 14 files repaired - trigger new Codemagic build
echo https://codemagic.io/apps
echo.
pause
