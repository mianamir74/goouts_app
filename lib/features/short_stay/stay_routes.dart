import 'package:flutter/material.dart';

import 'services/stay_availability_service.dart';
import 'guest/01_short_stay_home_screen.dart';
import 'guest/02_search_results_screen.dart';
import 'guest/03_search_filters_screen.dart';
import 'guest/04_map_results_screen.dart';
import 'guest/05_listing_detail_screen.dart';
import 'guest/06_amenities_full_screen.dart';
import 'guest/07_days_out_screen.dart';
import 'guest/08_cluster_detail_screen.dart';
import 'guest/09_neighbourhood_screen.dart';
import 'guest/10_whats_on_screen.dart';
import 'guest/11_booking_dates_screen.dart';
import 'guest/12_checkout_screen.dart';
import 'guest/13_booking_confirmed_screen.dart';
import 'guest/14_my_bookings_screen.dart';
import 'guest/15_trip_detail_screen.dart';
import 'guest/16_capture_intro_screen.dart';
// 17, 18, 19, 20 and 21 are no longer imported here. They are pure components
// with no data of their own, and routing straight to one opens it empty — a
// checklist with no rooms, a summary of no photographs. They are reached
// through capture_flow_screen.dart and capture_complete_host.dart, which own
// the booking and supply the props.
import 'guest/capture_complete_host.dart';
import 'models/stay_enums.dart';
import 'guest/capture_flow_screen.dart';
import 'guest/22_evidence_pack_screen.dart';
import 'guest/23_claim_notification_screen.dart';
import 'guest/24_contest_claim_screen.dart';
import 'guest/25_review_stay_screen.dart';
import 'guest/26_booking_details_screen.dart';
import 'guest/27_edit_booking_screen.dart';
import 'guest/28_cancel_booking_screen.dart';
import 'guest/29_cancellation_confirmed_screen.dart';
import 'models/stay_booking_request.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Short Stay routing.
//
// WHY THIS FILE EXISTS
// main.dart already holds a named route map with around 60 entries. Adding 29
// more would take it past 90 and make it the largest file in the app. Instead
// main.dart gains ONE line:
//
//     onGenerateRoute: StayRoutes.onGenerateRoute,
//
// THE RULE: PASS IDS, NEVER OBJECTS.
// A route argument holding a StayListing breaks deep links, breaks state
// restoration after the OS kills the app in the background, and is a known
// cause of null crashes on resume. Every route below takes a String id and the
// screen loads its own data.
// ─────────────────────────────────────────────────────────────────────────────

class StayRoutes {
  StayRoutes._();

  static const home                 = '/stay';
  static const results              = '/stay/results';
  static const filters              = '/stay/filters';
  static const map                  = '/stay/map';
  static const listing              = '/stay/listing';
  static const amenities            = '/stay/listing/amenities';
  static const daysOut              = '/stay/days-out';
  static const cluster              = '/stay/days-out/cluster';
  static const neighbourhood        = '/stay/neighbourhood';
  static const whatsOn              = '/stay/whats-on';
  static const bookingDates         = '/stay/book/dates';
  static const checkout             = '/stay/book/checkout';
  static const bookingConfirmed     = '/stay/book/confirmed';
  static const myBookings           = '/stay/bookings';
  static const trip                 = '/stay/trip';
  static const bookingDetails       = '/stay/booking';
  static const editBooking          = '/stay/booking/edit';
  static const cancelBooking        = '/stay/booking/cancel';
  static const cancellationDone     = '/stay/booking/cancelled';
  static const captureIntro         = '/stay/capture';
  static const captureChecklist     = '/stay/capture/checklist';
  static const cameraCapture        = '/stay/capture/camera';
  static const skipRoom             = '/stay/capture/skip';
  static const captureComplete      = '/stay/capture/complete';
  static const checkoutCapture      = '/stay/capture/checkout';
  static const evidencePack         = '/stay/evidence';
  static const claim                = '/stay/claim';
  static const contestClaim         = '/stay/claim/contest';
  static const review               = '/stay/review';

  /// Every route this feature owns. Used by the guard below so a typo in a
  /// route name produces a clear error rather than a blank screen.
  static const _all = <String>{
    home, results, filters, map, listing, amenities, daysOut, cluster,
    neighbourhood, whatsOn, bookingDates, checkout, bookingConfirmed,
    myBookings, trip, bookingDetails, editBooking, cancelBooking,
    cancellationDone, captureIntro, captureChecklist, cameraCapture, skipRoom,
    captureComplete, checkoutCapture, evidencePack, claim, contestClaim, review,
  };

  static bool owns(String? name) => name != null && _all.contains(name);

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (!owns(name)) return null; // not ours, let the app handle it

    final args = (settings.arguments as Map<String, dynamic>?) ?? const {};
    String id(String key) => (args[key] ?? '') as String;

