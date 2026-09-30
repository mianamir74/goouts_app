import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/food_complaint_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DeliveryConfirmationScreen
//
//  Route: /food-delivery-confirmation
//  Args:  orderId (String, required), order (Map<String,dynamic>, required —
//         the order document already held by the tracking screen at the
//         moment status becomes delivered; passed through rather than
//         re-read, since it was just streamed a moment ago)
//
//  ── ⚠ NOT A REPLACEMENT SCREEN, AN ADDITIVE ONE ──────────────────────────
//
//  The rating and tip on this screen call the exact same rateFoodDelivery
//  callable the bottom sheet on the tracking screen already called, with the
//  same one-transaction guarantee (rating and tip land together or not at
//  all — see food_orders.js). Nothing about the money path changes here.
//  The one addition is the item checklist above it, which the bottom sheet
//  never had.
//
//  ── ⚠ NO "CASHBACK CREDITED" LINE, DELIBERATELY ──────────────────────────
//
//  Stitch's reference design showed "GBP 1.48 has been added to your GoOuts
//  wallet" as a statement of fact. Checked before wiring this: nothing in
//  the backend ever writes cashbackEarned onto a food order, and no trigger
//  fires when status reaches delivered. That line would have told the
//  customer money moved when none did. Left out until a real crediting
//  mechanism exists — a false balance is worse than no cashback line at all.
//
//  ── ⚠ "REPORT MISSING ITEMS" ROUTES TO SUPPORT, IT DOES NOT REFUND ───────
//
//  Unticking an item opens /contact-support with the order id, the same
//  route the tracking screen's own help button already uses. There is no
//  confirmFoodOrderItems callable and this screen does not invent one —
//  that was an explicit scope decision, not an oversight.
// ─────────────────────────────────────────────────────────────────────────────

class DeliveryConfirmationScreen extends StatefulWidget {
  const DeliveryConfirmationScreen({super.key});

  @override
  State<DeliveryConfirmationScreen> createState() =>
      _DeliveryConfirmationScreenState();
}

