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
  const DaysOutScreen({super.key, required this.listingId});

  /// ⚠ REQUIRED. This screen used to take nothing, which is part of why it was
  /// never wired: with no property it cannot know which city to show or which
  /// clusters are nearest.
  final String listingId;

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
      // The town on the property decides the city document. A property with no
      // town simply has no days out, which is the honest outcome rather than
      // guessing a city from a postcode prefix.
      final StayAttractions? a = l == null
          ? null
          : await StayAttractionsService.instance.forTown(l.address.town);
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
        toolbarHeight: 52,
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
        title: Text('Days out from your stay',
            style: _screenTitle.copyWith(color: GoOutsColors.primaryBlue)),
      ),
      bottomNavigationBar: const StayBottomNav(current: StayTab.trips),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : clusters.isEmpty
              ? _empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: <Widget>[
                    Text(
                      'Grouped by what you can do in one trip, nearest first.',
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
                ),
    );
  }

  /// Shown when we have not built this city yet.
  ///
  /// ⚠ SAYS WHAT IS ACTUALLY TRUE. Not "no days out near you", which would be
  /// false for every city in Britain. The data is missing, not the attractions.
  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.map_outlined,
                  size: 48, color: GoOutsColors.primaryBlue),
              const SizedBox(height: 12),
              Text('We have not mapped this area yet',
                  textAlign: TextAlign.center,
                  style: _cardTitle.copyWith(color: GoOutsColors.deepNavy)),
              const SizedBox(height: 6),
              Text(
                'Days out are added city by city. Your host and the partners '
                'near your stay are still on the trip screen.',
                textAlign: TextAlign.center,
                style: _body.copyWith(color: GoOutsColors.bodyText),
              ),
            ],
          ),
        ),
      );

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
