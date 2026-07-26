import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FoodOrderHistoryScreen extends StatefulWidget {
  const FoodOrderHistoryScreen({super.key});

  @override
  State<FoodOrderHistoryScreen> createState() => _FoodOrderHistoryScreenState();
}

class _FoodOrderHistoryScreenState extends State<FoodOrderHistoryScreen> {
  static const Color _primary = Color(0xFFEA580C);
  static const Color _navy    = Color(0xFF0D1B3E);
  static const Color _green   = Color(0xFF10B981);
  static const Color _red     = Color(0xFFEF4444);
  static const Color _amber   = Color(0xFFF59E0B);
  static const Color _blue    = Color(0xFF0392CA);

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  List<Map<String, dynamic>> _orders = [];
  String _filter = 'all'; // all | active | completed | cancelled | refund_pending

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final uid = _auth.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    final snap = await _db
        .collection('food_orders')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    final list = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['_id'] = d.id;
      final ts = data['createdAt'];
      data['_date'] = ts is Timestamp ? ts.toDate() : null;
      return data;
    }).toList();
    if (mounted) setState(() { _orders = list; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'active':
        return _orders.where((o) => _isActive(o['status'] as String? ?? '')).toList();
      case 'completed':
        return _orders.where((o) => (o['status'] as String? ?? '') == 'delivered').toList();
      case 'cancelled':
        return _orders.where((o) => (_statusGroup(o['status'] as String? ?? '')) == 'cancelled').toList();
      case 'refund_pending':
        return _orders.where((o) => o['refundStatus'] == 'pending_bank_refund').toList();
      default:
        return _orders;
    }
  }

  bool _isActive(String s) => ['pending','accepted','preparing','ready',
      'driver_heading_to_restaurant','driver_picked_up'].contains(s);

  String _statusGroup(String s) {
    if (_isActive(s)) return 'active';
    if (s == 'delivered') return 'completed';
    if (s.startsWith('cancelled')) return 'cancelled';
    return 'other';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pendingBankCount = _orders.where((o) => o['refundStatus'] == 'pending_bank_refund').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: _navy),
        title: Text('Order History',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: _primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _navy),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : Column(children: [
              // Filter chips
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip('all',            'All (${_orders.length})'),
                    _chip('active',         'Active'),
                    _chip('completed',      'Completed'),
                    _chip('cancelled',      'Cancelled'),
                    if (pendingBankCount > 0)
                      _chip('refund_pending', 'Card Refund Pending ($pendingBankCount)', color: _blue),
                  ]),
                ),
              ),
              // Summary stats
              if (_filter == 'all' && _orders.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
                    _statCard('Total Orders', '${_orders.length}', _primary),
                    const SizedBox(width: 10),
                    _statCard('Completed', '${_orders.where((o) => o['status'] == 'delivered').length}', _green),
                    const SizedBox(width: 10),
                    _statCard('Cancelled', '${_orders.where((o) => (_statusGroup(o['status'] as String? ?? '')) == 'cancelled').length}', _red),
                  ]),
                ),
              const SizedBox(height: 10),
              // Orders list
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.receipt_long_rounded, size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No orders here yet.',
                            style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[400])),
                      ]))
                    : RefreshIndicator(
                        color: _primary,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _orderCard(filtered[i]),
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _chip(String value, String label, {Color? color}) {
    final active = _filter == value;
    final c = color ?? _primary;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? c : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : Colors.grey[600])),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
      ]),
    ),
  );

  Widget _orderCard(Map<String, dynamic> order) {
    final orderId     = order['_id'] as String;
    final restaurant  = order['restaurantName'] as String? ?? 'Restaurant';
    final status      = order['status'] as String? ?? 'pending';
    final date        = order['_date'] as DateTime?;
    final total       = (order['grandTotal'] as num?)?.toDouble() ?? (order['total'] as num?)?.toDouble() ?? 0.0;
    final items       = order['items'] as List? ?? [];
    final refundMethod      = order['refundMethod'] as String?;
    final refundStatus      = order['refundStatus'] as String?;
    final cashbackClawback  = (order['cashbackClawback'] as num?)?.toDouble() ?? 0.0;
    final netRefundAmount   = (order['netRefundAmount'] as num?)?.toDouble();
    final refundToCustomer  = (order['refundToCustomer'] as num?)?.toDouble();
    final socialBoost       = order['socialBoostApplied'] as bool? ?? false;
    final cashbackEarned    = (order['cashbackEarned'] as num?)?.toDouble() ?? 0.0;
    final cancellationFee   = (order['cancellationFee'] as num?)?.toDouble() ?? 0.0;
    final refundHistory     = order['refundHistory'] as List? ?? [];

    final statusInfo = _statusInfo(status, refundStatus);
    final isRefundPending = refundStatus == 'pending_bank_refund';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/food-order-tracking',
          arguments: {'orderId': orderId}),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isRefundPending
              ? Border.all(color: _blue.withValues(alpha: 0.4), width: 1.5)
              : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delivery_dining_rounded, color: _primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(restaurant, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
                Text(
                  date != null ? _formatDate(date) : '—',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                ),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('£${total.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
                const SizedBox(height: 4),
                _statusBadge(statusInfo),
              ]),
            ]),
          ),

          Divider(height: 1, color: Colors.grey[100]),

          // Items summary
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Text(
              items.isEmpty ? 'No item details' :
              items.take(3).map((i) {
                final m = i as Map;
                return '${m['qty'] ?? 1}× ${m['name'] ?? ''}';
              }).join(', ') + (items.length > 3 ? ' +${items.length - 3} more' : ''),
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
            ),
          ),

          // Offers / social boost
          if (socialBoost) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _infoBadge(Icons.local_offer_rounded, _primary, 'Social Boost applied'),
            ),
          ],
          if (cashbackEarned > 0) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _infoBadge(Icons.account_balance_wallet_rounded, _green,
                  'Cashback earned: £${cashbackEarned.toStringAsFixed(2)}'),
            ),
          ],

          // Refund details section
          if (refundHistory.isNotEmpty || refundToCustomer != null) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey[100]),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('REFUND DETAILS', style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Colors.grey[400], letterSpacing: 0.8)),
                const SizedBox(height: 8),
                if (cancellationFee > 0)
                  _refundRow('Cancellation fee', '-£${cancellationFee.toStringAsFixed(2)}', _red),
                if (cashbackClawback > 0)
                  _refundRow('Cashback adjustment', '-£${cashbackClawback.toStringAsFixed(2)}', _amber),
                if (netRefundAmount != null)
                  _refundRow('Net refund', '£${netRefundAmount.toStringAsFixed(2)}', _green, bold: true),
                if (refundMethod != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(
                      refundMethod == 'wallet' ? Icons.account_balance_wallet_rounded : Icons.credit_card_rounded,
                      size: 14, color: refundMethod == 'wallet' ? _green : _blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      refundMethod == 'wallet'
                          ? 'Refunded to GoOuts Wallet'
                          : 'Refund to original payment method',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600,
                          color: refundMethod == 'wallet' ? _green : _blue),
                    ),
                  ]),
                ],
                if (isRefundPending) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _blue.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.hourglass_bottom_rounded, size: 14, color: _blue),
                      const SizedBox(width: 6),
                      Expanded(child: Text(
                        'Card refund in progress · 3–5 business days',
                        style: GoogleFonts.inter(fontSize: 11, color: _blue),
                      )),
                    ]),
                  ),
                ],
              ]),
            ),
          ],

          // Order ID + tap hint
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(children: [
              Text('#${orderId.substring(0, 8).toUpperCase()}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400], letterSpacing: 0.6)),
              const Spacer(),
              Text('View details',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _primary)),
              const Icon(Icons.chevron_right_rounded, size: 16, color: _primary),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _statusBadge(Map<String, dynamic> info) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: (info['color'] as Color).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(info['label'] as String,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
            color: info['color'] as Color)),
  );

  Widget _infoBadge(IconData icon, Color color, String text) => Row(children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 5),
    Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  ]);

  Widget _refundRow(String label, String value, Color color, {bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
      const Spacer(),
      Text(value, style: GoogleFonts.inter(fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color)),
    ]),
  );

  Map<String, dynamic> _statusInfo(String status, String? refundStatus) {
    if (refundStatus == 'pending_bank_refund') {
      return {'label': 'REFUND PENDING', 'color': _blue};
    }
    switch (status) {
      case 'pending':                      return {'label': 'PENDING',    'color': _amber};
      case 'accepted':                     return {'label': 'ACCEPTED',   'color': _primary};
      case 'preparing':                    return {'label': 'PREPARING',  'color': _primary};
      case 'ready':                        return {'label': 'READY',      'color': _primary};
      case 'driver_heading_to_restaurant': return {'label': 'DRIVER ON WAY', 'color': _primary};
      case 'driver_picked_up':             return {'label': 'ON THE WAY', 'color': _primary};
      case 'delivered':                    return {'label': 'DELIVERED',  'color': _green};
      case 'cancelled':                    return {'label': 'CANCELLED',  'color': _red};
      case 'cancelled_with_fee':           return {'label': 'CANCELLED',  'color': _red};
      case 'refunded':                     return {'label': 'REFUNDED',   'color': _green};
      case 'rejected':                     return {'label': 'REJECTED',   'color': _red};
      default:                             return {'label': status.toUpperCase(), 'color': Colors.grey};
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today ${_timeStr(dt)}';
    if (diff.inDays == 1) return 'Yesterday ${_timeStr(dt)}';
    return '${dt.day}/${dt.month}/${dt.year} ${_timeStr(dt)}';
  }

  String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
