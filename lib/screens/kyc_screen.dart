import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import '../services/id_quality_inspector.dart';
import '../services/biometric_selfie_inspector.dart';
import '../services/user_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KYC Screen — 4 steps:
//   0. Personal Details (text entry)
//   1. ID Document Scan (camera + rounded-rect overlay)
//   2. Live Selfie     (camera + oval overlay)
//   3. Review & Submit
// Continue is locked until both on-device inspectors return isValid:true.
// ─────────────────────────────────────────────────────────────────────────────
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
  bool _checking = false;
  String _feedbackMsg = '';

  // ── Inspectors ────────────────────────────────────────────────────────────
  final _idInspector = IdQualityInspector();
  final _selfieInspector = BiometricSelfieInspector();

  // ── Submit state ───────────────────────────────────────────────────────────
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _initCameras();
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

    await _cameraCtrl?.dispose();
    final ctrl = CameraController(desc, ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    await ctrl.initialize();
    if (!mounted) return;
    setState(() {
      _cameraCtrl = ctrl;
      _cameraReady = true;
      _feedbackMsg = '';
    });
  }

  Future<void> _stopCamera() async {
    await _cameraCtrl?.dispose();
    _cameraCtrl = null;
    if (mounted) setState(() => _cameraReady = false);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _cameraCtrl?.dispose();
    _idInspector.dispose();
    _selfieInspector.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step navigation
  // ─────────────────────────────────────────────────────────────────────────
  void _goTo(int step) async {
    // Stop camera when leaving camera steps
    if (_step == 1 || _step == 2) await _stopCamera();

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
      final file = await _cameraCtrl!.takePicture();
      final result = await _idInspector.inspectDocument(file.path);

      if (result['isValid'] == true) {
        setState(() {
          _idImagePath = file.path;
          _idValid = true;
          _feedbackMsg = '';
          _checking = false;
        });
        _goTo(2);
      } else {
        setState(() {
          _feedbackMsg = result['errorMessage'] ?? 'Please retake.';
          _checking = false;
        });
      }
    } catch (e) {
      setState(() {
        _feedbackMsg = 'Capture failed. Please try again.';
        _checking = false;
      });
    }
  }

  Future<void> _captureSelfie() async {
    if (_cameraCtrl == null || !_cameraReady || _checking) return;
    setState(() {
      _checking = true;
      _feedbackMsg = 'Analysing selfie…';
    });

    try {
      final file = await _cameraCtrl!.takePicture();
      final result = await _selfieInspector.inspectSelfie(file.path);

      if (result['isValid'] == true) {
        setState(() {
          _selfieImagePath = file.path;
          _selfieValid = true;
          _feedbackMsg = '';
          _checking = false;
        });
        _goTo(3);
      } else {
        setState(() {
          _feedbackMsg = result['errorMessage'] ?? 'Please retake.';
          _checking = false;
        });
      }
    } catch (e) {
      setState(() {
        _feedbackMsg = 'Capture failed. Please try again.';
        _checking = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_idValid || !_selfieValid) return;
    setState(() => _submitting = true);

    // Save kycStatus as 'pending' immediately when user submits
    await UserService().updateUser({'kycStatus': 'pending'});

    // Simulate remote verification delay (replace with real Sumsub/KYC API call later)
    await Future.delayed(const Duration(seconds: 2));

    // For prototype: mark as verified after simulated check
    await UserService().updateUser({'kycStatus': 'verified'});

    if (mounted) setState(() => _submitting = false);
    if (mounted) setState(() => _submitted = true);
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
                  keyboardType: TextInputType.datetime,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return null;
                  }),
              const SizedBox(height: 32),
              _primaryButton('Continue to ID Scan', onPressed: () {
                if (_formKey.currentState!.validate()) _goTo(1);
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
                Text(
                  isId ? 'Scan Your ID Document' : 'Take a Live Selfie',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _dark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isId
                      ? 'Place your passport or driving licence within the frame. Ensure all text is clearly visible.'
                      : 'Look directly at the camera, keep your eyes open and ensure your face is well lit.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey[600], height: 1.5),
                  textAlign: TextAlign.center,
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
                _cameraReady && _cameraCtrl != null
                    ? ClipRect(child: CameraPreview(_cameraCtrl!))
                    : Container(
                        color: Colors.black,
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white),
                        ),
                      ),

                // Overlay mask
                IgnorePointer(
                  child: CustomPaint(
                    painter: isId
                        ? _RoundedRectOverlay()
                        : _OvalOverlay(),
                    child: const SizedBox.expand(),
                  ),
                ),

                // Feedback message
                if (_feedbackMsg.isNotEmpty)
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
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

          // Capture button
          SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _checking
                  ? const CircularProgressIndicator()
                  : _primaryButton(
                      isId ? 'Capture Document' : 'Take Selfie',
                      onPressed:
                          isId ? _captureId : _captureSelfie,
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
                color: Colors.black.withOpacity(0.04),
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
                color: Colors.black.withOpacity(0.04),
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
                  color: Colors.black.withOpacity(0.45),
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
                color: Colors.black.withOpacity(0.04),
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
          ],
        ),
      );

  Widget _checkRow(String label, bool passed) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(
              passed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: passed ? _green : Colors.grey[300],
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[700])),
          ],
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Success screen
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccess() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded,
                    color: _green, size: 48),
              ),
              const SizedBox(height: 28),
              Text('Verification Submitted',
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _dark),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Your documents passed all on-device checks and have been securely submitted for review. You\'ll receive a notification once verified.',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              _primaryButton('Back to Home', onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (_) => false);
              }),
            ],
          ),
        ),
      );

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
      String? Function(String?)? validator}) =>
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

    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.55));

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

/// Oval overlay for selfie capture.
class _OvalOverlay extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    const hPad = 40.0;
    final vPad = h * 0.18;
    final ovalRect = Rect.fromLTRB(hPad, vPad, w - hPad, h - vPad);

    // Dark overlay excluding oval
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, w, h))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.55));

    // Oval border
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = const Color(0xFF0392CA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
