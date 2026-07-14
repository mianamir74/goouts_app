# GoOuts — Session Summary June 2026
# Backup Memory File — Saved to goouts_app folder for safety

---

## Payment Architecture — FINALISED

- Model: JIT-VRP V4 confirmed
- BaaS: Stripe Issuing — consumer virtual card only (commercial card dropped)
- Commercial card dropped — FCA/PSR regulatory risk, mis-selling risk
- Consumer interchange 0.20% kept as bonus revenue
- Open Banking: TrueLayer or Yapily — 5p to 11p flat per sweep
- GoOuts = PISP only, no EMI licence needed
- Stripe holds funds, GoOuts never holds customer money
- Wallet = Firebase ledger (number only, real money at Stripe)
- Top-up: Open Banking FPS only, no card top-ups
- All 6 payment scenarios confirmed clean — max one VRP fee ever
- Document: GoOuts_Payment_Architecture_V2.docx

## Smart Routing on JIT Webhook

1. Settle wallet and cashback from Stripe internally — zero cost
2. Sweep remainder from personal bank via VRP — 5p to 11p
3. Maximum one VRP fee per transaction always

## Revenue Model

- Primary: Partner commission 10 to 15 percent per transaction
- Secondary: Consumer interchange 0.20 percent bonus
- Tertiary: GoOuts Plus membership £5 per year
- Card issuance £0.10 covered by first partner visit commission

---

## GoOuts Plus — Full Model

- Free to join always, first year free
- Unlocks when combined family cashback hits £100 (any combination of members)
- At £100: Plus activates, £5 charged via Open Banking, shows in Activity history
- £5 covers whole family group
- Renews annually from activation date
- Cancel any time in 3 taps, full refund within 14 days

## GoOuts Plus Features

- Bonus cashback 1 to 2 percent above standard
- Exclusive member discounts
- Early access to partner offers 24 hours early
- Family cashback dashboard
- Priority support 4 hour response

---

## Family Plan

- Up to 2 family members per group
- Linking: phone number search in app, send link request, accept or decline
- NO invite codes
- Firebase Dynamic Links deprecated August 2025 — do not use
- Each member keeps private wallet, cashback, and history
- Combined cashback from all members counts toward £100

## 3-Touch Milestone

- Touch 1: Slide 4 soft caption (built)
- Touch 2: After first cashback — Family Cashback Intro screen shown (built)
- Touch 3: £100 reached — GoOuts Plus celebration screen (built)

## Family Plan Visibility

- Hidden in Profile until firstCashbackEarned = true
- Shows after first cashback transaction completes
- NOT YET IMPLEMENTED IN CODE — outstanding task

---

## Firebase Structure Needed (NOT YET BUILT)

users collection additions:
  familyGroupId, familyRole, totalCashbackEarned, firstCashbackEarned,
  gooutsPlusMember, gooutsPlusActivatedAt, gooutsPlusRenewalDate, firstYearEnd

familyGroups collection:
  primaryUid, memberUids, combinedCashbackEarned, milestoneReached,
  milestoneReachedAt, plusActivated, plusActivatedAt, plusRenewalDate, maxMembers

familyLinkRequests collection:
  fromUid, fromName, toPhone, toUid, status, createdAt

Cloud Function needed:
  On every cashback write — update combinedCashbackEarned, check milestone,
  notify primary user, trigger celebration screen

---

## Flutter Screens Built

- family_plan_screen.dart (demo data — Firebase not wired yet)
- goouts_plus_unlocked_screen.dart (confetti celebration)
- family_cashback_intro_screen.dart (Stitch screen, fixed and wired)
- slide4_screen.dart (family caption added)
- profile_screen.dart (Family Plan entry added — not yet conditional)
- main.dart (routes: /family-plan, /goouts-plus-unlocked, /family-cashback-intro)

## Documents Produced

- GoOuts_Payment_Architecture_V2.docx
- GoOuts_Terms_Conditions_V3.docx (Part 16 GoOuts Plus)
- GoOuts_FAQ.docx (Q22 to Q34 GoOuts Plus section)
- Stitch asset: assets/images/family_cashback.webp

---

## Outstanding Tasks — Pick Up Here Next Session

1. Implement Firebase familyGroups and familyLinkRequests collections
2. Rebuild family_plan_screen.dart with real Firebase reads
3. Build phone number search and link request flow
4. Build accept or decline UI for receiving member
5. Cloud Function: £100 auto-trigger on every cashback write
6. Make Family Plan row in Profile conditional on firstCashbackEarned
7. Wire GoOuts Plus activation to Stripe £5 charge
8. Wire £5 charge to appear in Activity screen transaction history

---

## Key Lines to Remember

Pitch:
"Earn £100 cashback together as a family, unlock GoOuts Plus —
discounts, bonus cashback, and more — for just £5 a year."

Slide 4 caption:
"The more family you add, the more you earn together. And if you
feel generous, you can always share your cashback with friends
and family too."

---

Saved: June 2026
