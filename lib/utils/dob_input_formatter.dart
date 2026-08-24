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

/// The age at which the financial features may be used.
///
/// The consumer Terms say "at least 16 years of age (18 for financial
/// features)". Identity verification exists to issue a card, so it is the
/// second number that applies here, not the first.
const int kMinimumFinancialAge = 18;

/// Checks a date of birth typed as `DD / MM / YYYY`.
///
/// Returns null when it is acceptable, otherwise the message to show.
///
/// ── ⚠ WHY THIS EXISTS ────────────────────────────────────────────────────
///
/// 24 August 2026. A real submission went all the way through KYC — passport,
/// selfie, liveness, every on-device check green — carrying the date of birth
/// "01 / 06 / 974". A three digit year.
///
/// Both screens validated this field with `if (v == null || v.isEmpty)`. That
/// is not a date check; it is a presence check wearing a date check's coat.
/// The typing formatter above stops you exceeding eight digits but is
/// perfectly happy with seven, because its job is formatting and it was never
/// asked whether the date was finished.
///
/// ⚠ THIS IS THE FIELD STRIPE NEEDS. A cardholder is created from name, date
/// of birth and address; a malformed date fails at the point of issuing a card
/// or, worse, silently widens a sanctions-screening match. It is also the one
/// field on the form the person cannot correct later without a support ticket.
///
/// ⚠ LIVES HERE, BESIDE THE FORMATTER, ON PURPOSE. The two belong to the same
/// fact. Putting the validator in one screen is how the formatter came to be
/// missing from the other one in the first place — see the header.
String? validateDob(String? raw) {
  final String digits = (raw ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.isEmpty) return 'Required';
  if (digits.length < 8) return 'Enter the full date, as DD / MM / YYYY';

  final int day = int.parse(digits.substring(0, 2));
  final int month = int.parse(digits.substring(2, 4));
  final int year = int.parse(digits.substring(4, 8));

  if (month < 1 || month > 12) return 'That month does not exist';
  if (day < 1 || day > 31) return 'That day does not exist';

  // ⚠ DateTime DOES NOT THROW ON 31 FEBRUARY. DateTime(2001, 2, 31) quietly
  // rolls forward to 3 March, so constructing it proves nothing. Reading the
  // parts back is the only way to know the date stored is the date typed.
  final DateTime parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return 'That date does not exist';
  }

  final DateTime now = DateTime.now();
  if (parsed.isAfter(now)) return 'That date is in the future';

  // Whole years only, and the birthday has to have happened. now.year - year
  // on its own makes somebody 18 for the months before their eighteenth
  // birthday.
  int age = now.year - year;
  if (now.month < month || (now.month == month && now.day < day)) age--;

  if (age < kMinimumFinancialAge) {
    return 'You must be $kMinimumFinancialAge or over to verify your identity';
  }
  // Not a real limit, a typo guard — a mistyped year usually lands centuries
  // out, and this catches it while the person is still on the field.
  if (age > 120) return 'Please check the year';

  return null;
}
