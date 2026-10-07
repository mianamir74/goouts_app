import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WelcomeBonusProgress — added 4 October 2026.
//
//  The £5 welcome bonus is unlocked in three steps (£1.50, £1.50, £2.00), one
//  per purchase of £5 or more, within 30 days of signing up. This widget draws
//  that progress: the blue hero card, the three steps, and the "Cashback
//  Earned so far" box. Design approved by Mian on 4 October 2026.
//
//  It READS welcome_bonus_state/{uid} and nothing else. That document is
//  written only by the server (admin_panel/functions/welcome_bonus.js); the
//  app cannot change it, which is the point. Amounts, the minimum spend and
//  the expiry date all come from the document, so finance can change the
//  offer without an app release.
//
//  The document appears a second or two after registration. Until it does,
//  the widget shows the standard offer with nothing unlocked, so the screen
//  after signup is never blank.
//
//  Accounts created before this shipped have scheme "legacy_flat" (they got
//  the old flat £2). For those the widget draws nothing.
// ─────────────────────────────────────────────────────────────────────────────

class WelcomeBonusState {
  final String scheme;
  final String status; // active | completed | expired
  final List<double> tiers;
  final double minSpend;
  final double total;
  final int step;
  final double unlocked;
  final double cashbackDuringBonus;
  final DateTime? expiresAt;
  final List<Map<String, dynamic>> stepLog;

  const WelcomeBonusState({
    required this.scheme,
    required this.status,
    required this.tiers,
    required this.minSpend,
    required this.total,
    required this.step,
    required this.unlocked,
    required this.cashbackDuringBonus,
    required this.expiresAt,
    required this.stepLog,
  });

  /// The offer as it stands before the server has written anything.
  static const WelcomeBonusState pending = WelcomeBonusState(
    scheme: 'tiered_v1',
    status: 'active',
    tiers: [1.5, 1.5, 2.0],
    minSpend: 5.0,
    total: 5.0,
    step: 0,
    unlocked: 0.0,
    cashbackDuringBonus: 0.0,
    expiresAt: null,
    stepLog: [],
  );

  static double _d(dynamic v) => v is num ? v.toDouble() : 0.0;

  factory WelcomeBonusState.fromMap(Map<String, dynamic> m) {
    final rawTiers = m['tiers'];
    final tiers = rawTiers is List
        ? rawTiers.map((e) => _d(e)).toList()
        : <double>[1.5, 1.5, 2.0];
    final rawLog = m['stepLog'];
    final log = <Map<String, dynamic>>[];
    if (rawLog is List) {
      for (final e in rawLog) {
        if (e is Map) log.add(Map<String, dynamic>.from(e));
      }
    }
    final exp = m['expiresAt'];
    return WelcomeBonusState(
      scheme: (m['scheme'] ?? '').toString(),
      status: (m['status'] ?? 'active').toString(),
      tiers: tiers,
      minSpend: m['minSpend'] is num ? _d(m['minSpend']) : 5.0,
      total: m['total'] is num
          ? _d(m['total'])
          : tiers.fold<double>(0.0, (a, b) => a + b),
      step: m['step'] is num ? (m['step'] as num).toInt() : 0,
      unlocked: _d(m['unlocked']),
      cashbackDuringBonus: _d(m['cashbackDuringBonus']),
      expiresAt: exp is Timestamp ? exp.toDate() : null,
      stepLog: log,
    );
  }

  bool get isTiered => scheme == 'tiered_v1';
  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired';
  double get remaining => (total - unlocked) < 0 ? 0.0 : total - unlocked;

  int get daysLeft {
    final e = expiresAt;
    if (e == null) return 30;
    final d = e.difference(DateTime.now());
    if (d.isNegative) return 0;
    return (d.inHours / 24).ceil();
  }
}

String _gbp(double v) => '£${v.toStringAsFixed(2)}';

String _ordinal(int i) {
  const names = ['First', 'Second', 'Third', 'Fourth', 'Fifth'];
  return i < names.length ? names[i] : 'Purchase ${i + 1}';
}

/// The stream every bonus view shares. Null uid (signed out) yields nothing.
Stream<WelcomeBonusState?> welcomeBonusStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Stream<WelcomeBonusState?>.empty();
  return FirebaseFirestore.instance
      .collection('welcome_bonus_state')
      .doc(uid)
      .snapshots()
      .map((s) {
    final data = s.data();
    if (!s.exists || data == null) return null;
    return WelcomeBonusState.fromMap(data);
  });
}

class WelcomeBonusProgress extends StatelessWidget {
  /// When true, an account with no state document yet is shown the standard
  /// offer (used straight after signup). When false it shows nothing (used on
  /// screens an older account may open).
  final bool showPendingWhenMissing;

  const WelcomeBonusProgress({super.key, this.showPendingWhenMissing = true});

