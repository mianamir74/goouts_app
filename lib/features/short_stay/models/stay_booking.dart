import 'package:cloud_firestore/cloud_firestore.dart';
import 'money.dart';
import 'stay_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// A booking.  Collection: stay_bookings/{bookingId}
//
// NOTHING IN THIS FILE MAY BE WRITTEN BY A CLIENT.
//
// There is no toMap and that is deliberate. Every booking is created and
// modified by a Cloud Function, inside a transaction, because two guests can
// book the same nights within milliseconds of each other. A client that could
// write a booking could also write its own price.
//
// The security rules enforce this. This model is read only by construction so
// the rule and the code agree.
// ─────────────────────────────────────────────────────────────────────────────

class StayBooking {
  final String id;
  final String listingId;
  final String hostUid;
  final String guestUid;

  final DateTime checkIn;
  final DateTime checkOut;
  final int nights;
  final StayGuests guests;
  final BookingStatus status;

  final StayPricing pricing;
  final StayDeposit? deposit;
  final StayCaptureState capture;
  final StayCancellation? cancellation;
  final String? claimId;

  // ── ADDED 17 August 2026 ─────────────────────────────────────────────────
  //
  // createStayBooking has written these since the demo payment seam went in,
  // and this model did not read them. The booking details screen needed to
  // show whether a stay was paid for and could not ask — so it would have had
  // to guess, which is how the Stitch version ended up showing a green PAID
  // badge to everybody.
  //
  // Server writes, client reads. Never set from the app.

  /// not_taken | demo_paid | whatever a real integration writes later.
  final String paymentStatus;

  /// What was actually settled. Zero when paymentStatus is not_taken.
  final Pence paidPence;

  /// The two pots that make up paidPence. Always sum to it.
  ///
  /// Stored separately because a refund goes back to where the money came
  /// from — £31 of cashback returns to the wallet and £238 returns to the
  /// card. A single combined figure could not tell them apart, and refunding
  /// cash for cashback is a real loss.
  final Pence paidFromWallet;
  final Pence paidFromCard;

  /// card | wallet | apple | google, or null when nothing was taken.
  final String? paymentMethod;

  /// none | demo | stripe — the mode in force WHEN THIS BOOKING WAS MADE.
  /// Stored per booking so a demo one can never be mistaken for a real one
  /// after Stripe goes live.
  final String paymentMode;

  /// Set by creditStayCashbackOnce when the guest completes check-out. False
  /// until then, and false forever on a stay that was never paid for.
  final bool cashbackAwarded;

  const StayBooking({
    required this.id,
    required this.listingId,
    required this.hostUid,
    required this.guestUid,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    required this.guests,
    required this.status,
    required this.pricing,
    required this.deposit,
    required this.capture,
    required this.cancellation,
    required this.paymentStatus,
    required this.paidPence,
    required this.paidFromWallet,
    required this.paidFromCard,
    required this.paymentMethod,
    required this.paymentMode,
    required this.cashbackAwarded,
    required this.claimId,
  });

  factory StayBooking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      StayBooking.fromMap(doc.id, doc.data() ?? const {});

  factory StayBooking.fromMap(String id, Map<String, dynamic> m) {
    final ci = (m['checkIn'] as Timestamp?)?.toDate() ?? DateTime.now();
    final co = (m['checkOut'] as Timestamp?)?.toDate() ??
        DateTime.now().add(const Duration(days: 1));
    return StayBooking(
      id: id,
      listingId: (m['listingId'] ?? '') as String,
      hostUid: (m['hostUid'] ?? '') as String,
      guestUid: (m['guestUid'] ?? '') as String,
      checkIn: ci,
      checkOut: co,
      nights: (m['nights'] as num?)?.toInt() ?? co.difference(ci).inDays,
      guests: StayGuests.fromMap((m['guests'] as Map?)?.cast<String, dynamic>()),
      status: BookingStatus.from(m['status'] as String?),
      pricing:
          StayPricing.fromMap((m['pricing'] as Map?)?.cast<String, dynamic>()),
      deposit: m['depositPreAuth'] == null
          ? null
          : StayDeposit.fromMap(
              (m['depositPreAuth'] as Map).cast<String, dynamic>()),
      capture: StayCaptureState.fromMap(
          (m['capture'] as Map?)?.cast<String, dynamic>()),
      cancellation: m['cancellation'] == null
          ? null
          : StayCancellation.fromMap(
              (m['cancellation'] as Map).cast<String, dynamic>()),
      claimId: m['claimId'] as String?,
      // Defaults describe a booking nothing was taken for, which is the
      // correct reading of a document written before these fields existed.
      paymentStatus: (m['paymentStatus'] ?? 'not_taken') as String,
      paidPence: Pence.fromFirestore(m['paidPence']),
      paidFromWallet: Pence.fromFirestore(m['paidFromWalletPence']),
      paidFromCard: Pence.fromFirestore(m['paidFromCardPence']),
      paymentMethod: m['paymentMethod'] as String?,
      paymentMode: (m['paymentMode'] ?? 'none') as String,
      cashbackAwarded: m['cashbackAwarded'] == true,
    );
  }

