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
    {'icon': Icons.swap_horiz_rounded, 'label': 'Shares'},
    {'icon': Icons.credit_card_rounded, 'label': 'Cashback'},
    {'icon': Icons.shield_rounded, 'label': 'Account Security'},
  ];

  final List<Map<String, String>> _faqs = const [
    {
      'q': 'How to claim my £2 bonus?',
      'a':
          'Your £2 welcome bonus is automatically added to your wallet once you complete your first transaction using your GoOuts card. Simply make any purchase at a participating partner and the bonus will appear within 24 hours.',
    },
    {
      'q': 'How long do shares take?',
      'a':
          'Cashback shares are credited to your wallet within 14 days of a confirmed purchase. This processing window allows time for the merchant to confirm the transaction. You can track the status in your Wallet → Cashback section.',
    },
    {
      'q': 'Why is my account pending verification?',
      'a':
          'Your account is under KYC (Know Your Customer) review. This usually takes 1–2 business days. Make sure your ID document is clear and matches your registered name. You will receive a notification once verification is complete.',
    },
    {
      'q': 'Can I change my registered phone number?',
      'a':
          'Yes. Go to Profile → Account Settings → Personal Information and tap on your phone number to update it. You will need to verify the new number with a one-time OTP before the change takes effect.',
    },
    {
      'q': 'Can I refer a partner?',
      'a':
          'Absolutely — and we\'d love that! If you know a business that would be a great fit for GoOuts, go ahead and refer them. Once they\'re on board and live on the platform, we\'ll add £25 to your wallet as a thank-you. The best part? There\'s no limit — you can refer as many partners as you like and earn £25 for every single one.',
    },
    {
      'q': 'How does instant cashback work?',
      'a':
          'Every time you pay at a GoOuts partner venue using your GoOuts virtual card, cashback is credited to your wallet the moment the payment is confirmed — no waiting, no claiming. The cashback percentage varies by partner and is shown on the partner\'s page before you pay.',
    },
    {
      'q': 'Is there a minimum cashback amount to use?',
      'a':
          'No minimum at all. Any amount in your wallet — even a few pence — can be used towards your next payment at a partner venue. Simply choose how much to apply when you tap Pay.',
    },
    {
      'q': 'Why is my wallet balance different from my cashback balance?',
      'a':
          'Your wallet balance is the total amount available to spend right now. Your cashback balance is the running total of all cashback you have ever earned. The two can differ if you have spent some of your cashback or received other credits into your wallet.',
    },
    {
      'q': 'What is the GoOuts virtual card?',
      'a':
          'Your GoOuts virtual card is a digital debit card that works at any GoOuts partner venue. It is linked securely to your bank account via Open Banking — there is no money sitting on the card itself. When you pay, the exact amount is swept from your bank in real time, keeping everything safe and instant.',
    },
    {
      'q': 'Is my bank account safe when I pay with GoOuts?',
      'a':
          'Yes, completely. GoOuts uses Open Banking and Variable Recurring Payments (VRP) — the same regulated technology used by major UK banks. We never store your bank login details and each payment requires your authorisation. Your money only moves when you choose to pay.',
    },
    {
      'q': 'Why was my payment declined?',
      'a':
          'Payments can be declined for a few reasons: your bank did not authorise the transaction, there were insufficient funds in your linked bank account, or you have reached a daily spending limit set by your bank. Check your bank app for details and try again, or contact your bank if the issue continues.',
    },
    {
      'q': 'What documents do I need to verify my identity?',
      'a':
          'You will need a valid government-issued photo ID — a passport or driving licence works perfectly. You will also need to take a quick selfie so we can match your face to the document. Make sure your ID is not expired and that all four corners are visible in the photo.',
    },
    {
      'q': 'How long does KYC verification take?',
      'a':
          'In most cases, verification is completed within a couple of minutes. Occasionally our team may need to review your documents manually, which can take up to 2 business days. You will receive a notification as soon as a decision is made.',
    },
    {
      'q': 'Why was my ID rejected?',
      'a':
          'The most common reasons are a blurry or dark photo, an expired document, or a name that does not match your GoOuts profile. Make sure you are in good lighting, hold the document flat and steady, and use the exact name shown on your ID when registering. You can re-submit directly from the Profile screen.',
    },
    {
      'q': 'How do I find GoOuts partner venues near me?',
      'a':
          'Open the Explore tab and tap "Near You". GoOuts will show you all partner venues within your area on a map and as a list. You can filter by category — restaurants, bars, cafés, and more — to find exactly what you\'re in the mood for.',
    },
    {
      'q': 'Why is a venue not giving me cashback?',
      'a':
          'Cashback is only available at officially verified GoOuts partner venues. If a venue is not showing a cashback rate on its partner page, it is not currently part of the programme. You can suggest a venue to us and we\'ll do our best to get them on board.',
    },
    {
      'q': 'What happens to my cashback if I return an item?',
      'a':
          'If a purchase is refunded or reversed, any cashback earned on that transaction will be reclaimed from your wallet. This ensures cashback is only kept for genuine completed purchases. If you believe a clawback was made in error, please contact our support team.',
    },
    {
      'q': 'What is a GoOuts PIN and why do I need it?',
      'a':
          'Your GoOuts PIN is a 4-digit code that protects your account. It is required any time you want to edit your personal information, saved addresses, or security settings. Think of it as a second layer of protection — even if someone has access to your phone, they cannot change your details without your PIN.',
    },
    {
      'q': 'What should I do if I lose my phone?',
      'a':
          'Act quickly — go to Profile → Security and freeze your virtual card immediately from another device or ask someone to help you. Then contact our support team so we can flag your account. Once you have your new device, simply log back in with your registered phone number and OTP.',
    },
    {
      'q': 'Can I have more than one GoOuts account?',
      'a':
          'No — GoOuts allows one account per person. Each account is tied to a verified identity and phone number. Creating multiple accounts is against our terms and may result in all accounts being suspended. If you are having trouble accessing your account, our support team is happy to help.',
    },
    {
      'q': 'How does GoOuts process my payment at the till?',
      'a':
          'Before you tap your GoOuts card, you confirm exactly how much cashback and wallet balance you want to use on the payment sheet. When you tap your GoOuts Virtual Card at the till, our system reads those confirmed details instantly.\n\nThe till requests the full bill amount — say £150. GoOuts approves the full £150 to the merchant, so the partner always receives every penny. Behind the scenes, our system only sweeps the remaining balance from your bank — for example, if you used £100 cashback and £50 wallet, your bank is charged nothing. If you used £100 cashback and no wallet, your bank is charged £50.\n\nNothing moves without your confirmation. If you close the payment sheet without completing it, no charge is made, no balance is updated, and no transaction is recorded.',
    },
  ];

  final Set<int> _expanded = {};

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
                      color: Colors.black.withOpacity(0.05),
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
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
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
                        decoration: const BoxDecoration(
                          color: Color(0xFFD6EEF8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData,
                            color: _teal, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _dark),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 22),

            Text(
              'FREQUENT QUESTIONS',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 1.0),
            ),
            const SizedBox(height: 10),

            ...List.generate(_faqs.length, (i) {
              final faq = _faqs[i];
              final isOpen = _expanded.contains(i);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isOpen) {
                    _expanded.remove(i);
                  } else {
                    _expanded.add(i);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: isOpen
                        ? Border.all(
                            color: _primary.withOpacity(0.25), width: 1)
                        : null,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                faq['q']!,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: isOpen
                                        ? FontWeight.w700
                                        : FontWeight.w500,
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
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Text(
                            faq['a']!,
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
            }),

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
                        color: Colors.white.withOpacity(0.85),
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
                color: Colors.black.withOpacity(0.06),
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
