import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/stay_enums.dart';
import '../models/stay_evidence.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Capture, compress, upload, record.
//
// MEMORY DISCIPLINE IS NOT OPTIONAL HERE.
// This app has previously been killed by iOS Jetsam. A modern phone photograph
// is 4 to 8 MB decoded, and a seven room capture wants seven of them. The rule
// below is absolute:
//
//     NEVER HOLD MORE THAN ONE FULL RESOLUTION IMAGE IN MEMORY.
//     Compress to a temp file, upload FROM THE FILE, delete the temp file.
//
// Do not "optimise" this by keeping bytes in a list to retry an upload. That
// is what kills the app.
// ─────────────────────────────────────────────────────────────────────────────

class StayEvidenceService {
  StayEvidenceService._();
  static final instance = StayEvidenceService._();

  static const int _maxEdge = 1600;
  static const int _jpegQuality = 80;

  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _col(String bookingId) =>
      _db.collection('stay_bookings').doc(bookingId).collection('evidence');

  Stream<List<StayEvidence>> watch(String bookingId) => _col(bookingId)
      .orderBy('takenAt')
      .limit(200)
      .snapshots()
      .map((q) => q.docs.map(StayEvidence.fromDoc).toList(growable: false));

  Stream<List<StayEvidence>> watchKind(String bookingId, CaptureKind kind) =>
      _col(bookingId)
          .where('kind', isEqualTo: kind.wire)
          .limit(100)
          .snapshots()
          .map((q) => q.docs.map(StayEvidence.fromDoc).toList(growable: false));

  /// Compresses in place and returns a temp file. The caller MUST delete it,
  /// and `capture` below does.
  Future<File> _compress(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return source;

    final resized = decoded.width > decoded.height
        ? img.copyResize(decoded, width: _maxEdge)
        : img.copyResize(decoded, height: _maxEdge);

    final jpg = img.encodeJpg(resized, quality: _jpegQuality);
    final dir = await getTemporaryDirectory();
    final out = File(
        '${dir.path}/stay_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await out.writeAsBytes(jpg, flush: true);
    return out;
  }

  /// The whole capture path for one room.
  ///
  /// `takenAt` is a SERVER timestamp. A device clock can be changed by the
  /// person holding the phone, and a timestamp the guest controls would make
  /// the entire pack worthless in a dispute.
  Future<void> capture({
    required String bookingId,
    required CaptureKind kind,
    required String room,
    required File photo,
    required String platform,
    required String appVersion,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');

    File? temp;
    try {
      temp = await _compress(photo);

      final id = _col(bookingId).doc().id;
      final path = 'stay/$bookingId/${kind.wire}/$id.jpg';
      final ref = _storage.ref(path);

      await ref.putFile(
        temp,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        ),
      );
      final url = await ref.getDownloadURL();

      await _col(bookingId).doc(id).set(StayEvidence.createPayload(
            kind: kind,
            room: room,
            storagePath: path,
            url: url,
            capturedBy: uid,
            platform: platform,
            appVersion: appVersion,
          ));
    } finally {
      // Always, even if the upload threw. A leaked temp file per capture would
      // fill the device.
      if (temp != null && temp.path != photo.path) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }

  /// A skip is evidence too. It is recorded, and it counts against whoever
  /// skipped it if there is ever a claim. Never silently ignore one.
  Future<void> skip({
    required String bookingId,
    required CaptureKind kind,
    required String room,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    await _col(bookingId).add(StayEvidence.skipPayload(
      kind: kind,
      room: room,
      capturedBy: uid,
      reason: reason,
    ));
  }

  /// The guest's own arrival photograph of one room, used as the ghost overlay
  /// on the check out camera so the two sets are actually comparable.
  Future<StayEvidence?> arrivalPhotoFor({
    required String bookingId,
    required String room,
  }) async {
    final q = await _col(bookingId)
        .where('kind', isEqualTo: CaptureKind.guestCheckIn.wire)
        .where('room', isEqualTo: room)
        .where('skipped', isEqualTo: false)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return StayEvidence.fromDoc(q.docs.first);
  }
}
