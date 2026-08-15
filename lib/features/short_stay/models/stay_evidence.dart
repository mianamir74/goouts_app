import 'package:cloud_firestore/cloud_firestore.dart';
import 'stay_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// One captured photograph, or one recorded skip.
// Collection: stay_bookings/{bookingId}/evidence/{evidenceId}
//
// APPEND ONLY. There is no update and no delete, for anyone, including us.
// That is enforced in the security rules, not here:
//
//     allow create: if isParticipant()
//                   && request.resource.data.takenAt == request.time;
//     allow update, delete: if false;
//
// `takenAt` MUST be FieldValue.serverTimestamp(). A device clock can be changed
// by the person holding the phone, which would make the entire evidence pack
// worthless in a dispute.
// ─────────────────────────────────────────────────────────────────────────────

class StayEvidence {
  final String id;
  final CaptureKind kind;
  final String room;
  final String storagePath;
  final String url;
  final DateTime? takenAt;
  final String capturedBy;
  final bool skipped;
  final String? skipReason;

  const StayEvidence({
    required this.id,
    required this.kind,
    required this.room,
    required this.storagePath,
    required this.url,
    required this.takenAt,
    required this.capturedBy,
    required this.skipped,
    required this.skipReason,
  });

  factory StayEvidence.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return StayEvidence(
      id: doc.id,
      kind: CaptureKind.from(m['kind'] as String?),
      room: (m['room'] ?? '') as String,
      storagePath: (m['storagePath'] ?? '') as String,
      url: (m['url'] ?? '') as String,
      takenAt: (m['takenAt'] as Timestamp?)?.toDate(),
      capturedBy: (m['capturedBy'] ?? '') as String,
      skipped: (m['skipped'] ?? false) as bool,
      skipReason: m['skipReason'] as String?,
    );
  }

  /// The write payload. No id, no update path, and takenAt is a server value.
  static Map<String, dynamic> createPayload({
    required CaptureKind kind,
    required String room,
    required String storagePath,
    required String url,
    required String capturedBy,
    required String platform,
    required String appVersion,
  }) =>
      {
        'kind': kind.wire,
        'room': room,
        'storagePath': storagePath,
        'url': url,
        'capturedBy': capturedBy,
        'skipped': false,
        'takenAt': FieldValue.serverTimestamp(),
        'deviceMeta': {'platform': platform, 'appVersion': appVersion},
      };

  static Map<String, dynamic> skipPayload({
    required CaptureKind kind,
    required String room,
    required String capturedBy,
    required String reason,
  }) =>
      {
        'kind': kind.wire,
        'room': room,
        'storagePath': '',
        'url': '',
        'capturedBy': capturedBy,
        'skipped': true,
        'skipReason': reason,
        'takenAt': FieldValue.serverTimestamp(),
      };
}
