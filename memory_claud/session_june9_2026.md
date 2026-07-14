# GoOuts Session Memory — 9 June 2026

## Summary of Work Done This Session

---

## 1. Biometric Login — Fully Implemented (User App)

### Files Modified/Created

**`goouts_app/pubspec.yaml`**
- Added: `local_auth: ^2.3.0`

**`goouts_app/android/app/src/main/AndroidManifest.xml`**
- Added: `USE_BIOMETRIC` and `USE_FINGERPRINT` permissions

**`goouts_app/ios/Runner/Info.plist`**
- Added: `NSFaceIDUsageDescription` — "GoOuts uses Face ID to keep your account secure and let you log in quickly."

**`goouts_app/lib/services/biometric_service.dart`** — NEW FILE
- Singleton: `BiometricService.instance`
- `isSupported()` — checks canCheckBiometrics && isDeviceSupported
- `isEnabled()` — reads SharedPreferences key `'biometric_login_enabled'`
- `setEnabled(bool)` — saves to SharedPreferences
- `authenticate({String reason})` — calls LocalAuthentication with stickyAuth:true, biometricOnly:false
- `availableTypes()` — returns List<BiometricType>

**`goouts_app/lib/screens/biometric_lock_screen.dart`** — NEW FILE
- Dark branded lock screen (GoOuts blue on navy background)
- Auto-prompts biometric on open (addPostFrameCallback)
- Shows fingerprint or face icon based on device capability
- On success: navigates to `widget.nextRoute`
- On failure: shows error + "Try Again" tap
- "Use PIN instead" → pushReplacementNamed('/login')

**`goouts_app/lib/screens/profile_security_screen.dart`** — MODIFIED
- Added import for `biometric_service.dart`
- Added state: `_biometricEnabled`, `_biometricSupported`
- Added `_loadBiometric()` called in `initState`
- Added `_toggleBiometric(bool)` — requires one biometric confirm before enabling
- Biometric toggle row now reads real state, shows "Not available on this device" if unsupported
- Was hardcoded `value: true, onChanged: (_) {}` — now fully functional

**`goouts_app/lib/screens/splash_screen.dart`** — MODIFIED
- Added import for `biometric_service.dart`
- Before routing logged-in user to `/home`, checks `BiometricService.instance.isEnabled()`
- If enabled → routes to `/biometric-lock` instead of `/home`

**`goouts_app/lib/main.dart`** — MODIFIED
- Added import for `biometric_lock_screen.dart`
- Added route: `'/biometric-lock': (context) => const BiometricLockScreen(nextRoute: '/home')`

---

## 2. Admin Panel — Content Showing Fix

### Root Cause
`_buildSelectedSection` used `IndexedStack` which renders ALL sections simultaneously.
New `_FaqManagementPage` and `_ContentPagesManagementPage` had `Expanded` widgets inside
`Column` inside `SingleChildScrollView` → unconstrained height → layout error → entire
IndexedStack went blank.

### Fix Applied
1. Removed outer `SingleChildScrollView` wrapping `_buildSelectedSection`
   - Changed `Expanded(child: SingleChildScrollView(child: _buildSelectedSection(...)))` 
     to `Expanded(child: _buildSelectedSection(...))`
2. Changed `IndexedStack` → `KeyedSubtree` — renders only selected section:
   ```dart
   Widget _buildSelectedSection({required bool isTablet}) {
     return KeyedSubtree(
       key: ValueKey(_selectedSection),
       child: _sectionWidget(_selectedSection, isTablet: isTablet),
     );
   }
   ```
3. Wrapped `_buildComingSoonPage` in its own `SingleChildScrollView` with padding:24

---

## 3. FAQ Management — Admin Panel + Firestore

### Admin Panel (`goouts/admin_panel/lib/admin_dashboard.dart`)
- Added `faqManagement` and `contentPages` to `DashboardSection` enum
- Added sidebar menu items, section titles, permission keys for both
- `_FaqManagementPage` — full CRUD (add/edit/delete, active toggle, order)
- Seed button seeds 21 default FAQs to Firestore `faqs` collection
- Seed data uses Unicode escapes only (`—`, `£`, `→`) — no raw special chars

