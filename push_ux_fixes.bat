@echo off
echo === Pushing UX fixes + iOS icon fix ===
cd /d C:\Users\Maz\goouts\goouts_app
del /f .git\index.lock 2>nul
del /f .git\index_backup 2>nul

git add lib/screens/explore_screen.dart
git add lib/screens/create_profile_screen.dart
git add lib/screens/create_profile_expanded_screen.dart
git add lib/screens/home_screen.dart
git add lib/screens/food_address_picker_screen.dart
git add lib/services/address_lookup_service.dart
git add assets/images/icon_source.png
git add ios/Runner/Assets.xcassets/AppIcon.appiconset/
git add ios/Runner/Info.plist

git commit -m "Fix: KYC doc upload, T&C link+gate, postcode interpolation, food address bug, restaurant label, manual address link, iOS app icon"

git push
echo === Done! Now trigger Codemagic build ===
pause
