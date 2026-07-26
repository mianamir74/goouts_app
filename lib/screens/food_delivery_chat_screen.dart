import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FoodDeliveryChatScreen — Customer ↔ Driver in-app chat
//
//  Route:  /food-delivery-chat
//  Args:   orderId (String), driverName (String), orderStatus (String),
//          deliveredAt (Timestamp?)
//
//  Window: Customer can send messages while driver is heading/picked up, and
//          for 30 min after delivery. After that the input is locked (read-only).
// ─────────────────────────────────────────────────────────────────────────────
class FoodDeliveryChatScreen extends StatefulWidget {
  const FoodDeliveryChatScreen({super.key});

  @override
  State<FoodDeliveryChatScreen> createState() => _FoodDeliveryChatScreenState();
}

class _FoodDeliveryChatScreenState extends State<FoodDeliveryChatScreen> {
  static const Color _primary = Color(0xFFEA580C);
  static const Color _navy    = Color(0xFF0D1B3E);
  static const Color _bg      = Color(0xFFF2F4F7);

  // Args
  late String _orderId;
  late String _driverName;
  bool _argsInit = false;

  // State
  final _db       = FirebaseFirestore.instance;
  final _auth     = FirebaseAuth.instance;
  final _msgCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending   = false;
  bool _chatOpen  = false;  // whether the send window is open

  // Live order sub for status + deliveredAt
  StreamSubscription? _orderSub;
  String   _orderStatus  = '';
  DateTime? _deliveredAt;

  Timer? _lockTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsInit) return;
    _argsInit = true;
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>? ?? {};
    _orderId    = (args['orderId']    as String?) ?? '';
    _driverName = (args['driverName'] as String?) ?? 'Driver';
    _subscribeToOrder();
  }

  void _subscribeToOrder() {
    _orderSub = _db.collection('food_orders').doc(_orderId).snapshots().listen((snap) {
      if (!mounted || !snap.exists) return;
      final data        = snap.data()!;
      final status      = data['status'] as String? ?? '';
      final deliveredAt = (data['deliveredAt'] as Timestamp?)?.toDate();
      setState(() {
        _orderStatus = status;
        _deliveredAt = deliveredAt;
        _chatOpen    = _computeChatOpen(status, deliveredAt);
      });
      _scheduleLockIfNeeded(deliveredAt);
    });
  }

  bool _computeChatOpen(String status, DateTime? deliveredAt) {
    const activeStatuses = ['driver_heading_to_restaurant', 'driver_picked_up'];
    if (activeStatuses.contains(status)) return true;
    if (status == 'delivered' && deliveredAt != null) {
      return DateTime.now().isBefore(deliveredAt.add(const Duration(minutes: 30)));
    }
    return false;
  }

  void _scheduleLockIfNeeded(DateTime? deliveredAt) {
    _lockTimer?.cancel();
    if (_orderStatus == 'delivered' && deliveredAt != null) {
      final lockAt = deliveredAt.add(const Duration(minutes: 30));
      final rem    = lockAt.difference(DateTime.now());
      if (rem > Duration.zero) {
        _lockTimer = Timer(rem, () {
          if (mounted) setState(() => _chatOpen = false);
        });
      }
    }
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _lockTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || !_chatOpen || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      final uid = _auth.currentUser?.uid ?? '';
      await _db
          .collection('order_chats').doc(_orderId)
          .collection('messages').add({
        'senderId'  : uid,
        'senderRole': 'customer',
        'text'      : text,
        'sentAt'    : FieldValue.serverTimestamp(),
        'read'      : false,
      });
      // Ensure chat doc exists
      await _db.collection('order_chats').doc(_orderId).set({
        'orderId'  : _orderId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Color(0xFF0D1B3E)),
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primary.withValues(alpha: 0.15),
            child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFEA580C), size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_driverName,
                style: GoogleFonts.inter(color: _navy, fontWeight: FontWeight.w700, fontSize: 15)),
            Text(
              _chatOpen ? 'Online — chat open' : 'Chat closed',
              style: GoogleFonts.inter(
                  color: _chatOpen ? Colors.green : Colors.grey,
                  fontSize: 11),
            ),
          ]),
        ]),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('order_chats').doc(_orderId)
                  .collection('messages')
                  .orderBy('sentAt')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.black12),
                      const SizedBox(height: 12),
                      Text('No messages yet',
                          style: GoogleFonts.inter(color: Colors.black38, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Chat with your driver here.',
                          style: GoogleFonts.inter(color: Colors.black26, fontSize: 12)),
                    ]),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final d    = docs[i].data() as Map<String, dynamic>;
                    final isMe = (d['senderId'] as String?) == myUid;
                    final text = d['text'] as String? ?? '';
                    final ts   = (d['sentAt'] as Timestamp?)?.toDate();
                    return _bubble(text, isMe, ts);
                  },
                );
              },
            ),
          ),

          // Lock banner
          if (!_chatOpen) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.black.withValues(alpha: 0.04),
              child: Text(
                _orderStatus == 'delivered'
                    ? 'Chat closed — 30 min window has passed'
                    : 'Chat is available once the driver is on the way',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.black38, fontSize: 12),
              ),
            ),
          ],

          // Input bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
                left: 12, right: 12, top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  enabled: _chatOpen,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _chatOpen ? 'Message your driver…' : 'Chat closed',
                    hintStyle: const TextStyle(color: Colors.black26),
                    filled: true,
                    fillColor: const Color(0xFFF2F4F7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              _sending
                  ? const SizedBox(width: 44, height: 44,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : GestureDetector(
                      onTap: _chatOpen ? _send : null,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _chatOpen ? _primary : Colors.black12,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool isMe, DateTime? ts) {
    final timeStr = ts != null
        ? '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}'
        : '';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? _primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(18),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0,2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text, style: TextStyle(
              color: isMe ? Colors.white : _navy, fontSize: 14, height: 1.4)),
          const SizedBox(height: 3),
          Text(timeStr, style: TextStyle(
              fontSize: 10,
              color: isMe ? Colors.white60 : Colors.black26)),
        ]),
      ),
    );
  }
}
