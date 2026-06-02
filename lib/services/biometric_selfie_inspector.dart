import 'dart:io';
import 'package:image/image.dart' as img;

/// Module B — On-device selfie quality gate.
/// Checks image brightness and sharpness using pure Dart.
/// Full face/liveness detection is handled server-side by Sumsub/Onfido.
/// Costs £0.00 — runs entirely on device before any network call.
class BiometricSelfieInspector {
  static const double _blurThreshold = 60.0;
  static const double _minBrightness = 40.0;
  static const double _maxBrightness = 220.0;
  static const int _minFileSizeBytes = 40000; // ~40 KB minimum

  /// Returns `{"isValid": true}` or `{"isValid": false, "errorMessage": "..."}`.
  Future<Map<String, dynamic>> inspectSelfie(String imagePath) async {
    // ── Step 1: File size check ────────────────────────────────────────────
    final file = File(imagePath);
    final fileSize = await file.length();
    if (fileSize < _minFileSizeBytes) {
      return {
        'isValid': false,
        'errorMessage': 'Image too dark or low quality. Please ensure good lighting.',
      };
    }

    // ── Step 2: Decode image ───────────────────────────────────────────────
    final bytes = await file.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) {
      return {
        'isValid': false,
        'errorMessage': 'Could not read selfie. Please retake.',
      };
    }

    // Downsample for speed
    final small = img.copyResize(original, width: 200);
    final grey = img.grayscale(small);

    // ── Step 3: Brightness check ───────────────────────────────────────────
    final brightnessResult = _checkBrightness(grey);
    if (!brightnessResult['isValid']) return brightnessResult;

    // ── Step 4: Blur check ─────────────────────────────────────────────────
    final blurResult = _checkBlur(grey);
    if (!blurResult['isValid']) return blurResult;

    return {'isValid': true};
  }

  Map<String, dynamic> _checkBrightness(img.Image grey) {
    try {
      double total = 0;
      int count = grey.width * grey.height;
      for (int y = 0; y < grey.height; y++) {
        for (int x = 0; x < grey.width; x++) {
          total += grey.getPixel(x, y).r.toDouble();
        }
      }
      final avg = total / count;

      if (avg < _minBrightness) {
        return {
          'isValid': false,
          'errorMessage': 'Too dark. Move to a brighter area and retake.',
        };
      }
      if (avg > _maxBrightness) {
        return {
          'isValid': false,
          'errorMessage': 'Too bright. Avoid direct light behind you and retake.',
        };
      }
      return {'isValid': true};
    } catch (_) {
      return {'isValid': true};
    }
  }

  Map<String, dynamic> _checkBlur(img.Image grey) {
    try {
      final w = grey.width;
      final h = grey.height;
      double sumSq = 0;
      int count = 0;

      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final center = grey.getPixel(x, y).r.toInt();
          final top    = grey.getPixel(x, y - 1).r.toInt();
          final bottom = grey.getPixel(x, y + 1).r.toInt();
          final left   = grey.getPixel(x - 1, y).r.toInt();
          final right  = grey.getPixel(x + 1, y).r.toInt();
          final lap    = (top + bottom + left + right - 4 * center).toDouble();
          sumSq += lap * lap;
          count++;
        }
      }

      final variance = count > 0 ? sumSq / count : 0.0;
      if (variance < _blurThreshold) {
        return {
          'isValid': false,
          'errorMessage': 'Selfie is blurry. Hold still and retake.',
        };
      }
      return {'isValid': true};
    } catch (_) {
      return {'isValid': true};
    }
  }

  void dispose() {}
}
