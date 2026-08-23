// ─────────────────────────────────────────────────────────────────────────────
//  Liveness by head sweep — the ring that fills as you turn.
//
//  Built 22 August 2026.
//
//  ── WHAT IT IS ──────────────────────────────────────────────────────────────
//
//  The face goes in a circle. A hint says to turn the head slowly. As the head
//  turns, segments of the ring light up green, one band of angle at a time.
//  When enough of the ring is lit, the photograph is taken.
//
//  ── WHY THIS SHAPE, AND NOT BLINK-THEN-TURN ─────────────────────────────────
//
//  Because PROGRESS IS VISIBLE. The failure this replaces was a good selfie
//  refused ten times with nothing on screen explaining why — the person could
//  not tell whether they were close or hopeless, so they repeated the same
//  thing and gave up. A ring that fills cannot fail silently: you either see it
//  moving or you do not, and you adjust within a second.
//
//  A blink challenge has the opposite property. A blink lasts 100–400ms, ML
//  Kit in fast mode with frame dropping often never samples the closed frame,
//  and the user has no idea whether their blink "counted". That is the same
//  silent failure wearing a different hat.
//
//  ── ⚠ WHY ±30 DEGREES AND NOT 360 ──────────────────────────────────────────
//
//  A full head rotation is impossible to track with ML Kit and asking for one
//  would recreate the bug it is meant to fix.
//
//  ML Kit finds a face by seeing a face. Past roughly 45 degrees of turn it
//  loses the face entirely — so a user obediently turning further would watch
//  the ring FREEZE at the exact moment they were doing as they were told.
//  Google's own guidance is narrower still: the classification signals are
//  only reliable within about ±18 degrees.
//
//  Face ID does the full circle because it uses an infrared dot projector to
//  read depth. We have a camera and a face detector. So the ring maps a
//  comfortable head-shake — _sweepDegrees each way — onto a full circle of
//  paint. It LOOKS like a 360 and it is a movement anybody can do.
//
//  ── ⚠ NULL YAW IS NOT ZERO ──────────────────────────────────────────────────
//
//  Google documents that the Euler angles come back NULL when performance mode
//  is fast and both landmarks and classification are off. Our detector enables
//  both, so they are populated — but if that config is ever "optimised", a null
//  treated as 0.0 would peg the sweep at dead centre and the ring would never
//  fill, with no error anywhere. onYaw takes a nullable double and ignores
//  null. Do not add a `?? 0.0`.
//
//  ── IT ASSISTS. IT DOES NOT TRAP. ───────────────────────────────────────────
//
//  If the ring has not closed within _timeoutMs the controller reports
//  timedOut, and the SCREEN IS EXPECTED TO CAPTURE ANYWAY and mark the record
//  "liveness incomplete" for the admin. That is the rule established across
//  this codebase on 22 August: the app assists, the admin judges. Nobody is
//  ever stuck on a screen they cannot leave.
//
//  ── WHAT IT DEFEATS, HONESTLY ───────────────────────────────────────────────
//
//  A printed photograph, completely. A phone held up playing a video, only
//  awkwardly — the movement would have to match. It does not defeat a prepared
//  attacker, and nothing without depth sensing does. It is here because it is
//  legible and pleasant, not because it is hard to fool.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';

enum LivenessRingState {
  /// Waiting for a face, roughly centred, before anything can start.
  centring,

  /// Face is centred and held. Waiting for the person to press start.
  ///
  /// ── WHY A DELIBERATE START, ADDED 22 AUGUST ──────────────────────────────
  ///
  /// The first version began the sweep — and the twelve second clock — the
  /// instant a face happened to centre. So the instruction "turn your head
  /// slowly" appeared at the same moment the person was already being timed,
  /// and they read it while the clock ran.
  ///
  /// Now nothing starts until they say so. They get to read what is about to
  /// happen, decide they are ready, and press. The clock they are racing is
  /// one they started themselves, which is the difference between a task and
  /// an ambush.
  ready,

  /// 3 · 2 · 1 before the sweep. Long enough to put the phone where they want
  /// it and get their bearings; short enough not to be a delay.
  countdown,

  /// Face found and centred. Turning fills the ring.
  sweeping,

  /// Enough of the ring is lit. Take the photograph.
  complete,

  /// Ran out of time. The screen should capture anyway — see the header.
  timedOut,
}

class LivenessRingController {
  /// How many bands the ring is divided into.
  ///
  /// 24 gives a segment every 2.5 degrees across the sweep — fine enough to
  /// feel continuous, coarse enough that a dropped frame does not leave a
  /// visible gap the user cannot fill.
  static const int segments = 24;

