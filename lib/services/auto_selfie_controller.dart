// ─────────────────────────────────────────────────────────────────────────────
//  AutoSelfieController — watches the preview and takes the photo itself.
//
//  Written 20 August 2026, reported as "I tried ten times and it would not take
//  my selfie".
//
//  ── THE PROBLEM ─────────────────────────────────────────────────────────────
//
//  The old flow took the photo first and judged it afterwards. Every failure
//  arrived as "Please retake", with nothing to aim at. The person is guessing,
//  and the app knows the answer the whole time and says nothing until it is too
//  late to act on.
//
//  ── THE FIX ─────────────────────────────────────────────────────────────────
//
//  Run the SAME checks on the live preview, say what is wrong while it can
//  still be corrected, and fire the shutter only once they already pass. The
//  photo then passes by construction, because the gate that takes it is the
//  code that validates it.
//
//  ── FOUR THINGS THAT MAKE IT FEEL RIGHT RATHER THAN CLEVER ──────────────────
//
//  1. THROTTLED to ~3 checks a second. ML Kit cannot run at 30fps and trying
//     cooks the battery. Frames arriving while one is in flight are DROPPED,
//     not queued — a queue on a live stream grows for ever and the guidance
//     ends up describing where the face was two seconds ago.
//
//  2. CONSECUTIVE good frames, not one. A single lucky frame between two blinks
//     is not a person holding still, and a shutter that fires on it produces
//     exactly the blurred half-blink the old flow rejected.
//
//  3. A HOLD-STILL PAUSE before firing. Without it the shutter goes off with no
//     warning and feels broken even when it worked.
//
//  4. A MARGIN. The live pass mark is higher than the still one, because the
//     preview runs ML Kit in fast mode and the saved photo is judged in
//     accurate mode. A frame that only just scrapes past live could fail the
//     real check, and an auto-shutter that fires and is then rejected is worse
//     than the manual button it replaced.
//
//  ── AND IF THE STILL CHECK STILL FAILS ──────────────────────────────────────
//
//  It goes back to scanning and keeps guiding. It does NOT show "Please
//  retake." The person did nothing wrong and has nothing to do differently —
//  telling them to try again is asking them to repeat an action they never
//  chose to take.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'camera_frame_converter.dart';
import 'face_check_service.dart';

enum AutoSelfieState { idle, scanning, holdStill, capturing, captured }

class AutoSelfieController {
  AutoSelfieController({
    required this.controller,
    required this.onCaptured,
  });

  final CameraController controller;

  /// Called with the file path once a photo has been taken. The screen still
  /// runs its own full-quality check on it — this does not replace that.
  final Future<bool> Function(String path) onCaptured;

  // ── Tuning. See the numbered notes at the top. ────────────────────────────
  static const int _checkEveryMs = 300;
  static const int _neededGoodFrames = 3;
  static const int _holdStillMs = 700;

  /// Live pass mark. Deliberately above the still check's own bar so a
  /// borderline frame does not fire a shutter the accurate pass would reject.
  static const double _liveMinOverall = 0.65;

  final LiveFaceDetector _detector = LiveFaceDetector();

  final ValueNotifier<AutoSelfieState> state =
      ValueNotifier<AutoSelfieState>(AutoSelfieState.idle);

  /// What the person should do right now. Empty means "nothing, you are fine".
  final ValueNotifier<String> guidance = ValueNotifier<String>('');

  /// 0.0 to 1.0 — how far through the hold-still countdown. Drives the ring.
  final ValueNotifier<double> holdProgress = ValueNotifier<double>(0.0);

  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  int _goodFrames = 0;
  Timer? _holdTimer;
  bool _streaming = false;
  bool _stopped = false;

  bool get isRunning => _streaming;

  Future<void> start() async {
    if (_streaming || _stopped) return;
    if (!controller.value.isInitialized) return;
    try {
      _streaming = true;
      state.value = AutoSelfieState.scanning;
      guidance.value = 'Looking for your face…';
      await controller.startImageStream(_onFrame);
    } catch (e) {
      // Image streaming is unavailable on some devices and in some emulators.
      // Not fatal: the manual shutter is still there, which is why this only
      // logs. An identity check that cannot be completed at all is the one
      // outcome worth avoiding.
      debugPrint('AutoSelfieController: stream unavailable — $e');
      _streaming = false;
      state.value = AutoSelfieState.idle;
      guidance.value = '';
    }
  }

  Future<void> stop() async {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!_streaming) return;
    _streaming = false;
    try {
      await controller.stopImageStream();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _stopped = true;
    await stop();
    await _detector.dispose();
    state.dispose();
    guidance.dispose();
    holdProgress.dispose();
  }

