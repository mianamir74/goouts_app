// ─────────────────────────────────────────────────────────────────────────────
//  One day out, in full.
//
//  WIRED 28 August 2026, with screen 07. Live route, no data, no handlers since
//  3 August. See stay_routes.dart:129 and stay_attractions.js.
//
//  Reads the same stay_attractions/{citySlug} document screen 07 reads, through
//  the same cached service, so opening a cluster costs no extra Firestore read.
//
//  ⚠ MILES, NEVER MINUTES, for the reason given in 07. And the ODbL attribution
//  is required at the bottom, read from the document rather than hardcoded.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/stay_attraction.dart';
import '../models/stay_listing.dart';
import '../services/stay_attractions_service.dart';
import '../services/stay_listing_service.dart';
import '../theme/stay_colors.dart';
import '../widgets/stay_bottom_nav.dart';

class ClusterDetailScreen extends StatefulWidget {
  const ClusterDetailScreen({
    super.key,
    required this.listingId,
    required this.clusterId,
  });

  final String listingId;
  final String clusterId;

  @override
  State<ClusterDetailScreen> createState() => _ClusterDetailScreenState();
}

class _ClusterDetailScreenState extends State<ClusterDetailScreen> {
  StayListing? _listing;
  StayAttractions? _attractions;
  StayCluster? _cluster;
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
      final StayAttractions? a = l == null
          ? null
          : await StayAttractionsService.instance.forTown(l.address.town);