  /// Half-width of the sweep, in degrees. See the header for why this is not
  /// 180. Raising it past about 40 starts losing the face on real phones.
  static const double sweepDegrees = 30.0;

  /// How straight the head must be before the sweep begins. Without this the
  /// ring starts half filled because the user was already turned when the
  /// camera opened.
  static const double centreTolerance = 10.0;

  /// Fraction of the ring that must be lit to count as complete.
  ///
  /// Not 1.0 deliberately. Demanding every last segment means one dropped
  /// frame at the far edge leaves a single dark band the user cannot find, and
  /// they waggle their head at it until the timeout. 0.85 is a completed sweep
  /// in every practical sense.
  static const double completeFraction = 0.85;

  /// Both extremes must be reached, so a small wobble in the middle cannot
  /// fill 85% of the ring by jitter alone.
  static const double extremeFraction = 0.75;

  /// After this, give up and let the screen capture anyway.
  static const int timeoutMs = 12000;

  final ValueNotifier<LivenessRingState> state =
      ValueNotifier<LivenessRingState>(LivenessRingState.centring);

  /// Which segments are lit. The painter reads this.
  final ValueNotifier<List<bool>> lit =
      ValueNotifier<List<bool>>(List<bool>.filled(segments, false));

  /// What to tell the user right now.
  final ValueNotifier<String> hint =
      ValueNotifier<String>('Put your face in the circle');

  /// 0..1, for anything that wants a plain progress number.
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  /// Seconds counted down before the sweep. Shown big, in the ring.
  static const int countdownFrom = 3;

  /// How long the face must stay centred before Start is offered. Stops the
  /// button flickering in and out while somebody is still settling.
  static const int steadyMs = 600;

  /// The number currently on screen during [LivenessRingState.countdown].
  final ValueNotifier<int> count = ValueNotifier<int>(countdownFrom);

  /// Why the sweep did not finish, in words the person can act on.
  ///
  /// ── ⚠ NAMES THE ACTUAL CAUSE, NEVER "VERIFICATION FAILED" ────────────────
  ///
  /// "It failed, try again" tells somebody nothing and invites them to repeat
  /// exactly what they just did. Each reason below is measured from what the
  /// frames actually showed — how far the head got, whether it went both ways,
  /// whether the face kept leaving the frame — so the second attempt can be
  /// different from the first.
  ///
  /// Empty when the sweep completed.
  final ValueNotifier<String> failureReason = ValueNotifier<String>('');

  Timer? _timeout;
  Timer? _countdown;
  DateTime? _steadySince;
  bool _started = false;
  bool _finished = false;

  /// Counted so the timeout message can tell the difference between "you did
  /// not move" and "we kept losing sight of you", which need opposite advice.
  int _framesWithFace = 0;
  int _framesNoFace = 0;

  /// Feed every frame's result in here.
  ///
  /// [yaw] is nullable ON PURPOSE — see the header. [faceFound] is false when
  /// there is no face or more than one.
  void onFrame({required bool faceFound, required double? yaw}) {
    if (_finished) return;

    if (faceFound) {
      _framesWithFace++;
    } else {
      _framesNoFace++;
    }

    if (!faceFound) {
      _steadySince = null;
      // Losing the face mid-sweep is not a failure — a hand moved, the light
      // changed. The lit segments are KEPT so the person carries on from where
      // they were rather than starting again, which is the single most
      // demoralising thing this kind of screen can do.
      hint.value = _started
          ? 'Keep your face in the circle'
          : 'Put your face in the circle';
      return;
    }

    if (yaw == null) {
      // Not measured. Say nothing new and wait — never assume dead centre.
      return;
    }

    // ── NOTHING BEGINS WITHOUT A DELIBERATE START ──────────────────────
    //
    // Centring only offers the button. The sweep, and the clock, wait for the
    // person. See the note on LivenessRingState.ready.
    if (!_started) {
      if (state.value == LivenessRingState.countdown) return;

      if (yaw.abs() > centreTolerance) {
        _steadySince = null;
        state.value = LivenessRingState.centring;
        hint.value = 'Look straight at the camera';
        return;
      }

      // Held steady for a moment, so the button does not flicker in and out
      // while somebody is still getting comfortable.
      _steadySince ??= DateTime.now();
      if (DateTime.now().difference(_steadySince!).inMilliseconds < steadyMs) {
        return;
      }

      if (state.value != LivenessRingState.ready) {
        state.value = LivenessRingState.ready;
        hint.value = 'When you are ready, press start';
      }
      return;
    }

    _light(yaw);
  }

