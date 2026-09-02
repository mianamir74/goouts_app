// ─────────────────────────────────────────────────────────────────────────────
//  Reviews. The guest's side.
//
//  Written 29 August 2026 with functions/stay_reviews.js.
//
//  ── ⚠ WHY THERE IS NO WRITE PATH HERE ───────────────────────────────────────
//
//  Everything below either calls a Cloud Function or reads. Nothing in this
//  file writes to Firestore, and it must stay that way: reviews are DOUBLE
//  BLIND, and a client that could write a review could publish it early, or
//  read the drafts collection to see what the host said before answering.
//
//  firestore.rules enforces it — stay_review_drafts is closed to everyone and
//  the reviews subcollection is `allow write: if false` — so an attempt to add
//  a direct write here would simply be denied. This comment is so that the
//  denial is understood rather than worked around.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// What the server did with a submission.
class StayReviewOutcome {
  const StayReviewOutcome({
    required this.published,
    required this.waitingOn,
  });

  /// True when this submission completed the pair and both are now visible.
  final bool published;

  /// 'host', 'guest', or null when nothing is outstanding.
  final String? waitingOn;

  bool get isWaiting => !published && waitingOn != null;

  factory StayReviewOutcome.fromWire(Map<String, dynamic> m) =>
      StayReviewOutcome(
        published: m['published'] == true,
        waitingOn: m['waitingOn'] as String?,
      );
}

/// One published review of a property.
class StayReview {
  const StayReview({
    required this.id,
    required this.guestName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String guestName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  bool get hasComment => comment.trim().isNotEmpty;

  /// ⚠ TOLERANT OF THE SEED. stay_demo_seed.js wrote these documents before
  /// the real writer existed and its records carry no bookingId and no
  /// stayedOn. Demanding either would empty the review list on every demo
  /// property, which is most of what is on the platform today.
  factory StayReview.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final Map<String, dynamic> m = d.data();
    return StayReview(
      id: d.id,
      guestName: ((m['guestName'] ?? '') as String).trim().isEmpty
          ? 'Guest'
          : (m['guestName'] as String).trim(),
      rating: (m['rating'] as num?)?.toInt().clamp(1, 5) ?? 5,
      comment: ((m['comment'] ?? '') as String).trim(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class StayReviewService {
  StayReviewService._();
  static final StayReviewService instance = StayReviewService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // europe-west1, like every other function in this app. This is the field
  // that was us-central1 in stay_booking_service and failed only on a device,
  // only at runtime, so it is stated rather than defaulted.
  final FirebaseFunctions _fn =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Leaves this guest's review of a stay.
  ///
  /// Throws [FirebaseFunctionsException] with a server written message on any
  /// refusal — window closed, stay not finished, already reviewed. Screens
  /// show `e.message` rather than inventing their own wording, because the
  /// server is the only side that knows which of those it was.
  /// [categories] carries the six optional sub scores from screen 25, keyed by
  /// the wire names the server validates against — cleanliness, accuracy,
  /// checkIn, communication, location, value. Anything else is dropped there.
  ///
  /// ⚠ SENT, NOT JUST COLLECTED. The first draft of screen 25 gathered all six
  /// and then called this method without them, so a guest could rate six
  /// categories and have every one of them thrown away between the form and
  /// the wire. Sending nothing would have been more honest than asking.
  Future<StayReviewOutcome> submit({
    required String bookingId,
    required int rating,
    required String comment,
    Map<String, int> categories = const <String, int>{},
  }) async {
    final HttpsCallableResult<Map<String, dynamic>> res = await _fn
        .httpsCallable('submitStayReview')
        .call<Map<String, dynamic>>(<String, dynamic>{
      'bookingId': bookingId,
      'rating': rating,
      'comment': comment,
      if (categories.isNotEmpty) 'categories': categories,
    });
    return StayReviewOutcome.fromWire(res.data);
  }

  /// The published reviews on a property, newest first.
  ///
  /// Public read, so this works before sign in — a guest reads reviews while
  /// deciding whether to make an account.
  Future<List<StayReview>> forListing(String listingId, {int limit = 3}) async {
    if (listingId.isEmpty) return const <StayReview>[];
    final QuerySnapshot<Map<String, dynamic>> q = await _db
        .collection('stay_listings')
        .doc(listingId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return q.docs.map(StayReview.fromDoc).toList(growable: false);
  }
}
