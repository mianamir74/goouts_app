import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Wraps any screen and shows a full-screen promo overlay when an active
/// promo campaign exists for the current user.
class PromoOverlayWrapper extends StatefulWidget {
  final Widget child;
  const PromoOverlayWrapper({super.key, required this.child});

  @override
  State<PromoOverlayWrapper> createState() => _PromoOverlayWrapperState();
}

class _PromoOverlayWrapperState extends State<PromoOverlayWrapper> {
  Map<String, dynamic>? _activePromo;
  String? _promoDocId;
  bool _dismissed = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkForPromo();
  }

  Future<void> _checkForPromo() async {
    // Small delay so home screen renders before overlay appears
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList('dismissed_promos') ?? [];

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      final snap = await FirebaseFirestore.instance
          .collection('admin_promo_campaigns')
          .where('isActive', isEqualTo: true)
          .where('audienceType', isEqualTo: 'users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (final doc in snap.docs) {
        if (dismissed.contains(doc.id)) continue;
        final data = doc.data();
        // Check targeting
        final targetMode = (data['targetMode'] ?? '').toString();
        final targetUids = List<String>.from(data['targetUserUids'] ?? []);
        if (targetMode == 'SELECTED_USERS' && uid.isNotEmpty && !targetUids.contains(uid)) {
          continue;
        }
        // Mark as seen immediately — before showing — so closing the app
        // without tapping Skip doesn't cause it to reappear.
        if (!dismissed.contains(doc.id)) {
          dismissed.add(doc.id);
          await prefs.setStringList('dismissed_promos', dismissed);
        }
        if (mounted) {
          setState(() {
            _activePromo = data;
            _promoDocId = doc.id;
            _checked = true;
          });
        }
        return;
      }
      if (mounted) setState(() => _checked = true);
    } catch (_) {
      if (mounted) setState(() => _checked = true);
    }
  }

  void _dismiss() async {
    if (_promoDocId != null) {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getStringList('dismissed_promos') ?? [];
      if (!dismissed.contains(_promoDocId)) {
        dismissed.add(_promoDocId!);
        await prefs.setStringList('dismissed_promos', dismissed);
      }
    }
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final showPromo = _checked && _activePromo != null && !_dismissed;
    return Stack(
      children: [
        widget.child,
        if (showPromo)
          _PromoOverlay(
            promo: _activePromo!,
            onDismiss: _dismiss,
          ),
      ],
    );
  }
}

class _PromoOverlay extends StatefulWidget {
  final Map<String, dynamic> promo;
  final VoidCallback onDismiss;

  const _PromoOverlay({required this.promo, required this.onDismiss});

  @override
  State<_PromoOverlay> createState() => _PromoOverlayState();
}

class _PromoOverlayState extends State<_PromoOverlay> with SingleTickerProviderStateMixin {
  late int _secondsLeft;
  Timer? _timer;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _secondsLeft = (widget.promo['skipDelaySeconds'] as int? ?? 3).clamp(1, 30);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCta() async {
    final url = (widget.promo['ctaValue'] ?? '').toString().trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _dismiss() {
    _fadeCtrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = (widget.promo['imageUrl'] ?? '').toString().trim();
    final title = (widget.promo['title'] ?? '').toString().trim();
    final subtitle = (widget.promo['subtitle'] ?? '').toString().trim();
    final ctaLabel = (widget.promo['ctaLabel'] ?? '').toString().trim();
    final ctaValue = (widget.promo['ctaValue'] ?? '').toString().trim();
    final canDismiss = _secondsLeft <= 0;

    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: ctaValue.isNotEmpty ? _openCta : null,
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: SafeArea(
            child: Column(
              children: [
                // ── Close button row ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Spacer(),
                      GestureDetector(
                        onTap: canDismiss ? _dismiss : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D7A7A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                              canDismiss ? 'SKIP' : 'SKIP  $_secondsLeft',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 18),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Image ─────────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) => progress == null
                                  ? child
                                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.white38,
                                size: 60,
                              ),
                            )
                          : const Icon(Icons.campaign_rounded, color: Colors.white38, size: 80),
                    ),
                  ),
                ),

                // ── Title / subtitle ──────────────────────────────────
                if (title.isNotEmpty || subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: Column(
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // ── CTA button ────────────────────────────────────────
                if (ctaLabel.isNotEmpty && ctaValue.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _openCta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0392CA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          ctaLabel,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
