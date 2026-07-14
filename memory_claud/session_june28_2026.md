# Session Memory — 28 June 2026

## Session Focus
Stitch HTML → Flutter Web merchant portal rebuild + full inspection/bug-fix pass.

## Stitch Reference Files
Location: `C:\Users\Maz\Downloads\stitch_goouts_merchant_portal\`
Each subfolder has `code.html` + `screen.png`. Duplicate decisions:
- Login: `login_goouts_merchant_portal_2` (preferred)
- Menu Management: `menu_management_goouts_merchant_portal_2` (larger, more complete)

## Key Pattern — Dart const Bug
`static const` FAILS when a list/map with explicit `Map<String, dynamic>` type annotation
contains `Color` or `IconData` values. Fix: use `static final` + `const` on each `Color()`:
```dart
// BROKEN:
static const _list = [{'color': Color(0xFF0392CA), 'icon': Icons.star}];
// FIXED:
static final _list = [{'color': const Color(0xFF0392CA), 'icon': Icons.star}];
```
Records/tuples (not Maps) with IconData ARE const-safe — no change needed.

## Key Pattern — Mounted Guard
After every `async/await`, before `setState()`:
- Either `if (!mounted) return;` before setState block
- Or `if (mounted) setState(...)` inline
Both are valid. Always one of these is required.

## GoOuts Brand Colors
- Primary blue:  `#0392CA` / `const Color(0xFF0392CA)`
- Sidebar navy:  `#1F1D2E` / `const Color(0xFF1F1D2E)`
- Dark:          `#0D1B3E` / `const Color(0xFF0D1B3E)`
- Orange:        `#F97316` / `const Color(0xFFF97316)`
- BG:            `#F7F9FD` / `const Color(0xFFF7F9FD)`

## Files Changed This Session

### 1. `lib/screens/sponsored_listing_screen.dart`
- Bug: `static const _stitchTiers` had Color + IconData in a map list → build failure
- Fix: changed to `static final _stitchTiers`, added `const` before each `Color()`

### 2. `lib/screens/buy_credits_screen.dart` — FULL REWRITE (Task #109)
- Complete Stitch-matching rebuild
- Balance card: credits in blue `#0392CA`, stars icon
- ONE-TIME/AUTO-RELOAD segmented toggle
- 4-column package grid: POPULAR badge gold `Color(0xFFFFD700)` black text
- Package totals: Starter=50cr/£4.99, Growth=220cr/£17.99, Pro=575cr/£39.99, Enterprise=1800cr/£99.99
- Tier comparison table + checkout sidebar (280px)
- Buy Now button with payment icons + Stripe SSL note
- Bug fixed: added `if (!mounted) return;` in `_loadBalance()` after getCreditsBalance

### 3. `lib/screens/local_reach_screen.dart` — FULL REWRITE (Task #110)
- Bug fixed: `static const _nearbyBusinesses` → `static final`
- `_StitchRadarPainter`: dark navy `#0D1B3E` bg, white dot grid, 3 pulsing rings, merchant pin
- 4 radius options: `[1.0, 2.0, 5.0, 10.0]` (removed 0.5mi)
- 2-column layout: left (radius pills + dark radar + stats), right (businesses list)
- Stats chips: Households/Users Reached/Area with colored icons
- Business list: gray icon containers, `#C4D0FD` type badges
- CTA banner: blue→purple gradient `#0392CA` to `#6B38D4`
- `SingleTickerProviderStateMixin` (only one AnimationController)
- Added `if (!mounted) return;` in `_loadData()`

### 4. `lib/screens/campaign_creator_screen.dart` — TARGETED UPDATES (Task #111)
- `static const _goals` → `static final _goals` (had Color + IconData in Map<String,dynamic>)
- Goal icons updated to Stitch: `ads_click_rounded`, `install_mobile_rounded`, `shopping_cart_checkout_rounded`
- Goal colors: blue `0xFF0392CA`, slate `0xFF515D84`, purple `0xFF6B38D4`
- `_interestTags`: ['Foodies', 'Night Owls', 'Families', 'Students', 'Entertainment Seekers']
- `_radii`: [1.0, 2.0, 5.0, 10.0] (removed 0.5mi)
- Budget slider: min 50, max 500, default 150, divisions 45
- `_radiusLabel()` simplified: `'${r.toInt()}mi'`

### 5. `lib/screens/campaign_tracker_screen.dart`
- Bug fixed: added `if (!mounted) return;` after `await _svc.getCampaigns()` before setState

## Inspection Results (Task #112)
Scanned all 9 dart screens. Clean:
- `merchant_dashboard_screen.dart` ✓ — uses `if (mounted) setState()`
- `merchant_login_screen.dart` ✓ — uses `if (mounted) setState()` after await
- `revenue_reports_screen.dart` ✓ — uses `if (mounted) setState()`
- `menu_management_screen.dart` ✓ — uses `if (mounted) setState()` + multiple guards
- `sponsored_listing_screen.dart` ✓ — const bug fixed, no async setState issues
- `buy_credits_screen.dart` ✓ — mounted guard added this session
- `local_reach_screen.dart` ✓ — mounted guard added, SingleTicker
- `campaign_creator_screen.dart` ✓ — const bug fixed, `_segments` records are const-safe
- `campaign_tracker_screen.dart` ✓ — mounted guard added this session

No remaining const bugs. No remaining missing mounted guards. All screens clean.

## Pending Tasks (carry forward)
- Task #102: ✅ DONE — `menu_management_screen.dart` rebuilt + deployed
- Task #107: `revenue_reports_screen.dart` — Stitch-matched financial dashboard
- Task #65: GoOuts investor PowerPoint deck
- Task #58: goouts.org website HTML
- Task #59: Firebase Hosting config + deploy.bat for website
- Task #68: Live order management screen
- Task #69: Delivery settings screen
- Tasks #73, #74, #75: Consumer App cart/checkout, order tracking, order history
- Task #76: GoOuts DAPP — driver Flutter Android app
- Tasks #77-80: Admin panel food delivery management + CFs

## Deploy Reminder
Run `deploy.bat` in `C:\Users\Maz\goouts\merchants_panel\` to push all rebuilt screens to Firebase Hosting.

## MerchantService / CampaignService Notes
- `MerchantAuthService` + `MerchantService` handle Firebase Firestore + Storage
- `CampaignService` handles campaigns, credits balance (`getCreditsBalance`), `getCampaigns`
- All service calls are async — always guard setState with mounted check
