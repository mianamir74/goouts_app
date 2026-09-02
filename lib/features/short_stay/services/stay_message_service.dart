// ─────────────────────────────────────────────────────────────────────────────
//  Guest to host messages. ONE WRITER.
//
//  Extracted 29 August 2026, when screen 27 needed to send the host a note
//  about an amendment and the only send in the app was a Firestore .add()
//  inlined in screen 30.
//
//  ── ⚠ WHY THIS IS A SERVICE AND NOT A SECOND COPY OF THOSE SIX LINES ────────
//
//  The message document has four fields and every one of them is load bearing:
//
//      senderUid    the rules compare it to request.auth.uid
//      senderRole   'guest' here, 'host' in the host app, and the ONLY
//                   difference between the two writers
//      text         what was typed
//      sentAt       ⚠ serverTimestamp(), because serverTimestamp resolves to
//                   request.time during RULE EVALUATION and the rule compares
//                   against it. A DateTime.now() is rejected outright.
//
//  A second screen writing this by hand would have had to get all four right,
//  and the fourth is the kind of thing that looks arbitrary and gets
//  "simplified" to DateTime.now() by whoever touches it next — at which point
//  messages stop sending, with a permission error rather than an obvious one.
//
//  notifyOnStayMessage fires on this write and pushes to the host, so a message
//  written through here is delivered without the caller doing anything.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StayMessageService {
  StayMessageService._();
  static final StayMessageService instance = StayMessageService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> threadFor(String bookingId) =>
      _db.collection('stay_bookings').doc(bookingId).collection('messages');

  /// Sends one message from the signed in guest.
  ///
  /// Throws on failure so the caller can keep what was typed. Screen 30 leaves
  /// the text in the box on a failed send on purpose: clearing it loses the
  /// message with no way to get it back.
  Future<void> send({
    required String bookingId,
    required String text,
  }) async {
    final String? uid = _uid;
    final String body = text.trim();
    if (uid == null || bookingId.isEmpty || body.isEmpty) return;

    await threadFor(bookingId).add(<String, dynamic>{
      'senderUid': uid,
      'senderRole': 'guest',
      'text': body,
      // ⚠ SERVER TIME. See the header. Do not replace this with a local clock.
      'sentAt': FieldValue.serverTimestamp(),
    });
  }
}
