import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/family_service.dart';
import '../services/user_service.dart';
import '../widgets/goouts_sheet.dart';

class FamilyPlanScreen extends StatefulWidget {
  const FamilyPlanScreen({super.key});

  @override
  State<FamilyPlanScreen> createState() => _FamilyPlanScreenState();
}

class _FamilyPlanScreenState extends State<FamilyPlanScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _green = Color(0xFF0A7A3E);
  static const Color _bg = Color(0xFFF2F4F7);
  static const Color _gold = Color(0xFFFFBF00);

  final FamilyService _familyService = FamilyService();
  final UserService _userService = UserService();

  bool _loading = true;
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  bool _isPlusMember = false;

  // Phone search state
  bool _searching = false;
  bool _showSearchResult = false;
  Map<String, dynamic>? _searchResult;
  String _searchError = '';
  final TextEditingController _phoneController = TextEditingController();
  bool _sendingRequest = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final group = await _familyService.getMyFamilyGroup();
      // getFamilyMembers now reads the summaries already inside the group
      // document, so this is no longer N Firestore reads and no longer needs
      // to be awaited. See FamilyService for why that changed.
      final members = _familyService.getFamilyMembers(group);
      final requests = await _familyService.getIncomingRequests();
      final plus = await _userService.isGoOutsPlusMember();

      if (mounted) {
        setState(() {
          _group = group;
          _members = members;
          _incomingRequests = requests;
          _isPlusMember = plus;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _searchByPhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    setState(() {
      _searching = true;
      _searchError = '';
      _searchResult = null;
      _showSearchResult = false;
    });
    final result = await _familyService.findUserByPhone(phone);
    if (mounted) {
      setState(() {
        _searching = false;
        _showSearchResult = true;
        if (result == null) {
          _searchError =
              'No GoOuts account found with that number. Make sure they have signed up first.';
        } else if (result['inFamilyGroup'] == true) {
          // Was result['familyGroupId'] != null. findUserByPhone no longer
          // returns anyone else's group id, only whether they are in one,
          // because the id would let a stranger work out who is related to
          // whom.
          _searchError = 'This person is already in a GoOuts family group.';
        } else {
          _searchResult = result;
        }
      });
    }
  }

  Future<void> _sendRequest(String toUid, String toPhone) async {
    setState(() => _sendingRequest = true);
    final error = await _familyService.sendLinkRequest(
      toUid: toUid,
      toPhone: toPhone,
    );
    if (mounted) {
      setState(() {
        _sendingRequest = false;
        _showSearchResult = false;
        _phoneController.clear();
        _searchResult = null;
      });
      // ── ⚠ THIS USED TO REPORT SUCCESS EVEN WHEN THE REQUEST FAILED ────
      //
      // FIXED 14 August 2026. The line read:
      //
      //   message: 'error ?? \'Request sent! They will see it in their...',
      //
      // A QUOTED STRING, not an expression. During the snackbar-to-GoOutsSheet
      // migration the interpolation was swallowed into the literal, so the
      // user was shown the raw characters "error ?? 'Request sent! They will
      // see it in their GoOuts app." — and always under a green "Request
      // Sent!" heading, because sendLinkRequest's error return was never read.
      //
      // A family link request that failed reported success, in the live app.
      // The analyzer had been calling this out as "the value of the local
      // variable 'error' isn't used" and it was being read as noise.
      if (error != null) {
        GoOutsSheet.error(context,
          title: 'Request not sent',
          message: error,
        );
      } else {
        GoOutsSheet.success(context,
          title: 'Request sent',
          message: 'They will see it in their GoOuts app.',
        );
      }
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    final error = await _familyService.acceptLinkRequest(requestId);
    if (!mounted) return;
    if (error != null) {
      // BUG FIX: this passed the literal string 'error' instead of the error
      // variable, so the user always saw the word "error" rather than what
      // actually went wrong. (This is also why the analyzer flagged 'error'
      // as an unused local variable.)
      GoOutsSheet.error(context,
        title: 'Error',
        message: error,
      );
      return;
    }

    await _loadAll();
    // Re-check after the second await — the widget may have been disposed
    // while _loadAll() was running.
    if (!mounted) return;
    GoOutsSheet.success(context,
      title: 'Family Member Added',
      message: 'Family member added successfully.',
    );
  }

  Future<void> _declineRequest(String requestId) async {
    await _familyService.declineLinkRequest(requestId);
    if (mounted) await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();

    final double combined =
        (_group?['combinedCashbackEarned'] as num?)?.toDouble() ?? 0.0;
    final bool milestoneReached = _group?['milestoneReached'] as bool? ?? false;
    final bool plusActivated = _group?['plusActivated'] as bool? ?? false;
    final double progress = (combined / 100.0).clamp(0.0, 1.0);
    final double remaining = (100.0 - combined).clamp(0.0, 100.0);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Family Plan',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
        actions: [
          if (_isPlusMember || plusActivated)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: _gold, size: 14),
                  const SizedBox(width: 4),
                  Text('Plus Active',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _gold)),
                ],
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Incoming requests banner ──
              if (_incomingRequests.isNotEmpty) ...[
                ..._incomingRequests.map((r) => _buildRequestBanner(r)),
                const SizedBox(height: 12),
              ],

              // ── Progress card ──
              _buildProgressCard(combined, progress, remaining,
                  milestoneReached, plusActivated),
              const SizedBox(height: 20),

              // ── Family members ──
              _buildSectionTitle('Your Family Group'),
              const SizedBox(height: 12),
              if (_group != null) ...[
                ..._members.map((m) => _buildMemberCard(m)),
              ] else ...[
                _buildNoGroupCard(),
              ],

              // ── Empty slots ──
              if (_group != null && _members.length < 3) ...[
                const SizedBox(height: 10),
                ..._buildEmptySlots(_members.length),
              ],
              const SizedBox(height: 20),

              // ── Phone search ──
              if (_group == null || _members.length < 3) ...[
                _buildSectionTitle('Link a Family Member'),
                const SizedBox(height: 12),
                _buildPhoneSearch(),
                const SizedBox(height: 20),
              ],

              // ── What Plus gives you ──
              _buildSectionTitle('What GoOuts Plus gives you'),
              const SizedBox(height: 12),
              _buildPlusFeatures(),
              const SizedBox(height: 20),

              // ── Activate CTA ──
              if (milestoneReached && !plusActivated && !_isPlusMember)
                _buildActivateCta(context),

              if (!milestoneReached && _group != null)
                _buildProgressNote(remaining),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading ────────────────────────────────────────────────
  Widget _buildLoading() => Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _dark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Family Plan',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: _primary),
        ),
      );

  // ── Incoming request banner ────────────────────────────────
  Widget _buildRequestBanner(Map<String, dynamic> request) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primary.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: _primary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    color: _primary, size: 20),
                const SizedBox(width: 8),
                Text('Family Link Request',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dark)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${request['fromName']} wants to add you to their GoOuts family group.',
              style: GoogleFonts.inter(
                  fontSize: 13, color: Colors.grey[600], height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _declineRequest(request['requestId']),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text('Decline',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600])),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        _acceptRequest(request['requestId']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text('Accept',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  // ── Progress card ──────────────────────────────────────────
  Widget _buildProgressCard(double combined, double progress, double remaining,
          bool milestoneReached, bool plusActivated) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1B3E), Color(0xFF0A4A7A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1B3E).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Text('Family Cashback Progress',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85))),
                const Spacer(),
                if (milestoneReached)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Unlocked!',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('£${combined.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(' / £100.00',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.55))),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              milestoneReached
                  ? 'Your family has unlocked GoOuts Plus!'
                  : 'Just £${remaining.toStringAsFixed(2)} more to unlock GoOuts Plus',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                    milestoneReached ? _green : _primary),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _group != null
                  ? 'Combined across ${_members.length} family member${_members.length != 1 ? 's' : ''}'
                  : 'Link family members to earn together',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );

  // ── Section title ──────────────────────────────────────────
  Widget _buildSectionTitle(String title) => Text(title,
      style: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w700, color: _dark));

  // ── No group card ──────────────────────────────────────────
  Widget _buildNoGroupCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_alt_rounded,
                  color: _primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'You have not linked any family members yet. Search by phone number below to get started.',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[500],
                    height: 1.5),
              ),
            ),
          ],
        ),
      );

  // ── Member card ────────────────────────────────────────────
  Widget _buildMemberCard(Map<String, dynamic> member) {
    final isMe = member['familyRole'] == 'primary';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials(member['fullName'] as String),
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member['fullName'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _dark)),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('You',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _primary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Cashback earned: £${(member['totalCashbackEarned'] as double).toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            '£${(member['totalCashbackEarned'] as double).toStringAsFixed(2)}',
            style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _green),
          ),
        ],
      ),
    );
  }

  // ── Empty slots ────────────────────────────────────────────
  List<Widget> _buildEmptySlots(int currentCount) {
    final int needed = 3 - currentCount;
    return List.generate(
      needed,
      (_) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Icon(Icons.person_add_rounded,
                  color: Colors.grey[400], size: 22),
            ),
            const SizedBox(width: 14),
            Text('Empty slot — search below to add a family member',
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  // ── Phone search ───────────────────────────────────────────
  Widget _buildPhoneSearch() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the phone number of a family member who already has a GoOuts account.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.inter(fontSize: 15, color: _dark),
                    decoration: InputDecoration(
                      hintText: 'e.g. 07911 123456',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.phone_rounded,
                          color: _primary, size: 20),
                      filled: true,
                      fillColor: const Color(0xFFF2F4F7),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _searchByPhone(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _searching ? null : _searchByPhone,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _searching
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search_rounded,
                            color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),

            // Search result
            if (_showSearchResult) ...[
              const SizedBox(height: 14),
              if (_searchError.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_searchError,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.red[700])),
                      ),
                    ],
                  ),
                ),
              if (_searchResult != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _green.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _initials(
                                _searchResult!['fullName'] as String),
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _green),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _searchResult!['fullName'] as String,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _dark),
                            ),
                            Text('GoOuts member',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _sendingRequest
                            ? null
                            : () => _sendRequest(
                                _searchResult!['uid'] as String,
                                _searchResult!['phone'] as String),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _sendingRequest
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : Text('Send Request',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );

  // ── Plus features ──────────────────────────────────────────
  Widget _buildPlusFeatures() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            _featureRow(Icons.savings_rounded, _green, 'Bonus Cashback',
                'Extra 1 to 2% on top of the standard rate at every partner'),
            const Divider(height: 20, color: Color(0xFFF0F0F0)),
            _featureRow(Icons.local_offer_rounded, const Color(0xFFE65100),
                'Member Discounts', 'Exclusive deals available only to Plus members'),
            const Divider(height: 20, color: Color(0xFFF0F0F0)),
            _featureRow(Icons.flash_on_rounded, _gold, 'Early Access',
                'See new partner offers 24 hours before everyone else'),
            const Divider(height: 20, color: Color(0xFFF0F0F0)),
            _featureRow(Icons.bar_chart_rounded, _primary, 'Family Dashboard',
                'Track your combined cashback progress in one place'),
            const Divider(height: 20, color: Color(0xFFF0F0F0)),
            _featureRow(Icons.people_alt_rounded, _dark, 'Whole Family Covered',
                'One £10 annual payment covers every member of your group'),
          ],
        ),
      );

  Widget _featureRow(IconData icon, Color color, String title, String subtitle) =>
      Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                        height: 1.4)),
              ],
            ),
          ),
        ],
      );

  // ── Activate CTA ───────────────────────────────────────────
  Widget _buildActivateCta(BuildContext context) => GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/goouts-plus-unlocked'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A7A3E), Color(0xFF0D9E50)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text('Your family has unlocked GoOuts Plus!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                'Tap to activate and unlock all the benefits for just £10 a year.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5),
              ),
            ],
          ),
        ),
      );

  // ── Progress note ──────────────────────────────────────────
  Widget _buildProgressNote(double remaining) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: _primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Earn £${remaining.toStringAsFixed(2)} more in combined family cashback to unlock GoOuts Plus for just £10 a year.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: _primary, height: 1.5),
              ),
            ),
          ],
        ),
      );

  // ── Helpers ────────────────────────────────────────────────
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
