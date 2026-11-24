// ─────────────────────────────────────────────────────────────────────────────
//  scan_pay_screen.dart — Scan & Pay at the venue's own till (24 Nov 2026).
//
//  1. Customer scans the venue QR or types the venue number.
//  2. Enters the bill and how much cashback to use (Max = what they have).
//  3. "Pay with GoOuts virtual card" -> functions/createWalkInClaim. The
//     server caps and HOLDS the cashback used and works out the cashback.
//  4. Customer pays the rest at the venue's card machine.
//  5. Cashback rewards land when the venue confirms the bill in its Merchant
//     Portal (respondWalkInClaim). This screen updates by itself.
//
//  The app never decides an amount: it sends the venue, the bill and the
//  cashback wanted; the server decides what is allowed.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'walk_in_pay_screen.dart' show WalkInPassScreen;

const Color _navy = Color(0xFF0B1F3A);
const Color _blue = Color(0xFF0392CA);
const Color _gold = Color(0xFFFFC93C);
const Color _green = Color(0xFF16A34A);
const Color _red = Color(0xFFDC2626);
const Color _grey = Color(0xFF64748B);

String _gbp(num pence) => '£${(pence / 100).toStringAsFixed(2)}';

int? _toPence(String t) {
  final v = double.tryParse(t.replaceAll('£', '').replaceAll(',', '').trim());
  if (v == null || v < 0) return null;
  return (v * 100).round();
}

/// Venue number typed by the customer -> partner id (null if none).
Future<String?> partnerIdFromVenueNumber(String code) async {
  final c = code.trim();
  if (c.isEmpty) return null;
  final col = FirebaseFirestore.instance.collection('partners');
  for (final v in {c.toUpperCase(), c}) {
    final q = await col.where('verificationCode', isEqualTo: v).limit(1).get();
    if (q.docs.isNotEmpty) return q.docs.first.id;
  }
  return null;
}

class ScanPayScreen extends StatefulWidget {
  const ScanPayScreen({super.key, required this.partnerId, this.venue});
  final String partnerId;
  final Map<String, dynamic>? venue;
  @override
  State<ScanPayScreen> createState() => _ScanPayScreenState();
}

class _ScanPayScreenState extends State<ScanPayScreen> {
  final _bill = TextEditingController();
  final _use = TextEditingController();
  Map<String, dynamic>? _venue;
  int _availablePence = 0;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _venue = widget.venue;
    _load();
    _bill.addListener(() => setState(() {}));
    _use.addListener(() => setState(() {}));
  }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (_venue == null) {
        final s = await db.collection('partners').doc(widget.partnerId).get();
        _venue = s.data() ?? {};
      }
      if (uid != null) {
        final u = (await db.collection('users').doc(uid).get()).data() ?? {};
        final rb = (await db.collection('reward_balances').doc(uid).get()).data() ?? {};
        final wallet = (((u['walletBalance'] as num?) ?? 0) * 100).round();
        final server = ((rb['pence'] as num?) ?? 0).round();
        _availablePence = wallet < server ? wallet : server;
        if (_availablePence < 0) _availablePence = 0;
      }
    } catch (_) {
      _venue ??= {};
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bill.dispose();
    _use.dispose();
    super.dispose();
  }

  int get _billP => _toPence(_bill.text) ?? 0;
  int get _maxUse => _billP < _availablePence ? _billP : _availablePence;
  int get _useP {
    final u = _toPence(_use.text) ?? 0;
    return u > _maxUse ? _maxUse : u;
  }

  num get _pct => (_venue?['cashbackPercent'] as num?) ?? 0;
  int get _estCashback => (_billP * _pct / 100).floor();

  Future<void> _pay() async {
    if (_billP <= 0) {
      setState(() => _error = 'Please enter the bill amount.');
      return;
    }
    if ((_toPence(_use.text) ?? 0) > _maxUse) {
      setState(() => _error =
          'You can use up to ${_gbp(_maxUse)} of cashback on this bill.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('createWalkInClaim')
          .call({
        'partnerId': widget.partnerId,
        'billPence': _billP,
        'redeemPence': _useP,
      });
      final d = Map<String, dynamic>.from(res.data as Map);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ScanPayResultScreen(
                  claimId: d['claimId'] as String, first: d)));
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'Something went wrong. Please try again.');
    } catch (_) {
      setState(() => _error =
          'Something went wrong. Nothing has been taken. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_venue?['name'] ?? '').toString();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(name.isEmpty ? 'Scan & Pay' : name,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: _venue == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              if (_pct > 0)
                _note('You earn $_pct% cashback rewards on this bill.', _green),
              const SizedBox(height: 14),
              _label('Total bill'),
              _money(_bill, enabled: !_busy),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: _label('Use my cashback')),
                Text('You have ${_gbp(_availablePence)}',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: _grey)),
              ]),
              Row(children: [
                Expanded(
                    child: _money(_use,
                        enabled: !_busy && _availablePence > 0, hint: '0.00')),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _busy || _maxUse <= 0
                      ? null
                      : () => _use.text = (_maxUse / 100).toStringAsFixed(2),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _blue,
                    side: const BorderSide(color: _blue),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Max ${_gbp(_maxUse)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
              ]),
              if ((_toPence(_use.text) ?? 0) > _maxUse)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('The most you can use is ${_gbp(_maxUse)}.',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: _red)),
                ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(children: [
                  _row('Bill', _gbp(_billP)),
                  _row('Cashback used', '- ${_gbp(_useP)}'),
                  const Divider(height: 18),
                  _row('Pay at the till', _gbp(_billP - _useP), bold: true),
                  if (_pct > 0)
                    _row('Cashback you earn', '+ ${_gbp(_estCashback)}',
                        colour: _green),
                ]),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                _note(_error, _red),
              ],
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _busy ? null : _pay,
                icon: const Icon(Icons.credit_card_rounded),
                label: Text(_busy ? 'Please wait…' : 'Pay with GoOuts virtual card',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your cashback rewards are added as soon as the venue confirms your bill. T&Cs apply.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const WalkInPassScreen())),
                child: Text('Or show my GoOuts pass to the staff instead',
                    style: GoogleFonts.poppins(fontSize: 13, color: _blue)),
              ),
            ]),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _navy)),
      );

  Widget _money(TextEditingController c, {bool enabled = true, String hint = '0.00'}) =>
      TextField(
        controller: c,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,2})?')),
        ],
        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          prefixText: '£ ',
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );

  Widget _row(String a, String b, {bool bold = false, Color? colour}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(a,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                      color: _navy))),
          Text(b,
              style: GoogleFonts.poppins(
                  fontSize: bold ? 17 : 14,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: colour ?? _navy)),
        ]),
      );
}

