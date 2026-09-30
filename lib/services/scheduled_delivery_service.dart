import 'package:flutter/foundation.dart';

/// Holds the user's chosen delivery time for their CURRENT food order —
/// null means "Deliver now" (the default), a DateTime means a scheduled
/// future slot.
///
/// ⚠ ADDED 10 September 2026, replacing a local `_scheduledFor` field that
/// used to live only inside FoodDeliveryScreen's State — it was lost the
/// moment the user navigated into a restaurant's menu or checkout, so the
/// picker looked like it worked but the choice never survived past the
/// landing page. Singleton, same pattern as DeliveryAddressService, so the
/// selection made here is still visible on checkout_screen.dart.
///
/// ⚠ NOT PERSISTED to SharedPreferences on purpose (unlike the address).
/// A stale "deliver at 6pm" surviving a phone restart and silently
/// attaching itself to a brand new order placed days later is a worse bug
/// than just asking again — this resets to "Deliver now" every fresh app
/// session.
class ScheduledDeliveryService extends ChangeNotifier {
  static final ScheduledDeliveryService _instance =
      ScheduledDeliveryService._internal();
  factory ScheduledDeliveryService() => _instance;
  ScheduledDeliveryService._internal();

  DateTime? _scheduledFor;
  DateTime? get scheduledFor => _scheduledFor;

  bool get isScheduled => _scheduledFor != null;

  void set(DateTime? value) {
    _scheduledFor = value;
    notifyListeners();
  }

  void clear() => set(null);
}
