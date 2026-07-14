@echo off
echo === Regenerating app icons from icon_source.png ===
cd /d C:\Users\Maz\goouts_app
dart run flutter_launcher_icons
if %ERRORLEVEL% NEQ 0 (
  echo Icon generation FAILED - check errors above
  pause
  exit /b 1
)
echo === Pushing icon fix to git ===
git add pubspec.yaml
git add ios/Runner/Assets.xcassets/AppIcon.appiconset/
git add android/app/src/main/res/
git commit -m "Fix app icon: use icon_source.png, was pointing to missing virtual_card_ios.png"
git push
echo === Done! Run Codemagic build to see new icon ===
pause
