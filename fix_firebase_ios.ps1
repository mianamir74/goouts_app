# Fix Firebase Phone Auth on iOS
$ErrorActionPreference = "Stop"
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Working in: $appDir" -ForegroundColor Cyan

# Step 1: Find plist in Downloads
$downloads = "$env:USERPROFILE\Downloads"
$srcPlist = Get-ChildItem "$downloads\GoogleService-Info.plist" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $srcPlist) {
    Write-Host "ERROR: GoogleService-Info.plist not found in Downloads." -ForegroundColor Red
    Write-Host "Download it from Firebase Console > Project Settings > GoOuts Cashback App" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Found: $($srcPlist.FullName)" -ForegroundColor Green

# Step 2: Copy to ios/Runner/
$destPlist = "$appDir\ios\Runner\GoogleService-Info.plist"
Copy-Item $srcPlist.FullName $destPlist -Force
Write-Host "Copied plist to ios/Runner/" -ForegroundColor Green

# Step 3: Extract REVERSED_CLIENT_ID
$plistContent = Get-Content $destPlist -Raw
$match = [regex]::Match($plistContent, '<key>REVERSED_CLIENT_ID</key>\s*<string>([^<]+)</string>')
$reversedClientId = if ($match.Success) { $match.Groups[1].Value } else { $null }

if (-not $reversedClientId) {
    Write-Host "WARNING: REVERSED_CLIENT_ID not found in plist" -ForegroundColor Yellow
} else {
    Write-Host "REVERSED_CLIENT_ID: $reversedClientId" -ForegroundColor Green

    # Step 4: Add URL scheme to Info.plist
    $infoPlistPath = "$appDir\ios\Runner\Info.plist"
    $infoContent = Get-Content $infoPlistPath -Raw

    if ($infoContent -match "CFBundleURLTypes") {
        Write-Host "URL scheme already in Info.plist - skipping" -ForegroundColor Yellow
    } else {
        $urlBlock = "<key>CFBundleURLTypes</key>`n`t<array>`n`t`t<dict>`n`t`t`t<key>CFBundleTypeRole</key>`n`t`t`t<string>Editor</string>`n`t`t`t<key>CFBundleURLSchemes</key>`n`t`t`t<array>`n`t`t`t`t<string>$reversedClientId</string>`n`t`t`t</array>`n`t`t</dict>`n`t</array>"
        $infoContent = $infoContent -replace '</dict>\s*</plist>', "$urlBlock`n</dict>`n</plist>"
        Set-Content $infoPlistPath $infoContent -Encoding UTF8
        Write-Host "Added URL scheme to Info.plist" -ForegroundColor Green
    }
}

# Step 5: Git commit and push
Set-Location $appDir
Remove-Item ".git\index.lock" -ErrorAction SilentlyContinue
git config user.email "mianamir74@gmail.com"
git config user.name "Maz"
git add "ios/Runner/GoogleService-Info.plist" "ios/Runner/Info.plist" "ios/Runner.xcodeproj/project.pbxproj"
git commit -m "Add GoogleService-Info.plist, URL scheme and Xcode reference for iOS Phone Auth"
git push

Write-Host ""
Write-Host "Done! Codemagic will now build with Phone Auth properly configured." -ForegroundColor Green
Read-Host "Press Enter to close"
