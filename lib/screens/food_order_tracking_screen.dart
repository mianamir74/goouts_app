import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../widgets/live_tracking_map.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FoodOrderTrackingScreen  —  live order tracking + Add to Order (5-min window)
//  Route:  /food-order-tracking
//  Args:   orderId (String), restaurantId (String), restaurantName (String)
// ─────────────────────────────────────────────────────────────────────────────
class FoodOrderTrackingScreen extends StatefulWidget {
  const FoodOrderTrackingScreen({super.key});

  @override
  State<FoodOrderTrackingScreen> createState() =>
      _FoodOrderTrackingScreenState();
}

class _FoodOrderTrackingScreenState extends State<FoodOrderTrackingScreen> {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFFEA580C);
  static const Color _navy    = Color(0xFF0D1B3E);
  static const Color _green   = Color(0xFF10B981);
  static const Color _amber   = Color(0xFFF59E0B);
  static const Color _blue    = Color(0xFF3B82F6);
  static const Color _red     = Color(0xFFEF4444);
  static const Color _bg      = Color(0xFFF2F4F7);

  // ── Args ───────────────────────────────────────────────────────────────────
  late String _orderId;
  late String _restaurantId;
  late String _restaurantName;
  bool _argsInit = false;

  // ── State ──────────────────────────────────────────────────────────────────
  final _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _orderSub;
  Map<String, dynamic>? _order;
  bool _loading = true;

  // Rating / tip — shown once when status becomes 'delivered'
  bool _ratingShown = false;

  // Add-to-order window countdown
  Timer? _countdownTimer;
  Duration? _addWindowRemaining;
  bool _addWindowOpen = false;

  // Cancellation window
  Timer?    _cancelTimer;
  Duration? _cancelFreeRemaining;   // null = no free window active
  bool      _cancelFree    = false; // true = cancel is currently free
  bool      _cancelAllowed = false; // false = too late to cancel in-app
  double    _cancelFee     = 0.0;   // 0 = free, >0 = fee amount
  bool      _cancelling    = false;
  double    _cashbackEarned = 0.0;

  // Substitution request
  bool _subResponding = false;

  // Addition picker
  bool _menuLoading = false;
  List<_PickerItem> _menuItems     = [];
  List<_PickerItem> _suggestedItems = [];
  final Map<String, int> _pickerQty = {};

  // ── Status flow ────────────────────────────────────────────────────────────
  static const _steps = [
    'pending',
    'accepted',
    'preparing',
    'ready',
    'driver_heading_to_restaurant',
    'driver_picked_up',
    'delivered',
  ];

  static const Map<String, String> _stepLabel = {
    'pending'   : 'Order Placed',
    'accepted'  : 'Accepted',
    'preparing' : 'Preparing',
    'ready'     : 'Ready',
    'delivered' : 'Delivered',
  };

  static const Map<String, IconData> _stepIcon = {
    'pending'   : Icons.receipt_long_rounded,
    'accepted'  : Icons.check_circle_outline_rounded,
    'preparing' : Icons.restaurant_rounded,
    'ready'     : Icons.delivery_dining_rounded,
    'delivered' : Icons.celebration_rounded,
  };

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsInit) return;
    _argsInit = true;
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ??
            {};
    _orderId        = (args['orderId']        as String?) ?? '';
    _restaurantId   = (args['restaurantId']   as String?) ?? '';
    _restaurantName = (args['restaurantName'] as String?) ?? 'Restaurant';
    _subscribeToOrder();
  }

  void _subscribeToOrder() {
    _orderSub = _db
        .collection('food_orders')
        .doc(_orderId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final prevStatus = _order?['status'] as String?;
      setState(() {
        _order   = {'id': snap.id, ...snap.data()!};
        _loading = false;
      });
      _recalcWindow();
      _recalcCancel();
      // Auto-show rating sheet when delivery completes
      final newStatus = _order?['status'] as String?;
      if (!_ratingShown && newStatus == 'delivered' && prevStatus != 'delivered') {
        _ratingShown = true;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _showRatingSheet();
        });
      }
    });
  }

  void _recalcWindow() {
    _countdownTimer?.cancel();
    final status = _order?['status'] as String? ?? '';
    final isActive = status == 'accepted' || status == 'preparing';

    if (!isActive) {
      if (mounted) setState(() { _addWindowRemaining = null; _addWindowOpen = false; });
      return;
    }

    final acceptedAt = _order?['acceptedAt'] as Timestamp?;
    if (acceptedAt == null) {
      if (mounted) setState(() { _addWindowRemaining = null; _addWindowOpen = false; });
      return;
    }

    final windowEnd = acceptedAt.toDate().add(const Duration(minutes: 5));

    void tick() {
      final rem = windowEnd.difference(DateTime.now());
      if (!mounted) return;
      if (rem.isNegative) {
        _countdownTimer?.cancel();
        setState(() { _addWindowRemaining = Duration.zero; _addWindowOpen = false; });
      } else {
        setState(() { _addWindowRemaining = rem; _addWindowOpen = true; });
      }
    }

    tick(); // immediate
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // ── Cancellation window ───────────────────────────────────────────────────
  void _recalcCancel() {
    _cancelTimer?.cancel();
    final status = _order?['status'] as String? ?? '';

    // Statuses where in-app cancel is blocked
    const blocked = ['ready', 'driver_heading_to_restaurant',
                     'driver_picked_up', 'delivered',
                     'cancelled', 'cancelled_with_fee', 'refunded', 'rejected'];
    if (blocked.contains(status)) {
      if (mounted) setState(() { _cancelAllowed = false; _cancelFree = false; _cancelFreeRemaining = null; });
      return;
    }

    // Pending — always free, no countdown
    if (status == 'pending') {
      if (mounted) setState(() { _cancelAllowed = true; _cancelFree = true; _cancelFee = 0; _cancelFreeRemaining = null; });
      return;
    }

    final foodTotal  = (_order?['foodTotal'] ?? _order?['orderTotal'] ?? 0.0).toDouble();
    final acceptedAt = _order?['acceptedAt'] as Timestamp?;

    if (status == 'accepted') {
      if (acceptedAt == null) {
        // acceptedAt not stamped yet — treat as free
        if (mounted) setState(() { _cancelAllowed = true; _cancelFree = true; _cancelFee = 0; _cancelFreeRemaining = null; });
        return;
      }
      final graceEnd = acceptedAt.toDate().add(const Duration(minutes: 5));

      void tick() {
        if (!mounted) return;
        final rem = graceEnd.difference(DateTime.now());
        if (rem.isNegative) {
          _cancelTimer?.cancel();
          setState(() {
            _cancelAllowed       = true;
            _cancelFree          = false;
            _cancelFreeRemaining = Duration.zero;
            _cancelFee           = double.parse((foodTotal * 0.50).toStringAsFixed(2));
          });
        } else {
          setState(() {
            _cancelAllowed       = true;
            _cancelFree          = true;
            _cancelFreeRemaining = rem;
            _cancelFee           = 0;
          });
        }
      }
      tick();
      _cancelTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
      return;
    }

    if (status == 'preparing') {
      // Can still cancel but 75% fee applies — no countdown
      if (mounted) setState(() {
        _cancelAllowed       = true;
        _cancelFree          = false;
        _cancelFreeRemaining = null;
        _cancelFee           = double.parse((foodTotal * 0.75).toStringAsFixed(2));
      });
    }
  }

  Future<void> _cancelOrder() async {
    // Step 1: confirm cancellation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(_cancelFee > 0
            ? '£${_cancelFee.toStringAsFixed(2)} cancellation fee will be charged. '
              'The remaining amount will be refunded.'
            : 'Are you sure you want to cancel this order?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Order')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: Colors.white),
            child: Text(_cancelFee > 0 ? 'Cancel & Pay Fee' : 'Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Step 2: pick refund method
    final refundMethod = await _showRefundMethodSheet(
      refundAmount: _cancelFreeRemaining != null ? (_order?['grandTotal'] as double?) ?? 0.0 : 0.0,
      cashbackEarned: _cashbackEarned,
      context: 'cancel',
    );
    if (refundMethod == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final res = await fn.httpsCallable('cancelFoodOrder').call({
        'orderId'      : _orderId,
        'reason'       : 'customer_request',
        'refundMethod' : refundMethod,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.data['message'] as String? ?? 'Order cancelled.'),
        backgroundColor: _cancelFee > 0 ? _amber : _green,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cancellation failed: $e'),
        backgroundColor: _red,
      ));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  /// Shows a bottom sheet for the customer to choose their refund destination.
  /// Returns 'wallet' | 'original_payment' | null (dismissed).
  Future<String?> _showRefundMethodSheet({
    required double refundAmount,
    required double cashbackEarned,
    required String context,
  }) {
    final netRefund = (refundAmount - cashbackEarned).clamp(0.0, double.infinity);
    return showModalBottomSheet<String>(
      context: this.context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 18),
          Text('Choose Refund Method',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 6),
          if (cashbackEarned > 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _amber.withOpacity(0.4)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: _amber, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'You earned £${cashbackEarned.toStringAsFixed(2)} cashback on this order. '
                  'This will be deducted from your refund.',
                  style: GoogleFonts.inter(fontSize: 12, color: _navy, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          // Wallet option
          _refundOption(
            icon: Icons.account_balance_wallet_rounded,
            color: _green,
            title: 'GoOuts Wallet',
            subtitle: 'Instant · available for your next order immediately',
            amount: netRefund,
            badge: 'INSTANT',
            badgeColor: _green,
            onTap: () => Navigator.pop(_, 'wallet'),
          ),
          const SizedBox(height: 10),
          // Original payment option
          _refundOption(
            icon: Icons.credit_card_rounded,
            color: _primary,
            title: 'Original Payment Method',
            subtitle: 'Back to your card or bank account · 3–5 business days',
            amount: netRefund,
            badge: '3–5 DAYS',
            badgeColor: _primary,
            onTap: () => Navigator.pop(_, 'original_payment'),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => Navigator.pop(_, null),
            child: Center(child: Text('Go Back',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]))),
          ),
        ]),
      ),
    );
  }

  Widget _refundOption({
    required IconData icon, required Color color, required String title,
    required String subtitle, required double amount, required String badge,
    required Color badgeColor, required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: badgeColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(badge, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
        ])),
        Text('£${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );

  // ── Rating + Tip sheet ────────────────────────────────────────────────────
  void _showRatingSheet() {
    int selectedStars  = 5;
    int selectedTipIdx = 1; // default £1.00
    bool submitting    = false;

    final tipOptions = [
      {'label': 'No tip',  'amount': 0.0},
      {'label': '£1.00',   'amount': 1.0},
      {'label': '£2.00',   'amount': 2.0},
      {'label': '£3.00',   'amount': 3.0},
      {'label': 'Custom',  'amount': -1.0},
    ];

    final customCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final driverName = (_order?['driverName'] as String?) ?? 'Your Driver';

          Future<void> submit() async {
            setSheet(() => submitting = true);
            try {
              double tipAmount = 0.0;
              if (selectedTipIdx == tipOptions.length - 1) {
                tipAmount = double.tryParse(customCtrl.text) ?? 0.0;
              } else {
                tipAmount = (tipOptions[selectedTipIdx]['amount'] as double);
              }

              final uid = _order?['userId'] as String?;
              final driverId = _order?['driverId'] as String?;

              // Save rating to order doc
              await _db.collection('food_orders').doc(_orderId).update({
                'driverRating' : selectedStars,
                'driverTip'    : tipAmount,
                'ratedAt'      : FieldValue.serverTimestamp(),
              });

              // Save tip to driver doc if driver assigned
              if (driverId != null && tipAmount > 0) {
                await _db.collection('food_drivers').doc(driverId).set({
                  'pendingTips': FieldValue.increment(tipAmount),
                }, SetOptions(merge: true));
              }

              if (ctx.mounted) {
                Navigator.pop(ctx);
                // If rating is 3 or below, show complaint form
                if (selectedStars <= 3 && mounted) {
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted) _showComplaintSheet(selectedStars);
                  });
                }
              }
            } catch (_) {
              setSheet(() => submitting = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Celebration icon
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.celebration_rounded,
                        color: _green, size: 32),
                  ),
                  const SizedBox(height: 14),

                  Text('Order Delivered!',
                    style: GoogleFonts.inter(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: _navy)),
                  const SizedBox(height: 6),
                  Text('How was $driverName?',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 20),

                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => GestureDetector(
                      onTap: () => setSheet(() => selectedStars = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          i < selectedStars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: _amber,
                          size: 40,
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedStars == 5 ? 'Excellent!' :
                    selectedStars == 4 ? 'Great' :
                    selectedStars == 3 ? 'Good' :
                    selectedStars == 2 ? 'Could be better' : 'Poor',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: _amber,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),

                  // Tip section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Leave a tip?',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: _navy)),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('100% goes directly to your driver.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: Colors.grey[500])),
                  ),
                  const SizedBox(height: 12),

                  // Tip pills
                  Row(
                    children: List.generate(tipOptions.length, (i) {
                      final selected = selectedTipIdx == i;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setSheet(() => selectedTipIdx = i),
                          child: Container(
                            margin: EdgeInsets.only(right: i < tipOptions.length - 1 ? 8 : 0),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? _primary : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: selected ? _primary : Colors.grey.shade300),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              tipOptions[i]['label'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : _navy),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  // Custom tip input
                  if (selectedTipIdx == tipOptions.length - 1) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '£',
                        hintText: '0.00',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _primary, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: submitting ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('Submit & Done',
                              style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),

                  // Skip
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Skip',
                      style: GoogleFonts.inter(
                          color: Colors.grey[400], fontSize: 13)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // ── Complaint sheet — shown automatically after rating ≤ 3 ────────────────
  void _showComplaintSheet(int stars) {
    final categories = [
      'Late delivery',
      'Wrong items',
      'Missing items',
      'Poor packaging',
      'Cold food',
      'Driver behaviour',
      'Food quality',
      'Other',
    ];
    final selected   = <String>{};
    final noteCtrl   = TextEditingController();
    bool submitting  = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> submitComplaint() async {
            if (selected.isEmpty) return;
            setSheet(() => submitting = true);
            try {
              await _db.collection('food_complaints').add({
                'orderId'      : _orderId,
                'restaurantId' : _restaurantId,
                'restaurantName': _restaurantName,
                'customerId'   : _order?['userId'],
                'driverId'     : _order?['driverId'],
                'driverRating' : stars,
                'categories'   : selected.toList(),
                'note'         : noteCtrl.text.trim(),
                'status'       : 'open',
                'createdAt'    : FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Complaint submitted — our team will review it.'),
                    backgroundColor: Color(0xFF0D1B3E),
                  ),
                );
              }
            } catch (_) {
              setSheet(() => submitting = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sentiment_dissatisfied_rounded,
                          color: _red, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('What went wrong?',
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                      Text('Help us improve your experience.',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
                    ])),
                  ]),
                  const SizedBox(height: 20),

                  // Category chips
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selected.contains(cat);
                      return GestureDetector(
                        onTap: () => setSheet(() {
                          if (isSelected) selected.remove(cat);
                          else selected.add(cat);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? _red.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected ? _red : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 1),
                          ),
                          child: Text(cat,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                                  color: isSelected ? _red : Colors.black54)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Note field
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.inter(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add more details (optional)…',
                      hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF2F4F7),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (submitting || selected.isEmpty) ? null : submitComplaint,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: submitting
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              selected.isEmpty
                                  ? 'Select at least one issue'
                                  : 'Submit Complaint',
                              style: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Skip for now',
                        style: GoogleFonts.inter(
                            color: Colors.grey[400], fontSize: 13)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _countdownTimer?.cancel();
    _cancelTimer?.cancel();
    super.dispose();
  }

  // ── Load menu + compute AI suggestions ────────────────────────────────────
  Future<void> _loadMenu() async {
    if (_menuItems.isNotEmpty) return;
    setState(() => _menuLoading = true);
    try {
      final snap = await _db
          .collection('merchants')
          .doc(_restaurantId)
          .collection('menu_items')
          .where('isAvailable', isEqualTo: true)
          .orderBy('name')
          .get();
      _menuItems = snap.docs
          .map<_PickerItem>((d) {
            final data = d.data();
            return _PickerItem(
              id:            d.id,
              name:          data['name']       as String? ?? '',
              price:         (data['price'] as num?)?.toDouble() ?? 0,
              imageUrl:      data['imageUrl']   as String? ?? '',
              categoryId:    data['categoryId'] as String? ?? '',
              isRecommended: data['isRecommended'] == true,
              isPopular:     data['isPopular']     == true,
              orderCount:    (data['orderCount'] as num?)?.toInt() ?? 0,
            );
          })
          .where((i) => i.name.isNotEmpty)
          .toList();
      _suggestedItems = _computeSuggestions();
    } catch (_) {}
    if (mounted) setState(() => _menuLoading = false);
  }

  // ── Rule-based AI suggestion engine ───────────────────────────────────────
  // Scores each menu item based on:
  //  +5  isRecommended (merchant-flagged chef's pick)
  //  +3  isPopular (high-volume item)
  //  +orderCount/20  order volume signal
  //  +4  fills a category gap (category not in current order)
  //  -99 already in this order → excluded
  List<_PickerItem> _computeSuggestions() {
    if (_menuItems.isEmpty) return [];

    // Categories already covered by the current order
    final orderItems = List<Map<String, dynamic>>.from(_order?['items'] ?? []);
    final orderedCategoryIds = orderItems
        .map((i) => i['categoryId'] as String? ?? '')
        .where((c) => c.isNotEmpty)
        .toSet();
    final orderedItemIds = orderItems
        .map((i) => i['itemId'] as String? ?? i['id'] as String? ?? '')
        .toSet();

    // Score every item
    final scored = <_PickerItem, double>{};
    for (final item in _menuItems) {
      if (orderedItemIds.contains(item.id)) continue; // already ordered
      double score = 0;
      if (item.isRecommended)  score += 5;
      if (item.isPopular)       score += 3;
      score += item.orderCount / 20.0; // volume signal, capped naturally
      if (!orderedCategoryIds.contains(item.categoryId)) score += 4; // gap-fill
      scored[item] = score;
    }

    // Sort by score desc, take top 5
    final ranked = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ranked.take(5).map((e) => e.key).toList();
  }

  // ── Send addition request ──────────────────────────────────────────────────
  Future<void> _sendAdditionRequest() async {
    final selected = _pickerQty.entries
        .where((e) => e.value > 0)
        .map((e) {
          final item = _menuItems.firstWhere((i) => i.id == e.key);
          return {
            'itemId'  : item.id,
            'name'    : item.name,
            'price'   : item.price,
            'quantity': e.value,
            'subtotal': item.price * e.value,
          };
        })
        .toList();

    if (selected.isEmpty) return;

    final additionalTotal = selected.fold<double>(
        0, (sum, i) => sum + ((i['subtotal'] as num?)?.toDouble() ?? 0));

    final addition = {
      'additionId'      : DateTime.now().millisecondsSinceEpoch.toString(),
      'items'           : selected,
      'additionalTotal' : additionalTotal,
      'status'          : 'pending',
      'requestedAt'     : FieldValue.serverTimestamp(),
      'respondedAt'     : null,
    };

    try {
      await _db.collection('food_orders').doc(_orderId).update({
        'additions': FieldValue.arrayUnion([addition]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context); // close bottom sheet
        _pickerQty.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Addition request sent to the restaurant!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request. Please try again.',
                style: GoogleFonts.inter()),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmt(dynamic v) =>
      '£${((v as num?)?.toDouble() ?? 0).toStringAsFixed(2)}';

  String _fmtTime(dynamic ts) {
    if (ts == null) return '';
    final dt = ts is Timestamp ? ts.toDate() : ts as DateTime;
    return DateFormat('d MMM, h:mm a').format(dt);
  }

  String _countdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int _stepIndex(String status) {
    if (status == 'cancelled' || status == 'rejected') return -1;
    // Legacy alias
    if (status == 'picked_up') return _steps.indexOf('driver_picked_up');
    final idx = _steps.indexOf(status);
    // Unknown status — clamp to last known step
    return idx < 0 ? 0 : idx;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Color(0xFF0D1B3E)),
          title: Text('Order Tracking',
              style: GoogleFonts.inter(
                  color: _navy, fontWeight: FontWeight.w700)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: Color(0xFFEA580C))),
      );
    }

    final order   = _order!;
    final status  = order['status'] as String? ?? 'pending';
    final isCancelled = status == 'cancelled' || status == 'rejected';
    final items   = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final additions = List<Map<String, dynamic>>.from(order['additions'] ?? []);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF0D1B3E)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_restaurantName,
                style: GoogleFonts.inter(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            Text('Order #${_orderId.length > 8 ? _orderId.substring(0, 8) : _orderId}',
                style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
        actions: [
          // Chat button — shown once driver is heading to restaurant
          if (['driver_heading_to_restaurant', 'driver_picked_up', 'delivered']
              .contains(status))
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFFEA580C)),
              tooltip: 'Chat with driver',
              onPressed: () => Navigator.pushNamed(
                context,
                '/food-delivery-chat',
                arguments: {
                  'orderId'    : _orderId,
                  'driverName' : (order['driverName'] as String?) ?? 'Your Driver',
                  'orderStatus': status,
                },
              ),
            ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.grey),
            tooltip: 'Get Help',
            onPressed: () => Navigator.pushNamed(
              context,
              '/contact-support',
              arguments: {'orderId': _orderId},
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.grey),
            tooltip: 'Order History',
            onPressed: () => Navigator.pushNamed(context, '/food-order-history'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status card
            if (!isCancelled) _buildStatusStepper(status),
            if (isCancelled)  _buildCancelledCard(status),

            // Live tracking map — shown when driver is en route
            if (['driver_heading_to_restaurant', 'driver_picked_up']
                .contains(status)) ...[
              const SizedBox(height: 16),
              LiveTrackingMap(
                orderId: _orderId,
                restaurantLocation: order['restaurantLocation'] as GeoPoint?,
                deliveryLocation:   order['deliveryLocation']   as GeoPoint?,
                restaurantName:     order['restaurantName']     as String?,
              ),
            ],

            // Cancellation button (shown while order is still cancellable)
            if (!isCancelled && _cancelAllowed) ...[
              const SizedBox(height: 12),
              _buildCancelCard(),
            ],

            // Substitution request banner (restaurant flagged an item unavailable)
            if (!isCancelled && order['substitutionRequest'] != null &&
                (order['substitutionRequest'] as Map)['status'] == 'pending') ...[
              const SizedBox(height: 12),
              _buildSubstitutionBanner(order['substitutionRequest'] as Map<String, dynamic>),
            ],

            const SizedBox(height: 16),

            // Add to Order window (only when window is open)
            if (_addWindowOpen && _addWindowRemaining != null &&
                _addWindowRemaining! > Duration.zero)
              _buildAddToOrderCard(),

            // Pending addition requests
            if (additions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...additions.map(_buildAdditionCard),
            ],

            const SizedBox(height: 8),

            // Order summary
            _buildOrderSummary(order, items),

            const SizedBox(height: 8),

            // Delivery info
            _buildDeliveryInfo(order),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Status stepper ─────────────────────────────────────────────────────────
  Widget _buildStatusStepper(String status) {
    final currentIdx = _stepIndex(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                  color: Color(0xFF10B981), shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text('Live Order Status',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF0D1B3E))),
          ]),
          const SizedBox(height: 20),
          ...List.generate(_steps.length, (i) {
            final step    = _steps[i];
            final isDone  = i <= currentIdx;
            final isNow   = i == currentIdx;
            final isLast  = i == _steps.length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line + icon column
                Column(children: [
                  _stepDot(isDone, isNow, _stepIcon[step]!),
                  if (!isLast)
                    Container(
                      width: 2, height: 32,
                      color: isDone && i < currentIdx
                          ? _primary
                          : const Color(0xFFE5E7EB),
                    ),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_stepLabel[step]!,
                            style: GoogleFonts.inter(
                                fontWeight: isNow
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 14,
                                color: isDone ? _navy : Colors.grey[400])),
                        if (isNow)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(_stepSubtitle(step),
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _primary)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _stepDot(bool done, bool isNow, IconData icon) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: done ? _primary : const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
        border: isNow
            ? Border.all(color: _primary, width: 2)
            : null,
      ),
      child: Icon(icon,
          size: 16,
          color: done ? Colors.white : Colors.grey[400]),
    );
  }

  String _stepSubtitle(String step) {
    switch (step) {
      case 'pending'  : return 'Waiting for restaurant to accept...';
      case 'accepted' : return 'Restaurant has accepted your order';
      case 'preparing': return 'Your food is being prepared';
      case 'ready'    : return 'Ready — driver on the way';
      case 'delivered': return 'Enjoy your meal!';
      default         : return '';
    }
  }

  // ── Substitution banner ────────────────────────────────────────────────────
  Widget _buildSubstitutionBanner(Map<String, dynamic> sub) {
    final itemName   = sub['itemName']   as String? ?? 'an item';
    final alts       = List<Map<String, dynamic>>.from(sub['alternatives'] ?? []);
    final hasAlts    = alts.isNotEmpty;
    final origPrice  = (sub['originalPrice'] ?? 0.0).toDouble();
    final origQty    = (sub['originalQty']   ?? 1).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title row
        Row(children: [
          const Icon(Icons.swap_horiz_rounded, color: Color(0xFFF59E0B), size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Item unavailable: $itemName',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF92400E)),
          )),
        ]),
        const SizedBox(height: 6),
        Text(
          hasAlts
              ? 'The restaurant suggests a substitute. Choose one below, remove the item, or cancel your order.'
              : 'The restaurant cannot fulfil this item. You can remove it (refund issued) or cancel your order.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF78350F)),
        ),

        // Alternatives
        if (hasAlts) ...[
          const SizedBox(height: 12),
          ...alts.map((alt) {
            final altName  = alt['itemName'] as String? ?? '';
            final altPrice = (alt['price'] ?? 0.0).toDouble();
            final altId    = alt['itemId']   as String? ?? '';
            final diff     = altPrice - origPrice;
            final diffText = diff == 0 ? 'Same price'
                           : diff > 0  ? '+£${diff.toStringAsFixed(2)}'
                           : '-£${(-diff).toStringAsFixed(2)}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF92400E),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: _subResponding ? null : () => _respondToSubstitution('accept', chosenAltId: altId),
                child: Row(children: [
                  Expanded(child: Text(altName, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text('£${(altPrice * origQty).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: diff <= 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(diffText,
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: diff <= 0 ? const Color(0xFF166534) : const Color(0xFF92400E),
                        )),
                  ),
                ]),
              ),
            );
          }),
        ],

        const SizedBox(height: 8),
        // Remove / Cancel row
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: BorderSide(color: _red.withOpacity(0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _subResponding ? null : () => _respondToSubstitution('decline'),
              child: Text(
                'Remove & Refund\n(£${(origPrice * origQty).toStringAsFixed(2)} back)',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: BorderSide(color: _red.withOpacity(0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _subResponding ? null : () => _respondToSubstitution('cancel_order'),
              child: const Text(
                'Cancel Order\n(full refund)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ]),

        if (_subResponding)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)))),
          ),
      ]),
    );
  }

  Future<void> _respondToSubstitution(String response, {String? chosenAltId}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          response == 'accept'  ? 'Accept Substitution?' :
          response == 'decline' ? 'Remove Item & Refund?' : 'Cancel Order?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          response == 'accept'  ? 'The substitute item will be prepared instead.' :
          response == 'decline' ? 'The item will be removed. Choose how to receive your refund next.' :
                                  'Your full payment will be refunded. Choose how to receive it next.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: response == 'accept' ? _green : _red,
              foregroundColor: Colors.white,
            ),
            child: Text(response == 'accept' ? 'Confirm' : response == 'decline' ? 'Remove Item' : 'Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // For decline/cancel ask refund method; accept doesn't involve a refund choice
    String refundMethod = 'wallet';
    if (response != 'accept') {
      final chosen = await _showRefundMethodSheet(
        refundAmount: _cashbackEarned, // approximate; server calculates exact
        cashbackEarned: _cashbackEarned,
        context: 'substitution',
      );
      if (chosen == null || !mounted) return;
      refundMethod = chosen;
    }

    setState(() => _subResponding = true);
    try {
      final fn  = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final res = await fn.httpsCallable('respondToSubstitution').call({
        'orderId'      : _orderId,
        'response'     : response,
        'refundMethod' : refundMethod,
        if (chosenAltId != null) 'chosenAltId': chosenAltId,
      });
      final msg = (res.data as Map?)?['message'] as String?;
      if (mounted && msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor:
              response == 'accept' ? _green : _primary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: _red),
        );
      }
    } finally {
      if (mounted) setState(() => _subResponding = false);
    }
  }

  // ── Cancel order card ──────────────────────────────────────────────────────
  Widget _buildCancelCard() {
    // Format countdown MM:SS
    String countdown = '';
    if (_cancelFreeRemaining != null && _cancelFreeRemaining! > Duration.zero) {
      final m = _cancelFreeRemaining!.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = _cancelFreeRemaining!.inSeconds.remainder(60).toString().padLeft(2, '0');
      countdown = '$m:$s';
    }

    final isFree   = _cancelFree;
    final hasFee   = !isFree && _cancelFee > 0;
    final cardColor = isFree ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED);
    final borderColor = isFree ? const Color(0xFF86EFAC) : const Color(0xFFFBD38D);
    final textColor   = isFree ? const Color(0xFF166534) : const Color(0xFF92400E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(
          isFree ? Icons.timer_rounded : Icons.warning_amber_rounded,
          color: textColor, size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isFree
                ? (countdown.isNotEmpty ? 'Free cancellation — $countdown remaining' : 'Free cancellation')
                : 'Cancellation fee: £${_cancelFee.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: textColor),
          ),
          Text(
            isFree
                ? 'Full refund to your GoOuts wallet'
                : hasFee
                    ? 'Restaurant has already started your order'
                    : '',
            style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8)),
          ),
        ])),
        const SizedBox(width: 10),
        _cancelling
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textColor))
            : GestureDetector(
                onTap: _cancelOrder,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFree ? const Color(0xFF16A34A) : _red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Cancel',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
      ]),
    );
  }

  // ── Cancelled card ─────────────────────────────────────────────────────────
  Widget _buildCancelledCard(String status) {
    final isRejected = status == 'rejected';
    final reason = _order?['rejectReason'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _red.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 32),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRejected ? 'Order Rejected' : 'Order Cancelled',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _red),
            ),
            if (reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Reason: $reason',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey[600])),
              ),
          ],
        )),
      ]),
    );
  }

  // ── Add to Order card ──────────────────────────────────────────────────────
  Widget _buildAddToOrderCard() {
    final rem = _addWindowRemaining!;

    return GestureDetector(
      onTap: _openAddToOrderSheet,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_amber, const Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: _amber.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(children: [
          const Icon(Icons.add_shopping_cart_rounded,
              color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add More Items',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                Text('Forgot something? Add it now.',
                    style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_countdown(rem),
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      fontFeatures: [const FontFeature.tabularFigures()])),
              Text('remaining',
                  style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10)),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Open add-to-order bottom sheet ─────────────────────────────────────────
  Future<void> _openAddToOrderSheet() async {
    await _loadMenu();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) {
          final pickerTotal = _pickerQty.entries
              .where((e) => e.value > 0)
              .fold<double>(0, (sum, e) {
            final item = _menuItems.firstWhere((i) => i.id == e.key,
                orElse: () => _PickerItem(id: '', name: '', price: 0, imageUrl: ''));
            return sum + item.price * e.value;
          });
          final hasItems = _pickerQty.values.any((q) => q > 0);

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add More Items',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: _navy)),
                          Text('Select items to add to your order',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_rounded,
                              size: 14, color: _amber),
                          const SizedBox(width: 4),
                          Text(
                            _addWindowRemaining != null
                                ? _countdown(_addWindowRemaining!)
                                : '--:--',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _amber),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Menu content
              Expanded(
                child: _menuLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFEA580C)))
                    : _menuItems.isEmpty
                        ? Center(
                            child: Text('Menu not available',
                                style: GoogleFonts.inter(
                                    color: Colors.grey[400])))
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              // ── Suggested for you ───────────────────────
                              if (_suggestedItems.isNotEmpty) ...[
                                Container(
                                  color: const Color(0xFFFFF7ED),
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 12, 16, 8),
                                  child: Row(children: [
                                    const Text('✨',
                                        style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Suggested for you',
                                        style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: const Color(0xFF92400E)),
                                      ),
                                    ),
                                    Text('Based on your order',
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: const Color(0xFFF59E0B))),
                                  ]),
                                ),
                                SizedBox(
                                  height: 140,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 12),
                                    itemCount: _suggestedItems.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (_, i) {
                                      final item = _suggestedItems[i];
                                      final qty =
                                          _pickerQty[item.id] ?? 0;
                                      return _buildSuggestionCard(
                                          item, qty, ss);
                                    },
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 10, 16, 4),
                                  child: Text('Full Menu',
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: Colors.grey[500])),
                                ),
                              ],
                              // ── Full menu list ──────────────────────────
                              ..._menuItems.asMap().entries.map((entry) {
                                final item = entry.value;
                                final isLast =
                                    entry.key == _menuItems.length - 1;
                                final qty = _pickerQty[item.id] ?? 0;
                                return Column(children: [
                                  ListTile(
                                    leading: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      child: item.imageUrl.isEmpty
                                          ? Container(
                                              width: 52, height: 52,
                                              color: const Color(0xFFF3F4F6),
                                              child: const Icon(
                                                  Icons.fastfood_rounded,
                                                  color: Color(0xFFD1D5DB)))
                                          : Image.network(
                                              item.imageUrl,
                                              width: 52, height: 52,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                      width: 52, height: 52,
                                                      color: const Color(
                                                          0xFFF3F4F6),
                                                      child: const Icon(
                                                          Icons
                                                              .fastfood_rounded,
                                                          color: Color(
                                                              0xFFD1D5DB)))),
                                    ),
                                    title: Row(children: [
                                      Expanded(
                                        child: Text(item.name,
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: _navy)),
                                      ),
                                      if (item.isRecommended)
                                        Container(
                                          margin: const EdgeInsets.only(
                                              left: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: _primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: Text('Pick',
                                              style: GoogleFonts.inter(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: _primary)),
                                        ),
                                    ]),
                                    subtitle: Text(_fmt(item.price),
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: _primary,
                                            fontWeight: FontWeight.w600)),
                                    trailing: qty == 0
                                        ? GestureDetector(
                                            onTap: () => ss(() =>
                                                _pickerQty[item.id] = 1),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 7),
                                              decoration: BoxDecoration(
                                                color: _primary,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text('Add',
                                                  style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13)),
                                            ),
                                          )
                                        : _qtyControls(item.id, qty, ss),
                                  ),
                                  if (!isLast)
                                    const Divider(height: 1, indent: 20),
                                ]);
                              }),
                            ],
                          ),
              ),

              // Footer — send button
              if (hasItems)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _sendAdditionRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Send Request  •  ${_fmt(pickerTotal)}',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }

  Widget _qtyControls(String itemId, int qty, StateSetter ss) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _circleBtn(Icons.remove, () => ss(() {
            if (qty > 1) {
              _pickerQty[itemId] = qty - 1;
            } else {
              _pickerQty.remove(itemId);
            }
          })),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('$qty',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _navy)),
      ),
      _circleBtn(Icons.add, () => ss(() => _pickerQty[itemId] = qty + 1)),
    ]);
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: _primary.withOpacity(0.4)),
        ),
        child: Icon(icon, size: 16, color: _primary),
      ),
    );
  }

  // ── Suggestion card (horizontal scroll inside bottom sheet) ──────────────
  Widget _buildSuggestionCard(_PickerItem item, int qty, StateSetter ss) {
    return GestureDetector(
      onTap: () => ss(() => _pickerQty[item.id] = (qty == 0 ? 1 : qty + 1)),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: qty > 0
                  ? _primary.withOpacity(0.5)
                  : const Color(0xFFE5E7EB),
              width: qty > 0 ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: item.imageUrl.isEmpty
                  ? Container(
                      height: 70,
                      color: const Color(0xFFF3F4F6),
                      child: const Center(
                          child: Icon(Icons.fastfood_rounded,
                              color: Color(0xFFD1D5DB), size: 28)))
                  : Image.network(
                      item.imageUrl,
                      height: 70,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          height: 70,
                          color: const Color(0xFFF3F4F6),
                          child: const Center(
                              child: Icon(Icons.fastfood_rounded,
                                  color: Color(0xFFD1D5DB), size: 28)))),
            ),
            // Name + price
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('£${item.price.toStringAsFixed(2)}',
                      style: GoogleFonts.inter(
                          color: _primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                  if (qty > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('×$qty added',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 9)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Addition card ──────────────────────────────────────────────────────────
  Widget _buildAdditionCard(Map<String, dynamic> addition) {
    final items = List<Map<String, dynamic>>.from(addition['items'] ?? []);
    final status = addition['status'] as String? ?? 'pending';
    final Color statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Add to Order Request',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: _navy)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(),
                    style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.w700, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${item['name']} ×${item['quantity']}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
                    Text('£${((item['subtotal'] ?? 0) as num).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Order summary card ─────────────────────────────────────────────────────
  Widget _buildOrderSummary(Map<String, dynamic> order, List<Map<String, dynamic>> items) {
    final subtotal = (order['subtotal'] ?? order['totalAmount'] ?? 0) as num;
    final deliveryFee = (order['deliveryFee'] ?? 0) as num;
    final total = (order['totalAmount'] ?? subtotal + deliveryFee) as num;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: _navy)),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${item['name']} ×${item['quantity']}',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700])),
                    ),
                    Text('£${((item['subtotal'] ?? (item['price'] ?? 0) * (item['quantity'] ?? 1)) as num).toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                  ],
                ),
              )),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery fee', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
              Text('£${deliveryFee.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _navy)),
              Text('£${total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: _primary)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Delivery info card ─────────────────────────────────────────────────────
  Widget _buildDeliveryInfo(Map<String, dynamic> order) {
    final address = order['deliveryAddress'] as String? ?? order['address'] as String? ?? 'N/A';
    final instructions = order['deliveryInstructions'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Details',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: _navy)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_rounded, color: _primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(address,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700])),
              ),
            ],
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey[500], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(instructions,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _PickerItem {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String categoryId;
  final bool isRecommended;
  final bool isPopular;
  final int orderCount;

  const _PickerItem({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.categoryId = '',
    this.isRecommended = false,
    this.isPopular = false,
    this.orderCount = 0,
  });
}
