import 'package:cloud_firestore/cloud_firestore.dart';
import 'money.dart';
import 'stay_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// A damage claim.  Collection: stay_claims/{claimId}
//
// Client writes NOTHING here. submitStayClaim, respondToStayClaim and
// decideStayClaim are all Cloud Functions, because a claim opens a 72 hour
// window, freezes evidence, and can take money.
//
// BETTERMENT lives in this file as a pure function so that the host claim
// screen and the guest response screen can never show different numbers.
// The schedule itself is NOT hardcoded: it comes from platform_config so
// finance can change it without a release.
// ─────────────────────────────────────────────────────────────────────────────

class StayClaim {
  final String id;
  final String bookingId;
  final String listingId;
  final String hostUid;
  final String guestUid;
  final ClaimStatus status;
  final List<ClaimItem> items;
  final List<String> evidenceRefs;
  final ClaimResponse? guestResponse;
  final ClaimDecision? decision;
  final DateTime? windowClosesAt;
  final DateTime? createdAt;

  const StayClaim({
    required this.id,
    required this.bookingId,
    required this.listingId,
    required this.hostUid,
    required this.guestUid,
    required this.status,
    required this.items,
    required this.evidenceRefs,
    required this.guestResponse,
    required this.decision,
    required this.windowClosesAt,
    required this.createdAt,
  });

  factory StayClaim.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return StayClaim(
      id: doc.id,
      bookingId: (m['bookingId'] ?? '') as String,
      listingId: (m['listingId'] ?? '') as String,
      hostUid: (m['hostUid'] ?? '') as String,
      guestUid: (m['guestUid'] ?? '') as String,
      status: ClaimStatus.from(m['status'] as String?),
      items: ((m['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ClaimItem.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false),
      evidenceRefs: ((m['evidenceRefs'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      guestResponse: m['guestResponse'] == null
          ? null
          : ClaimResponse.fromMap(
              (m['guestResponse'] as Map).cast<String, dynamic>()),
      decision: m['decision'] == null
          ? null
          : ClaimDecision.fromMap(
              (m['decision'] as Map).cast<String, dynamic>()),
      windowClosesAt: (m['windowClosesAt'] as Timestamp?)?.toDate(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Pence get claimedTotal =>
      items.fold<Pence>(Pence.zero, (a, b) => a + b.claimedAmount);
  Pence get payableTotal =>
      items.fold<Pence>(Pence.zero, (a, b) => a + b.payableAmount);

  Duration? get timeToRespond {
    if (windowClosesAt == null) return null;
    final d = windowClosesAt!.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get awaitingGuest => status == ClaimStatus.awaitingGuest;
}

class ClaimItem {
  final String room;
  final String description;
  final Pence itemCost;
  final int itemAgeYears;
  final int expectedLifeYears;
  final Pence claimedAmount;
  final Pence payableAmount;

  const ClaimItem({
    required this.room,
    required this.description,
    required this.itemCost,
    required this.itemAgeYears,
    required this.expectedLifeYears,
    required this.claimedAmount,
    required this.payableAmount,
  });

  factory ClaimItem.fromMap(Map<String, dynamic> m) => ClaimItem(
        room: (m['room'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        itemCost: Pence.fromFirestore(m['itemCost']),
        itemAgeYears: (m['itemAgeYears'] as num?)?.toInt() ?? 0,
        expectedLifeYears: (m['expectedLifeYears'] as num?)?.toInt() ?? 0,
        claimedAmount: Pence.fromFirestore(m['claimedAmount']),
        payableAmount: Pence.fromFirestore(m['payableAmount']),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Betterment. ONE implementation, shared by the host claim screen and the
// guest response screen, so the two can never disagree about a number.
//
//   payable = replacement cost x (remaining life / expected life)
//
// A guest pays for the life that was lost, not for a new item. A seven year
// old carpet with a ten year life had three years left, so a £800 carpet
// pays £240. This is ordinary insurance practice and the market leader does
// the same, which is worth telling a host before they claim rather than after.
// ─────────────────────────────────────────────────────────────────────────────
class Betterment {
  Betterment._();

  static Pence payable({
    required Pence itemCost,
    required int ageYears,
    required int expectedLifeYears,
  }) {
    if (expectedLifeYears <= 0) return itemCost; // no schedule, pay at cost
    final remaining = expectedLifeYears - ageYears;
    if (remaining <= 0) return Pence.zero;       // fully depreciated
    if (remaining >= expectedLifeYears) return itemCost;
    return Pence((itemCost.value * remaining / expectedLifeYears).round());
  }

  /// Plain wording for the screen, so the guest and the host read the same
  /// sentence rather than two different framings of the same rule.
  static String explain({
    required Pence itemCost,
    required int ageYears,
    required int expectedLifeYears,
  }) {
    if (expectedLifeYears <= 0) {
      return 'Small items are paid at cost, with no deduction for age.';
    }
    final remaining = expectedLifeYears - ageYears;
    if (remaining <= 0) {
      return 'This item was already past its expected life of '
          '$expectedLifeYears years, so nothing is payable.';
    }
    final p = payable(
        itemCost: itemCost, ageYears: ageYears, expectedLifeYears: expectedLifeYears);
    return 'This item cost ${itemCost.compact} and is $ageYears years old, '
        'against an expected life of $expectedLifeYears years. '
        '$remaining years of life were lost, so ${p.compact} is payable '
        'rather than the cost of a new one.';
  }
}

class ClaimResponse {
  final String action; // accept | contest
  final String text;
  final DateTime? at;
  const ClaimResponse({required this.action, required this.text, required this.at});

  factory ClaimResponse.fromMap(Map<String, dynamic> m) => ClaimResponse(
        action: (m['action'] ?? '') as String,
        text: (m['text'] ?? '') as String,
        at: (m['at'] as Timestamp?)?.toDate(),
      );

  bool get accepted => action == 'accept';
}

class ClaimDecision {
  final String outcome;
  final Pence amount;
  final String reasoning;
  final List<String> evidenceRelied;
  final DateTime? at;
  const ClaimDecision({
    required this.outcome,
    required this.amount,
    required this.reasoning,
    required this.evidenceRelied,
    required this.at,
  });

  factory ClaimDecision.fromMap(Map<String, dynamic> m) => ClaimDecision(
        outcome: (m['outcome'] ?? '') as String,
        amount: Pence.fromFirestore(m['amount']),
        reasoning: (m['reasoning'] ?? '') as String,
        evidenceRelied: ((m['evidenceRelied'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        at: (m['at'] as Timestamp?)?.toDate(),
      );
}
