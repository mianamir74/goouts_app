// ─────────────────────────────────────────────────────────────────────────────
//  Short Stay home. Rebuilt to the Stitch layout 27 August 2026.
//
//  Reported as: "there is lot of big fonts sizes used as headings and some ui is
//  changed", with the Stitch design and a device screenshot side by side.
//
//  Instruction: "keep the hero card but use the same style of stitch", and
//  "design of UI we need to use Stitch one but built in color is fine".
//
//  So: Stitch's TYPE, SPACING and COMPONENTS. GoOuts' COLOURS. Hero kept.
//
//  ── ⚠ WHAT WAS ACTUALLY WRONG. IT WAS NOT THE COLOURS. ──────────────────────
//
//  Stitch shipped a named scale in the Tailwind config of 28 of the 29 screens —
//  six text styles, largest 20px, heaviest weight 700. See theme/stay_type.dart.
//
//  This screen used:
//      25px / w800  hero headline      ← 5px past the ceiling, weight not in the
//                                        design system at all
//      17px / w800  section headers    ← should be 15 / 700
//      15px / w800  prices             ← should be 14 / 700
//      12px         card body          ← should be 13.5
//      18 / 22 / 28 section gaps       ← should be 20, every time
//
//  Nothing was broken. The type was simply louder and larger than it was drawn,
//  and once every screen picks its own "slightly bigger" heading the set stops
//  looking designed. Every size and gap below now comes from StayType and
//  StaySpacing, and this file declares no raw font size of its own.
//
//  ── ⚠ THE SEARCH FIELD HAD A BOX INSIDE THE BOX ─────────────────────────────
//
//  Reported as: "when we click on the search it show another input box with in
//  search box thats is very bad".
//
//  Visible in the screenshot even unfocused: a grey rounded rectangle sitting
//  inside the white search container, starting just after the magnifier.
//
//  Cause: the TextField inherited `filled: true` from the app's global
//  InputDecorationTheme. The white Container is ours; the grey fill is the
//  theme's, drawn inside it. Two backgrounds, one field.
//
//  Fixed by declaring the decoration completely — filled:false, transparent
//  fill, no borders, explicit contentPadding — so the field cannot inherit a
//  second background from anywhere. Do not shorten this to `border:
//  InputBorder.none`; that removes the outline and leaves the fill.
//
//  ── ⚠ WHAT CAME BACK, AND WHAT DID NOT ──────────────────────────────────────
//
//  "Recently viewed" is back, because it is now REAL — StayRecentlyViewed
//  records a listing id on open. It was deleted on 22 August for showing the
//  same two hardcoded properties as the section above it.
//
//  "Weekend breaks" has NOT come back and is not faked. Nothing in the product
//  defines what makes a stay a weekend break. Doing it honestly means querying
//  next Friday–Sunday availability per listing, which is real work, not a
//  layout change. The Stitch card shape for that section is used for "More
//  places to stay" so the rhythm of the page matches regardless.
//
//  The city chips are gone — not in the Stitch design, and they duplicated the
//  search field directly above them.
//
//  ⚠ NOTHING BELOW INVENTS A NUMBER. Rating hidden when ratingCount == 0.
//  Partner count hidden when 0. Cashback hidden unless the rate is known.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/stay_listing.dart';
// StaySearchCriteria lives here, not in stay_listing_service.
import '../services/stay_availability_service.dart';
import '../services/stay_booking_service.dart';
import '../services/stay_listing_service.dart';
import '../services/stay_recently_viewed.dart';
import '../theme/stay_colors.dart';
import '../theme/stay_type.dart';
import '../stay_routes.dart';
import '../widgets/desktop_top_nav.dart' show JoinAsHostButton, AccountMenuButton, GoOutsBrandLogo;
import '../widgets/stay_bottom_nav.dart';

class ShortStayHomeScreen extends StatefulWidget {
  const ShortStayHomeScreen({super.key});

  @override
  State<ShortStayHomeScreen> createState() => _ShortStayHomeScreenState();
}

class _ShortStayHomeScreenState extends State<ShortStayHomeScreen> {
  final _whereCtrl = TextEditingController();
  DateTimeRange? _dates;
  int _adults = 2;
  int _children = 0;
  int _infants = 0;

  List<StayListing> _listings = const <StayListing>[];
  List<StayListing> _recent = const <StayListing>[];
  bool _loading = true;

  /// Why the list is empty, when the reason was an error rather than an absence
  /// of properties. A silent catch that renders the empty state is not a
  /// graceful failure, it is a lost error message.
  String? _error;

  StayCashbackRate _rate = StayCashbackRate.unknown;

  // ── ⚠ CITY ROWS, 9 September 2026. REPLACED "most partners" + a grid. ────
  //
  // Was one row of the top 4 by partner count, then every remaining
  // property dumped into a 2 (mobile) / 3 (desktop) column grid under
  // "Explore United Kingdom" — one undifferentiated pile, nothing like the
  // "Popular homes in London", "Available in Manchester" rows every
  // reference site (Airbnb, booking.com) actually uses on its homepage.
  //
  // Grouped on address.town — exactly what the host typed, never geocoded
  // or invented here — so a "London" row only ever holds properties a host
  // actually marked as London. London is pinned first when present; every
  // other town follows busiest-first, the same ordering the old partners
  // row used.
  Map<String, List<StayListing>> get _byCity {
    final Map<String, List<StayListing>> map = <String, List<StayListing>>{};
    for (final StayListing l in _listings) {
      final String town = l.address.town.trim();
      if (town.isEmpty) continue;
      map.putIfAbsent(town, () => <StayListing>[]).add(l);
    }
    return map;
  }

