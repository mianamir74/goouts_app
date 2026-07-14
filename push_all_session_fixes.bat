@echo off
echo === Pushing all session fixes to GitHub ===
cd /d C:\Users\Maz\goouts_app

REM -- Dart/screen changes --
git add lib/screens/create_profile_screen.dart
git add lib/screens/create_profile_expanded_screen.dart
git add lib/screens/explore_screen.dart
git add lib/screens/home_screen.dart
git add lib/screens/profile_screen.dart
git add lib/services/address_lookup_service.dart
git add lib/services/user_service.dart

REM -- iOS permissions + pubspec icon path --
git add ios/Runner/Info.plist
git add pubspec.yaml

git commit -m "Session fixes: create_profile KYC redesign, T&C KYC rewrite, photo upload feedback, cashback% fix, member since date, Mapbox v5, photoUrl preserve, NSPhotoLibraryUsageDescription, icon pubspec fix"
git push
echo === Code changes pushed! ===
echo.
echo NEXT: Run push_icon_fix.bat to regenerate and push the app icon.
echo (push_icon_fix.bat runs dart run flutter_launcher_icons first)
pause
