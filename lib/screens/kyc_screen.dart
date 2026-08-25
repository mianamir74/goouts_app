import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_orientation.dart';
import '../services/liveness_ring_controller.dart';
import '../widgets/liveness_ring.dart';
import '../services/id_quality_inspector.dart';
import '../services/biometric_selfie_inspector.dart';
import '../services/auto_selfie_controller.dart';
// FaceCheckResult, for the onResult closure that feeds the liveness ring.
import '../services/face_check_service.dart';
import '../services/document_quality_inspector.dart';
// user_service import removed 4 August 2026. Both uses were
// UserService().updateUser({'kycStatus': 'pending'}), which is now the
// markKycSubmitted Cloud Function — kycStatus is no longer client writable.
import '../widgets/goouts_sheet.dart';
import '../utils/dob_input_formatter.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _bg = Color(0xFFF2F4F7);
  static const Color _green = Color(0xFF0A7A3E);

  // ── Step tracking ──────────────────────────────────────────────────────────
  int _step = 0; // 0=details, 1=id, 2=selfie, 3=review

  // ── Step 0: Personal details ───────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── Step 1 & 2: Camera ─────────────────────────────────────────────────────
  CameraController? _cameraCtrl;
  List<CameraDescription> _cameras = [];
  bool _cameraReady = false;

  // ── Captured paths ─────────────────────────────────────────────────────────
  String? _idImagePath;
  String? _selfieImagePath;

  // ── Inspector results ──────────────────────────────────────────────────────
  bool _idValid = false;
  bool _selfieValid = false;

  /// The quality warning, when the photo was accepted despite one. Stored with
  /// the record so an admin sees what the app thought.
  String? _selfieAdvice;

  /// Whether the head sweep completed, or the shutter was released by the
  /// timeout instead. Sent with the submission so a reviewer knows which.
  bool _livenessComplete = false;

  /// Why the sweep did not finish, if it did not. Sent with the submission.
  String _livenessNote = '';

  /// The instructions sheet is shown once per visit to this screen.
  bool _introShown = false;

  /// Stand-in for a ring that does not exist, so the bracket builder above has
  /// a notifier to listen to without allocating one on every rebuild.
  final ValueNotifier<LivenessRingState> _completedRing =
      ValueNotifier<LivenessRingState>(LivenessRingState.complete);
  Map<String, double> _selfieScores = const <String, double>{};
  bool _checking = false;
  String _feedbackMsg = '';

  /// Watches the preview and takes the selfie itself once the checks pass.
  /// Null whenever the front camera is not running, or on a device where image
  /// streaming is unavailable — the manual shutter still works in both cases.
  AutoSelfieController? _autoSelfie;

  /// The head sweep that must finish before the shutter is allowed.
  ///
  /// ⚠ IT SHARES THE AUTO-SELFIE'S DETECTOR. It is fed from
  /// AutoSelfieController.onResult rather than running a second face detector
  /// on the same stream — two detectors would double the CPU cost and could
  /// disagree about whether a face is even present.
  LivenessRingController? _liveness;

  // ── Inspectors ────────────────────────────────────────────────────────────
  final _idInspector       = IdQualityInspector();
  final _selfieInspector   = BiometricSelfieInspector();
  final _documentInspector = DocumentQualityInspector();

  // ── Submit state ───────────────────────────────────────────────────────────
  bool   _submitting       = false;
  bool   _submitted        = false;
  // GREEN | AMBER | RED — set by kycAutoDecision CF response
  String _kycDecisionTier  = 'GREEN';

  /// The composite score kycAutoDecision actually calculated, and the sentence
  /// it wrote to explain the outcome.
  ///
  /// ── ⚠ THESE WERE BEING THROWN AWAY ───────────────────────────────────────
  ///
  /// 24 August 2026. kycAutoDecision returns
  /// { decision, tier, overallScore, newKycStatus, reason } and this screen
  /// read exactly one field of it — tier. The number that DECIDED the outcome,
  /// and the sentence explaining it, were discarded on arrival.
  ///
  /// So a submission where every on-device check showed green landed in manual
  /// review and NOBODY COULD SEE WHY: not the applicant, not the admin, not
  /// me reading the code afterwards. The threshold for auto-approval is 0.85
  /// and there was no way to know whether a given attempt scored 0.84 or 0.66
  /// — which is the difference between "adjust the calibration slightly" and
  /// "something is badly wrong".
  ///
  /// Auto-approval exists to keep applications off the admin's desk. A gate
  /// that silently sends everybody to manual review is indistinguishable from
  /// having no gate at all, and this was the missing instrument.
  double? _kycAutoScore;
  String  _kycAutoReason = '';

  @override
  void initState() {
    super.initState();
    _initCameras();
    _checkExistingKyc();
  }

  /// On open, check Firestore kycStatus — show correct status screen instead of blank form.
  Future<void> _checkExistingKyc() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final status = doc.data()?['kycStatus'] as String? ?? '';
      if (!mounted) return;
      if (status == 'verified') {
        setState(() { _submitted = true; _kycDecisionTier = 'GREEN'; });
      } else if (status == 'pending') {
        setState(() { _submitted = true; _kycDecisionTier = 'AMBER'; });
      } else if (status == 'rejected') {
        setState(() { _submitted = true; _kycDecisionTier = 'RED'; });
      }
    } catch (_) {}
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (_) {}
  }

  Future<void> _startCamera({required bool front}) async {
    if (_cameras.isEmpty) return;

    final desc = front
        ? _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first,
          )
        : _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          );

    await _disposeAutoSelfie();
    await _cameraCtrl?.dispose();

    // ⚠ THE FORMAT DECIDES WHETHER AUTO-CAPTURE CAN WORK AT ALL.
    //
    // This was ImageFormatGroup.jpeg for both cameras. JPEG frames cannot be
    // fed to ML Kit, so an image stream on a JPEG group yields nothing usable
    // and the live check would simply never see a face — silently, with no
    // error, for ever.
    //
    // The ID step does not stream, so it keeps JPEG. The selfie step needs the
    // platform's raw format: NV21 on Android, BGRA on iOS.
    final ImageFormatGroup group = front
        ? (Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888)
        : ImageFormatGroup.jpeg;

    final ctrl = CameraController(desc, ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: group);
    await ctrl.initialize();
    if (!mounted) return;
    setState(() {
      _cameraCtrl = ctrl;
      _cameraReady = true;
      _feedbackMsg = '';
    });

    if (front) {
      final auto = AutoSelfieController(
        controller: ctrl,
        onCaptured: _acceptSelfie,
      );
      final ring = LivenessRingController();

      // ── THE FLOW ────────────────────────────────────────────────────────
      //
      //   1. sweep      the ring fills as the head turns. Shutter held.
      //   2. complete   or timed out — the shutter is released either way.
      //   3. capture    the EXISTING auto-capture takes the photo, straight
      //                 on, once the framing settles.
      //
      // Two separate things on purpose. The ring needs the head TURNING; the
      // photograph needs it STRAIGHT, because an admin compares it against a
      // passport. A frame grabbed mid-sweep would be a profile shot that
      // matches nothing.
      auto.holdShutter = true;
      auto.onResult = (FaceCheckResult r) {
        ring.onFrame(
          faceFound: r.available && r.faceCount == 1,
          // ⚠ PASSED THROUGH AS NULL WHEN NOT MEASURED. Never `?? 0`, which
          // would read as "facing dead ahead" and peg the sweep for ever.
          yaw: r.yaw,
        );
      };
      ring.state.addListener(() {
        final LivenessRingState s = ring.state.value;

        // ── ⚠ THE FAST SAMPLE RATE IS TIED TO THE SWEEP, NOT TO THE SCREEN ──
        //
        // The ring needs far more samples than framing does: at the resting
        // 300ms a whole head turn is described by four or five points and the
        // ring lurches round in steps instead of sweeping.
        //
        // But it is raised HERE, when the sweep actually starts, and not when
        // the camera opens. Raising it at setup meant a person who opened the
        // instruction sheet and read it — or who simply hesitated before
        // pressing start — had ML Kit running at eight frames a second the
        // whole time, for no benefit, warming the phone before the check had
        // even begun. Nothing is moving during centring; 300ms is plenty.
        if (s == LivenessRingState.sweeping) {
          auto.checkEveryMs = AutoSelfieController.sweepCheckEveryMs;
          return;
        }

        if (s == LivenessRingState.complete ||
            s == LivenessRingState.timedOut) {
          // Released on BOTH outcomes. A timeout must not trap anybody — the
          // photo is taken and the record carries `livenessComplete: false`
          // for the admin. See the note on the controller.
          auto.holdShutter = false;
          // Back to the framing rate. The head is meant to be STILL from here
          // on, so the extra frames would buy nothing and cost battery.
          auto.checkEveryMs = AutoSelfieController.framingCheckEveryMs;
          _livenessComplete = s == LivenessRingState.complete;
          // The same sentence the person was shown. A reviewer seeing
          // "turned left but not right" knows to look at the photo rather
          // than assume a failed check means a fraudulent one.
          _livenessNote = ring.failureReason.value;
          if (mounted) setState(() {});
        }
      });

      _autoSelfie = auto;
      _liveness = ring;
      await auto.start();
      if (mounted) setState(() {});

      // ── TELL THEM WHAT IS COMING, BEFORE IT COMES ────────────────────────
      //
      // Shown AFTER the camera is live so it opens over a working preview
      // rather than a black rectangle — people trust a screen that is
      // visibly ready more than one that is visibly loading.
      //
      // Once per visit to this screen, not once per attempt: re-reading the
      // same instructions after a retry is nagging, not helping.
      if (mounted && !_introShown) {
        _introShown = true;
        await _showLivenessIntro();
      }
    }
  }

  /// The single instruction line over the preview.
  ///
  /// Extracted so the sweep hint and the framing hint render IDENTICALLY —
  /// two copies of this styling would eventually drift and the line would
  /// visibly change shape as the screen handed over from one to the other.
  Widget _hintPill(String msg) => AnimatedOpacity(
        opacity: msg.isEmpty ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            msg.isEmpty ? ' ' : msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );

  /// Puts the movement check back to the beginning, in place.
  ///
  /// ── ⚠ WHY THIS EXISTS ────────────────────────────────────────────────────
  ///
  /// Reported from a real device, 24 August 2026: "there is no way to retry on
  /// the screen unless close and open again which is weird."
  ///
  /// It was exactly that. LivenessRingController.reset() had been written and
  /// NOTHING EVER CALLED IT. So the panel explained precisely what had gone
  /// wrong — "you turned to the left but not to the right" — and then offered
  /// no way to act on the explanation. The only route back was to leave the
  /// screen and re-enter, which also discarded the ID photograph taken on the
  /// step before.
  ///
  /// Diagnosing a problem and then not letting the person fix it is worse than
  /// not diagnosing it, because it proves the app knew.
  Future<void> _retryLiveness() async {
    final AutoSelfieController? auto = _autoSelfie;
    final LivenessRingController? ring = _liveness;
    if (auto == null || ring == null) return;

    ring.reset();
    // Held again from the very start: the shutter must not fire while the new
    // sweep is under way, or the photograph is a profile shot.
    auto.holdShutter = true;
    // The resting rate. The sweep's own listener raises it again when the
    // person presses start, exactly as it does on a first attempt.
    auto.checkEveryMs = AutoSelfieController.framingCheckEveryMs;

    setState(() {
      // ⚠ THE PREVIOUS ATTEMPT'S VERDICT MUST GO WITH IT. Leaving
      // _livenessNote set would file the new attempt under the old attempt's
      // failure, and an admin would read a note that describes a sweep that
      // was replaced.
      _livenessComplete = false;
      _livenessNote = '';
      _selfieAdvice = null;
      _selfieScores = const <String, double>{};
      _selfieImagePath = null;
      _selfieValid = false;
      _feedbackMsg = '';
      _checking = false;
    });

    await auto.restart();
    if (mounted) setState(() {});
  }

  Future<void> _disposeAutoSelfie() async {
    final auto = _autoSelfie;
    _autoSelfie = null;
    // Cleared first: the controller's onResult closure holds the ring, so
    // disposing the ring while frames are still arriving would fire listeners
    // on a disposed ValueNotifier.
    auto?.onResult = null;
    await auto?.dispose();
    _liveness?.dispose();
    _liveness = null;
  }

  Future<void> _stopCamera() async {
    await _disposeAutoSelfie();
    await _cameraCtrl?.dispose();
    _cameraCtrl = null;
    if (mounted) setState(() => _cameraReady = false);
  }

  @override
  void dispose() {
    _completedRing.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _cameraCtrl?.dispose();
    // ── ⚠ THE RING WAS LEAKING ON THIS PATH. FIXED 24 August 2026. ──────────
    //
    // _disposeAutoSelfie() clears onResult and disposes BOTH controllers, but
    // this method never called it — it disposed the auto-selfie controller and
    // stopped. So whenever the screen was destroyed without passing through
    // _stopCamera (backing out mid-check, the app being killed from the
    // recents list), the LivenessRingController survived with six live
    // ValueNotifiers and, mid-sweep, a twelve-second Timer still counting
    // down against a screen that no longer exists.
    //
    // onResult is cleared FIRST for the reason given in _disposeAutoSelfie: a
    // frame already in flight would otherwise call ring.onFrame after the ring
    // had gone. Both are null-guarded, so this is safe if _stopCamera already
    // ran and left them null.
    _autoSelfie?.onResult = null;
    _autoSelfie?.dispose();
    _autoSelfie = null;
    _liveness?.dispose();
    _liveness = null;
    _idInspector.dispose();
    _selfieInspector.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step navigation
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _goTo(int step) async {
    // Stop camera when leaving camera steps
    if (_step == 1 || _step == 2) await _stopCamera();

    // Releasing a camera is slow, and this screen is one a user commonly
    // leaves mid-flow: they back out to fetch their passport, or the app is
    // pushed to the background. If that happens while _stopCamera is still
    // running, this State is disposed and setState throws.
    if (!mounted) return;

    setState(() {
      _step = step;
      _cameraReady = false;
      _feedbackMsg = '';
    });

    // Start camera for the new step
    if (step == 1) await _startCamera(front: false);
    if (step == 2) await _startCamera(front: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Capture + inspect
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _captureId() async {
    if (_cameraCtrl == null || !_cameraReady || _checking) return;
    setState(() {
      _checking = true;
      _feedbackMsg = 'Analysing document…';
    });

    try {
      // ── ⚠ THE CAMERA PATH WAS NEVER NORMALISED EITHER ──────────────────────
      //
      // Found 24 August 2026 while fixing the selfie. The GALLERY path below
      // (_pickId) has called normaliseOrientation since 22 August; this one,
      // eleven lines away in the same file, never did.
      //
      // Same consequence, and slightly worse here: id_quality_inspector checks
      // the ASPECT RATIO of a card. On a photograph whose orientation lives in
      // an EXIF tag that decodeImage ignores, that check measures the wrong
      // dimension — a correctly held driving licence reads as the wrong shape
      // and is refused. The sideways file was also what went to Storage, so
      // the admin reviewed a rotated document.
      final XFile raw = await _cameraCtrl!.takePicture();
      final String uprightPath = await normaliseOrientation(raw.path);
      if (!mounted) return;
      final result = await _idInspector.inspectDocument(uprightPath);

      // Taking a photograph and running the document inspector together take
      // seconds, and a user who gets bored or takes a call in that window
      // leaves the screen. Without this guard setState throws on a disposed
      // State, and on iOS that surfaces as a crash with no useful stack.
      if (!mounted) return;

      if (result['isValid'] == true) {
        setState(() {
          // ⚠ THE UPRIGHT FILE, not raw.path. This is the one that gets
          // uploaded and re-inspected at submit; storing the raw path here
          // would undo the normalisation for everything downstream.
          _idImagePath = uprightPath;
          _idValid = true;
          _feedbackMsg = '';
          _checking = false;
        });
        await _goTo(2);
      } else {
        // crash_scan: ok - sibling branch of the await above, cannot both run
        setState(() {
          _feedbackMsg = result['errorMessage'] ?? 'Please retake.';
          _checking = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackMsg = 'Capture failed. Please try again.';
        _checking = false;
      });
    }
  }

  // Gallery fallback — only for the ID document step (selfie must be live)
  Future<void> _pickIdFromGallery() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // ⚠ NO imageQuality / maxWidth. The re-encode drops the EXIF
        // orientation tag WITHOUT rotating the pixels, and a sideways ID
        // fails the aspect-ratio check — it measures the wrong dimension on
        // a rotated card. The resize happens in normaliseOrientation instead.
      );
      if (picked == null) return;

      // The gallery picker is a separate system UI. On iOS, presenting it can
      // push this app into the background, and a low memory device may unload
      // the screen behind it entirely. So the State can already be gone by the
      // time the user has chosen a photograph.
      if (!mounted) return;

      setState(() {
        _checking    = true;
        _feedbackMsg = 'Analysing document…';
      });

      // Baked upright before anything reads the pixels. See
      // services/image_orientation.dart.
      final String uprightId = await normaliseOrientation(picked.path);
      if (!mounted) return;

      final result = await _idInspector.inspectDocument(uprightId);
      if (!mounted) return;

      if (result['isValid'] == true) {
        setState(() {
          _idImagePath = uprightId;
          _idValid     = true;
          _feedbackMsg = '';
          _checking    = false;
        });
        await _goTo(2);
      } else {
        // crash_scan: ok - sibling branch of the await above, cannot both run
        setState(() {
          _feedbackMsg = result['errorMessage'] ??
              'Could not verify this image. Please ensure all text on your ID is clearly visible and try again.';
          _checking = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedbackMsg = 'Could not open gallery. Please try again.';
        _checking    = false;
      });
    }
  }

  /// Judges a selfie that has already been taken, whoever took it.
  ///
  /// Both the manual shutter and AutoSelfieController end up here, so the photo
  /// is held to one standard however it was captured.
  ///
  /// Returns true when it was accepted. AutoSelfieController uses that to
  /// decide whether to move on or quietly resume guiding — which is why the
  /// rejection path below does NOT say "Please retake" when the shutter fired
  /// by itself. Nobody chose to take that photo, so there is nothing for them
  /// to do again.
  Future<bool> _acceptSelfie(String rawPath) async {
    if (!mounted) return false;
    setState(() {
      _checking = true;
      _feedbackMsg = 'Checking…';
    });

    // ── ⚠ BAKE THE ROTATION IN BEFORE ANYTHING READS THIS FILE ──────────────
    //
    // ADDED 24 August 2026. Reported from a real device: the liveness ring
    // completed, the brackets were green over a perfectly framed face, and
    // three consecutive photographs came back "We couldn't find a face in that
    // photo."
    //
    // ⚠ THIS IS THE SAME BUG normaliseOrientation WAS WRITTEN FOR ON 22
    // AUGUST, AND IT WAS ONLY EVER APPLIED TO THE ID PHOTOGRAPH. _captureId
    // normalises; the selfie did not. One fix, three call sites, one of them
    // done — which is this codebase's oldest and most expensive habit.
    //
    // Why it makes a face vanish:
    //
    //   biometric_selfie_inspector decodes with img.decodeImage, which IGNORES
    //   the EXIF orientation tag, and then hands ML Kit the width and height it
    //   got from that decode — the RAW SENSOR dimensions, which on a portrait
    //   iPhone photo are landscape.
    //
    //   ML Kit, meanwhile, reads the file through InputImage.fromFilePath,
    //   which DOES honour the tag. So it finds the face in a correctly upright
    //   image and reports the box in portrait coordinates.
    //
    //   evaluate() then measures a portrait face box against a landscape
    //   frame. The face-area fraction is computed against the wrong
    //   denominator and the box can sit outside the frame it is being compared
    //   with — so a photograph containing an obvious, well lit, centred face is
    //   judged to contain no usable face at all.
    //
    // Baking the rotation into the pixels and dropping the tag removes the
    // disagreement at source: after this there is nothing left for the two
    // readers to interpret differently.
    //
    // ⚠ COVERS BOTH ROUTES. Auto-capture and the manual Take Selfie button
    // both arrive here, so this is the one place it needs to happen. It also
    // never throws — a failure returns the original path.
    final String path = await normaliseOrientation(rawPath);
    if (!mounted) return false;

    try {
      final result = await _selfieInspector.inspectSelfie(path);
      if (!mounted) return false;

      // ── ⚠ ACCEPT UNLESS IT IS UNUSABLE. Changed 22 August 2026. ────────
      //
      // This used to require isValid == true. A well lit, centred,
      // straight-on selfie was refused ten times in a row: the face filled
      // the on-screen bracket exactly as instructed, but the size check
      // measures the face against the WHOLE frame and the bracket is only
      // the middle of it. Auto-capture then gave up and manual capture failed
      // the same check, so there was no way through the screen at all.
      //
      // Now only 'blocking' stops it — no face in the photograph, two people
      // in it, or a file that will not decode. Everything else is ADVICE: the
      // photo is kept, the warning is shown once, and the quality score goes
      // to the admin with the record.
      //
      // ⚠ DO NOT RESTORE THE isValid GATE. The app assists; the admin judges.
      final bool blocking = result['blocking'] == true;

      if (result['isValid'] == true || !blocking) {
        final String? advice =
            result['isValid'] == true ? null : result['errorMessage'] as String?;
        setState(() {
          _selfieImagePath = path;
          _selfieValid = true;
          // Shown briefly on the way through rather than as a refusal. They
          // are not being asked to do anything about it.
          _feedbackMsg = advice ?? '';
          _selfieAdvice = advice;
          _selfieScores = (result['scores'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
              const <String, double>{};
          _checking = false;
        });
        await _goTo(3);
        return true;
      }

      // Genuinely unusable. Say so whether the shutter was theirs or ours —
      // "automatic capture could not get a clear photo" on a photo with
      // nobody in it told them nothing.
      setState(() {
        _feedbackMsg = (result['errorMessage'] as String?) ??
            'We could not use that photo. Please take it again.';
        _checking = false;
      });
      return false;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _feedbackMsg = 'Capture failed. Please try again.';
        _checking = false;
      });
      return false;
    }
  }

  /// The manual shutter. Kept deliberately.
  ///
  /// Auto-capture will not fire on every device — image streaming is
  /// unavailable on some, and poor light can keep the score below the bar
  /// indefinitely. An identity check with no way to finish is the one outcome
  /// worth avoiding, so there is always a button.
  Future<void> _captureSelfie() async {
    if (_cameraCtrl == null || !_cameraReady || _checking) return;
    // The stream must stop before takePicture — several Android devices fail
    // outright if both run at once.
    await _autoSelfie?.stop();
    setState(() {
      _checking = true;
      _feedbackMsg = 'Analysing selfie…';
    });
    try {
      final file = await _cameraCtrl!.takePicture();
      final bool accepted = await _acceptSelfie(file.path);
      if (!accepted && mounted && _autoSelfie != null) {
        await _autoSelfie!.start();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedbackMsg = 'Capture failed. Please try again.';
        _checking = false;
      });
      await _autoSelfie?.start();
    }
  }

  Future<void> _submit() async {
    if (!_idValid || !_selfieValid) return;
    setState(() => _submitting = true);

    try {
      // ── 1. Collect document scores ────────────────────────────────────────
      Map<String, dynamic> documentScores = {'overall': 0.75};
      if (_idImagePath != null) {
        final docResult = await _documentInspector.inspectDocument(_idImagePath!);
        if (docResult['isValid'] == true) {
          documentScores = Map<String, dynamic>.from(
              docResult['scores'] as Map? ?? {'overall': 0.75});
        }
      }

      // ── 2. Collect selfie scores ──────────────────────────────────────────
      Map<String, dynamic> selfieScores = {'overall': 0.75};
      if (_selfieImagePath != null) {
        final selfieResult = await _selfieInspector.inspectSelfie(_selfieImagePath!);
        if (selfieResult['isValid'] == true) {
          selfieScores = Map<String, dynamic>.from(
              selfieResult['scores'] as Map? ?? {'overall': 0.75});
        }
      }

      // ── 3. Profile completeness score ─────────────────────────────────────
      // Checks: firstName, lastName, dob all filled (each worth 1/3)
      double profileCompleteness = 0.0;
      if (_firstNameCtrl.text.trim().isNotEmpty) profileCompleteness += 0.34;
      if (_lastNameCtrl.text.trim().isNotEmpty)  profileCompleteness += 0.33;
      if (_dobCtrl.text.trim().isNotEmpty)       profileCompleteness += 0.33;

      // ── 4. Upload images to Firebase Storage and save URLs ───────────────
      final uid = FirebaseAuth.instance.currentUser?.uid;
      String idFrontUrl  = '';
      String selfieUrl   = '';

      if (uid != null) {
        try {
          if (_idImagePath != null) {
            final idRef = FirebaseStorage.instance
                .ref('kyc/$uid/id_front.jpg');
            await idRef.putFile(File(_idImagePath!));
            idFrontUrl = await idRef.getDownloadURL();
          }
          if (_selfieImagePath != null) {
            final selfieRef = FirebaseStorage.instance
                .ref('kyc/$uid/selfie.jpg');
            await selfieRef.putFile(File(_selfieImagePath!));
            selfieUrl = await selfieRef.getDownloadURL();
          }
          // Save URLs to Firestore immediately so admin can see them.
          //
          // Via a Cloud Function now, not updateUser. kycStatus was writable
          // by the client, and while THIS call only ever wrote 'pending', the
          // rule that allowed it allowed 'approved' too — so a user could
          // pass their own identity check. For a business moving money that
          // is an AML control failure, not just a bug.
          //
          // markKycSubmitted also checks the URLs point at this user's own
          // kyc/{uid}/ folder, so nobody can attach someone else's verified
          // documents to their application.
          await FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable('markKycSubmitted')
              .call(<String, dynamic>{
            'idFrontUrl': idFrontUrl,
            'selfieUrl': selfieUrl,
            // ── WHAT THE APP THOUGHT OF THE SELFIE ────────────────────────
            //
            // Sent because the app no longer refuses an imperfect photo — it
            // accepts it and passes its own opinion along. Without this the
            // admin sees a picture with no idea whether the phone flagged
            // anything, which is exactly the blind approval the on-device
            // checks were added to prevent.
            //
            // Empty when the photo passed cleanly.
            if (_selfieAdvice != null) 'selfieAdvice': _selfieAdvice,
            if (_selfieScores.isNotEmpty) 'selfieScores': _selfieScores,
            // False means the ring timed out and the photo was taken anyway.
            // Not a rejection — a note for the reviewer that the movement
            // check did not finish, so they may want to look harder.
            'livenessComplete': _livenessComplete,
            if (_livenessNote.isNotEmpty) 'livenessNote': _livenessNote,
          });
        } catch (_) {
          // Upload failed — continue anyway, CF will still run
        }
      }

      // ── 5. Call kycAutoDecision Cloud Function ────────────────────────────
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('kycAutoDecision');

      final response = await callable.call(<String, dynamic>{
        'selfieScores':        selfieScores,
        'documentScores':      documentScores,
        'profileCompleteness': profileCompleteness,
      });

      final data = response.data as Map<String, dynamic>? ?? {};
      final tier = (data['tier'] as String?) ?? 'GREEN';

      if (mounted) {
        setState(() {
          _kycDecisionTier = tier;
          // Kept, not discarded. See the field declarations.
          _kycAutoScore  = (data['overallScore'] as num?)?.toDouble();
          _kycAutoReason = (data['reason'] as String?) ?? '';
          _submitting      = false;
          _submitted       = true;
        });
      }
    } catch (e) {
      // Fallback: set pending and show success UI — admin reviews manually
      try {
        // Same reason as above: kycStatus is not client writable any more.
        // markKycSubmitted is idempotent and will not walk an already
        // approved or rejected application backwards.
        await FirebaseFunctions.instanceFor(region: 'europe-west1')
            .httpsCallable('markKycSubmitted')
            .call(<String, dynamic>{});
      } catch (_) {}
      if (mounted) {
        setState(() {
          _kycDecisionTier = 'AMBER';
          _submitting      = false;
          _submitted       = true;
        });
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: !_submitted
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.black87),
                onPressed: () {
                  if (_step > 0) {
                    _goTo(_step - 1);
                  } else {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          'Identity Verification',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: _dark),
        ),
        centerTitle: true,
      ),
      body: _submitted ? _buildSuccess() : _buildStep(),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildDetailsStep();
      case 1:
        return _buildCameraStep(isId: true);
      case 2:
        return _buildCameraStep(isId: false);
      case 3:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared step header + progress dots
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProgressDots() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final active = i == _step;
            final done = i < _step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: done
                    ? _green
                    : active
                        ? _primary
                        : Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Step 0: Personal Details
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDetailsStep() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressDots(),
              _sectionIcon(Icons.person_outline_rounded),
              const SizedBox(height: 16),
              Text('Personal Details',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _dark)),
              const SizedBox(height: 6),
              Text(
                'Enter your details exactly as they appear on your ID document.',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 28),
              _inputField('First Name', _firstNameCtrl,
                  hint: 'e.g. James',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              _inputField('Last Name', _lastNameCtrl,
                  hint: 'e.g. Smith',
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              _inputField('Date of Birth', _dobCtrl,
                  hint: 'DD / MM / YYYY',
                  // number, not datetime. On iOS the datetime keyboard is a
                  // normal QWERTY with a few extra symbols — it does not give
                  // the numeric pad, which is what a date entered as digits
                  // actually needs.
                  keyboardType: TextInputType.number,
                  // Inserts " / " after the day and the month as you type, the
                  // same as the registration screen. Shared helper so the two
                  // screens cannot drift apart again.
                  onChanged: (val) {
                    final String formatted = formatDobInput(val);
                    if (formatted != val) {
                      _dobCtrl.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                            offset: formatted.length),
                      );
                    }
                  },
                  // ⚠ NOT `isEmpty`. That let "01 / 06 / 974" through the whole
                  // of KYC on 24 August. See validateDob.
                  validator: validateDob),
              const SizedBox(height: 32),
              _primaryButton('Continue to ID Scan', onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final status = await Permission.camera.request();
                if (status.isGranted) {
                  await _goTo(1);
                } else if (status.isPermanentlyDenied) {
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Camera Access Required'),
                      content: const Text(
                          'Camera permission is required for ID verification. '
                          'Please enable it in your device settings.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              openAppSettings();
                            },
                            child: const Text('Open Settings')),
                      ],
                    ),
                  );
                } else {
                  if (!mounted) return;
                  GoOutsSheet.warning(context,
                    title: 'Permission Required',
                    message: 'Camera permission is required for KYC.',
                  );
                }
              }),
              const SizedBox(height: 16),
              _infoCard(
                icon: Icons.lock_outline_rounded,
                text:
                    'Your data is encrypted and never shared without your consent.',
              ),
            ],
          ),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Step 1 & 2: Camera steps
  // ─────────────────────────────────────────────────────────────────────────
  /// Title and one supporting line, styled once.
  ///
  /// Extracted because five states now need it and five copies would drift —
  /// the heading would visibly change size as the screen moved between them.
  /// What is about to happen, before it happens.
  ///
  /// ── WHY A SHEET AND NOT MORE TEXT ON THE SCREEN ──────────────────────────
  ///
  /// The camera screen has room for one instruction at a time, and it has to
  /// be the one that applies right now. Everything else — how many steps,
  /// how long it takes, what to do about glasses — has nowhere to live there
  /// and would crowd out the line that matters.
  ///
  /// A sheet read at your own pace, dismissed when YOU are ready, solves both:
  /// the full picture up front, then a clean screen with one instruction.
  ///
  /// ⚠ DISMISSIBLE EVERY WAY. Close button, the ready button, tapping outside,
  /// and the system back gesture all work. A modal somebody cannot leave on a
  /// verification screen is how an account never gets created.
  Future<void> _showLivenessIntro() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Before you start',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close_rounded, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'This takes about fifteen seconds and proves you are a real '
              'person, not a photograph.',
              style: GoogleFonts.inter(
                  fontSize: 13.5, height: 1.5, color: Colors.grey[700]),
            ),
            const SizedBox(height: 22),
            // ── ⚠ THE SHEET DESCRIBES THE FLOW THAT ACTUALLY RUNS ───────────
            //
            // Rewritten 24 August 2026 after a device test. It was describing
            // a four-step flow that no longer existed: it never mentioned
            // coming back to the centre — which is now the step that decides
            // when the photograph is taken — and it said nothing about
            // glasses, which are refused outright when the lenses catch the
            // light.
            //
            // An instruction sheet that is out of date is worse than none. The
            // person follows it, the app does something else, and they
            // conclude the app is broken rather than that the sheet is.
            _introStep(1, Icons.remove_red_eye_outlined,
                'Take your glasses off',
                'Lenses catching the light hide your eyes, and the photo will '
                    'be refused.'),
            _introStep(2, Icons.face_retouching_natural_rounded,
                'Put your face in the circle',
                'Hold the phone at arm\'s length, in good light.'),
            _introStep(3, Icons.touch_app_outlined, 'Press start',
                'Nothing begins until you do. You will get a short countdown.'),
            _introStep(4, Icons.rotate_right_rounded,
                'Turn your head, left then right',
                'Go as far as is comfortable each way. The ring fills as you '
                    'go and the arrows show which side is done.'),
            _introStep(5, Icons.center_focus_strong_rounded,
                'Come back to the middle',
                'Line up with the mark at the bottom of the circle and look '
                    'straight ahead. The photo is taken for you.'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline_rounded,
                      size: 17, color: _primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      // Said plainly, because being unable to finish is the
                      // fear people actually have on this screen.
                      'If the ring does not fill in time we will still take '
                      'your photo and a person will review it. You will not '
                      'get stuck here.',
                      style: GoogleFonts.inter(
                          fontSize: 12, height: 1.45, color: _dark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
                child: Text(
                  "I'm ready",
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introStep(int n, IconData icon, String title, String detail) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F3FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$n. $title',
                    style: GoogleFonts.inter(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _dark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _stepHeading(String title, String subtitle) => Column(
        children: <Widget>[
          Text(
            title,
            style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w800, color: _dark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          SizedBox(
            // Fixed height so the camera below does not jump up and down as
            // the wording changes between states.
            height: 38,
            child: Text(
              subtitle,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[600], height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );

  Widget _buildCameraStep({required bool isId}) => Column(
        children: [
          _buildProgressDots(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _sectionIcon(isId
                    ? Icons.badge_outlined
                    : Icons.face_retouching_natural_rounded),
                const SizedBox(height: 12),

                // ── ⚠ THE HEADING FOLLOWS THE STATE ────────────────────
                //
                // It used to read "Look directly at the camera, keep your
                // eyes open" throughout — which flatly CONTRADICTS the ring
                // the moment it asks for a turn. Two instructions telling
                // somebody opposite things is the fastest way to make a
                // screen feel broken, and they will believe the big text
                // over the small one.
                if (isId)
                  _stepHeading(
                    'Scan your ID document',
                    'Place your passport or driving licence within the '
                        'frame. Make sure all the text is readable.',
                  )
                else if (_liveness == null)
                  _stepHeading(
                    'Take a live selfie',
                    'Hold the phone at arm\'s length in good light.',
                  )
                else
                  ValueListenableBuilder<LivenessRingState>(
                    valueListenable: _liveness!.state,
                    builder: (_, LivenessRingState st, Widget? child) {
                      switch (st) {
                        case LivenessRingState.centring:
                          return _stepHeading(
                            'Take a live selfie',
                            'Put your face inside the circle, at about '
                                'arm\'s length.',
                          );
                        case LivenessRingState.ready:
                          return _stepHeading(
                            'Ready when you are',
                            'You will turn your head to the left, then all '
                                'the way to the right. Press start.',
                          );
                        case LivenessRingState.countdown:
                          return _stepHeading(
                            'Get ready',
                            'Turn left, then all the way right. Keep your '
                                'face in the circle.',
                          );
                        case LivenessRingState.sweeping:
                          return _stepHeading(
                            'Turn your head',
                            'The green ring fills as you go. Left first, '
                                'then straight back across to the right.',
                          );
                        case LivenessRingState.returnToCentre:
                          return _stepHeading(
                            'Now back to the centre',
                            'Bring your face back to the middle of the circle '
                                'and look straight at the camera.',
                          );
                        case LivenessRingState.complete:
                        case LivenessRingState.timedOut:
                          return _stepHeading(
                            'Almost done',
                            'Look straight at the camera and hold still.',
                          );
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Camera viewport
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Camera preview
                // ── THE VIEWPORT ────────────────────────────────────
                //
                // Inset and rounded rather than bleeding to the screen edge.
                // A full-bleed preview with black bars reads as an unstyled
                // camera; a framed one reads as part of the product, which
                // matters on the screen where somebody is deciding whether
                // to trust us with their passport.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox.expand(
                      child: _cameraReady && _cameraCtrl != null
                          ? FittedBox(
                              // Fills the rounded frame without squashing the
                              // face — an aspect-distorted preview makes the
                              // face detector's own numbers misleading.
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: _cameraCtrl!.value.previewSize?.height ??
                                    720,
                                height: _cameraCtrl!.value.previewSize?.width ??
                                    1280,
                                child: CameraPreview(_cameraCtrl!),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF0D1B3E),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                    ),
                  ),
                ),

                // Overlay mask
                IgnorePointer(
                  child: isId
                      ? CustomPaint(
                          painter: _RoundedRectOverlay(),
                          child: const SizedBox.expand(),
                        )
                      // ── ⚠ THE SELFIE STEP IS A CIRCLE, START TO FINISH ──
                      //
                      // Reported from a device on 24 August 2026: "about 20%
                      // left Square line shows — this should not be, it should
                      // remain circle".
                      //
                      // The bracket used to reappear the instant the ring
                      // closed, so the guide the person had spent five seconds
                      // filling was replaced by a different shape at the exact
                      // moment they succeeded. It reads as the app changing its
                      // mind, and it happened while the ring still had visible
                      // dark segments — because completion is 85% coverage, not
                      // 100% — so it looked like the square arrived to say the
                      // circle had failed.
                      //
                      // ⚠ THE SQUARE IS NOW ONLY FOR THE ID STEP, where a card
                      // is genuinely rectangular. A face gets a circle and
                      // keeps it. The ring stays on screen through the capture,
                      // fully lit, with the centre mark showing where to look.
                      : const SizedBox.expand(),
                ),

                // ── THE LIVENESS RING ────────────────────────────────────
                //
                // Drawn only while the sweep is unfinished. Once it completes
                // it disappears, so the last thing on screen before the
                // shutter is a clean preview rather than a ring nobody needs
                // any more.
                if (!isId && _liveness != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<LivenessRingState>(
                        valueListenable: _liveness!.state,
                        builder: (_, LivenessRingState st, Widget? child) {
                          // ⚠ NO EARLY RETURN ON complete ANY MORE.
                          //
                          // The ring used to vanish the moment the sweep
                          // finished, which is what let the square bracket take
                          // its place — the complaint that started this. The
                          // circle now stays for the whole selfie step: filled,
                          // with the centre mark lit, right through the
                          // photograph being taken. One shape, start to finish.
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                            Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                ValueListenableBuilder<List<bool>>(
                                  valueListenable: _liveness!.lit,
                                  builder: (_, List<bool> lit, Widget? child) =>
                                      LivenessRing(
                                    lit: lit,
                                    centreActive: st ==
                                        LivenessRingState.returnToCentre,
                                  ),
                                ),
                                // 3 · 2 · 1, big, in the middle of the ring.
                                if (st == LivenessRingState.countdown)
                                  ValueListenableBuilder<int>(
                                    valueListenable: _liveness!.count,
                                    builder: (_, int n, Widget? child) => Container(
                                      width: 96,
                                      height: 96,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.55),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$n',
                                        style: GoogleFonts.inter(
                                          fontSize: 52,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                                ),

                                // ── WHICH WAY NOW ─────────────────────────
                                //
                                // The ring says how much is done; these say
                                // which side still needs doing, without asking
                                // anybody to read a sentence while they are
                                // concentrating on holding a phone steady.
                                //
                                // ⚠ FED THE SAME `lit` LIST THE RING PAINTS.
                                // Never the head angle — the preview is
                                // mirrored and ML Kit's sign convention is not
                                // worth guessing at. This way the chevrons
                                // cannot contradict the ring, and if the ring
                                // is ever found to fill the wrong way round on
                                // a real handset, that is one fix in the
                                // controller and these follow it for free.
                                const SizedBox(height: 18),
                                ValueListenableBuilder<List<bool>>(
                                  valueListenable: _liveness!.lit,
                                  builder: (_, List<bool> lit, Widget? child) =>
                                      LivenessArrows(lit: lit),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // ── Live guidance, selfie step only ──────────────────────
                //
                // Comes from AutoSelfieController, which gets it from the same
                // check that judges the final photo. So what it tells you to
                // fix is exactly what would otherwise have rejected you.
                if (!isId && _autoSelfie != null && _liveness != null)
                  Positioned(
                    top: 20,
                    left: 24,
                    right: 24,
                    // ⚠ THE SWEEP HINT WINS WHILE THE RING IS RUNNING.
                    //
                    // Two sources want this one line: the ring says "turn your
                    // head to the left", the framing check says "move closer".
                    // Showing both alternately is how a screen becomes
                    // impossible to follow, so while the sweep is unfinished
                    // the ring's instruction is the only one displayed. The
                    // framing hints return the moment the ring is done, in
                    // time to matter for the actual photograph.
                    // ⚠ _liveness! is safe: the enclosing `if` requires it.
                    // It used to fall back to `ValueNotifier(...)` inline,
                    // which allocated — and leaked — a new notifier on every
                    // single rebuild of this screen.
                    child: ValueListenableBuilder<LivenessRingState>(
                      valueListenable: _liveness!.state,
                      builder: (_, LivenessRingState st, Widget? child) {
                        final bool sweeping =
                            st != LivenessRingState.complete;
                        // The failure box already explains what happened in
                        // full. "Taking your photo anyway" above it as well
                        // was two panels saying one thing.
                        if ((_liveness?.failureReason.value ?? '').isNotEmpty) {
                          return const SizedBox.shrink();
                        }
                        return ValueListenableBuilder<bool>(
                          valueListenable: _autoSelfie!.gaveUp,
                          builder: (_, bool up, Widget? child) {
                            // ⚠ THE THIRD BOX. Once auto-capture has given up
                            // the panel lower down already says "use the
                            // button below", and this pill said the same thing
                            // again, higher up, in its own black rectangle.
                            if (up) return const SizedBox.shrink();
                            return ValueListenableBuilder<String>(
                              valueListenable: sweeping && _liveness != null
                                  ? _liveness!.hint
                                  : _autoSelfie!.guidance,
                              builder: (_, msg, Widget? child) => _hintPill(msg),
                            );
                          },
                        );
                      },
                    ),
                  ),


                // ── START BUTTON ────────────────────────────────────────
                //
                // The sweep begins when the person says so, never when their
                // face happens to drift into centre. Shown only in `ready`,
                // so it cannot be pressed before the face is found or after
                // the sweep is under way.
                if (!isId && _liveness != null)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: ValueListenableBuilder<LivenessRingState>(
                      valueListenable: _liveness!.state,
                      builder: (_, LivenessRingState st, Widget? child) {
                        if (st != LivenessRingState.ready) {
                          return const SizedBox.shrink();
                        }
                        return FilledButton(
                          onPressed: _liveness!.start,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: const Color(0xFF0392CA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26)),
                          ),
                          child: Text(
                            'Start',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        );
                      },
                    ),
                  ),

                // ── WHY IT DID NOT FINISH ───────────────────────────────
                //
                // Named specifically — "you turned left but not right", not
                // "verification failed". A person told only that it failed
                // repeats exactly what they just did.
                //
                // The photo has ALREADY been taken by this point. This is an
                // explanation, not a refusal, and the wording says so.
                if (!isId && _liveness != null)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 92,
                    child: ValueListenableBuilder<String>(
                      valueListenable: _liveness!.failureReason,
                      builder: (_, String reason, Widget? child) {
                        if (reason.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'The movement check did not finish',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                reason,
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: Colors.white
                                      .withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                // ⚠ "SAVED", NOT "SENT". Nothing is uploaded
                                // at this point — the photo is held on the
                                // device and goes up with the rest of the form
                                // at the end. Telling somebody their picture
                                // has already been sent for review, when they
                                // can still replace it, is a small lie that
                                // makes the retry button look pointless.
                                'Your photo was still saved and will go for '
                                'review. You can carry on, or try the movement '
                                'check again.',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: Colors.white
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // ── ⚠ THE WAY BACK. See _retryLiveness. ───────
                              //
                              // In the panel itself, not down with the other
                              // controls, because this is the answer to the
                              // sentence directly above it. A person reading
                              // "turn all the way back the other way" should
                              // find the button that lets them do so without
                              // moving their eyes.
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _retryLiveness,
                                  icon: const Icon(
                                      Icons.refresh_rounded, size: 18),
                                  label: Text(
                                    'Try the movement check again',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 44),
                                    backgroundColor: const Color(0xFF22C55E),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(22)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Hold-still ring. Fills over 0.7s so the shutter never fires
                // without warning — an unannounced capture reads as a bug even
                // when it worked.
                if (!isId && _autoSelfie != null)
                  IgnorePointer(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _autoSelfie!.holdProgress,
                      builder: (_, p, Widget? child) => p <= 0.0
                          ? const SizedBox.shrink()
                          : CustomPaint(
                              painter: _HoldStillBar(p),
                              child: const SizedBox.expand(),
                            ),
                    ),
                  ),

                // Auto-capture has stopped trying. Say so, once, instead of
                // letting the screen sit there looking like it is still
                // working.
                //
                // ⚠ Positioned OUTSIDE the builder, not returned from it.
                // A Positioned must be a DIRECT child of its Stack. Returning
                // one from a ValueListenableBuilder makes the BUILDER the
                // Stack's child, and Flutter throws "Incorrect use of
                // ParentDataWidget" at runtime — invisible to the analyzer,
                // and it would have fired exactly when auto-capture gave up,
                // which is the moment the person most needs the screen to work.
                // ⚠ HIDDEN WHILE THE LIVENESS FAILURE BOX IS SHOWING.
                //
                // Both used to render at bottom: 90 and bottom: 92, so they
                // printed straight over each other and neither was readable.
                // The liveness box is the more specific message, so it wins.
                // ⚠ AND HIDDEN WHILE A SPECIFIC REASON IS SHOWING.
                //
                // 24 August 2026, from a real device: this panel, the feedback
                // panel and the guidance pill all rendered at once, overlapping
                // and unreadable — "Automatic capture could not get a clear
                // photo" printed straight through "We couldn't find a face in
                // that photo".
                //
                // They are not three messages. They are one event described
                // three times, at three levels of usefulness. The specific
                // reason wins; this generic one only appears when there is no
                // specific one to show.
                if (!isId &&
                    _autoSelfie != null &&
                    _feedbackMsg.isEmpty &&
                    (_liveness?.failureReason.value ?? '').isEmpty)
                  Positioned(
                    bottom: 90,
                    left: 24,
                    right: 24,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _autoSelfie!.gaveUp,
                      builder: (_, up, Widget? child) => !up
                          ? const SizedBox.shrink()
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Automatic capture could not get a clear '
                                'photo. Use the button below.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                    fontSize: 12.5, color: Colors.white),
                              ),
                            ),
                    ),
                  ),

                // Feedback message.
                //
                // Also suppressed while the liveness box is up — three
                // stacked black panels is what the screen looked like before.
                if (_feedbackMsg.isNotEmpty &&
                    (_liveness?.failureReason.value ?? '').isEmpty)
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _feedbackMsg,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Capture button + gallery option (ID only)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: _checking
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _primaryButton(
                          isId ? 'Capture Document' : 'Take Selfie',
                          onPressed: isId ? _captureId : _captureSelfie,
                        ),
                        if (isId) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _pickIdFromGallery,
                              icon: const Icon(Icons.photo_library_rounded, size: 18),
                              label: Text(
                                'Choose from Gallery',
                                style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: const BorderSide(color: _primary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Use gallery if you have a digital copy of your ID',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Step 3: Review & Submit
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildReviewStep() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressDots(),
            _sectionIcon(Icons.fact_check_outlined),
            const SizedBox(height: 16),
            Text('Review & Submit',
                style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _dark)),
            const SizedBox(height: 6),
            Text(
              'All checks passed on your device. Review below and submit for final verification.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 28),

            // Name summary
            _reviewTile(
              icon: Icons.person_rounded,
              label: 'Name',
              value:
                  '${_firstNameCtrl.text} ${_lastNameCtrl.text}',
            ),
            _reviewTile(
              icon: Icons.cake_rounded,
              label: 'Date of Birth',
              value: _dobCtrl.text,
            ),

            const SizedBox(height: 20),

            // Captured images row
            Row(
              children: [
                Expanded(
                  child: _capturePreview(
                    path: _idImagePath,
                    label: 'ID Document',
                    icon: Icons.badge_outlined,
                    isValid: _idValid,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _capturePreview(
                    path: _selfieImagePath,
                    label: 'Selfie',
                    icon: Icons.face_retouching_natural_rounded,
                    isValid: _selfieValid,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // On-device checks summary
            _checksCard(),

            const SizedBox(height: 24),

            // Submit button — locked until both pass (they always will here
            // because we only reach step 3 after both pass, but we guard anyway)
            _primaryButton(
              'Submit for Verification',
              onPressed: (_idValid && _selfieValid && !_submitting)
                  ? _submit
                  : null,
              loading: _submitting,
            ),
            const SizedBox(height: 16),
            _infoCard(
              icon: Icons.verified_user_outlined,
              text:
                  'Verification is typically completed within 2 minutes. You will be notified once approved.',
            ),
          ],
        ),
      );

  Widget _reviewTile(
      {required IconData icon,
      required String label,
      required String value}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 22),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
              ],
            ),
          ],
        ),
      );

  Widget _capturePreview({
    required String? path,
    required String label,
    required IconData icon,
    required bool isValid,
  }) =>
      Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isValid ? _green : Colors.grey[300]!, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (path != null)
                Image.file(File(path), fit: BoxFit.cover)
              else
                Center(
                    child: Icon(icon, size: 36, color: Colors.grey[300])),
              if (isValid)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _checksCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('On-Device Checks',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            const SizedBox(height: 12),
            _checkRow('Image sharpness', _idValid),
            _checkRow('Document framing', _idValid),
            _checkRow('Face detected', _selfieValid),
            _checkRow('Eyes open & clear', _selfieValid),
            // ── ⚠ THE MOVEMENT CHECK IS LISTED HONESTLY. ────────────────────
            //
            // Reported from a device on 24 August 2026, and the reporter was
            // right to call it the real one: "if i do not do the face
            // verification and press take selfie it by pass the live test and
            // capture with green tick".
            //
            // The manual shutter has to stay — it is the guarantee that a
            // camera, a face detector or a phone we did not anticipate cannot
            // trap somebody on this screen for ever. That is not negotiable.
            //
            // What was wrong was the SCREEN, not the button. Four green ticks
            // and no mention of liveness reads as "everything passed", so
            // skipping the movement check looked identical to completing it —
            // to the applicant AND to the reviewer, since nothing on this panel
            // said otherwise.
            //
            // Now it is a row like any other, and it shows the truth. Amber,
            // not red: an unverified movement check is a reason to look harder
            // at the photograph, not grounds to refuse it.
            _checkRow(
              _livenessComplete
                  ? 'Movement check passed'
                  : 'Movement check not completed',
              _livenessComplete,
              warnWhenFalse: true,
            ),
          ],
        ),
      );

  /// One line of the on-device checks panel.
  ///
  /// [warnWhenFalse] draws the unfinished state in amber with a warning icon
  /// instead of a grey empty circle. A grey circle in a list of green ticks
  /// reads as "still loading"; amber reads as "look at this", which is the
  /// difference between a panel that informs and one that reassures falsely.
  Widget _checkRow(String label, bool passed,
          {bool warnWhenFalse = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              passed
                  ? Icons.check_circle_rounded
                  : warnWhenFalse
                      ? Icons.error_outline_rounded
                      : Icons.radio_button_unchecked_rounded,
              color: passed
                  ? _green
                  : warnWhenFalse
                      ? const Color(0xFFD97706)
                      : Colors.grey[300],
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          (!passed && warnWhenFalse) ? FontWeight.w600 : null,
                      color: (!passed && warnWhenFalse)
                          ? const Color(0xFFB45309)
                          : Colors.grey[700])),
            ),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Success screen
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    // ── GREEN: auto-approved ──────────────────────────────────────────────
    if (_kycDecisionTier == 'GREEN') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded, color: _green, size: 48),
              ),
              const SizedBox(height: 28),
              Text('Identity Verified!',
                  style: GoogleFonts.inter(
                      fontSize: 24, fontWeight: FontWeight.w800, color: _dark),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Your identity has been automatically verified. You can now use all GoOuts features.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: Colors.grey[600], height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              _primaryButton('Done', onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                }
              }),
            ],
          ),
        ),
      );
    }

    // ── RED: rejected — resubmit ──────────────────────────────────────────
    if (_kycDecisionTier == 'RED') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2), shape: BoxShape.circle),
                child: const Icon(Icons.cancel_rounded,
                    color: Color(0xFFDC2626), size: 48),
              ),
              const SizedBox(height: 28),
              Text('Verification Unsuccessful',
                  style: GoogleFonts.inter(
                      fontSize: 24, fontWeight: FontWeight.w800, color: _dark),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'We couldn\'t verify your identity from the images provided. Please ensure good lighting, all text is visible, and retake both your ID and selfie.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: Colors.grey[600], height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              _primaryButton('Try Again', onPressed: () {
                setState(() {
                  _step            = 0;
                  _idValid         = false;
                  _selfieValid     = false;
                  _submitted       = false;
                  _idImagePath     = null;
                  _selfieImagePath = null;
                  _feedbackMsg     = '';
                  _kycDecisionTier = 'GREEN';
                  // ⚠ The previous attempt's score goes with the previous
                  // attempt. Left behind, the next submission would display a
                  // number that was never calculated for it.
                  _kycAutoScore    = null;
                  _kycAutoReason   = '';
                });
              }),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
                  }
                },
                child: Text('Back to Profile',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey[600])),
              ),
            ],
          ),
        ),
      );
    }

    // ── AMBER: manual review pending (default fallback) ───────────────────
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7), shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFFD97706), size: 48),
            ),
            const SizedBox(height: 28),
            Text('Under Review',
                style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.w800, color: _dark),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Your documents have been submitted and are being reviewed by our team. This usually takes up to 24 hours. We\'ll notify you once complete.',
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey[600], height: 1.6),
              textAlign: TextAlign.center,
            ),
            // ── WHY THIS ONE NEEDED A HUMAN ──────────────────────────────────
            //
            // Only shown when the score came back, so it never appears on the
            // fallback path where the function could not be reached at all.
            //
            // Deliberately quiet — grey, small, below the explanation. The
            // applicant does not need to care, and reads past it. The person
            // who does need it is whoever is calibrating the 0.85 threshold,
            // and today that means asking somebody to submit and read this
            // line back.
            if (_kycAutoScore != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Automated score '
                      '${_kycAutoScore!.toStringAsFixed(2)} — needs 0.85 to '
                      'approve without a reviewer',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700]),
                    ),
                    if (_kycAutoReason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _kycAutoReason,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 11, height: 1.4, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 36),
            _primaryButton('Back to Profile', onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
              }
            }),
            const SizedBox(height: 8),
            // ── ⚠ A WAY BACK FROM "SUBMITTED", ADDED 24 August 2026 ───────────
            //
            // The rejected branch above has offered "Try Again" all along. This
            // one — the branch almost everybody lands on — offered nothing but
            // a way out of the screen.
            //
            // So somebody who noticed a mistake the moment they submitted, a
            // mistyped date of birth or a photograph of the wrong page, had to
            // WAIT TO BE REFUSED before they were allowed to correct it. A day
            // of an admin's attention spent rejecting a submission the
            // applicant already knew was wrong, and a day of the applicant's
            // waiting to be told something they told us first.
            //
            // Re-submitting overwrites the same record, so there is nothing to
            // clean up and no second entry for the admin to reconcile.
            TextButton(
              onPressed: () {
                setState(() {
                  _step            = 0;
                  _idValid         = false;
                  _selfieValid     = false;
                  _submitted       = false;
                  _idImagePath     = null;
                  _selfieImagePath = null;
                  _feedbackMsg     = '';
                  _kycDecisionTier = 'GREEN';
                  // ⚠ The previous attempt's score goes with the previous
                  // attempt. Left behind, the next submission would display a
                  // number that was never calculated for it.
                  _kycAutoScore    = null;
                  _kycAutoReason   = '';
                  // The liveness verdict belonged to the submission being
                  // replaced. Carrying it forward would file the new attempt
                  // under the old attempt's evidence.
                  _livenessComplete = false;
                  _livenessNote     = '';
                  _selfieAdvice     = null;
                  _selfieScores     = const <String, double>{};
                });
              },
              child: Text(
                'Something wrong? Submit again',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reusable widgets
  // ─────────────────────────────────────────────────────────────────────────
  Widget _sectionIcon(IconData icon) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
            color: const Color(0xFFE8F4FB),
            borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: _primary, size: 28),
      );

  Widget _primaryButton(String label,
          {required VoidCallback? onPressed, bool loading = false}) =>
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                onPressed == null ? Colors.grey[300] : _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _inputField(String label, TextEditingController ctrl,
      {String? hint,
      TextInputType? keyboardType,
      String? Function(String?)? validator,
      // Added 14 August 2026. This helper had no way to react to typing, which
      // is why the date-of-birth field on this screen never auto-formatted
      // while the identical field on the registration screen did.
      void Function(String)? onChanged}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            validator: validator,
            onChanged: onChanged,
            style: GoogleFonts.inter(fontSize: 15, color: _dark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
            ),
          ),
        ],
      );

  Widget _infoCard({required IconData icon, required String text}) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F4FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: _primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.5)),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painters for camera overlays
