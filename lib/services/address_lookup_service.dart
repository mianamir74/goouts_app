import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// GoOuts Address Lookup Service
///
/// Strategy: user types postcode → tap "Look Up" → Mapbox validates it and
/// returns town + coordinates in one call → town/city/country auto-fill →
/// user types house number and street name manually.
class AddressLookupService {
  static const String _mapboxToken =
      'pk.eyJ1IjoibWlhbmFtaXI3NCIsImEiOiJjbW44aGp1bTYwYzVrMnBxcnRvYzA5bG40In0.2thWcmSMupWuGVNKJmfQyg';

  // ─── Postcode helpers ────────────────────────────────────────────────────

  /// Normalise postcode to standard `AA1 1AA` format.
  static String normalise(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length < 3) return cleaned;
    return '${cleaned.substring(0, cleaned.length - 3)} '
        '${cleaned.substring(cleaned.length - 3)}';
  }

  /// True if the postcode is a Northern Ireland (BT) code.
  static bool isNorthernIrelandPostcode(String raw) {
    final String cleaned =
        raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.startsWith('BT');
  }

  // ─── Mapbox postcode validation ──────────────────────────────────────────

  /// Validates a postcode via Mapbox and returns town + coordinates.
  /// Returns null if the postcode is not recognised.
  Future<MapboxAddressResult?> validatePostcode(String postcode) async {
    final String normalised = normalise(postcode);
    try {
      final Uri uri = Uri.https(
        'api.mapbox.com',
        '/search/geocode/v6/forward',
        <String, String>{
          'q': normalised,
          'country': 'GB',
          'types': 'postcode',
          'limit': '1',
          'autocomplete': 'false',
          'access_token': _mapboxToken,
        },
      );

      final http.Response res =
          await http.get(uri).timeout(const Duration(seconds: 10));

      developer.log(
        'Mapbox postcode ${res.statusCode} for $normalised',
        name: 'AddressLookup',
      );

      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final Map<String, dynamic> decoded =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> features =
          (decoded['features'] as List<dynamic>?) ?? <dynamic>[];
      if (features.isEmpty) return null;

      final Map<String, dynamic> feature = _asMap(features.first);
      final Map<String, dynamic> props = _asMap(feature['properties']);
      final Map<String, dynamic> ctx = _asMap(props['context']);
      final Map<String, dynamic> geometry = _asMap(feature['geometry']);
      final List<dynamic> coords =
          (geometry['coordinates'] as List<dynamic>?) ?? <dynamic>[];

      double? lng;
      double? lat;
      if (coords.length >= 2) {
        lng = _toDouble(coords[0]);
        lat = _toDouble(coords[1]);
      }

      final String city = _readContextName(ctx, 'place') ??
          _readContextName(ctx, 'locality') ??
          _readContextName(ctx, 'district') ??
          '';

      final String fullAddress = _str(props['full_address']).isNotEmpty
          ? _str(props['full_address'])
          : _str(props['name']);

      return MapboxAddressResult(
        city: city,
        fullAddress: fullAddress,
        postcode: normalised,
        latitude: lat,
        longitude: lng,
      );
    } catch (e, st) {
      developer.log(
        'Mapbox error: $e',
        name: 'AddressLookup',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ─── City inference from postcode area ──────────────────────────────────

  /// Maps a UK postcode to the major city name.
  /// Two-letter area codes are checked before one-letter codes.
  /// Returns null if the postcode area is not mapped.
  static String? inferCityFromPostcode(String postcode) {
    final String area = postcode
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .replaceAll(RegExp(r'\d.*'), '');

    const Map<String, String> twoLetter = <String, String>{
      'AB': 'Aberdeen',
      'BA': 'Bath',
      'BB': 'Blackburn',
      'BD': 'Bradford',
      'BH': 'Bournemouth',
      'BL': 'Bolton',
      'BN': 'Brighton',
      'BR': 'London',
      'BS': 'Bristol',
      'CB': 'Cambridge',
      'CF': 'Cardiff',
      'CH': 'Chester',
      'CM': 'Chelmsford',
      'CO': 'Colchester',
      'CR': 'London',
      'CV': 'Coventry',
      'DA': 'London',
      'DD': 'Dundee',
      'DE': 'Derby',
      'DH': 'Durham',
      'DY': 'Wolverhampton',
      'EC': 'London',
      'EH': 'Edinburgh',
      'EN': 'London',
      'EX': 'Exeter',
      'FY': 'Blackpool',
      'GL': 'Gloucester',
      'HA': 'London',
      'HD': 'Huddersfield',
      'HU': 'Hull',
      'IG': 'London',
      'IP': 'Ipswich',
      'IV': 'Inverness',
      'KT': 'London',
      'LE': 'Leicester',
      'LL': 'Chester',
      'LN': 'Lincoln',
      'LS': 'Leeds',
      'LU': 'Luton',
      'ME': 'Chelmsford',
      'MK': 'Milton Keynes',
      'NE': 'Newcastle upon Tyne',
      'NG': 'Nottingham',
      'NN': 'Northampton',
      'NR': 'Norwich',
      'NW': 'London',
      'OX': 'Oxford',
      'PE': 'Peterborough',
      'PL': 'Plymouth',
      'PO': 'Portsmouth',
      'PR': 'Preston',
      'RG': 'Reading',
      'RM': 'London',
      'SA': 'Swansea',
      'SE': 'London',
      'SM': 'London',
      'SO': 'Southampton',
      'SR': 'Sunderland',
      'ST': 'Stoke-on-Trent',
      'SW': 'London',
      'TW': 'London',
      'UB': 'London',
      'WC': 'London',
      'WD': 'London',
      'WR': 'Worcester',
      'WS': 'Wolverhampton',
      'WV': 'Wolverhampton',
      'YO': 'York',
      'BT': 'Belfast',
    };

    if (area.length >= 2 && twoLetter.containsKey(area.substring(0, 2))) {
      return twoLetter[area.substring(0, 2)];
    }

    const Map<String, String> oneLetter = <String, String>{
      'B': 'Birmingham',
      'E': 'London',
      'G': 'Glasgow',
      'L': 'Liverpool',
      'M': 'Manchester',
      'N': 'London',
      'S': 'Sheffield',
      'W': 'London',
    };

    if (area.isNotEmpty && oneLetter.containsKey(area[0])) {
      return oneLetter[area[0]];
    }

    return null;
  }

  // ─── Reverse geocode ─────────────────────────────────────────────────────

  /// Reverse geocodes a lat/lng pair via Mapbox.
  Future<MapboxAddressResult?> reverseGeocode(
      double latitude, double longitude) async {
    try {
      final Uri uri = Uri.https(
        'api.mapbox.com',
        '/search/geocode/v6/reverse',
        <String, String>{
          'longitude': longitude.toString(),
          'latitude': latitude.toString(),
          'types': 'address',
          'limit': '1',
          'access_token': _mapboxToken,
        },
      );

      final http.Response res =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final Map<String, dynamic> decoded =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> features =
          (decoded['features'] as List<dynamic>?) ?? <dynamic>[];
      if (features.isEmpty) return null;

      final Map<String, dynamic> feature = _asMap(features.first);
      final Map<String, dynamic> props = _asMap(feature['properties']);
      final Map<String, dynamic> ctx = _asMap(props['context']);

      final String city = _readContextName(ctx, 'place') ??
          _readContextName(ctx, 'locality') ??
          _readContextName(ctx, 'district') ??
          '';

      final dynamic postcodeCtx = ctx['postcode'];
      String postcode = '';
      if (postcodeCtx is Map) {
        postcode = _str(Map<String, dynamic>.from(postcodeCtx)['name']);
      }

      final String fullAddress = _str(props['full_address']).isNotEmpty
          ? _str(props['full_address'])
          : _str(props['name']);

      return MapboxAddressResult(
        city: city,
        fullAddress: fullAddress,
        postcode: postcode,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _str(dynamic v) => v?.toString().trim() ?? '';

  static double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static String? _readContextName(Map<String, dynamic> ctx, String key) {
    final dynamic v = ctx[key];
    if (v is Map) {
      final String name = _str(Map<String, dynamic>.from(v)['name']);
      if (name.isNotEmpty) return name;
    }
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }
}

/// Result from Mapbox postcode validation.
class MapboxAddressResult {
  const MapboxAddressResult({
    required this.city,
    required this.fullAddress,
    required this.postcode,
    required this.latitude,
    required this.longitude,
  });

  /// Local area name from Mapbox (e.g. "Wembley", "Salford").
  final String city;

  /// Full formatted address string from Mapbox.
  final String fullAddress;

  /// Normalised postcode (e.g. "HA9 9PT").
  final String postcode;

  final double? latitude;
  final double? longitude;
}
