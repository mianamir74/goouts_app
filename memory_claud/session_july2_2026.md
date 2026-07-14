# GoOuts Session Memory — 2 July 2026

## Session Focus
Merchant Portal VAT invoice system, food image library picker (correct terminal), campaign pricing, Firestore rules fixes, admin panel credit sales ledger.

---

## Completed This Session

### 1. Food Image Library Picker — Merchant Terminal (CORRECT location)
- Location: `C:\Users\Maz\goouts\merchant_terminal\lib\`
- `services/menu_service.dart` — added `libraryImageUrl` param to `saveItem()`
- `screens/menu_management_screen.dart` — added `_LibraryPickerSheet`, two buttons (Upload Photo / Use Library), library preview, `_pickFromLibrary()` method
- Runs via `run_terminal.bat` (USB to Android tablet, no deploy needed)

### 2. Campaign Pricing System
- `merchants_panel/lib/services/campaign_service.dart` — added `fetchGlobalMultiplier()` reading from `platform_config/campaign_pricing`, added `globalMultiplier` param to `calculatePrice()`, added `estimatedCost: budgetCredits` to return map
- `merchants_panel/lib/screens/campaign_creator_screen.dart` — added `_globalMultiplier` state, pricing table widget `_buildPricingTable()` with 6 tiers, tappable rows, VAT footnote
- `admin_panel/lib/admin_dashboard.dart` — added "Campaign Pricing" card to Platform Settings: slider 0.25x–3.0x, live preview table, saves to `platform_config/campaign_pricing`

### 3. Firestore Rules Fixes
- `admin_panel/firestore.rules` — added `merchant_campaigns` rule (read/create/update for auth users), `partner_reach_cache` rule (read only, write:false), `credit_purchases` rule (merchant reads own, admin reads all, create allowed, delete blocked)
- `admin_panel/firebase.json` — confirmed `"rules": "firestore.rules"` present
- `admin_panel/deploy.bat` — confirmed `firestore:rules` in deploy command

### 4. VAT on Credit Purchases
- `merchants_panel/lib/screens/buy_credits_screen.dart` — full rewrite: VAT breakdown in package cards (+ VAT label), comparison table now has Price ex VAT / VAT 20% / Total incl VAT rows, checkout card shows full subtotal/VAT/total breakdown, `_processing` state, Firestore save on payment, success dialog with PDF download, "Billing History" link in AppBar
- `merchants_panel/pubspec.yaml` — added `pdf: ^3.11.0` and `printing: ^5.13.2`

### 5. VAT Receipt Service (NEW)
- `merchants_panel/lib/services/vat_receipt_service.dart` — generates A4 PDF: GoOuts header + PAID stamp, Bill To section, line items table, subtotal/VAT/total totals, payment confirmed green box, HMRC footer, downloads via `dart:html` blob
- `generateInvoiceNumber()` static method (INV-YYYY-NNNNN format)

### 6. Billing History Screen (NEW)
- `merchants_panel/lib/screens/billing_history_screen.dart` — lists all `credit_purchases` for merchant, summary cards (invoice count / total spent / VAT paid), per-row download invoice button, CSV export, empty state

### 7. Admin Panel — Credit Sales Ledger (NEW section in VAT Management)
- `admin_panel/lib/admin_dashboard.dart` — added below existing food orders VAT table:
  - `_loadPurchases()` reads `credit_purchases` collection
  - `_filteredPurchases` getter with period filter
  - `_exportCreditsCsv()` browser download
  - Summary cards: Credit Sales VAT to HMRC, Revenue ex VAT, Total Purchases
  - Period filter chips (This Quarter / Last Quarter / This Year / All)
  - Full DataTable with Invoice No, Merchant, Package, Credits, Ex VAT, VAT, Total Paid columns

---

## Deploys Done Today
- Admin Panel `deploy.bat` — hosting + functions + Firestore indexes + rules ✅
- Merchant Portal `deploy.bat` — hosting only ✅
- Merchant Terminal `run_terminal.bat` — flutter run to Android tablet ✅

---

## Important Technical Notes
- `dart:html` used for PDF + CSV browser download in web apps — causes WebAssembly warnings (not errors, acceptable for now)
- `GoogleFonts.inter()` does NOT accept `fontFamily` param — use `TextStyle(fontFamily: 'monospace')` directly
- Merchant Portal credit purchase flow is SIMULATED (no real Stripe) — adds credits and saves invoice record immediately on "Pay Now"
- `credit_purchases` Firestore collection is the accounting source of truth for credit sales VAT
- PDF invoices generated on-demand from Firestore records — NOT stored in Firebase Storage

---

## Pending Tasks (Full List)

### Merchant Portal (goouts-merchants.web.app)
- [ ] Stripe real payment integration for credit purchases (currently simulated)
- [ ] Real GoOuts Ltd VAT number on PDF invoices (currently placeholder: GB 000 0000 00)
- [ ] Real registered company address on PDF invoices
- [ ] Delivery settings: opening hours, radius, min order value, delivery fee (Task #69)
- [ ] Photo upload from web (Firebase Storage)
- [ ] Cashback % change with admin approval flow
- [ ] "Learn more about credit usage" link — not wired up

### Driver App (DAPP) — C:\Users\Maz\goouts\driver_app
- [ ] Replace map placeholders with real google_maps_flutter in dashboard + active_delivery_screen
- [ ] Wire FCM push notification for new order offer popup
- [ ] Run flutter pub get in driver_app folder
- [ ] Test on Android device
- [ ] Unbuilt Stitch screens: trip_radar, delivery_verification, identity_verification, safety_toolkit, weekly_residual_summary, dashboard_heatmap

### Consumer App (goouts_app)
- [ ] Wire checkout_screen.dart into food_menu_screen.dart navigation (Task #73)
- [ ] Order history + reorder screen (Task #75)
- [ ] services_screen.dart — still hardcoded
- [ ] special_offers_screen.dart — still hardcoded
- [ ] home_screen.dart — still hardcoded

### Admin Panel (goouts-f16db.web.app)
- [ ] Food delivery orders management screen (Task #77)
- [ ] Enhanced driver management screen (Task #78)
- [ ] Menu moderation screen (Task #79)
- [ ] Transaction monitoring
- [ ] Commission management
- [ ] Report generation
- [ ] Fraud / security control

### Website (www.goouts.co.uk)
- [ ] New section: "Redeem Points Abroad with GoOuts Virtual Card"

### Payment Architecture (blocked on external applications)
- [ ] Stripe Issuing application — NOT applied
- [ ] TrueLayer Open Banking VRP — NOT applied
- [ ] JIT webhook backend — NOT built
- [ ] Barclays Corporate account — NOT set up

### Training Manual (BIG JOB)
- [ ] Admin Panel Training Manual — full written guide for backend support staff covering every section: User Management, Driver Management, Partner Management, VAT Management, Food Orders, Support Tickets, Broadcast, Platform Settings, Campaign Pricing, Credit Sales Ledger, FAQ/Content Pages, Food Image Library
- [ ] Should include: how to use each screen, what each field means, step-by-step workflows (e.g. how to approve a merchant, how to issue credits, how to export VAT CSV, how to handle a refund)
- [ ] Format: likely Word .docx or PDF — professional, GoOuts branded
- [ ] Audience: non-technical backend/ops staff and support team

### Compliance / Legal (before go-live)
- [ ] T&C Part 14 (TSP clause) → Firestore
- [ ] Privacy Policy → Firestore
- [ ] FCA TSP legal opinion (~£2–3k)

---

## Key File Paths (quick reference)
| App | Path |
|---|---|
| Merchant Portal | C:\Users\Maz\goouts\merchants_panel\ |
| Admin Panel | C:\Users\Maz\goouts\admin_panel\ |
| Merchant Terminal | C:\Users\Maz\goouts\merchant_terminal\ |
| Consumer App | C:\Users\Maz\goouts_app\ |
| Driver App | C:\Users\Maz\goouts\driver_app\ |
| Cloud Functions | C:\Users\Maz\goouts\admin_panel\functions\index.js |
| Website | C:\Users\Maz\goouts\goouts_website\public\index.html |

## Live URLs
| Site | URL |
|---|---|
| Admin Panel | https://goouts-f16db.web.app |
| Merchant Portal | https://goouts-merchants.web.app |
| Website | https://www.goouts.co.uk |
