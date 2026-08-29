// ─────────────────────────────────────────────────────────────────────────────
//  All amenities. Rebuilt to the Stitch layout 27 August 2026.
//
//  Reported as "stitch screen look more professional full amenities screen",
//  with the Stitch design and its DESIGN.md supplied.
//
//  ── WHAT WAS ACTUALLY DIFFERENT ─────────────────────────────────────────────
//
//  The DATA was already right. This screen has ticked exactly what the host
//  selected since 16 August, and it already struck through what they did not.
//  That part was never the problem.
//
//  The PRESENTATION was flat. A blue group heading, a bare tick or cross at
//  15px, a full width divider, repeat. No cards, no amenity icons, everything
//  the same weight, so a list of thirty six items read as one grey wall.
//
//  Stitch does four things this did not:
//
//    · each group sits in its own white rounded card on the page background,
//      so the groups are objects rather than paragraphs
//    · every amenity carries ITS OWN icon, taken from the catalogue, on the
//      left. The tick moves to the right hand edge
//    · the status marker is a filled circle, not a bare glyph
//    · group headings are uppercase, grey and small, so they label the card
//      below rather than competing with it
//
//  Classes taken from the supplied code.html:
//    heading  font-section-header text-section-header text-on-surface-variant
//    card     bg-surface-container-lowest rounded-xl p-4 flex flex-col gap-4
//    row      flex items-center justify-between, inner gap-3
//    label    font-body text-body
//
//  Type and spacing are Stitch. Colours stay GoOuts, by the 27 August decision.
//
//  ── ⚠ TWO THINGS FROM THE STITCH SCREEN ARE DELIBERATELY NOT HERE ───────────
//
//  1. THE FOOTER CLAIM. Stitch prints, over a photograph of a bathroom:
//
//         "All provisions are inspected for quality before each guest arrival."
//
//     NOBODY INSPECTS ANYTHING. There is no inspection step in the product, no
//     inspector, and no record of one. It is a promise about a service that
//     does not exist, printed on the screen a guest reads while deciding.
//
//     If a guest arrives to a flat with no towels, that sentence is the one
//     they will quote back, and they will be right to. It is not a design
//     detail, it is a statement GoOuts would have to stand behind.
//
//     It goes in the moment there is an inspection to describe. Not before.
//
//  2. THE STOCK PHOTOGRAPHS. The Stitch hero is a stock image captioned
//     "Comprehensive Provisions". This uses THE PROPERTY'S OWN first
//     photograph and its own title instead, and shows nothing at all when the
//     host has not uploaded one. Same reasoning as stay_demo_seed.js, which
//     ships with photos: [] for exactly this reason.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/stay_amenities.dart';
import '../models/stay_listing.dart';
import '../services/stay_listing_service.dart';
import '../theme/stay_colors.dart';

class AmenitiesFullScreen extends StatefulWidget {
  const AmenitiesFullScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<AmenitiesFullScreen> createState() => _AmenitiesFullScreenState();
}

class _AmenitiesFullScreenState extends State<AmenitiesFullScreen> {
  late final Future<StayListing?> _listing =
      StayListingService.instance.byId(widget.listingId);

  // ── The Stitch scale. See theme/stay_type.dart for the full note. ─────────
  static TextStyle get _screenTitle => GoogleFonts.inter(
      fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w700);

  static TextStyle get _sectionHeader => GoogleFonts.inter(
      fontSize: 15,
      height: 20 / 15,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3);

  static TextStyle get _body =>
      GoogleFonts.inter(fontSize: 13.5, height: 20 / 13.5);

