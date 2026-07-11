import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's active delivery address for food ordering.
/// Persists across app restarts via SharedPreferences.
/// Screens listen via [ChangeNotifier] and rebuild when address changes.
class DeliveryAddressService extends ChangeNotifier {
  static const _kPrefKey = 'goouts_delivery_address';

  static final DeliveryAddressService _instance =
      DeliveryAddressService._internal();
  factory DeliveryAddressService() => _instance;
  DeliveryAddressService._internal();

  DeliveryAddress? _current;
  DeliveryAddress? get current => _current;

  bool get hasAddress => _current != null;

  /// Load persisted address on app start.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kPrefKey);
    if (json != null) {
      try {
        _current = DeliveryAddress.fromJson(jsonDecode(json) as Map<String, dynamic>);
        notifyListeners();
      } catch (_) {}
    }
  }

  /// Set a new delivery address and persist it.
  Future<void> setAddress(DeliveryAddress address) async {
    _current = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, jsonEncode(address.toJson()));
    notifyListeners();
  }

  /// Clear the address (e.g., on logout).
  Future<void> clear() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
    notifyListeners();
  }
}

class DeliveryAddress {
  final String label;        // e.g. "Home", "Work", or the street
  final String line1;        // building number + street
  final String line2;        // town/city
  final String postcode;
  final double? latitude;
  final double? longitude;
  final String? uprn;        // Ordnance Survey UPRN if available

  const DeliveryAddress({
    required this.label,
    required this.line1,
    required this.line2,
    required this.postcode,
    this.latitude,
    this.longitude,
    this.uprn,
  });

  /// Short display string shown in the app bar.
  String get shortDisplay {
    if (line1.isNotEmpty) return line1;
    if (postcode.isNotEmpty) return postcode;
    return label;
  }

  /// Full display string for address cards.
  String get fullDisplay {
    final parts = <String>[
      if (line1.isNotEmpty) line1,
      if (line2.isNotEmpty) line2,
      if (postcode.isNotEmpty) postcode,
    ];
    return parts.join(', ');
  }

  factory DeliveryAddress.fromJson(Map<String, dynamic> j) => DeliveryAddress(
        label: j['label'] as String? ?? '',
        line1: j['line1'] as String? ?? '',
        line2: j['line2'] as String? ?? '',
        postcode: j['postcode'] as String? ?? '',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        uprn: j['uprn'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'line1': line1,
        'line2': line2,
        'postcode': postcode,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (uprn != null) 'uprn': uprn,
      };
}
