// ─────────────────────────────────────────────────────────────────────────────
//  The circle the face goes in, and the ring that fills as the head turns.
//
//  Built 22 August 2026. Driven by services/liveness_ring_controller.dart —
//  read that file first, it explains why the sweep is ±30 degrees rather than
//  a full rotation.
//
//  ── WHY A RING RATHER THAN A PROGRESS BAR ───────────────────────────────────
//
//  Because the ring IS the head movement. A segment on the left lights when
//  the head is turned left; the shape on screen and the motion of the body
//  are the same shape, so nobody has to be told what the relationship is.
//
//  A bar filling 0 to 100 would carry identical information and teach nothing
//  — the user would still be guessing which way to turn and how far.
//
//  ⚠ THE SEGMENT COUNT LIVES IN THE CONTROLLER, not here. This widget paints
//  whatever length of list it is given. Two constants would drift.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'package:flutter/material.dart';

class LivenessRing extends StatelessWidget {
  const LivenessRing({
    super.key,
    required this.lit,
    this.diameter = 260,
    this.ringColour = const Color(0xFF22C55E),
    this.trackColour = const Color(0x33FFFFFF),
  });

  /// One entry per segment, true where the head has already been.
  final List<bool> lit;

  final double diameter;
  final Color ringColour;
  final Color trackColour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _RingPainter(
          lit: lit,
          ringColour: ringColour,
          trackColour: trackColour,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.lit,
    required this.ringColour,
    required this.trackColour,
  });

  final List<bool> lit;
  final Color ringColour;
  final Color trackColour;

  /// Gap between segments, in radians. Without it the ring reads as one solid
  /// circle and the sense of "filling up piece by piece" is lost.
  static const double _gap = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    if (lit.isEmpty) return;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(6);
    final double sweep = (2 * math.pi) / lit.length;

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = trackColour;

    final Paint on = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = ringColour;

    for (int i = 0; i < lit.length; i++) {
      // ⚠ STARTS AT THE TOP AND RUNS CLOCKWISE.
      //
      // Canvas angles start at 3 o'clock, so -pi/2 rotates the origin to 12
      // o'clock. Segment 0 is the far LEFT of the head sweep and must appear
      // on the left of the ring — the preview is mirrored, like a mirror, so
      // turning left moves the image left and the ring must agree. Getting
      // this backwards makes the ring fill away from the direction the head
      // is moving, which is disorienting in a way people cannot articulate.
      final double start = -math.pi / 2 + (i * sweep) + (_gap / 2);
      canvas.drawArc(
        rect,
        start,
        sweep - _gap,
        false,
        lit[i] ? on : track,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    if (old.lit.length != lit.length) return true;
    for (int i = 0; i < lit.length; i++) {
      if (old.lit[i] != lit[i]) return true;
    }
    return old.ringColour != ringColour || old.trackColour != trackColour;
  }
}
