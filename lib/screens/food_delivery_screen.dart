import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/delivery_address_service.dart';

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
  static const Color _primary  = Color(0xFFEA580C); // orange
  static const Color _navy     = Color(0xFF0D1B3E);
  static const Color _purple   = Color(0xFF7C3AED);
  static const Color _bg       = Color(0xFFF2F4F7);

  // ── Cuisine categories (Deliveroo + UberEats UK, with emoji icons) ──────────
  // Stored in Firestore `foodCuisines` collection in production.
  // Hardcoded here as fallback so screen works before Firestore is seeded.
  static const _cuisineList = [
    _Cuisine('🍽️', 'All'),
    _Cuisine('🍕', 'Pizza'),
    _Cuisine('🍛', 'Indian'),
    _Cuisine('🥡', 'Chinese'),
    _Cuisine('🍔', 'Burgers'),
    _Cuisine('🍣', 'Sushi'),
    _Cuisine('🌮', 'Mexican'),
    _Cuisine('🥙', 'Kebab'),
    _Cuisine('🍜', 'Thai'),
    _Cuisine('🍝', 'Italian'),
    _Cuisine('🍱', 'Japanese'),
    _Cuisine('🥗', 'Healthy'),
    _Cuisine('🫕', 'Lebanese'),
    _Cuisine('🍗', 'Chicken'),
    _Cuisine('🥐', 'Breakfast'),
    _Cuisine('🍟', 'American'),
    _Cuisine('🐟', 'Fish & Chips'),
    _Cuisine('🫙', 'Greek'),
    _Cuisine('🌯', 'Pakistani'),
    _Cuisine('🥘', 'Caribbean'),
    _Cuisine('🍲', 'Nigerian'),
    _Cuisine('🥩', 'Korean BBQ'),
    _Cuisine('🍩', 'Desserts'),
    _Cuisine('🛒', 'Groceries'),
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
  final _addrService  = DeliveryAddressService(); // singleton — safe as field
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
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          // Its chips are green and purple when selected. On the orange band
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

  // ── App bar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      // Orange, so the app bar and the search band below it read as one
      // header rather than a white strip on a coloured panel.
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
            onTap: () => Navigator.pushNamed(context, '/food-address-picker'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  addr != null
                      ? Icons.location_on_rounded
                      : Icons.location_searching_rounded,
                  color: _primary,
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
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500),
                      ),
                      if (addr != null)
                        Text(
                          addr.shortDisplay,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _navy),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[500], size: 18),
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
  Widget _buildSearchAndFilter() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                        decoration: InputDecoration(
                          hintText: 'Restaurants, dishes...',
                          hintStyle: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[400]),
                          border: InputBorder.none,
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
            const SizedBox(width: 10),
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
            const SizedBox(width: 10),
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
  Widget _buildCuisineRow() => SizedBox(
        height: 60,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          itemCount: _cuisineList.length,
          itemBuilder: (context, i) {
            final c = _cuisineList[i];
            final selected = c.label == _selectedCuisine;
            return GestureDetector(
              onTap: () => setState(() => _selectedCuisine = c.label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  // ⚠ INVERTED FOR THE ORANGE BAND. Selected used to be
                  // _primary — orange on orange, which made the chosen
                  // cuisine invisible the moment the header became coloured.
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
                    Text(c.emoji, style: const TextStyle(fontSize: 14)),
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
              label: '⚡ Social Boost',
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

  Widget _dietaryChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
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
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: selected ? color : Colors.grey[700],
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal)),
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
          onTap: () => Navigator.pushNamed(context, '/food-address-picker'),
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
                  color: Color(0xFFEA580C), size: 20),
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
                  color: Color(0xFFEA580C), size: 18),
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
                            child: Text('📸',
                                style: TextStyle(fontSize: 22))),
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

  /// The orange band the search sits in.
  ///
  /// The screen used to open on a white app bar over a grey background with
  /// the search field floating on it, which read as a settings page. Food is
  /// the one section where appetite matters.
  Widget _buildHeroBand({required Widget child}) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEA580C), Color(0xFFF97316)],
          ),
        ),
        padding: const EdgeInsets.only(bottom: 16),
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
            const Text('😕', style: TextStyle(fontSize: 52)),
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
  Widget _restaurantCard(_RestaurantItem r) => GestureDetector(
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
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                            _badge('⚡ Social Boost', _purple),
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
                        child: Text(
                          r.deliveryFee == 0
                              ? '🚚 Free delivery'
                              : '£${r.deliveryFee.toStringAsFixed(2)} delivery',
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
            Text('🍽️', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 6),
            Text(r.name,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _primary.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w700)),
      );

  // ── Sort bottom sheet ───────────────────────────────────────────────────────
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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

// ─────────────────────────────────────────────────────────────────────────────
//  Data models
// ─────────────────────────────────────────────────────────────────────────────

class _Cuisine {
  final String emoji;
  final String label;
  const _Cuisine(this.emoji, this.label);
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