  @override
  Widget build(BuildContext context) {
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
        title: Text('Amenities',
            style: _screenTitle.copyWith(color: GoOutsColors.primaryBlue)),
      ),
      body: FutureBuilder<StayListing?>(
        future: _listing,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final StayListing? listing = snapshot.data;
          if (snapshot.hasError || listing == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'The amenities for this property could not be loaded.',
                  textAlign: TextAlign.center,
                  style: _body.copyWith(color: GoOutsColors.bodyText),
                ),
              ),
            );
          }

          final Set<String> has = listing.amenities.toSet();

          // Anything the host selected that this build does not recognise.
          // Given its own card rather than dropped, so an amenity added on the
          // host side before a consumer release is visible rather than absent.
          final List<String> unknown = listing.amenities
              .where((s) => !stayAmenitiesAll.any((a) => a.slug == s))
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              _hero(listing),
              for (final MapEntry<String, List<StayAmenity>> e
                  in stayAmenityGroups.entries)
                _group(e.key, e.value, has),
              if (unknown.isNotEmpty)
                _group('Also provided',
                    unknown.map(stayAmenityFor).toList(growable: false), has),
            ],
          );
        },
      ),
    );
  }

  /// The property's own photograph with its own title over it.
  ///
  /// Hidden entirely when the host has not uploaded one. An empty grey block
  /// captioned with the property name reads as a failed image load, which is
  /// worse than simply starting at the first group.
  Widget _hero(StayListing listing) {
    final List<StayPhoto> photos = List<StayPhoto>.from(listing.photos)
      ..sort((a, b) => a.order.compareTo(b.order));
    if (photos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 160,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.network(
                photos.first.url,
                fit: BoxFit.cover,
                cacheWidth: 900,
                errorBuilder: (_, __, ___) =>
                    Container(color: GoOutsColors.paleBlueTint),
              ),
              // A scrim, so white text stays readable over a bright photograph.
              // Without it the title vanishes on any picture of a white room,
              // which most interior photographs are.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Color(0xB3000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _screenTitle.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// An uppercase grey label, then a white card holding the rows.
  Widget _group(String title, List<StayAmenity> items, Set<String> has) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              // Uppercased here rather than in the catalogue, because the
              // catalogue is shared with the host wizard and the filter sheet,
              // where sentence case is correct.
              title.toUpperCase(),
              style: _sectionHeader.copyWith(color: GoOutsColors.bodyText),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: GoOutsColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  _row(items[i], has.contains(items[i].slug)),
                  if (i != items.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 0.5,
                      color: GoOutsColors.dividerGray,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Icon and label on the left, a filled status circle on the right.
  ///
  /// ⚠ THE ROW SAYS THE SAME THING THREE TIMES WHEN IT IS ABSENT: the icon
  /// greys out, the label is struck through, and the circle turns red. That is
  /// on purpose. Colour alone is not readable to everyone, and a tick and a
  /// cross at a glance look alike; the strikethrough is what actually carries
  /// the meaning without relying on either.
  Widget _row(StayAmenity amenity, bool included) {
    final Color iconColour =
        included ? GoOutsColors.primaryBlue : GoOutsColors.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: <Widget>[
          Icon(amenity.icon, size: 22, color: iconColour),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              amenity.label,
              style: _body.copyWith(
                color: included
                    ? GoOutsColors.deepNavy
                    : GoOutsColors.bodyText.withValues(alpha: 0.55),
                decoration:
                    included ? TextDecoration.none : TextDecoration.lineThrough,
                decorationColor: GoOutsColors.bodyText.withValues(alpha: 0.55),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ⚠ FULL STRENGTH RED, NOT A FADED ONE.
          //
          // Reported as "which amenities are not available we cross with lines
          // rather than red X like stitch". The old screen put a small pale
          // cross on the LEFT at the same size as the tick, so the only thing
          // that actually read at a glance was the strikethrough.
          //
          // Stitch puts a solid filled circle on the RIGHT EDGE, where the eye
          // scans down a list, and it is a real red. Softening it to 65 percent
          // was my own addition and it undid the point of the change.
          Icon(
            included ? Icons.check_circle : Icons.cancel,
            size: 22,
            color:
                included ? GoOutsColors.primaryBlue : GoOutsColors.errorRed,
          ),
        ],
      ),
    );
  }
}
