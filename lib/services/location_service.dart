import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Checks permission status and requests if needed.
  /// Returns the permission status after the check.
  Future<LocationPermission> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Gets the current device position.
  /// Returns null if permission is denied or location unavailable.
  Future<Position?> getCurrentPosition() async {
    try {
      final permission = await checkAndRequestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Calculates distance in metres between two coordinates.
  double distanceBetween(
      double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Formats distance into a readable string (e.g. "0.4 mi" or "1.2 mi").
  String formatDistance(double metres) {
    final miles = metres / 1609.344;
    if (miles < 0.1) return 'Nearby';
    return '${miles.toStringAsFixed(1)} mi';
  }

  /// Opens device location settings (for permanently denied state).
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