  void _onFrame(CameraImage image) {
    if (!_streaming || _stopped) return;
    if (state.value == AutoSelfieState.capturing ||
        state.value == AutoSelfieState.captured) {
      return;
    }
    // Drop rather than queue. See note 1.
    if (_detector.isBusy) return;

    final DateTime now = DateTime.now();
    if (now.difference(_lastCheck).inMilliseconds < _checkEveryMs) return;
    _lastCheck = now;

    final InputImageLike? converted = _convert(image);
    if (converted == null) return; // unsupported frame, not a failed check

    _detector
        .check(converted.image,
            imageWidth: converted.width, imageHeight: converted.height)
        .then(_onResult);
  }

  InputImageLike? _convert(CameraImage image) {
    final input = CameraFrameConverter.toInputImage(
      image,
      controller.description,
      DeviceOrientation.portraitUp,
    );
    if (input == null) return null;
    return InputImageLike(input, image.width, image.height);
  }

  void _onResult(FaceCheckResult? result) {
    if (result == null || _stopped || !_streaming) return;
    if (state.value == AutoSelfieState.capturing) return;

    // ML Kit unavailable on this device. Say nothing, change nothing, and let
    // the manual shutter carry it — the same fail-open policy the still check
    // already uses.
    if (!result.available) {
      guidance.value = '';
      return;
    }

    final bool good = result.isValid && result.overall >= _liveMinOverall;

    if (!good) {
      _goodFrames = 0;
      _cancelHold();
      // The check's own words. One source of truth for what is wrong, so the
      // live hint and the final message cannot contradict each other.
      guidance.value = result.errorMessage?.isNotEmpty == true
          ? _liveWording(result.errorMessage!)
          : 'Hold steady…';
      state.value = AutoSelfieState.scanning;
      return;
    }

    _goodFrames++;
    guidance.value = '';
    if (_goodFrames >= _neededGoodFrames &&
        state.value != AutoSelfieState.holdStill) {
      _beginHold();
    }
  }

  /// The still-photo messages are written for after the event — "take it
  /// again". Live, the photo has not been taken yet, so they are rewritten in
  /// the present tense. Same checks, same order, correct tense.
  String _liveWording(String stillMessage) {
    final String m = stillMessage.toLowerCase();
    if (m.contains('find a face')) return 'Bring your face into the circle';
    if (m.contains('more than one')) return 'Only you in the frame, please';
    if (m.contains('too small')) return 'Move a little closer';
    if (m.contains('look straight')) return 'Look straight at the camera';
    if (m.contains('tilted')) return 'Hold the phone level';
    if (m.contains('eyes look closed')) return 'Open both eyes';
    if (m.contains('covered')) return 'Uncover your face';
    return 'Hold steady…';
  }

  void _beginHold() {
    state.value = AutoSelfieState.holdStill;
    guidance.value = 'Hold still…';
    holdProgress.value = 0.0;

    const int tick = 50;
    int elapsed = 0;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: tick), (t) {
      elapsed += tick;
      holdProgress.value = (elapsed / _holdStillMs).clamp(0.0, 1.0);
      if (elapsed >= _holdStillMs) {
        t.cancel();
        _capture();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    holdProgress.value = 0.0;
  }

  Future<void> _capture() async {
    if (_stopped || state.value == AutoSelfieState.capturing) return;
    state.value = AutoSelfieState.capturing;
    guidance.value = '';

    // The stream MUST stop before takePicture. Several Android devices fail
    // outright if both run at once, and the failure is a native exception with
    // no useful message.
    await stop();

    try {
      final XFile shot = await controller.takePicture();
      final bool accepted = await onCaptured(shot.path);
      if (_stopped) return;
      if (accepted) {
        state.value = AutoSelfieState.captured;
        return;
      }
      // Rejected by the full-quality check. Not the person's fault and not
      // their problem to solve — go back to guiding, silently.
      _goodFrames = 0;
      state.value = AutoSelfieState.scanning;
      await start();
    } catch (e) {
      debugPrint('AutoSelfieController: capture failed — $e');
      if (_stopped) return;
      _goodFrames = 0;
      state.value = AutoSelfieState.scanning;
      await start();
    }
  }
}

/// Carries the converted frame together with the dimensions the checks need.
/// The size must come from the CameraImage, not the InputImage, because the
/// face-area threshold is a fraction of the frame and a wrong denominator
/// silently changes how close the person is asked to sit.
class InputImageLike {
  const InputImageLike(this.image, this.width, this.height);
  final InputImage image;
  final int width;
  final int height;
}