### User App (`goouts_app/lib/screens/faq_screen.dart`)
- Removed 21-item hardcoded `_faqs` list
- Replaced with `StreamBuilder<QuerySnapshot>` on `faqs` collection
  - Filter: `where('isActive', isEqualTo: true).orderBy('order')`
  - Expand state keyed by Firestore doc ID (not index)

---

## 4. Content Pages — Admin Panel + User App Live

### Admin Panel
- `_ContentPagesManagementPage` with TabController (3 tabs):
  - Privacy Policy (`content_pages/privacy_policy`)
  - Terms & Conditions (`content_pages/terms_conditions`)
  - Cookies Policy (`content_pages/cookies_policy`)
- `_ContentPageEditor` per tab: loads/saves Firestore, "Unsaved changes" badge, last saved timestamp

### User App
**`goouts_app/lib/screens/signup_screen.dart`** — MODIFIED
- Added `cloud_firestore` import
- `_loadTerms()` in `initState` fetches `content_pages/terms_conditions`
- `_showTerms` uses `_termsFromDb ?? hardcoded_fallback`

**`goouts_app/lib/screens/create_profile_expanded_screen.dart`** — MODIFIED
- Added `cloud_firestore` import
- `_loadLegalContent()` in `initState` fetches both `terms_conditions` and `privacy_policy`
- T&C and Privacy Policy sheet calls use `_termsFromDb ?? _termsContent` and `_privacyFromDb ?? _privacyContent`
- Fallback to hardcoded strings if Firestore empty or offline

---

## 5. Firestore Rules Updated

**`goouts_app/firestore.rules`** — MODIFIED
- Added `faqs` collection: read=authenticated, write=isAdmin()
- Added `content_pages` collection: read=authenticated, write=isAdmin()
- Deployed: `firebase deploy --only firestore:rules --project goouts-f16db` (from goouts_app/)

---

## 6. Build & Deploy Pattern (Admin Panel)
```bash
cd admin_panel
flutter build web
firebase deploy --only hosting --project goouts-f16db
```

---

## Key Architecture Notes

### Content Pages Flow
- Admin types content in admin panel editor → saves to `content_pages/{pageId}`
- User app fetches on screen open → shows Firestore content
- If nothing saved → falls back to hardcoded Dart strings (no broken UX)

### FAQ Flow
- Admin seeds/manages FAQs in admin panel → stored in `faqs` collection
- User app FAQ screen streams live from Firestore (instant updates, no rebuild needed)

### Biometric Flow
1. User enables in Profile → Security → Biometric Login (confirms with biometric first)
2. Stored in SharedPreferences: `biometric_login_enabled = true`
3. On next app open: splash checks `BiometricService.isEnabled()` → routes to `/biometric-lock`
4. Lock screen auto-prompts Face ID/fingerprint → on success → `/home`
5. "Use PIN instead" → `/login`

---

## Known Issues / Watch Out
- T&C content has box-drawing chars (`━━━`) that cause null bytes when embedded in Dart strings via Python
  - Fix: never embed raw T&C text from Python write — paste manually via admin panel instead
- Admin dashboard is 9700+ lines in a single file — always use Python for large edits
- `Expanded` inside `Column` inside `SingleChildScrollView` = layout crash (unconstrained height)

---

## Firestore Collections Reference
| Collection | Purpose |
|---|---|
| `faqs` | FAQ items managed by admin |
| `content_pages` | T&C, Privacy Policy, Cookies Policy |
| `users/{uid}/notifications` | User notification inbox |
| `users/{uid}/messages` | Direct messages from admin |
| `admin_promo_campaigns` | Promo overlays |

---

## CRITICAL CONSTRAINT (never touch)
- KYC function before Stripe was built to save costs — DO NOT DISTURB

---

## Pending Tasks
- Task #26: Rebuild Notifications screen to read from Firestore
- Task #27: Unread badge counts on Messages tab and bell icon
- Task #28: Deep linking — notification tap routes to correct screen
- Task #35: Biometric login implemented but NOT yet tested on physical device
- Seed content_pages/terms_conditions and content_pages/privacy_policy via admin panel (manual paste)
- User app rebuild needed to pick up biometric + Firestore T&C changes: `flutter pub get && flutter run`
