@echo off
echo === Pushing goouts_app icon update ===
cd /d C:\Users\Maz\goouts_app
git add ios/Runner/Assets.xcassets/AppIcon.appiconset/
git add android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png
git add android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png
git add android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png
git add android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png
git add android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png
git add android/app/src/main/res/mipmap-mdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-hdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
git commit -m "Update app icon to thicker-line GoOuts logo (icon_source.png)"
git push
echo === goouts_app icon pushed! ===
pause
