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
import 'guest/30_message_host_screen.dart';
import 'guest/27_edit_booking_screen.dart';
import 'guest/28_cancel_booking_screen.dart';
import 'guest/29_cancellation_confirmed_screen.dart';
import 'models/stay_booking_request.dart';
// For the typed cast of args['listings'] on the map route.
import 'models/stay_listing.dart';

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
  // The guest half of stay_bookings/{id}/messages. The host half lives in
  // goouts_host at HostRoutes.guestThread and writes the same documents.
  static const messageHost          = '/stay/booking/messages';

  /// Every route this feature owns. Used by the guard below so a typo in a
  /// route name produces a clear error rather than a blank screen.
  static const _all = <String>{
    home, results, filters, map, listing, amenities, daysOut, cluster,
    neighbourhood, bookingDates, checkout, bookingConfirmed,
    myBookings, trip, bookingDetails, editBooking, cancelBooking,
    cancellationDone, captureIntro, captureChecklist, cameraCapture, skipRoom,
    captureComplete, checkoutCapture, evidencePack, claim, contestClaim, review,
    messageHost,
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
    // Every guest screen that needs an id now takes one.
    //
    // Updated 28 August 2026. 07 (days out) and 08 (cluster detail) ARE now
    // wired, to stay_attractions/{citySlug} built from OpenStreetMap. Both take
    // a listingId, which is what they lacked.
    //
    // Still unwired: 09 (neighbourhood) and 10 (what's on). 10 needs DATED
    // EVENTS, which OpenStreetMap does not hold — that is a PredictHQ or
    // Ticketmaster job and is deliberately deferred rather than faked.
    // 23-25 (claims and reviews) remain deferred under task #106.
    final listingId = id('listingId');
    final bookingId = id('bookingId');

    // ⚠ ARGUMENTS IN THIS APP ARE A MAP, NOT A BARE STRING.
    //
    // Added 25 August 2026 with the claims wiring. I first wrote these two
    // screens reading `settings.arguments as String`, copying the host app's
    // convention — and the host app IS a bare string, so it looked right.
    // Here it would have been null every single time: the cast fails silently
    // and both screens would have opened blank, on the one journey where blank
    // means somebody cannot find out why they are being asked for £150.
    //
    // Two apps, two conventions, each internally consistent. Read the
    // generator, do not assume the other one.
    final claimId = id('claimId');

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
          // ⚠ TAKES THE CRITERIA. Fixed 29 August 2026, and it is the exact
          // fault this file warns about thirty lines above: screen 02 has
          // always pushed `arguments: {'criteria': _criteria}` here, and this
          // line answered with `const SearchFiltersSheet()` and dropped it.
          //
          // The sheet therefore opened blank every time, and — worse — applied
          // its result onto an EMPTY criteria, discarding the town, the dates
          // and the guest count. Filtering by price in Richmond returned the
          // whole country. See _apply in 03_search_filters_screen.dart.
          filters           => SearchFiltersSheet(
                initial: args['criteria'] as StaySearchCriteria?,
              ),
          // ⚠ TAKES THE RESULTS. Fixed 29 August 2026. MapResultsScreen has
          // always accepted `listings`, and this line built it `const` — so
          // the list was empty on every open and the screen showed its own
          // "Nothing to show on the map" empty state, permanently. A live
          // route with no data behind it, exactly as 07 and 08 were.
          //
          // The results are PASSED rather than re-queried on purpose, so the
          // map and the list cannot disagree about what was found.
          map               => MapResultsScreen(
                listings: (args['listings'] as List<StayListing>?) ??
                    const <StayListing>[],
                criteria: args['criteria'] as StaySearchCriteria?,
              ),
          listing           => ListingDetailScreen(listingId: listingId),
          amenities         => AmenitiesFullScreen(listingId: listingId),
          // ── WIRED 28 August 2026. Both took NOTHING before, which is part of
          // why they were never wired: with no property they cannot know which
          // city to read or which day out is nearest. See stay_attractions.js.
          // ⚠ fromListing DECIDES WHICH BOTTOM TAB IS LIT. Added 29 August
          // 2026, when days out started appearing on the property screen as
          // well as the trip screen.
          //
          // A browsing guest is in Search, not Trips. Lighting Trips is not
          // cosmetic: the active tab does nothing when tapped, so it makes
          // Search look like the way back — and Search is
          // pushNamedAndRemoveUntil, which throws away the property they were
          // reading. See the note on DaysOutScreen.fromListing.
          daysOut           => DaysOutScreen(
                listingId: listingId,
                fromListing: args['fromListing'] == true,
              ),
          cluster           => ClusterDetailScreen(
                listingId: listingId,
                clusterId: id('clusterId'),
                fromListing: args['fromListing'] == true,
              ),
          // ⚠ WIRED 29 August 2026, and it takes the property. This was
          // `const NeighbourhoodScreen()` in front of a screen whose "map" was
          // an Unsplash photograph of a city from above with Positioned() pins
          // at fixed pixel offsets on top of it, and every handler empty.
          //
          // The data had been there the whole time: locationContext
          // .nearestPartners, up to ten partners within three miles with a
          // name, a category, a distance and a cashback rate, written by
          // enrichListingLocation and only ever surfaced as a COUNT.
          neighbourhood     => NeighbourhoodScreen(listingId: listingId),
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
          messageHost       => MessageHostScreen(bookingId: bookingId),
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
          // ⚠ NOT const, AND THEY TAKE THE CLAIM ID. Wired 25 August 2026 —
          // these were Stitch shells with empty handlers and a route that
          // passed them nothing. A claim screen with no claim on it is a blank
          // page where somebody expected to find out why they are being asked
          // for £150. Both fall back to settings.arguments so a plain
          // pushNamed(claim, arguments: id) works from a push notification tap.
          claim             => ClaimNotificationScreen(claimId: claimId),
          contestClaim      => ContestClaimScreen(claimId: claimId),
          // ⚠ TAKES THE BOOKING. Wired 29 August 2026. This was
          // `const ReviewStayScreen()` in front of a screen that accepted
          // nothing, and NOTHING PUSHED IT — a live route with no way in, over
          // a form that could not have known which stay it was about. See
          // functions/stay_reviews.js for what was behind it, which was
          // nothing at all: every real listing sat at ratingAvg 0 while four
          // screens read reviews that only the demo seed could produce.
          review            => ReviewStayScreen(bookingId: bookingId),
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
