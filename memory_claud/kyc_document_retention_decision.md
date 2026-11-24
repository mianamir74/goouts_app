# KYC documents — GoOuts NEVER retains originals

**FINAL DECISION, 24 August 2026. This supersedes everything earlier in this file's
history, including the 5-year AML retention position recorded earlier the same day.**

---

## THE RULE

**GoOuts does not hold original identity documents in any capacity.**

Not in Firebase Storage, not archived, not "temporarily" beyond the seconds it takes to
hand them to Stripe. A passport or driving licence image exists on GoOuts
infrastructure only in transit.

> User, 24 August 2026: *"forget about AML 5 YEars we cannot hold orignal document in
> any capacity as TSP, so this is the best method as cashback company"*

---

## WHY — AND WHY THE EARLIER 5-YEAR POSITION WAS WRONG FOR US

The Money Laundering Regulations compel **the regulated firm** to retain Customer Due
Diligence records for five years. The whole question is who the regulated firm is.

Under the V8 Hybrid architecture it is **not GoOuts**:

- GoOuts is a **Technical Service Provider**, outside the regulated flow.
- **Stripe is the EMI.** Stripe performs the KYC and holds the CDD obligation.
- Consumers are **Stripe Issuing cardholders**, not GoOuts' regulated customers.
- Hosts, drivers and merchants are **Stripe Connect accounts**, same logic.

So GoOuts has no MLR duty — and therefore **no Article 6(1)(c) legal obligation** to
point at as a lawful basis. Without it, retention would have to rest on Article 6(1)(f)
legitimate interest, which requires proving that a less intrusive method would not work.
A less intrusive method demonstrably *does* work: let Stripe hold the document and keep
a reference to it. That argument cannot be won, so it should not be attempted.

⚠ **Holding documents we have no basis to hold is the risk, not deleting them.** The
earlier note had this backwards because it assumed GoOuts carried the CDD duty.

This is also what keeps TSP status clean — the "never let a passport touch your Firebase
Storage" rule.

---

## THE METHOD — DESTROY ON CONFIRMATION, NOT ON A TIMER

Rejected: the "ephemeral pipeline" that shreds after ~60 seconds regardless of outcome.
It destroys documents for verifications that Stripe has asked the user to resubmit.

The agreed method:

1. Document uploads to a **temporary** Storage path, never the permanent `kyc/{uid}/`.
2. It is passed to Stripe.
3. Stripe reports a verification outcome by webhook.
4. On a **TERMINAL** outcome only — verified or cancelled, never "processing" or
   "requires input" — GoOuts destroys its copy.
5. GoOuts retains: the extracted text fields, the **Stripe verification reference**, the
   outcome, and an audit entry. The reference is the receipt that proves the check
   happened.

### ⚠ FOUR THINGS THAT DECIDE WHETHER IT IS SAFE

**Terminal states only.** Deleting on "requires input" destroys the document the user
still needs to complete their verification.

**Assume the webhook is lost.** Webhooks go missing. If deletion only ever happens when
one arrives, a single dropped message leaves a passport in the bucket permanently — the
exact outcome this design exists to prevent. A scheduled sweep must find old temporary
documents, ask Stripe directly what happened, and clean up. **The webhook is the fast
path; the sweep is the guarantee.**

**A bucket lifecycle rule on the temporary prefix is the last line.** Code that crashes
or times out never reaches its cleanup block. The lifecycle rule is the only mechanism
that survives the code failing.

**Every purge is logged.** A document deleted with no record is indistinguishable from
one never held — and from one that leaked. Purge entries go to `/kyc_audit_log`, which
is already append-only, admin-read, nobody-write.

**Webhook signatures must be verified.** An endpoint that deletes documents is an
endpoint worth attacking.

---

## ⚠ STATUS: BLOCKED ON STRIPE, BY DESIGN

Checked 24 August 2026: `admin_panel/functions/package.json` depends on
`firebase-admin` and `firebase-functions` **and nothing else**. There is no Stripe SDK
anywhere in the backend.

The trigger for this entire mechanism is a Stripe webhook, so it cannot be tested until
Stripe is connected. **Do not ship a deletion path guarding passports that has never
fired once.** This belongs in the Stripe integration work.

### Ready-able beforehand
- A field to hold the Stripe verification reference on the user/host/driver record
- The admin review sheet handling a purged document without an empty preview card
- `/kyc_audit_log` accepting a purge entry type

### Consequence to design for
The admin currently reviews the passport image. Afterwards they see extracted fields,
Stripe's verdict and the audit trail — **no picture**. The `_DocumentPreviewCard`s in
`admin_dashboard._showHostDetail` would sit empty. Design it, do not discover it.

---

## OPEN — NOT YET DECIDED
- Rejected or abandoned verifications: same immediate destruction (assumed yes, since
  there is even less basis to hold those).
- Whether host / driver / merchant documents follow the identical path. They are Connect
  accounts rather than Issuing cardholders, but the TSP logic is the same.

---

## RELATED
- `goouts_app/GoOuts_Sponsor_Brief_V8_Hybrid_Updated.PDF` — the TSP / EMI split
- Task #22 — T&C gaps: **Stripe is named ZERO times** in either terms file, and the host
  terms still list "Identity Documents (Passport / Driving Licence)" as data collected.
  Both must be corrected before this ships.
- `admin_panel/functions/kyc_audit.js` — the audit trail this writes to
