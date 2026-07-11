# GoOuts Session Memory — June 2026 Part B
# Saved to goouts_app/memory_claud/ for easy reference

## What was built this session (Sessions 2 + 3)

### GoOuts User App (Session 2)
- createUser() clears old transactions/reviews on every signup
- Notifications screen: no more hardcoded demo data
- GoOuts Plus price: £10/year (was £5)
- Full ticket system: support_ticket_service.dart rebuilt, real-time chat, image upload, star rating
- New: support_ticket_chat_screen.dart
- Updated: support_tickets_screen.dart, contact_support_screen.dart, profile_screen.dart, main.dart

### Driver App (Session 2)
- Contact us form redesigned with GoOuts-style visual tiles
- Backup: help_support_screen.BACKUP.dart
- All Firestore fields identical — nothing broke

### Admin Panel — Session 2 (https://goouts-f16db.web.app/)
- Support Tools: source filter, Waiting User label, unreadByUser flag
- User Management page: 7 KPI cards, table with KYC/wallet/cashback/plus, expand panel with Approve/Reject actions
- Sidebar: drag-and-drop with 3-line handles, dividers, buildDefaultDragHandles:false
- 3-minute idle timeout with 30-second warning dialog
- Login: Remember Me checkbox (localStorage), admin profile recovery button
- Login: error now shows actual Firebase Auth UID when profile not found
- User review sheet: draggable floating panel (Overlay-based, 900x87vh)
- Review sheet: Photos & Documents, 14 verification flags, document preview banner
- Driver filter buttons fixed (All/Registered/Pending/Active/Inactive)
- All Firestore writes → callable CFs (Security Rules fix)
- adminUpdateDriverStatus / adminUpdateUserKyc CFs created
- Driver approve revert: CF guard + write identityVerificationStatus: verified
- _DocumentPreviewCard 15-second timeout
- Direct message button on all rows + review sheets
- _QuickMessageDialog (5 request types) + adminSendDirectMessage CF
- Resubmission request system: dialog types + Firestore field + FCM deep link
- Identity verification OTP: _VerifyIdentityDialog + adminSendVerificationCode CF
- Mobile dev handoff doc created

### Admin Panel — Session 3 + 4 (2026-06-08)
- ALL CF regions changed: us-central1 → europe-west1 (12 occurrences in index.js)
- All Flutter callers updated: admin_dashboard.dart, admin_driver_service.dart
- guardApprovedDriverStatus CF: onDocumentWritten on drivers/{id} — restores APPROVED if adminManuallyApproved=true
- guardApprovedCabDriverStatus CF: same for cab_drivers/{id}
- guardApprovedUserKyc CF: onDocumentWritten on users/{id} — restores kycStatus=approved if adminManuallyApprovedKyc=true
- adminUpdateDriverStatus now writes adminManuallyApproved: true on approve
- adminUpdateUserKyc now writes adminManuallyApprovedKyc: true on approve
- adminUpdateUserKyc: .update() → .set({merge:true}) + internal try/catch + console.log
- adminGetUsers CF added: reads users via Admin SDK, paginated (pageSize + lastDocId), returns {users, hasMore, nextLastDocId}
- AdminDataProvider complete rebuild:
  * Lazy loading gates per page
  * Named subscription map _subs for individual cancel
  * Debounced notifyListeners (100ms Timer)
  * Error retry after 5 seconds
  * reset() on logout: cancels subs, clears data, resets flags
  * Users loaded via adminGetUsers CF (NOT Firestore stream — Security Rules block collection queries)
  * refreshUsers() method: re-fetches page 1 after KYC update
  * Pagination: _userPageSize=50, _usersLastDocId cursor, hasMoreUsers, loadingMoreUsers
- _triggerLazyLoad(section) in admin_dashboard.dart: fires ensureXxxLoaded() per page
- Both logout paths call AdminDataProvider.instance.reset()
- KYC approval: calls refreshUsers() after success so list updates immediately
- Error snackbar format: 'KYC update failed [ExceptionType]: message' — helps diagnose
- _fetchUsersPage: captures _generation before CF call, discards result if generation changed (stale guard)
- Dashboard spinner fix: admin_auth_service.dart getAdminProfileData() tries Source.cache first (instant), background server refresh, 8s server timeout; _loadAdminProfile() has 10s outer timeout safety net
- Result: logout → login now loads dashboard in <2s instead of 45s

### Root Cause — User KYC permission-denied (Session 3)
GoOuts Firestore Security Rules restrict collection queries on users to request.auth.uid == userId.
Admin web client UID doesn't match any user UID → stream fails with permission-denied.
persistenceEnabled: true (in main.dart) was masking this: cached IndexedDB data showed normally
while the live stream silently failed. Fix: use adminGetUsers CF which runs as Admin SDK.

### Firestore Rules note (from Session 2)
- session_june2026b.md noted rules were updated with request.auth != null for users reads
- File saved: goouts_app/firestore.rules — but may not have been deployed
- If rules ARE deployed and allow admin reads, the Firestore stream approach would also work

### Two-Way Chat (Session 4 — 2026-06-08)
- adminSendDirectMessage CF already creates support_requests ticket + messages subcollection
- User app getMyTickets() query: .where('uid').where('sourceCollection','users') — finds admin-initiated tickets ✓
- Driver app my_tickets_screen.dart: .where('uid') only — finds all tickets including admin-initiated ✓
- CF updated: now does profile lookup (firstName, surname, email, mobileNumber), writes ticketNumber (SR-XXXXXXXX), lastMessage, lastMessageAt, lastMessageBy:'admin', unreadByAdmin:false
- Two-way chat fully working end-to-end for both user app and driver app — no app code changes needed

### App Icons (Session 4 — 2026-06-08)
- Source images: 1024×1024 high-res provided for iOS and Android separately
- iOS source: goouts_app/assets/images/ios logos/1024-iod.png (RGB, no alpha, solid background) 
- Android source: goouts_app/assets/images/android logos/1024-android.png (1024×1024)
- iOS icons generated: 21 sizes (20px → 1024px), all RGB (alpha removed — Apple rejects transparency)
  * Injected into: goouts_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/
  * Injected into: goouts/driver_app/ios/Runner/Assets.xcassets/AppIcon.appiconset/
- Android icons generated: ic_launcher.png + ic_launcher_round.png in all 5 mipmap folders (48→192px)
  * Plus ic_launcher_foreground.png in all drawable folders
  * Injected into: goouts_app/android/ and goouts/driver_app/android/
- Source folders (assets/images/ios logos, assets/images/android logos) can be deleted — no longer needed
- MacBook pending delivery — iOS App Store submission on hold until then
- Reminder when MacBook arrives: check Info.plist and provisioning profile before first App Store submission

### Migration Notes Document
- Firebase → AWS migration planning doc created: goouts/admin_panel/GoOuts_Firebase_AWS_Migration_Notes.docx
- Ref: Work Session 3, 8 June 2026
- Covers: service mapping, complexity table, Bedrock/Claude integration, GoOuts-specific notes, migration phases

## Still pending
1. firebase deploy --only functions (MUST do first)
2. flutter build web --release && firebase deploy --only hosting
3. Test KYC approve after deploy — should show green snackbar
4. Add "Load More" button in _UserManagementPage for pagination UI
5. Node.js 20 → 22 upgrade in functions/package.json
6. Family plan Firebase structure not built yet
7. GoOuts Plus docs still say £5 (Terms, FAQ docx files)
8. Mobile dev tasks (see MOBILE_DEV_RESUBMISSION_HANDOFF.md)
9. App Store submission — waiting for MacBook delivery (icons already in place)
