// ─────────────────────────────────────────────────────────────────────────────
//  Days out from your stay.
//
//  WIRED 28 August 2026. It had been a live route with nothing behind it since
//  3 August: every handler empty, no service, no data. stay_routes.dart:129
//  recorded it and nothing changed until now.
//
//  ── WHERE THE DATA COMES FROM ───────────────────────────────────────────────
//
//  stay_attractions/{citySlug}, built once per city from OpenStreetMap by
//  buildCityAttractions. Not Google Places: the Maps terms forbid warehousing
//  anything but place_id, so a Places version would pay for a live lookup per
//  attraction every time this screen opened, for museums that have not moved in
//  a century. OSM is ODbL and may be stored permanently.
//
//  ⚠ ODbL REQUIRES THE ATTRIBUTION AT THE BOTTOM OF THIS SCREEN. It is read
//  from the document rather than hardcoded here, so the obligation travels with
//  the data. Do not remove it to tidy the layout.
//
//  ── ⚠ MILES, NEVER MINUTES ──────────────────────────────────────────────────
//
//  The Stitch design says "About 35 minutes from your door" on every card. We
//  have no routing API, and a straight line between two points is not a
//  journey time. Distance is measured; a travel time would be invented, and
//  this is a screen somebody plans an afternoon around.
//
//  ── ⚠ THE PARTNER COUNT LEADS EACH CARD ─────────────────────────────────────
//
//  It is the only line here no other travel app can write. A photograph of the
//  Natural History Museum makes this look like every other guide; "7 GoOuts
//  partners nearby for lunch" does not.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/stay_attraction.dart';
import '../models/stay_listing.dart';
import '../services/stay_attractions_service.dart';
import '../services/stay_listing_service.dart';
import '../stay_routes.dart';
import '../theme/stay_colors.dart';
import '../widgets/stay_bottom_nav.dart';

class DaysOutScreen extends StatefulWidget {
  const DaysOutScreen({
    super.key,
    required this.listingId,
    this.fromListing = false,
  });

  /// ⚠ REQUIRED. This screen used to take nothing, which is part of why it was
  /// never wired: with no property it cannot know which city to show or which
  /// clusters are nearest.
  final String listingId;

  /// True when a guest arrived here from the PROPERTY screen while browsing,
  /// rather than from the trip screen after booking.
  ///
  /// ── ⚠ IT DECIDES WHICH BOTTOM TAB IS LIT, AND THAT MATTERS ────────────────
  ///
  ///  Until 29 August 2026 this screen was reachable only from the trip screen,
  ///  so Trips was always the right tab. Days out now appear on the property
  ///  screen too, and a guest who is BROWSING is not in Trips — they are in
  ///  Search.
  ///
  ///  Lighting the wrong tab is not cosmetic. The tab you are already on does
  ///  nothing when tapped, by design, so a browsing guest who taps Search to
  ///  get back gets a working button that throws away the property they were
  ///  reading — pushNamedAndRemoveUntil drops the whole stack. Telling them
  ///  they are in Trips makes Search look like the way out. It is the way out
  ///  of everything.
  final bool fromListing;

  @override
  State<DaysOutScreen> createState() => _DaysOutScreenState();
}

