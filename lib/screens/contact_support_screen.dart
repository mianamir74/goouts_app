import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/support_ticket_service.dart';
import '../services/self_service_service.dart';
import '../widgets/goouts_sheet.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _teal = Color(0xFF0A6E8A);

  final _service = SupportTicketService();
  final _selfService = SelfServiceService();

  // ── Topics ────────────────────────────────────────────────────────────────
  final List<Map<String, String>> _topics = [
    {'label': '— Select a Topic —', 'value': ''},
    {'label': 'Transaction Issue',  'value': 'transaction_issue'},
    {'label': 'Account Security',   'value': 'account_security'},
    {'label': 'Cashback Query',     'value': 'cashback_query'},
    {'label': 'Card Problem',       'value': 'card_problem'},
    {'label': 'KYC / Verification', 'value': 'kyc_verification'},
    {'label': 'Food Delivery',      'value': 'food_delivery'},
    {'label': 'Other',              'value': 'other'},
  ];

  // ── Sub-topics ────────────────────────────────────────────────────────────
  final Map<String, List<Map<String, String>>> _subTopics = {
    'transaction_issue': [
      {'label': 'Payment Failed',        'icon': 'error',      'desc': 'My payment did not go through'},
      {'label': 'Charged Twice',         'icon': 'repeat',     'desc': 'I was charged more than once'},
      {'label': 'Unauthorized Charge',   'icon': 'block',      'desc': 'I did not make this transaction'},
      {'label': 'Wrong Amount Charged',  'icon': 'money_off',  'desc': 'I was charged the wrong amount'},
      {'label': 'Transaction Pending',   'icon': 'hourglass',  'desc': 'My transaction is stuck as pending'},
      {'label': 'Cashback Not Credited', 'icon': 'wallet',     'desc': 'Expected cashback has not appeared'},
      {'label': 'Other Transaction',     'icon': 'help',       'desc': 'Something else with my transaction'},
    ],
    'account_security': [
      {'label': 'Suspicious Login',        'icon': 'warning',    'desc': 'Someone may have accessed my account'},
      {'label': 'Account Locked / Frozen', 'icon': 'lock',       'desc': 'I cannot access my account'},
      {'label': 'Change Password / PIN',   'icon': 'key',        'desc': 'I need to reset my PIN or password'},
      {'label': '2FA Issue',               'icon': 'shield',     'desc': 'Two-factor authentication not working'},
      {'label': 'Phishing / Scam Report',  'icon': 'phishing',   'desc': 'I received a suspicious message or call'},
      {'label': 'Lost or Stolen Device',   'icon': 'device_off', 'desc': 'My phone with the app was lost or stolen'},
      {'label': 'Other Security Issue',    'icon': 'help',       'desc': 'Another account security concern'},
    ],
    'cashback_query': [
      {'label': 'Cashback Not Received',   'icon': 'wallet',     'desc': 'My cashback has not appeared in wallet'},
      {'label': 'Wrong Cashback Amount',   'icon': 'money_off',  'desc': 'The amount credited is incorrect'},
      {'label': 'Cashback Still Pending',  'icon': 'hourglass',  'desc': 'Cashback showing pending for too long'},
      {'label': 'Partner Not Showing',     'icon': 'store',      'desc': 'A merchant is not giving cashback'},
      {'label': 'Cashback Expiring',       'icon': 'timer',      'desc': 'My cashback is about to expire'},
      {'label': 'How to Redeem Cashback',  'icon': 'redeem',     'desc': 'I need help withdrawing my cashback'},
      {'label': 'Other Cashback Question', 'icon': 'help',       'desc': 'Something else about my cashback'},
    ],
    'card_problem': [
      {'label': 'Card Declined',      'icon': 'block',       'desc': 'My virtual card was refused at checkout'},
      {'label': 'Freeze / Unfreeze',  'icon': 'ac_unit',     'desc': 'I want to lock or unlock my card'},
      {'label': 'Virtual Card Issue', 'icon': 'credit_card', 'desc': 'Problem with my virtual card online'},
      {'label': 'PIN Forgotten',      'icon': 'key',         'desc': 'I have forgotten my card PIN'},
      {'label': 'Other Card Issue',   'icon': 'help',        'desc': 'Another issue with my card'},
    ],
    'kyc_verification': [
      {'label': 'Document Rejected',        'icon': 'cancel_doc', 'desc': 'My ID document was not accepted'},
      {'label': 'Verification Taking Long', 'icon': 'hourglass',  'desc': 'My verification is taking too long'},
      {'label': 'Selfie Not Accepted',      'icon': 'face',       'desc': 'My selfie photo was rejected'},
      {'label': 'Address Proof Rejected',   'icon': 'home',       'desc': 'My proof of address was not accepted'},
      {'label': 'Account Restricted',       'icon': 'lock',       'desc': 'My account is restricted pending KYC'},
      {'label': 'Re-submit Documents',      'icon': 'upload',     'desc': 'I need to upload my documents again'},
      {'label': 'Other Verification Issue', 'icon': 'help',       'desc': 'Another question about verification'},
    ],
    'food_delivery': [
      {'label': 'Order Late / Not Arrived',      'icon': 'hourglass',  'desc': 'My food order has not arrived yet'},
      {'label': 'Wrong Items Delivered',         'icon': 'error',      'desc': 'I received the incorrect items'},
      {'label': 'Missing Items',                 'icon': 'help',       'desc': 'Some items were missing from my order'},
      {'label': 'Driver Issue',                  'icon': 'warning',    'desc': 'I had a problem with the delivery driver'},
      {'label': 'Order Cancelled by Restaurant', 'icon': 'block',      'desc': 'The restaurant cancelled my order'},
      {'label': 'Refund Not Received',           'icon': 'wallet',     'desc': 'Expected refund not appearing in my wallet'},
      {'label': 'Other Food Delivery Issue',     'icon': 'help',       'desc': 'Something else about my food delivery'},
    ],
  };

  // ── Icon map ──────────────────────────────────────────────────────────────
  static const Map<String, IconData> _iconMap = {
    'error':       Icons.error_outline_rounded,
    'repeat':      Icons.repeat_rounded,
    'block':       Icons.block_rounded,
    'undo':        Icons.undo_rounded,
    'money_off':   Icons.money_off_rounded,
    'hourglass':   Icons.hourglass_bottom_rounded,
    'wallet':      Icons.account_balance_wallet_rounded,
    'help':        Icons.help_outline_rounded,
    'warning':     Icons.warning_amber_rounded,
    'lock':        Icons.lock_outline_rounded,
    'key':         Icons.key_rounded,
    'shield':      Icons.shield_outlined,
    'phishing':    Icons.phishing_rounded,
    'device_off':  Icons.no_cell_rounded,
    'store':       Icons.store_rounded,
    'timer':       Icons.timer_outlined,
    'redeem':      Icons.redeem_rounded,
    'local_post':  Icons.local_post_office_rounded,
    'report':      Icons.report_problem_rounded,
    'broken':      Icons.credit_card_off_rounded,
    'ac_unit':     Icons.ac_unit_rounded,
    'credit_card': Icons.credit_card_rounded,
    'cancel_doc':  Icons.cancel_presentation_rounded,
    'face':        Icons.face_rounded,
    'home':        Icons.home_outlined,
    'upload':      Icons.upload_rounded,
    'delivery':    Icons.delivery_dining_rounded,
  };

  // ── State ─────────────────────────────────────────────────────────────────
  String _selectedTopicValue = '';
  String _selectedTopicLabel = '— Select a Topic —';
  String? _selectedSubTopic;
  Map<String, dynamic>? _selectedCashbackTxn;
  Map<String, dynamic>? _selectedSupportTxn; // for transaction/card/security topics

  // Stores the self-service data fetched — passed as context snapshot to ticket
  Map<String, dynamic> _lastSelfServiceData = {};

  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitting = false;
  bool _loadingCheck = false;
  String? _errorMsg;

  // Pre-filled from route args (food delivery deep-link)
  String? _prefilledOrderId;
  bool _argsInitDone = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitDone) {
      _argsInitDone = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final orderId = args['orderId'] as String?;
        if (orderId != null && orderId.isNotEmpty) {
          setState(() {
            _prefilledOrderId = orderId;
            _selectedTopicValue = 'food_delivery';
            _selectedTopicLabel = 'Food Delivery';
          });
        }
      }
    }
  }

  // ── Self-service check ────────────────────────────────────────────────────
  Future<void> _checkBeforeSubmit() async {
    if (_selectedTopicValue.isEmpty) {
      setState(() => _errorMsg = 'Please select a topic.');
      return;
    }
    if (_subTopics.containsKey(_selectedTopicValue) && _selectedSubTopic == null) {
      setState(() => _errorMsg = 'Please select a related issue type.');
      return;
    }

    setState(() { _loadingCheck = true; _errorMsg = null; });
    final data = await _selfService.fetchForTopic(_selectedTopicValue);
    if (!mounted) return;
    setState(() {
      _loadingCheck = false;
      _selectedCashbackTxn = null;
      _selectedSupportTxn = null;
      _lastSelfServiceData = data; // store for context snapshot
    });
    _showSelfServiceSheet(data);
  }

  // ── Submit ticket ─────────────────────────────────────────────────────────
  Future<void> _submit({String message = ''}) async {
    setState(() { _submitting = true; _errorMsg = null; });

    // Build a clean context snapshot for admin — strip out non-serialisable objects
    final Map<String, dynamic> snapshot = {};
    if (_lastSelfServiceData.isNotEmpty) {
      // Wallet balance
      if (_lastSelfServiceData['walletBalance'] != null)
        snapshot['walletBalance'] = _lastSelfServiceData['walletBalance'];
      // KYC status
      if (_lastSelfServiceData['kycStatus'] != null)
        snapshot['kycStatus'] = _lastSelfServiceData['kycStatus'];
      if (_lastSelfServiceData['kycLabel'] != null)
        snapshot['kycLabel'] = _lastSelfServiceData['kycLabel'];
      // Card status
      if (_lastSelfServiceData['cardStatus'] != null)
        snapshot['cardStatus'] = _lastSelfServiceData['cardStatus'];
      // Recent transactions (last 3, id + title + amount + date + status)
      final txns = (_lastSelfServiceData['transactions'] ??
                    _lastSelfServiceData['spendingTransactions'] ?? []) as List;
      if (txns.isNotEmpty) {
        snapshot['recentTransactions'] = txns.take(3).map((t) => {
          'id':     t['id']     ?? '',
          'title':  t['title']  ?? '',
          'amount': t['amount'] ?? '',
          'date':   t['date']   ?? '',
          'status': t['status'] ?? '',
        }).toList();
      }
      // Selected transaction (if user tapped one in the self-service view)
      final selTxn = _selectedCashbackTxn ?? _selectedSupportTxn;
      if (selTxn != null) {
        snapshot['selectedTransaction'] = {
          'id':     selTxn['id']     ?? '',
          'title':  selTxn['title']  ?? '',
          'amount': selTxn['amount'] ?? '',
          'date':   selTxn['date']   ?? '',
          'status': selTxn['status'] ?? '',
        };
      }
    }

    try {
      final result = await _service.submitTicket(
        category: _selectedTopicValue,
        categoryLabel: _selectedTopicLabel,
        subject: _selectedSubTopic ?? _selectedTopicLabel,
        message: message,
        subTopic: _selectedSubTopic ?? '',
        selfServiceAttempted: _lastSelfServiceData.isNotEmpty,
        contextSnapshot: snapshot,
        linkedTransactionId: (_selectedCashbackTxn ?? _selectedSupportTxn)?['id'] as String?,
      );
      if (!mounted) return;
      _showSuccess(
        ticketId:     result['ticketId']     ?? '',
        ticketNumber: result['ticketNumber'] ?? '',
        subject:      _selectedSubTopic ?? _selectedTopicLabel,
        userName:     result['fullName']     ?? '',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMsg = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  void _showSuccess({
    required String ticketId,
    required String ticketNumber,
    required String subject,
    required String userName,
  }) {
    setState(() => _submitting = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF388E3C), size: 36),
            ),
            const SizedBox(height: 16),
            Text('Ticket Submitted!',
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _dark)),
            const SizedBox(height: 8),
            Text(
              'Your ticket $ticketNumber has been received.\nWe\'ll get back to you within 2 hours.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  Navigator.pushNamed(
                    context,
                    '/support-ticket-chat',
                    arguments: {
                      'ticketId':     ticketId,
                      'ticketNumber': ticketNumber,
                      'subject':      subject,
                      'userName':     userName,
                    },
                  );
                },
                icon: const Icon(Icons.chat_rounded,
                    color: Colors.white, size: 18),
                label: Text('Open My Ticket',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('Back to Help',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey[500])),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    _subjectCtrl.clear();
    _messageCtrl.clear();
    setState(() {
      _selectedTopicValue = '';
      _selectedTopicLabel = '— Select a Topic —';
      _selectedSubTopic = null;
      _selectedCashbackTxn = null;
    });
  }

  // ── Self-service sheet ────────────────────────────────────────────────────
  void _showSelfServiceSheet(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx2, scroll) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD6EEF8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.search_rounded,
                            color: _primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('We found this for you',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _dark)),
                            Text('Check if this resolves your issue',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 24, color: Colors.grey[100]),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      _buildSelfServiceContent(data, setSheet),
                      const SizedBox(height: 24),

                      // Resolved button
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            GoOutsSheet.success(context,
                              title: 'All Good!',
                              message: 'Great! Glad we could help.',
                            );
                          },
                          icon: const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 18),
                          label: Text('This solved my issue',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF388E3C),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Escalate button
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showEscalationSheet();
                          },
                          icon: Icon(Icons.send_rounded,
                              color: Colors.grey[600], size: 16),
                          label: Text('Still need help — Submit Ticket',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700])),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Escalation sheet — shown when AI cannot resolve ───────────────────────
  void _showEscalationSheet() {
    final msgCtrl = TextEditingController();
    // Pre-fill TXN reference if a transaction was selected
    final selTxn = _selectedCashbackTxn ?? _selectedSupportTxn;
    if (selTxn != null) {
      final txnId = selTxn['id'] as String? ?? '';
      if (txnId.length >= 8) {
        msgCtrl.text = 'Transaction reference: TXN-${txnId.substring(0, 8).toUpperCase()}\n\n';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 18),

                // Header
                Row(children: [
                  Container(width: 42, height: 42,
                    decoration: BoxDecoration(color: const Color(0xFFD6EEF8),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.support_agent_rounded,
                        color: _primary, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Submit a Ticket',
                          style: GoogleFonts.inter(fontSize: 17,
                              fontWeight: FontWeight.w800, color: _dark)),
                      Text('Our team will respond within 2 hours',
                          style: GoogleFonts.inter(fontSize: 12,
                              color: Colors.grey[500])),
                    ],
                  )),
                ]),
                const SizedBox(height: 16),

                // Topic + sub-topic summary (read-only)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryLine('Topic', _selectedTopicLabel),
                      if (_selectedSubTopic != null)
                        _summaryLine('Issue', _selectedSubTopic!),
                      if (selTxn != null &&
                          (selTxn['id'] as String? ?? '').length >= 8)
                        _summaryLine('Transaction',
                            'TXN-${(selTxn['id'] as String).substring(0, 8).toUpperCase()}'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Message box
                Text('Describe your issue',
                    style: GoogleFonts.inter(fontSize: 13,
                        fontWeight: FontWeight.w600, color: Colors.grey[600])),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: msgCtrl,
                    maxLines: 5,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Please describe your problem in detail...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    style: GoogleFonts.inter(fontSize: 14, color: _dark),
                  ),
                ),
                const SizedBox(height: 16),

                // Submit button
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            if (msgCtrl.text.trim().isEmpty) {
                              GoOutsSheet.warning(context,
                                title: 'Message Required',
                                message: 'Please describe your issue.',
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            _submit(message: msgCtrl.text.trim());
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Submit Ticket',
                        style: GoogleFonts.inter(fontSize: 15,
                            fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Text('$label: ', style: GoogleFonts.inter(fontSize: 12,
          fontWeight: FontWeight.w600, color: Colors.grey[500])),
      Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12,
          fontWeight: FontWeight.w600, color: _dark))),
    ]),
  );

  // ── Self-service content router ───────────────────────────────────────────
  Widget _buildSelfServiceContent(
      Map<String, dynamic> data, StateSetter setSheet) {
    final sub = _selectedSubTopic ?? '';
    switch (data['type'] as String? ?? '') {
      case 'transaction':    return _selfServiceTransaction(data, sub, setSheet);
      case 'cashback':       return _selfServiceCashback(data, setSheet, sub);
      case 'security':       return _selfServiceSecurity(data, sub, setSheet);
      case 'card':           return _selfServiceCard(data, sub, setSheet);
      case 'kyc':            return _selfServiceKyc(data);
      case 'food_delivery':  return _selfServiceFoodDelivery(sub);
      default:
        return _infoTile(Icons.info_outline_rounded, _primary,
            'Tip', 'Fill in the form and our team will assist you shortly.');
    }
  }

  // ── Transaction ───────────────────────────────────────────────────────────
  Widget _selfServiceTransaction(Map<String, dynamic> data, String sub, StateSetter setSheet) {
    final txns      = data['transactions']  as List? ?? [];
    final balance   = data['walletBalance'] as String? ?? 'N/A';
    final hasPending = data['hasPending']   as bool?   ?? false;

    // Sub-topic specific banners
    Widget? subBanner;

    if (sub == 'Payment Failed') {
      subBanner = _infoTile(
        Icons.error_outline_rounded, Colors.red,
        'Why payments fail',
        'Common reasons:\n'
        '• Your bank did not authorise the payment (contact your bank)\n'
        '• Insufficient funds in your linked bank account\n'
        '• Daily spending limit reached on your bank side\n'
        '• Card details changed — re-link your payment method in Settings\n\n'
        'Check your most recent transaction below for its status.',
      );
    } else if (sub == 'Charged Twice') {
      subBanner = Column(
        children: [
          _infoTile(
            Icons.repeat_rounded, Colors.orange,
            'Possible double charge detected',
            'If you see two identical transactions below, note both Transaction IDs. '
            'Our team will be notified immediately when you submit this ticket and '
            'will investigate and refund the duplicate within 24 hours.',
          ),
          const SizedBox(height: 6),
          _infoTile(
            Icons.info_outline_rounded, _primary,
            'Tip',
            'Banks sometimes show a pre-authorisation and a final charge separately. '
            'The pre-auth usually disappears within 3–5 business days.',
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTile(Icons.account_balance_wallet_rounded, _primary,
            'Current Balance', balance),
        if (subBanner != null) ...[
          const SizedBox(height: 10),
          subBanner,
        ],
        if (hasPending && sub != 'Payment Failed') ...[
          const SizedBox(height: 10),
          _infoTile(Icons.hourglass_bottom_rounded, Colors.orange,
              'Pending Transactions',
              'You have ${data['pendingCount']} pending transaction(s). These usually clear within 1–3 business days.'),
        ],
        const SizedBox(height: 16),
        Text('Recent Transactions',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
        const SizedBox(height: 8),
        if (txns.isEmpty)
          _infoTile(Icons.receipt_long_rounded, Colors.grey,
              'No transactions found', 'No recent transactions on this account.')
        else
          ...txns.map((t) {
            final tx = t as Map<String, dynamic>;
            final isSelected = _selectedSupportTxn?['id'] == tx['id'];
            return Column(
              children: [
                _txnRow(tx,
                  selected: isSelected,
                  onTap: () => setSheet(() => _selectedSupportTxn = tx),
                ),
                // If cashback not credited sub-topic and this txn selected → AI result
                if (isSelected && sub == 'Cashback Not Credited') ...[
                  const SizedBox(height: 4),
                  _txnCashbackCheck(tx),
                  const SizedBox(height: 8),
                ],
              ],
            );
          }),
      ],
    );
  }

  // AI cashback check for selected transaction — uses real Firestore partner check
  Widget _txnCashbackCheck(Map<String, dynamic> txn) {
    final isPending = (txn['status'] as String? ?? '').toLowerCase() == 'pending';
    final cashbackEarned = txn['cashbackEarned'];
    final rawTitle = txn['title'] as String? ?? '';
    final merchantName = SelfServiceService.extractMerchantName(rawTitle);
    final isSpendingTxn = txn['positive'] == false &&
        !rawTitle.startsWith('Wallet Used') &&
        !rawTitle.startsWith('Cashback Redeemed') &&
        !rawTitle.contains('— Cashback');

    // If user selected a sub-transaction (wallet used, cashback record etc.) — guide them
    if (!isSpendingTxn) {
      return _infoTile(Icons.info_outline_rounded, _primary,
          'Please select the main payment transaction',
          'You selected a "$rawTitle" record. For a cashback check, please select the main spending transaction for "$merchantName" — it shows the full bill amount (e.g. -£180.00).');
    }

    // If cashback IS on this transaction — already credited
    if (cashbackEarned != null) {
      final earned = cashbackEarned is num
          ? '+£${cashbackEarned.toStringAsFixed(2)}'
          : '$cashbackEarned';
      return _infoTile(Icons.check_circle_rounded, const Color(0xFF388E3C),
          'Cashback Credited: $earned',
          'Our records show cashback was credited instantly to your wallet for this transaction. Pull down to refresh your wallet balance to see it.');
    }

    // If pending — too early for cashback
    if (isPending) {
      return _infoTile(Icons.hourglass_bottom_rounded, Colors.orange,
          'Transaction Still Settling',
          'Cashback is applied once the payment fully settles — usually within 1–3 business days. Please check back shortly.');
    }

    // Check Firestore in real-time whether this merchant is a known partner
    return FutureBuilder<bool>(
      future: _selfService.isKnownPartner(merchantName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F6FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
              const SizedBox(width: 12),
              Text('Checking partner status...',
                  style: GoogleFonts.inter(fontSize: 13, color: _dark)),
            ]),
          );
        }

        final isConfirmedPartner = snapshot.data ?? false;

        if (isConfirmedPartner) {
          // Confirmed partner — cashback should have been applied
          return _infoTile(Icons.warning_amber_rounded, Colors.orange,
              'GoOuts Partner — Cashback Missing',
              'We can confirm "$merchantName" is a GoOuts partner venue. '
              'Cashback should have been applied to this transaction. '
              'This may be a processing delay — please wait 24 hours. '
              'If it still does not appear, tap "Still need help" and our team will investigate immediately.');
        }

        // Not confirmed as partner in user history — unknown
        return _infoTile(Icons.help_outline_rounded, Colors.grey[600]!,
            'Partner Status Unknown',
            'We could not confirm "$merchantName" as a GoOuts partner venue from your transaction history. '
            'If you believe this venue is a GoOuts partner, tap "Still need help" '
            'and include the venue name so our team can verify and apply your cashback.');
      },
    );
  }

  // ── Cashback ──────────────────────────────────────────────────────────────
  Widget _selfServiceCashback(
      Map<String, dynamic> data, StateSetter setSheet, String sub) {
    final balance = data['walletBalance'] as String? ?? 'N/A';

    // ── No transaction picker for these sub-topics ───────────────────────────
    if (sub == 'Partner Not Showing') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoTile(Icons.account_balance_wallet_rounded, _primary, 'Wallet Balance', balance),
        const SizedBox(height: 10),
        _infoTile(Icons.store_rounded, Colors.grey[600]!,
            'Partner Not in Programme',
            'Cashback is only available at officially verified GoOuts partner venues. '
            'If a venue is not showing a cashback rate on their page, they are not currently part of the programme. '
            'You can suggest them by submitting a ticket below.'),
      ]);
    }

    if (sub == 'Cashback Expiring') {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoTile(Icons.account_balance_wallet_rounded, _primary, 'Wallet Balance', balance),
        const SizedBox(height: 10),
        _infoTile(Icons.timer_outlined, Colors.orange,
            'Cashback Does Not Expire',
            'Your GoOuts cashback balance does not have an expiry date. '
            'It stays in your wallet until you choose to use it. '
            'If you are seeing something different, please submit a ticket and include a screenshot.'),
      ]);
    }

    // ── How to Redeem — simple explanation, no transaction picker needed ──
    if (sub == 'How to Redeem Cashback') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoTile(Icons.account_balance_wallet_rounded, _primary,
              'Your Wallet Balance', balance),
          const SizedBox(height: 10),
          _infoTile(Icons.check_circle_rounded, const Color(0xFF388E3C),
              'No manual redemption needed',
              'Your cashback is automatically credited to your GoOuts wallet the moment you spend at a partner venue. '
              'There is nothing to claim or activate.'),
          const SizedBox(height: 10),
          _infoTile(Icons.storefront_rounded, _teal,
              'How to use your cashback balance',
              'Simply pay with your GoOuts virtual card at any partner venue. '
              'Your wallet balance is used first — the cashback you earned is spent automatically.'),
          const SizedBox(height: 10),
          _infoTile(Icons.visibility_rounded, Colors.grey[600]!,
              'Where to see your cashback',
              'Go to the Wallet screen → your current balance is shown at the top. '
              'Every cashback credit also appears in your transaction history.'),
        ],
      );
    }
    final txns    = data['spendingTransactions'] as List? ?? [];
    final selected = _selectedCashbackTxn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTile(Icons.account_balance_wallet_rounded, _primary,
            'Current Wallet Balance', balance),
        const SizedBox(height: 14),
        Text(
          selected == null
              ? 'Select the transaction you have a cashback query about:'
              : 'Transaction selected — here is what we found:',
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w700, color: _dark),
        ),
        const SizedBox(height: 8),

        if (selected != null) ...[
          // Selected tile
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD6EEF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _primary, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected['title'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _primary)),
                      Text(
                        '${selected['amount']}  •  ${selected['date']}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.grey[600]),
                      ),
                      if ((selected['id'] as String? ?? '').length >= 8)
                        Text(
                          'TXN-${(selected['id'] as String).substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              color: _primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setSheet(
                      () => _selectedCashbackTxn = null),
                  child: Text('Change',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _cashbackAnswer(selected),
          const SizedBox(height: 8),
          // Auto-include TXN reference note
          if ((selected['id'] as String? ?? '').length >= 8)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F6FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: _primary, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'If you submit a ticket, the reference TXN-${(selected['id'] as String).substring(0, 8).toUpperCase()} will be included automatically so our team can locate your transaction instantly.',
                      style: GoogleFonts.inter(fontSize: 11, color: _dark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ] else if (txns.isEmpty)
          _infoTile(Icons.receipt_long_rounded, Colors.grey,
              'No transactions found',
              'No recent spending transactions found.')
        else
          ...txns.map((t) {
            final tx = t as Map<String, dynamic>;
            final hasEarned = tx['isPartner'] as bool? ?? false;
            return GestureDetector(
              onTap: () => setSheet(() => _selectedCashbackTxn = tx),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx['title'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _dark)),
                          Text(tx['date'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(tx['amount'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _dark)),
                        if (hasEarned)
                          Text(tx['cashbackStr'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF388E3C)))
                        else
                          Text('No cashback',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey[400])),
                      ],
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.grey, size: 18),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _cashbackAnswer(Map<String, dynamic> txn) {
    final isPartner  = txn['isPartner']  as bool?   ?? false;
    final cashbackStr = txn['cashbackStr'] as String?;
    final isPending  = (txn['status'] as String? ?? '')
        .toLowerCase() == 'pending';

    if (isPending) {
      return _infoTile(Icons.hourglass_bottom_rounded, Colors.orange,
          'Transaction Still Pending',
          'Cashback is calculated once the transaction is fully settled — usually within 1–3 business days.');
    }
    if (!isPartner) {
      return _infoTile(Icons.store_rounded, Colors.grey[600]!,
          'Not a GoOuts Partner',
          'This merchant is not part of the GoOuts cashback programme. Only purchases at partner venues earn cashback. Check the Offers section for partner merchants near you.');
    }
    if (cashbackStr != null) {
      return _infoTile(Icons.check_circle_rounded,
          const Color(0xFF388E3C),
          'Cashback Earned: $cashbackStr',
          'Cashback was credited instantly to your GoOuts wallet. If you cannot see it, pull down to refresh your wallet balance.');
    }
    return _infoTile(Icons.help_outline_rounded, Colors.orange,
        'Cashback Not Yet Applied',
        'This is a GoOuts partner purchase but cashback has not been applied yet. If the issue persists after 24 hours, please submit a ticket.');
  }

  // ── Account Security ──────────────────────────────────────────────────────
  Widget _selfServiceSecurity(Map<String, dynamic> data, String sub, StateSetter setSheet) {
    final kycLabel  = data['kycLabel']  as String? ?? 'Unknown';
    final kycStatus = data['kycStatus'] as String? ?? '';
    final email     = data['email']     as String? ?? '';
    final phone     = data['phone']     as String? ?? '';
    final kycColor  = kycStatus == 'verified'
        ? const Color(0xFF388E3C)
        : kycStatus == 'pending' ? Colors.orange : Colors.grey;
    final recentTxns = data['recentTransactions'] as List? ?? [];
    final isPhishing = sub == 'Phishing / Scam Report';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTile(Icons.check_circle_rounded, const Color(0xFF388E3C),
            'Account Status', 'Active — No restrictions detected'),
        const SizedBox(height: 10),
        _infoTile(Icons.badge_outlined, kycColor,
            'Identity Verification', kycLabel),
        const SizedBox(height: 10),
        _infoTile(Icons.email_outlined, Colors.grey[600]!,
            'Email on file', email.isNotEmpty ? email : 'Not set'),
        const SizedBox(height: 10),
        _infoTile(Icons.phone_outlined, Colors.grey[600]!,
            'Phone on file', phone.isNotEmpty ? phone : 'Not set'),
        const SizedBox(height: 10),
        _infoTile(Icons.lightbulb_outline_rounded, _teal, 'Quick tip',
            'If you suspect unauthorised access, go to Profile → Security → Change PIN immediately.'),
        if (isPhishing) ...[
          const SizedBox(height: 16),
          _infoTile(Icons.warning_amber_rounded, Colors.red,
              'Phishing Alert',
              'GoOuts will NEVER ask for your PIN, password or OTP via phone, email or SMS. If someone has, please report it immediately.'),
          const SizedBox(height: 16),
          Text('Recent Transactions',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 4),
          Text('Select any transaction you did not make:',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 8),
          if (recentTxns.isEmpty)
            _infoTile(Icons.receipt_long_rounded, Colors.grey,
                'No transactions found', 'No recent transactions found.')
          else
            ...recentTxns.map((t) {
              final tx = t as Map<String, dynamic>;
              return _txnRow(tx,
                selected: _selectedSupportTxn?['id'] == tx['id'],
                onTap: () => setSheet(() => _selectedSupportTxn = tx),
              );
            }),
        ],
      ],
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────
  Widget _selfServiceCard(Map<String, dynamic> data, String sub, StateSetter setSheet) {
    final cardFrozen = data['cardFrozen'] as bool? ?? false;
    final txns = data['transactions'] as List? ?? [];
    final showTxns = ['Card Declined', 'Virtual Card Issue', 'Other Card Issue'].contains(sub);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTile(
          cardFrozen ? Icons.ac_unit_rounded : Icons.credit_card_rounded,
          cardFrozen ? Colors.blue : const Color(0xFF388E3C),
          'Card Status',
          cardFrozen
              ? 'Your card is currently FROZEN. Go to Profile → Security to unfreeze it.'
              : 'Your card is Active and ready to use.',
        ),
        const SizedBox(height: 10),
        _infoTile(Icons.lightbulb_outline_rounded, _teal, 'Quick tip',
            'If your card was declined, check it is not frozen and that you have sufficient balance.'),
        if (showTxns) ...[
          const SizedBox(height: 16),
          Text('Recent Transactions',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
          const SizedBox(height: 4),
          Text('Select the transaction related to your issue:',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
          const SizedBox(height: 8),
          if (txns.isEmpty)
            _infoTile(Icons.receipt_long_rounded, Colors.grey,
                'No transactions found', 'No recent transactions on this account.')
          else
            ...txns.map((t) {
              final tx = t as Map<String, dynamic>;
              return _txnRow(tx,
                selected: _selectedSupportTxn?['id'] == tx['id'],
                onTap: () => setSheet(() => _selectedSupportTxn = tx),
              );
            }),
        ],
      ],
    );
  }

  // ── KYC ───────────────────────────────────────────────────────────────────
  Widget _selfServiceKyc(Map<String, dynamic> data) {
    final statusTitle   = data['statusTitle']   as String? ?? '';
    final statusMessage = data['statusMessage'] as String? ?? '';
    final colorStr      = data['statusColor']   as String? ?? 'grey';
    final Color color   = colorStr == 'green'
        ? const Color(0xFF388E3C)
        : colorStr == 'orange'
            ? Colors.orange
            : colorStr == 'red'
                ? Colors.red
                : Colors.grey;
    final IconData icon = colorStr == 'green'
        ? Icons.verified_user_rounded
        : colorStr == 'orange'
            ? Icons.hourglass_top_rounded
            : colorStr == 'red'
                ? Icons.cancel_rounded
                : Icons.shield_outlined;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoTile(icon, color, statusTitle, statusMessage),
        const SizedBox(height: 10),
        _infoTile(Icons.lightbulb_outline_rounded, _teal,
            'Verification Tips',
            'Ensure your ID is a valid government-issued document, not expired, and fully visible. Your selfie must clearly show your face matching the document.'),
      ],
    );
  }

  // ── Food Delivery ────────────────────────────────────────────────────────
  Widget _selfServiceFoodDelivery(String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_prefilledOrderId != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD6EEF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _primary.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.delivery_dining_rounded, color: _primary, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Linked Order', style: GoogleFonts.inter(fontSize: 11,
                    fontWeight: FontWeight.w600, color: Colors.grey[500])),
                Text('#${_prefilledOrderId!.length > 8 ? _prefilledOrderId!.substring(0, 8).toUpperCase() : _prefilledOrderId!.toUpperCase()}',
                    style: GoogleFonts.inter(fontSize: 14,
                        fontWeight: FontWeight.w700, color: _primary)),
              ])),
              const Icon(Icons.check_circle_rounded, color: _primary, size: 16),
            ]),
          ),
        if (sub == 'Order Late / Not Arrived') ...[
          _infoTile(Icons.hourglass_bottom_rounded, Colors.orange, 'Typical Delivery Times',
              'Most GoOuts deliveries arrive within the estimated time shown on your order tracking screen.\n\n'
              '• Weather or traffic can cause short delays\n'
              '• Contact your driver via the in-app chat on the order tracking screen\n'
              '• If your order shows "Delivered" but you have not received it, submit a ticket below.'),
          const SizedBox(height: 8),
          _infoTile(Icons.map_rounded, _teal, 'Check Live Tracking',
              "Open your order in the GoOuts app to see your driver's live position on the map."),
        ] else if (sub == 'Wrong Items Delivered' || sub == 'Missing Items') ...[
          _infoTile(Icons.restaurant_menu_rounded, Colors.orange, 'What happens next',
              "If you received incorrect or missing items, we'll arrange a refund or replacement.\n\n"
              '• Take a photo of the items received (helpful for our team)\n'
              '• Refunds are credited instantly to your GoOuts wallet\n'
              '• Submit the ticket below — include details of what was missing or wrong.'),
          const SizedBox(height: 8),
          _infoTile(Icons.account_balance_wallet_rounded, _primary, 'Refund Method',
              'GoOuts refunds food delivery issues directly to your GoOuts wallet — no card reversal needed.'),
        ] else if (sub == 'Driver Issue') ...[
          _infoTile(Icons.warning_amber_rounded, Colors.orange, 'Driver Behaviour Concern',
              'We take driver conduct seriously. Your feedback helps us maintain quality.\n\n'
              '• If you feel unsafe, contact emergency services first\n'
              '• Your report will be reviewed by our safety team within 24 hours\n'
              "• The driver's account will be reviewed and may be suspended."),
        ] else if (sub == 'Order Cancelled by Restaurant') ...[
          _infoTile(Icons.account_balance_wallet_rounded, _primary, 'Automatic Refund',
              'When a restaurant cancels your order, the full amount including delivery fee is automatically refunded to your GoOuts wallet within minutes.\n\n'
              'If your wallet has not updated, please allow up to 30 minutes and pull to refresh.'),
        ] else if (sub == 'Refund Not Received') ...[
          _infoTile(Icons.account_balance_wallet_rounded, _primary, 'Where Refunds Go',
              'GoOuts food delivery refunds go to your GoOuts wallet — not back to your bank card.\n\n'
              '• Open the Wallet screen and pull down to refresh\n'
              '• Refunds typically appear within 1–5 minutes\n'
              '• If it has been over 30 minutes, submit a ticket below.'),
        ] else ...[
          _infoTile(Icons.delivery_dining_rounded, _primary, 'Food Delivery Support',
              'Our team is available to help with any food delivery issue. Include as much detail as possible so we can resolve it quickly.'),
        ],
        const SizedBox(height: 10),
        _infoTile(Icons.info_outline_rounded, Colors.grey[600]!, 'Useful tip',
            'You can also rate your order and report specific issues directly from the Order Tracking screen after delivery.'),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _infoTile(IconData icon, Color color, String title, String body) =>
      Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 3),
                  Text(body,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: _dark, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _txnRow(Map<String, dynamic> t, {VoidCallback? onTap, bool selected = false}) {
    final isPositive = t['positive'] as bool? ?? false;
    final isPending  = (t['status'] as String? ?? '').toLowerCase() == 'pending';
    final txnId      = t['id'] as String? ?? '';
    final txnRef     = txnId.length >= 8 ? 'TXN-${txnId.substring(0, 8).toUpperCase()}' : '';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD6EEF8) : const Color(0xFFF8FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _primary : Colors.grey[200]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['title'] as String? ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? _primary : _dark)),
                  const SizedBox(height: 2),
                  Text(t['date'] as String? ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey[500])),
                  if (txnRef.isNotEmpty)
                    Text(txnRef,
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: selected ? _primary : Colors.grey[400],
                            letterSpacing: 0.8)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isPositive ? '+' : ''}${t['amount']}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isPositive ? const Color(0xFF388E3C) : _dark),
                ),
                if (isPending)
                  Text('Pending',
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600)),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: _primary, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final subs = _subTopics[_selectedTopicValue];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: _primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Contact Support',
            style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _primary)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded,
                color: Colors.black87, size: 22),
            onPressed: () =>
                Navigator.pushNamed(context, '/support-tickets'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFD6EEF8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded, color: _teal, size: 14),
                  const SizedBox(width: 5),
                  Text('Active Support Team',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _teal)),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Text('How can we help you today?',
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _dark)),
            const SizedBox(height: 8),
            Text(
              'Fill out the form below and our team will get back to you shortly.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[500], height: 1.5),
            ),

            const SizedBox(height: 20),

            // Form card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Topic
                  _fieldLabel('Topic'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTopicValue,
                        isExpanded: true,
                        icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.grey),
                        style: GoogleFonts.inter(
                            fontSize: 14, color: _dark),
                        onChanged: (v) {
                          if (v == null) return;
                          final t = _topics.firstWhere(
                              (t) => t['value'] == v);
                          setState(() {
                            _selectedTopicValue = v;
                            _selectedTopicLabel = t['label']!;
                            _selectedSubTopic = null;
                            _subjectCtrl.clear();
                          });
                        },
                        items: _topics
                            .map((t) => DropdownMenuItem(
                                  value: t['value'],
                                  child: Text(t['label']!,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: _dark)),
                                ))
                            .toList(),
                      ),
                    ),
                  ),

                  // Sub-topics
                  if (subs != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: _fieldLabel(
                                'What is the specific issue?')),
                        if (_selectedSubTopic != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedSubTopic = null;
                              _subjectCtrl.clear();
                            }),
                            child: Text('Change',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _primary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...subs.map((sub) {
                      final isSelected =
                          _selectedSubTopic == sub['label'];
                      if (_selectedSubTopic != null && !isSelected) {
                        return const SizedBox.shrink();
                      }
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedSubTopic = sub['label'];
                          _subjectCtrl.text = sub['label']!;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFD6EEF8)
                                : const Color(0xFFF8FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? _primary
                                  : Colors.grey[200]!,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? _primary.withValues(alpha: 0.15)
                                      : Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconMap[sub['icon']] ??
                                      Icons.help_outline_rounded,
                                  color: isSelected
                                      ? _primary
                                      : Colors.grey[500],
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub['label']!,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? _primary
                                              : _dark),
                                    ),
                                    Text(sub['desc']!,
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                    Icons.check_circle_rounded,
                                    color: _primary,
                                    size: 20),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 8),
                  // Info hint — message collected later
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6EEF8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded,
                          color: _primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                          'Tap "Check for Help" — our AI assistant will try to resolve your issue first.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: _dark, height: 1.4))),
                    ]),
                  ),

                  // Error
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_errorMsg!,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.red)),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Submit button
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: (_submitting || _loadingCheck)
                          ? null
                          : _checkBeforeSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: (_submitting || _loadingCheck)
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5))
                          : Text('Check for Help',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 5),
                      Text('Our team usually replies within 2 hours',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[400])),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // System status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SYSTEM STATUS',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[400],
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                          width: 10, height: 10,
                          decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('All Systems Operational',
                          style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _dark)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Core banking and wallet services are running smoothly.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[500],
                        height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Field helpers ─────────────────────────────────────────────────────────
  Widget _fieldLabel(String label) => Text(label,
      style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600]));

  // ── Bottom nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 'Home', '/home'),
                _navItem(Icons.account_balance_wallet_rounded,
                    'Wallet', '/wallet'),
                _navItemActive(),
                _navItem(
                    Icons.person_rounded, 'Profile', '/profile'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(IconData icon, String label, String route) =>
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.grey[400], size: 24),
            const SizedBox(height: 3),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11, color: Colors.grey[400])),
          ],
        ),
      );

  Widget _navItemActive() => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F3FB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline_rounded,
                color: _primary, size: 22),
            const SizedBox(width: 6),
            Text('Support',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _primary)),
          ],
        ),
      );
}