  // ── Derived state. Drives which card the trip screen shows. ───────────────
  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get isUpcoming => checkIn.isAfter(_today);
  bool get isStaying =>
      !checkIn.isAfter(_today) && checkOut.isAfter(_today);
  bool get isPast => !checkOut.isAfter(_today);

  int get daysUntilCheckIn => checkIn.difference(_today).inDays;

  /// The 72 hour window in which a host may claim, from checkout.
  DateTime get claimWindowCloses => checkOut.add(const Duration(hours: 72));
  bool get claimWindowOpen => DateTime.now().isBefore(claimWindowCloses);

  bool get needsCheckInCapture =>
      (isStaying || daysUntilCheckIn == 0) && !capture.guestCheckIn.isComplete;
  bool get needsCheckOutCapture =>
      isStaying && !capture.guestCheckOut.isComplete;

  bool get canCancel => status.guestCanCancel && isUpcoming;
}

class StayGuests {
  final int adults;
  final int children;
  final int infants;
  const StayGuests(
      {required this.adults, required this.children, required this.infants});

  factory StayGuests.fromMap(Map<String, dynamic>? m) => StayGuests(
        adults: (m?['adults'] as num?)?.toInt() ?? 1,
        children: (m?['children'] as num?)?.toInt() ?? 0,
        infants: (m?['infants'] as num?)?.toInt() ?? 0,
      );

  /// Infants do not count towards a property's maximum occupancy.
  int get countedTotal => adults + children;

  String get label {
    final parts = <String>[
      '$adults ${adults == 1 ? 'adult' : 'adults'}',
      if (children > 0) '$children ${children == 1 ? 'child' : 'children'}',
      if (infants > 0) '$infants ${infants == 1 ? 'infant' : 'infants'}',
    ];
    return parts.join(', ');
  }
}

class StayPricing {
  final Pence nightlyRate;
  final int nights;
  final Pence accommodationTotal;
  final Pence cleaningFee;
  final Pence serviceFee;
  final Pence total;
  final Pence hostPayout;
  final Pence platformCommission;

  const StayPricing({
    required this.nightlyRate,
    required this.nights,
    required this.accommodationTotal,
    required this.cleaningFee,
    required this.serviceFee,
    required this.total,
    required this.hostPayout,
    required this.platformCommission,
  });

  factory StayPricing.fromMap(Map<String, dynamic>? m) => StayPricing(
        nightlyRate: Pence.fromFirestore(m?['nightlyRate']),
        nights: (m?['nights'] as num?)?.toInt() ?? 0,
        accommodationTotal: Pence.fromFirestore(m?['accommodationTotal']),
        cleaningFee: Pence.fromFirestore(m?['cleaningFee']),
        serviceFee: Pence.fromFirestore(m?['serviceFee']),
        total: Pence.fromFirestore(m?['total']),
        hostPayout: Pence.fromFirestore(m?['hostPayout']),
        platformCommission: Pence.fromFirestore(m?['platformCommission']),
      );

  /// Lines for the checkout breakdown. The server total is authoritative; this
  /// is display only and must never be summed to produce the charge.
  List<({String label, Pence amount})> get lines => [
        (
          label: '${nightlyRate.compact} x $nights '
              '${nights == 1 ? 'night' : 'nights'}',
          amount: accommodationTotal
        ),
        if (!cleaningFee.isZero) (label: 'Cleaning fee', amount: cleaningFee),
        if (!serviceFee.isZero) (label: 'Service fee', amount: serviceFee),
      ];
}

class StayDeposit {
  final Pence amount;
  final String status;
  final String? providerRef;
  final DateTime? expiresAt;
  const StayDeposit({
    required this.amount,
    required this.status,
    required this.providerRef,
    required this.expiresAt,
  });

  factory StayDeposit.fromMap(Map<String, dynamic> m) => StayDeposit(
        amount: Pence.fromFirestore(m['amount']),
        status: (m['status'] ?? 'none') as String,
        providerRef: m['providerRef'] as String?,
        expiresAt: (m['expiresAt'] as Timestamp?)?.toDate(),
      );

