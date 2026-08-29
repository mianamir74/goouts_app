// ─────────────────────────────────────────────────────────────────────────────
//  Damage claims — the guest's side.
//
//  Written 25 August 2026, with functions/stay_claims.js and the host's
//  host_claims_service.dart.
//
//  ── ⚠ WHY THE GUEST SIDE IS NOT OPTIONAL ────────────────────────────────────
//
//  This app has told guests, since Short Stay shipped, that a damage claim may
//  be made against them and that their arrival photographs are their evidence —
//  on the checkout screen, twice on the confirmation screen, on the trip detail
//  screen and on the capture intro.
//
//  Until today no host could make a claim, so the promise was harmless. Now one
//  can. A claim the other party cannot answer is not a process, it is a debit
//  with a covering letter — so this file ships in the same change as the host's
//  claim form, not after it.
//
//  ── WHAT THE GUEST CAN AND CANNOT DO ────────────────────────────────────────
//
//    see      the claim, the amount, the host's photographs, and the arrival
//             photographs frozen to it — the same record an admin will read
//    accept   agrees the damage happened. Does NOT settle anything by itself.
//    dispute  with a reason, which is required. See the note in
//             respondToStayClaim: a bare "disputed" against a host's four
//             paragraphs loses on the page even when it is right.
//    nothing  else. The guest cannot edit, withdraw or decide a claim, and
//             neither can the host.
//
//  ⚠ REPLYING LATE STILL WORKS. respondToStayClaim deliberately does not check
//  respondBy. The window stops a claim stalling for ever; it is not there to
//  strip somebody of a reply because they were somewhere without signal.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String kStayClaimsCollection = 'stay_claims';

/// ⚠ MIRRORS OPEN_STATES + "decided" IN stay_claims.js. A state this app does
/// not recognise renders as nothing, which is how a guest ends up believing a
/// claim disappeared.
enum GuestClaimStatus { awaitingYou, accepted, disputed, decided, unknown }

GuestClaimStatus guestClaimStatusFrom(String? wire) {
  switch ((wire ?? '').trim()) {
    case 'awaiting_guest':
      return GuestClaimStatus.awaitingYou;
    case 'accepted':
      return GuestClaimStatus.accepted;
    case 'disputed':
      return GuestClaimStatus.disputed;
    case 'decided':
      return GuestClaimStatus.decided;
    default:
      return GuestClaimStatus.unknown;
  }
}

/// One frozen evidence photograph, as it stood when the claim was opened.
class ClaimEvidence {
  const ClaimEvidence({
    required this.room,
    required this.kind,
    required this.url,
    required this.takenAt,
    required this.skipped,
    required this.skipReason,
  });

  final String room;

  /// arrival | departure — CaptureKind.wire
  final String kind;
  final String url;
  final DateTime? takenAt;
  final bool skipped;
  final String? skipReason;

  factory ClaimEvidence.fromMap(Map<dynamic, dynamic> m) => ClaimEvidence(
        room: (m['room'] ?? '').toString(),
        kind: (m['kind'] ?? '').toString(),
        url: (m['url'] ?? '').toString(),
        takenAt: (m['takenAt'] as Timestamp?)?.toDate(),
        skipped: m['skipped'] == true,
        skipReason: m['skipReason'] as String?,
      );
}

class StayClaim {
  const StayClaim({
    required this.id,
    required this.bookingId,
    required this.status,
    required this.amountPence,
    required this.awardedPence,
    required this.depositCapPence,
    required this.description,
    required this.hostPhotoUrls,
    required this.evidence,
    required this.openedAt,
    required this.respondBy,
    required this.guestResponse,
    required this.guestResponseNote,
    required this.decision,
    required this.decisionReason,
  });

  final String id;
  final String bookingId;
  final GuestClaimStatus status;
  final int amountPence;
  final int awardedPence;
  final int depositCapPence;
  final String description;
  final List<String> hostPhotoUrls;
  final List<ClaimEvidence> evidence;
  final DateTime? openedAt;
  final DateTime? respondBy;
  final String? guestResponse;
  final String? guestResponseNote;
  final String? decision;
  final String? decisionReason;

