// The piece screens 17, 18 and 19 were built to plug into, and which did not
// exist until 16 August 2026.
//
// ── WHY THIS FILE EXISTS ─────────────────────────────────────────────────
//
// The capture screens were finished in the right shape and left unconnected:
//
//   17  CaptureChecklistScreen  takes `rooms`, `phase`, onCapture, onSkip,
//                               onFinish. Pure. Owns no data.
//   18  CameraCaptureScreen     takes `room`, `kind`, `onCaptured`. Pure.
//   19  SkipRoomSheet           returns a reason through Navigator.pop. Pure.
//
// Every one of them is a component with props and callbacks, and nothing
// supplied the props or answered the callbacks. Routed directly they open with
// `rooms: const []` and show "nothing to photograph" — a finished-looking
// screen that can never do anything, which is the hardest kind of gap to spot.
//
// This is the controller. It owns the bookingId, loads the room list, watches
// the evidence, and answers the three callbacks. The components stay pure.
//
// ── PROGRESS COMES FROM THE EVIDENCE, NOT FROM THE BOOKING ───────────────
//
// Screen 17 draws its progress from a CapturePhase. The obvious source is
// booking.capture.guestCheckIn — and on 16 August that field was found to be
// written once, empty, by createStayBooking and never touched again. A guest
// could photograph all seven rooms and be told "0 of 7 captured" for ever,
// with Finish never enabling.
//
// syncStayCaptureProgress now maintains it server side. This screen still
// builds the phase from the evidence subcollection directly, and deliberately:
//
//   * The evidence documents ARE the truth. The booking field is a summary of
//     them, and a summary can only ever be as fresh as its last trigger.
//   * A trigger takes a moment. A guest who has just taken a photograph should
//     see the tick immediately, not after a round trip through a function.
//   * If the trigger ever fails or is not deployed, the checklist still works.
//     The screen degrades to correct rather than to zero.
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/stay_booking.dart';
import '../models/stay_enums.dart';
import '../models/stay_evidence.dart';
import '../models/stay_listing.dart';
import '../services/stay_booking_service.dart';
import '../services/stay_evidence_service.dart';
import '../services/stay_listing_service.dart';
import '../stay_routes.dart';
import '../theme/stay_colors.dart';
import '17_capture_checklist_screen.dart';
import '18_camera_capture_screen.dart';
import '19_skip_room_sheet_screen.dart';

class CaptureFlowScreen extends StatefulWidget {
  const CaptureFlowScreen({
    super.key,
    required this.bookingId,
    this.kind = CaptureKind.guestCheckIn,
  });

  final String bookingId;

  /// Arrival or departure. The same three screens serve both — only the room
  /// states, the guidance and the reference photograph differ.
  final CaptureKind kind;

  @override
  State<CaptureFlowScreen> createState() => _CaptureFlowScreenState();
}

class _CaptureFlowScreenState extends State<CaptureFlowScreen> {
  final StayEvidenceService _evidence = StayEvidenceService.instance;

  List<String> _rooms = const <String>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  /// The room list comes from the LISTING, not from a constant here.
  ///
  /// The server generates captureRooms from the property's bedrooms and
  /// bathrooms, so a one bedroom flat and a four bedroom house ask for
  /// different things. Screen 17's own header note says the same: it cannot be
  /// guessed or shortened.
  Future<void> _loadRooms() async {
    try {
      final StayBooking? booking =
          await StayBookingService.instance.byId(widget.bookingId);
      if (booking == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'We could not find this booking.';
        });
        return;
      }

      final StayListing? listing =
          await StayListingService.instance.byId(booking.listingId);

