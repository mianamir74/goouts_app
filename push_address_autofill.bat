@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/services/address_lookup_service.dart"
git add "lib/screens/create_profile_expanded_screen.dart"
git add "lib/screens/food_address_picker_screen.dart"

git commit -m "Upgrade address lookup: postcode dropdown + food autofill with session tokens"

git push

echo.
echo === Address autofill pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
