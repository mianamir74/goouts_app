// Merchant offer flyer, opened from a Flyer Studio push notification.
// Added 5 Nov 2026.
//
// "Show and go" live pass: at the counter the customer taps Use offer now.
// The server checks they are within 150 m of the venue, then the phone shows
// a moving green pass with a running clock for 10 minutes. Staff only glance
// at it, so there is nothing to type or scan at busy times. A screenshot
// cannot fake it because the clock and animation keep moving.

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class FlyerOfferScreen extends StatefulWidget {
  final String flyerId;
  const FlyerOfferScreen({super.key, required this.flyerId});
  @override
  State<FlyerOfferScreen> createState() => _FlyerOfferScreenState();
}

class _FlyerOfferScreenState extends State<FlyerOfferScreen> {
  final _fn = FirebaseFunctions.instanceFor(region: 'europe-west1');
  Map<String, dynamic>? _f;
  String? _error;
  bool _busy = false;
  int _passExp = 0, _passStart = 0, _clockSkew = 0;
  bool _used = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _fn.httpsCallable('flyerGetForCustomer').call({'flyerId': widget.flyerId});
      final d = Map<String, dynamic>.from(r.data as Map);
      setState(() {
        _f = d;
        _used = d['used'] == true;
        _passExp = (d['passExpiresAt'] as num?)?.toInt() ?? 0;
        _passStart = (d['passStartedAt'] as num?)?.toInt() ?? 0;
        _clockSkew = ((d['serverNow'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch) -
            DateTime.now().millisecondsSinceEpoch;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'This offer is no longer available.');
    } catch (_) {
      setState(() => _error = 'This offer is no longer available.');
    }
  }

  int get _now => DateTime.now().millisecondsSinceEpoch + _clockSkew;
  bool get _passOpen => _passExp > _now;

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<Position?> _position() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      _snack('Turn on location so we can check you are at the venue.');
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      _snack('Turn on location services on your phone.');
      return null;
    }
    return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
  }

  Future<void> _useNow() async {
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Use offer now?'),
      content: const Text('Only tap this at the counter. The pass lasts 10 minutes and can be used once.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not yet')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Use now')),
      ],
    ));
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final pos = await _position();
      if (pos == null) return;
      final r = await _fn.httpsCallable('flyerUsePass').call({
        'flyerId': widget.flyerId, 'lat': pos.latitude, 'lng': pos.longitude,
      });
      final d = Map<String, dynamic>.from(r.data as Map);
      setState(() {
        _used = true;
        _passExp = (d['expiresAt'] as num).toInt();
        _passStart = (d['startedAt'] as num).toInt();
      });
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'Could not use the offer.');
    } catch (_) {
      _snack('Could not get your location. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _directions() async {
    final f = _f;
    if (f == null) return;
    final geo = f['venueGeo'] as Map?;
    final venue = Map<String, dynamic>.from(f['venue'] as Map? ?? {});
    final q = geo != null ? '${geo['lat']},${geo['lng']}' : Uri.encodeComponent('${venue['name']} ${venue['address']}');
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'),
        mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    if (f != null && _passOpen) {
      return _LivePass(
        venue: (Map<String, dynamic>.from(f['venue'] as Map? ?? {})['name'] ?? '').toString(),
        offer: (f['offerText'] ?? '').toString(),
        dish: (f['dishName'] ?? '').toString(),
        expiresAt: _passExp, startedAt: _passStart, skew: _clockSkew,
        onDone: () => setState(() {}),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
          title: Text('Offer', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))))
          : f == null
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(child: Column(children: [
                  Expanded(child: InteractiveViewer(child: Center(child: Image.network(
                      (f['finalUrl'] ?? '').toString(), fit: BoxFit.contain)))),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(14),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (!_used && f['active'] == true && f['expired'] != true && f['soldOut'] != true)
                        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text(
                            'At the counter, tap Use offer now and show your screen. Staff just take a look.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54))),
                      Row(children: [
                        Expanded(flex: 3, child: FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669), padding: const EdgeInsets.all(14)),
                          onPressed: (!_used && f['active'] == true && f['expired'] != true && f['soldOut'] != true && !_busy)
                              ? _useNow : null,
                          child: _busy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_used ? 'Offer used ✔' : f['soldOut'] == true ? 'Sold out'
                                  : f['expired'] == true ? 'Offer ended' : '✅ Use offer now',
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                        )),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(14)),
                          onPressed: _directions, icon: const Icon(Icons.directions), label: const Text('Directions'))),
                      ]),
                    ]),
                  ),
                ])),
    );
  }
}

/// Full screen moving pass. Running clock to the second, pulsing tick and a
/// sweeping shine, so a screenshot or old photo is easy for staff to spot.
class _LivePass extends StatefulWidget {
  final String venue, offer, dish;
  final int expiresAt, startedAt, skew;
  final VoidCallback onDone;
  const _LivePass({required this.venue, required this.offer, required this.dish,
      required this.expiresAt, required this.startedAt, required this.skew, required this.onDone});
  @override
  State<_LivePass> createState() => _LivePassState();
}

class _LivePassState extends State<_LivePass> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_now >= widget.expiresAt) {
        _t?.cancel();
        widget.onDone();
      }
      setState(() {});
    });
  }

  int get _now => DateTime.now().millisecondsSinceEpoch + widget.skew;

  @override
  void dispose() {
    _t?.cancel();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = Duration(milliseconds: math.max(0, widget.expiresAt - _now));
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final clock = DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(_now));
    return Scaffold(
      body: AnimatedBuilder(
        animation: _a,
        builder: (_, __) {
          final t = _a.value;
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -1), end: Alignment(1 - 2 * t, 1),
              colors: const [Color(0xFF047857), Color(0xFF10B981), Color(0xFF065F46)],
            )),
            child: SafeArea(child: Column(children: [
              Align(alignment: Alignment.topLeft, child: IconButton(
                  onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white))),
              const Spacer(),
              Transform.scale(
                scale: 1 + 0.08 * math.sin(t * 2 * math.pi),
                child: Container(
                  width: 150, height: 150,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 110, color: Color(0xFF059669)),
                ),
              ),
              const SizedBox(height: 22),
              Text('OFFER VALID', style: GoogleFonts.inter(color: Colors.white, fontSize: 30,
                  fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(widget.offer,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))),
              if (widget.dish.isNotEmpty) Text(widget.dish,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 18),
              Text(widget.venue, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 26),
              Text(clock, style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Pass closes in $mm:$ss', style: GoogleFonts.inter(color: Colors.white, fontSize: 15)),
              const Spacer(),
              // sweeping bar: moves constantly, impossible in a screenshot
              Container(
                height: 10, margin: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: Align(
                  alignment: Alignment(-1 + 2 * t, 0),
                  child: Container(width: 80, decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ])),
          );
        },
      ),
    );
  }
}