class _DaysOutScreenState extends State<DaysOutScreen> {
  StayListing? _listing;
  StayAttractions? _attractions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final StayListing? l =
          await StayListingService.instance.byId(widget.listingId);
      // ⚠ THE PROPERTY'S COORDINATES DECIDE THE DOCUMENT, NOT ITS TOWN NAME.
      // The town is still passed as a fallback while the grid sweep runs; see
      // forProperty. A property with neither has no days out, which is the
      // honest outcome rather than guessing from a postcode prefix.
      final StayAttractions? a = l == null
          ? null
          : await StayAttractionsService.instance.forProperty(
              lat: l.lat,
              lng: l.lng,
              town: l.address.town,
            );
      if (!mounted) return;
      setState(() {
        _listing = l;
        _attractions = a;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ── Stitch scale ──────────────────────────────────────────────────────────
  static TextStyle get _screenTitle => GoogleFonts.inter(
      fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w700);
  static TextStyle get _cardTitle => GoogleFonts.inter(
      fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
  static TextStyle get _body =>
      GoogleFonts.inter(fontSize: 13.5, height: 20 / 13.5);
  static TextStyle get _caption =>
      GoogleFonts.inter(fontSize: 12, height: 16 / 12);

  @override
  Widget build(BuildContext context) {
    final List<StayCluster> clusters = StayAttractionsService.nearest(
      _attractions?.clusters ?? const <StayCluster>[],
      _listing?.lat,
      _listing?.lng,
    );

    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      appBar: AppBar(
        backgroundColor: GoOutsColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: GoOutsColors.outlineVariant, width: 0.5),
        ),
        // ⚠ A REAL BUTTON. This was a bare Icon with no gesture handling, the
        // same fault screens 01 and 06 had: it looked like a working app bar
        // and the only way to notice was to press it.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GoOutsColors.primaryBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // ⚠ THE PROPERTY NAME UNDER THE TITLE, when we know it.
        //
        // A guest who came here from a property is two screens deep in that
        // property's context and nothing on the page said so. Naming it makes
        // the back arrow's destination obvious instead of something they have
        // to try — which is the whole question "how do I get back to the one I
        // liked" is asking.
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Days out',
                style: _screenTitle.copyWith(color: GoOutsColors.primaryBlue)),
            if (_listing != null)
              Text(
                'from ${_listing!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body.copyWith(color: GoOutsColors.bodyText),
              ),
          ],
        ),
        toolbarHeight: _listing == null ? 52 : 62,
      ),
      bottomNavigationBar: StayBottomNav(
        current: widget.fromListing ? StayTab.search : StayTab.trips,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop = kIsWeb && constraints.maxWidth >= 900;
          final Widget content = _loading
          ? const Center(child: CircularProgressIndicator())
          : clusters.isEmpty
              ? _empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: <Widget>[
                    Text(
                      // ⚠ THE LEAD LINE CHANGES WHEN THE NEAREST IS A DRIVE.
                      //
                      // "Nearest first" is fine in a city and slightly absurd
                      // in the Highlands, where the nearest is 30 miles off. A
                      // guest who reads it and then sees 34 miles on the first
                      // card concludes the screen is broken. Saying it plainly
                      // costs nothing and is simply true: in the countryside a
                      // day out is a drive, and people staying there know that
                      // better than we do.
                      _leadLine(clusters),
                      style: _body.copyWith(color: GoOutsColors.bodyText),
                    ),
                    const SizedBox(height: 16),
                    for (final StayCluster c in clusters) ...<Widget>[
                      _clusterCard(c),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                    _attributionLine(),
                  ],
                );
          if (!desktop) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: content,
            ),
          );
        },
      ),
    );
  }

  /// The line above the list, which depends on how far the nearest one is.
  String _leadLine(List<StayCluster> clusters) {
    final double? lat = _listing?.lat;
    final double? lng = _listing?.lng;
    if (clusters.isEmpty || lat == null || lng == null) {
      return 'Grouped by what you can do in one trip, nearest first.';
    }
    final double mi = StayAttractionsService.milesBetween(
        lat, lng, clusters.first.lat, clusters.first.lng);
    if (mi < 12) {
      return 'Grouped by what you can do in one trip, nearest first.';
    }
    return 'You are somewhere quiet, so these are a drive rather than a walk. '
        'The nearest is about ${mi.round()} miles away.';
  }

  /// Shown when there is nothing to list.
  ///
  /// ── ⚠ TWO DIFFERENT FACTS, AND THEY USED TO SHARE ONE MESSAGE ─────────────
  ///
  ///  "We have not built this area yet" and "we have looked and there is
  ///  genuinely very little near you" are not the same thing, and until the
  ///  grid shipped there was no way to tell them apart, so both said the
  ///  first one.
  ///
  ///  Now a built cell exists even when it holds nothing, which is exactly
  ///  what makes the difference knowable: _attractions is null only when the
  ///  sweep has not reached here.
  ///
  ///  ⚠ THE SECOND MESSAGE MUST NOT SAY "no days out near you" EITHER. The
  ///  app searched about 40 miles and found nothing it would stake its name
  ///  on. That is a statement about our list, not about the countryside, and
  ///  a guest staying in the Highlands knows perfectly well there is plenty
  ///  out there. Claiming otherwise makes us look wrong rather than modest.
  Widget _empty() {
    final bool notBuilt = _attractions == null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(notBuilt ? Icons.map_outlined : Icons.landscape_outlined,
                size: 48, color: GoOutsColors.primaryBlue),
            const SizedBox(height: 12),
            Text(
              notBuilt
                  ? 'We have not mapped this area yet'
                  : 'Nothing on our list within about 40 miles',
              textAlign: TextAlign.center,
              style: _cardTitle.copyWith(color: GoOutsColors.deepNavy),
            ),
            const SizedBox(height: 6),
            Text(
              notBuilt
                  ? 'We are working through the country a region at a time. '
                      'Your host and the partners near your stay are still on '
                      'the trip screen.'
                  : 'That says more about our list than about where you are '
                      'staying. Your host will know the area far better than '
                      'we do, and the partners near your stay are still on '
                      'the trip screen.',
              textAlign: TextAlign.center,
              style: _body.copyWith(color: GoOutsColors.bodyText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clusterCard(StayCluster c) {
    final double? lat = _listing?.lat;
    final double? lng = _listing?.lng;
    final double? mi = (lat != null && lng != null)
        ? StayAttractionsService.milesBetween(lat, lng, c.lat, c.lng)
        : null;

    return Material(
      color: GoOutsColors.cardSurface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(
          StayRoutes.cluster,
          arguments: <String, dynamic>{
            'listingId': widget.listingId,
            'clusterId': c.id,
            // ⚠ CARRIED THROUGH, not defaulted. Without this the flag survives
            // exactly one hop: a guest going property → days out → a day out
            // would see Search lit on the middle screen and Trips on the last
            // one, in the same journey. Any screen that passes a journey along
            // has to pass the whole journey.
            'fromListing': widget.fromListing,
          },
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (c.photo != null) _photo(c.photo!),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(c.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _cardTitle.copyWith(color: GoOutsColors.deepNavy)),
                  // ⚠ TWO LINES ON THE CARD, THE WHOLE THING ON SCREEN 08.
                  // A description is what turns a name into a reason to go,
                  // and the card is where somebody is scanning for one. Two
                  // lines is enough to sell it and short enough to keep the
                  // cards the same height as each other.
                  if (c.hasAbout) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      c.about,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _body.copyWith(color: GoOutsColors.bodyText),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.straighten_rounded,
                          size: 14, color: GoOutsColors.bodyText),
                      const SizedBox(width: 5),
                      Text(
                        // Miles, never minutes. See the header.
                        mi == null
                            ? '${c.placeCount} places'
                            : '${mi.toStringAsFixed(1)} miles from your stay · '
                                '${c.placeCount} places',
                        style: _caption.copyWith(color: GoOutsColors.bodyText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    c.places.take(3).map((p) => p.name).join(', ') +
                        (c.placeCount > 3 ? ' and more' : ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _body.copyWith(color: GoOutsColors.bodyText),
                  ),
                ],
              ),
            ),
            // The partner banner, only when there are partners. A "0 partners
            // nearby" strip would advertise the absence of the thing this
            // product is for.
            if (c.partnerCount > 0) _partnerBanner(c),
          ],
        ),
      ),
    );
  }

  /// ⚠ THE CREDIT IS PART OF THE IMAGE, NOT DECORATION.
  ///
  /// Wikimedia licences differ per photograph and several require naming the
  /// photographer. StayPhotoCredit only exists when a licence was readable, so
  /// if there is a picture here there is a credit, and both render or neither
  /// does. Removing the caption to tidy the card is the one edit nobody is
  /// allowed to make.
  Widget _photo(StayPhotoCredit p) => Stack(
        children: <Widget>[
          Image.network(
            p.url,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 900,
            errorBuilder: (_, __, ___) => Container(
              height: 150,
              color: GoOutsColors.paleBlueTint,
              child: const Icon(Icons.photo_outlined,
                  color: GoOutsColors.primaryBlue),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: Colors.black.withValues(alpha: 0.45),
              child: Text(
                p.creditLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    height: 14 / 10,
                    color: Colors.white.withValues(alpha: 0.9)),
              ),
            ),
          ),
        ],
      );

  Widget _partnerBanner(StayCluster c) => Container(
        width: double.infinity,
        color: GoOutsColors.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.local_offer_outlined, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${c.partnerCount} GoOuts '
                    '${c.partnerCount == 1 ? 'partner' : 'partners'} nearby',
                    style: GoogleFonts.inter(
                        fontSize: 13.5,
                        height: 20 / 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  if (c.partnerSummary.isNotEmpty)
                    Text(c.partnerSummary,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 16 / 12,
                            color: Colors.white.withValues(alpha: 0.85))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      );

  /// ⚠ REQUIRED BY ODbL. Not optional and not cosmetic.
  Widget _attributionLine() {
    final StayAttractions? a = _attractions;
    if (a == null) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        onPressed: () => launchUrl(Uri.parse(a.attributionUrl),
            mode: LaunchMode.externalApplication),
        child: Text(
          '${a.attribution} · ODbL',
          style: _caption.copyWith(color: GoOutsColors.bodyText),
        ),
      ),
    );
  }
}
