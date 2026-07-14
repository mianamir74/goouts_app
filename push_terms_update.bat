@echo off
echo === Pushing Terms & Conditions update ===
cd /d C:\Users\Maz\goouts_app
git add lib/screens/create_profile_expanded_screen.dart
git commit -m "Update T&C: rewrite KYC section (soft approach), add cashback redemption-only clause (6.6)"
git push
echo === T&C update pushed! ===
pause
