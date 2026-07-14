import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';

/// Result of a QR scan verification
class QrVerifyResult {
  final bool valid;
  final String? reason; // error message if invalid
  QrVerifyResult({required this.valid, this.reason});
}

/// Result of a GPS proximity check
class GpsVerifyResult {
  final bool withinRange;
  final double? distanceMetres;
  final String? error; // permission denied, service disabled, etc.
  GpsVerifyResult({required this.withinRange, this.distanceMetres, this.error});
}

class VisitVerifier {
  // ── Shared secret (same secret used in admin panel to generate QR codes) ──
  static const _secret = 'goouts_qr_verify_2025';

  // ── Maximum distance in metres to count as "at the partner" ──────────────
  static const double _maxDistanceMetres = 50.0;

  // ────────────────────────────────────────────────────────────────────────
  // QR Verification
  // Format: goouts://pay?mid=MERCHANT_ID&name=MERCHANT_NAME&cb=CB_PCT&sig=SIG
  // sig = HMAC-SHA256(mid:name:cb, _secret) in hex (first 16 chars for brevity)
  // ────────────────────────────────────────────────────────────────────────

  /// Verify a raw QR string against the expected merchant.
  static QrVerifyResult verifyQr(String raw, String expectedMerchantId) {
    try {
      if (!raw.startsWith('goouts://pay?')) {
        return QrVerifyResult(valid: false, reason: 'Not a GoOuts QR code.');
      }

      final uri = Uri.parse(raw);
      final mid = uri.queryParameters['mid'] ?? '';
      final name = uri.queryParameters['name'] ?? '';
      final cb = uri.queryParameters['cb'] ?? '';
      final sig = uri.queryParameters['sig'] ?? '';

      if (mid.isEmpty || sig.isEmpty) {
        return QrVerifyResult(valid: false, reason: 'QR code is incomplete.');
      }

      // Check merchant ID matches the partner page
      if (mid.toLowerCase() != expectedMerchantId.toLowerCase()) {
        return QrVerifyResult(
          valid: false,
          reason: 'This QR code is for a different partner ($mid). '
              'Please scan the QR code displayed at this partner\'s counter.',
        );
      }

      // Verify signature
      final expectedSig = _sign('$mid:$name:$cb');
      if (sig != expectedSig) {
        return QrVerifyResult(
          valid: false,
          reason: 'QR code signature is invalid. Please contact the partner.',
        );
      }

      return QrVerifyResult(valid: true);
    } catch (_) {
      return QrVerifyResult(valid: false, reason: 'Could not read QR code.');
    }
  }

  /// Generate the QR payload for a partner (used by admin panel / partner setup).
  static String generateQrPayload({
    required String merchantId,
    required String merchantName,
    required double cashbackPct,
  }) {
    final mid = merchantId.toLowerCase().replaceAll(' ', '-');
    final sig = _sign('$mid:$merchantName:${cashbackPct.toStringAsFixed(0)}');
    final encoded = Uri.encodeComponent(merchantName);
    return 'goouts://pay?mid=$mid&name=$encoded&cb=${cashbackPct.toStringAsFixed(0)}&sig=$sig';
  }

  static String _sign(String data) {
    final key = utf8.encode(_secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    // Return first 16 hex chars — short but sufficient for tamper detection
    return digest.toString().substring(0, 16);
  }

  // ────────────────────────────────────────────────────────────────────────
  // GPS Proximity Check
  // ────────────────────────────────────────────────────────────────────────

  /// Check if the user is within [_maxDistanceMetres] of the partner.
  /// Pass [partnerLat] = 0 and [partnerLng] = 0 if partner has no coordinates
  /// — in that case the check is skipped and returns withinRange: true.
  static Future<GpsVerifyResult> checkGps(double partnerLat, double partnerLng) async {
    // If partner has no registered coordinates → skip GPS check
    if (partnerLat == 0.0 && partnerLng == 0.0) {
      return GpsVerifyResult(withinRange: true, distanceMetres: null);
    }

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return GpsVerifyResult(
          withinRange: false,
          error: 'Location services are turned off. Please enable GPS.',
        );
      }

      // Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return GpsVerifyResult(
          withinRange: false,
          error: permission == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Please enable it in Settings.'
              : 'Location permission denied. We need it to verify you are at this partner.',
        );
      }

      // Get current position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        partnerLat, partnerLng,
      );

      return GpsVerifyResult(
        withinRange: distance <= _maxDistanceMetres,
        distanceMetres: distance,
      );
    } catch (e) {
      return GpsVerifyResult(
        withinRange: false,
        error: 'Could not get your location. Please check GPS is enabled.',
      );
    }
  }

  /// Derive a consistent merchant ID from a display name.
  /// e.g. "Artisan Brews" → "artisan-brews"
  static String merchantIdFromName(String name) =>
      name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}