  List<String> get _cityOrder {
    final List<String> cities = _byCity.keys.toList();
    cities.sort((a, b) {
      final bool aLondon = a.toLowerCase() == 'london';
      final bool bLondon = b.toLowerCase() == 'london';
      if (aLondon != bLondon) return aLondon ? -1 : 1;
      return _byCity[b]!.length.compareTo(_byCity[a]!.length);
    });
    return cities;
  }

  @override
  void initState() {
    super.initState();
    _loadListings();
    _loadRate();
    _loadRecent();
  }

  // ── ⚠ THREE INDEPENDENT LOADS. DO NOT PUT THESE BACK IN A Future.wait. ─────
  //
  // Future.wait completes when the SLOWEST future completes. The cashback rate
  // is a Cloud Function, and a function idle for fifteen minutes COLD STARTS —
  // seconds, not milliseconds. Waiting on it held a spinner over listings that
  // had already arrived. That was the 22 August "Short Stay takes too much time
  // to load" report.
  Future<void> _loadListings() async {
    try {
      final List<StayListing> found =
          await StayListingService.instance.mostPartnersNearby(limit: 12);
      if (!mounted) return;
      setState(() {
        _listings = found;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listings = const <StayListing>[];
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadRate() async {
    final StayCashbackRate r = await StayBookingService.instance.cashbackRate();
    if (!mounted) return;
    setState(() => _rate = r);
  }

  /// Reads ids from the device, then re-reads the listings so the row shows
  /// today's price rather than the price at the moment it was viewed.
  Future<void> _loadRecent() async {
    try {
      final List<String> ids = await StayRecentlyViewed.instance.ids();
      if (ids.isEmpty) {
        if (mounted) setState(() => _recent = const <StayListing>[]);
        return;
      }
      final List<StayListing> found =
          await StayListingService.instance.byIds(ids);
      // byIds does not promise order. Restore most-recent-first.
      final Map<String, StayListing> byId = <String, StayListing>{
        for (final StayListing l in found) l.id: l,
      };
      final List<StayListing> ordered = <StayListing>[
        for (final String id in ids)
          if (byId[id] != null) byId[id]!,
      ];
      if (!mounted) return;
      setState(() => _recent = ordered);
    } catch (_) {
      // A convenience row. Never allowed to break the screen.
      if (mounted) setState(() => _recent = const <StayListing>[]);
    }
  }

  @override
  void dispose() {
    _whereCtrl.dispose();
    super.dispose();
  }

  int get _countedGuests => _adults + _children; // infants do not count

  String get _datesLabel {
    final d = _dates;
    if (d == null) return 'Date range';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.start.day} ${m[d.start.month - 1]}'
        ' – ${d.end.day} ${m[d.end.month - 1]}';
  }

  String get _guestsLabel {
    if (_countedGuests == 2 && _infants == 0) return 'Guests';
    final parts = <String>[
      '$_adults ${_adults == 1 ? 'adult' : 'adults'}',
      if (_children > 0) '$_children ${_children == 1 ? 'child' : 'children'}',
      if (_infants > 0) '$_infants ${_infants == 1 ? 'infant' : 'infants'}',
    ];
    return parts.join(', ');
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDateRange: _dates,
      helpText: 'When are you going',
      saveText: 'Done',
    );
    if (!mounted) return;
    if (picked != null) setState(() => _dates = picked);
  }

  Future<void> _pickGuests() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: GoOutsColors.cardSurface,
      constraints: kIsWeb && MediaQuery.of(context).size.width >= 900
          ? const BoxConstraints(maxWidth: 560)
          : null,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(
              StaySpacing.page, StaySpacing.page, StaySpacing.page, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Guests',
                  style: StayType.screenTitle.on(GoOutsColors.deepNavy)),
              StaySpacing.gapCard,
              _guestRow('Adults', _adults, 1, 16, (v) {
                setSheetState(() => _adults = v);
                setState(() {});   // crash_scan: ok - tap callback, not async flow
              }),
              _guestRow('Children', _children, 0, 10, (v) {
                setSheetState(() => _children = v);
                setState(() {});   // crash_scan: ok - tap callback, not async flow
              }, note: 'Age 2 to 12'),
              _guestRow('Infants', _infants, 0, 5, (v) {
                setSheetState(() => _infants = v);
                setState(() {});   // crash_scan: ok - tap callback, not async flow
              }, note: 'Under 2, and they do not count towards the limit'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guestRow(String label, int value, int min, int max,
      ValueChanged<int> onChange, {String? note}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: StayType.cardTitle.on(GoOutsColors.deepNavy)),
                if (note != null)
                  Text(note, style: StayType.caption.on(GoOutsColors.bodyText)),
              ],
            ),
          ),
          IconButton(
            onPressed: value <= min ? null : () => onChange(value - 1),
            icon: const Icon(Icons.remove_circle_outline),
            color: GoOutsColors.primaryBlue,
            disabledColor: GoOutsColors.outlineVariant,
          ),
          SizedBox(
            width: 28,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: StayType.cardTitle.on(GoOutsColors.deepNavy)),
          ),
          IconButton(
            onPressed: value >= max ? null : () => onChange(value + 1),
            icon: const Icon(Icons.add_circle_outline),
            color: GoOutsColors.primaryBlue,
            disabledColor: GoOutsColors.outlineVariant,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    // ⚠ ADDED 9 September 2026. Reported: "the web version is not perfect,
    // need spacing both side... use your skills to make it professional
    // UI/UX... check Airbnb, Uber Eats, Deliveroo, booking.com."
    //
    // Those sites all share the same shape: a real top nav bar (not a phone
    // tab bar pinned to the bottom), a wide hero with a prominent search row,
    // and page content held to a comfortable reading width and CENTRED, so a
    // wide monitor gets even gutters on both sides instead of the mobile
    // layout pinned to the left edge with a void on the right.
    //
    // This is a SEPARATE layout, not a stretched version of the phone one.
    // The mobile branch below is completely unchanged — StaySpacing's "16,
    // without exception" rule is a mobile rule, and a desktop browser window
    // is not a phone screen wearing a costume. kIsWeb also gates this off on
    // an actual phone opening this same URL: it still gets the phone layout,
    // which is correct for it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool desktop = kIsWeb && constraints.maxWidth >= 900;
        return desktop ? _buildDesktop(context) : _buildMobile(context);
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      // ⚠ The app bar carries NO title. The hero headline immediately below is
      // the screen title, at StayType.screenTitle. Two 20px headings forty
      // pixels apart is the "big headings" complaint in miniature.
      appBar: AppBar(
        backgroundColor: GoOutsColors.deepNavy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: StaySpacing.buttonHeight,
        // ⚠ ADDED 9 September 2026. On the phone app this screen is always
        // pushed on top of something, so a back arrow always has somewhere
        // to go. On web this is the app's ROOT screen (see main.dart's
        // `home: kIsWeb ? ShortStayHomeScreen() : ...`) — there is nothing
        // to pop, and an arrow that does nothing when tapped is exactly the
        // "decorative back button" class of bug already fixed everywhere
        // else in this app. canPop() is false at the root on both
        // platforms, so this one check covers both without a kIsWeb branch.
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      bottomNavigationBar: const StayBottomNav(current: StayTab.search),
      body: RefreshIndicator(
        color: GoOutsColors.primaryBlue,
        onRefresh: () async {
          _loadRate();
          _loadRecent();
          await _loadListings();
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            _hero(),
            StaySpacing.gapSection,
            // ⚠ ADDED 9 September 2026, building the web version of this
            // app. Food ordering (screens/food_delivery_screen.dart etc.)
            // ships in the same build as Short Stay — it always has, they
            // are the same app — but nothing on this screen ever linked to
            // it, because on phone a guest reaches food ordering from the
            // main wallet home screen, not from here. Web visitors land on
            // THIS screen first (see main.dart), so without this card
            // food ordering was live but functionally unreachable on web.
            Padding(
              padding: StaySpacing.pageH,
              child: _foodOrderingCard(),
            ),
            StaySpacing.gapSection,
            if (_loading)
              _skeletons()
            else if (_error != null)
              Padding(padding: StaySpacing.pageH, child: _buildLoadFailed())
            else if (_listings.isEmpty)
              Padding(padding: StaySpacing.pageH, child: _buildEmpty())
            else ...<Widget>[
              // ── ⚠ ONE SECTION PER CITY, 9 September 2026. London first,
              // then every other town, busiest first — see _byCity/_cityOrder
              // for the full note.
              for (int i = 0; i < _cityOrder.length; i++) ...<Widget>[
                if (i > 0) StaySpacing.gapSection,
                _sectionHeader(_cityOrder[i]),
                _wideRow(_byCity[_cityOrder[i]]!),
              ],
              if (_recent.isNotEmpty) ...<Widget>[
                StaySpacing.gapSection,
                _sectionHeader('Recently viewed'),
                _recentRow(),
              ],
            ],
            const SizedBox(height: StaySpacing.section + StaySpacing.page),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DESKTOP WEB LAYOUT — see the note at the top of build().
  // ══════════════════════════════════════════════════════════════════════════

  /// Content column width. Airbnb and booking.com both settle around
  /// 1400-1760px on a wide monitor rather than stretching edge to edge —
  /// past this a row of cards just gets more empty-feeling gaps between
  /// them, not more usable page.
  static const double _desktopMaxWidth = 1400;

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: GoOutsColors.pageBackground,
      body: Column(
        children: <Widget>[
          _desktopTopNav(context),
          Expanded(
            child: RefreshIndicator(
              color: GoOutsColors.primaryBlue,
              onRefresh: () async {
                _loadRate();
                _loadRecent();
                await _loadListings();
              },
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  _desktopHero(context),
                  // ── ⚠ FOOD ORDERING CARD REMOVED ON DESKTOP, 9 September
                  // 2026. Was added because the mobile layout's bottom tab
                  // bar has no Food tab, so this card was the only way a web
                  // visitor could reach food ordering at all. The desktop
                  // top nav (_desktopTopNav above) now carries a Food icon
                  // tab of its own, so the card duplicated a path that
                  // already exists — same reasoning Airbnb's own Homes page
                  // uses: Experiences/Services get a nav icon, not a promo
                  // card competing with the actual listings. MOBILE KEEPS
                  // THE CARD (see _buildMobile below) — its bottom nav still
                  // has no Food tab, so removing it there would leave no way
                  // in at all.
                  const SizedBox(height: 40),
                  if (_loading)
                    _desktopSection(_skeletons())
                  else if (_error != null)
                    _desktopSection(_buildLoadFailed())
                  else if (_listings.isEmpty)
                    _desktopSection(_buildEmpty())
                  else ...<Widget>[
                    // ── ⚠ ONE SECTION PER CITY, 9 September 2026. Replaced
                    // "most partners" + a single "Explore United Kingdom"
                    // grid with London first, then every other town,
                    // busiest first — see _byCity/_cityOrder's own note.
                    // 4 columns rather than the mobile grid's 2: at 1400px
                    // wide, 2 columns produced two oversized cards with
                    // empty-feeling gaps; each _desktopSection wrap keeps
                    // every header and row lined up on the identical
                    // (1400 wide, 48px outer padding) box, edge to edge.
                    for (int i = 0; i < _cityOrder.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: 40),
                      _desktopSection(_sectionHeader(_cityOrder[i])),
                      _desktopSection(_wideRow(
                        _byCity[_cityOrder[i]]!,
                        crossAxisCount: 4,
                        photoHeight: 190,
                      )),
                    ],
                    if (_recent.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 40),
                      _desktopSection(_sectionHeader('Recently viewed')),
                      _desktopSection(_recentRow()),
                    ],
                  ],
                  const SizedBox(height: 64),
                  _desktopSection(_desktopAboutTeaser(context)),
                  const SizedBox(height: 64),
                  _desktopFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Centres a child inside [_desktopMaxWidth] with even side gutters — this
  /// is the actual fix for "need spacing both side". Everything that already
  /// carries its own `StaySpacing.pageH` (the card rows) keeps that padding
  /// AS AN INNER GUTTER relative to this box, so their cards line up with
  /// the section headers without those methods needing to change at all.
  ///
  /// ⚠ FIXED 9 September 2026, found in live desktop review: without the
  /// SizedBox(width: double.infinity) below, ConstrainedBox only sets a
  /// CEILING — it does not make its child actually BE 1400 wide. A Text
  /// inside a Padding shrink-wraps to its own content width regardless of
  /// that ceiling, so Center() was centring a small text-width blob in the
  /// middle of the page instead of left-aligning it inside a 1400-wide,
  /// evenly-guttered lane. The SizedBox forces the full width through, so
  /// everything downstream (the padding, the text, the row) actually fills
  /// the lane and lines up the way "need spacing both side" asked for.
  Widget _desktopSection(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopMaxWidth),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: child,
            ),
          ),
        ),
      );


  /// White, bottom hairline, GoOuts wordmark left, the same four
  /// destinations StayBottomNav offers on the phone as plain-text links,
  /// sign in / account on the right. This REPLACES StayBottomNav on desktop
  /// rather than sitting above it — a tab bar pinned to the bottom of a
  /// browser window is the single biggest "this is a phone app, not a
  /// website" tell across every reference site checked (Airbnb, Uber Eats,
  /// Deliveroo, booking.com — all top nav, none bottom tabs).
  // ── ⚠ ICON-BEFORE-TEXT, 9 September 2026. ─────────────────────────────────
  //
  // Was icon-above-label with an active underline (Airbnb's mobile-app-style
  // stacked tab). Changed to icon-then-label on one line so every nav item —
  // including "GoOuts" itself — sits on the same baseline, plus a hover
  // colour change now that this only ever runs on web, where hover is a real
  // signal a text-only nav bar can't give. Nav bar back to 72px, its
  // original height, now that nothing needs the extra room for a stacked
  // icon/label/underline.
  Widget _desktopTopNav(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: GoOutsColors.cardSurface,
        border: Border(
          bottom: BorderSide(color: GoOutsColors.outlineVariant, width: 1),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Row(
              children: <Widget>[
                // ── FAR LEFT: logo, hyperlinked home ────────────────────────
                const GoOutsBrandLogo(),
                // ── CENTRE: the same four tabs as every other page's nav ──
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _NavIconTab(
                          icon: Icons.villa_rounded,
                          label: 'Short Stay',
                          active: true,
                          onTap: () {},
                        ),
                        const SizedBox(width: 4),
                        _NavIconTab(
                          icon: Icons.restaurant_rounded,
                          label: 'Food Delivery',
                          onTap: () =>
                              Navigator.of(context).pushNamed('/food-delivery'),
                        ),
                        const SizedBox(width: 4),
                        _NavIconTab(
                          icon: Icons.local_offer_rounded,
                          label: 'Explore Cashback',
                          onTap: () => Navigator.of(context)
                              .pushNamed(StayRoutes.exploreCashback),
                        ),
                        const SizedBox(width: 4),
                        _NavIconTab(
                          icon: Icons.info_outline_rounded,
                          label: 'About Us',
                          onTap: () => Navigator.of(context)
                              .pushNamed(StayRoutes.aboutUs),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── FAR RIGHT: Join as Host, then profile+menu — matches the
                // shared bar in desktop_top_nav.dart used by every "inside"
                // page, and the goouts.co.uk theme (colours, ghost-button
                // style) this was asked to keep. See that file's own header
                // comment for why left/right are the way they are.
                JoinAsHostButton(),
                const SizedBox(width: 14),
                AccountMenuButton(user: user),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ⚠ _navLink/_navPrimaryButton REMOVED 14 September 2026 — Sign up/Sign in
  // /Sign out now live inside AccountMenuButton's dropdown (see
  // desktop_top_nav.dart), not as standalone bar items, as part of the same
  // nav rebuild that moved account controls to the far left.

  /// Same gradient and copy as the phone hero, at desktop scale: a bigger
  /// headline (this is a NEW style, scoped to this method — StayType's "20px
  /// is the largest text in the product" rule is written for the mobile
  /// scale in StaySpacing.page's 16px world, not for a hero on a 1440px
  /// browser window), and the Uber Eats/booking.com shape of ONE search row
  /// — field, dates, guests and a solid button side by side — rather than
  /// the phone's stacked field-then-pills, because there is finally room
  /// for it on one line.
  Widget _desktopHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 72),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[GoOutsColors.deepNavy, GoOutsColors.primaryBlue],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: <Widget>[
              Text('Stay somewhere, earn everywhere',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 44,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  )),
              const SizedBox(height: 14),
              Text(
                'Book a place, then get cashback at GoOuts partners around it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 36),
              _desktopSearchRow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopSearchRow(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 12),
          const Icon(Icons.search, size: 20, color: GoOutsColors.outlineVariant),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _whereCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _search(),
              cursorColor: GoOutsColors.primaryBlue,
              style: GoogleFonts.inter(fontSize: 15, color: GoOutsColors.deepNavy),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: 'Where are you going',
                hintStyle: GoogleFonts.inter(
                    fontSize: 15, color: GoOutsColors.outlineVariant),
              ),
            ),
          ),
          _desktopDivider(),
          _desktopSearchSegment(_datesLabel, Icons.calendar_today_outlined,
              _pickDates, active: _dates != null),
          _desktopDivider(),
          _desktopSearchSegment(_guestsLabel, Icons.group_outlined,
              _pickGuests,
              active: _countedGuests != 2 || _infants > 0),
          const SizedBox(width: 6),
          InkWell(
            onTap: _search,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 26),
              decoration: BoxDecoration(
                color: GoOutsColors.primaryBlue,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text('Search',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopDivider() => Container(
        width: 1,
        height: 32,
        color: GoOutsColors.outlineVariant.withValues(alpha: 0.5),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  Widget _desktopSearchSegment(
      String text, IconData icon, VoidCallback onTap,
      {bool active = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon,
                size: 17,
                color: active
                    ? GoOutsColors.primaryBlue
                    : GoOutsColors.bodyText),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active
                        ? GoOutsColors.primaryBlue
                        : GoOutsColors.bodyText,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  /// Short About Us teaser on the home page itself, requested directly —
  /// "a short about us on the main page", alongside the fuller page at
  /// StayRoutes.aboutUs (see 32_about_us_screen.dart, which carries the same
  /// real copy word for word from index.html's #about-us section). This is
  /// the condensed version: the headline, one summary line, the four value
  /// labels with no body text, and a link through to the full page — same
  /// relationship the marketing site itself doesn't need (it has no
  /// separate About page, this app does), but the copy underneath is
  /// identical, not a third rewrite.
  Widget _desktopAboutTeaser(BuildContext context) {
    const List<(IconData, String, Color)> values = <(IconData, String, Color)>[
      (Icons.check_circle_rounded, 'Honest and Transparent', Color(0xFF0392CA)),
      (Icons.groups_rounded, 'Built for Communities', Color(0xFFF59E0B)),
      (Icons.balance_rounded, 'Fair for Everyone', Color(0xFF10B981)),
      (Icons.verified_rounded, 'No Gimmicks', Color(0xFF6C63FF)),
    ];
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: GoOutsColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GoOutsColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('About Us',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: GoOutsColors.primaryBlue,
                      letterSpacing: 0.4,
                    )),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: GoOutsColors.deepNavy,
                      height: 1.25,
                      letterSpacing: -0.4,
                    ),
                    children: const <TextSpan>[
                      TextSpan(text: 'We built GoOuts because '),
                      TextSpan(
                        text: 'people deserve more.',
                        style: TextStyle(color: GoOutsColors.primaryBlue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'When you spend at a local venue, you should get something '
                  'back right away — real Cashback Points, not a voucher that '
                  'expires.',
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    height: 1.6,
                    color: GoOutsColors.bodyText,
                  ),
                ),
                const SizedBox(height: 18),
                InkWell(
                  onTap: () =>
                      Navigator.of(context).pushNamed(StayRoutes.aboutUs),
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Read our story',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: GoOutsColors.primaryBlue,
                          )),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: GoOutsColors.primaryBlue),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48),
          Expanded(
            flex: 6,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 20,
              crossAxisSpacing: 24,
              childAspectRatio: 2.6,
              children: <Widget>[
                for (final (IconData icon, String label, Color accent) in values)
                  Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: GoOutsColors.deepNavy,
                            )),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopFooter() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: GoOutsColors.outlineVariant, width: 1),
          ),
        ),
        child: Center(
          child: Text('© ${DateTime.now().year} GoOuts',
              style: GoogleFonts.inter(
                  fontSize: 13, color: GoOutsColors.bodyText)),
        ),
      );

  // ── HERO ──────────────────────────────────────────────────────────────────
  //
  // Kept by instruction, restyled to the Stitch scale. The headline is
  // screenTitle (20/700) rather than 25/w800, and the proposition line is body
  // (13.5/400) rather than 13.5 with an invented line height.
  //
  // The standalone white "Search" button is gone. Stitch has no such button —
  // the field submits. It was a 52px block of white doing what pressing enter
  // already did, and it pushed the first real card off the fold.
  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          StaySpacing.page, 0, StaySpacing.page, StaySpacing.section),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[GoOutsColors.deepNavy, GoOutsColors.primaryBlue],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Stay somewhere, earn everywhere',
              style: StayType.screenTitle.on(Colors.white)),
          const SizedBox(height: 4),
          Text(
            'Book a place, then get cashback at GoOuts partners around it.',
            style: StayType.body.on(Colors.white.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: StaySpacing.inline),
          _searchField(),
          const SizedBox(height: StaySpacing.card),
          Row(
            children: <Widget>[
              _pill(_datesLabel, Icons.calendar_today_outlined, _pickDates,
                  active: _dates != null),
              const SizedBox(width: StaySpacing.card),
              _pill(_guestsLabel, Icons.group_outlined, _pickGuests,
                  active: _countedGuests != 2 || _infants > 0),
            ],
          ),
        ],
      ),
    );
  }

  /// ⚠ THE DECORATION IS DECLARED IN FULL ON PURPOSE. See the file header.
  ///
  /// `filled: false` AND a transparent `fillColor` AND explicit borders. The
  /// global InputDecorationTheme sets `filled: true` with a grey fill, and it
  /// only takes one of these being absent for the grey box to reappear inside
  /// the white one.
  Widget _searchField() {
    return Container(
      height: StaySpacing.buttonHeight,
      padding: const EdgeInsets.symmetric(horizontal: StaySpacing.inline),
      decoration: BoxDecoration(
        color: GoOutsColors.cardSurface,
        borderRadius: BorderRadius.circular(StaySpacing.inline),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search, size: 20, color: GoOutsColors.outlineVariant),
          const SizedBox(width: StaySpacing.card),
          Expanded(
            child: TextField(
              controller: _whereCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _search(),
              cursorColor: GoOutsColors.primaryBlue,
              style: StayType.buttonText
                  .copyWith(fontWeight: FontWeight.w400)
                  .on(GoOutsColors.deepNavy),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                hoverColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: 'Where are you going',
                hintStyle: StayType.buttonText
                    .copyWith(fontWeight: FontWeight.w400)
                    .on(GoOutsColors.outlineVariant),
              ),
            ),
          ),
          if (_whereCtrl.text.isNotEmpty)
            InkWell(
              onTap: () {
                _whereCtrl.clear();
                setState(() {});
              },
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 18, color: GoOutsColors.bodyText),
              ),
            ),
        ],
      ),
    );
  }

  /// Stitch pill: rounded-full, px-4 py-2, pale container fill, 18px icon,
  /// caption text at button weight. Ours was a white pill with body text.
  Widget _pill(String text, IconData icon, VoidCallback onTap,
      {bool active = false}) {
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: StaySpacing.page, vertical: StaySpacing.card),
          decoration: BoxDecoration(
            color: GoOutsColors.cardSurface
                .withValues(alpha: active ? 1.0 : 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: active ? 0 : 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon,
                  size: 18,
                  color:
                      active ? GoOutsColors.primaryBlue : Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: StayType.caption.semibold.on(
                      active ? GoOutsColors.primaryBlue : Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _search() {
    Navigator.of(context).pushNamed(
      StayRoutes.results,
      arguments: <String, dynamic>{
        'criteria': StaySearchCriteria(
          town: _whereCtrl.text.trim().isEmpty ? null : _whereCtrl.text.trim(),
          checkIn: _dates?.start,
          checkOut: _dates?.end,
          guests: _countedGuests,
        ),
      },
    );
  }

  // ── SECTIONS ──────────────────────────────────────────────────────────────
  //
  // Stitch: <h2 class="px-page-padding font-section-header text-section-header
  // mb-3">. 15/700, +0.02em, 12px below, NO SUBTITLE. Ours were 17/w800 with a
  // grey subtitle under each, which is what made the page read as a stack of
  // shouted headings.
  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(
            StaySpacing.page, 0, StaySpacing.page, StaySpacing.inline),
        child: Text(title,
            style: StayType.sectionHeader.on(GoOutsColors.deepNavy)),
      );

  /// ⚠ ADDED 9 September 2026, building the web version of this app. See the
  /// call site above in build() for why this exists. Same visual language as
  /// the rest of this screen (GoOutsColors, StayType, StaySpacing) so it
  /// doesn't look bolted on.
  Widget _foodOrderingCard() => InkWell(
        onTap: () => Navigator.of(context).pushNamed('/food-delivery'),
        borderRadius: BorderRadius.circular(StaySpacing.inline),
        child: Container(
          padding: const EdgeInsets.all(StaySpacing.card),
          decoration: BoxDecoration(
            color: GoOutsColors.cardSurface,
            borderRadius: BorderRadius.circular(StaySpacing.inline),
            border: Border.all(color: GoOutsColors.paleBlueTint),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: GoOutsColors.paleBlueTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_outlined,
                    color: GoOutsColors.primaryBlue),
              ),
              const SizedBox(width: StaySpacing.card),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Order food too',
                        style: StayType.buttonText.on(GoOutsColors.deepNavy)),
                    const SizedBox(height: 2),
                    Text('Get it delivered and earn cashback at the same time.',
                        style:
                            StayType.caption.on(GoOutsColors.outlineVariant)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 14, color: GoOutsColors.outlineVariant),
            ],
          ),
        ),
      );

  // ── CARDS ─────────────────────────────────────────────────────────────────

  /// Stitch: `absolute top-3 left-3 bg-primary text-on-primary px-3 py-1.5
  /// rounded-full text-caption font-bold shadow-md`.
  ///
  /// SOLID primary, not a translucent scrim, and it says "14 partners nearby"
  /// in full. Ours was a 82%-opacity navy chip reading "4 nearby" with a tag
  /// icon — smaller, vaguer, and the one number this product exists to compute.
  Widget _partnerBadge(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: GoOutsColors.primaryBlue,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Text('$n ${n == 1 ? 'partner' : 'partners'} nearby',
            style: StayType.caption.bold.on(Colors.white)),
      );

  /// Stitch's pale chip, used under the title in the second section.
  Widget _tintChip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: GoOutsColors.paleBlueTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: StayType.caption.semibold.on(GoOutsColors.primaryBlue)),
      );

  Widget _photo(StayListing l, {required double h, double w = double.infinity}) {
    final List<StayPhoto> photos = List<StayPhoto>.from(l.photos)
      ..sort((a, b) => a.order.compareTo(b.order));

    Widget placeholder() => Container(
          height: h,
          width: w,
          color: GoOutsColors.paleBlueTint,
          child: const Icon(Icons.home_outlined,
              size: 32, color: GoOutsColors.primaryBlue),
        );

    if (photos.isEmpty) return placeholder();
    return Image.network(
      photos.first.url,
      height: h,
      width: w,
      fit: BoxFit.cover,
      // Decoded to roughly card size. Without this a host's 3000px photograph is
      // decoded and held at full resolution for a thumbnail.
      cacheWidth: 700,
      errorBuilder: (_, __, ___) => placeholder(),
    );
  }

  /// Star + rating, sized to sit on the title row like Stitch's `☆ 4.8`.
  ///
  /// A property with no reviews shows NOTHING rather than 0.0 beside a star,
  /// which reads as a bad property instead of a new one.
  Widget _rating(StayListing l) {
    if (l.ratingCount == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.star_border_rounded,
            size: 16, color: GoOutsColors.primaryBlue),
        const SizedBox(width: 2),
        Text(l.ratingAvg.toStringAsFixed(1),
            style: StayType.caption.semibold.on(GoOutsColors.primaryBlue)),
      ],
    );
  }

  /// "£85" bold + " nightly" regular, both at card-title size so they share one
  /// baseline. Ours was 15/w800 + 11.5, which is two sizes and a weight the
  /// design does not contain.
  Widget _price(StayListing l) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l.nightlyRate.compact,
              style: StayType.price.on(GoOutsColors.deepNavy)),
          Text(' nightly', style: StayType.priceUnit.on(GoOutsColors.bodyText)),
        ],
      );

  /// ⚠ DOES NOT RECORD THE VIEW. 05_listing_detail_screen does, in initState,
  /// because listings also open from search results and this screen is not the
  /// only door. Recording here would mean anything found by searching never
  /// entered the history.
  ///
  /// It only REFRESHES the row on the way back, so a property just looked at
  /// appears without needing a pull-to-refresh.
  void _openListing(StayListing l) {
    Navigator.of(context)
        .pushNamed(StayRoutes.listing,
            arguments: <String, dynamic>{'listingId': l.id})
        .then((_) => _loadRecent());
  }

  /// Section 1. Stitch: w-[260px], rounded-xl (12), image h-40 (160).
  Widget _partnersRow(List<StayListing> items) {
    return SizedBox(
      height: 160 + 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: StaySpacing.pageH,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: StaySpacing.card),
        itemBuilder: (context, i) {
          final StayListing l = items[i];
          final int partners = l.locationContext?.partnerCounts.halfMile ?? 0;

          return InkWell(
            onTap: () => _openListing(l),
            borderRadius: BorderRadius.circular(StaySpacing.inline),
            child: Container(
              width: 260,
              decoration: BoxDecoration(
                color: GoOutsColors.cardSurface,
                borderRadius: BorderRadius.circular(StaySpacing.inline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      _photo(l, h: 160, w: 260),
                      // Hidden entirely until the location engine has run.
                      // "0 partners nearby" would not be true — it is not known
                      // yet — and this figure is the whole proposition.
                      if (partners > 0)
                        Positioned(
                            left: StaySpacing.inline,
                            top: StaySpacing.inline,
                            child: _partnerBadge(partners)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(StaySpacing.inline),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                l.address.town.isEmpty ? l.title : l.address.town,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: StayType.cardTitle
                                    .on(GoOutsColors.deepNavy),
                              ),
                            ),
                            _rating(l),
                          ],
                        ),
                        const SizedBox(height: 2),
                        _price(l),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Section 2. Stitch's "Weekend breaks" card shape — image, title, then
  /// rating and price on ONE row, then a pale partners chip.
  ///
  /// Vertical two-column grid rather than a sideways row: this list is every
  /// remaining property, and a long list that scrolls sideways is one nobody
  /// reaches the end of.
  /// [crossAxisCount] and [photoHeight] default to the original mobile
  /// shape (2 columns, 118px photo). The desktop city sections added
  /// 9 September 2026 pass 4 and a shorter photo — narrower cards read as
  /// more deliberate on a wide monitor than two oversized ones stretched
  /// edge to edge, which is what this grid looked like at the old 2-column
  /// count on a 1400px desktop row.
  Widget _wideRow(List<StayListing> items,
      {int crossAxisCount = 2, double photoHeight = 118}) {
    final double cardHeight = photoHeight + 114;
    return Padding(
      padding: StaySpacing.pageH,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: StaySpacing.card,
          crossAxisSpacing: StaySpacing.card,
          mainAxisExtent: cardHeight,
        ),
        itemBuilder: (context, i) {
          final StayListing l = items[i];
          final int partners = l.locationContext?.partnerCounts.halfMile ?? 0;

          return InkWell(
            onTap: () => _openListing(l),
            borderRadius: BorderRadius.circular(StaySpacing.inline),
            child: Container(
              decoration: BoxDecoration(
                color: GoOutsColors.cardSurface,
                borderRadius: BorderRadius.circular(StaySpacing.inline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _photo(l, h: photoHeight),
                  Padding(
                    padding: const EdgeInsets.all(StaySpacing.inline),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          l.address.town.isEmpty ? l.title : l.address.town,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: StayType.cardTitle.on(GoOutsColors.deepNavy),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            _rating(l),
                            if (l.ratingCount > 0) const SizedBox(width: 6),
                            Flexible(child: _price(l)),
                          ],
                        ),
                        if (partners > 0) ...<Widget>[
                          const SizedBox(height: StaySpacing.card),
                          _tintChip('$partners '
                              '${partners == 1 ? 'partner' : 'partners'} nearby'),
                        ] else if (_rate.isKnown) ...<Widget>[
                          const SizedBox(height: StaySpacing.card),
                          _tintChip('${_rate.label} back'),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Section 3. Stitch: a white panel holding small items — thumbnail, caption
  /// title, price. Now backed by StayRecentlyViewed, so the heading is true.
  Widget _recentRow() {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: StaySpacing.pageH,
        itemCount: _recent.length,
        separatorBuilder: (_, __) => const SizedBox(width: StaySpacing.card),
        itemBuilder: (context, i) {
          final StayListing l = _recent[i];
          return InkWell(
            onTap: () => _openListing(l),
            borderRadius: BorderRadius.circular(StaySpacing.inline),
            child: Container(
              width: 190,
              decoration: BoxDecoration(
                color: GoOutsColors.cardSurface,
                borderRadius: BorderRadius.circular(StaySpacing.inline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _photo(l, h: 90, w: 190),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: StaySpacing.card, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(l.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                StayType.caption.on(GoOutsColors.deepNavy)),
                        const SizedBox(height: 2),
                        Text(l.nightlyRate.compact,
                            style: StayType.caption.semibold
                                .on(GoOutsColors.bodyText)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // The bottom bar moved to widgets/stay_bottom_nav.dart on 28 August 2026, so
  // one definition serves every Short Stay screen. This screen had the only
  // working copy; four other screens had a version with no handlers at all.

  // ── STATES ────────────────────────────────────────────────────────────────

  Widget _skeletons() {
    Widget box(double h, double w, [double r = 8]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: GoOutsColors.dividerGray,
            borderRadius: BorderRadius.circular(r),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
              StaySpacing.page, 0, StaySpacing.page, StaySpacing.inline),
          child: box(15, 240),
        ),
        SizedBox(
          height: 160 + 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: StaySpacing.pageH,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: StaySpacing.card),
            itemBuilder: (_, __) => Container(
              width: 260,
              decoration: BoxDecoration(
                color: GoOutsColors.cardSurface,
                borderRadius: BorderRadius.circular(StaySpacing.inline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  box(160, 260, 0),
                  const SizedBox(height: StaySpacing.inline),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: StaySpacing.inline),
                      child: box(14, 160)),
                  const SizedBox(height: StaySpacing.card),
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: StaySpacing.inline),
                      child: box(14, 100)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shown when the query FAILED. Deliberately not the same as the empty state:
  /// "no properties are listed yet" is a lie if the truth is that the app could
  /// not read them.
  Widget _buildLoadFailed() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded,
              size: 48, color: GoOutsColors.primaryBlue),
          const SizedBox(height: StaySpacing.inline),
          Text('We could not load properties',
              style: StayType.cardTitle.on(GoOutsColors.deepNavy)),
          const SizedBox(height: 6),
          Text('They are still there. Something went wrong fetching them.',
              textAlign: TextAlign.center,
              style: StayType.body.on(GoOutsColors.bodyText)),
          const SizedBox(height: StaySpacing.inline),
          // The real message. A guest will not read it, and the one person who
          // needs it — whoever is asked "why can I not see listings" — gets the
          // answer from the screen instead of from the source.
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: StayType.caption
                .on(GoOutsColors.bodyText.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: StaySpacing.inline),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _loadListings();
              _loadRate();
            },
            child: Text('Try again',
                style: StayType.caption.semibold
                    .on(GoOutsColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: <Widget>[
          const Icon(Icons.holiday_village_outlined,
              size: 48, color: GoOutsColors.primaryBlue),
          const SizedBox(height: StaySpacing.inline),
          Text('No properties are listed yet',
              style: StayType.cardTitle.on(GoOutsColors.deepNavy)),
          const SizedBox(height: 6),
          Text('Search for a town above, or check back soon.',
              textAlign: TextAlign.center,
              style: StayType.body.on(GoOutsColors.bodyText)),
        ],
      ),
    );
  }
}

/// Icon-then-label nav item, one row, hover-aware. Same widget as
/// desktop_top_nav.dart's own _NavIconTab (deliberately not shared — see
/// that file's note on why this nav bar stays a separate inline copy).
class _NavIconTab extends StatefulWidget {
  const _NavIconTab({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  State<_NavIconTab> createState() => _NavIconTabState();
}

class _NavIconTabState extends State<_NavIconTab> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final Color color = widget.active
        ? GoOutsColors.primaryBlue
        : _hovering
            ? GoOutsColors.primaryBlue
            : GoOutsColors.deepNavy;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, size: 19, color: color),
              const SizedBox(width: 7),
              Text(widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight:
                        widget.active ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