// ─────────────────────────────────────────────────────────────────────────────

/// Rounded rectangle overlay for ID document scanning.
class _RoundedRectOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Frame dimensions: wide & short, centred
    const hPad = 32.0;
    final vPad = h * 0.25;
    final rect = Rect.fromLTRB(hPad, vPad, w - hPad, h - vPad);
    const radius = Radius.circular(16);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // Dark overlay excluding the frame
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.55));

    // Frame border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF0392CA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Corner accents
    _drawCorners(canvas, rect, radius.x);
  }

  void _drawCorners(Canvas canvas, Rect r, double cr) {
    const len = 22.0;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(r.left + cr, r.top), Offset(r.left + cr + len, r.top), p);
    canvas.drawLine(Offset(r.left, r.top + cr), Offset(r.left, r.top + cr + len), p);
    // Top-right
    canvas.drawLine(Offset(r.right - cr, r.top), Offset(r.right - cr - len, r.top), p);
    canvas.drawLine(Offset(r.right, r.top + cr), Offset(r.right, r.top + cr + len), p);
    // Bottom-left
    canvas.drawLine(Offset(r.left + cr, r.bottom), Offset(r.left + cr + len, r.bottom), p);
    canvas.drawLine(Offset(r.left, r.bottom - cr), Offset(r.left, r.bottom - cr - len), p);
    // Bottom-right
    canvas.drawLine(Offset(r.right - cr, r.bottom), Offset(r.right - cr - len, r.bottom), p);
    canvas.drawLine(Offset(r.right, r.bottom - cr), Offset(r.right, r.bottom - cr - len), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}


