import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/message_service.dart';
import '../services/user_fcm_service.dart';
import '../widgets/promo_overlay.dart';
import '../widgets/goouts_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _displayName = '';
  String? _photoUrl;
  bool _loadingUser = true;
  bool _uploadingPhoto = false;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
  final _msgService = MessageService();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _markOnboardingComplete();
    // Ask for notification permission on first launch (shows branded dialog first)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UserFcmService.instance.askPermissionWithRationale(context);
      }
    });
  }

  Future<void> _markOnboardingComplete() async {
    try {
      await UserService().updateUser({'onboardingComplete': true});
    } catch (_) {}
  }

  Future<void> _loadUserName() async {
    try {
      final data = await UserService().getCurrentUser();
      if (data != null && mounted) {
        final fullName = (data['fullName'] as String? ?? '').trim();
        setState(() {
          _displayName = fullName.isNotEmpty ? fullName : '';
          _photoUrl = data['photoUrl'] as String?;
          _loadingUser = false;
        });
      } else {
        if (mounted) setState(() => _loadingUser = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(
                    source: ImageSource.camera, imageQuality: 80);
                if (picked != null) _uploadPhoto(File(picked.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (picked != null) _uploadPhoto(File(picked.path));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(File file) async {
    setState(() => _uploadingPhoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _uploadingPhoto = false);
        return;
      }
      final ref = FirebaseStorage.instance
          .ref()
          .child('users/$uid/profile_photo.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'photoUrl': url}, SetOptions(merge: true));
      if (mounted) {
        setState(() { _photoUrl = url; _uploadingPhoto = false; });
        GoOutsSheet.success(context,
          title: 'Photo Updated',
          message: 'Your profile photo has been saved.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        GoOutsSheet.error(context,
          title: 'Upload Failed',
          message: 'Could not save your photo. Please check your connection and try again.',
        );
      }
    }
  }

  final List<Map<String, dynamic>> _services = [
    {'icon': Icons.coffee_rounded, 'label': 'Cafes', 'route': 'Cafes'},
    {'icon': Icons.restaurant_rounded, 'label': 'Restaurants', 'route': 'Restaurants'},
    {'icon': Icons.fastfood_rounded, 'label': 'Fast Food', 'route': 'Fast Food'},
    {'icon': Icons.sports_bar_rounded, 'label': 'Pubs', 'route': 'Pubs'},
    {'icon': Icons.nightlife_rounded, 'label': 'Clubs', 'route': 'Clubs'},
    {'icon': Icons.music_note_rounded, 'label': 'Music', 'route': 'Music'},
    {'icon': Icons.theater_comedy_rounded, 'label': 'Comedy', 'route': 'Comedy'},
  ];

  final List<Map<String, dynamic>> _trending = [
    {
      'name': 'Monmouth Coffee Co.',
      'type': 'Café',
      'address': '2 Park St, Borough Market, SE1 9AB',
      'cashback': '12% Cashback',
      'rating': '4.9',
      'reviews': '3.1k',
      'color': const Color(0xFF5C3D1E),
      'icon': Icons.coffee_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=200&q=80',
      'category': 'Café',
      'visits': '18.4k+ visits',
      'phone': '020 7232 3010',
      'cashback_pct': '12%',
      'desc': 'One of London\'s most celebrated independent coffee roasters, beloved for its single-origin brews served in a rustic Borough Market setting.',
    },
    {
      'name': 'Dishoom Covent Garden',
      'type': 'Restaurant',
      'address': '12 Upper St Martin\'s Lane, WC2H 9FB',
      'cashback': '10% Cashback',
      'rating': '4.8',
      'reviews': '8.4k',
      'color': const Color(0xFF3B1F0A),
      'icon': Icons.restaurant_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=200&q=80',
      'category': 'Indian Restaurant',
      'visits': '32.5k+ visits',
      'phone': '020 7420 9320',
      'cashback_pct': '10%',
      'desc': 'Inspired by the iconic Irani cafés of Bombay, Dishoom serves extraordinary food all day long. Famous for its black dal and bacon naan.',
    },
    {
      'name': 'Fabric',
      'type': 'Nightclub',
      'address': '77a Charterhouse St, Farringdon, EC1M 6HJ',
      'cashback': '8% Cashback',
      'rating': '4.7',
      'reviews': '5.2k',
      'color': const Color(0xFF1A0533),
      'icon': Icons.nightlife_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1566737236500-c8ac43014a67?w=200&q=80',
      'category': 'Nightclub',
      'visits': '42.1k+ visits',
      'phone': '020 7336 8898',
      'cashback_pct': '8%',
      'desc': 'One of the world\'s most respected nightclubs, Fabric has been a cornerstone of London\'s electronic music scene since 1999.',
    },
    {
      'name': 'The Churchill Arms',
      'type': 'Pub',
      'address': '119 Kensington Church St, W8 7LN',
      'cashback': '15% Cashback',
      'rating': '4.8',
      'reviews': '2.6k',
      'color': const Color(0xFF1A3A1A),
      'icon': Icons.sports_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1525268323446-0505b6fe7778?w=200&q=80',
      'category': 'Historic Pub',
      'visits': '24.6k+ visits',
      'phone': '020 7727 4242',
      'cashback_pct': '15%',
      'desc': 'A legendary Kensington pub draped in hanging flower baskets and festive lights, known for its affordable Thai food and real ales.',
    },
    {
      'name': 'Sketch',
      'type': 'Restaurant & Bar',
      'address': '9 Conduit St, Mayfair, W1S 2XG',
      'cashback': '12% Cashback',
      'rating': '4.7',
      'reviews': '4.9k',
      'color': const Color(0xFF1C1C2E),
      'icon': Icons.wine_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=200&q=80',
      'category': 'Restaurant & Bar',
      'visits': '14.8k+ visits',
      'phone': '020 7659 4500',
      'cashback_pct': '12%',
      'desc': 'A spectacular collection of unique restaurants, bars, and a patisserie housed in an 18th-century townhouse in Mayfair.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return PromoOverlayWrapper(
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F4F7),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildGreeting()),
              SliverToBoxAdapter(child: _buildVirtualCard()),
              SliverToBoxAdapter(child: _buildServices()),
              SliverToBoxAdapter(child: _buildSpecialOffers()),
              SliverToBoxAdapter(child: _buildTrending()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Greeting — truly centred on full screen width
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_greeting,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: const Color(0xFF0392CA))),
                _loadingUser
                    ? Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: 110,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : Text(
                        _displayName.isNotEmpty ? _displayName : 'Welcome!',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0D1B3E))),
              ],
            ),
            // Profile pic left + icons right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _pickAndUploadPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.grey[300],
                        child: ClipOval(
                          child: _uploadingPhoto
                              ? const SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF0392CA)),
                                    ),
                                  ),
                                )
                              : _photoUrl != null && _photoUrl!.isNotEmpty
                                  ? Image.network(
                                      _photoUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0392CA),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Bell icon (notifications)
                StreamBuilder<int>(
                      stream: _msgService.unreadNotificationsStream(),
                      builder: (context, snap) {
                        final count = snap.data ?? 0;
                        return GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/notifications'),
                          child: Stack(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 6)
                                  ],
                                ),
                                child: const Icon(Icons.notifications_outlined,
                                    color: Colors.black87, size: 22),
                              ),
                              if (count > 0)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                        color: Colors.red, shape: BoxShape.circle),
                                    child: Center(
                                      child: Text(
                                        count > 9 ? '9+' : '$count',
                                        style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
              ],
            ),
          ],
        ),
      );

  Widget _buildGreeting() => const SizedBox.shrink();

  Widget _buildVirtualCard() => Padding(
        padding: const EdgeInsets.all(16),
        child: AspectRatio(
          aspectRatio: 85.60 / 53.98,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0392CA), Color(0xFF026899), Color(0xFF014F75)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0392CA).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GoOuts',
                            style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        Text('Virtual Card',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.75),
                                letterSpacing: 0.5)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.6), width: 1.5),
                      ),
                      child: Transform.rotate(
                        angle: 1.5708,
                        child: const Icon(Icons.wifi_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text('CARD NUMBER',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.white,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 1)),
                        ])),
                const SizedBox(height: 4),
                Text('4821  5567  8901  2345',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 1)),
                        ])),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName.isNotEmpty ? _displayName.toUpperCase() : 'CARD HOLDER',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8,
                                shadows: [
                                  Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 1)),
                                ])),
                        Text('12/26',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                shadows: [
                                  Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 1)),
                                ])),
                      ],
                    ),
                    const Spacer(),
                    Text('VISA',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildServices() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Text('Services',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D1B3E))),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/services'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Show All',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0392CA))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _services.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final s = _services[index];
                  return GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/nearby',
                        arguments: {'category': s['route'] as String}),
                    child: SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.07),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(s['icon'] as IconData,
                                color: const Color(0xFF0392CA), size: 28),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 32,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                s['label'] as String,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D1B3E),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _buildSpecialOffers() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Special Offers',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D1B3E))),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/special-offers'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Show All',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0392CA))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _offerCard(
                    context,
                    title: '20% Off First Visit',
                    subtitle: 'Dishoom Covent Garden',
                    color: const Color(0xFF3B1F0A),
                    partner: {
                      'name': 'Dishoom Covent Garden',
                      'type': 'Restaurant',
                      'address': '12 Upper St Martin\'s Lane, WC2H 9FB',
                      'cashback': '10% Cashback',
                      'cashback_pct': '10%',
                      'rating': '4.8',
                      'reviews': '8.4k',
                      'visits': '32.5k+ visits',
                      'phone': '020 7420 9320',
                      'category': 'Indian Restaurant',
                      'imageUrl': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80',
                      'desc': 'Inspired by the iconic Irani cafés of Bombay, Dishoom serves extraordinary food all day long. Famous for its black dal and bacon naan.',
                    },
                  ),
                  const SizedBox(width: 12),
                  _offerCard(
                    context,
                    title: 'Happy Hour 30% Off',
                    subtitle: 'Aqua Shard · Level 31',
                    color: const Color(0xFF0A2A4A),
                    partner: {
                      'name': 'Aqua Shard',
                      'type': 'Restaurant & Bar',
                      'address': '31st Floor, The Shard, SE1 9RY',
                      'cashback': '8% Cashback',
                      'cashback_pct': '8%',
                      'rating': '4.6',
                      'reviews': '6.1k',
                      'visits': '19.2k+ visits',
                      'phone': '020 3011 1256',
                      'category': 'Restaurant & Bar',
                      'imageUrl': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80',
                      'desc': 'Breathtaking views of London from the 31st floor of The Shard. Modern British cuisine with an impressive cocktail menu.',
                    },
                  ),
                  const SizedBox(width: 12),
                  _offerCard(
                    context,
                    title: 'VIP Entry Deal',
                    subtitle: 'XOYO Shoreditch',
                    color: const Color(0xFF1A0533),
                    partner: {
                      'name': 'XOYO Shoreditch',
                      'type': 'Nightclub',
                      'address': '32-37 Cowper St, Shoreditch, EC2A 4AP',
                      'cashback': '8% Cashback',
                      'cashback_pct': '8%',
                      'rating': '4.6',
                      'reviews': '3.9k',
                      'visits': '28.3k+ visits',
                      'phone': '020 7608 2878',
                      'category': 'Nightclub',
                      'imageUrl': 'https://images.unsplash.com/photo-1566737236500-c8ac43014a67?w=800&q=80',
                      'desc': 'One of East London\'s most iconic nightclubs. XOYO hosts world-class DJs every Friday and Saturday night in Shoreditch.',
                    },
                  ),
                  const SizedBox(width: 12),
                  _offerCard(
                    context,
                    title: 'Free Coffee',
                    subtitle: 'Monmouth Coffee Co.',
                    color: const Color(0xFF2C1A08),
                    partner: {
                      'name': 'Monmouth Coffee Co.',
                      'type': 'Café',
                      'address': '2 Park St, Borough Market, SE1 9AB',
                      'cashback': '12% Cashback',
                      'cashback_pct': '12%',
                      'rating': '4.9',
                      'reviews': '3.1k',
                      'visits': '18.4k+ visits',
                      'phone': '020 7232 3010',
                      'category': 'Café',
                      'imageUrl': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=800&q=80',
                      'desc': 'One of London\'s most celebrated independent coffee roasters, beloved for its single-origin brews served in a rustic Borough Market setting.',
                    },
                  ),
                  const SizedBox(width: 12),
                  _offerCard(
                    context,
                    title: '2-for-1 Cocktails',
                    subtitle: 'Cahoots · Soho',
                    color: const Color(0xFF0D3B2E),
                    partner: {
                      'name': 'Cahoots',
                      'type': 'Bar',
                      'address': '13 Kingly Court, Carnaby, W1B 5PW',
                      'cashback': '10% Cashback',
                      'cashback_pct': '10%',
                      'rating': '4.7',
                      'reviews': '2.8k',
                      'visits': '15.6k+ visits',
                      'phone': '020 3846 3190',
                      'category': 'Cocktail Bar',
                      'imageUrl': 'https://images.unsplash.com/photo-1525268323446-0505b6fe7778?w=800&q=80',
                      'desc': 'A 1940s underground tube station turned into a vintage cocktail bar. Cahoots serves immersive experiences and incredible drinks in Soho.',
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _offerCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color color,
    required Map<String, dynamic> partner,
  }) {
    final imageUrl = partner['imageUrl'] as String?;
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/partner-details', arguments: partner),
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Venue photo ──────────────────────────
              if (imageUrl != null)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: color),
                )
              else
                Container(color: color),

              // ── Dark gradient overlay (bottom) ───────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.80),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),

              // ── Offer badge — top left ───────────────
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A7A3E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),

              // ── Partner name + category — bottom ─────
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.local_offer_rounded,
                            color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          partner['cashback'] as String? ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrending() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                Text('Trending',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D1B3E))),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/nearby'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Show All',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0392CA))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._trending.map((v) => _trendingCard(v)),
          ],
        ),
      );

  Widget _trendingCard(Map<String, dynamic> v) => GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/partner-details', arguments: v),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: v['color'] as Color),
                          if (v['imageUrl'] != null)
                            Image.network(
                              v['imageUrl'] as String,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                v['icon'] as IconData? ?? Icons.store_rounded,
                                color: Colors.white38, size: 32),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D6E3A),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        v['cashback'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(v['name'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0D1B3E)),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (v['type'] != null)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F3FB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(v['type'] as String,
                                maxLines: 1,
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0392CA))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(v['address'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 3),
                        Text(
                            '${v['rating']} (${v['reviews']})',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 22),
            ],
          ),
        ),
      );

  Widget _buildBottomNav() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            const routes = [
              '/home',
              '/explore',
              '/wallet',
              '/activity',
              '/profile'
            ];
            if (i != 0) Navigator.pushNamed(context, routes[i]);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0392CA),
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.explore_rounded), label: 'Explore'),
            BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Wallet'),
            BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      );
}
