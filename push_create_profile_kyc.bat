@echo off
echo === Pushing Create Profile screen with KYC selection + iOS photo permission fix ===
cd /d C:\Users\Maz\goouts_app
git add lib/screens/create_profile_screen.dart
git add ios/Runner/Info.plist
git commit -m "Redesign create_profile_screen: KYC doc selector + fix missing NSPhotoLibraryUsageDescription iOS crash"
git push
echo === Done! ===
pause
