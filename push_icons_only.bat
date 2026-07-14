@echo off
echo === Pushing regenerated app icons ===
cd /d C:\Users\Maz\goouts_app
git add ios/Runner/Assets.xcassets/AppIcon.appiconset/
git add android/app/src/main/res/mipmap-mdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-hdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
git add android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
git add android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png
git add android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png
git add android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png
git add android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png
git add android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png
git commit -m "Regenerate all app icons from icon_source.png (iOS 21 sizes + Android mipmap + adaptive foreground)"
git push
echo === Icons pushed! Ready to build in Codemagic ===
pause