/// The selfie target: four corner brackets, not a circle.
///
/// ── WHY BRACKETS, AND WHY THIS SIZE ─────────────────────────────────────────
///
/// 20 August 2026, reported as "the selfie circle is too big".
///
/// It was. The old oval covered roughly 40% of the frame while
/// FaceCheckService wants a face at about 22% of it. So the app drew one
/// target and measured against another: fill the oval as instructed, and the
/// check still said move closer, because by its own arithmetic you had not.
///
/// These brackets are AutoSelfieController.targetW x targetH — 0.55 x 0.40,
/// area 0.220, which is _idealFaceArea. Filling the brackets and passing the
/// size check are now the same act. Change either number and change the other
/// in the same edit.
///
/// Corners rather than a closed shape because a bracket says "put it between
/// these" without drawing an outline the face is meant to trace. A circle
/// invites people to match its edge, which is not what is measured.
// ⚠ _FaceBracketOverlay WAS DELETED ON 24 August 2026.
//
// It drew the corner brackets around the selfie, and the selfie step is a
// circle from start to finish now — the liveness ring stays on screen through
// the capture instead of handing over to a square halfway. Reported from a
// device as "about 20% left Square line shows, this should not be, it should
// remain circle".
//
// The ID step still uses _RoundedRectOverlay, which is correct: a passport
// IS a rectangle. Left as a private unused class it would have failed CI as a
// warning, and warnings are still fatal there. Git has it if it is ever wanted.

/// Hold-still progress, drawn as a bar beneath the brackets.
///
/// A bar rather than an arc around the target: an arc has to trace the same
/// geometry as the brackets, and two definitions of one shape is exactly how
/// the first version of this ended up visibly misaligned with its own mask.
class _HoldStillBar extends CustomPainter {
  _HoldStillBar(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width * 0.55;
    final double left = (size.width - w) / 2;
    final double y = size.height * 0.46 + (size.height * 0.40) / 2 + 22;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(left, y, w, 5), const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(left, y, w * progress.clamp(0.0, 1.0), 5),
          const Radius.circular(3)),
      Paint()..color = const Color(0xFF0A7A3E),
    );
  }

  @override
  bool shouldRepaint(_HoldStillBar old) => old.progress != progress;
}
