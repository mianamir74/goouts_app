@echo off
echo === Pushing profile fixes ===
cd /d C:\Users\Maz\goouts_app
git add lib/services/user_service.dart
git add lib/screens/profile_screen.dart
git add lib/screens/home_screen.dart
git add lib/screens/explore_screen.dart
git commit -m "Fix photo upload feedback, profile photo preservation, member since date, cashback %, category label"
git push
echo === Profile fixes pushed! ===
pause
