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

/// The pre-existing damage entry, stored in `room` like any other.
///
/// ── ⚠ A SLUG, NOT THE WORDS ─────────────────────────────────────────────────
///
///  Written 29 August 2026. Every display site maps it through
///  [stayRoomLabel], so the wording can be changed without orphaning every
///  photograph already taken under the old sentence.
///
///  This codebase has been bitten repeatedly by storing a LABEL where a slug
///  belonged — amenities and property types both did it, and in both cases a
///  filter silently matched nothing. A room name that is user-visible prose is
///  the same trap: rename it and the server can no longer recognise it.
///
/// ── ⚠ IT IS NOT ONE OF THE REQUIRED ROOMS AND MUST NEVER BECOME ONE ─────────
///
///  captureRooms comes from the server and lists the rooms a guest has to
///  photograph. This is not on that list, deliberately:
///
///    · it is OPTIONAL. Forcing a photograph of damage from a guest who found
///      a spotless flat leaves them unable to finish, holding a camera,
///      looking for a scratch.
///    · both counters — syncStayCaptureProgress and _phaseFrom — now count
///      only rooms that appear in captureRooms, so a damage photograph cannot
///      push a phase to "complete" with a real room unphotographed.
const String kStayDamageRoom = '__existing_damage';

/// What to show a person for a stored room value.
///
/// Ordinary rooms are stored as their own display names ("Living room") and
/// pass straight through. Only the reserved slugs are translated.
String stayRoomLabel(String room) =>
    room == kStayDamageRoom ? 'Anything already damaged' : room;

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
