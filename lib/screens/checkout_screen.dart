import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cart_service.dart';
import '../services/delivery_address_service.dart';
import 'food_order_tracking_screen.dart';
import '../widgets/goouts_sheet.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _primary  = Color(0xFFEA580C); // orange
  static const Color _navy     = Color(0xFF0D1B3E);
  static const Color _green    = Color(0xFF10B981);
  static const Color _blue     = Color(0xFF0392CA);
  static const Color _purple   = Color(0xFF7C3AED);
  static const Color _bg       = Color(0xFFF2F4F7);
  static const Color _border   = Color(0xFFE2E8F0);

  // ── Services ───────────────────────────────────────────────────────────────
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _cart = CartService.instance;
  final _addressService = DeliveryAddressService();

  // ── State ──────────────────────────────────────────────────────────────────
  bool   _loading         = true;
  bool   _placing         = false;
  String _deliveryAddress = '';
  String _selectedPayment = 'card'; // card | wallet | apple | google

  // Social Boost
  String? _boostCodeId;
  bool    _boostApplied  = false;
  bool    _boostChecked  = false;

  // Promo / notes
  final _noteCtrl = TextEditingController();

  // Effective delivery fee (may be zeroed by boost)
  double _effectiveDeliveryFee = 0;

  @override
  void initState() {
    super.initState();
    _effectiveDeliveryFee = _cart.deliveryFee;
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Load address + check social boost code ─────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Ensure address service is initialised, then read current address
      await _addressService.init();
      if (mounted) {
        setState(() =>
            _deliveryAddress = _addressService.current?.fullDisplay ?? '');
      }
      // Check for Social Boost free delivery code
      await _checkSocialBoostCode();
    } catch (e) {
      debugPrint('Checkout _load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkSocialBoostCode() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _cart.restaurantId == null) return;

    try {
      // Query user's social boost codes for this restaurant, unused, not expired
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('socialBoostCodes')
          .where('restaurantId', isEqualTo: _cart.restaurantId)
          .where('used', isEqualTo: false)
          .where('type', isEqualTo: 'freeDelivery')
          .orderBy('expiresAt', descending: false)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;

      final doc = snap.docs.first;
      final expiresAt = (doc.data()['expiresAt'] as Timestamp?)?.toDate();
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) return;

      // Valid code found — show popup
      if (mounted) {
        setState(() => _boostCodeId = doc.id);
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) _showBoostPopup();
      }
    } catch (_) {}
  }

  // ── Social Boost popup ─────────────────────────────────────────────────────
  void _showBoostPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Boost icon
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEA580C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 20),

              Text('You Have a Free Delivery!',
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _navy),
                textAlign: TextAlign.center),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEA580C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('SOCIAL BOOST REWARD',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ]),
              ),
              const SizedBox(height: 16),

              Text(
                'You earned a free delivery by sharing your visit on social media. '
                'Apply it now to save £${_cart.deliveryFee.toStringAsFixed(2)} on this order.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: Colors.grey[700], height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _boostApplied        = true;
                      _boostChecked        = true;
                      _effectiveDeliveryFee = 0;
                    });
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: Text('Apply Free Delivery',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Skip button
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _boostChecked = true);
                },
                child: Text('Skip, pay delivery fee',
                  style: GoogleFonts.inter(
                      color: Colors.grey[500], fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Place order ────────────────────────────────────────────────────────────
  Future<void> _placeOrder() async {
    if (_placing) return;
    if (_deliveryAddress.isEmpty) {
      _showSnack('Please add a delivery address first.', error: true);
      return;
    }

    setState(() => _placing = true);

    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in');

      final orderRef = _db.collection('food_orders').doc();

      // VAT-inclusive extraction from cart items (food VAT)
      final foodVatTotal = _cart.foodVatTotal;

      // GoOuts own VAT: service fee (10% of subtotal) + delivery fee at 20% each
      // This mirrors the Cloud Function logic — stored on order so CF can verify
      const serviceFeeRate = 0.10;
      final serviceFee     = double.parse((_cart.subtotal * serviceFeeRate).toStringAsFixed(2));
      final gooutsVatTotal = double.parse(
          ((serviceFee * 0.20) + (_effectiveDeliveryFee * 0.20)).toStringAsFixed(2));

      // Customer display name for driver app + vat_records
      final customerName = FirebaseAuth.instance.currentUser?.displayName ?? '';

      final orderData = {
        'orderId'           : orderRef.id,
        'userId'            : uid,
        'customerName'      : customerName,
        'restaurantId'      : _cart.restaurantId,
        'restaurantName'    : _cart.restaurantName,
        'items'             : _cart.items.map((i) => i.toMap()).toList(),
        'subtotal'          : _cart.subtotal,
        'serviceFee'        : serviceFee,       // needed by Cloud Function for VAT
        'deliveryFee'       : _effectiveDeliveryFee,
        'total'             : _cart.subtotal + _effectiveDeliveryFee,
        'foodVatTotal'      : foodVatTotal,
        'gooutsVatTotal'    : gooutsVatTotal,
        'grandTotalVat'     : double.parse((foodVatTotal + gooutsVatTotal).toStringAsFixed(2)),
        'deliveryAddress'   : _deliveryAddress,
        'paymentMethod'     : _selectedPayment,
        'specialNote'       : _noteCtrl.text.trim(),
        'status'            : 'pending',
        'socialBoostApplied': _boostApplied,
        'socialBoostCodeId' : _boostApplied ? _boostCodeId : null,
        'createdAt'         : FieldValue.serverTimestamp(),
        'estimatedMins'     : _cart.deliveryMins,
      };

      await orderRef.set(orderData);

      // Mark social boost code as used
      if (_boostApplied && _boostCodeId != null) {
        await _db
            .collection('users')
            .doc(uid)
            .collection('socialBoostCodes')
            .doc(_boostCodeId)
            .update({
          'used'      : true,
          'usedAt'    : FieldValue.serverTimestamp(),
          'usedOnOrder': orderRef.id,
        });
      }

      // Clear cart
      _cart.clear();

      if (mounted) {
        // Navigate to tracking screen — pass args via RouteSettings
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const FoodOrderTrackingScreen(),
            settings: RouteSettings(arguments: {
              'orderId':        orderRef.id,
              'restaurantId':   _cart.restaurantId ?? '',
              'restaurantName': _cart.restaurantName ?? '',
            }),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _placing = false);
        _showSnack('Failed to place order. Please try again.', error: true);
      }
    }
  }

  // ── ⚠ THIS IGNORED ITS OWN ARGUMENT ────────────────────────────────────
  //
  // FIXED 14 August 2026. It read:
  //
  //   GoOutsSheet.error(context, title: 'msg', message: 'msg');
  //
  // QUOTED. During the snackbar-to-GoOutsSheet migration the parameter name
  // was swallowed into a string literal, so every message this method was ever
  // asked to show was replaced by the three characters "msg".
  //
  // Two of the three call sites are in the checkout path — "Please add a
  // delivery address first" and "Failed to place order. Please try again."
  // A customer whose order failed was shown a box saying "msg".
  //
  // The `error` flag was ignored too: everything came out as an error sheet,
  // including confirmations.
  void _showSnack(String msg, {bool error = false}) {
    if (error) {
      GoOutsSheet.error(context, title: 'Something went wrong', message: msg);
    } else {
      GoOutsSheet.info(context, title: 'GoOuts', message: msg);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checkout',
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
            if (_cart.restaurantName != null)
              Text(_cart.restaurantName!,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final subtotal     = _cart.subtotal;
    final delivery     = _effectiveDeliveryFee;
    final total        = subtotal + delivery;
    final foodVat      = _cart.foodVatTotal;
    final totalVat     = double.parse(
        (foodVat + (subtotal * 0.10 * 0.20) + (delivery * 0.20)).toStringAsFixed(2));

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
          children: [
            // ── Social Boost applied banner ───────────────────────────────
            if (_boostApplied)
              _boostBanner(),

            // ── Delivery address ──────────────────────────────────────────
            _sectionCard(
              icon: Icons.location_on_rounded,
              iconColor: _primary,
              title: 'Delivery Address',
              child: _deliveryAddress.isEmpty
                  ? GestureDetector(
                      onTap: _pickAddress,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: _primary, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.add_location_alt_rounded,
                              color: _primary, size: 20),
                          const SizedBox(width: 10),
                          Text('Add delivery address',
                            style: GoogleFonts.inter(
                                color: _primary, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Text(_deliveryAddress,
                            style: GoogleFonts.inter(
                                fontSize: 14, color: _navy, height: 1.4)),
                        ),
                        TextButton(
                          onPressed: _pickAddress,
                          child: Text('Change',
                            style: GoogleFonts.inter(
                                color: _blue, fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),

            // ── Order items ───────────────────────────────────────────────
            _sectionCard(
              icon: Icons.receipt_long_rounded,
              iconColor: _navy,
              title: 'Your Order',
              trailing: Text(
                '${_cart.totalItems} ${_cart.totalItems == 1 ? "item" : "items"}',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
              child: Column(
                children: [
                  ..._cart.items.map((item) => _orderItemRow(item)),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  // Note to restaurant
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 13, color: _navy),
                    decoration: InputDecoration(
                      hintText: 'Add a note to the restaurant (e.g. no onions)…',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 13, color: Colors.grey[400]),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _primary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Payment method ────────────────────────────────────────────
            _sectionCard(
              icon: Icons.payment_rounded,
              iconColor: _blue,
              title: 'Payment Method',
              child: Column(
                children: [
                  _paymentOption('card',   Icons.credit_card_rounded,
                      'Credit / Debit Card', 'Visa, Mastercard, Amex'),
                  _paymentOption('wallet', Icons.account_balance_wallet_rounded,
                      'GoOuts Wallet', 'Use your cashback balance'),
                  _paymentOption('apple',  Icons.phone_iphone_rounded,
                      'Apple Pay', 'Touch ID or Face ID'),
                  _paymentOption('google', Icons.g_mobiledata_rounded,
                      'Google Pay', 'Quick & secure'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Price summary ─────────────────────────────────────────────
            _sectionCard(
              icon: Icons.summarize_rounded,
              iconColor: _green,
              title: 'Order Summary',
              child: Column(
                children: [
                  _summaryRow('Subtotal', '£${subtotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _summaryRow(
                    'Delivery fee',
                    _boostApplied ? 'FREE' : '£${delivery.toStringAsFixed(2)}',
                    valueColor: _boostApplied ? _green : null,
                    strikethrough: _boostApplied,
                    strikeValue: '£${_cart.deliveryFee.toStringAsFixed(2)}',
                  ),
                  if (_boostApplied) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.bolt_rounded, color: _purple, size: 14),
                      const SizedBox(width: 4),
                      Text('Social Boost applied',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: _purple,
                            fontWeight: FontWeight.w500)),
                    ]),
                  ],
                  if (totalVat > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.receipt_rounded, size: 13,
                              color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('Incl. VAT',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: const Color(0xFF64748B))),
                        ]),
                        Text('£${totalVat.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: _navy)),
                      Text('£${total.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: _primary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.timer_rounded, size: 14, color: _green),
                    const SizedBox(width: 4),
                    Text('Estimated delivery: ${_cart.deliveryMins} min',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[600])),
                  ]),
                ],
              ),
            ),
          ],
        ),

        // ── Place order button (fixed bottom) ─────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20, offset: const Offset(0, -4))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Boost prompt if not yet checked and has boost
                if (!_boostChecked && _boostCodeId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: _showBoostPopup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFEA580C)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const Icon(Icons.bolt_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have a free delivery reward! Tap to apply.',
                              style: GoogleFonts.inter(
                                  color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white70, size: 14),
                        ]),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _placing ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: _primary.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _placing
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Place Order · £${total.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Social Boost applied banner ────────────────────────────────────────────
  Widget _boostBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFEA580C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Social Boost Applied!',
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            Text('Free delivery reward applied to your order.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('FREE',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ]),
    );
  }

  // ── Section card ───────────────────────────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 8),
                Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  // ── Order item row ─────────────────────────────────────────────────────────
  Widget _orderItemRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${item.quantity}x',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _primary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.name,
              style: GoogleFonts.inter(fontSize: 14, color: _navy)),
          ),
          Text('£${item.subtotal.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
        ],
      ),
    );
  }

  // ── Payment option ─────────────────────────────────────────────────────────
  Widget _paymentOption(String id, IconData icon, String label, String sub) {
    final selected = _selectedPayment == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _blue.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? _blue : _border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _blue : Colors.grey[500], size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: selected ? _blue : _navy)),
                Text(sub,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _blue, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Summary row ────────────────────────────────────────────────────────────
  Widget _summaryRow(String label, String value,
      {Color? valueColor, bool strikethrough = false, String? strikeValue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600])),
        Row(children: [
          if (strikethrough && strikeValue != null)
            Text(strikeValue,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[400],
                  decoration: TextDecoration.lineThrough)),
          if (strikethrough) const SizedBox(width: 6),
          Text(value,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: valueColor ?? _navy)),
        ]),
      ],
    );
  }

  // ── Address picker ─────────────────────────────────────────────────────────
  Future<void> _pickAddress() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddressPickerSheet(
          addressService: _addressService),
    );
    if (result != null && mounted) {
      setState(() => _deliveryAddress = result);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AddressPickerSheet
// ─────────────────────────────────────────────────────────────────────────────
class _AddressPickerSheet extends StatefulWidget {
  final DeliveryAddressService addressService;
  const _AddressPickerSheet({required this.addressService});

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  static const Color _navy    = Color(0xFF0D1B3E);
  static const Color _primary = Color(0xFFEA580C);
  static const Color _blue    = Color(0xFF0392CA);

  final _ctrl = TextEditingController();
  List<String> _saved = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await widget.addressService.getSavedAddresses();
      if (mounted) setState(() => _saved = saved);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Delivery Address',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 16),

            // Manual input
            TextField(
              controller: _ctrl,
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter full address…',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.grey, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_ctrl.text.trim().isNotEmpty) {
                    Navigator.pop(context, _ctrl.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text('Use This Address',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ),

            // Saved addresses
            if (_saved.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Saved Addresses',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Colors.grey[600])),
              const SizedBox(height: 8),
              ..._saved.map((addr) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_rounded,
                    color: _blue, size: 20),
                title: Text(addr,
                  style: GoogleFonts.inter(fontSize: 13, color: _navy)),
                onTap: () => Navigator.pop(context, addr),
              )),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
