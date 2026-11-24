@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "assets/images/special offers/home_needs.webp"
git add "lib/data/goouts_services.dart"
git add "lib/screens/services_screen.dart"
git add "lib/screens/nearby_screen.dart"
git add "lib/screens/partner_details_screen.dart"

git commit -m "Add Home Needs category with demo stores (15%% cashback) for partner pitch"

git push

echo.
echo === Home Needs demo pushed. Codemagic will build and send to TestFlight. ===
echo Track it at https://codemagic.io/apps
echo.
pause
