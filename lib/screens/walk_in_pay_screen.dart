// ─────────────────────────────────────────────────────────────────────────────
//  walk_in_pay_screen.dart — pay at a venue in the GoOuts app (16 Nov 2026).
//
//  Scenario S2a in PAYMENTS\GoOuts-Payment-Scenarios.md:
//    1. scan the venue QR (https://www.goouts.co.uk/pay?v=<partnerId>)
//    2. type the bill, choose whether to use cashback
//    3. functions/createWalkInPayment works out every number and returns a
//       Stripe page (Pay by Bank first, card as backup)
//    4. this screen listens to walkin_payments/{id}; the Stripe webhook marks
//       it paid and credits the cashback, so the result appears here live.
//
//  The app never decides a price, a fee or a cashback amount. It only sends
//  the venue id, the bill in pence and the cashback choice.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _navy = Color(0xFF0B1F3A);
const Color _blue = Color(0xFF0392CA);
const Color _gold = Color(0xFFFFC93C);
const Color _green = Color(0xFF16A34A);
const Color _red = Color(0xFFDC2626);

/// Reads a venue id from a GoOuts venue QR. Returns null for anything else.
String? venueIdFromQr(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  if (host != 'www.goouts.co.uk' && host != 'goouts.co.uk') return null;
  if (!uri.path.startsWith('/pay')) return null;
  final v = uri.queryParameters['v'] ?? '';
  return RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(v) ? v : null;
}

class WalkInScanScreen extends StatefulWidget {
  const WalkInScanScreen({super.key});
  @override
  State<WalkInScanScreen> createState() => _WalkInScanScreenState();
}

class _WalkInScanScreenState extends State<WalkInScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _handled = false;
  String _msg = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_handled) return;
    for (final b in cap.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final id = venueIdFromQr(raw);
      if (id == null) {
        setState(() => _msg = 'That is not a GoOuts venue code.');
        continue;
      }
      _handled = true;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => WalkInPayScreen(partnerId: id)));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('Scan to pay',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: Stack(children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14)),
            child: Text(
              _msg.isEmpty
                  ? 'Point your camera at the GoOuts QR code at the counter or on your table.'
                  : _msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ]),
    );
  }
}

class WalkInPayScreen extends StatefulWidget {
  const WalkInPayScreen({super.key, required this.partnerId});
  final String partnerId;
  @override
  State<WalkInPayScreen> createState() => _WalkInPayScreenState();
}

