import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/cart_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FoodMenuScreen  —  restaurant menu browsing (Task #72)
//  Route: /food-menu
//  Args: restaurantId, restaurantName, cuisineType, deliveryFee,
//        deliveryMins, socialBoostEnabled
// ─────────────────────────────────────────────────────────────────────────────
class FoodMenuScreen extends StatefulWidget {
  const FoodMenuScreen({super.key});

  @override
  State<FoodMenuScreen> createState() => _FoodMenuScreenState();
}

class _FoodMenuScreenState extends State<FoodMenuScreen> {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFFEA580C);  // orange
  static const Color _navy     = Color(0xFF0D1B3E);
  static const Color _green    = Color(0xFF10B981);
  static const Color _bg       = Color(0xFFF2F4F7);

  // ── Args ───────────────────────────────────────────────────────────────────
  late String _restaurantId;
  late String _restaurantName;
  double? _cashbackPct;
  late String _cuisineType;
  late double _deliveryFee;
  late int    _deliveryMins;
  late bool   _socialBoost;

  // ── State ──────────────────────────────────────────────────────────────────
  final _db   = FirebaseFirestore.instance;
  final _cart = CartService.instance;

  List<_MenuCategory> _categories   = [];
  List<_MenuItem>     _popularItems  = [];
  bool _loading = true;

  // Category tab scroll
  int _activeCatIndex = 0;
  final _tabScrollCtrl = ScrollController();

  // Items scroll — used to detect which category section is visible
  final _itemsScrollCtrl = ScrollController();

  // GlobalKeys for each category section so we can scroll to them
  final List<GlobalKey> _sectionKeys = [];

  bool _argsInitialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsInitialised) return;
    _argsInitialised = true;

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
    _restaurantId   = (args['restaurantId']       ?? '') as String;
    _restaurantName = (args['restaurantName']      ?? 'Restaurant') as String;
    _cuisineType    = (args['cuisineType']         ?? '') as String;
    _deliveryFee    = (args['deliveryFee']  as num?)?.toDouble() ?? 0;
    _deliveryMins   = (args['deliveryMins'] as num?)?.toInt()    ?? 30;
    _socialBoost    = (args['socialBoostEnabled']  ?? false) as bool;
    // ⚠ NULLABLE. Absent when the partner has no rate — the strip below is
    // hidden rather than defaulted. A menu that promises a rate the card did
    // not is how a customer ends up disputing their cashback.
    _cashbackPct    = (args['cashbackPct'] as num?)?.toDouble();

    // Register with CartService (clear if different restaurant)
    final ok = _cart.setRestaurant(
      restaurantId:   _restaurantId,
      restaurantName: _restaurantName,
      deliveryFee:    _deliveryFee,
      deliveryMins:   _deliveryMins,
    );
    if (!ok) {
      // Different restaurant — ask user
      WidgetsBinding.instance.addPostFrameCallback((_) => _showClearCartDialog());
    }

    _loadMenu();
  }

  @override
  void dispose() {
    _tabScrollCtrl.dispose();
    _itemsScrollCtrl.dispose();
    super.dispose();
  }

  // ── Load menu ──────────────────────────────────────────────────────────────
  Future<void> _loadMenu() async {
    setState(() => _loading = true);
    try {
      // Load categories
      final catSnap = await _db
          .collection('merchants')
          .doc(_restaurantId)
          .collection('menu_categories')
          .where('isAvailable', isEqualTo: true)
          .orderBy('position')
          .get();

      final cats = <_MenuCategory>[];
      for (final catDoc in catSnap.docs) {
        final catData = catDoc.data();
        // Load items for this category
        final itemSnap = await _db
            .collection('merchants')
            .doc(_restaurantId)
            .collection('menu_items')
            .where('categoryId', isEqualTo: catDoc.id)
            .where('isAvailable', isEqualTo: true)
            .orderBy('position')
            .get();

        final items = itemSnap.docs.map((d) {
          final d2 = d.data();
          return _MenuItem(
            id:            d.id,
            name:          (d2['name']          ?? '') as String,
            description:   (d2['description']   ?? '') as String,
            price:         (d2['price'] as num?)?.toDouble() ?? 0,
            imageUrl:      (d2['imageUrl']       ?? '') as String,
            categoryId:    catDoc.id,
            isPopular:     (d2['isPopular']      ?? false) as bool,
            isRecommended: (d2['isRecommended']  ?? false) as bool,
            orderCount:    (d2['orderCount'] as num?)?.toInt() ?? 0,
            // VAT fields — set by admin in Menu VAT Moderation panel
            vatApplicable: (d2['vatApplicable']  ?? false) as bool,
            vatRate:       (d2['vatRate'] as num?)?.toDouble() ?? 0.0,
          );
        }).toList();

        if (items.isNotEmpty) {
          cats.add(_MenuCategory(
            id:   catDoc.id,
            name: (catData['name'] ?? 'Menu') as String,
            items: items,
          ));
        }
      }

      // Collect popular/recommended items (deduplicated, sorted by orderCount)
      final popular = cats
          .expand<_MenuItem>((c) => c.items)
          .where((i) => i.isPopular || i.isRecommended)
          .fold<Map<String, _MenuItem>>({}, (map, i) { map[i.id] = i; return map; })
          .values
          .toList()
        ..sort((a, b) => b.orderCount.compareTo(a.orderCount));

      // If no flagged items, fall back to top 6 by orderCount
      final topPicks = popular.isNotEmpty
          ? popular.take(8).toList()
          : (cats.expand<_MenuItem>((c) => c.items).toList()
              ..sort((a, b) => b.orderCount.compareTo(a.orderCount)))
              .take(6)
              .toList();

      // If no Firestore menu yet, show empty state
      if (mounted) {
        setState(() {
          _categories   = cats;
          _popularItems = topPicks;
          _sectionKeys
            ..clear()
            ..addAll(List.generate(cats.length, (_) => GlobalKey()));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _categories = []; _loading = false; });
    }
  }

  // ── Scroll to category section ─────────────────────────────────────────────
  void _scrollToCategory(int index) {
    setState(() => _activeCatIndex = index);
    // Scroll category tab into view — guard if controller not yet attached
    try {
      if (_tabScrollCtrl.hasClients) {
        _tabScrollCtrl.animateTo(
          (index * 100.0).clamp(0.0, _tabScrollCtrl.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {}
    // Scroll to section
    if (index < _sectionKeys.length) {
      final key = _sectionKeys[index];
      if (key.currentContext != null) {
        Scrollable.ensureVisible(key.currentContext!,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            alignment: 0.0);
      }
    }
  }

  // ── Cart ────────────────────────────────────────────────────────────────────
  void _addItem(_MenuItem item) {
    _cart.addItem(CartItem(
      itemId:        item.id,
      name:          item.name,
      price:         item.price,
      imageUrl:      item.imageUrl,
      categoryId:    item.categoryId,
      vatApplicable: item.vatApplicable,
      vatRate:       item.vatRate,
    ));
  }

  void _removeItem(_MenuItem item) => _cart.removeOne(item.id);

  void _showClearCartDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Start new order?',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
        content: Text(
          'You have items from "${_cart.restaurantName}" in your cart. '
          'Starting a new order will clear your current cart.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Cart', style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Start Fresh', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _cart.clear();
      _cart.setRestaurant(
        restaurantId:   _restaurantId,
        restaurantName: _restaurantName,
        deliveryFee:    _deliveryFee,
        deliveryMins:   _deliveryMins,
      );
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? _buildSkeleton()
          : Stack(
              children: [
                CustomScrollView(
                  controller: _itemsScrollCtrl,
                  slivers: [
                    // ── Restaurant header ────────────────────────────────────
                    _buildSliverHeader(),
                    // ── CASHBACK STRIP ────────────────────────────────────────
                    //
                    // Added 22 August 2026. This screen mentioned cashback
                    // nowhere at all — a GoOuts menu that reads exactly like
                    // any other delivery app's menu. The rate is carried in
                    // from the restaurant card so the two cannot disagree.
                    if (_cashbackPct != null && _cashbackPct! > 0)
                      SliverToBoxAdapter(child: _buildCashbackStrip()),
                    // ── Popular Picks / AI upsell ─────────────────────────────
                    if (_popularItems.isNotEmpty)
                      SliverToBoxAdapter(child: _buildPopularPicksSection()),
                    // ── Category tabs (sticky) ───────────────────────────────
                    if (_categories.isNotEmpty)
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _CategoryTabsDelegate(
                          categories:     _categories,
                          activeIndex:    _activeCatIndex,
                          scrollCtrl:     _tabScrollCtrl,
                          onTap:          _scrollToCategory,
                          primaryColor:   _primary,
                        ),
                      ),
                    // ── Menu sections ────────────────────────────────────────
                    if (_categories.isEmpty)
                      SliverFillRemaining(child: _buildEmptyMenu())
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildCategorySection(i),
                          childCount: _categories.length,
                        ),
                      ),
                    // Extra bottom padding so cart bar doesn't cover last item
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),

                // ── Floating cart bar ────────────────────────────────────────
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _CartBar(cart: _cart, primary: _primary),
                ),
              ],
            ),
    );
  }

  // ── Sliver header ──────────────────────────────────────────────────────────
  /// States the rate once, near the top, and says when it arrives.
  ///
  /// ⚠ ONLY RENDERED WHEN _cashbackPct IS NON NULL. See didChangeDependencies.
  Widget _buildCashbackStrip() {
    final double pct = _cashbackPct!;
    final String label = pct == pct.roundToDouble()
        ? pct.toStringAsFixed(0)
        : pct.toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.savings_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label% cashback on this order',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // Says WHEN, not just that. "You will get cashback" with no
                  // timing is the sentence customers dispute later.
                  'Added to your GoOuts wallet after the order is delivered.',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: _navy,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
          ),
          onPressed: () => _showItemSearch(),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Cover gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0D1B3E)],
                ),
              ),
            ),
            // Emoji / cuisine icon
            Center(
              child: Text(_cuisineEmoji(_cuisineType),
                  style: const TextStyle(fontSize: 64)),
            ),
            // Bottom gradient + info
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC0D1B3E)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_socialBoost)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('⚡ Social Boost',
                            style: GoogleFonts.inter(
                                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    Text(_restaurantName,
                        style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _infoChip(Icons.schedule_rounded,
                          '$_deliveryMins min', Colors.white70),
                      const SizedBox(width: 10),
                      _infoChip(Icons.delivery_dining_rounded,
                          _deliveryFee == 0 ? 'Free delivery' : '£${_deliveryFee.toStringAsFixed(2)} delivery',
                          _deliveryFee == 0 ? _green : Colors.white70),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ],
  );

  // ── Category section ───────────────────────────────────────────────────────
  Widget _buildCategorySection(int catIndex) {
    final cat = _categories[catIndex];
    return Column(
      key: _sectionKeys[catIndex],
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          color: _bg,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Text(cat.name,
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
        ),
        // Items
        ...cat.items.map((item) => _buildItemTile(item)),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Popular Picks (AI upsell) ─────────────────────────────────────────────
  Widget _buildPopularPicksSection() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Popular Picks',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: _navy)),
                Text('Customers love these',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.grey[500])),
              ]),
            ]),
          ),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: _popularItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _buildPopularCard(_popularItems[i]),
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildPopularCard(_MenuItem item) {
    final qty = _cart.quantityOf(item.id);
    return GestureDetector(
      onTap: () => _addItem(item),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: item.imageUrl.isEmpty
                  ? Container(
                      height: 100,
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                          child: Icon(Icons.fastfood_rounded,
                              size: 32, color: Color(0xFFD1D5DB))))
                  : Image.network(
                      item.imageUrl,
                      height: 100, width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                              child: Icon(Icons.fastfood_rounded,
                                  size: 32, color: Color(0xFFD1D5DB)))),
                    ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge
                    if (item.isRecommended)
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('Chef\'s Pick',
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _primary)),
                      ),
                    Text(item.name,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _navy),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '£${item.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _primary),
                        ),
                        qty == 0
                            ? GestureDetector(
                                onTap: () => _addItem(item),
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                      color: _primary,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.add_rounded,
                                      size: 18, color: Colors.white),
                                ),
                              )
                            : GestureDetector(
                                onTap: () => _removeItem(item),
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                      color: _primary.withValues(alpha: 0.12),
                                      shape: BoxShape.circle),
                                  child: Center(
                                    child: Text('$qty',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _primary)),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Item tile ──────────────────────────────────────────────────────────────
  Widget _buildItemTile(_MenuItem item) {
    return ListenableBuilder(
      listenable: _cart,
      builder: (ctx, _) {
        final qty = _cart.quantityOf(item.id);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.description,
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 8),
                      Text('£${item.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w800, color: _primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Image + add button
                Column(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 90, height: 80,
                        child: item.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey[100]),
                                errorWidget: (_, __, ___) => _noImage(),
                              )
                            : _noImage(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quantity stepper
                    qty == 0
                        ? _addButton(item)
                        : _stepperWidget(item, qty),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _addButton(_MenuItem item) => GestureDetector(
    onTap: () => _addItem(item),
    child: Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text('+ Add',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    ),
  );

  Widget _stepperWidget(_MenuItem item, int qty) => Container(
    width: 90,
    decoration: BoxDecoration(
      color: _primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _primary.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _stepBtn(Icons.remove_rounded, () => _removeItem(item)),
        Text('$qty',
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w800, color: _primary)),
        _stepBtn(Icons.add_rounded, () => _addItem(item)),
      ],
    ),
  );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Icon(icon, size: 16, color: _primary),
    ),
  );

  Widget _noImage() => Container(
    color: Colors.grey[100],
    child: Center(child: Icon(Icons.fastfood_outlined, size: 28, color: Colors.grey[300])),
  );

  // ── Empty menu ──────────────────────────────────────────────────────────────
  Widget _buildEmptyMenu() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🍽️', style: const TextStyle(fontSize: 60)),
        const SizedBox(height: 16),
        Text('Menu coming soon',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        Text('This restaurant hasn\'t added their menu yet.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
      ],
    ),
  );

  // ── Loading skeleton ────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: _navy,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0D1B3E)],
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _skeletonTile(),
            childCount: 6,
          ),
        ),
      ],
    );
  }

  Widget _skeletonTile() => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    height: 110,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmer(140, 14),
              const SizedBox(height: 8),
              _shimmer(200, 12),
              const SizedBox(height: 6),
              _shimmer(100, 12),
            ],
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.all(12),
        width: 90, height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
      ),
    ]),
  );

  Widget _shimmer(double w, double h) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
  );

  // ── Item search ─────────────────────────────────────────────────────────────
  void _showItemSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemSearchSheet(
        categories: _categories,
        onAdd:    _addItem,
        onRemove: _removeItem,
        cart:     _cart,
        primary:  _primary,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  String _cuisineEmoji(String type) {
    const map = {
      'pizza': '🍕', 'indian': '🍛', 'chinese': '🥡', 'burgers': '🍔',
      'sushi': '🍣', 'mexican': '🌮', 'kebab': '🥙', 'thai': '🍜',
      'italian': '🍝', 'japanese': '🍱', 'healthy': '🥗', 'lebanese': '🫕',
      'chicken': '🍗', 'breakfast': '🥐', 'american': '🍟',
      'fish & chips': '🐟', 'greek': '🫙', 'pakistani': '🌯',
      'caribbean': '🥘', 'nigerian': '🍲', 'korean bbq': '🥩',
      'desserts': '🍩', 'groceries': '🛒',
    };
    return map[type.toLowerCase()] ?? '🍽️';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Category tabs — SliverPersistentHeader delegate
// ═══════════════════════════════════════════════════════════════════════════
class _CategoryTabsDelegate extends SliverPersistentHeaderDelegate {
  final List<_MenuCategory> categories;
  final int activeIndex;
  final ScrollController scrollCtrl;
  final void Function(int) onTap;
  final Color primaryColor;

  const _CategoryTabsDelegate({
    required this.categories,
    required this.activeIndex,
    required this.scrollCtrl,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  double get minExtent => 50;
  @override
  double get maxExtent => 50;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 50,
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: List.generate(categories.length, (i) {
            final active = i == activeIndex;
            return GestureDetector(
              onTap: () => onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? primaryColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  categories[i].name,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_CategoryTabsDelegate old) =>
      old.activeIndex != activeIndex || old.categories.length != categories.length;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Floating cart bar
// ═══════════════════════════════════════════════════════════════════════════
class _CartBar extends StatelessWidget {
  final CartService cart;
  final Color primary;

  const _CartBar({required this.cart, required this.primary});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cart,
      builder: (ctx, _) {
        if (cart.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.all(12),
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/food-cart'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 6,
              shadowColor: primary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            child: Row(children: [
              // Item count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${cart.totalItems}',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('View Cart',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              Text('£${cart.total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Item search bottom sheet
// ═══════════════════════════════════════════════════════════════════════════
class _ItemSearchSheet extends StatefulWidget {
  final List<_MenuCategory> categories;
  final void Function(_MenuItem) onAdd;
  final void Function(_MenuItem) onRemove;
  final CartService cart;
  final Color primary;

  const _ItemSearchSheet({
    required this.categories,
    required this.onAdd,
    required this.onRemove,
    required this.cart,
    required this.primary,
  });

  @override
  State<_ItemSearchSheet> createState() => _ItemSearchSheetState();
}

class _ItemSearchSheetState extends State<_ItemSearchSheet> {
  final _ctrl   = TextEditingController();
  String _query = '';

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  List<_MenuItem> get _results {
    final q = _query.toLowerCase();
    if (q.isEmpty) return widget.categories.expand<_MenuItem>((c) => c.items).toList();
    return widget.categories
        .expand<_MenuItem>((c) => c.items)
        .where((i) =>
            i.name.toLowerCase().contains(q) ||
            i.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search menu...',
              hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const Divider(height: 1),
        // Results
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text('No items found',
                      style: GoogleFonts.inter(color: Colors.grey[400])))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: results.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 20),
                  itemBuilder: (_, i) {
                    final item = results[i];
                    final qty  = widget.cart.quantityOf(item.id);
                    return ListTile(
                      leading: item.imageUrl.isEmpty
                          ? Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.fastfood_rounded,
                                  color: Color(0xFFD1D5DB)))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(item.imageUrl,
                                  width: 48, height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      width: 48, height: 48,
                                      color: const Color(0xFFF3F4F6),
                                      child: const Icon(Icons.fastfood_rounded,
                                          color: Color(0xFFD1D5DB))))),
                      title: Text(item.name,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                          '£${item.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.primary)),
                      trailing: qty == 0
                          ? GestureDetector(
                              onTap: () => widget.onAdd(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                    color: widget.primary,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text('Add',
                                    style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            )
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              _iconBtn(Icons.remove,
                                  () => widget.onRemove(item)),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Text('$qty',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                              _iconBtn(Icons.add, () => widget.onAdd(item)),
                            ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: widget.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: widget.primary),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  Data models
// ═══════════════════════════════════════════════════════════════════════════
class _MenuCategory {
  final String id;
  final String name;
  final List<_MenuItem> items;
  const _MenuCategory({required this.id, required this.name, required this.items});
}

class _MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String categoryId;
  final bool   isPopular;
  final bool   isRecommended;
  final int    orderCount;
  // ── VAT fields (set by admin via Menu VAT Moderation) ──────────────────────
  final bool   vatApplicable;  // true = item is VAT chargeable
  final double vatRate;        // 0.0, 5.0, or 20.0

  const _MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.isPopular      = false,
    this.isRecommended  = false,
    this.orderCount     = 0,
    this.vatApplicable  = false,
    this.vatRate        = 0.0,
  });

  /// VAT amount on this item at given quantity (VAT-inclusive extraction)
  double vatAmount({int qty = 1}) {
    if (!vatApplicable || vatRate == 0) return 0.0;
    final lineTotal = price * qty;
    return double.parse((lineTotal - (lineTotal / (1 + vatRate / 100))).toStringAsFixed(2));
  }
}