      StayCluster? found;
      for (final StayCluster c in a?.clusters ?? const <StayCluster>[]) {
        if (c.id == widget.clusterId) {
          found = c;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _listing = l;
        _attractions = a;
        _cluster = found;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  static TextStyle get _screenTitle => GoogleFonts.inter(
      fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w700);
  static TextStyle get _sectionHeader => GoogleFonts.inter(
      fontSize: 15,
      height: 20 / 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3);
  static TextStyle get _cardTitle => GoogleFonts.inter(
      fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600);
  static TextStyle get _body =>
      GoogleFonts.inter(fontSize: 13.5, height: 20 / 13.5);
  static TextStyle get _caption =>
      GoogleFonts.inter(fontSize: 12, height: 16 / 12);

  @override
  Widget build(BuildContext context) {
    final StayCluster? c = _cluster;

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: GoOutsColors.primaryBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          c?.name ?? 'Day out',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _screenTitle.copyWith(color: GoOutsColors.primaryBlue),
        ),
      ),
      bottomNavigationBar: const StayBottomNav(current: StayTab.trips),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : c == null
              ? _missing()
              : ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    if (c.photo != null) _photo(c.photo!),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _distanceLine(c),
                          const SizedBox(height: 20),
                          Text('What is here', style: _sectionHeader),
                          const SizedBox(height: 10),
                          _placesCard(c),
                          if (c.partnerCount > 0) ...<Widget>[
                            const SizedBox(height: 20),
                            Text('Eat and drink nearby',
                                style: _sectionHeader),
                            const SizedBox(height: 10),
                            _partnersCard(c),
                          ],
                          const SizedBox(height: 20),
                          _directionsButton(c),
                          const SizedBox(height: 8),
                          _attributionLine(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  /// ⚠ NOT "this day out does not exist". A cluster id that no longer resolves
  /// almost always means the city was rebuilt and the anchor place changed its
  /// name, not that the museums went away.
  Widget _missing() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.explore_off_outlined,
                  size: 48, color: GoOutsColors.primaryBlue),
              const SizedBox(height: 12),
              Text('This day out could not be loaded',
                  textAlign: TextAlign.center,
                  style: _cardTitle.copyWith(color: GoOutsColors.deepNavy)),
              const SizedBox(height: 6),
              Text('Go back and pick another one.',
                  textAlign: TextAlign.center,
                  style: _body.copyWith(color: GoOutsColors.bodyText)),
            ],
          ),
        ),
      );

  Widget _photo(StayPhotoCredit p) => Stack(
        children: <Widget>[
          Image.network(
            p.url,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 1000,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: GoOutsColors.paleBlueTint,
              child: const Icon(Icons.photo_outlined,
                  color: GoOutsColors.primaryBlue),
            ),
          ),
          // The credit again, for the same reason as screen 07. A licence that
          // requires naming the photographer requires it on every screen the
          // photograph appears on, not just the first.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget _distanceLine(StayCluster c) {
    final double? lat = _listing?.lat;
    final double? lng = _listing?.lng;
    final String text = (lat == null || lng == null)
        ? '${c.placeCount} places'
        : '${StayAttractionsService.milesBetween(lat, lng, c.lat, c.lng).toStringAsFixed(1)}'
            ' miles from your stay · ${c.placeCount} places';

    return Row(
      children: <Widget>[
        const Icon(Icons.straighten_rounded,
            size: 16, color: GoOutsColors.bodyText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: _body.copyWith(color: GoOutsColors.bodyText)),
        ),
      ],
    );
  }

  Widget _placesCard(StayCluster c) => Container(
        decoration: BoxDecoration(
          color: GoOutsColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: <Widget>[
            for (int i = 0; i < c.places.length; i++) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  children: <Widget>[
                    Icon(_iconFor(c.places[i].category),
                        size: 20, color: GoOutsColors.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(c.places[i].name,
                              style: _cardTitle.copyWith(
                                  color: GoOutsColors.deepNavy)),
                          Text(c.places[i].category,
                              style:
                                  _caption.copyWith(color: GoOutsColors.bodyText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i != c.places.length - 1)
                const Divider(
                    height: 1, thickness: 0.5, color: GoOutsColors.dividerGray),
            ],
            // The list is capped at 12 by the builder. Saying so beats showing
            // twelve and implying that is all there is.
            if (c.placeCount > c.places.length)
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Text(
                  'and ${c.placeCount - c.places.length} more nearby',
                  style: _caption.copyWith(color: GoOutsColors.bodyText),
                ),
              ),
          ],
        ),
      );

  Widget _partnersCard(StayCluster c) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: GoOutsColors.primaryBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.local_offer_outlined,
                    size: 20, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${c.partnerCount} GoOuts '
                    '${c.partnerCount == 1 ? 'partner' : 'partners'} '
                    'within half a mile',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 20 / 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
            if (c.partnerSummary.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(c.partnerSummary,
                  style: GoogleFonts.inter(
                      fontSize: 13.5,
                      height: 20 / 13.5,
                      color: Colors.white.withValues(alpha: 0.9))),
            ],
            const SizedBox(height: 6),
            Text('Earn cashback while you are out.',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 16 / 12,
                    color: Colors.white.withValues(alpha: 0.85))),
          ],
        ),
      );

  Widget _directionsButton(StayCluster c) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('https://www.google.com/maps/search/?api=1&query='
                '${c.lat},${c.lng}'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.directions_outlined, size: 20),
          label: Text('Open in Maps',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: GoOutsColors.primaryBlue,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _attributionLine() {
    final StayAttractions? a = _attractions;
    if (a == null) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        onPressed: () => launchUrl(Uri.parse(a.attributionUrl),
            mode: LaunchMode.externalApplication),
        child: Text('${a.attribution} · ODbL',
            style: _caption.copyWith(color: GoOutsColors.bodyText)),
      ),
    );
  }

  static IconData _iconFor(String category) {
    switch (category) {
      case 'Museum':
        return Icons.museum_outlined;
      case 'Gallery':
        return Icons.palette_outlined;
      case 'Castle':
      case 'Historic site':
      case 'Monument':
        return Icons.castle_outlined;
      case 'Zoo':
      case 'Aquarium':
        return Icons.pets_outlined;
      case 'Theme park':
        return Icons.attractions_outlined;
      case 'Park':
      case 'Garden':
      case 'Nature reserve':
        return Icons.park_outlined;
      case 'Theatre':
        return Icons.theater_comedy_outlined;
      case 'Viewpoint':
        return Icons.landscape_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}
