import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  // ── Location ───────────────────────────────────────────
  final _locationService = LocationService();
  // ignore: unused_field
  Position? _userPosition;
  // ignore: unused_field
  bool _locationGranted = false;
  // ignore: unused_field
  bool _locationPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final permission = await _locationService.checkAndRequestPermission();

    if (permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationPermanentlyDenied = true);
      _showLocationSheet(permanentlyDenied: true);
      return;
    }

    if (permission == LocationPermission.denied) {
      // Show explanation sheet, then request
      if (mounted) _showLocationSheet(permanentlyDenied: false);
      return;
    }

    // Permission granted — get position
    final pos = await _locationService.getCurrentPosition();
    if (mounted) {
      setState(() {
        _userPosition = pos;
        _locationGranted = pos != null;
      });
    }
  }

  void _showLocationSheet({required bool permanentlyDenied}) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F3FB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded,
                  color: Color(0xFF0392CA), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              permanentlyDenied
                  ? 'Location Access Blocked'
                  : 'Enable Location',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0D1B3E)),
            ),
            const SizedBox(height: 10),
            Text(
              permanentlyDenied
                  ? 'Location was blocked. Please open Settings and allow location access for GoOuts to show venues near you.'
                  : 'GoOuts uses your location to show you the best places nearby and personalise your cashback offers.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (permanentlyDenied) {
                    await _locationService.openLocationSettings();
                  } else {
                    final pos = await _locationService.getCurrentPosition();
                    if (mounted) {
                      setState(() {
                        _userPosition = pos;
                        _locationGranted = pos != null;
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0392CA),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  permanentlyDenied ? 'Open Settings' : 'Allow Location',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Not Now',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey[500])),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns distance label for a venue if location is available.

  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _bg = Color(0xFFF2F4F7);

  // ── CAFES ──────────────────────────────────────────────
  final List<Map<String, dynamic>> _cafes = [
    {
      'name': 'Monmouth Coffee Co.',
      'category': 'Café',
      'rating': '4.9',
      'visits': '18.4k+ visits',
      'address': '2 Park St, Borough Market, SE1 9AB',
      'lat': 51.5055, 'lon': -0.0903,
      'phone': '020 7232 3010',
      'cashback': '12%',
      'color': const Color(0xFF5C3D1E),
      'icon': Icons.coffee_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=400&q=75',
      'desc': 'One of London\'s most celebrated independent coffee roasters, beloved for its single-origin brews served in a rustic Borough Market setting.',
    },
    {
      'name': 'Workshop Coffee',
      'category': 'Specialty Café',
      'rating': '4.8',
      'visits': '9.1k+ visits',
      'address': '27 Shelton St, Covent Garden, WC2H 9EQ',
      'lat': 51.5143, 'lon': -0.1245,
      'phone': '020 7253 5754',
      'cashback': '10%',
      'color': const Color(0xFF2C3E50),
      'icon': Icons.coffee_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&q=75',
      'desc': 'Award-winning specialty coffee roaster with a passion for precision brewing and ethically sourced beans from around the world.',
    },
    {
      'name': 'Attendant Coffee',
      'category': 'Café',
      'rating': '4.8',
      'visits': '7.3k+ visits',
      'address': '74 Great Titchfield St, Fitzrovia, W1W 7QP',
      'phone': '020 7580 6089',
      'cashback': '15%',
      'color': const Color(0xFF4A2C17),
      'icon': Icons.coffee_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1442512595331-e89e73853f31?w=400&q=75',
      'desc': 'A unique café housed in a restored Victorian underground public toilet — now serving exceptional coffee and brunch in a truly one-of-a-kind space.',
    },
    {
      'name': 'Notes Coffee Roasters',
      'category': 'Café & Bar',
      'rating': '4.7',
      'visits': '6.8k+ visits',
      'address': '31 St Martin\'s Lane, Covent Garden, WC2N 4ER',
      'phone': '020 7240 0424',
      'cashback': '12%',
      'color': const Color(0xFF1A2A1A),
      'icon': Icons.coffee_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1453614512568-c4024d13c247?w=400&q=75',
      'desc': 'A beloved London roastery and café known for its natural wines, craft beers, and exceptional seasonal filter coffee menus.',
    },
    {
      'name': 'Leyas',
      'category': 'Café & Brunch',
      'rating': '4.6',
      'visits': '4.2k+ visits',
      'address': '64 Wentworth St, Spitalfields, E1 7AL',
      'phone': '020 7247 4321',
      'cashback': '10%',
      'color': const Color(0xFF3D2B1A),
      'icon': Icons.coffee_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1559305616-3f99cd43e353?w=400&q=75',
      'desc': 'A vibrant East London café beloved for its generous brunch platters, speciality flat whites, and warm community atmosphere.',
    },
  ];

  // ── RESTAURANTS ────────────────────────────────────────
  final List<Map<String, dynamic>> _restaurants = [
    {
      'name': 'Dishoom Covent Garden',
      'category': 'Indian Restaurant',
      'rating': '4.8',
      'visits': '32.5k+ visits',
      'address': '12 Upper St Martin\'s Lane, WC2H 9FB',
      'lat': 51.5128, 'lon': -0.1283,
      'phone': '020 7420 9320',
      'cashback': '10%',
      'color': const Color(0xFF3B1F0A),
      'icon': Icons.restaurant_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&q=75',
      'desc': 'Inspired by the iconic Irani cafés of Bombay, Dishoom serves extraordinary food all day long. Famous for its black dal and bacon naan.',
    },
    {
      'name': 'Sketch',
      'category': 'Restaurant & Bar',
      'rating': '4.7',
      'visits': '14.8k+ visits',
      'address': '9 Conduit St, Mayfair, W1S 2XG',
      'phone': '020 7659 4500',
      'cashback': '12%',
      'color': const Color(0xFF1C1C2E),
      'icon': Icons.restaurant_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=400&q=75',
      'desc': 'A spectacular collection of unique restaurants, bars, and a patisserie housed in an 18th-century townhouse. The Parlour pink room is unmissable.',
    },
    {
      'name': 'Hakkasan Mayfair',
      'category': 'Chinese Restaurant',
      'rating': '4.8',
      'visits': '11.3k+ visits',
      'address': '17 Bruton St, Mayfair, W1J 6QB',
      'phone': '020 7907 1888',
      'cashback': '15%',
      'color': const Color(0xFF0A1A2E),
      'icon': Icons.restaurant_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=400&q=75',
      'desc': 'Michelin-starred Cantonese restaurant combining authentic Chinese cuisine with a glamorous, seductive atmosphere in the heart of Mayfair.',
    },
    {
      'name': 'Brasserie Zédel',
      'category': 'French Brasserie',
      'rating': '4.7',
      'visits': '19.2k+ visits',
      'address': '20 Sherwood St, Soho, W1F 7ED',
      'phone': '020 7734 4888',
      'cashback': '10%',
      'color': const Color(0xFF1A0A00),
      'icon': Icons.restaurant_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1424847651672-bf20a4b0982b?w=400&q=75',
      'desc': 'A grand Parisian brasserie in the heart of Soho, serving classic French cuisine at remarkably accessible prices in a stunning Art Deco setting.',
    },
    {
      'name': 'The Ledbury',
      'category': 'Fine Dining',
      'rating': '4.9',
      'visits': '8.6k+ visits',
      'address': '127 Ledbury Rd, Notting Hill, W11 2AQ',
      'phone': '020 7792 9090',
      'cashback': '12%',
      'color': const Color(0xFF0D2B1A),
      'icon': Icons.restaurant_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=400&q=75',
      'desc': 'Two Michelin star restaurant in Notting Hill, offering creative modern European cuisine with impeccable service in an elegant setting.',
    },
  ];

  // ── CLUBS ──────────────────────────────────────────────
  final List<Map<String, dynamic>> _clubs = [
    {
      'name': 'Fabric',
      'category': 'Nightclub',
      'rating': '4.7',
      'visits': '42.1k+ visits',
      'address': '77a Charterhouse St, Farringdon, EC1M 6HJ',
      'phone': '020 7336 8898',
      'cashback': '8%',
      'color': const Color(0xFF1A0533),
      'icon': Icons.nightlife_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1566737236500-c8ac43014a67?w=400&q=75',
      'desc': 'One of the world\'s most respected nightclubs, Fabric has been a cornerstone of London\'s electronic music scene since 1999, featuring three rooms of cutting-edge music.',
    },
    {
      'name': 'XOYO',
      'category': 'Nightclub',
      'rating': '4.6',
      'visits': '28.7k+ visits',
      'address': '32-37 Cowper St, Shoreditch, EC2A 4AP',
      'phone': '020 7608 2878',
      'cashback': '8%',
      'color': const Color(0xFF200840),
      'icon': Icons.nightlife_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1429962714451-bb934ecdc4ec?w=400&q=75',
      'desc': 'Shoreditch\'s favourite nightclub hosts the best in house, techno, and drum & bass across two floors. Resident DJs and world-class international acts every weekend.',
    },
    {
      'name': 'Ministry of Sound',
      'category': 'Superclub',
      'rating': '4.8',
      'visits': '55.4k+ visits',
      'address': '103 Gaunt St, Elephant & Castle, SE1 6DP',
      'phone': '020 7740 8600',
      'cashback': '10%',
      'color': const Color(0xFF0A0A0A),
      'icon': Icons.nightlife_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1493676304819-0d7a8d026dcf?w=400&q=75',
      'desc': 'A global icon of dance music culture. Ministry of Sound boasts world-class sound systems, legendary DJs, and has been the heartbeat of London\'s club scene since 1991.',
    },
    {
      'name': 'Egg London',
      'category': 'Nightclub',
      'rating': '4.5',
      'visits': '16.3k+ visits',
      'address': '200 York Way, King\'s Cross, N7 9AX',
      'phone': '020 7609 8364',
      'cashback': '8%',
      'color': const Color(0xFF0A1A35),
      'icon': Icons.nightlife_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1571266028243-d220c6f40a3c?w=400&q=75',
      'desc': 'A warehouse-style venue near King\'s Cross with an outdoor terrace, multiple dance floors, and a devotion to house and techno that draws serious clubbers.',
    },
    {
      'name': 'Printworks London',
      'category': 'Events Venue',
      'rating': '4.8',
      'visits': '22.9k+ visits',
      'address': 'Surrey Quays Rd, Rotherhithe, SE16 7PJ',
      'phone': '020 8146 5422',
      'cashback': '10%',
      'color': const Color(0xFF1A1A0A),
      'icon': Icons.nightlife_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=400&q=75',
      'desc': 'Housed in a former printing press, Printworks is one of London\'s most unique event spaces — a cavernous industrial venue for electronic music, art, and culture.',
    },
  ];

  // ── PUBS ───────────────────────────────────────────────
  final List<Map<String, dynamic>> _pubs = [
    {
      'name': 'The Churchill Arms',
      'category': 'Historic Pub',
      'rating': '4.8',
      'visits': '24.6k+ visits',
      'address': '119 Kensington Church St, W8 7LN',
      'phone': '020 7727 4242',
      'cashback': '15%',
      'color': const Color(0xFF1A3A1A),
      'icon': Icons.sports_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1525268323446-0505b6fe7778?w=400&q=75',
      'desc': 'A legendary Kensington pub draped in hanging flower baskets and festive lights, known for its affordable Thai food, real ales, and friendly atmosphere.',
    },
    {
      'name': 'Ye Olde Cheshire Cheese',
      'category': 'Historic Pub',
      'rating': '4.7',
      'visits': '19.1k+ visits',
      'address': '145 Fleet St, City of London, EC4A 2BU',
      'phone': '020 7353 6170',
      'cashback': '12%',
      'color': const Color(0xFF2A1A08),
      'icon': Icons.sports_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1516997121675-4c2d1684aa3e?w=400&q=75',
      'desc': 'Rebuilt after the Great Fire of 1666, this atmospheric pub off Fleet Street has hosted Charles Dickens, Samuel Johnson, and countless other literary legends.',
    },
    {
      'name': 'The Prospect of Whitby',
      'category': 'Riverside Pub',
      'rating': '4.6',
      'visits': '15.8k+ visits',
      'address': '57 Wapping Wall, E1W 3SH',
      'phone': '020 7481 1095',
      'cashback': '15%',
      'color': const Color(0xFF2A0A0A),
      'icon': Icons.sports_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=400&q=75',
      'desc': 'Dating back to 1520, London\'s oldest riverside pub sits on the Thames in Wapping and offers spectacular river views alongside traditional ales and hearty food.',
    },
    {
      'name': 'The Mayflower',
      'category': 'Historic Pub',
      'rating': '4.7',
      'visits': '12.3k+ visits',
      'address': '117 Rotherhithe St, SE16 4NF',
      'phone': '020 7237 4088',
      'cashback': '12%',
      'color': const Color(0xFF0A2A1A),
      'icon': Icons.sports_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1575367439058-6096bb9cf5e2?w=400&q=75',
      'desc': 'Named after the ship that carried the Pilgrim Fathers to America in 1620, this charming timber-framed pub overlooks the Thames at Rotherhithe.',
    },
    {
      'name': 'The Lamb & Flag',
      'category': 'Traditional Pub',
      'rating': '4.6',
      'visits': '18.4k+ visits',
      'address': '33 Rose St, Covent Garden, WC2E 9EB',
      'phone': '020 7497 9504',
      'cashback': '15%',
      'color': const Color(0xFF1A0A2A),
      'icon': Icons.sports_bar_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1560512823-829485b8bf24?w=400&q=75',
      'desc': 'One of the oldest pubs in Covent Garden, known as "The Bucket of Blood" in its bare-knuckle boxing days. Now a beloved historic pub serving quality ales.',
    },
  ];

  // ── MUSIC VENUES ───────────────────────────────────────
  final List<Map<String, dynamic>> _music = [
    {
      'name': 'Ronnie Scott\'s',
      'category': 'Jazz Club',
      'rating': '4.9',
      'visits': '31.2k+ visits',
      'address': '47 Frith St, Soho, W1D 4HT',
      'phone': '020 7439 0747',
      'cashback': '10%',
      'color': const Color(0xFF1A0A00),
      'icon': Icons.music_note_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=400&q=75',
      'desc': 'The world\'s most famous jazz club. Since 1959, Ronnie Scott\'s has been at the heart of London\'s jazz scene, hosting legends from Miles Davis to Amy Winehouse.',
    },
    {
      'name': 'The O2 Arena',
      'category': 'Concert Venue',
      'rating': '4.7',
      'visits': '280k+ visits',
      'address': 'Peninsula Square, Greenwich, SE10 0DX',
      'phone': '020 8463 2000',
      'cashback': '8%',
      'color': const Color(0xFF0A1A3A),
      'icon': Icons.music_note_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1540039155158-136537ebd069?w=400&q=75',
      'desc': 'The world\'s most visited music venue and entertainment destination, hosting the biggest global artists and spectacular live events year-round.',
    },
    {
      'name': '100 Club',
      'category': 'Live Music Venue',
      'rating': '4.8',
      'visits': '14.7k+ visits',
      'address': '100 Oxford St, W1D 1LL',
      'phone': '020 7636 0933',
      'cashback': '12%',
      'color': const Color(0xFF0A0A1A),
      'icon': Icons.music_note_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&q=75',
      'desc': 'An iconic Oxford Street venue that launched punk, jazz, and blues onto London\'s stages since 1942. The Rolling Stones and Sex Pistols both played here.',
    },
    {
      'name': 'Jazz Cafe',
      'category': 'Jazz & Soul Venue',
      'rating': '4.6',
      'visits': '9.4k+ visits',
      'address': '5 Parkway, Camden Town, NW1 7PG',
      'phone': '020 7485 6834',
      'cashback': '10%',
      'color': const Color(0xFF1A0A1A),
      'icon': Icons.music_note_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=400&q=75',
      'desc': 'Camden\'s intimate jazz and soul venue hosting emerging talent and global stars alike. Late-night DJ sets continue after live performances every weekend.',
    },
    {
      'name': 'EartH',
      'category': 'Concert Hall',
      'rating': '4.7',
      'visits': '8.2k+ visits',
      'address': '11 Stoke Newington Rd, Hackney, N16 8BH',
      'phone': '020 7923 1234',
      'cashback': '10%',
      'color': const Color(0xFF0A1A0A),
      'icon': Icons.music_note_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=400&q=75',
      'desc': 'A stunning multi-arts venue in Hackney housed in a restored 1930s theatre, featuring live music across genres, club nights, and cultural events.',
    },
  ];

  // ── COMEDY ─────────────────────────────────────────────
  final List<Map<String, dynamic>> _comedy = [
    {
      'name': 'The Comedy Store',
      'category': 'Comedy Club',
      'rating': '4.8',
      'visits': '22.3k+ visits',
      'address': '1a Oxendon St, Leicester Square, SW1Y 4EE',
      'phone': '0844 871 7699',
      'cashback': '12%',
      'color': const Color(0xFF1A0A00),
      'icon': Icons.theater_comedy_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1527224857830-43a7acc85260?w=400&q=75',
      'desc': 'London\'s premier comedy club since 1979, launching the careers of Eddie Izzard, Lee Evans, and countless others. World-class stand-up every night of the week.',
    },
    {
      'name': 'Soho Theatre',
      'category': 'Theatre & Comedy',
      'rating': '4.8',
      'visits': '16.5k+ visits',
      'address': '21 Dean St, Soho, W1D 3NE',
      'phone': '020 7478 0100',
      'cashback': '10%',
      'color': const Color(0xFF0A0A2A),
      'icon': Icons.theater_comedy_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1516280440614-37939bbacd81?w=400&q=75',
      'desc': 'A world-class theatre and comedy venue in the heart of Soho, nurturing new writing talent and hosting the best in British and international comedy.',
    },
    {
      'name': 'Up The Creek',
      'category': 'Comedy Club',
      'rating': '4.6',
      'visits': '8.7k+ visits',
      'address': '302 Creek Rd, Greenwich, SE10 9SW',
      'phone': '020 8858 4581',
      'cashback': '12%',
      'color': const Color(0xFF1A1A00),
      'icon': Icons.theater_comedy_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1574375927938-e2fb3e46ebf1?w=400&q=75',
      'desc': 'A legendary Greenwich comedy club famous for its unpredictable atmosphere and Saturday night audience participation. Malcolm Hardee\'s irreverent legacy lives on.',
    },
    {
      'name': 'Angel Comedy',
      'category': 'Free Comedy Club',
      'rating': '4.7',
      'visits': '11.2k+ visits',
      'address': '2 Camden Walk, Islington, N1 8DY',
      'phone': '020 7354 2414',
      'cashback': '15%',
      'color': const Color(0xFF0A1A00),
      'icon': Icons.theater_comedy_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1589903308904-1010c2294adc?w=400&q=75',
      'desc': 'London\'s home of free comedy in Islington, hosting nightly shows with both rising stars and established comedians. A true gem for comedy lovers on a budget.',
    },
    {
      'name': 'Backyard Comedy Club',
      'category': 'Comedy Club',
      'rating': '4.5',
      'visits': '6.9k+ visits',
      'address': '231 Cambridge Heath Rd, Bethnal Green, E2 0EL',
      'phone': '020 7739 3122',
      'cashback': '12%',
      'color': const Color(0xFF2A0A0A),
      'icon': Icons.theater_comedy_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1503095396549-807759245b35?w=400&q=75',
      'desc': 'Lee Hurst\'s iconic East London comedy venue bringing world-class comedians to Bethnal Green since 1995. A true grassroots comedy institution.',
    },
  ];

  // ── FAST FOOD ──────────────────────────────────────────
  final List<Map<String, dynamic>> _fastFood = [
    {
      'name': 'Morley\'s',
      'category': 'Chicken Shop',
      'subtype': 'Chicken',
      'rating': '4.6',
      'visits': '28.4k+ visits',
      'address': '214 Brixton Rd, Brixton, SW9 6AP',
      'phone': '020 7733 5526',
      'cashback': '10%',
      'color': const Color(0xFF8B1A1A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1562967914-d44b4e6d1d7d?w=400&q=75',
      'desc': 'South London\'s iconic home-grown fried chicken chain since 1985. A true cultural institution loved across the city — famous for the crispiest wings in London.',
    },
    {
      'name': 'Chicken Cottage',
      'category': 'Chicken Shop',
      'subtype': 'Chicken',
      'rating': '4.4',
      'visits': '19.7k+ visits',
      'address': '32 Edgware Rd, Marylebone, W2 2EH',
      'phone': '020 7723 9900',
      'cashback': '10%',
      'color': const Color(0xFFB8360A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=400&q=75',
      'desc': 'A beloved fast-food staple across London since 1994, serving flame-grilled and fried chicken with a loyal following in every corner of the city.',
    },
    {
      'name': 'Dixy Chicken',
      'category': 'Chicken Shop',
      'subtype': 'Chicken',
      'rating': '4.3',
      'visits': '14.2k+ visits',
      'address': '118 Commercial Rd, Whitechapel, E1 1NF',
      'phone': '020 7247 0033',
      'cashback': '12%',
      'color': const Color(0xFF9B2B0A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1585325701165-9caacfe4d5ac?w=400&q=75',
      'desc': 'East London\'s go-to fried chicken spot. Serving crispy chicken, spicy wings, and loaded burgers to hungry Londoners around the clock.',
    },
    {
      'name': 'Poppies Fish & Chips',
      'category': 'Fish & Chips',
      'subtype': 'Fish & Chips',
      'rating': '4.8',
      'visits': '22.1k+ visits',
      'address': '6-8 Hanbury St, Spitalfields, E1 6QR',
      'phone': '020 7247 0892',
      'cashback': '12%',
      'color': const Color(0xFF1A3A5C),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1519984388953-d2406bc725e1?w=400&q=75',
      'desc': 'London\'s most celebrated fish and chip shop, bringing a taste of 1950s East End charm to Spitalfields. Traditional recipes, sustainably sourced fish, outstanding quality.',
    },
    {
      'name': 'Toff\'s of Muswell Hill',
      'category': 'Fish & Chips',
      'subtype': 'Fish & Chips',
      'rating': '4.9',
      'visits': '11.6k+ visits',
      'address': '38 Muswell Hill Broadway, N10 3RT',
      'phone': '020 8883 8656',
      'cashback': '15%',
      'color': const Color(0xFF0A2A4A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?w=400&q=75',
      'desc': 'Award-winning fish and chips in North London since 1968. Multiple national champion of the Fish & Chip Shop of the Year. The gold standard of British chippies.',
    },
    {
      'name': 'Franco Manca',
      'category': 'Pizza',
      'subtype': 'Pizza',
      'rating': '4.7',
      'visits': '31.4k+ visits',
      'address': '4 Market Row, Brixton Market, SW9 8LD',
      'phone': '020 7738 3021',
      'cashback': '10%',
      'color': const Color(0xFF7A1A0A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=75',
      'desc': 'The sourdough pizza that started it all. Born in Brixton Market, Franco Manca\'s slow-risen dough and organic toppings have become a London institution since 2008.',
    },
    {
      'name': 'Pizza Pilgrims',
      'category': 'Pizza',
      'subtype': 'Pizza',
      'rating': '4.7',
      'visits': '24.8k+ visits',
      'address': '11 Dean St, Soho, W1D 3RP',
      'phone': '020 7287 8964',
      'cashback': '10%',
      'color': const Color(0xFF3A0A0A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&q=75',
      'desc': 'Neapolitan pizzas made with love in the heart of Soho. Two brothers drove a Piaggio Ape van from London to Naples to learn the craft — the result is exceptional.',
    },
    {
      'name': 'Bleecker Burger',
      'category': 'Burgers',
      'subtype': 'Burgers',
      'rating': '4.8',
      'visits': '18.3k+ visits',
      'address': 'Unit 3, Bloomberg Arcade, EC4N 8AR',
      'phone': '020 3019 7722',
      'cashback': '12%',
      'color': const Color(0xFF1A1A0A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=75',
      'desc': 'Voted London\'s best burger multiple years running. Bleecker\'s smash burgers are made with 35-day dry-aged British beef — simple, honest, and absolutely outstanding.',
    },
    {
      'name': 'Ranoush Juice',
      'category': 'Kebabs',
      'subtype': 'Kebabs',
      'rating': '4.6',
      'visits': '16.9k+ visits',
      'address': '43 Edgware Rd, Marylebone, W2 2JR',
      'phone': '020 7723 5929',
      'cashback': '10%',
      'color': const Color(0xFF1A0A00),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1529694157872-4e0c0f3b238b?w=400&q=75',
      'desc': 'A Mayfair institution serving the finest Lebanese shawarma, mezze, and fresh juices. Open until 3am — the most glamorous late-night kebab in London.',
    },
    {
      'name': 'Roti King',
      'category': 'Malaysian',
      'subtype': 'Burgers',
      'rating': '4.8',
      'visits': '13.5k+ visits',
      'address': '40 Doric Way, Euston, NW1 1LH',
      'phone': '020 7387 2518',
      'cashback': '12%',
      'color': const Color(0xFF0A2A0A),
      'icon': Icons.fastfood_rounded,
      'imageUrl': 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=400&q=75',
      'desc': 'A legendary Malaysian basement restaurant near Euston serving the finest roti canai and curry outside of Kuala Lumpur. Always a queue, always worth it.',
    },
  ];

  // ── FAST FOOD FILTER STATE ─────────────────────────────
  String _fastFoodFilter = 'All';
  final List<String> _fastFoodFilters = [
    'All', 'Chicken', 'Fish & Chips', 'Pizza', 'Burgers', 'Kebabs',
  ];

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final category = args?['category'] as String? ?? 'Cafes';

    final List<Map<String, dynamic>> allVenues;
    final IconData categoryIcon;
    final bool isFastFood = category.toLowerCase() == 'fast food';

    switch (category.toLowerCase()) {
      case 'restaurants':
        allVenues = _restaurants;
        categoryIcon = Icons.restaurant_rounded;
        break;
      case 'clubs':
        allVenues = _clubs;
        categoryIcon = Icons.nightlife_rounded;
        break;
      case 'pubs':
        allVenues = _pubs;
        categoryIcon = Icons.sports_bar_rounded;
        break;
      case 'music':
        allVenues = _music;
        categoryIcon = Icons.music_note_rounded;
        break;
      case 'comedy':
        allVenues = _comedy;
        categoryIcon = Icons.theater_comedy_rounded;
        break;
      case 'fast food':
        allVenues = _fastFood;
        categoryIcon = Icons.fastfood_rounded;
        break;
      case 'bars':
        allVenues = _clubs;
        categoryIcon = Icons.local_bar_rounded;
        break;
      default:
        allVenues = _cafes;
        categoryIcon = Icons.coffee_rounded;
    }

    final List<Map<String, dynamic>> venues = isFastFood && _fastFoodFilter != 'All'
        ? allVenues.where((v) => v['subtype'] == _fastFoodFilter).toList()
        : allVenues;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.black87, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          category,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: _primary, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Showing ${venues.length} within 3 miles of you',
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          if (isFastFood) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _fastFoodFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _fastFoodFilters[index];
                  final isSelected = _fastFoodFilter == filter;
                  return GestureDetector(
                    onTap: () => setState(() => _fastFoodFilter = filter),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? _primary : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(
                                color: _primary.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )]
                            : [],
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 10),

          Expanded(
            child: venues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(categoryIcon, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'No venues found',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try a different filter',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: venues.length,
                    itemBuilder: (context, index) =>
                        _venueCard(venues[index], categoryIcon),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _venueCard(Map<String, dynamic> v,
      [IconData fallbackIcon = Icons.store_rounded]) =>
      GestureDetector(
        onTap: () =>
            Navigator.pushNamed(context, '/partner-details', arguments: v),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo header
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background colour (shows while image loads)
                      Container(color: v['color'] as Color),
                      // Cached image — instant on revisit
                      if (v['imageUrl'] != null)
                        CachedNetworkImage(
                          imageUrl: v['imageUrl'] as String,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => Center(
                            child: Icon(
                              v['icon'] as IconData? ?? fallbackIcon,
                              color: Colors.white.withOpacity(0.18),
                              size: 80,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(
                              v['icon'] as IconData? ?? fallbackIcon,
                              color: Colors.white.withOpacity(0.18),
                              size: 80,
                            ),
                          ),
                        ),
                      // Subtle dark gradient at bottom for readability
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.25),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Category badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            v['category'] as String? ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      // Cashback badge
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0392CA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${v['cashback']} Cashback',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v['name'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _dark),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          v['rating'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _dark),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('·',
                              style: GoogleFonts.inter(
                                  color: Colors.grey[400], fontSize: 13)),
                        ),
                        Text(
                          v['visits'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (v['desc'] != null)
                      Text(
                        v['desc'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.grey[600], height: 1.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            v['address'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 5),
                        Text(
                          v['phone'] as String,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 'Home', 0),
                _navItemActive(Icons.explore_rounded, 'Explore', 1),
                _navItem(Icons.account_balance_wallet_rounded, 'Wallet', 2),
                _navItem(Icons.receipt_long_rounded, 'Activity', 3),
                _navItem(Icons.person_rounded, 'Profile', 4),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(IconData icon, String label, int index) => GestureDetector(
        onTap: () {
          const routes = ['/home', '/explore', '/wallet', '/activity', '/profile'];
          Navigator.pushNamed(context, routes[index]);
        },
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

  Widget _navItemActive(IconData icon, String label, int index) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F3FB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _primary, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary),
            ),
          ],
        ),
      );
}
