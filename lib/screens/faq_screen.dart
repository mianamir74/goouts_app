import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _teal = Color(0xFF0A6E8A);

  final List<Map<String, dynamic>> _quickHelp = const [
    {'icon': Icons.account_balance_wallet_rounded, 'label': 'My Wallet'},
    {'icon': Icons.credit_card_rounded, 'label': 'Cashback'},
    {'icon': Icons.delivery_dining_rounded, 'label': 'Food Orders'},
    {'icon': Icons.shield_rounded, 'label': 'Account Security'},
  ];

  final Set<String> _expanded = {};
  String? _selectedCategory; // null = show all

  // Maps Quick Help label → FAQ category field value
  static const Map<String, String> _categoryMap = {
    'My Wallet':        'Wallet',
    'Cashback':         'Cashback',
    'Food Orders':      'Food Orders',
    'Account Security': 'Account Security',
  };

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
        title: Text(
          'FAQ',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: _primary),
        ),
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
            const SizedBox(height: 8),

            Text(
              'How can we help?',
              style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _dark),
            ),

            const SizedBox(height: 14),

            // Search bar
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search_rounded,
                      color: Colors.grey[400], size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Search for articles, guides...',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'QUICK HELP',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 1.0),
            ),
            const SizedBox(height: 10),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemCount: _quickHelp.length,
              itemBuilder: (context, i) {
                final item = _quickHelp[i];
                final label = item['label'] as String;
                final category = _categoryMap[label];
                final isActive = _selectedCategory == category;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = isActive ? null : category;
                    _expanded.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isActive ? _primary : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.2)
                                : const Color(0xFFD6EEF8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item['icon'] as IconData,
                              color: isActive ? Colors.white : _teal,
                              size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : _dark),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                Text(
                  'FREQUENT QUESTIONS',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                      letterSpacing: 1.0),
                ),
                if (_selectedCategory != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedCategory = null;
                      _expanded.clear();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCategory!,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _primary),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.close_rounded, size: 12, color: _primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('faqs')
                  .where('isActive', isEqualTo: true)
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
                    ),
                  );
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No FAQs available at this time.',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final allDocs = snap.data!.docs;
                final docs = _selectedCategory == null
                    ? allDocs
                    : allDocs.where((d) {
                        final data = d.data() as Map<String, dynamic>;
                        return (data['category'] as String?) == _selectedCategory;
                      }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No FAQs in this category yet.',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[400]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return Column(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final question = data['question'] as String? ?? '';
                    final answer = data['answer'] as String? ?? '';
                    final id = doc.id;
                    final isOpen = _expanded.contains(id);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isOpen) {
                          _expanded.remove(id);
                        } else {
                          _expanded.add(id);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: isOpen
                              ? Border.all(color: _primary.withValues(alpha: 0.25), width: 1)
                              : null,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      question,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: isOpen ? FontWeight.w700 : FontWeight.w500,
                                          color: _dark),
                                    ),
                                  ),
                                  Icon(
                                    isOpen
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: isOpen ? _primary : Colors.grey,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                            if (isOpen) ...[
                              Divider(height: 1, color: Colors.grey[100]),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: Text(
                                  answer,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      height: 1.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // Still need help banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _teal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Still need help?',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Our experts are available 24/7 to assist you with any inquiries.',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/contact-support'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        color: _teal, size: 18),
                    label: Text(
                      'Live Chat',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _teal),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB3E0F2),
                      minimumSize: const Size(double.infinity, 48),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone_rounded,
                        color: Colors.white, size: 18),
                    label: Text(
                      'Call Support',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(
                          color: Colors.white, width: 1.5),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) => Container(
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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(context, Icons.home_rounded, 'Home', '/home'),
                _navItem(context, Icons.account_balance_wallet_rounded,
                    'Wallet', '/wallet'),
                _navItemActive(),
                _navItem(
                    context, Icons.person_rounded, 'Profile', '/profile'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(BuildContext context, IconData icon, String label,
          String route) =>
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
