# GoOuts Session Memory — 8 June 2026 (Sessions 5–6)

## Files Modified Today

### User App (`goouts_app`)
- `lib/screens/message_center_screen.dart` — FULL REWRITE
  - Direct Firestore stream: `users/{uid}/messages`
  - All/Unread tabs, search bar, swipe-to-archive/delete
  - Auto-mark-all-read on open (batch write)
  - `_InboxMessage` model now includes: imageUrl, imageCaption, ctaLabel, ctaValue
  - Navigates to `UserMessageDetailScreen` on tap
  - AppBar: blue, "My Tickets" button → `/support-tickets`

- `lib/screens/user_message_detail_screen.dart` — NEW FILE
  - Full-page message detail
  - Shows header card (sender, title, date) + body card
  - Shows promo image (Image.network) if `imageUrl` present
  - Shows CTA button if `ctaLabel` + `ctaValue` present
  - "Open Support Chat" button if `ticketId` present → SupportTicketChatScreen
  - Marks message as read on open

- `lib/widgets/promo_overlay.dart` — NEW FILE
  - `PromoOverlayWrapper` wraps home screen
  - Reads `admin_promo_campaigns` where `isActive=true`, `audienceType='users'`
  - 1.8s delay before showing (so home screen renders first)
  - Full-screen dark overlay with promo image
  - Countdown timer in teal rounded-rectangle "SKIP X >" button
  - After countdown: "SKIP >" button dismisses
  - CTA button opens sponsor URL via url_launcher (launchUrl external)
  - SharedPreferences stores dismissed promo IDs (shows once per user)
  - Targeting: checks `targetUserUids` for SELECTED_USERS mode

- `lib/screens/home_screen.dart`
  - Wrapped build() return in `PromoOverlayWrapper`
  - Added import for promo_overlay.dart

- `pubspec.yaml`
  - Added: `url_launcher: ^6.3.0`

- `android/app/src/main/AndroidManifest.xml`
  - Added http/https intent queries for url_launcher

- `firestore.rules`
  - Added rules for: admin_driver_message_jobs, admin_user_message_jobs, admin_promo_campaigns
  - Deployed with: `firebase deploy --only firestore --project goouts-f16db` (from goouts_app folder)

- `firestore.indexes.json` — NEW FILE
  - Composite index: admin_promo_campaigns (isActive ASC, audienceType ASC, createdAt DESC)

- `firebase.json`
  - Added `firestore: { rules, indexes }` section

### Admin Panel (`goouts/admin_panel`)
- `lib/broadcast/admin_driver_messaging_page.dart` — MAJOR ADDITIONS
  - Added `_AudienceType` enum: `drivers | users`
  - Added `_TargetMode` extended: `allUsers | selectedUsers`
  - Added `_UserRecord` model (id, fullName, email, phone, kycStatus, fcmToken)
  - Added `_UserTinyStatus` widget
  - Broadcast UI now has Audience Type switcher (Drivers | Users)
  - User targeting: All Users / Selected Users, verified filter, search + checkbox list
  - `_submitFirebaseFlow` branches on audienceType:
    - Standard message to users → writes to `admin_user_message_jobs`
    - Promo to users → writes to `admin_promo_campaigns` with `isActive: true`
    - Promo to drivers → writes to `admin_promo_campaigns` with `isActive: false` (draft)
  - Error catch now shows actual error: `Error: ${e.toString()}`
  - Fixed exhaustive switch on `_TargetMode` (added allUsers/selectedUsers cases)

### Cloud Functions (`goouts/admin_panel/functions/index.js`)
- `processUserMessageJob` — UPDATED
  - Now passes through: contentType, imageUrl, imageCaption, ctaLabel, ctaValue to inbox message
  - Promo fields stored in `users/{uid}/messages` doc

- `processAdminUserMessageJob` export — NEW (added in previous session)
  - Triggers on `admin_user_message_jobs/{jobId}` onCreate
  - Region: europe-west1

- `processAdminPromoCampaign` export — NEW
  - Triggers on `admin_promo_campaigns/{campaignId}` onCreate
  - Sends FCM push to all target users (`audienceType === 'users'`)
  - Reads fcmToken from users collection
  - Stores pushSentCount + pushSentAt on campaign doc
  - Region: europe-west1

- **CRITICAL**: index.js was truncated mid-line multiple times during session
  - Fixed each time using Python binary append
  - Always verify with: `node --check functions/index.js`

## Architecture Decisions

### Broadcast → User Inbox
- Standard messages: `admin_user_message_jobs` → CF → `users/{uid}/messages`
- Promo/advertising: `admin_promo_campaigns` (isActive=true) → CF sends push → user app overlay

### Promo Ad Flow
1. Admin creates promo with image, title, subtitle, CTA label/URL, skip seconds
2. Saved to `admin_promo_campaigns` with `isActive: true`
3. CF `processAdminPromoCampaign` fires → sends FCM push to target users
4. User receives push notification (works offline)
5. User opens app → home screen → 1.8s delay → promo overlay appears
6. Overlay shows: image, title, subtitle, SKIP countdown button, CTA button
7. After skipDelaySeconds: SKIP button becomes tappable
8. CTA tapped → opens sponsor URL in external browser
9. Dismissed promo ID saved to SharedPreferences (never shows again)

### Message Inbox (User App)
- Source: `users/{uid}/messages` subcollection (NOT MessageService)
- Promo messages have `imageUrl` field → shown as image in detail screen
- Standard messages have `ticketId` → shows "Open Support Chat" button

## Firestore Collections Added/Used
- `admin_user_message_jobs` — user broadcast jobs (new)
- `admin_promo_campaigns` — promo/advertising campaigns (existing, now used for users too)
- `users/{uid}/messages` — user inbox subcollection

## Pending / Still To Do
- Deploy checklist (run after waking up):
  1. `firebase deploy --only functions` (from admin_panel)
  2. `flutter build web --release && firebase deploy --only hosting` (admin_panel)
  3. `firebase deploy --only firestore --project goouts-f16db` (from goouts_app)
  4. `flutter pub get && flutter run` (goouts_app — picks up url_launcher)
- Load More button in User Management page (pagination UI)
- Node.js 20 → 22 upgrade in functions/package.json
- Family plan Firebase structure (not built yet)
- GoOuts Plus docs still say £5 (Terms, FAQ docx files need updating)
- App Store submission — waiting for MacBook delivery
- When MacBook arrives: check Info.plist and provisioning profile

## Key Constants / IDs
- Firebase project: goouts-f16db
- CF region: europe-west1 (ALL functions)
- Admin panel URL: https://goouts-f16db.web.app/
- GoOuts blue: #0392CA
- Promo overlay background: Colors.black ~85% opacity
- Skip button colour: #2D7A7A (teal)

## CRITICAL CONSTRAINT (never touch)
- KYC function before Stripe was built to save costs — DO NOT DISTURB

## File Truncation Issue (ongoing)
- Write/Edit tools truncate large files — always verify with `wc -l` and `node --check`
- Fix pattern: use Python binary append with tail content written via Write tool first
- bash heredoc also truncates for large content — use Python instead
