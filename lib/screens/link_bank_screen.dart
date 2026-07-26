import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LinkBankScreen extends StatefulWidget {
  const LinkBankScreen({super.key});

  @override
  State<LinkBankScreen> createState() => _LinkBankScreenState();
}

class _LinkBankScreenState extends State<LinkBankScreen> {
  int _selectedBank = -1;

  final List<_BankItem> _banks = const [
    _BankItem(
        name: 'Barclays',
        subtitle: 'Personal & Business',
        color: Color(0xFF00AEEF)),
    _BankItem(
        name: 'HSBC',
        subtitle: 'Personal Banking',
        color: Color(0xFFDB0011)),
    _BankItem(
        name: 'Lloyds Bank',
        subtitle: 'Personal & Business',
        color: Color(0xFF024731)),
    _BankItem(
        name: 'NatWest',
        subtitle: 'Personal Banking',
        color: Color(0xFF42145F)),
    _BankItem(
        name: 'Santander',
        subtitle: 'Personal & Business',
        color: Color(0xFFEC0000)),
    _BankItem(
        name: 'Monzo',
        subtitle: 'Digital Bank',
        color: Color(0xFFFF6E57)),
    _BankItem(
        name: 'Starling Bank',
        subtitle: 'Digital Bank',
        color: Color(0xFF6935D3)),
    _BankItem(
        name: 'Halifax',
        subtitle: 'Personal Banking',
        color: Color(0xFF009AC7)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildProgressSteps(),
                    const SizedBox(height: 24),
                    _buildIllustration(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(),
                    const SizedBox(height: 16),
                    _buildBankList(),
                    const SizedBox(height: 12),
                    _buildSearchOtherBanks(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.pushReplacementNamed(context, '/registration-success');
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Link Bank Account',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0392CA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step 03',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0392CA),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    final steps = [
      ('Account Created', true),
      ('Link a Card', true),
      ('Link Your Bank', false),
      ('First Purchase', false),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final step = entry.value;
          final isDone = step.$2;
          final isCurrent = idx == 2;

          return Row(
            children: [
              _buildStepChip(
                label: step.$1,
                isDone: isDone,
                isCurrent: isCurrent,
              ),
              if (idx < steps.length - 1)
                Container(
                  width: 16,
                  height: 1,
                  color: isDone
                      ? const Color(0xFF0392CA)
                      : const Color(0xFFD8D8E8),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepChip({
    required String label,
    required bool isDone,
    required bool isCurrent,
  }) {
    Color bg;
    Color textColor;
    if (isDone && !isCurrent) {
      bg = const Color(0xFF0392CA).withValues(alpha: 0.12);
      textColor = const Color(0xFF0392CA);
    } else if (isCurrent) {
      bg = const Color(0xFF0392CA);
      textColor = Colors.white;
    } else {
      bg = const Color(0xFFF0F0F8);
      textColor = const Color(0xFFAAAAAA);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          if (isDone && !isCurrent) ...[
            Icon(Icons.check_circle_rounded,
                size: 12, color: const Color(0xFF0392CA)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/slide2a_illustration.webp',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stack) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0392CA).withValues(alpha: 0.08),
                  const Color(0xFF0392CA).withValues(alpha: 0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0392CA).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    size: 30,
                    color: Color(0xFF0392CA),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Power your GoOuts Virtual Card',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0392CA),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Link once — pay anywhere. When you pay with your GoOuts Virtual Card, funds are pulled automatically from your bank and cashback is awarded instantly.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF8A8A9A),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Bank',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'No top up needed. The funds will be obtained automatically when you select to pay.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A2E),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFF0392CA)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your GoOuts Virtual Card is powered by your linked bank. Every purchase at a GoOuts partner earns you instant cashback with no pre-loading required.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF1A1A2E),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankList() {
    return Column(
      children: _banks.asMap().entries.map((entry) {
        final idx = entry.key;
        final bank = entry.value;
        final isSelected = _selectedBank == idx;

        return GestureDetector(
          onTap: () => setState(() => _selectedBank = idx),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0392CA)
                    : const Color(0xFFE8E8F0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF0392CA).withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bank.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      bank.name.substring(0, 1),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: bank.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bank.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      Text(
                        bank.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF8A8A9A),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0392CA)
                          : const Color(0xFFD0D0E0),
                      width: 2,
                    ),
                    color: isSelected
                        ? const Color(0xFF0392CA)
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchOtherBanks() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE8E8F0),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 20, color: Color(0xFF0392CA)),
            const SizedBox(width: 12),
            Text(
              'Search for another bank...',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF8A8A9A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _selectedBank >= 0
                  ? () => Navigator.pushReplacementNamed(context, '/home')
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0392CA),
                disabledBackgroundColor: const Color(0xFFCCE8F5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_rounded,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Connect Bank',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankItem {
  final String name;
  final String subtitle;
  final Color color;

  const _BankItem({
    required this.name,
    required this.subtitle,
    required this.color,
  });
}
