import 'package:flutter/material.dart';

/// Venue amenities chosen in Admin Panel > Partner Management (field
/// `amenities`, a list of these keys). Shared by the app and the Admin Panel
/// copy so the two lists never drift apart. Added 10 Nov 2026.
class PartnerAmenities {
  static const List<(String, String, IconData)> all = [
    ('wifi', 'Wi-Fi', Icons.wifi_rounded),
    ('seating', 'Seating', Icons.chair_rounded),
    ('charging', 'Charging', Icons.bolt_rounded),
    ('pets', 'Pet friendly', Icons.pets_rounded),
    ('outdoor', 'Outdoor seating', Icons.deck_rounded),
    ('wheelchair', 'Wheelchair access', Icons.accessible_rounded),
    ('toilets', 'Toilets', Icons.wc_rounded),
    ('parking', 'Parking', Icons.local_parking_rounded),
    ('family', 'Family friendly', Icons.family_restroom_rounded),
    ('sports', 'Live sports', Icons.sports_soccer_rounded),
    ('takeaway', 'Takeaway', Icons.takeout_dining_rounded),
  ];

  /// From a whole partner record: the `amenities` list if set, otherwise the
  /// older yes/no fields (hasWifi, hasSeating, hasCharging, allowsPets).
  static List<(String, String, IconData)> fromDoc(Map<String, dynamic>? d) {
    if (d == null) return const [];
    if (d['amenities'] is List) return fromList(d['amenities']);
    return fromList([
      if (d['hasWifi'] == true) 'wifi',
      if (d['hasSeating'] == true) 'seating',
      if (d['hasCharging'] == true) 'charging',
      if (d['allowsPets'] == true) 'pets',
    ]);
  }

  /// Accepts keys ("wifi") or labels ("Wi-Fi"), in any case.
  static List<(String, String, IconData)> fromList(dynamic raw) {
    if (raw is! List) return const [];
    final want = raw.map((e) => e.toString().toLowerCase().trim()).toSet();
    return all
        .where((a) => want.contains(a.$1) || want.contains(a.$2.toLowerCase()))
        .toList();
  }
}