  /// A pre authorisation, never a held payment. No money moves unless a claim
  /// is decided. Wording matters here, so it is defined once.
  String get explainer =>
      'A hold of ${amount.compact} is placed on your card. '
      'No money is taken, and the hold is released if nothing is claimed.';
}

class StayCaptureState {
  final CapturePhase hostPreArrival;
  final CapturePhase guestCheckIn;
  final CapturePhase guestCheckOut;
  const StayCaptureState({
    required this.hostPreArrival,
    required this.guestCheckIn,
    required this.guestCheckOut,
  });

  factory StayCaptureState.fromMap(Map<String, dynamic>? m) => StayCaptureState(
        hostPreArrival: CapturePhase.fromMap(
            (m?['hostPreArrival'] as Map?)?.cast<String, dynamic>()),
        guestCheckIn: CapturePhase.fromMap(
            (m?['guestCheckIn'] as Map?)?.cast<String, dynamic>()),
        guestCheckOut: CapturePhase.fromMap(
            (m?['guestCheckOut'] as Map?)?.cast<String, dynamic>()),
      );

  CapturePhase forKind(CaptureKind k) => switch (k) {
        CaptureKind.hostPreArrival => hostPreArrival,
        CaptureKind.guestCheckIn => guestCheckIn,
        CaptureKind.guestCheckOut => guestCheckOut,
      };
}

class CapturePhase {
  final String status;
  final DateTime? completedAt;
  final List<String> roomsDone;
  final List<String> roomsSkipped;
  const CapturePhase({
    required this.status,
    required this.completedAt,
    required this.roomsDone,
    required this.roomsSkipped,
  });

  factory CapturePhase.fromMap(Map<String, dynamic>? m) => CapturePhase(
        status: (m?['status'] ?? 'not_started') as String,
        completedAt: (m?['completedAt'] as Timestamp?)?.toDate(),
        roomsDone: ((m?['roomsDone'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        roomsSkipped: ((m?['roomsSkipped'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );

  bool get isComplete => status == 'complete';

  /// A room that was skipped counts as addressed for progress, but the skip is
  /// recorded and counts against whoever skipped it if there is ever a claim.
  int addressedCount() => roomsDone.length + roomsSkipped.length;

  bool isDone(String room) => roomsDone.contains(room);
  bool isSkipped(String room) => roomsSkipped.contains(room);
}

class StayCancellation {
  final String by;
  final DateTime? at;
  final String reason;
  final Pence refundAmount;
  final Pence nonRefundable;

  /// Where the refund went. toWallet has already moved; toCard is recorded
  /// and waits for a card integration. See refundStatus on the document.
  final Pence refundToWallet;
  final Pence refundToCard;

  final String policyApplied;

  /// The server's own sentence explaining the figure. Shown verbatim so the
  /// screen cannot describe the refund differently from the function that
  /// calculated it.
  final String explanation;

  const StayCancellation({
    required this.by,
    required this.at,
    required this.reason,
    required this.refundAmount,
    required this.nonRefundable,
    required this.refundToWallet,
    required this.refundToCard,
    required this.policyApplied,
    required this.explanation,
  });

  // ⚠ refundPence FIRST, refundAmount SECOND.
  //
  // FIXED 17 August 2026. This read m['refundAmount']. cancelStayBooking —
  // written the day before — stores the figure as `refundPence`:
  //
  //     cancellation: { refundPence, nonRefundablePence, policyApplied, ... }
  //
  // So every cancellation would have parsed as Pence(0), because
  // Pence.fromFirestore returns zero for anything it does not recognise. The
  // screen would then have shown a confident, well formatted £0.00 refund to a
  // guest owed £269 — the exact failure this file's own service header warns
  // about, and I wrote both halves a day apart without checking one against
  // the other.
  //
  // refundAmount is kept as a fallback in case any document was written under
  // the old name. The server name wins.
  factory StayCancellation.fromMap(Map<String, dynamic> m) => StayCancellation(
        by: (m['by'] ?? '') as String,
        at: (m['at'] as Timestamp?)?.toDate(),
        reason: (m['reason'] ?? '') as String,
        refundAmount:
            Pence.fromFirestore(m['refundPence'] ?? m['refundAmount']),
        nonRefundable: Pence.fromFirestore(m['nonRefundablePence']),
        refundToWallet: Pence.fromFirestore(m['refundToWalletPence']),
        refundToCard: Pence.fromFirestore(m['refundToCardPence']),
        policyApplied: (m['policyApplied'] ?? '') as String,
        explanation: (m['explanation'] ?? '') as String,
      );

  bool get byHost => by == 'host';
}