class _DeliveryConfirmationScreenState
    extends State<DeliveryConfirmationScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _navy = Color(0xFF0D1B3E);
  static const Color _teal = Color(0xFF0A6E8A);
  static const Color _bg = Color(0xFFF2F4F7);
  static const Color _paleTint = Color(0xFFE0F3FB);
  static const Color _body = Color(0xFF475569);
  static const Color _error = Color(0xFFEF4444);
  static const Color _outlineVariant = Color(0xFFBEC8D0);

  late String _orderId;
  late Map<String, dynamic> _order;
  bool _argsInit = false;

  // Item checklist — every item starts confirmed. The customer only has to
  // act on what is wrong, not confirm everything that arrived correctly.
  late List<_ChecklistItem> _items;

  int _rating = 0;
  static const List<String> _ratingLabels = [
    'Poor', 'Fair', 'Satisfactory', 'Very Good', 'Excellent'
  ];

  static const List<Map<String, Object>> _tipOptions = [
    {'label': 'No tip', 'amount': 0.0},
    {'label': '£1.00', 'amount': 1.0},
    {'label': '£2.00', 'amount': 2.0},
    {'label': '£3.00', 'amount': 3.0},
  ];
  double? _selectedTip = 0.0;
  bool _customTipChosen = false;
  final TextEditingController _customTipController = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsInit) return;
    _argsInit = true;
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>? ?? {};
    _orderId = (args['orderId'] as String?) ?? '';
    _order = (args['order'] as Map<String, dynamic>?) ?? {};

    final rawItems = (_order['items'] as List?) ?? const [];
    _items = rawItems.map((raw) {
      final m = (raw as Map?)?.cast<String, dynamic>() ?? {};
      final qty = (m['quantity'] as num?)?.toInt() ?? 1;
      return _ChecklistItem(
        name: '${qty}x ${m['name'] ?? 'Item'}',
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  @override
  void dispose() {
    _customTipController.dispose();
    super.dispose();
  }

  int get _confirmedCount => _items.where((i) => i.confirmed).length;
  bool get _allConfirmed =>
      _items.isEmpty || _confirmedCount == _items.length;

  double get _resolvedTip {
    if (_customTipChosen) {
      return double.tryParse(_customTipController.text) ?? 0.0;
    }
    return _selectedTip ?? 0.0;
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a star rating first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      // ⚠ SAME CALLABLE, SAME SHAPE the tracking screen's rating sheet has
      // always used. One transaction: rating and tip land together or not
      // at all. See rateFoodDelivery in food_orders.js.
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('rateFoodDelivery')
          .call<Map<String, dynamic>>({
        'orderId': _orderId,
        'stars': _rating,
        'tip': _resolvedTip,
      });
      if (mounted) setState(() => _submitted = true);

      // ⚠ WIRED 4 September 2026. This trigger, and the sheet itself, always
      // existed — food_order_tracking_screen.dart's old rating bottom sheet
      // had both. This screen replaced that bottom sheet without carrying
      // the complaint trigger over, so a low rating here went nowhere. Same
      // threshold (3 stars or under) as the original. See
      // widgets/food_complaint_sheet.dart for the sheet itself, now shared
      // rather than duplicated.
      if (mounted && _rating <= 3) {
        final restaurantId = (_order['restaurantId'] as String?) ?? '';
        final restaurantName =
            (_order['restaurantName'] as String?) ?? 'the restaurant';
        final driverId = _order['driverId'] as String?;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            showFoodComplaintSheet(
              context: context,
              orderId: _orderId,
              restaurantId: restaurantId,
              restaurantName: restaurantName,
              driverId: driverId,
              stars: _rating,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send your rating. Please try again.')),
        );
      }
    }
  }

  void _reportMissing() {
    Navigator.pushNamed(context, '/contact-support', arguments: {'orderId': _orderId});
  }

  void _goToRestaurants() {
    Navigator.pushNamedAndRemoveUntil(context, '/food-delivery', (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final restaurantName = (_order['restaurantName'] as String?) ?? 'the restaurant';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: _navy,
        automaticallyImplyLeading: false,
        title: Text('Delivery Confirmation',
            style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: _navy)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool desktop = kIsWeb && constraints.maxWidth >= 900;
          final Widget content = SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: _teal, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('Delivered',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _teal)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Your order has arrived',
                style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 4),
            Text('Please confirm everything arrived from $restaurantName',
                style: GoogleFonts.inter(fontSize: 14, color: _body)),
            const SizedBox(height: 20),
            if (_items.isNotEmpty) ...[
              _buildChecklist(),
              const SizedBox(height: 12),
              _buildActionButton(),
              const SizedBox(height: 20),
            ],
            _buildRatingAndTip(),
          ],
        ),
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
      // ⚠ NO BOTTOM NAV. Checkout and tracking deliberately have none —
      // a mid-flow screen should not let a tap send the customer sideways
      // with an unsubmitted rating sitting behind them. This screen is
      // pushed the same way and follows the same rule. "Back to
      // restaurants" above, once submitted, is the deliberate exit.
    );
  }

  Widget _buildChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Delivered items',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
            Text('$_confirmedCount of ${_items.length} confirmed',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _teal)),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => item.confirmed = !item.confirmed),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0D0D1B3E), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: item.confirmed ? _primary : _bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        item.confirmed ? Icons.check : Icons.close,
                        size: 16,
                        color: item.confirmed ? Colors.white : _body,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item.name,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: _navy),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (item.price > 0)
                      Text('£${item.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton() {
    final int missing = _items.length - _confirmedCount;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _allConfirmed ? null : _reportMissing,
            style: ElevatedButton.styleFrom(
              backgroundColor: _allConfirmed ? _bg : _error,
              foregroundColor: _allConfirmed ? _outlineVariant : Colors.white,
              disabledBackgroundColor: _bg,
              disabledForegroundColor: _outlineVariant,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(_allConfirmed ? Icons.task_alt : Icons.warning_amber_rounded, size: 20),
            label: Text(
              _allConfirmed ? 'All correct' : 'Report $missing missing item${missing > 1 ? 's' : ''}',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _allConfirmed
              ? 'Tap any item above to flag it as missing'
              : 'This opens support with your order attached',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12, color: _body),
        ),
      ],
    );
  }

  Widget _buildRatingAndTip() {
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x0D0D1B3E), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          children: [
            const Icon(Icons.celebration_rounded, color: _primary, size: 36),
            const SizedBox(height: 10),
            Text('Thanks for your feedback',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _navy)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _goToRestaurants,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  side: const BorderSide(color: _primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Back to restaurants',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0D0D1B3E), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text('Rate delivery experience',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final int starValue = i + 1;
              final bool filled = starValue <= _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = starValue),
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  size: 30,
                  color: filled ? _primary : _outlineVariant,
                ),
              );
            }),
          ),
          Text(
            _rating == 0 ? 'Tap to rate' : '${_ratingLabels[_rating - 1]} ($_rating of 5)',
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _body),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Add a tip for the driver',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Entirely optional. Goes straight to your driver.',
                style: GoogleFonts.inter(fontSize: 12, color: _body)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final opt in _tipOptions) ...[
                Expanded(child: _tipChip(opt['label'] as String, opt['amount'] as double)),
                const SizedBox(width: 8),
              ],
              Expanded(child: _tipChip('Custom', null)),
            ],
          ),
          if (_customTipChosen) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customTipController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '£',
                hintText: '0.00',
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Submit & done',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipChip(String label, double? amount) {
    final bool selected = amount == null ? _customTipChosen : (_selectedTip == amount && !_customTipChosen);
    return SizedBox(
      height: 38,
      child: TextButton(
        onPressed: () => setState(() {
          if (amount == null) {
            _customTipChosen = true;
            _selectedTip = null;
          } else {
            _customTipChosen = false;
            _selectedTip = amount;
          }
        }),
        style: TextButton.styleFrom(
          backgroundColor: selected ? _paleTint : _bg,
          foregroundColor: selected ? _teal : _body,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: EdgeInsets.zero,
        ),
        child: Text(label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
      ),
    );
  }
}

class _ChecklistItem {
  _ChecklistItem({required this.name, required this.price});
  final String name;
  final double price;
  // Every item starts confirmed — see the checklist note near the top of
  // the file. Not a constructor param: nothing ever needs to start one
  // unticked, and an unused optional param is exactly what triggered this
  // lint in the first place.
  bool confirmed = true;
}