class _WalkInPayScreenState extends State<WalkInPayScreen> {
  final _amount = TextEditingController();
  bool _useCashback = true;
  bool _busy = false;
  String _error = '';
  String? _paymentId;
  String? _url;
  Map<String, dynamic>? _venue;
  StreamSubscription? _sub;
  Map<String, dynamic>? _pay;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('partners')
        .doc(widget.partnerId)
        .get()
        .then((s) {
      if (mounted) setState(() => _venue = s.data() ?? {});
    }).catchError((_) {
      if (mounted) setState(() => _venue = {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _amount.dispose();
    super.dispose();
  }

  int? _pence() {
    final t = _amount.text.replaceAll('£', '').replaceAll(',', '').trim();
    final v = double.tryParse(t);
    if (v == null || v <= 0) return null;
    return (v * 100).round();
  }

  Future<void> _start() async {
    final p = _pence();
    if (p == null) {
      setState(() => _error = 'Please enter the bill amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('createWalkInPayment')
          .call({
        'partnerId': widget.partnerId,
        'billPence': p,
        'useCashback': _useCashback,
      });
      final data = Map<String, dynamic>.from(res.data as Map);
      _paymentId = data['paymentId'] as String?;
      _url = data['url'] as String?;
      _listen();
      if (_url != null) await _openStripe();
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'Payment could not be started.');
    } catch (_) {
      setState(() => _error =
          'Payment could not be started. Nothing has been charged. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _listen() {
    if (_paymentId == null) return;
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('walkin_payments')
        .doc(_paymentId)
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _pay = s.data());
    });
  }

  Future<void> _openStripe() async {
    final u = Uri.tryParse(_url ?? '');
    if (u == null) return;
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      setState(() => _error = 'Could not open the payment page.');
    }
  }

  String _gbp(num pence) => '£${(pence / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final name = (_venue?['name'] ?? '').toString();
    final cbPct = _venue?['cashbackPercent'];
    final inApp = _venue?['walkInInAppPayments'] == true &&
        _venue?['stripeChargesEnabled'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(name.isEmpty ? 'Pay at venue' : name,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: _venue == null
          ? const Center(child: CircularProgressIndicator())
          : _pay != null
              ? _result()
              : ListView(padding: const EdgeInsets.all(20), children: [
                  if (!inApp)
                    _note(
                        'This venue does not take GoOuts app payments yet. Please pay at the till and show your GoOuts pass to earn your cashback.',
                        _red),
                  if (inApp && cbPct != null)
                    _note('You earn $cbPct% cashback rewards on this bill.',
                        _green),
                  const SizedBox(height: 14),
                  Text('Bill amount',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, color: _navy)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _amount,
                    enabled: inApp && !_busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(
                        fontSize: 28, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      prefixText: '£ ',
                      hintText: '0.00',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _useCashback,
                    onChanged: inApp && !_busy
                        ? (v) => setState(() => _useCashback = v)
                        : null,
                    title: Text('Use my cashback first',
                        style: GoogleFonts.poppins(fontSize: 14)),
                    activeThumbColor: _blue,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_error.isNotEmpty) _note(_error, _red),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: inApp && !_busy ? _start : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_busy ? 'Starting…' : 'Pay by Bank or card',
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You pay the same price as at the till. Pay by Bank is the quickest way. Card is available too.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ]),
    );
  }

  Widget _result() {
    final s = (_pay?['status'] ?? '').toString();
    final paid = s == 'paid';
    final cancelled = s == 'cancelled';
    final cb = (_pay?['cashbackPence'] ?? 0) as num;
    final bill = (_pay?['billPence'] ?? 0) as num;
    final used = (_pay?['rewardsPence'] ?? 0) as num;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Icon(
          paid
              ? Icons.check_circle_rounded
              : cancelled
                  ? Icons.cancel_rounded
                  : Icons.hourglass_top_rounded,
          size: 72,
          color: paid ? _green : (cancelled ? _red : _blue)),
      const SizedBox(height: 12),
      Text(
          paid
              ? 'Paid'
              : cancelled
                  ? 'Payment cancelled'
                  : 'Waiting for your payment',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
              fontSize: 24, fontWeight: FontWeight.w800, color: _navy)),
      const SizedBox(height: 10),
      Text(
          paid
              ? 'Show this screen to the staff. Bill ${_gbp(bill)}${used > 0 ? ', ${_gbp(used)} paid with cashback' : ''}. You earned ${_gbp(cb)} cashback rewards.'
              : cancelled
                  ? 'Nothing has been charged and any cashback you chose to use is back in your wallet.'
                  : 'Finish paying on the Stripe page, then come back here. This screen updates by itself.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 15, color: const Color(0xFF334155))),
      const SizedBox(height: 20),
      if (!paid && !cancelled && _url != null)
        OutlinedButton(
            onPressed: _openStripe, child: const Text('Open the payment page again')),
      if (paid || cancelled)
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: _navy, foregroundColor: Colors.white),
          child: const Text('Done'),
        ),
    ]);
  }

  Widget _note(String t, Color c) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withValues(alpha: 0.3))),
        child: Text(t, style: GoogleFonts.poppins(fontSize: 13, color: c)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  WalkInPassScreen — pay at the till, earn cashback (S1, S2). 16 Nov 2026.
//
//  The customer pays at the venue's own card machine as normal. Staff type
//  the 8 letter pass code and the bill into the Partner Portal
//  (functions/recordWalkInBill). The pass lasts 10 minutes and works once.
//  If "use my cashback" is on, staff take that much off the bill at the till.
//  This screen listens to walkin_passes/{code} and shows the result live.
// ─────────────────────────────────────────────────────────────────────────────

class WalkInPassScreen extends StatefulWidget {
  const WalkInPassScreen({super.key});
  @override
  State<WalkInPassScreen> createState() => _WalkInPassScreenState();
}

class _WalkInPassScreenState extends State<WalkInPassScreen> {
  bool _useCashback = false;
  bool _busy = false;
  String _error = '';
  String? _code;
  DateTime? _expires;
  Map<String, dynamic>? _pass;
  StreamSubscription? _sub;
  Timer? _tick;

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _make() async {
    setState(() {
      _busy = true;
      _error = '';
      _pass = null;
    });
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('createWalkInPass')
          .call({'useCashback': _useCashback});
      final d = Map<String, dynamic>.from(res.data as Map);
      _code = d['code'] as String?;
      _expires = DateTime.now()
          .add(Duration(seconds: (d['expiresInSec'] as num?)?.toInt() ?? 600));
      _sub?.cancel();
      _sub = FirebaseFirestore.instance
          .collection('walkin_passes')
          .doc(_code)
          .snapshots()
          .listen((s) {
        if (mounted) setState(() => _pass = s.data());
      }, onError: (_) {});
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'Could not make a pass.');
    } catch (_) {
      setState(() => _error = 'Could not make a pass. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _gbp(num pence) => '£${(pence / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final used = _pass?['status'] == 'used';
    final left = _expires == null
        ? 0
        : _expires!.difference(DateTime.now()).inSeconds.clamp(0, 3600);
    final expired = _code != null && !used && left == 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('My GoOuts pass',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (used) ...[
          const Icon(Icons.check_circle_rounded, size: 72, color: _green),
          const SizedBox(height: 10),
          Text('Bill recorded',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 24, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          Text(
              '${_pass?['partnerName'] ?? 'Venue'}: bill ${_gbp(_pass?['billPence'] ?? 0)}.'
              '${((_pass?['rewardsPence'] ?? 0) as num) > 0 ? ' ${_gbp(_pass?['rewardsPence'] ?? 0)} paid with cashback, pay ${_gbp(((_pass?['billPence'] ?? 0) as num) - ((_pass?['rewardsPence'] ?? 0) as num))} at the till.' : ''}'
              ' You earned ${_gbp(_pass?['cashbackPence'] ?? 0)} Instant Cashback.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 15, color: const Color(0xFF334155))),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white),
            child: const Text('Done'),
          ),
        ] else if (_code != null && !expired) ...[
          Text('Show this to the staff',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(data: _code!, size: 200),
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
              '${_code!.substring(0, 4)} ${_code!.substring(4)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: _navy)),
          const SizedBox(height: 6),
          Text(
              'Works once. ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')} left.'
              '${_useCashback ? ' Your cashback will be taken off the bill.' : ''}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: const Color(0xFF64748B))),
          const SizedBox(height: 10),
          Text('This screen updates by itself when the staff record your bill.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF64748B))),
        ] else ...[
          if (expired)
            _passNote('That pass has expired. Make a new one below.', _red),
          Text(
              'Pay at the till as normal and earn Instant Cashback. Make a pass, then show it to the staff before you pay.',
              style: GoogleFonts.poppins(
                  fontSize: 14, color: const Color(0xFF334155), height: 1.5)),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _useCashback,
            onChanged: _busy ? null : (v) => setState(() => _useCashback = v),
            title: Text('Use my cashback on this bill',
                style: GoogleFonts.poppins(fontSize: 14)),
            activeThumbColor: _blue,
            contentPadding: EdgeInsets.zero,
          ),
          if (_error.isNotEmpty) _passNote(_error, _red),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _busy ? null : _make,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _navy,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(_busy ? 'Making your pass…' : 'Show my pass',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ]),
    );
  }

  Widget _passNote(String t, Color c) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withValues(alpha: 0.3))),
        child: Text(t, style: GoogleFonts.poppins(fontSize: 13, color: c)),
      );
}