  static const Color _primary = Color(0xFF0392CA);
  static const Color _primaryDark = Color(0xFF005A82);
  static const Color _navy = Color(0xFF0D1B3E);
  static const Color _grey = Color(0xFF42474E);
  static const Color _green = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WelcomeBonusState?>(
      stream: welcomeBonusStream(),
      builder: (context, snap) {
        WelcomeBonusState? s = snap.data;
        if (s == null) {
          if (!showPendingWhenMissing) return const SizedBox.shrink();
          s = WelcomeBonusState.pending;
        }
        if (!s.isTiered) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(s),
            const SizedBox(height: 14),
            for (int i = 0; i < s.tiers.length; i++) ...[
              _stepRow(s, i),
              const SizedBox(height: 9),
            ],
            if (s.step > 0) ...[
              const SizedBox(height: 1),
              _earnedBox(s),
              const SizedBox(height: 10),
            ],
            _infoBox(s),
          ],
        );
      },
    );
  }

  // ── Blue hero card ────────────────────────────────────────────────────────
  Widget _hero(WelcomeBonusState s) {
    final bool started = s.step > 0;
    final double big = started ? s.unlocked : s.total;
    final double progress = s.total <= 0 ? 0.0 : (s.unlocked / s.total);

    String caption;
    String pill;
    if (s.isCompleted) {
      caption = 'Welcome Bonus, fully unlocked';
      pill = '${s.tiers.length} of ${s.tiers.length} purchases complete';
    } else if (s.isExpired) {
      caption = 'of your ${_gbp(s.total)} Welcome Bonus was unlocked';
      pill = 'The remaining ${_gbp(s.remaining)} has expired';
    } else if (started) {
      caption = 'of your ${_gbp(s.total)} Welcome Bonus';
      pill = '${_gbp(s.remaining)} still to unlock · '
          '${s.daysLeft} day${s.daysLeft == 1 ? '' : 's'} left';
    } else {
      caption = 'Welcome Bonus, unlocked over your first '
          '${s.tiers.length} purchases';
      pill = '${_gbp(0)} of ${_gbp(s.total)} unlocked · '
          '${s.daysLeft} days left';
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryDark, _primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard_rounded,
              color: Colors.white70, size: 28),
          const SizedBox(height: 6),
          Text(
            _gbp(big),
            style: GoogleFonts.inter(
              fontSize: 50,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: Text(
              pill,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── One step row ──────────────────────────────────────────────────────────
  Widget _stepRow(WelcomeBonusState s, int i) {
    final bool done = i < s.step;
    final bool next = i == s.step && s.status == 'active';
    final bool locked = !done && !next;

    Map<String, dynamic>? entry;
    for (final e in s.stepLog) {
      if (e['tier'] == i + 1) entry = e;
    }
    final double cashback =
        entry != null && entry['cashback'] is num
            ? (entry['cashback'] as num).toDouble()
            : 0.0;
    final double spent = entry != null && entry['amount'] is num
        ? (entry['amount'] as num).toDouble()
        : 0.0;
    final String label = entry != null ? (entry['label'] ?? '').toString() : '';

    String sub;
    if (done) {
      sub = spent > 0
          ? (label.isNotEmpty ? '${_gbp(spent)} at $label' : _gbp(spent))
          : 'Unlocked';
    } else if (s.isExpired) {
      sub = 'Expired';
    } else {
      final String min = _gbp(s.minSpend).replaceAll('.00', '');
      sub = next ? 'Spend $min or more at any partner' : 'Spend $min or more';
    }

    final Color border = done
        ? const Color(0xFFBBF7D0)
        : (next ? _primary : const Color(0xFFE3E9F0));

    return Opacity(
      opacity: locked ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: done ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: next ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? _green
                    : (next
                        ? const Color(0xFFF0F9FF)
                        : const Color(0xFFF1F3F6)),
                border: Border.all(
                  color: done
                      ? _green
                      : (next ? _primary : const Color(0xFFB6C0CC)),
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 20)
                  : Text(
                      '${i + 1}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: next ? _primary : const Color(0xFF8793A3),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_ordinal(i)} purchase',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: _grey),
                  ),
                  if (done && cashback > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEFCC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+ ${_gbp(cashback)} cashback earned',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB7640A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _gbp(s.tiers[i]),
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: done ? _green : _primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── "Cashback Earned so far" ──────────────────────────────────────────────
  Widget _earnedBox(WelcomeBonusState s) {
    final double totalBack = s.unlocked + s.cashbackDuringBonus;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryDark, _primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cashback Earned so far',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_gbp(s.unlocked)} bonus + '
                  '${_gbp(s.cashbackDuringBonus)} cashback',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          Text(
            _gbp(totalBack),
            style: GoogleFonts.inter(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Info line under the steps ─────────────────────────────────────────────
  Widget _infoBox(WelcomeBonusState s) {
    String text;
    if (s.isCompleted) {
      text = 'Now invite friends. You earn £5 for each friend who completes '
          'three purchases, up to 20 friends.';
    } else if (s.isExpired) {
      text = 'The time to unlock the rest of your welcome bonus has passed. '
          'You still earn cashback on every purchase.';
    } else if (s.step > 0) {
      text = 'You can make your next purchase today. Each one unlocks the '
          'next part of your bonus.';
    } else {
      text = 'You also earn cashback on what you pay each time. Any bonus '
          'not unlocked within 30 days expires.';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _navy,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WelcomeBonusScreen — the full page. Opened from the "welcome_bonus"
//  notification, and from the Welcome Bonus row on the profile screen.
// ─────────────────────────────────────────────────────────────────────────────
class WelcomeBonusScreen extends StatelessWidget {
  const WelcomeBonusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF0D1B3E),
        title: Text(
          'Welcome Bonus',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0D1B3E),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: StreamBuilder<WelcomeBonusState?>(
              stream: welcomeBonusStream(),
              builder: (context, snap) {
                final s = snap.data;
                final bool completed = s != null && s.isCompleted;
                final bool legacy = s != null && !s.isTiered;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (legacy)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            'Your account received its welcome bonus when '
                            'you joined. Invite friends to earn more.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: const Color(0xFF42474E),
                              height: 1.5,
                            ),
                          ),
                        )
                      else
                        const WelcomeBonusProgress(),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0392CA),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            if (completed || legacy) {
                              Navigator.pushNamed(context, '/refer-friend');
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          child: Text(
                            (completed || legacy)
                                ? 'Invite a friend, earn £5'
                                : 'Find a partner nearby',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