  void _light(double yaw) {
    final double clamped = yaw.clamp(-sweepDegrees, sweepDegrees);

    // -sweep..+sweep mapped onto 0..segments-1.
    final double t = (clamped + sweepDegrees) / (2 * sweepDegrees);
    final int index =
        (t * (segments - 1)).round().clamp(0, segments - 1);

    final List<bool> next = List<bool>.from(lit.value);
    if (!next[index]) {
      next[index] = true;
      lit.value = next;
    }

    final int on = next.where((bool b) => b).length;
    progress.value = on / segments;

    // Both ends, so a wobble in the middle cannot pass.
    final int edge = (segments * (1 - extremeFraction) / 2).floor().clamp(1, 6);
    final bool leftDone = next.take(edge).any((bool b) => b);
    final bool rightDone =
        next.reversed.take(edge).any((bool b) => b);

    if (!leftDone) {
      hint.value = 'Turn your head to the left';
    } else if (!rightDone) {
      hint.value = 'Now turn your head to the right';
    } else {
      hint.value = 'Almost there';
    }

    if (on >= (segments * completeFraction) && leftDone && rightDone) {
      _finish(LivenessRingState.complete);
      hint.value = 'Hold still';
    }
  }

  /// Called by the Start button. Runs 3 · 2 · 1, then opens the sweep.
  void start() {
    if (_started || _finished) return;
    if (state.value == LivenessRingState.countdown) return;

    state.value = LivenessRingState.countdown;
    count.value = countdownFrom;
    // Shown DURING the countdown, so the instruction is read before it is
    // needed rather than at the moment of acting on it.
    hint.value = 'Get ready to turn your head slowly, left then right';

    _countdown = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (_finished) {
        t.cancel();
        return;
      }
      if (count.value > 1) {
        count.value = count.value - 1;
        return;
      }
      t.cancel();
      _countdown = null;
      _beginSweep();
    });
  }

  void _beginSweep() {
    _started = true;
    _framesWithFace = 0;
    _framesNoFace = 0;
    state.value = LivenessRingState.sweeping;
    hint.value = 'Turn your head slowly to the left';
    // ⚠ THE CLOCK STARTS HERE, not when a face was first seen. It is now
    // twelve seconds the person chose to begin.
    _timeout = Timer(const Duration(milliseconds: timeoutMs), _giveUp);
  }

  void _giveUp() {
    if (_finished) return;

    failureReason.value = _explain();
    _finish(LivenessRingState.timedOut);

    // The photo is still taken — see the header. The hint says what is
    // happening; failureReason says why the check did not finish.
    hint.value = 'Taking your photo anyway';
  }

  /// Turns what the frames showed into one specific, actionable sentence.
  String _explain() {
    final List<bool> l = lit.value;
    final int on = l.where((bool b) => b).length;
    final int edge = (segments * (1 - extremeFraction) / 2).floor().clamp(1, 6);
    final bool left = l.take(edge).any((bool b) => b);
    final bool right = l.reversed.take(edge).any((bool b) => b);

    // Face kept leaving the frame — nothing about turning will help until
    // that is fixed, so it is checked first.
    final int total = _framesWithFace + _framesNoFace;
    if (total > 0 && _framesNoFace > total * 0.35) {
      return 'Your face kept going out of view. Hold the phone at arm\'s '
          'length, keep it still, and turn only your head.';
    }

    if (on <= 2) {
      return 'We did not see your head move. Next time turn slowly to the '
          'left, then slowly to the right, keeping your face in the circle.';
    }

    if (left && !right) {
      return 'You turned to the left but not to the right. The circle needs '
          'both sides — turn slowly all the way back the other way.';
    }

    if (right && !left) {
      return 'You turned to the right but not to the left. The circle needs '
          'both sides — turn slowly all the way back the other way.';
    }

    return 'The circle did not quite fill. Turn a little further each way, '
        'and more slowly — it needs a moment to read each position.';
  }

  void _finish(LivenessRingState s) {
    _finished = true;
    _timeout?.cancel();
    _timeout = null;
    _countdown?.cancel();
    _countdown = null;
    state.value = s;
  }

  /// Start again from nothing. Used when a second face appears, which is the
  /// one case where keeping progress would be wrong.
  void reset() {
    _timeout?.cancel();
    _timeout = null;
    _countdown?.cancel();
    _countdown = null;
    _steadySince = null;
    _framesWithFace = 0;
    _framesNoFace = 0;
    count.value = countdownFrom;
    failureReason.value = '';
    _started = false;
    _finished = false;
    lit.value = List<bool>.filled(segments, false);
    progress.value = 0.0;
    state.value = LivenessRingState.centring;
    hint.value = 'Put your face in the circle';
  }

  void dispose() {
    _timeout?.cancel();
    _countdown?.cancel();
    count.dispose();
    failureReason.dispose();
    state.dispose();
    lit.dispose();
    hint.dispose();
    progress.dispose();
  }
}
