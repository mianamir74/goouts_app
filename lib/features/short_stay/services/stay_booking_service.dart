import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/money.dart';
import '../models/stay_booking.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bookings. READS are direct Firestore. Every WRITE is a Cloud Function.
//
// There is no createBooking that touches Firestore from here, and there never
// should be. Two guests can book the same nights within milliseconds. The
// server reads blocked_dates and writes both the booking and the blocked
// nights inside ONE transaction. A client cannot do that, and a client that
// could write a booking could also write its own price.
//
// ── REWRITTEN 4 AUGUST 2026, AND WHY ────────────────────────────────────────
//
// This file described a backend that did not exist. Every one of these was
// wrong, and none of it would have failed until a device ran it:
//
//   * region was 'us-central1'. Every deployed function is europe-west1, so
//     every call failed with NOT_FOUND. Third file with this same bug.
//   * quote() called `quoteStayBooking`. The function is `getStayQuote`.
//   * StayQuote.fromWire read flat fields (nightlyRate, total, depositHold,
//     cancellationSummary). getStayQuote returns pricing nested, plus
//     depositPence and a structured cancellation object. Every figure would
//     have parsed as zero — and Pence.fromFirestore returns Pence(0) on
//     anything it does not recognise, so a checkout screen would have shown
//     a confident, well formatted £0.00 rather than an error.
//   * four functions did not exist AT ALL: quoteStayCancellation,
//     cancelStayBooking, quoteStayAmendment, amendStayBooking. They were kept
//     below, clearly marked, because deleting them would silently remove
//     features from screens that already call them.
//
//     WRITTEN 16 August 2026 in admin_panel/functions/stay_booking.js and
//     exported from index.js. This note stays because the reason those methods
//     survived as stubs is the reason they could be filled in later.
//
// WHAT IS LIVE:   getStayQuote, createStayBooking, listBlockedNights
// WHAT IS WRITTEN BUT NEEDS DEPLOYING:
//                 quoteStayCancellation, cancelStayBooking,
//                 quoteStayAmendment, amendStayBooking
//
// ⚠ "Written" is not "deployed". Until `firebase deploy --only functions` has
//    run, the four above return NOT_FOUND on a device and the analyzer stays
//    green throughout — which is exactly how listBlockedNights was missed.
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when a screen calls something the backend does not implement yet.
///
/// Exists so the failure says what is actually wrong. Without it the screen
/// gets a raw `NOT_FOUND` from Firebase and the likeliest conclusion is a
/// network problem, which sends the next person debugging in the wrong
/// direction entirely.
class StayFeatureNotBuilt implements Exception {
  final String function;
  final String whatItNeeds;
  const StayFeatureNotBuilt(this.function, this.whatItNeeds);
  @override
  String toString() =>
      'Short Stay: $function is not built yet. $whatItNeeds';
}

class StayQuote {
  final Pence nightlyRate;
  final int nights;
  final Pence accommodationTotal;
  final Pence cleaningFee;
  final Pence serviceFee;
  final Pence total;
  final Pence hostPayout;
  final Pence depositHold;

  /// What the guest earns back. Partner credit, not cash, credited at
  /// check-out. The server decides the rate — the app has no access to it,
  /// because platform_config is admin-only in the security rules.
  final Pence cashback;
  final double cashbackPct;
  final String cashbackNote;
  final bool isPlus;

  /// FALSE means at least one night is already taken. The checkout screen must
  /// not offer a Confirm button in that case.
  final bool available;
  final List<String> unavailableNights;

  final String cancellationPolicy;
  final DateTime? fullRefundUntil;
  final int partialRefundPct;
  final DateTime? graceUntil;

  /// Whether the checkout may offer to take a payment at all.
  ///
  /// This used to be documented as "always false today", and the checkout
  /// screen was built around that. It now follows platform_config paymentMode
  /// server side, so it is true in demo and in stripe, false in none.
  final bool paymentAvailable;

  /// none | demo | stripe. THE thing the screen must key its wording off.
  ///
  /// paymentAvailable says a payment can be taken; this says whether it is
  /// real. Showing "Test mode" is driven by this being 'demo' and by nothing
  /// else, so the label cannot drift away from the behaviour — a screen that
  /// hardcoded the label would keep showing it after Stripe went live, or
  /// worse, stop showing it before.
  final String paymentMode;

