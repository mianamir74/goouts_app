// The one date-of-birth input formatter.
//
// ── WHY THIS FILE EXISTS ─────────────────────────────────────────────────
//
// 14 August 2026, reported as: "in Profile > Identity verification, typing the
// date of birth does not move on by itself like it does on the registration
// screen".
//
// It was not a bug in the KYC screen so much as an absence. create_profile_
// expanded_screen had a private _formatDobInput that inserts the separators as
// you type; kyc_screen builds its fields through a generic _inputField helper
// that takes no onChanged, so the same field on that screen had no formatter at
// all. Two screens asking for the same thing, one of them helpful.
//
// Rather than copy the private method across — which is how unreadByUser /
// unreadByDriver and kycStatus / status both started — it lives here once and
// both screens call it.
//
// ── WHAT IT DOES ─────────────────────────────────────────────────────────
//
// Strips everything that is not a digit, then rebuilds the string inserting
// " / " after the day and after the month:
//
//   "1"        -> "1"
//   "12"       -> "12"
//   "123"      -> "12 / 3"
//   "12031990" -> "12 / 03 / 1990"
//
// Capped at eight digits, so a stray keypress cannot run past the year.
//
// ── WHY IT REBUILDS RATHER THAN INSERTS ──────────────────────────────────
//
// Because deleting has to work too. Inserting a separator on the way forward
// and leaving it there means backspace hits " / " and appears to do nothing —
// the user presses it three times to remove one digit. Rebuilding from the
// digits alone makes deletion behave exactly like typing, in reverse.
library;

/// Formats raw keyboard input as `DD / MM / YYYY` while it is being typed.
String formatDobInput(String raw) {
  final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  final StringBuffer buf = StringBuffer();
  for (int i = 0; i < digits.length && i < 8; i++) {
    if (i == 2 || i == 4) buf.write(' / ');
    buf.write(digits[i]);
  }
  return buf.toString();
}