  factory StayClaim.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final Map<String, dynamic> m = d.data() ?? const <String, dynamic>{};
    return StayClaim(
      id: d.id,
      bookingId: (m['bookingId'] ?? '') as String,
      status: guestClaimStatusFrom(m['status'] as String?),
      amountPence: (m['amountPence'] as num?)?.toInt() ?? 0,
      awardedPence: (m['awardedPence'] as num?)?.toInt() ?? 0,
      depositCapPence: (m['depositCapPence'] as num?)?.toInt() ?? 0,
      description: (m['description'] ?? '') as String,
      hostPhotoUrls:
          ((m['hostPhotoUrls'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(growable: false),
      evidence: ((m['evidenceSnapshot'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<dynamic, dynamic>>()
          .map(ClaimEvidence.fromMap)
          .toList(growable: false),
      openedAt: (m['openedAt'] as Timestamp?)?.toDate(),
      respondBy: (m['respondBy'] as Timestamp?)?.toDate(),
      guestResponse: m['guestResponse'] as String?,
      guestResponseNote: m['guestResponseNote'] as String?,
      decision: m['decision'] as String?,
      decisionReason: m['decisionReason'] as String?,
    );
  }

  double get amount => amountPence / 100.0;
  double get awarded => awardedPence / 100.0;
  bool get needsReply => status == GuestClaimStatus.awaitingYou;

  /// How long is left, or null when there is no deadline to show.
  ///
  /// ⚠ MAY BE NEGATIVE, AND THE SCREEN MUST NOT HIDE THAT. Being past the
  /// deadline does not close the door — respondToStayClaim still accepts a late
  /// reply — but telling somebody they have "0 hours" when they can still
  /// answer would stop them trying.
  Duration? get timeLeft => respondBy?.difference(DateTime.now());
}

class StayClaimService {
  StayClaimService._();
  static final StayClaimService instance = StayClaimService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _fns =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Claims made against this guest, newest first.
  ///
  /// ⚠ FILTERED ON guestUid BECAUSE THE RULE READS resource.data.guestUid.
  /// A list query whose rule references `resource` is REJECTED OUTRIGHT unless
  /// the query filters on that field — the trap that would have stopped guest
  /// messaging loading, caught on 21 August. Removing this where() does not
  /// widen the results, it returns an error.
  Stream<List<StayClaim>> watchMyClaims({int limit = 50}) {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<List<StayClaim>>.value(const <StayClaim>[]);
    return _db
        .collection(kStayClaimsCollection)
        .where('guestUid', isEqualTo: uid)
        .orderBy('openedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> q) =>
            q.docs.map(StayClaim.fromDoc).toList(growable: false));
  }

  Stream<StayClaim?> watchClaim(String claimId) => _db
      .collection(kStayClaimsCollection)
      .doc(claimId)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> d) =>
          d.exists ? StayClaim.fromDoc(d) : null);

  /// Only the claims still waiting on this guest.
  ///
  /// ⚠ THE NARROW QUERY IS THE POINT. The trip screen originally streamed the
  /// last 20 claims of ANY status on every open and discarded almost all of
  /// them on the phone. This asks the server for the only ones that can produce
  /// a banner, which for nearly every guest is an empty result — and an empty
  /// result costs one read, not twenty.
  ///
  /// Needs the composite index (guestUid ASC, status ASC). It is in
  /// firestore.indexes.json; without it this throws in production and returns
  /// nothing in a way that looks like "no claims".
  Stream<List<StayClaim>> watchAwaitingReplyClaims({int limit = 20}) {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<List<StayClaim>>.value(const <StayClaim>[]);
    return _db
        .collection(kStayClaimsCollection)
        .where('guestUid', isEqualTo: uid)
        .where('status', isEqualTo: 'awaiting_guest')
        .limit(limit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> q) =>
            q.docs.map(StayClaim.fromDoc).toList(growable: false));
  }

  /// How many are waiting on this guest. Drives a badge.
  Stream<int> watchAwaitingReply() =>
      watchAwaitingReplyClaims().map((List<StayClaim> c) => c.length);

  /// Accept or dispute. [note] is REQUIRED for a dispute — the server refuses
  /// it otherwise, and that refusal is deliberate.
  Future<void> respond({
    required String claimId,
    required bool accept,
    String note = '',
  }) async {
    try {
      await _fns.httpsCallable('respondToStayClaim').call(<String, dynamic>{
        'claimId': claimId,
        'response': accept ? 'accept' : 'dispute',
        'note': note,
      });
    } on FirebaseFunctionsException catch (e) {
      // The server's own wording. Its refusals are written to be read by a
      // guest — "Tell us why you disagree, so it can be looked at properly" —
      // and replacing them with "Something went wrong" throws away the only
      // part that says what to do.
      throw ClaimError(e.message ?? 'That response could not be sent.');
    } catch (e) {
      throw ClaimError('That response could not be sent. $e');
    }
  }
}

class ClaimError implements Exception {
  ClaimError(this.message);
  final String message;
  @override
  String toString() => message;
}
