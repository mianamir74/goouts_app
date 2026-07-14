# Push APNs + Push Notifications capability fix
$ErrorActionPreference = "Stop"
$appDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Working in: $appDir" -ForegroundColor Cyan

# Git commit and push all changes
Set-Location $appDir
Remove-Item ".git\index.lock" -ErrorAction SilentlyContinue
git config user.email "mianamir74@gmail.com"
git config user.name "Maz"
git add "ios/Runner/AppDelegate.swift"
git add "ios/Runner/Runner.entitlements"
git add "ios/Runner.xcodeproj/project.pbxproj"
git commit -m "Add Push Notifications entitlement + Firebase APNs delegate methods for iOS Phone Auth"
git push

Write-Host ""
Write-Host "=== Code pushed! Now search for your APNs key file ===" -ForegroundColor Green

# Search for the .p8 file
Write-Host "Searching for AuthKey_CD2KNZ24U2.p8 ..." -ForegroundColor Cyan
$searchPaths = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\OneDrive",
    "$env:USERPROFILE\OneDrive - GOOUTS WORLDWIDE LTD",
    "C:\Users\Maz"
)

$found = $null
foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $result = Get-ChildItem -Path $path -Recurse -Filter "AuthKey_CD2KNZ24U2.p8" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($result) {
            $found = $result
            break
        }
    }
}

# Also search for any .p8 file
if (-not $found) {
    Write-Host "Exact file not found. Looking for any .p8 file..." -ForegroundColor Yellow
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $results = Get-ChildItem -Path $path -Recurse -Filter "*.p8" -ErrorAction SilentlyContinue
            if ($results) {
                Write-Host "Found .p8 files:" -ForegroundColor Yellow
                $results | ForEach-Object { Write-Host "  $($_.FullName)" -ForegroundColor White }
                $found = $results | Select-Object -First 1
            }
        }
    }
}

Write-Host ""
if ($found) {
    Write-Host "FOUND: $($found.FullName)" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== NEXT STEP: Upload APNs key to Firebase ===" -ForegroundColor Cyan
    Write-Host "1. Open: https://console.firebase.google.com/u/0/project/goouts-f16db/settings/cloudmessaging/ios:com.goouts.app"
    Write-Host "2. Under 'APNs Authentication Key' click 'Upload'"
    Write-Host "3. Select file: $($found.FullName)"
    Write-Host "4. Key ID: CD2KNZ24U2"
    Write-Host "5. Team ID: 6B62Z4423C"
    # Copy path to clipboard
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetText($found.FullName)
    Write-Host ""
    Write-Host "File path copied to clipboard!" -ForegroundColor Green
} else {
    Write-Host "APNs key file NOT found on this computer." -ForegroundColor Red
    Write-Host ""
    Write-Host "=== NEXT STEP: Create a new APNs key ===" -ForegroundColor Yellow
    Write-Host "1. Go to: https://developer.apple.com/account/resources/authkeys/add"
    Write-Host "2. Name it: GooutsAPNS2"
    Write-Host "3. Check 'Apple Push Notifications service (APNs)'"
    Write-Host "4. Click Continue, then Register"
    Write-Host "5. Click DOWNLOAD (you can only download once!)"
    Write-Host "6. Then upload to Firebase:"
    Write-Host "   https://console.firebase.google.com/u/0/project/goouts-f16db/settings/cloudmessaging/ios:com.goouts.app"
    Write-Host "   Key ID = (shown on Apple page), Team ID: 6B62Z4423C"
}

Write-Host ""
Read-Host "Press Enter to close"