  /// Methods the server will accept. Sent by the server rather than listed in
  /// the app, so adding one does not need an app release to match.
  final List<String> paymentMethods;

  bool get isDemoPayment => paymentMode == 'demo';

  const StayQuote({
    required this.nightlyRate,
    required this.nights,
    required this.accommodationTotal,
    required this.cleaningFee,
    required this.serviceFee,
    required this.total,
    required this.hostPayout,
    required this.depositHold,
    required this.cashback,
    required this.cashbackPct,
    required this.cashbackNote,
    required this.isPlus,
    required this.available,
    required this.unavailableNights,
    required this.cancellationPolicy,
    required this.fullRefundUntil,
    required this.partialRefundPct,
    required this.graceUntil,
    required this.paymentAvailable,
    required this.paymentMode,
    required this.paymentMethods,
  });

  /// Callable results arrive as `Map<Object?, Object?>` on Android, so every
  /// nested map is cast rather than assumed. Getting this wrong throws at
  /// runtime on one platform only, which is the worst kind of bug to find.
  static Map<String, dynamic> _sub(dynamic v) =>
      (v as Map?)?.cast<String, dynamic>() ?? const {};

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    // A callable returns a Timestamp as {_seconds, _nanoseconds}, not as a
    // Timestamp object — that conversion only happens on a Firestore read.
    if (v is Map) {
      final s = (v['_seconds'] ?? v['seconds']) as num?;
      if (s != null) {
        return DateTime.fromMillisecondsSinceEpoch(s.toInt() * 1000,
            isUtc: true);
      }
    }
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory StayQuote.fromWire(Map<String, dynamic> m) {
    final p = _sub(m['pricing']);
    final c = _sub(m['cancellation']);
    return StayQuote(
      nightlyRate: Pence.fromFirestore(p['nightlyRate']),
      nights: (p['nights'] as num?)?.toInt() ?? 0,
      accommodationTotal: Pence.fromFirestore(p['accommodationTotal']),
      cleaningFee: Pence.fromFirestore(p['cleaningFee']),
      serviceFee: Pence.fromFirestore(p['serviceFee']),
      total: Pence.fromFirestore(p['total']),
      hostPayout: Pence.fromFirestore(p['hostPayout']),
      depositHold: Pence.fromFirestore(m['depositPence']),
      cashback: Pence.fromFirestore(p['cashbackPence']),
      cashbackPct: (p['cashbackPct'] as num?)?.toDouble() ?? 0,
      cashbackNote: (m['cashbackNote'] ?? '') as String,
      isPlus: m['isPlus'] == true,
      available: m['available'] == true,
      unavailableNights: ((m['unavailableNights'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      cancellationPolicy: (c['policy'] ?? 'moderate') as String,
      fullRefundUntil: _ts(c['fullRefundUntil']),
      partialRefundPct: (c['partialRefundPct'] as num?)?.toInt() ?? 0,
      graceUntil: _ts(c['graceUntil']),
      paymentAvailable: m['paymentAvailable'] == true,
      paymentMode: (m['paymentMode'] ?? 'none') as String,
      // Defaults to empty, NOT to the four methods. An older server that does
      // not send this yet must produce a checkout with no payment section
      // rather than one offering methods it will reject.
      paymentMethods: ((m['paymentMethods'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }

  List<({String label, Pence amount})> get lines => [
        (
          label: '${nightlyRate.compact} x $nights '
              '${nights == 1 ? 'night' : 'nights'}',
          amount: accommodationTotal
        ),
        if (!cleaningFee.isZero) (label: 'Cleaning fee', amount: cleaningFee),
        if (!serviceFee.isZero) (label: 'Service fee', amount: serviceFee),
      ];

  /// One sentence for the checkout screen. Built from the SERVER's dates, not
  /// from the policy name, so it cannot describe terms other than the ones
  /// snapshotted onto the booking.
  String get cancellationSummary {
    final d = fullRefundUntil;
    if (d == null) return 'See the cancellation terms for this property.';
    final day = '${d.day}/${d.month}/${d.year}';
    final tail = partialRefundPct > 0
        ? ' After that, $partialRefundPct% of unspent nights.'
        : ' After that, no refund.';
    return 'Free cancellation until $day.$tail';
  }
}

class StayRefundQuote {
  final Pence refundAmount;
  final Pence nonRefundable;
  final String policyApplied;
  final String explanation;
  const StayRefundQuote({
    required this.refundAmount,
    required this.nonRefundable,
    required this.policyApplied,
    required this.explanation,
  });

  factory StayRefundQuote.fromWire(Map<String, dynamic> m) => StayRefundQuote(
        refundAmount: Pence.fromFirestore(m['refundAmount']),
        nonRefundable: Pence.fromFirestore(m['nonRefundable']),
        policyApplied: (m['policyApplied'] ?? '') as String,
        explanation: (m['explanation'] ?? '') as String,
      );
}

/// The guest-facing cashback terms. No commission, no host payout — those stay
/// on the server. See getStayCashbackRate.
class StayCashbackRate {
  final double pct;
  final bool isPlus;
  final double plusPct;
  final bool partnerCreditOnly;
  final String note;

  const StayCashbackRate({
    required this.pct,
    required this.isPlus,
    required this.plusPct,
    required this.partnerCreditOnly,
    required this.note,
  });

  /// Zero means "not known", and every caller treats it as "show nothing".
  ///
  /// Deliberately NOT a plausible default like 3%. A hardcoded fallback rate
  /// is an advertised figure the server never agreed to, and the guest would
  /// be told they earn something they might not.
  static const StayCashbackRate unknown = StayCashbackRate(
    pct: 0,
    isPlus: false,
    plusPct: 0,
    partnerCreditOnly: true,
    note: '',
  );

  bool get isKnown => pct > 0;

  /// "3%" or "2.5%" — no trailing zero on whole numbers.
  String get label => pct == pct.roundToDouble()
      ? '${pct.toStringAsFixed(0)}%'
      : '${pct.toStringAsFixed(1)}%';

  factory StayCashbackRate.fromWire(Map<String, dynamic> m) =>
      StayCashbackRate(
        pct: (m['pct'] as num?)?.toDouble() ?? 0,
        isPlus: m['isPlus'] == true,
        plusPct: (m['plusPct'] as num?)?.toDouble() ?? 0,
        partnerCreditOnly: m['partnerCreditOnly'] != false,
        note: (m['note'] ?? '') as String,
      );
}

class StayBookingService {
  StayBookingService._();
  static final instance = StayBookingService._();

  final _db = FirebaseFirestore.instance;

  // europe-west1. Every deployed function lives here. This said us-central1,
  // which fails only on a device and only at runtime.
  final _fn = FirebaseFunctions.instanceFor(region: 'europe-west1');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('stay_bookings');

  // ── Reads ────────────────────────────────────────────────────────────────
  Stream<StayBooking?> watch(String bookingId) => _col
      .doc(bookingId)
      .snapshots()
      .map((d) => d.exists ? StayBooking.fromDoc(d) : null);

  Future<StayBooking?> byId(String bookingId) async {
    if (bookingId.isEmpty) return null;
    final d = await _col.doc(bookingId).get();
    return d.exists ? StayBooking.fromDoc(d) : null;
  }

  /// My bookings, newest check in first. Limited, because a frequent traveller
  /// will accumulate hundreds and an unbounded query would read them all.
  Stream<List<StayBooking>> myBookings({int limit = 50}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _col
        .where('guestUid', isEqualTo: uid)
        .orderBy('checkIn', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(StayBooking.fromDoc).toList(growable: false));
  }

  // ── Writes. All server side. ─────────────────────────────────────────────

  /// Price a stay WITHOUT creating anything. Call on every date or guest
  /// change. Never add up the lines on the client to produce a charge.
  ///
  /// The returned `available` flag is a snapshot, not a reservation. Nights can
  /// go between quoting and confirming, which is precisely why
  /// createStayBooking re-checks inside its transaction and can still fail.
  ///
  /// Dates are sent as YYYY-MM-DD, deliberately. Sending a full ISO datetime
  /// makes a night ambiguous across timezones: 2026-08-12T23:00+01:00 is the
  /// 11th in UTC, and the guest would block the wrong night.
  Future<StayQuote> quote({
    required String listingId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required int children,
    required int infants,
  }) async {
    final res = await _fn
        .httpsCallable('getStayQuote')
        .call<Map<String, dynamic>>({
      'listingId': listingId,
      'checkIn': _day(checkIn),
      'checkOut': _day(checkOut),
      'guests': {'adults': adults, 'children': children, 'infants': infants},
    });
    return StayQuote.fromWire(res.data);
  }

  /// Creates the booking. The server does the availability check and the write
  /// in one transaction. Returns the new booking id.
  ///
  /// `idempotencyKey` MUST be generated once when the checkout screen opens and
  /// reused for every retry — not regenerated per tap. Its whole purpose is
  /// that a double tap, or a retry after a dropped connection, returns the
  /// first booking instead of creating a second one and blocking twice the
  /// nights.
  ///
  /// NO PAYMENT IS TAKEN. There is no Stripe integration. A booking is created
  /// as pending with paymentStatus 'not_taken', and the server releases unpaid
  /// bookings after 48 hours.
  Future<({String bookingId, String status, bool duplicate})> create({
    required String listingId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int adults,
    required int children,
    required int infants,
    required String idempotencyKey,
    String? messageToHost,

    /// card | wallet | apple | google, from StayQuote.paymentMethods.
    ///
    /// Ignored by the server when paymentMode is 'none'. Sending a method the
    /// server does not accept is refused rather than quietly treated as a
    /// card — a booking recorded against a payment route that does not exist
    /// is worse than a failed booking.
    String paymentMethod = 'card',
  }) async {
    final res = await _fn
        .httpsCallable('createStayBooking')
        .call<Map<String, dynamic>>({
      'listingId': listingId,
      'checkIn': _day(checkIn),
      'checkOut': _day(checkOut),
      'guests': {'adults': adults, 'children': children, 'infants': infants},
      'idempotencyKey': idempotencyKey,
      'paymentMethod': paymentMethod,
      if (messageToHost != null && messageToHost.isNotEmpty)
        'messageToHost': messageToHost,
    });
    return (
      bookingId: (res.data['bookingId'] ?? '') as String,
      status: (res.data['status'] ?? 'pending') as String,
      duplicate: res.data['duplicate'] == true,
    );
  }

  // blockedNights deliberately does NOT live here. It is on
  // StayAvailabilityService, where the date picker already looks for it. Two
  // copies of the same call is how the two drift — one gets a fix, the other
  // does not, and which one a screen used decides whether it works.

  /// The signed-in guest's cashback rate, for the listing cards.
  ///
  /// Cached for the life of the app process. The rate is platform wide and the
  /// home screen draws a dozen cards from it, so fetching per card would be a
  /// dozen identical callable invocations to render one number.
  ///
  /// On failure it returns [StayCashbackRate.unknown] rather than throwing or
  /// guessing. A card then shows no cashback line at all, which is the correct
  /// failure: an advertised rate the server did not supply is a promise nobody
  /// made.
  StayCashbackRate? _rateCache;

  Future<StayCashbackRate> cashbackRate({bool refresh = false}) async {
    final StayCashbackRate? cached = _rateCache;
    if (cached != null && !refresh) return cached;
    try {
      final res = await _fn
          .httpsCallable('getStayCashbackRate')
          .call<Map<String, dynamic>>({});
      final rate = StayCashbackRate.fromWire(res.data);
      _rateCache = rate;
      return rate;
    } catch (_) {
      return StayCashbackRate.unknown;
    }
  }

  /// A night is a calendar date, never an instant. See `quote`.
  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ───────────────────────────────────────────────────────────────────────────
  //  CANCELLATION AND AMENDMENT
  //
  //  BUILT 16 August 2026. All four of these used to throw StayFeatureNotBuilt
  //  because the Cloud Functions did not exist. They exist now, in
  //  admin_panel/functions/stay_booking.js, and are exported from index.js.
  //
  //  ⚠ THEY MUST BE DEPLOYED. Writing the function is not the same as shipping
  //  it — until `firebase deploy --only functions` has run, every one of these
  //  returns NOT_FOUND on a device and nothing in the analyzer will say so.
  //  That is the same failure listBlockedNights had on 4 August.
  //
  //  ── NO MONEY MOVES ─────────────────────────────────────────────────────────
  //
  //  A refund figure is what the policy WOULD return once payments exist. Every
  //  booking has paymentStatus 'not_taken', so nothing is actually returned
  //  today. The server says so in `explanation`, and screens must show that
  //  text rather than writing their own.
  // ───────────────────────────────────────────────────────────────────────────

  /// What cancelling this booking would refund, without cancelling it.
  ///
  /// Read only, so screen 28 can show the consequence before the guest commits.
  Future<StayRefundQuote> quoteCancellation(String bookingId) async {
    final res = await _fn
        .httpsCallable('quoteStayCancellation')
        .call<Map<String, dynamic>>({'bookingId': bookingId});
    return StayRefundQuote.fromWire(res.data);
  }

  /// Cancels the booking and frees the nights it was holding.
  ///
  /// Safe to retry: the server returns the existing cancellation record rather
  /// than failing if the booking is already cancelled, so a double tap on a
  /// poor connection does not produce an error about something that worked.
  Future<StayRefundQuote> cancel({
    required String bookingId,
    required String reason,
  }) async {
    final res = await _fn
        .httpsCallable('cancelStayBooking')
        .call<Map<String, dynamic>>({
      'bookingId': bookingId,
      'reason': reason,
    });
    // The commit returns the same four fields as the quote, under the server's
    // own names, so the screen can show what was actually applied rather than
    // the figure it happened to be showing a moment earlier.
    final Map<String, dynamic> d = res.data;
    return StayRefundQuote.fromWire(<String, dynamic>{
      'refundAmount': d['refundPence'],
      'nonRefundable': d['nonRefundablePence'],
      'policyApplied': d['policyApplied'],
      'explanation': d['explanation'],
    });
  }

  /// Prices a change of dates or party size. Changes nothing.
  ///
  /// Returns the same shape as [quote] — the server deliberately mirrors
  /// getStayQuote so one parser serves both.
  Future<StayQuote> quoteAmendment({
    required String bookingId,
    DateTime? checkIn,
    DateTime? checkOut,
    int? adults,
    int? children,
    int? infants,
  }) async {
    final res = await _fn
        .httpsCallable('quoteStayAmendment')
        .call<Map<String, dynamic>>({
      'bookingId': bookingId,
      if (checkIn != null) 'checkIn': _day(checkIn),
      if (checkOut != null) 'checkOut': _day(checkOut),
      if (adults != null || children != null || infants != null)
        'guests': <String, dynamic>{
          if (adults != null) 'adults': adults,
          if (children != null) 'children': children,
          if (infants != null) 'infants': infants,
        },
    });
    return StayQuote.fromWire(res.data);
  }

  /// Applies the amendment. Releases the old nights and takes the new ones in
  /// one server transaction.
  ///
  /// Returns whether the booking went back to `pending`. On a request-mode
  /// listing a DATE change needs the host's agreement again — they accepted
  /// particular nights, and moving them without asking would let a guest turn
  /// an accepted weekend into a fortnight. A party-size change does not.
  ///
  /// Screen 27 must warn about this BEFORE the guest confirms, not report it
  /// afterwards.
  Future<({String status, bool returnedToPending, int differencePence})> amend({
    required String bookingId,
    DateTime? checkIn,
    DateTime? checkOut,
    int? adults,
    int? children,
    int? infants,
  }) async {
    final res = await _fn
        .httpsCallable('amendStayBooking')
        .call<Map<String, dynamic>>({
      'bookingId': bookingId,
      if (checkIn != null) 'checkIn': _day(checkIn),
      if (checkOut != null) 'checkOut': _day(checkOut),
      if (adults != null || children != null || infants != null)
        'guests': <String, dynamic>{
          if (adults != null) 'adults': adults,
          if (children != null) 'children': children,
          if (infants != null) 'infants': infants,
        },
    });
    return (
      status: (res.data['status'] ?? 'pending') as String,
      returnedToPending: res.data['returnedToPending'] == true,
      differencePence: (res.data['differencePence'] ?? 0) as int,
    );
  }
}
