import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/short_stay/stay_routes.dart';
import '../features/short_stay/widgets/desktop_top_nav.dart'
    show JoinAsHostButton, AccountMenuButton, GoOutsBrandLogo;
import '../services/delivery_address_service.dart';
import '../services/scheduled_delivery_service.dart';
import '../widgets/delivery_address_search_field.dart';
import '../widgets/delivery_time_picker.dart';
import '../widgets/food_bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GoOuts Food Delivery — Restaurant Listing & Discovery Screen
//  Task 71 | Cuisines sourced from Deliveroo + UberEats UK live data
// ─────────────────────────────────────────────────────────────────────────────

class FoodDeliveryScreen extends StatefulWidget {
  const FoodDeliveryScreen({super.key});

  @override
  State<FoodDeliveryScreen> createState() => _FoodDeliveryScreenState();
}

class _FoodDeliveryScreenState extends State<FoodDeliveryScreen>
    with SingleTickerProviderStateMixin {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFF0392CA); // GoOuts blue. Was 0xFFEA580C.
  static const Color _navy     = Color(0xFF0D1B3E);
  static const Color _purple   = Color(0xFF7C3AED);
  static const Color _bg       = Color(0xFFF2F4F7);

  // ── Cuisine categories (Deliveroo + UberEats UK) ────────────────────────────
  // Stored in Firestore `foodCuisines` collection in production.
  // Hardcoded here as fallback so screen works before Firestore is seeded.
  //
  // ⚠ MATERIAL ICONS, NOT EMOJI. Changed 9 September 2026. CanvasKit (the
  // renderer `flutter build web` ships by default) has no colour-emoji font
  // — Skia can't paint 🍕/🍛/etc. at all, so on web it silently fell back to
  // a blank/white glyph box. Reported as "icon becomes unrecognizable on
  // hover" — it isn't hover-specific, hover just repaints the chip and
  // exposes the box that was always blank. Material icons are vector glyphs
  // CanvasKit draws natively, so this is a real fix, not a workaround.
  static const _cuisineList = [
    _Cuisine(Icons.apps_rounded, 'All'),
    _Cuisine(Icons.local_pizza_rounded, 'Pizza'),
    _Cuisine(Icons.dinner_dining_rounded, 'Indian'),
    _Cuisine(Icons.ramen_dining_rounded, 'Chinese'),
    _Cuisine(Icons.lunch_dining_rounded, 'Burgers'),
    _Cuisine(Icons.set_meal_rounded, 'Sushi'),
    _Cuisine(Icons.tapas_rounded, 'Mexican'),
    _Cuisine(Icons.kebab_dining_rounded, 'Kebab'),
    _Cuisine(Icons.soup_kitchen_rounded, 'Thai'),
    _Cuisine(Icons.local_pizza_rounded, 'Italian'),
    _Cuisine(Icons.rice_bowl_rounded, 'Japanese'),
    _Cuisine(Icons.eco_rounded, 'Healthy'),
    _Cuisine(Icons.dinner_dining_rounded, 'Lebanese'),
    _Cuisine(Icons.restaurant_rounded, 'Chicken'),
    _Cuisine(Icons.free_breakfast_rounded, 'Breakfast'),
    _Cuisine(Icons.fastfood_rounded, 'American'),
    _Cuisine(Icons.set_meal_rounded, 'Fish & Chips'),
    _Cuisine(Icons.tapas_rounded, 'Greek'),
    _Cuisine(Icons.soup_kitchen_rounded, 'Pakistani'),
    _Cuisine(Icons.restaurant_menu_rounded, 'Caribbean'),
    _Cuisine(Icons.soup_kitchen_rounded, 'Nigerian'),
    _Cuisine(Icons.outdoor_grill_rounded, 'Korean BBQ'),
    _Cuisine(Icons.icecream_rounded, 'Desserts'),
    _Cuisine(Icons.local_grocery_store_rounded, 'Groceries'),
  ];

  // ── Dietary filters (separate row, shown when Filters expanded) ─────────────
  // Matches `dietaryTags` field saved by admin panel
  static const _dietaryList = [
    'Halal', 'Vegetarian', 'Vegan', 'Gluten Free',
    'Kosher', 'Nut Free', 'Dairy Free',
  ];

  // ── Sort options ────────────────────────────────────────────────────────────
  static const _sortOptions = ['Popular', 'Fastest', 'Top Rated', 'Lowest Fee'];

  // ── State ───────────────────────────────────────────────────────────────────
  final _searchCtrl   = TextEditingController();
  // ⚠ ADDED 9 September 2026. The cuisine row's own ScrollController — see
  // _buildCuisineRow for why it needs one on web.
  final _cuisineScrollCtrl = ScrollController();
  final _addrService  = DeliveryAddressService(); // singleton — safe as field
  // ⚠ "Deliver now" scheduling state MOVED 10 September 2026 into
  // ScheduledDeliveryService (services/scheduled_delivery_service.dart) — a
  // local field here was lost the moment the user navigated into a
  // restaurant's menu or checkout. Now genuinely wired end to end: this
  // screen's picker, checkout_screen.dart's display, createFoodOrder
  // (validates + stores it), a release sweep that holds the order back from
  // driver dispatch until shortly before the chosen time, and the order
  // tracking screen. See food_orders.js for the server side.
  final _scheduledService = ScheduledDeliveryService();
  String _searchQuery      = '';
  String _selectedCuisine  = 'All';
  String _sortBy           = 'Popular';
  bool   _socialBoostOnly  = false;
  bool   _filtersExpanded  = false;
  final Set<String> _selectedDietary = {};

  late final TabController _tabCtrl;

  /// How many restaurants the list will fetch and hold a listener on.
  /// See the note on the query in _buildRestaurantList before changing it.
  static const int _listLimit = 60;

  /// Decode width for a cover photo, in device pixels.
  ///
  /// A card is about 150 logical pixels tall and full width. Without this,
  /// Image.network decodes the ORIGINAL — a 3000px partner photograph is
  /// decoded and held in memory at full size for a thumbnail, which is both
  /// the scroll jank and a large slice of the memory this screen uses.
  static const int _coverDecodeWidth = 800;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    _cuisineScrollCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ⚠ ADDED 9 September 2026 — same "professional desktop shell" pass as
    // 01_short_stay_home_screen.dart. See that file's build() for the full
    // reasoning (Airbnb/Uber Eats/Deliveroo/booking.com all top nav + a
    // centred, gutter-both-sides content column, never a phone tab bar
    // pinned to the bottom of a browser window). The mobile branch below is
    // completely unchanged.
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool desktop = kIsWeb && constraints.maxWidth >= 900;
        return desktop ? _buildDesktop(context) : _buildMobile(context);
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:
          const FoodBottomNav(current: FoodTab.restaurants),
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: _buildHeroBand(
              child: Column(
                children: [
                  _buildSearchAndFilter(),
                  _buildCuisineRow(),
                ],
              ),
            ),
          ),
          // ── DIETARY ROW SITS BELOW THE BAND, NOT INSIDE IT ──────────────
          //
          // Its chips are green and purple when selected. On the coloured band
          // that is three warm colours fighting; on the neutral background
          // they read as what they are — filters, not decoration.
          if (_filtersExpanded)
            SliverToBoxAdapter(child: _buildDietaryRow()),
          SliverToBoxAdapter(child: _buildAddressBanner()),
          SliverToBoxAdapter(child: _buildPromoBanner()),
          SliverToBoxAdapter(child: _buildSectionHeader('Restaurants near you')),
          _buildRestaurantList(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DESKTOP WEB LAYOUT
  // ══════════════════════════════════════════════════════════════════════════

  static const double _desktopMaxWidth = 1400;

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: <Widget>[
          _desktopTopNav(context),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                // ── ⚠ ADDED 9 September 2026. Reference given directly: a
                // screenshot of ubereats.com's own homepage — full-bleed
                // food photo, one big headline, ONE address search row with
                // a "Find Food" button, "Or Sign in" beneath. This is a NEW
                // top section, not a replacement for _buildHeroBand below
                // it: that band's search bar searches RESTAURANTS AND DISHES
                // within an address already set, while this one's job is
                // setting the address itself — two different questions, so
                // both stay, in the order a guest actually answers them.
                _desktopHero(context),
                _buildHeroBand(
                  // ⚠ FIXED 9 September 2026, same bug and same fix as
                  // 01_short_stay_home_screen.dart's _desktopSection: a
                  // Column's WIDTH (its cross axis) shrink-wraps to its
                  // widest child under a loose constraint — ConstrainedBox
                  // only sets a ceiling, it does not make the Column actually
                  // BE 1400 wide. The SizedBox(width: double.infinity) forces
                  // that, so Center() centres an even, full-width lane
                  // instead of a shrink-wrapped blob.
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: _desktopMaxWidth),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: <Widget>[
                            const SizedBox(height: 8),
                            _buildSearchAndFilter(),
                            _buildCuisineRow(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _desktopMaxWidth),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: <Widget>[
                          if (_filtersExpanded) _buildDietaryRow(),
                          // ⚠ REMOVED 10 September 2026 — this used to be
                          // _desktopBannersRow(): the big purple "Social
                          // Boost" promo strip, plus a redundant "Set
                          // delivery address" chip (the hero above already
                          // has a live DeliveryAddressField, so that chip
                          // was a second way to do the same thing). Social
                          // Boost now lives as a small nav-bar link + "BONUS"
                          // badge in _desktopTopNav, matching goouts.co.uk's
                          // own nav treatment instead of a full banner.
                          _buildSectionHeader('Restaurants near you'),
                          _desktopRestaurantGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 64),
                _desktopFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Full-bleed photo hero — see the ⚠ note above its call site for why it
  /// coexists with _buildHeroBand rather than replacing it.
  ///
  /// ⚠ THE PHOTO IS A STOCK UNSPLASH IMAGE, NOT A GOOUTS ASSET. Same image
  /// (photo-1568901346375-23c9450c58cd, "Bleecker Burger") already used
  /// elsewhere in this codebase (partner_seed_service.dart, nearby_screen.dart)
  /// at thumbnail size — reused here at hero size rather than a new unverified
  /// URL, so it is already known to load. It illustrates food in general, it
  /// is not a photograph of any actual GoOuts partner or dish, and should be
  /// swapped for real brand photography whenever that exists.
  Widget _desktopHero(BuildContext context) {
    return SizedBox(
      // ⚠ SWAPPED 10 September 2026 (fifth swap) — the flat-background
      // burger plate photo (food_hero_burgers.jpg, kept in the repo, no
      // longer referenced here) was replaced with the person's own
      // "hungry couple ordering on their phone" image, saved into
      // assets/images/food_hero_couple.jpg. Source was 1504x910 — resized
      // up to 2400px wide with Lanczos resampling and ONLY a light unsharp
      // mask (radius 1.6, percent 55). The previous photo's aggressive
      // sharpen pass is exactly what caused the "pixelated cover around the
      // object" complaint fixed just before this swap — kept deliberately
      // restrained this time. Re-run the same restrained settings if this
      // photo is ever swapped again.
      //
      // ⚠ TEXT COLOUR BACK TO WHITE + GRADIENT SCRIM RE-ADDED. The burger
      // photo was flat yellow everywhere behind the text, so navy-on-yellow
      // with no scrim worked. This photo has real subjects — two people,
      // one in a dark grey T-shirt — sitting exactly where the text overlay
      // sits (bottom-left). Navy text would go dark-on-dark over the shirt.
      // A bottom-left gradient scrim (transparent -> _navy at ~70% opacity)
      // guarantees contrast regardless of what's directly behind the text,
      // which is the same reasoning the ORIGINAL pre-burger photo used.
      //
      // ⚠ ALIGNMENT BIASED UP, Alignment(0, -0.35). BoxFit.cover on a wide
      // viewport crops top and bottom evenly from the centre by default,
      // which risked cropping into the couple's heads — the one thing that
      // must never be cropped in a photo of people. Biasing the visible
      // window upward keeps both faces safely in frame; the food on the
      // right (which extends further down the frame) can afford to lose a
      // little more off its bottom edge than a forehead can.
      //
      // ⚠ OUTLINE THINNED, 10 September 2026, reported as "outer lines
      // from couple" — the source composite had a visible hard dark ring
      // where the two people were cut out and placed onto the yellow
      // background (most visible on the man's shoulder and the woman's
      // hair). Fixed at the source, before the resize/sharpen above: found
      // dark pixels sitting right next to the bright yellow background
      // (that combination is the ring, not real photo detail), and blended
      // just those pixels toward a blurred version of themselves so the
      // line thins into the background instead of sitting as a crisp cutout
      // edge. Everything else in the photo — hair, the man's dark T-shirt,
      // shadows — was left untouched since it isn't next to the yellow.
      //
      // ⚠ FACES BRIGHTENED, 10 September 2026, reported as "still very
      // dark", then again as "need little more bright". Measured rather
      // than guessed both times. First pass: gamma 1.35 + brightness 1.05.
      // Second pass, this one: gamma raised to 1.55 and brightness to 1.10
      // (contrast held at 1.03) — man's face luminance ended up ~126/255,
      // woman's ~199/255, background ~211/255, checked against a crop
      // before shipping to confirm nothing had blown out to flat white.
      // Same gamma-over-flat-brightness reasoning as the first pass: it
      // lifts shadows and midtones (the people) much more than the
      // already-bright background, so there was still headroom to push
      // further without losing the yellow.
      height: 720,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(color: const Color(0xFFFAC836)), // shows instantly while the photo loads — sampled from this photo's own background yellow, so there's no colour flash
          Image.asset(
            'assets/images/food_hero_couple.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.35),
            errorBuilder: (_, __, ___) => Container(color: _navy),
          ),
          // Legibility scrim — see the ⚠ note above on why white text needs
          // this now. Strongest bottom-left (behind the text), fading to
          // nothing across the rest of the photo so the food on the right
          // stays fully visible and un-dimmed.
          //
          // ⚠ LIGHTENED 10 September 2026, reported as "too dark" — this
          // started at 0xCC (80%) opacity and faded out by 62% across the
          // photo, which dimmed the couple themselves, not just the text
          // area. Dropped to 0x80 (50%) and pulled the fade in to 42% so it
          // stays tight behind the text corner. The text's own drop shadow
          // (see _HeroHeadline) was already doing real work, so a lighter
          // scrim underneath it is still enough for contrast.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: <Color>[
                    Color(0x800D1B3E),
                    Color(0x000D1B3E),
                  ],
                  stops: <double>[0.0, 0.42],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _desktopMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Rotating headline — ADDED 10 September 2026,
                      // requested directly: "a text animation ... day is
                      // over lets order food from GoOuts & Get Cashback".
                      // Fixed-height box so the search row below never
                      // jumps as the messages change length; see
                      // _HeroHeadline for the rotation itself.
                      const SizedBox(
                        height: 116,
                        child: _HeroHeadline(),
                      ),
                      const SizedBox(height: 24),
                      _desktopHeroSearchRow(context),
                      // ⚠ "Or Sign in" REMOVED 10 September 2026 — the top
                      // nav (_desktopTopNav) already has its own Sign in
                      // button on every page, this one was a duplicate.
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The address bar. Deliberately separate from _buildSearchAndFilter's
  /// restaurant/dish search box below — this one answers "where", that one
  /// answers "what", and they read the same values (_addrService) rather
  /// than duplicating state.
  ///
  /// ⚠ REBUILT 10 September 2026 — used to be read-only text that opened
  /// the /food-address-picker page. That page is gone; this box is now a
  /// live DeliveryAddressField (same Mapbox-backed finder the registration
  /// postcode lookup uses) — type an address or postcode right here.
  Widget _desktopHeroSearchRow(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 760),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 16),
          Expanded(
            child: DeliveryAddressField(
              iconColor: Colors.black54,
              textColor: _navy,
              fontSize: 15,
            ),
          ),
          Container(width: 1, height: 32, color: Colors.grey.shade300),
          // ⚠ FIXED 10 September 2026 — used to be decorative. Now opens
          // showDeliveryTimeSheet() (widgets/delivery_time_picker.dart), a
          // real date/time picker wired end to end — see food_orders.js.
          ListenableBuilder(
            listenable: _scheduledService,
            builder: (context, _) => InkWell(
              onTap: () => showDeliveryTimeSheet(context),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.schedule_rounded,
                        size: 18, color: Colors.black54),
                    const SizedBox(width: 8),
                    Text(
                        deliveryTimeLabel(
                            context, _scheduledService.scheduledFor),
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _navy,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: ElevatedButton(
              onPressed: () {
                final addr = _addrService.current;
                if (addr == null) {
                  showDeliveryAddressSheet(context);
                }
                // Address already set: nothing to do here — the restaurant
                // grid below is already filtered to it via _addrService,
                // this button's job in that case is just to invite a
                // scroll, which a click on it naturally causes anyway.
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                elevation: 0,
              ),
              child: Text('Find Food',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ── ⚠ ICON-BEFORE-TEXT, 9 September 2026 — see 01_short_stay_home_
  //    screen.dart's own note on the matching change for the full reasoning.
  //    Same layout, same hover behaviour, mirrored here so the tab a guest
  //    is looking at reads the same whichever of the two top-level pages
  //    they are on.
  Widget _desktopTopNav(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFBEC8D0), width: 1)),
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
                          onTap: () => Navigator.of(context)
                              .pushNamedAndRemoveUntil(
                                  StayRoutes.home, (r) => r.isFirst),
                        ),
                        const SizedBox(width: 4),
                        _NavIconTab(
                          icon: Icons.restaurant_rounded,
                          label: 'Food Delivery',
                          active: true,
                          onTap: () {},
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
                // ── FAR RIGHT: Cart + Orders only once signed in (fixed 23
                // September 2026, per Mian — a guest has no cart or order
                // history yet, so showing those icons before login was
                // misleading), then Social Boost (a browse-time promo link,
                // relevant to guests too), then Join as Host and
                // profile+menu LAST. Spacing widened from 4px to 10px
                // between these icons so they read as separate tap targets
                // instead of a cramped cluster.
                if (user != null) ...<Widget>[
                  _cartIconButton(context),
                  const SizedBox(width: 10),
                  _NavIconTab(
                    icon: Icons.receipt_long_rounded,
                    label: 'Orders',
                    onTap: () {
                      Navigator.of(context).pushNamed('/food-order-history');
                    },
                  ),
                  const SizedBox(width: 10),
                ],
                _socialBoostNavLink(context),
                const SizedBox(width: 20),
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

  // ⚠ _navLink REMOVED 14 September 2026 — Sign up/Sign in/Sign out moved
  // into AccountMenuButton's dropdown (desktop_top_nav.dart) as part of the
  // same nav rebuild that moved account controls to the far left. Cart is
  // now its own icon button below, matching the mobile app bar's cart icon
  // exactly rather than the text link it used to be here.

  /// Same treatment as the mobile app bar's cart icon (shopping_bag_outlined
  /// + a small dot) — see that AppBar's `actions` above. The dot is not a
  /// live item count there either ("Cart badge — wire to CartService
  /// later"), so this does not invent one; it stays visually consistent
  /// with the existing, honest state rather than showing a number nothing
  /// backs.
  Widget _cartIconButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/food-cart'),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const Icon(Icons.shopping_bag_outlined,
                size: 22, color: _navy),
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration:
                    const BoxDecoration(color: _primary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Social Boost" nav link with its small "BONUS" badge — pulled straight
  /// from goouts.co.uk's own top nav, not guessed: that site's badge is
  /// white 9px/weight-900 text, 5px/1px padding, 4px corners, on a
  /// 135deg purple (#6C63FF) -> amber (#F59E0B) gradient (read from its
  /// live CSS on 10 September 2026). Badge text updated to drop the flat
  /// "2X" multiplier since Social Boost is now tier-based (1.5x/2x/2.5x by
  /// follower count, not a flat 2X). Toggles the same _socialBoostOnly
  /// filter the old promo banner's tap target never actually did anything
  /// with — this one filters the grid for real.
  ///
  /// ⚠ LEADING ICON ADDED 10 September 2026, requested directly, matching
  /// _NavIconTab's icon-before-label pattern used by Stay/Food/Orders —
  /// bolt icon, the same one already standing in for the ⚡ emoji everywhere
  /// else Social Boost appears in this file (CanvasKit-on-web has no emoji
  /// font — see the note on that fix further up this file's history).
  Widget _socialBoostNavLink(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _socialBoostOnly = !_socialBoostOnly),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.bolt_rounded,
                size: 19,
                color: _socialBoostOnly ? _primary : _navy),
            const SizedBox(width: 7),
            Text('Social Boost',
                style: GoogleFonts.inter(
                  fontSize: 14.5,
                  fontWeight:
                      _socialBoostOnly ? FontWeight.w700 : FontWeight.w500,
                  color: _socialBoostOnly ? _primary : _navy,
                )),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF6C63FF), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('BONUS',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  /// Same query, filters and sort as [_buildRestaurantList] — duplicated
  /// rather than shared because that method must return a Sliver (it lives
  /// directly in the mobile CustomScrollView) and this one must return a
  /// plain box (it lives in a desktop-only ListView). Keeping two small
  /// methods is lower risk than making one method serve two different
  /// parent protocols.
  Widget _desktopRestaurantGrid() => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .where('isOnline', isEqualTo: true)
            .where('isApproved', isEqualTo: true)
            .limit(_listLimit)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _listMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load restaurants',
              body: '${snapshot.error}',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _skeletons();
          }

          final restaurants = <_RestaurantItem>[];
          final skipped = <String>[];
          for (final d in (snapshot.data?.docs ?? const [])) {
            try {
              restaurants.add(_RestaurantItem.fromDoc(d));
            } catch (e) {
              skipped.add('${d.id}: $e');
            }
          }
          if (skipped.isNotEmpty) {
            debugPrint('food (desktop): dropped ${skipped.length} unreadable '
                'restaurant(s): ${skipped.join(" | ")}');
          }

          if (restaurants.isEmpty) {
            return _listMessage(
              icon: Icons.storefront_outlined,
              title: 'No restaurants available yet',
              body: 'We are adding partners in your area. Please check back '
                  'soon.',
            );
          }

          var filtered = restaurants.where((r) {
            if (_searchQuery.isNotEmpty &&
                !r.name.toLowerCase().contains(_searchQuery) &&
                !r.cuisineType.toLowerCase().contains(_searchQuery)) {
              return false;
            }
            if (_selectedCuisine != 'All' &&
                !r.cuisineType
                    .toLowerCase()
                    .contains(_selectedCuisine.toLowerCase())) {
              return false;
            }
            if (_socialBoostOnly && !r.socialBoostEnabled) return false;
            for (final d in _selectedDietary) {
              final norm = d.toLowerCase().replaceAll('-', ' ');
              if (!r.tags.any((t) => t.toLowerCase().replaceAll('-', ' ') == norm)) {
                return false;
              }
            }
            return true;
          }).toList();

          switch (_sortBy) {
            case 'Top Rated':
              filtered.sort((a, b) => b.rating.compareTo(a.rating));
              break;
            case 'Fastest':
              filtered.sort((a, b) => a.deliveryMins.compareTo(b.deliveryMins));
              break;
            case 'Lowest Fee':
              filtered.sort((a, b) => a.deliveryFee.compareTo(b.deliveryFee));
              break;
            default:
              break;
          }

          if (filtered.isEmpty) return _emptyState();

          // ── ⚠ EXACTLY 4 PER ROW, ALIGNED WITH THE HEADER, 9 September
          // 2026. Was a plain Wrap of 380px-wide cards — at 1400px wide that
          // fits 3 with a large uneven gap on the right, not a real grid.
          // LayoutBuilder computes a card width that makes 4 fit exactly
          // (with a fixed 20px gap between them), and the whole grid is
          // wrapped in the SAME 16px horizontal padding _buildSectionHeader,
          // _buildAddressBanner and _buildPromoBanner already use, so the
          // first and last card line up with "Restaurants near you" and the
          // Social Boost bar above rather than starting flush at the very
          // edge.
          //
          // ⚠ desktop: true on _restaurantCard strips its own baked-in 16px
          // side margin (meant for the single-column mobile list) — left in
          // place here, the margin would have added on TOP of this grid's
          // own 16px padding and 20px gaps, throwing the alignment off
          // again in the other direction.
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const int cols = 4;
                const double gap = 20;
                final double cardWidth =
                    (constraints.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final r in filtered)
                      SizedBox(
                        width: cardWidth,
                        child: _restaurantCard(r, desktop: true),
                      ),
                  ],
                );
              },
            ),
          );
        },
      );

  Widget _desktopFooter() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFBEC8D0), width: 1)),
        ),
        child: Center(
          child: Text('© ${DateTime.now().year} GoOuts',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
        ),
      );

  // ── App bar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      // The brand colour, so the app bar and the search band below it read
      // as one header rather than a white strip on a coloured panel.
      backgroundColor: _primary,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      // Address bar replaces static title
      title: ListenableBuilder(
        listenable: _addrService,
        builder: (context, _) {
          final addr = _addrService.current;
          return GestureDetector(
            onTap: () => showDeliveryAddressSheet(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  addr != null
                      ? Icons.location_on_rounded
                      : Icons.location_searching_rounded,
                  // ⚠ WAS _primary — the exact same blue as this app bar's
                  // own background, so the pin rendered invisible. This whole
                  // block's colours (grey label, navy address, primary-blue
                  // icon) were written for a white background and never
                  // adjusted when it moved into the blue app bar title.
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        addr != null ? 'Delivering to' : 'Set delivery address',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500),
                      ),
                      if (addr != null)
                        Text(
                          addr.shortDisplay,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.8), size: 18),
              ],
            ),
          );
        },
      ),
      centerTitle: false,
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.black87),
              onPressed: () => Navigator.pushNamed(context, '/food-cart'),
            ),
            // Cart badge — wire to CartService later
            Positioned(
              right: 8, top: 8,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: _primary, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Search + filter row ─────────────────────────────────────────────────────
  // ⚠ SPACING, 9 September 2026 — reported as the search bar and cuisine
  // chips sitting flush against each other with no breathing room. Top
  // padding gives the band air above the search bar; bottom padding is the
  // actual gap before the chip row (which no longer adds its own top
  // padding — see _buildCuisineRow, so this is the ONLY thing controlling
  // that gap, rather than the two fighting each other).
  Widget _buildSearchAndFilter() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Row(
          children: [
            // Search bar
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                        // ⚠ ADDED 9 September 2026. On web, a plain TextField
                        // gets Chrome's own autofill dropdown — a second box
                        // of the browser's own styling popping up under the
                        // field, nothing to do with this app's UI. Empty
                        // autofillHints (rather than omitting the property)
                        // tells the browser this field has no saved-value
                        // category to suggest from, so it stops offering one.
                        autofillHints: const <String>[],
                        decoration: InputDecoration(
                          hintText: 'Restaurants, dishes...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[400]),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.grey[400], size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Filter toggle button
            GestureDetector(
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _filtersExpanded
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Icon(Icons.tune_rounded,
                    color: _filtersExpanded ? _primary : Colors.white,
                    size: 20),
              ),
            ),
            const SizedBox(width: 12),
            // Sort button
            GestureDetector(
              onTap: _showSortSheet,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort_rounded, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text(_sortBy,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey[700])),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: Colors.grey[500]),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  // ── Cuisine horizontal chips ────────────────────────────────────────────────
  //
  // ⚠ MOUSE SCROLL, 9 September 2026. Reported as "the last chip is cut off
  // and can't be scrolled to" — true on desktop web, where there's no touch
  // swipe. ScrollConfiguration forces drag-to-scroll to also respond to a
  // mouse (Flutter's default MaterialScrollBehavior doesn't always enable
  // this), and the Listener translates a normal (vertical) mouse-wheel
  // scroll into horizontal movement, since a trackpad/wheel over a
  // horizontal list is the natural way a desktop user expects to move it.
  // ⚠ SLIMMED 10 September 2026 — reported as "pills are too thick". Row
  // height 64->56, chip vertical padding 8->6 (icon/text unchanged, just
  // less padding around them). Chip gap standardised to 12 to match the
  // 12px gaps now used in the search/filter/sort row above, so the whole
  // band reads as one consistent spacing system rather than two slightly
  // different ones.
  //
  // ⚠ RIGHT-EDGE FADE ADDED same day — reported as "chips not aligned with
  // Social Boost bar on the right, going out". The row's own padding (16,
  // matching every other band in this section) was already correct — what
  // read as misalignment was the last chip getting hard-clipped mid-pill by
  // the scrollable ListView's own edge, which looks like an overflow bug
  // rather than the "there's more, scroll for it" cue it is. A gradient
  // fade to the band's own background colour over the final chip makes that
  // cut a deliberate scroll affordance instead of a jagged edge, and does
  // not touch the actual (already-correct) 16px right inset underneath it.
  Widget _buildCuisineRow() => SizedBox(
        height: 56,
        child: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const <PointerDeviceKind>{
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: Listener(
                onPointerSignal: (signal) {
                  if (signal is! PointerScrollEvent) return;
                  if (!_cuisineScrollCtrl.hasClients) return;
                  final double delta =
                      signal.scrollDelta.dy.abs() > signal.scrollDelta.dx.abs()
                          ? signal.scrollDelta.dy
                          : signal.scrollDelta.dx;
                  _cuisineScrollCtrl.jumpTo(
                    (_cuisineScrollCtrl.offset + delta).clamp(
                        0.0, _cuisineScrollCtrl.position.maxScrollExtent),
                  );
                },
                child: ListView.builder(
                  controller: _cuisineScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  itemCount: _cuisineList.length,
                  itemBuilder: (context, i) {
                    final c = _cuisineList[i];
                    final selected = c.label == _selectedCuisine;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCuisine = c.label),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          // ⚠ INVERTED FOR THE COLOURED BAND. Selected used to be
                          // _primary, which put the brand colour on the brand
                          // colour and made the chosen cuisine invisible. Still
                          // true now the band is blue rather than orange: the
                          // reason was never the hue, it was the chip matching
                          // its own background.
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.35)),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                      color: _primary.withValues(alpha: 0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(c.icon,
                                size: 15,
                                color: selected ? _primary : Colors.white),
                            const SizedBox(width: 5),
                            Text(c.label,
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color:
                                        selected ? _primary : Colors.white)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 8,
              width: 36,
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0x000392CA), Color(0xFF004C6B)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  // ── Dietary filter chips (expanded) ─────────────────────────────────────────
  Widget _buildDietaryRow() => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          children: [
            // Social Boost toggle
            _dietaryChip(
              label: 'Social Boost',
              icon: Icons.bolt_rounded,
              selected: _socialBoostOnly,
              color: _purple,
              onTap: () => setState(() => _socialBoostOnly = !_socialBoostOnly),
            ),
            ..._dietaryList.map((d) => _dietaryChip(
                  label: d,
                  selected: _selectedDietary.contains(d),
                  color: const Color(0xFF10B981),
                  onTap: () => setState(() => _selectedDietary.contains(d)
                      ? _selectedDietary.remove(d)
                      : _selectedDietary.add(d)),
                )),
          ],
        ),
      );

  // ⚠ `icon` replaces an emoji character that used to be prefixed onto
  // `label` (e.g. "⚡ Social Boost") — CanvasKit (Flutter Web's renderer)
  // has no colour-emoji font, so that emoji painted as a blank/invisible
  // box, not text. A real Icon widget always renders. Same bug class as
  // _coverPlaceholder above.
  Widget _dietaryChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    IconData? icon,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? color : Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? color : Colors.grey[700]),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: selected ? color : Colors.grey[700],
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal)),
            ],
          ),
        ),
      );

  // ── Address prompt banner (shown only when no address set) ─────────────────
  Widget _buildAddressBanner() {
    return ListenableBuilder(
      listenable: _addrService,
      builder: (context, _) {
        final addr = _addrService.current;
        if (addr != null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showDeliveryAddressSheet(context),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(children: [
              const Icon(Icons.location_on_rounded,
                  color: Color(0xFF0392CA), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Set your delivery address to see restaurants near you',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF9A3412),
                      fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF0392CA), size: 18),
            ]),
          ),
        );
      },
    );
  }

  // ── Promo banner ────────────────────────────────────────────────────────────
  Widget _buildPromoBanner() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: GestureDetector(
          onTap: () {}, // future: open Social Boost info sheet
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF0392CA)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -12, top: -12,
                  child: Icon(Icons.campaign_rounded,
                      size: 100,
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                            child: Icon(Icons.camera_alt_rounded,
                                size: 22, color: Colors.white)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text('Social Boost',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('FREE DELIVERY',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                                'Post about your order on Instagram → next delivery free.',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.85))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white60),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  // ⚠ REMOVED 10 September 2026 — _desktopBannersRow(), _desktopAddressChip()
  // and _desktopPromoBanner() used to live here (the "Social Boost" purple
  // promo strip + a "Set delivery address" chip that duplicated the hero's
  // own live DeliveryAddressField). See the removal note at this section's
  // old call site, in the desktop build() body above, and _socialBoostNavLink
  // (near _navLink) for where Social Boost now lives instead.

  // ── Section header ──────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Row(
          children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _navy)),
            const Spacer(),
            // Active filter count badge
            if (_selectedDietary.isNotEmpty || _socialBoostOnly)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    '${_selectedDietary.length + (_socialBoostOnly ? 1 : 0)} filter${(_selectedDietary.length + (_socialBoostOnly ? 1 : 0)) > 1 ? 's' : ''} active',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _primary,
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      );

  /// One shared empty/error state, so a failure and an empty result LOOK
  /// different and neither looks like a working list.
  Widget _listMessage({
    required IconData icon,
    required String title,
    required String body,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
        child: Column(
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      );

  // ── Restaurant list ─────────────────────────────────────────────────────────
  //
  // THIS USED TO SHOW FAKE RESTAURANTS WHEN THE QUERY FAILED. Audited 4 Aug
  // 2026. The old code was:
  //
  //     final restaurants = snapshot.hasData && snapshot.data!.docs.isNotEmpty
  //         ? snapshot.data!.docs.map(...).toList()
  //         : _placeholders;
  //
  // `snapshot.hasError` was never checked, so a permission-denied error was
  // indistinguishable from "still loading" — and both fell through to
  // `_placeholders`, three hardcoded restaurants that render as tappable and
  // orderable.
  //
  // That is exactly what was happening: /restaurants had NO security rule, so
  // Firestore refused every read, and this screen quietly showed Spice Garden,
  // Pizza Palace and Dragon Wok to everybody. A customer could open one and
  // try to order from a restaurant that does not exist. Nobody could see the
  // problem by looking at the app, which is why it survived.
  //
  // The three states are now distinct, and a failure says so.
  /// Grey blocks the size of the real cards.
  Widget _skeletons() {
    Widget box(double h, double w, [double r = 8]) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
            color: const Color(0xFFE4E8EE),
            borderRadius: BorderRadius.circular(r),
          ),
        );

    return Column(
      children: List<Widget>.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box(150, double.infinity, 16),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: box(15, 180),
              ),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: box(12, 120),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// The coloured band the search sits in.
  ///
  /// ⚠ WAS ORANGE, 0xFFEA580C to 0xFFF97316, changed 31 August 2026. It read
  /// as a different product sitting inside GoOuts rather than part of it, and
  /// at that saturation it fought everything below it. Now the house gradient,
  /// AppColors.primary to gradientEnd.
  ///
  /// The screen used to open on a white app bar over a grey background with
  /// the search field floating on it, which read as a settings page. Food is
  /// the one section where appetite matters.
  Widget _buildHeroBand({required Widget child}) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0392CA), Color(0xFF004C6B)],
          ),
        ),
        padding: const EdgeInsets.only(bottom: 22),
        child: child,
      );

  /// 10.0 -> "10%", 12.5 -> "12.5%". A trailing ".0" on a cashback rate
  /// reads like a system talking rather than an offer.
  static String _pct(double v) =>
      '${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1)}%';

  Widget _buildRestaurantList() => StreamBuilder<QuerySnapshot>(
        // ── ⚠ .limit() IS NOT OPTIONAL. Added 22 August 2026, reported as
        //    "food delivery takes too much time to load".
        //
        // This was an UNBOUNDED live listener. It downloaded every approved,
        // online restaurant on every open and kept a socket open for all of
        // them, and the filters below run in Dart AFTER the whole collection
        // has arrived. With a few dozen demo restaurants that is merely
        // wasteful; at a few hundred it is the load time.
        //
        // _listLimit is the one number that controls it. Raising it costs
        // every user on every open, so raise it only with a reason — the real
        // fix at scale is filtering in the query, and location, not a bigger
        // number here.
        stream: FirebaseFirestore.instance
            .collection('restaurants')
            .where('isOnline', isEqualTo: true)
            .where('isApproved', isEqualTo: true)
            .limit(_listLimit)
            .snapshots(),
        // ── ⚠ EVERY BRANCH HERE MUST RETURN A SLIVER ──────────────────────
        //
        // FIXED 15 August 2026, reported as "food delivery opens to a white
        // screen".
        //
        // This StreamBuilder sits directly inside CustomScrollView.slivers, so
        // whatever the builder returns becomes a child of a sliver parent. Three
        // of the five branches returned plain box widgets — _listMessage() is a
        // Padding, and the loading branch was a bare Padding too.
        //
        // Flutter throws "expected a child of type RenderSliver but received a
        // child of type RenderPadding", the whole CustomScrollView fails to lay
        // out, and the screen renders as blank white. In release there is no red
        // error box, so it looks like a screen that simply does nothing.
        //
        // The loading branch is the one that made it total: it runs FIRST on
        // every open, before Firestore replies, so the screen never rendered at
        // all. The success branch was correct, which is why this was never
        // caught by reading the code.
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // The REAL reason, not "check your connection".
            //
            // 18 August 2026: restaurants stopped appearing and this branch
            // blamed the network, which sent the search in the wrong
            // direction for an hour. A permission-denied and a flat aeroplane
            // mode are not the same fault and must not read the same.
            return SliverToBoxAdapter(
                child: _listMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load restaurants',
              body: '${snapshot.error}',
            ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Blocks in the shape of the cards, not a bare spinner. Still a
            // sliver — see the warning above; every branch here must be one.
            return SliverToBoxAdapter(child: _skeletons());
          }

          // ── PER DOCUMENT, NOT PER BATCH ──────────────────────────────
          //
          // Was `.map((d) => _RestaurantItem.fromDoc(d)).toList()`, which is
          // all-or-nothing: fromDoc throws on a field of the wrong TYPE (a
          // number where a String is expected, a Map where a List is), and
          // one bad restaurant anywhere in the collection threw inside this
          // builder — taking out the entire list, and with it the screen.
          //
          // Exactly the same shape as the Short Stay listing fault found the
          // same day. A restaurant we cannot read is one restaurant we cannot
          // show; it is not a reason to hide every other one.
          final restaurants = <_RestaurantItem>[];
          final skipped = <String>[];
          for (final d in (snapshot.data?.docs ?? const [])) {
            try {
              restaurants.add(_RestaurantItem.fromDoc(d));
            } catch (e) {
              skipped.add('${d.id}: $e');
            }
          }
          if (skipped.isNotEmpty) {
            debugPrint('food: dropped ${skipped.length} unreadable '
                'restaurant(s): ${skipped.join(" | ")}');
          }

          if (restaurants.isEmpty) {
            return SliverToBoxAdapter(
                child: _listMessage(
              icon: Icons.storefront_outlined,
              title: 'No restaurants available yet',
              body: 'We are adding partners in your area. Please check back '
                  'soon.',
            ));
          }

          // ── Apply filters ──────────────────────────────────────────────────
          var filtered = restaurants.where((r) {
            // Search
            if (_searchQuery.isNotEmpty &&
                !r.name.toLowerCase().contains(_searchQuery) &&
                !r.cuisineType.toLowerCase().contains(_searchQuery)) {
              return false;
            }
            // Cuisine
            if (_selectedCuisine != 'All' &&
                !r.cuisineType
                    .toLowerCase()
                    .contains(_selectedCuisine.toLowerCase())) {
              return false;
            }
            // Social Boost
            if (_socialBoostOnly && !r.socialBoostEnabled) return false;
            // Dietary tags — normalise both sides (strip hyphens, lowercase)
            for (final d in _selectedDietary) {
              final norm = d.toLowerCase().replaceAll('-', ' ');
              if (!r.tags.any((t) => t.toLowerCase().replaceAll('-', ' ') == norm)) {
                return false;
              }
            }
            return true;
          }).toList();

          // ── Sort ───────────────────────────────────────────────────────────
          switch (_sortBy) {
            case 'Top Rated':
              filtered.sort((a, b) => b.rating.compareTo(a.rating));
              break;
            case 'Fastest':
              filtered.sort((a, b) =>
                  a.deliveryMins.compareTo(b.deliveryMins));
              break;
            case 'Lowest Fee':
              filtered.sort(
                  (a, b) => a.deliveryFee.compareTo(b.deliveryFee));
              break;
            default:
              break; // Popular = Firestore order
          }

          if (filtered.isEmpty) {
            return SliverToBoxAdapter(child: _emptyState());
          }

          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _restaurantCard(filtered[i]),
              childCount: filtered.length,
            ),
          );
        },
      );

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 52, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No restaurants found',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600])),
            const SizedBox(height: 6),
            Text('Try a different cuisine or remove some filters.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[400])),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() {
                _selectedCuisine = 'All';
                _socialBoostOnly = false;
                _selectedDietary.clear();
              }),
              child: Text('Clear all filters',
                  style: GoogleFonts.inter(color: _primary)),
            ),
          ],
        ),
      );

  // ── Restaurant card ─────────────────────────────────────────────────────────
  /// [desktop] drops the mobile-list margin — see the desktop grid's own
  /// note on why a card built for that grid must not carry it.
  Widget _restaurantCard(_RestaurantItem r, {bool desktop = false}) =>
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/food-menu', arguments: {
          'restaurantId': r.id,
          'restaurantName': r.name,
          'cuisineType': r.cuisineType,
          'deliveryFee': r.deliveryFee,
          'deliveryMins': r.deliveryMins,
          'socialBoostEnabled': r.socialBoostEnabled,
          // Carried through so the menu can show the same rate the
          // card promised. Null when the partner has none.
          'cashbackPct': r.cashbackPct,
        }),
        child: Container(
          margin: desktop
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(16, 10, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover image ────────────────────────────────────────────────
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  children: [
                    r.coverImageUrl != null
                        ? Image.network(r.coverImageUrl!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // Decode to roughly card size, not to the size of
                            // whatever the partner uploaded. See
                            // _coverDecodeWidth.
                            cacheWidth: _coverDecodeWidth,
                            errorBuilder: (_, __, ___) => _coverPlaceholder(r))
                        : _coverPlaceholder(r),
                    // Gradient overlay at bottom
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top-left badges
                    Positioned(
                      top: 10, left: 10,
                      child: Wrap(
                        spacing: 5,
                        children: [
                          if (r.isBusy) _badge('Busy', Colors.orange),
                          if (r.socialBoostEnabled)
                            _badge('Social Boost', _purple, icon: Icons.bolt_rounded),
                          if (r.tags.contains('halal'))
                            _badge('Halal', const Color(0xFF10B981)),
                        ],
                      ),
                    ),
                    // ── CASHBACK, BOTTOM LEFT ──────────────────────────
                    //
                    // Hidden entirely when the partner has no rate. See the
                    // note on _RestaurantItem.cashbackPct — a card that
                    // invents a rate is a promise the checkout will break.
                    if (r.cashbackPct != null && r.cashbackPct! > 0)
                      Positioned(
                        bottom: 8, left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _navy,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.savings_outlined,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                '${_pct(r.cashbackPct!)} cashback',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Delivery fee — bottom right
                    Positioned(
                      bottom: 8, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: r.deliveryFee == 0
                              ? const Color(0xFF10B981)
                              : Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: r.deliveryFee == 0
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_shipping_rounded,
                                      size: 11, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text('Free delivery',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700)),
                                ],
                              )
                            : Text(
                                '£${r.deliveryFee.toStringAsFixed(2)} delivery',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Info row ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.name,
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _navy)),
                          const SizedBox(height: 2),
                          Text(r.cuisineType,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _infoChip(
                                  Icons.access_time_rounded,
                                  '${r.deliveryMins} min'),
                              const SizedBox(width: 10),
                              _infoChip(
                                  Icons.shopping_bag_outlined,
                                  'Min £${r.minOrder.toStringAsFixed(0)}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Rating
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 16,
                                color: Color(0xFFF59E0B)),
                            const SizedBox(width: 3),
                            Text(r.rating.toStringAsFixed(1),
                                style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _navy)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('(${r.reviewCount})',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[400])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _infoChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey[600])),
        ],
      );

  Widget _coverPlaceholder(_RestaurantItem r) => Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _primary.withValues(alpha: 0.08),
              _primary.withValues(alpha: 0.14),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ⚠ FIXED 10 September 2026 — was Text('🍽️', ...). Same
            // CanvasKit-has-no-colour-emoji-font bug fixed earlier for the
            // cuisine chips and Social Boost banner: on Flutter Web this
            // rendered as a blank box, not a plate icon. A restaurant with
            // no coverImageUrl falls back to THIS placeholder, so every
            // photo-less restaurant looked like its picture had failed to
            // load, when really the picture was never meant to be there —
            // this placeholder's own icon was invisible. Icon() is a vector
            // glyph, not a font-rendered emoji, so it paints correctly.
            Icon(Icons.restaurant_rounded,
                size: 40, color: _primary.withValues(alpha: 0.55)),
            const SizedBox(height: 6),
            Text(r.name,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _primary.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // ⚠ `icon` replaces an emoji prefix that used to be baked into `label`
  // (e.g. "⚡ Social Boost") — invisible on Flutter Web (CanvasKit has no
  // colour-emoji font). Same bug class as _coverPlaceholder/_dietaryChip.
  Widget _badge(String label, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10, color: Colors.white),
              const SizedBox(width: 3),
            ],
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  // ── Sort bottom sheet ───────────────────────────────────────────────────────
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      constraints: kIsWeb && MediaQuery.of(context).size.width >= 900
          ? const BoxConstraints(maxWidth: 560)
          : null,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Sort by',
                style: GoogleFonts.inter(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._sortOptions.map((opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    opt == 'Popular'
                        ? Icons.local_fire_department_rounded
                        : opt == 'Fastest'
                            ? Icons.flash_on_rounded
                            : opt == 'Top Rated'
                                ? Icons.star_rounded
                                : Icons.money_off_rounded,
                    color:
                        _sortBy == opt ? _primary : Colors.grey[500],
                    size: 22,
                  ),
                  title: Text(opt,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: _sortBy == opt
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: _sortBy == opt ? _primary : Colors.black87)),
                  trailing: _sortBy == opt
                      ? Icon(Icons.check_circle_rounded,
                          color: _primary, size: 20)
                      : null,
                  onTap: () {
                    setState(() => _sortBy = opt);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  // ── Placeholder data — DELETED 4 August 2026 ────────────────────────────────
  //
  // Eight hardcoded restaurants (Spice Garden, Pizza Palace, Dragon Wok and
  // five more) used to render whenever the Firestore query returned no data —
  // including when it FAILED. They were tappable and orderable.
  //
  // Deleted rather than kept behind a debug flag. A fake restaurant that can be
  // opened and ordered from is not a useful development aid, and leaving the
  // list here is an invitation to wire it back up the next time the real query
  // looks empty.
}

/// Icon-then-label nav item, one row, hover-aware. Same widget as
/// 01_short_stay_home_screen.dart's own _NavIconTab (deliberately not
/// shared — see that file's note on why this nav bar stays a separate
/// inline copy). Colours hardcoded to match this file's own _navy/_primary
/// since those are private State fields this top-level class can't reach.
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
  static const Color _primary = Color(0xFF0392CA);
  static const Color _navy = Color(0xFF0D1B3E);

  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final Color color =
        (widget.active || _hovering) ? _primary : _navy;
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

// ─────────────────────────────────────────────────────────────────────────────
//  Desktop hero — rotating headline
// ─────────────────────────────────────────────────────────────────────────────

/// Cycles the hero headline on a timer, fading/sliding between messages.
///
/// ADDED 10 September 2026, requested directly alongside the new "hungry
/// couple" hero photo: "a text animation ... day is over lets order food
/// from GoOuts & Get Cashback". A separate StatefulWidget rather than a
/// field on the screen's own State so its Timer has its own tidy
/// initState/dispose pair, independent of everything else the food screen
/// is doing.
class _HeroHeadline extends StatefulWidget {
  const _HeroHeadline();

  @override
  State<_HeroHeadline> createState() => _HeroHeadlineState();
}

class _HeroHeadlineState extends State<_HeroHeadline> {
  // ⚠ REWRITTEN 10 September 2026, requested directly: human tone, no
  // special characters, proper punctuation, happy mood. Dropped the em
  // dash and ampersand from the second line and rounded it out into a
  // full, warm sentence rather than a clipped tagline.
  static const List<String> _messages = <String>[
    'Order food near you',
    // Manual line break, requested directly — "Feeling hungry?" on its
    // own first line, the rest on the second.
    "Feeling hungry?\nLet's order food and earn cashback.",
    'Fresh from your favourite local spots',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 4.5s per message, minus the 500ms transition, reads as a deliberate
    // pace rather than a distraction — quick enough to notice, slow enough
    // to actually read the longer line.
    _timer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.18),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Align(
        key: ValueKey<int>(_index),
        alignment: Alignment.topLeft,
        child: Text(
          _messages[_index],
          maxLines: 2,
          style: GoogleFonts.inter(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.12,
            letterSpacing: -0.6,
            shadows: const <Shadow>[
              Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────────────────────────────

class _Cuisine {
  final IconData icon;
  final String label;
  const _Cuisine(this.icon, this.label);
}

class _RestaurantItem {
  final String id;
  final String name;
  final String cuisineType;
  final double rating;
  final int reviewCount;
  final int deliveryMins;
  final double deliveryFee;
  final double minOrder;
  final bool isBusy;
  final bool socialBoostEnabled;
  final List<String> tags; // halal, vegetarian, vegan, gluten-free
  final String? coverImageUrl;

  /// The partner's cashback rate, or null when they have none.
  ///
  /// ⚠ NULLABLE ON PURPOSE. A default here would put a rate on the card that
  /// nothing else in the system promised, and the checkout would disagree.
  final double? cashbackPct;

  const _RestaurantItem({
    required this.id,
    required this.name,
    required this.cuisineType,
    required this.rating,
    required this.reviewCount,
    required this.deliveryMins,
    required this.deliveryFee,
    required this.minOrder,
    required this.isBusy,
    required this.socialBoostEnabled,
    required this.tags,
    this.coverImageUrl,
    this.cashbackPct,
  });

  factory _RestaurantItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _RestaurantItem(
      id: doc.id,
      name: d['name'] ?? '',
      cuisineType: (d['cuisineTypes'] as List?)?.join(' · ') ?? '',
      rating: (d['averageRating'] ?? 4.5).toDouble(),
      reviewCount: d['reviewCount'] ?? 0,
      deliveryMins: d['estimatedDeliveryMins'] ?? 30,
      deliveryFee: (d['deliveryFee'] ?? 2.99).toDouble(),
      minOrder: (d['minimumOrderAmount'] ?? 10.0).toDouble(),
      isBusy: d['isBusy'] ?? false,
      socialBoostEnabled: d['socialBoostEnabled'] ?? false,
      // Read `dietaryTags` (new field); fall back to `tags` for legacy docs
      tags: List<String>.from(d['dietaryTags'] ?? d['tags'] ?? []),
      coverImageUrl: d['coverImageUrl'],
      cashbackPct: (d['cashbackPct'] as num?)?.toDouble(),
    );
  }
}
