import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class LinkCardDetailsScreen extends StatefulWidget {
  const LinkCardDetailsScreen({super.key});

  @override
  State<LinkCardDetailsScreen> createState() => _LinkCardDetailsScreenState();
}

class _LinkCardDetailsScreenState extends State<LinkCardDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardholderController = TextEditingController();

  bool _obscureCvv = true;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardholderController.dispose();
    super.dispose();
  }

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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildStepBadge(),
                      const SizedBox(height: 24),
                      _buildCardPreview(),
                      const SizedBox(height: 32),
                      _buildSectionTitle(),
                      const SizedBox(height: 20),
                      _buildInputLabel('Cardholder Name'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _cardholderController,
                        hint: 'e.g. Alex Sterling',
                        icon: Icons.person_outline_rounded,
                        inputType: TextInputType.name,
                      ),
                      const SizedBox(height: 16),
                      _buildInputLabel('Card Number'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _cardNumberController,
                        hint: '0000  0000  0000  0000',
                        icon: Icons.credit_card_rounded,
                        inputType: TextInputType.number,
                        formatter: _CardNumberFormatter(),
                        maxLength: 22,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('Expiry Date'),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _expiryController,
                                  hint: 'MM / YY',
                                  icon: Icons.calendar_today_rounded,
                                  inputType: TextInputType.number,
                                  formatter: _ExpiryFormatter(),
                                  maxLength: 5,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('CVV'),
                                const SizedBox(height: 8),
                                _buildCvvField(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _buildCardTypeRow(),
                      const SizedBox(height: 32),
                    ],
                  ),
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
            onTap: () => Navigator.of(context).pop(),
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
              'Link Debit / Credit Card',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBadge() {
    return Row(
      children: [
        _buildDot(filled: true),
        _buildDot(filled: true),
        _buildDot(filled: false),
        _buildDot(filled: false),
      ],
    );
  }

  Widget _buildDot({required bool filled}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: filled ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFF0392CA) : const Color(0xFFD8D8E8),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildCardPreview() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _cardNumberController,
      builder: (context, value, _) {
        final rawNumber = value.text.replaceAll(' ', '');
        final displayNumber = rawNumber.isEmpty
            ? '••••  ••••  ••••  ••••'
            : value.text.padRight(22, '•');
        final displayName = _cardholderController.text.isEmpty
            ? 'YOUR NAME'
            : _cardholderController.text.toUpperCase();
        final displayExpiry =
            _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text;

        return Container(
          width: double.infinity,
          height: 190,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0392CA), Color(0xFF015F8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0392CA).withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox.shrink(),
                        const Icon(Icons.wifi_rounded,
                            color: Colors.white, size: 22),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      displayNumber,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CARDHOLDER',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              displayName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EXPIRES',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              displayExpiry,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'VISA',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your card information securely.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF8A8A9A),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A1A2E),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType inputType,
    TextInputFormatter? formatter,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      inputFormatters: [
        if (formatter != null) formatter,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1A1A2E),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFFBBBBCC),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFAAAAAA), size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF0392CA), width: 1.5),
        ),
        counterText: '',
      ),
    );
  }

  Widget _buildCvvField() {
    return TextFormField(
      controller: _cvvController,
      keyboardType: TextInputType.number,
      obscureText: _obscureCvv,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF1A1A2E),
      ),
      decoration: InputDecoration(
        hintText: '•••',
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFFBBBBCC),
        ),
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: Color(0xFFAAAAAA), size: 20),
        suffixIcon: GestureDetector(
          onTap: () => setState(() => _obscureCvv = !_obscureCvv),
          child: Icon(
            _obscureCvv ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: const Color(0xFFAAAAAA),
            size: 18,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF0392CA), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCardTypeRow() {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 14, color: Color(0xFFAAAAAA)),
        const SizedBox(width: 6),
        Text(
          'We accept Visa and Mastercard only.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFFAAAAAA),
          ),
        ),
      ],
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
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0392CA),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.credit_card_rounded,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    'Add Card',
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
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFB0B0C0)),
              const SizedBox(width: 6),
              Text(
                'Secure AES-256 Encryption • Powered by Stripe',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFFB0B0C0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('  ');
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
