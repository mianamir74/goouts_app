# GoOuts Session Memory — 4 July 2026

## Session Focus
Admin Panel — Food Orders Management, User Management Load More, Driver Referral field on Partners, memory update.

---

## Completed This Session

### 1. Food Orders Management Screen (NEW admin panel section)
- Added `foodOrders` to `DashboardSection` enum
- Wired in 8 places: enum, allowedSectionsForRole (super_admin/lead_manager/support_team), menuItems, sectionTitle, sectionWidget
- Built `_FoodOrdersManagementPage` class (~680 lines, appended end of file)
- Features:
  - Summary cards: Total Orders, Revenue, Delivered, In Progress, Cancelled, Refunded
  - Status filter chips: All / Pending / Accepted / Preparing / Ready / In Delivery / Delivered / Cancelled / Refunded
  - Date filter chips: All Time / Today / This Week / This Month
  - Search by order ID, customer name, restaurant name
  - DataTable: Date, Order ID, Customer, Restaurant, Total, Status, View + Refund buttons
  - Order detail dialog: full breakdown (customer, restaurant, timeline, items, totals)
  - Refund dialog: calls `processOrderRefund` Cloud Function
  - Load More pagination (50 per page)
  - CSV export via dart:html
- File: `C:\Users\Maz\goouts\admin_panel\lib\admin_dashboard.dart` (appended at end)
- DEPLOYED ✅

### 2. User Management Load More button
- Backend (`AdminDataProvider.loadMoreUsers()`) was already built
- Added Load More UI button at end of `_UserManagementPageState.build`
- Shows only when `p.hasMoreUsers == true`
- Shows spinner during `p.loadingMoreUsers`
- Shows "Showing X users — tap to load next page" count
- Location: admin_dashboard.dart ~line 6952
- NEEDS DEPLOY: run admin panel deploy.bat

### 3. Driver Referral field on Partner form
- Added two new TextEditingControllers: `_referringDriverId`, `_referringDriverName`
- Added to dispose() list
- Added to `_save()` data map: saves `referringDriverId` + `referringDriverName` to Firestore
- Added UI section "Driver Referral" between Commission Split and Offer/Promo
  - Row with two fields: "Referring Driver UID" + "Referring Driver Name"
  - Helper text explaining purpose
- These fields are the foundation for driver residual commission tracking
- NEEDS DEPLOY: run admin panel deploy.bat

### 4. Em-dash bug fix in Food Orders screen
- Bash heredoc wrote em-dash chars (U+2014) that caused dart2js compile error
- Fixed: replaced all em-dashes in new class with hyphens (-) via python script
- File is now valid UTF-8 with no problematic characters

### 5. Competitor refund policy saved for Escrow context
- GoOutdoors 28-day return / 365-day unused policy noted
- Informs GoOuts 14-day escrow hold design (mirrors retail return window)
- Saved to session_july4_2026.md memory

---

## Deploys Needed
- Admin Panel `deploy.bat` — Load More + Driver Referral fields need deployment
  (Food Orders was already deployed)

---

## Important Technical Notes
- `_FoodOrdersManagementPage` class is at END of admin_dashboard.dart (~line 15620+)
- Em-dash chars in new code must use `-` (hyphen) not `—` (em-dash) to avoid dart2js failure
- `loadMoreUsers()` + `hasMoreUsers` + `loadingMoreUsers` all in `AdminDataProvider`
- Partner form now saves `referringDriverId` + `referringDriverName` to `partners` collection
- Driver residuals screen (DashboardSection) NOT YET BUILT — deferred to next session

---

## Pending Tasks (Updated)

### Admin Panel (Priority 1)
- [ ] DEPLOY admin panel deploy.bat (Load More + Driver Referral changes)
- [ ] Driver residuals tracking screen (NEW section) — reads partners by referringDriverId, groups by driver, shows commission tracking
- [ ] Partner invoice history tab (per partner, show all credit_purchases)
- [ ] Partner onboarding email button (sends secure link — Cloud Function `resendMerchantPortalInvite` exists)
- [ ] Report generation screen (currently placeholder)

### Merchant Portal (Priority 2)
- [ ] Delivery settings: opening hours, radius, min order value, delivery fee
- [ ] Stripe real payment integration (currently simulated)
- [ ] Real GoOuts Ltd VAT number + address on PDF invoices

### Training Manual (Priority 3 — big job)
- [ ] Full written guide for ops/support staff covering every admin panel section

### Partner Billing (Priority 4)
- [ ] Partner onboarding email + secure token link
- [ ] GoCardless direct debit mandate
- [ ] Monthly auto-invoice Cloud Function

### Escrow Cashback (Priority 5)
- [ ] Firestore structure, daily release Cloud Function, 25% advance, clawback on return

### Website (Priority 6)
- [ ] "Redeem Points Abroad with GoOuts Virtual Card" section

### Blocked (external)
- [ ] Stripe Issuing application
- [ ] TrueLayer VRP
- [ ] Barclays Corporate account

---

## Key File Paths
| App | Path |
|---|---|
| Merchant Portal | C:\Users\Maz\goouts\merchants_panel\ |
| Admin Panel | C:\Users\Maz\goouts\admin_panel\ |
| Admin Dashboard | C:\Users\Maz\goouts\admin_panel\lib\admin_dashboard.dart |
| Admin Data Provider | C:\Users\Maz\goouts\admin_panel\lib\services\admin_data_provider.dart |
| Merchant Terminal | C:\Users\Maz\goouts\merchant_terminal\ |
| Consumer App | C:\Users\Maz\goouts_app\ |
| Driver App | C:\Users\Maz\goouts\driver_app\ |
| Cloud Functions | C:\Users\Maz\goouts\admin_panel\functions\index.js |

## Live URLs
| Site | URL |
|---|---|
| Admin Panel | https://goouts-f16db.web.app |
| Merchant Portal | https://goouts-merchants.web.app |
| Website | https://www.goouts.co.uk |