      if (!mounted) return;
      setState(() {
        _rooms = listing?.captureRooms ?? const <String>[];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'We could not load the rooms to photograph.';
      });
    }
  }

  /// Builds the phase screen 17 expects out of the evidence documents.
  ///
  /// A room photographed after being skipped counts as done, not skipped —
  /// matching syncStayCaptureProgress, because the two disagreeing is how a
  /// guest sees one thing and a claim is judged on another.
  CapturePhase _phaseFrom(List<StayEvidence> all) {
    final List<String> done = <String>[];
    final List<String> skipped = <String>[];

    for (final e in all) {
      if (e.kind != widget.kind || e.room.isEmpty) continue;
      if (e.skipped) {
        if (!skipped.contains(e.room)) skipped.add(e.room);
      } else {
        if (!done.contains(e.room)) done.add(e.room);
      }
    }
    skipped.removeWhere(done.contains);

    final int addressed = done.length + skipped.length;
    final bool complete = _rooms.isNotEmpty && addressed >= _rooms.length;
    return CapturePhase(
      status: addressed == 0
          ? 'not_started'
          : complete
              ? 'complete'
              : 'in_progress',
      // Null on purpose. completedAt is a server fact recorded by
      // syncStayCaptureProgress, and inventing a client clock value here would
      // put a time on the booking that no server ever agreed to — the sort of
      // thing that matters when a claim turns on when photographs were taken.
      completedAt: null,
      roomsDone: done,
      roomsSkipped: skipped,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: GoOutsColors.primaryBlue),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return StreamBuilder<List<StayEvidence>>(
      stream: _evidence.watch(widget.bookingId),
      builder: (context, snapshot) {
        final List<StayEvidence> all =
            snapshot.data ?? const <StayEvidence>[];
        return CaptureChecklistScreen(
          rooms: _rooms,
          phase: _phaseFrom(all),
          kind: widget.kind,
          onCapture: (room) => _capture(room),
          onSkip: (room) => _skip(room),
          onFinish: _finish,
        );
      },
    );
  }

  // ── Capture ──────────────────────────────────────────────────────────────

  Future<void> _capture(String room) async {
    // On departure the guest's own arrival photograph of this room is shown as
    // a ghost overlay, which is what makes the two sets comparable at all. A
    // check-out photograph taken from a different corner proves nothing.
    String? reference;
    if (widget.kind == CaptureKind.guestCheckOut) {
      try {
        final StayEvidence? arrival = await _evidence.arrivalPhotoFor(
          bookingId: widget.bookingId,
          room: room,
        );
        reference = arrival?.url;
      } catch (_) {
        // No overlay is worse than no camera. Carry on without it.
        reference = null;
      }
    }

    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CameraCaptureScreen(
          room: room,
          kind: widget.kind,
          referencePhotoUrl: reference,
          onCaptured: (File photo) => _evidence.capture(
            bookingId: widget.bookingId,
            kind: widget.kind,
            room: room,
            photo: photo,
            platform: Platform.operatingSystem,
            appVersion: _appVersion,
          ),
        ),
      ),
    );
    // No setState. The evidence stream reports the new photograph and the
    // checklist redraws itself — one source of truth, not two.
  }

  // Kept as a constant rather than read from package_info_plus, which is not a
  // dependency of this app. It is recorded on every photograph so a rendering
  // or orientation bug can later be traced to the build that produced it.
  static const String _appVersion = 'goouts_app/short_stay_capture_1';

  // ── Skip ─────────────────────────────────────────────────────────────────

  Future<void> _skip(String room) async {
    final String? reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SkipRoomSheet(room: room),
    );

    // Dismissed without choosing. Nothing is recorded — a skip has to be
    // deliberate, because it counts against whoever made it in a claim.
    if (reason == null || reason.trim().isEmpty) return;

    try {
      await _evidence.skip(
        bookingId: widget.bookingId,
        kind: widget.kind,
        room: room,
        reason: reason.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('That skip was not saved. $e')),
      );
    }
  }

  // ── Finish ───────────────────────────────────────────────────────────────

  void _finish() {
    Navigator.of(context).pushReplacementNamed(
      widget.kind == CaptureKind.guestCheckOut
          ? StayRoutes.evidencePack
          : StayRoutes.captureComplete,
      arguments: <String, dynamic>{'bookingId': widget.bookingId},
    );
  }
}
