import 'dart:io';
import 'package:image/image.dart' as img;

/// Module A — On-device ID document quality gate.
/// Uses pure Dart image processing to check sharpness and basic framing.
/// Costs £0.00 — runs entirely on device before any network call.
class IdQualityInspector {
  static const double _blurThreshold = 80.0;
  static const int _minFileSizeBytes = 50000; // ~50 KB minimum

  /// Returns `{"isValid": true}` or `{"isValid": false, "errorMessage": "..."}`.
  Future<Map<String, dynamic>> inspectDocument(String imagePath) async {
    // ── Step 1: Basic file size check ──────────────────────────────────────
    final file = File(imagePath);
    final fileSize = await file.length();
    if (fileSize < _minFileSizeBytes) {
      return {
        'isValid': false,
        'errorMessage': 'Image too small or too dark. Please ensure good lighting and retake.',
      };
    }

    // ── Step 2: Blur detection via Laplacian variance (pure Dart) ──────────
    final blurResult = await _checkBlur(imagePath);
    if (!blurResult['isValid']) return blurResult;

    return {'isValid': true};
  }

  /// Calculates Laplacian variance to detect blur.
  /// Low variance = blurry image.
  Future<Map<String, dynamic>> _checkBlur(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) {
        return {
          'isValid': false,
          'errorMessage': 'Could not read image. Please retake.',
        };
      }

      // Downsample for speed (max 200px wide)
      final small = img.copyResize(original, width: 200);
      final grey = img.grayscale(small);

      final width = grey.width;
      final height = grey.height;

      // Laplacian kernel: [0,1,0, 1,-4,1, 0,1,0]
      double sumSq = 0;
      int count = 0;

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          final center = _luma(grey, x, y);
          final top    = _luma(grey, x, y - 1);
          final bottom = _luma(grey, x, y + 1);
          final left   = _luma(grey, x - 1, y);
          final right  = _luma(grey, x + 1, y);

          final lap = (top + bottom + left + right - 4 * center).toDouble();
          sumSq += lap * lap;
          count++;
        }
      }

      final variance = count > 0 ? sumSq / count : 0.0;

      if (variance < _blurThreshold) {
        return {
          'isValid': false,
          'errorMessage': 'Image is too blurry. Hold your phone steady and retake.',
        };
      }

      return {'isValid': true};
    } catch (e) {
      // If analysis fails, allow through — don't block user on a processing error
      return {'isValid': true};
    }
  }

  int _luma(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);
    return pixel.r.toInt();
  }

  void dispose() {}
}
