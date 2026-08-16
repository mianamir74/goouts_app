// Supplies screen 20 with the photographs it is meant to be showing.
//
// CaptureCompleteScreen takes `evidence`, `kind` and `onDone` and owns no data,
// the same shape as 17, 18 and 19. Routed directly it opens with
// `evidence: const []` and congratulates the guest on capturing nothing.
//
// Kept as its own small file rather than folded into stay_routes so the route
// table stays a table. See capture_flow_screen.dart for the same reasoning
// applied to the checklist.
import 'package:flutter/material.dart';

import '../models/stay_enums.dart';
import '../models/stay_evidence.dart';
import '../services/stay_evidence_service.dart';
import '../stay_routes.dart';
import '20_capture_complete_screen.dart';

class CaptureCompleteHost extends StatelessWidget {
  const CaptureCompleteHost({
    super.key,
    required this.bookingId,
    this.kind = CaptureKind.guestCheckIn,
  });

  final String bookingId;
  final CaptureKind kind;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StayEvidence>>(
      // watchKind, not watch: this screen summarises ONE phase. Showing the
      // arrival set on the departure summary would tell a guest they had
      // photographed rooms they had not.
      stream: StayEvidenceService.instance.watchKind(bookingId, kind),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return CaptureCompleteScreen(
          evidence: snapshot.data ?? const <StayEvidence>[],
          kind: kind,
          onDone: () => Navigator.of(context).pushNamedAndRemoveUntil(
            StayRoutes.myBookings,
            (r) => r.isFirst,
          ),
        );
      },
    );
  }
}
