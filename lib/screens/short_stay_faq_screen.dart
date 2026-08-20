// ─────────────────────────────────────────────────────────────────────────────
//  Short Stay help — the 44 guest questions, finally readable by a guest.
//
//  Written 20 August 2026.
//
//  ── WHY THIS IS A SEPARATE SCREEN AND NOT A FILTER ──────────────────────────
//
//  The other Quick Help tiles filter the `faqs` collection by category. This
//  one cannot, for two reasons that are worth stating so nobody "simplifies" it
//  back:
//
//  1. DIFFERENT COLLECTION. Short Stay guest questions live in
//     `short_stay_faqs`, managed from Admin Panel -> Host Management ->
//     Host & Guest FAQs. They were seeded there and no consumer screen has ever
//     read them, so 44 written answers were invisible in the app.
//
//  2. DIFFERENT SHAPE. Those documents use cat / q / a. The `faqs` collection
//     uses category / question / answer. That is deliberate on the admin side
//     — the seeder even says so — but it means the two cannot be poured into
//     one list without a mapping, and a mapping applied on every rebuild of a
//     shared list is where the two would eventually drift.
//
//  Grouping also matters: 44 questions across 7 categories is not a flat list
//  anybody reads. The other tiles filter to a handful; this one needs sections.
//
//  ── HOST QUESTIONS ARE NOT HERE, DELIBERATELY ───────────────────────────────
//
//  `short_stay_host_faqs` is the other half — 35 questions about listing a
//  property, getting paid and damage claims. They belong in goouts_host. A
//  guest asking how to book should not be reading about host payouts.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ShortStayFaqScreen extends StatefulWidget {
  const ShortStayFaqScreen({super.key});

  @override
  State<ShortStayFaqScreen> createState() => _ShortStayFaqScreenState();
}

class _ShortStayFaqScreenState extends State<ShortStayFaqScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);

  /// The order the admin seed defines. Anything the seed adds later that is not
  /// listed here still shows — it lands at the end rather than disappearing,
  /// which is the safer way round for a list somebody else maintains.
  static const List<String> _categoryOrder = <String>[
    'Booking',
    'Cancellations and refunds',
    'Arrival and departure',
    'Damage and deposits',
    'Cashback',
    'Days out',
    'Account and safety',
  ];

  final Set<String> _expanded = <String>{};
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Short Stay help',
            style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w800, color: _primary)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // No where, no orderBy. The collection is small and fixed, and a
        // filter plus a sort would need a composite index — the exact thing
        // that made the main FAQ screen report "No FAQs available" while the
        // collection was full.
        stream: FirebaseFirestore.instance
            .collection('short_stay_faqs')
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color: _primary, strokeWidth: 2));
          }

          // Failed is not empty. See the note on the main FAQ screen.
          if (snap.hasError) {
            return _message(
              icon: Icons.cloud_off_rounded,
              title: 'We could not load these answers.',
              detail: '${snap.error}',
            );
          }

          final List<_Faq> all = (snap.data?.docs ?? const [])
              .map((d) => _Faq.fromDoc(d))
              .where((f) => f.question.isNotEmpty)
              .toList();

          if (all.isEmpty) {
            return _message(
              icon: Icons.help_outline_rounded,
              title: 'No Short Stay answers yet.',
              detail: 'They are added from the GoOuts admin panel.',
            );
          }

          final String q = _query.trim().toLowerCase();
          final List<_Faq> shown = q.isEmpty
              ? all
              : all
                  .where((f) =>
                      f.question.toLowerCase().contains(q) ||
                      f.answer.toLowerCase().contains(q))
                  .toList();

          final Map<String, List<_Faq>> grouped = <String, List<_Faq>>{};
          for (final _Faq f in shown) {
            grouped.putIfAbsent(f.category, () => <_Faq>[]).add(f);
          }
          final List<String> cats = <String>[
            ..._categoryOrder.where(grouped.containsKey),
            ...grouped.keys.where((c) => !_categoryOrder.contains(c)),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              _searchBox(),
              const SizedBox(height: 16),
              if (shown.isEmpty)
                _message(
                  icon: Icons.search_off_rounded,
                  title: 'Nothing matches "${_searchCtrl.text.trim()}".',
                  detail: 'Try a different word.',
                )
              else
                for (final String c in cats) ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      c.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  for (final _Faq f in grouped[c]!) _tile(f),
                  const SizedBox(height: 14),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _searchBox() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: GoogleFonts.inter(fontSize: 14, color: _dark),
          decoration: InputDecoration(
            hintText: 'Search Short Stay questions',
            hintStyle:
                GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );

  Widget _tile(_Faq f) {
    final bool open = _expanded.contains(f.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              open ? _expanded.remove(f.id) : _expanded.add(f.id);
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      f.question,
                      style: GoogleFonts.inter(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: _dark),
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  f.answer,
                  style: GoogleFonts.inter(
                      fontSize: 13.5, height: 1.55, color: Colors.grey[700]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String detail,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 36, color: Colors.grey[400]),
              const SizedBox(height: 10),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 6),
              Text(detail,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ),
      );
}

/// The admin seeder writes cat / q / a, NOT category / question / answer.
///
/// That mapping lives here and nowhere else. Reading `question` off one of
/// these documents returns null and renders an empty row — a failure that
/// looks like missing data rather than a wrong field name, which is how this
/// class of bug keeps surviving in this codebase.
class _Faq {
  const _Faq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final String id;
  final String category;
  final String question;
  final String answer;

  factory _Faq.fromDoc(QueryDocumentSnapshot doc) {
    final Map<String, dynamic> m =
        (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return _Faq(
      id: doc.id,
      category: (m['cat'] ?? m['category'] ?? 'Other').toString(),
      question: (m['q'] ?? m['question'] ?? '').toString(),
      answer: (m['a'] ?? m['answer'] ?? '').toString(),
    );
  }
}
