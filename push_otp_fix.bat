@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "lib/screens/otp_screen.dart"

git commit -m "Fix OTP screen: iOS autofill + backspace navigation"

git push

echo.
echo === OTP fix pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