    // ⚠ PARSED BEFORE page(), NOT AFTER.
    //
    // This used to sit BELOW the switch with `// ignore: unused_local_variable`
    // on it, under a note saying the screens would consume it later. That is
    // why "no listing is opening" was reported on 16 August: screen 02 passed
    // the id correctly, this file read it correctly, and then built
    // `const ListingDetailScreen()` — so every property in the results opened
    // the same hardcoded Richmond flat.
    //
    // The ignore comment is what hid it. An unused local the analyzer has been
    // told to stop mentioning is an unfinished wire that no longer reports
    // itself.
    //
    // RULE: anything parsed here must be PASSED to its screen in the switch
    // below, or not parsed at all.
    //
    // Every guest screen that needs an id now takes one. What remains
    // unwired is 07-10 (days out, cluster, neighbourhood, what's on), which
    // have no service behind them at all, and 23-25 (claims and reviews),
    // deferred under task #106 until payments exist.
    final listingId = id('listingId');
    final bookingId = id('bookingId');

    // Arrival or departure. Defaults to arrival via CaptureKind.from, which is
    // the safe way round: a missing value sends a guest to the check-in set
    // rather than silently recording arrival photographs as departure ones.
    final captureKind = CaptureKind.from(id('captureKind'));

    // A pending selection is a value, not a row — there is nothing to look up
    // until createStayBooking has run. Passed as an object for the same reason
    // StaySearchCriteria is: six loose keys in a map fail silently one at a
    // time, and `id('checkIn')` on a missing key returns '' rather than
    // complaining.
    final bookingRequest = args['request'] as StayBookingRequest?;

    Widget page() => switch (name) {
          home              => const ShortStayHomeScreen(),
          // The one route that takes a real object rather than an id. Search
          // criteria are a value, not a database row, so there is nothing to
          // look up — passing the id of something that does not exist would be
          // the worse choice here.
          results           => SearchResultsScreen(
                criteria: args['criteria'] as StaySearchCriteria?,
              ),
          filters           => const SearchFiltersSheet(),
          map               => const MapResultsScreen(),
          listing           => ListingDetailScreen(listingId: listingId),
          amenities         => AmenitiesFullScreen(listingId: listingId),
          daysOut           => const DaysOutScreen(),
          cluster           => const ClusterDetailScreen(),
          neighbourhood     => const NeighbourhoodScreen(),
          whatsOn           => const WhatsOnScreen(),
          bookingDates      => BookingDatesScreen(listingId: listingId),
          // Checkout cannot be opened cold — without a selection there is
          // nothing to price. Reached directly (a deep link, or a mistake in a
          // future screen) it says so instead of pricing a blank request.
          checkout          => bookingRequest == null
                ? const _StayRouteMissing()
                : CheckoutScreen(request: bookingRequest),
          bookingConfirmed  => BookingConfirmedScreen(bookingId: bookingId),
          // myBookings takes nothing on purpose — it queries the signed-in
          // guest's own bookings and there is no other guest it could show.
          myBookings        => const MyBookingsScreen(),
          trip              => TripDetailsScreen(bookingId: bookingId),
          bookingDetails    => BookingDetailsScreen(bookingId: bookingId),
          editBooking       => EditBookingScreen(bookingId: bookingId),
          cancelBooking     => CancelBookingScreen(bookingId: bookingId),
          cancellationDone  =>
              CancellationConfirmedScreen(bookingId: bookingId),
          // ── CAPTURE ──────────────────────────────────────────────────
          //
          // captureChecklist maps to CaptureFlowScreen, NOT to
          // CaptureChecklistScreen. 17 is a pure component with no data of its
          // own; routed directly it opens with `rooms: const []` and shows
          // "nothing to photograph" for ever. The flow screen owns the booking
          // and feeds it. Same for captureComplete and screen 20.
          //
          // cameraCapture and skipRoom are NOT routed to any more. They are
          // pushed by CaptureFlowScreen with the callbacks that make them do
          // something — reached through a route name they would have no way to
          // save a photograph. They stay in the switch only to say so.
          captureIntro      => DepositProtectionScreen(
                bookingId: bookingId,
                kind: captureKind,
              ),
          captureChecklist  => CaptureFlowScreen(
                bookingId: bookingId,
                kind: captureKind,
              ),
          cameraCapture     => const _StayRouteMissing(),
          skipRoom          => const _StayRouteMissing(),
          captureComplete   => CaptureCompleteHost(
                bookingId: bookingId,
                kind: captureKind,
              ),
          checkoutCapture   => CaptureFlowScreen(
                bookingId: bookingId,
                kind: CaptureKind.guestCheckOut,
              ),
          evidencePack      => EvidencePackScreen(bookingId: bookingId),
          claim             => const ClaimNotificationScreen(),
          contestClaim      => const ContestClaimScreen(),
          review            => const ReviewStayScreen(),
          _                 => const _StayRouteMissing(),
        };

    // Sheets present from the bottom, full screens push normally.
    final isSheet = name == filters || name == skipRoom;
    return MaterialPageRoute<dynamic>(
      settings: settings,
      fullscreenDialog: isSheet,
      builder: (_) => page(),
    );
  }
}

class _StayRouteMissing extends StatelessWidget {
  const _StayRouteMissing();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'That page could not be opened. Please go back and try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
