import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/scheduled_delivery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  "Deliver now" / scheduled-delivery time picker — shared between
//  food_delivery_screen.dart (where the choice is first made) and
//  checkout_screen.dart (where it can be reviewed/changed before paying).
//
//  ⚠ ADDED 10 September 2026. MIN_LEAD_MINUTES/MAX_LEAD_DAYS mirror the
//  bounds enforced server-side in createFoodOrder (food_orders.js) — kept
//  in sync deliberately so this picker never offers a time the server will
//  then refuse. If one changes, change the other.
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary = Color(0xFF0392CA);
const Color _kNavy = Color(0xFF0D1B3E);

/// Minimum notice a restaurant needs before a scheduled slot — matches
/// food_orders.js's own MIN_SCHEDULE_LEAD_MINUTES.
const int kMinScheduleLeadMinutes = 20;

/// How far ahead a slot may be booked — matches food_orders.js's own
/// MAX_SCHEDULE_LEAD_DAYS.
const int kMaxScheduleLeadDays = 7;

String deliveryTimeLabel(BuildContext context, DateTime? t) {
  if (t == null) return 'Deliver now';
  final DateTime now = DateTime.now();
  final bool isToday =
      t.year == now.year && t.month == now.month && t.day == now.day;
  final DateTime tomorrow = now.add(const Duration(days: 1));
  final bool isTomorrow = t.year == tomorrow.year &&
      t.month == tomorrow.month &&
      t.day == tomorrow.day;
  final String time = TimeOfDay.fromDateTime(t).format(context);
  if (isToday) return 'Today, $time';
  if (isTomorrow) return 'Tomorrow, $time';
  const List<String> weekdays = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  return '${weekdays[t.weekday - 1]} ${t.day}, $time';
}

// ⚠ FIXED 10 September 2026 — reported as "schedule delivery only shows
// the date". Root cause: the date-picker's own onTap called
// `Navigator.of(sheetContext).pop()` (closing the bottom sheet) and THEN
// awaited `pickScheduledDateTime(context)` using a `context` that belonged
// to a widget INSIDE that same sheet — pop() tears that context down
// immediately, so by the time the awaited showDatePicker call returned,
// the context was already unmounted. showTimePicker's own `context.mounted`
// guard then silently aborted before ever opening — the date picker had
// already shown (the removal isn't always synchronous within the same
// microtask), so it looked like "asks for a date, then just stops", not a
// crash. Fix: the ORIGINAL page context passed into showDeliveryTimeSheet
// (pageContext below) outlives the sheet — that is what every picker call
// after the sheet closes must use, never the sheet's own builder context.
Future<void> showDeliveryTimeSheet(BuildContext pageContext) async {
  final ScheduledDeliveryService service = ScheduledDeliveryService();
  await showModalBottomSheet<void>(
    context: pageContext,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => ListenableBuilder(
      listenable: service,
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Text('When would you like this?',
                    style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kNavy)),
                const SizedBox(height: 14),
                _timeOptionTile(
                  icon: Icons.bolt_rounded,
                  label: 'Deliver now',
                  selected: service.scheduledFor == null,
                  onTap: () {
                    service.clear();
                    Navigator.of(sheetContext).pop();
                  },
                ),
                const SizedBox(height: 8),
                _timeOptionTile(
                  icon: Icons.event_rounded,
                  label: service.scheduledFor != null
                      ? 'Scheduled: ${deliveryTimeLabel(context, service.scheduledFor)}'
                      : 'Schedule for later',
                  selected: service.scheduledFor != null,
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    // pageContext, NOT context/sheetContext — see the note
                    // above showDeliveryTimeSheet for why.
                    await pickScheduledDateTime(pageContext);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _timeOptionTile({
  required IconData icon,
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: selected ? _kPrimary.withValues(alpha: 0.08) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: selected ? _kPrimary : Colors.transparent, width: 1.4),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: selected ? _kPrimary : Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? _kPrimary : _kNavy)),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 18, color: _kPrimary),
        ],
      ),
    ),
  );
}

/// Real date + time selection using Flutter's own pickers — reliable,
/// accessible, and already themed to match the rest of the app.
Future<void> pickScheduledDateTime(BuildContext context) async {
  final ScheduledDeliveryService service = ScheduledDeliveryService();
  final DateTime now = DateTime.now();
  final DateTime? date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: now,
    lastDate: now.add(Duration(days: kMaxScheduleLeadDays)),
  );
  if (date == null || !context.mounted) return;

  final DateTime earliest = now.add(Duration(minutes: kMinScheduleLeadMinutes));
  final TimeOfDay initial = TimeOfDay.fromDateTime(earliest);
  final TimeOfDay? time = await showTimePicker(
    // ignore: use_build_context_synchronously
    context: context,
    initialTime: initial,
  );
  if (time == null || !context.mounted) return;

  DateTime picked =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
  // Guard against picking a slot sooner than the restaurant/driver pipeline
  // can realistically honour — matches the server's own MIN_SCHEDULE_LEAD.
  if (picked.isBefore(earliest)) picked = earliest;

  service.set(picked);
}
