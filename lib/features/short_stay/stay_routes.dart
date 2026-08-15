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
import 'guest/17_capture_checklist_screen.dart';
import 'guest/18_camera_capture_screen.dart';
import 'guest/19_skip_room_sheet_screen.dart';
import 'guest/20_capture_complete_screen.dart';
import 'guest/21_checkout_capture_screen.dart';
import 'guest/22_evidence_pack_screen.dart';
import 'guest/23_claim_notification_screen.dart';
import 'guest/24_contest_claim_screen.dart';
import 'guest/25_review_stay_screen.dart';
import 'guest/26_booking_details_screen.dart';
import 'guest/27_edit_booking_screen.dart';
import 'guest/28_cancel_booking_screen.dart';
import 'guest/29_cancellation_confirmed_screen.dart';

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
          listing           => const ListingDetailScreen(),
          amenities         => const AmenitiesFullScreen(),
          daysOut           => const DaysOutScreen(),
          cluster           => const ClusterDetailScreen(),
          neighbourhood     => const NeighbourhoodScreen(),
          whatsOn           => const WhatsOnScreen(),
          bookingDates      => const BookingDatesScreen(),
          checkout          => const CheckoutScreen(),
          bookingConfirmed  => const BookingConfirmedScreen(),
          myBookings        => const MyBookingsScreen(),
          trip              => const TripDetailsScreen(),
          bookingDetails    => const BookingDetailsScreen(),
          editBooking       => const EditBookingScreen(),
          cancelBooking     => const CancelBookingScreen(),
          cancellationDone  => const CancellationConfirmedScreen(),
          captureIntro      => const DepositProtectionScreen(),
          captureChecklist  => const CaptureChecklistScreen(),
          cameraCapture     => const CameraCaptureScreen(),
          skipRoom          => const SkipRoomSheet(),
          captureComplete   => const CaptureCompleteScreen(),
          checkoutCapture   => const CheckoutCaptureScreen(),
          evidencePack      => const EvidencePackScreen(),
          claim             => const ClaimNotificationScreen(),
          contestClaim      => const ContestClaimScreen(),
          review            => const ReviewStayScreen(),
          _                 => const _StayRouteMissing(),
        };

    // TODO wiring, task 116. Each screen will take its id from `id('...')`
    // once it loads real data. Ids are already parsed above so the call sites
    // can start passing them before the screens consume them.
    // ignore: unused_local_variable
    final listingId = id('listingId');
    // ignore: unused_local_variable
    final bookingId = id('bookingId');

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