Widget _note(String t, Color c) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.35))),
      child: Text(t, style: GoogleFonts.poppins(fontSize: 14, color: c)),
    );

/// After "Pay with GoOuts virtual card": what to pay and the live status.
class ScanPayResultScreen extends StatefulWidget {
  const ScanPayResultScreen({super.key, required this.claimId, this.first});
  final String claimId;
  final Map<String, dynamic>? first;
  @override
  State<ScanPayResultScreen> createState() => _ScanPayResultScreenState();
}

class _ScanPayResultScreenState extends State<ScanPayResultScreen> {
  StreamSubscription? _sub;
  Map<String, dynamic>? _c;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('walkin_claims')
        .doc(widget.claimId)
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _c = s.data());
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('cancelWalkInClaim')
          .call({'claimId': widget.claimId});
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'Could not cancel.');
    } catch (_) {
      setState(() => _error = 'Could not cancel. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c ?? widget.first ?? {};
    final status = (c['status'] ?? 'pending').toString();
    final name = (c['partnerName'] ?? '').toString();
    final payAtTill = (c['payAtTillPence'] as num?) ?? 0;
    final held = (c['heldPence'] as num?) ?? 0;
    final est = (c['estCashbackPence'] as num?) ?? 0;
    final earned = (c['cashbackPence'] as num?) ?? est;
    final ref = widget.claimId.substring(widget.claimId.length - 6).toUpperCase();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(name.isEmpty ? 'Scan & Pay' : name,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (status == 'pending') ...[
          Text('Now pay at the till',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 10),
          Text(_gbp(payAtTill),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 44, fontWeight: FontWeight.w800, color: _navy)),
          Text('Tap your GoOuts virtual card on the card machine.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
          const SizedBox(height: 18),
          if (held > 0)
            _note('${_gbp(held)} of your cashback is used on this bill.', _blue),
          const SizedBox(height: 10),
          _note(
              'Waiting for $name to confirm your bill. Your ${_gbp(est)} cashback rewards are added as soon as they do.',
              const Color(0xFFD97706)),
          const SizedBox(height: 14),
          Text('Reference $ref',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 2)),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: _busy ? null : _cancel,
            child: Text('Cancel this bill',
                style: GoogleFonts.poppins(color: _red)),
          ),
        ] else if (status == 'confirmed') ...[
          const Icon(Icons.check_circle_rounded, color: _green, size: 72),
          const SizedBox(height: 10),
          Text('Bill confirmed',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          Text('+ ${_gbp(earned)} cashback rewards',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 26, fontWeight: FontWeight.w800, color: _green)),
          Text('Added to your wallet. Spend them at any GoOuts partner or share them.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
        ] else ...[
          const Icon(Icons.info_rounded, color: _grey, size: 64),
          const SizedBox(height: 10),
          Text(
              status == 'cancelled'
                  ? 'Bill cancelled'
                  : status == 'expired'
                      ? 'Not confirmed in time'
                      : 'The venue did not confirm this bill',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          Text(
              held > 0
                  ? 'The ${_gbp(held)} cashback you used is back in your wallet.'
                  : 'No cashback was used.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: _grey)),
        ],
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 12),
          _note(_error, _red),
        ],
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: Text('Done', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}
