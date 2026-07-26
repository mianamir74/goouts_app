import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's active delivery address for food ordering.
/// Persists across app restarts via SharedPreferences.
/// Screens listen via [ChangeNotifier] and rebuild when address changes.
class DeliveryAddressService extends ChangeNotifier {
  static const _kPrefKey = 'goouts_delivery_address';
  static const _kSavedKey = 'goouts_saved_addresses';

  /// Most recent addresses kept for quick re-selection at checkout.
  static const int _maxSaved = 8;

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
  /// Also records it in the saved-address history shown at checkout.
  Future<void> setAddress(DeliveryAddress address) async {
    _current = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, jsonEncode(address.toJson()));
    await _rememberAddress(prefs, address);
    notifyListeners();
  }

  /// Previously used delivery addresses, newest first.
  ///
  /// checkout_screen calls this to offer quick re-selection. It was being
  /// called but never existed on this class — a compile error
  /// (undefined_method) that would fail the iOS build outright.
  Future<List<String>> getSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kSavedKey) ?? <String>[];
  }

  /// Adds an address to the front of the history, de-duplicated and capped.
  Future<void> _rememberAddress(
      SharedPreferences prefs, DeliveryAddress address) async {
    final String display = address.fullDisplay.trim();
    if (display.isEmpty) return;

    final List<String> saved = prefs.getStringList(_kSavedKey) ?? <String>[];
    saved.removeWhere((s) => s.toLowerCase() == display.toLowerCase());
    saved.insert(0, display);
    if (saved.length > _maxSaved) {
      saved.removeRange(_maxSaved, saved.length);
    }
    await prefs.setStringList(_kSavedKey, saved);
  }

  /// Clear the address (e.g., on logout). Also clears saved history so a
  /// different user on the same device doesn't see the previous one's
  /// addresses.
  Future<void> clear() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefKey);
    await prefs.remove(_kSavedKey);
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
