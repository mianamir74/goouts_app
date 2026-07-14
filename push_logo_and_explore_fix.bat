@echo off
cd /d "%~dp0"
echo Working in: %CD%

del /F /Q ".git\index.lock" 2>NUL

git config user.email "mianamir74@gmail.com"
git config user.name "Maz"

git add "assets/images/icon_source.png"
git add "assets/images/goouts_logo.png"
git add "assets/images/logo.png"
git add "assets/images/dark/logo.png"
git add "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
git add "android/app/src/main/res/"
git add "lib/screens/explore_screen.dart"

git commit -m "Update logo thick lines + fix explore screen partner images (bannerUrl->imageUrl)"

git push

echo.
echo === Logo + explore fix pushed! ===
echo Trigger new Codemagic build at https://codemagic.io/apps
echo.
pause
