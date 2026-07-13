import '../services/user_service.dart';

import '../services/user_service.dart';
import '../widgets/goouts_sheet.dart';
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const Color _primary = Color(0xFF0392CA);
  static const Color _dark = Color(0xFF0D1B3E);
  static const Color _bg = Color(0xFFF2F4F7);
  static const Color _green = Color(0xFF0A7A3E);
  static const Color _teal = Color(0xFF0A6E8A);
  static const Color _red = Color(0xFFD32F2F);
  static const Color _amber = Color(0xFFF59E0B);

  String _selectedFilter = 'All';
  String _searchQuery = '';
  bool _loadingData = true;
  bool _hasError = false;
  double _totalCashbackBalance = 0.0;
  Set<String> _reviewedTxnIds = {};
  Set<String> _expandedGroups = {};
  int _reviewPoints = 0;
  static const int _pointsPerReview = 2;
  static const int _pointsForBonus = 100;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filters = ['All', 'Cashback', 'Top-Up', 'Spending', 'Reviews'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final svc = TransactionService();
      final results = await Future.wait([
        svc.getTransactions(),
        svc.getAllReviewedTransactionIds(),
        UserService().getCurrentUser(),
      ]);
      final firestoreTransactions = results[0] as List<Map<String, dynamic>>;
      final reviewedIds = results[1] as Set<String>;
      final userData = results[2] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        // Always replace — empty list = clean state for new users
        _allTransactions
          ..clear()
          ..addAll(firestoreTransactions);
        _reviewedTxnIds = reviewedIds;
        final cb = userData?['cashbackBalance'];
        _totalCashbackBalance = cb is num ? cb.toDouble() : _totalCashbackFromList();
        _reviewPoints = (userData?['reviewPoints'] as num?)?.toInt() ?? 0;
        _loadingData = false;
        _hasError = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loadingData = false; _hasError = true; });
    }
  }

  double _totalCashbackFromList() => _allTransactions
      .where((t) => t['type'] == 'Cashback')
      .fold(0.0, (sum, t) {
    final raw = (t['amount'] as String).replaceAll('+£', '').replaceAll('-£', '');
    return sum + (double.tryParse(raw) ?? 0);
  });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _allTransactions = [];

  // Weekly cashback chart — starts empty, populated from real transactions
  final List<Map<String, dynamic>> _chartWeeks = [
    {'label': 'W1', 'cashback': 0.0},
    {'label': 'W2', 'cashback': 0.0},
    {'label': 'W3', 'cashback': 0.0},
    {'label': 'W4', 'cashback': 0.0},
  ];

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list;
    if (_selectedFilter == 'All') {
      list = _allTransactions;
    } else if (_selectedFilter == 'Reviews') {
      list = _allTransactions.where((t) {
        if ((t['type'] as String?) != 'Spending') return false;
        final id = t['id'] as String?;
        return id == null || !_reviewedTxnIds.contains(id);
      }).toList();
    } else {
      list = _allTransactions.where((t) => t['type'] == _selectedFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((t) => (t['title'] as String)
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return list;
  }

  int get _pendingReviewCount => _allTransactions.where((t) {
    if ((t['type'] as String?) != 'Spending') return false;
    final id = t['id'] as String?;
    return id == null || !_reviewedTxnIds.contains(id);
  }).length;

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final Map<String, List<Map<String, dynamic>>> result = {};
    for (final t in _filtered) {
      final month = t['month'] as String;
      result.putIfAbsent(month, () => []).add(t);
    }
    return result;
  }

  /// Merges sub-transactions (those with a groupId) into their parent spending
  /// transaction so they appear as one grouped card in the list.
  List<Map<String, dynamic>> _mergeGroups(
      List<Map<String, dynamic>> items) {
    // Build map: groupId → list of sub-transactions
    final Map<String, List<Map<String, dynamic>>> subMap = {};
    for (final t in items) {
      final gid = t['groupId'] as String?;
      if (gid != null) subMap.putIfAbsent(gid, () => []).add(t);
    }

    final List<Map<String, dynamic>> result = [];
    final Set<String> added = {};

    for (final t in items) {
      final id = t['id'] as String? ?? '';
      final gid = t['groupId'] as String?;

      // Skip sub-transactions — they'll appear inside the parent group card
      if (gid != null) continue;

      // Main spending transaction that has subs
      if (subMap.containsKey(id)) {
        result.add({
          ...t,
          '_isGroup': true,
          '_subs': subMap[id]!,
        });
        added.add(id);
      } else {
        result.add(t);
      }
    }
    return result;
  }

  double get _totalCashback => _totalCashbackBalance > 0
      ? _totalCashbackBalance
      : _totalCashbackFromList();

  String _monthNet(List<Map<String, dynamic>> transactions) {
    double net = 0;
    for (final t in transactions) {
      final raw = (t['amount'] as String).replaceAll('£', '').replaceAll(',', '');
      net += double.tryParse(raw) ?? 0;
    }
    final isPos = net >= 0;
    return '${isPos ? '+' : '-'}£${net.abs().toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final months = grouped.keys.toList();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1A1A2E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transaction History',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined,
                color: Color(0xFF0392CA), size: 22),
            onPressed: () => _showExportSheet(context),
          ),
        ],
      ),
      body: _loadingData
          ? _buildShimmer()
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Could not load transactions.',
                          style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[500])),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() { _loadingData = true; _hasError = false; _loadData(); }),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0392CA), elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: Text('Try Again', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                )
              : Column(
        children: [
          // ── Stats strip ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _statChip(
                    label: 'Total Cashback',
                    value: '£${_totalCashback.toStringAsFixed(2)}',
                    color: _green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statChip(
                    label: 'Partners Visited',
                    value: _allTransactions
                        .where((t) => t['type'] == 'Spending')
                        .length
                        .toString(),
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statChip(
                    label: 'Total Spent',
                    value: '£${_allTransactions.where((t) => t['type'] == 'Spending').fold(0.0, (sum, t) { final raw = (t['amount'] as String).replaceAll('-£', '').replaceAll('+£', ''); return sum + (double.tryParse(raw) ?? 0); }).toStringAsFixed(0)}',
                    color: _teal,
                  ),
                ),
              ],
            ),
          ),

          // ── Chart ────────────────────────────────────────
          _buildChart(),

          // ── Search bar ───────────────────────────────────
          _buildSearchBar(),

          // ── Filter chips ─────────────────────────────────
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: _filters.map((f) {
                  final selected = _selectedFilter == f;
                  final isReviews = f == 'Reviews';
                  final count = isReviews ? _pendingReviewCount : 0;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? (isReviews ? _amber : _primary)
                            : const Color(0xFFF0F0F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isReviews)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Icon(Icons.rate_review_rounded,
                                  size: 13,
                                  color: selected ? Colors.white : _amber),
                            ),
                          Text(
                            f,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : isReviews
                                      ? _amber
                                      : Colors.grey[600],
                            ),
                          ),
                          if (isReviews && count > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withOpacity(0.3)
                                    : _amber,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$count',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Transaction list ─────────────────────────────
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedFilter == 'Reviews'
                              ? Icons.rate_review_rounded
                              : Icons.receipt_long_rounded,
                          size: 56,
                          color: _selectedFilter == 'Reviews'
                              ? _green.withOpacity(0.35)
                              : Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedFilter == 'Reviews'
                              ? 'All Caught Up!'
                              : _searchQuery.isNotEmpty
                                  ? 'No results for "$_searchQuery"'
                                  : 'No transactions yet',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _selectedFilter == 'Reviews'
                                  ? _green
                                  : Colors.grey[400]),
                        ),
                        const SizedBox(height: 6),
                        if (_selectedFilter == 'Reviews')
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'You have reviewed all your partner visits. Thank you!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: Colors.grey[500], height: 1.5),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: months.length,
                    itemBuilder: (context, monthIndex) {
                      final month = months[monthIndex];
                      final rawItems = grouped[month]!;
                      final items = _mergeGroups(rawItems);
                      final net = _monthNet(rawItems);
                      final netPos = net.startsWith('+');
                      final isReviewsTab = _selectedFilter == 'Reviews';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Month header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, top: 4),
                            child: Row(
                              children: [
                                Text(month,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[500],
                                        letterSpacing: 0.5)),
                                const Spacer(),
                                if (!isReviewsTab)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: netPos
                                          ? _green.withOpacity(0.1)
                                          : _red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('$net net',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: netPos ? _green : _red)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text('${items.length} pending',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _amber)),
                                  ),
                              ],
                            ),
                          ),
                          // Transactions
                          ...items.asMap().entries.map((entry) {
                            final t = entry.value;
                            final isGroup = t['_isGroup'] as bool? ?? false;

                            if (isGroup) {
                              return _groupedPaymentCard(context, t);
                            }

                            return Container(
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
                              margin: const EdgeInsets.only(bottom: 8),
                              child: isReviewsTab
                                  ? _pendingReviewRow(context, t)
                                  : _transactionRow(t),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Shimmer placeholder ──────────────────────────────────
  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats strip placeholder
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )),
              ),
            ),
            // Chart placeholder
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            // Search bar placeholder
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // Filter chips placeholder
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: List.generate(4, (i) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 64,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                )),
              ),
            ),
            // Transaction rows placeholder
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: List.generate(5, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: double.infinity, height: 13, color: Colors.white),
                              const SizedBox(height: 6),
                              Container(width: 100, height: 11, color: Colors.white),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(width: 52, height: 14, color: Colors.white),
                            const SizedBox(height: 6),
                            Container(width: 40, height: 10, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                  )),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Export Sheet ─────────────────────────────────────────
  void _showExportSheet(BuildContext context) {
    int selectedFormat = 0; // 0=PDF, 1=CSV, 2=Excel
    bool isExporting = false;
    bool isDone = false;

    final formats = [
      {
        'label': 'PDF Statement',
        'subtitle': 'Formatted report, ready to print or share',
        'icon': Icons.picture_as_pdf_rounded,
        'color': const Color(0xFFD32F2F),
      },
      {
        'label': 'CSV File',
        'subtitle': 'Raw data, compatible with any spreadsheet',
        'icon': Icons.table_chart_rounded,
        'color': const Color(0xFF0A7A3E),
      },
      {
        'label': 'Excel (.xlsx)',
        'subtitle': 'Formatted spreadsheet with charts',
        'icon': Icons.insert_drive_file_rounded,
        'color': const Color(0xFF1565C0),
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: isDone
              ? _exportSuccessState(ctx)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.file_download_rounded,
                              color: _primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Export Transactions',
                              style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _dark),
                            ),
                            Text(
                              '${_filtered.length} transactions • ${_selectedFilter == 'All' ? 'All types' : _selectedFilter}',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Text(
                      'Choose format',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 10),

                    // Format options
                    ...formats.asMap().entries.map((entry) {
                      final i = entry.key;
                      final f = entry.value;
                      final selected = selectedFormat == i;
                      final color = f['color'] as Color;

                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedFormat = i),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.06)
                                : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? color.withOpacity(0.4)
                                  : Colors.grey[200]!,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(f['icon'] as IconData,
                                    color: color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f['label'] as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _dark),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f['subtitle'] as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: selected ? color : Colors.grey[300],
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 6),

                    // Export button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: isExporting
                            ? null
                            : () async {
                                setSheetState(() => isExporting = true);
                                await Future.delayed(
                                    const Duration(milliseconds: 1800));
                                setSheetState(() {
                                  isExporting = false;
                                  isDone = true;
                                });
                              },
                        icon: isExporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded,
                                color: Colors.white, size: 20),
                        label: Text(
                          isExporting ? 'Preparing...' : 'Export Now',
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _exportSuccessState(BuildContext ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.check_circle_rounded, color: _green, size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            'Export Ready!',
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w800, color: _dark),
          ),
          const SizedBox(height: 6),
          Text(
            'Your transaction statement has been\nprepared successfully.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 24),
          // Info row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F3FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'File will be available in your downloads. Connect your email in settings to receive it directly.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: _primary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Done',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );

  // ── Chart ────────────────────────────────────────────────
  Widget _buildChart() {
    const maxBarHeight = 72.0;
    final maxVal = _chartWeeks.fold(0.0, (prev, w) {
      final v = w['cashback'] as double;
      return v > prev ? v : prev;
    });

    // Dynamic month label and real cashback total
    final now = DateTime.now();
    const months = ['','Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final monthLabel = '${months[now.month]} ${now.year}';
    final monthTotal = _chartWeeks.fold(
        0.0, (sum, w) => sum + (w['cashback'] as double));
    final monthTotalStr = monthTotal > 0
        ? '£${monthTotal.toStringAsFixed(2)} earned'
        : 'No cashback yet';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFFE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: _green, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  '$monthLabel — Cashback Trend',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    monthTotalStr,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _green),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _chartWeeks.map((w) {
                final val = w['cashback'] as double;
                final barH = maxVal > 0
                    ? ((val / maxVal) * maxBarHeight).clamp(4.0, maxBarHeight)
                    : 4.0;
                final isEmpty = val == 0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Amount label above bar
                    Text(
                      val > 0 ? '£${val.toStringAsFixed(1)}' : '',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: _green),
                    ),
                    const SizedBox(height: 4),
                    // Bar
                    Container(
                      width: 36,
                      height: barH,
                      decoration: BoxDecoration(
                        gradient: isEmpty
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF0A7A3E), Color(0xFF34D399)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                        color: isEmpty ? Colors.grey[200] : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Week label
                    Text(
                      w['label'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500]),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────
  Widget _buildSearchBar() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.inter(fontSize: 13, color: _dark),
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              hintStyle:
                  GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Colors.grey, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Icon(Icons.cancel_rounded,
                          color: Colors.grey, size: 18),
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ),
      );

  // ── Stats chip ───────────────────────────────────────────
  Widget _statChip(
          {required String label,
          required String value,
          required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    GoogleFonts.inter(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      );

  // ── Grouped Payment Card (expandable) ───────────────────
  Widget _groupedPaymentCard(
      BuildContext context, Map<String, dynamic> group) {
    final id = group['id'] as String? ?? '';
    final isExpanded = _expandedGroups.contains(id);
    final subs = group['_subs'] as List<Map<String, dynamic>>? ?? [];

    // Find earned cashback from subs
    final earnedSub = subs.firstWhere(
      (s) => (s['positive'] as bool? ?? false) &&
          (s['type'] as String?) == 'Cashback',
      orElse: () => {},
    );
    final cbRedeemed = subs.firstWhere(
      (s) => !(s['positive'] as bool? ?? true) &&
          (s['type'] as String?) == 'Cashback',
      orElse: () => {},
    );
    final walUsed = subs.firstWhere(
      (s) => !(s['positive'] as bool? ?? true) &&
          (s['title'] as String? ?? '').contains('Wallet'),
      orElse: () => {},
    );

    final earnedStr  = earnedSub.isNotEmpty ? earnedSub['amount'] as String? : null;
    final cbStr      = cbRedeemed.isNotEmpty ? cbRedeemed['amount'] as String? : null;
    final walStr     = walUsed.isNotEmpty ? walUsed['amount'] as String? : null;

    return GestureDetector(
      onTap: () => setState(() {
        if (isExpanded) _expandedGroups.remove(id);
        else _expandedGroups.add(id);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded ? _primary.withOpacity(0.3) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            // Main row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                        group['icon'] as IconData? ?? Icons.restaurant_rounded,
                        color: _red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group['title'] as String? ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _dark)),
                        const SizedBox(height: 3),
                        Text(group['date'] as String? ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(height: 5),
                        // Summary badges
                        Wrap(spacing: 4, runSpacing: 4, children: [
                          if (cbStr != null)
                            _miniTag('CB ${cbStr.replaceAll('-', '')}', _green),
                          if (walStr != null)
                            _miniTag('Wallet ${walStr.replaceAll('-', '')}', _primary),
                          if (earnedStr != null)
                            _miniTag('Earned $earnedStr', _green),
                        ]),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(group['amount'] as String? ?? '',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _red)),
                      const SizedBox(height: 4),
                      _statusBadge(group['status'] as String? ?? 'Completed'),
                      const SizedBox(height: 4),
                      Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _primary,
                          size: 18),
                    ],
                  ),
                ],
              ),
            ),

            // Expanded breakdown
            if (isExpanded) ...[
              Divider(height: 1, color: Colors.grey[100]),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFB),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Breakdown',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[400],
                            letterSpacing: 0.8)),
                    const SizedBox(height: 10),
                    _breakdownRow('Bill Total', group['amount'] as String? ?? '',
                        color: _red),
                    if (cbStr != null)
                      _breakdownRow('Cashback Redeemed', cbStr, color: _green),
                    if (walStr != null)
                      _breakdownRow('Wallet Used', walStr, color: _primary),
                    if (cbStr != null || walStr != null) ...[
                      Divider(height: 16, color: Colors.grey[200]),
                      _breakdownRow(
                        'Charged to Bank',
                        () {
                          final bill = (group['amountValue'] as num?)?.toDouble() ?? 0.0;
                          final cb   = cbRedeemed.isNotEmpty
                              ? (cbRedeemed['amountValue'] as num?)?.toDouble() ?? 0.0 : 0.0;
                          final wal  = walUsed.isNotEmpty
                              ? (walUsed['amountValue'] as num?)?.toDouble() ?? 0.0 : 0.0;
                          return '£${(bill - cb - wal).abs().toStringAsFixed(2)}';
                        }(),
                        bold: true,
                      ),
                    ],
                    if (earnedStr != null) ...[
                      const SizedBox(height: 6),
                      _breakdownRow('Cashback Earned', earnedStr,
                          color: _green, bold: true),
                    ],
                    if (id.isNotEmpty) ...[
                      Divider(height: 14, color: Colors.grey[200]),
                      _breakdownRow('Reference',
                          'TXN-${id.substring(0, id.length >= 8 ? 8 : id.length).toUpperCase()}',
                          color: Colors.grey[500]),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color)),
      );

  Widget _breakdownRow(String label, String value,
          {Color? color, bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey[500])),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    color: color ?? _dark)),
          ],
        ),
      );

  // ── Transaction row ──────────────────────────────────────
  Widget _transactionRow(Map<String, dynamic> t) {
    final isPositive = t['positive'] as bool;
    final type = t['type'] as String;
    final earnedCashback = t['earnedCashback'] as String?;
    final status = t['status'] as String? ?? 'Completed';
    final txnId = t['id'] as String? ?? '';
    final txnRef = txnId.length >= 8
        ? 'TXN-${txnId.substring(0, 8).toUpperCase()}'
        : '';

    // Icon colour per type
    final Color iconColor;
    final Color iconBg;
    switch (type) {
      case 'Cashback':
        iconColor = _green;
        iconBg = _green.withOpacity(0.1);
        break;
      case 'Spending':
        iconColor = _red;
        iconBg = _red.withOpacity(0.08);
        break;
      case 'Top-Up':
        iconColor = _teal;
        iconBg = _teal.withOpacity(0.1);
        break;
      default:
        iconColor = _amber;
        iconBg = _amber.withOpacity(0.1);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: txnRef.isEmpty ? null : () => _showTxnDetail(context, t, txnRef),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(t['icon'] as IconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Title + date + cashback badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t['title'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _dark),
                ),
                const SizedBox(height: 3),
                if (txnRef.isNotEmpty)
                  Text(txnRef,
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.grey[400],
                          letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      t['date'] as String,
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                    if (earnedCashback != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded,
                                size: 9, color: _green),
                            const SizedBox(width: 2),
                            Text(
                              '$earnedCashback back',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: _green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Amount + type badge + status badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t['amount'] as String,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPositive ? _green : _red,
                ),
              ),
              const SizedBox(height: 4),
              _typeBadge(type),
              const SizedBox(height: 3),
              _statusBadge(status),
            ],
          ),
        ],
      ),
      ),
    );
  }

  // ── Transaction detail sheet ─────────────────────────────
  void _showTxnDetail(BuildContext context, Map<String, dynamic> t, String txnRef) {
    final isPositive = t['positive'] as bool;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            // Icon + title
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isPositive ? _green.withOpacity(0.1) : _red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(t['icon'] as IconData,
                    color: isPositive ? _green : _red, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['title'] as String,
                      style: GoogleFonts.inter(fontSize: 15,
                          fontWeight: FontWeight.w700, color: _dark)),
                  Text(t['date'] as String,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
                ],
              )),
              Text(t['amount'] as String,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800,
                      color: isPositive ? _green : _red)),
            ]),
            const SizedBox(height: 20),
            // Detail rows
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                _detailRow('Type', t['type'] as String),
                const SizedBox(height: 8),
                _detailRow('Status', t['status'] as String? ?? 'Completed'),
                const SizedBox(height: 8),
                _detailRow('Date', t['date'] as String),
                const Divider(height: 16, color: Color(0xFFDDE1E9)),
                _detailRow('Transaction Ref', txnRef, highlight: true),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: Text('Close',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool highlight = false}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500])),
        Text(value, style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: highlight ? _primary : _dark,
            letterSpacing: highlight ? 0.8 : 0)),
      ]);

  // ── Premium type badge ───────────────────────────────────
  Widget _typeBadge(String type) {
    final IconData icon;
    final Color color;
    final Color bg;

    switch (type) {
      case 'Cashback':
        icon = Icons.bolt_rounded;
        color = _green;
        bg = _green.withOpacity(0.1);
        break;
      case 'Spending':
        icon = Icons.arrow_outward_rounded;
        color = _red;
        bg = _red.withOpacity(0.08);
        break;
      case 'Top-Up':
        icon = Icons.add_circle_rounded;
        color = _teal;
        bg = _teal.withOpacity(0.1);
        break;
      default:
        icon = Icons.card_giftcard_rounded;
        color = _amber;
        bg = _amber.withOpacity(0.12);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            type,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  // ── Status badge ─────────────────────────────────────────
  Widget _statusBadge(String status) {
    final isPending = status == 'Pending';
    final color = isPending ? Colors.orange[700]! : Colors.grey[500]!;
    final bg = isPending
        ? Colors.orange.withOpacity(0.1)
        : Colors.grey.withOpacity(0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            status,
            style: GoogleFonts.inter(
                fontSize: 9, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  // ── Bottom Nav ───────────────────────────────────────────
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.home_rounded, 'Home', '/home'),
                _navItem(Icons.explore_rounded, 'Explore', '/explore'),
                _navItem(Icons.account_balance_wallet_rounded, 'Wallet', '/wallet'),
                _navItemActive(),
                _navItem(Icons.person_rounded, 'Profile', '/profile'),
              ],
            ),
          ),
        ),
      );

  Widget _navItem(IconData icon, String label, String route) =>
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
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F3FB),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_rounded,
                color: _primary, size: 22),
            const SizedBox(width: 6),
            Text(
              'Activity',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _primary),
            ),
          ],
        ),
      );

  // ── Pending Review Row ───────────────────────────────────
  Widget _pendingReviewRow(BuildContext context, Map<String, dynamic> txn) {
    final rawTitle = txn['title'] as String;
    final earnedCashback = txn['earnedCashback'] as String?;

    return InkWell(
      onTap: () => _showActivityReviewSheet(context, txn),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icon — amber to signal pending action
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(txn['icon'] as IconData, color: _amber, size: 20),
            ),
            const SizedBox(width: 12),

            // Partner name + date + cashback badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rawTitle,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _dark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    txn['date'] as String,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rate_review_rounded,
                                size: 9, color: _amber),
                            const SizedBox(width: 3),
                            Text('Review Pending',
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _amber)),
                          ],
                        ),
                      ),
                      if (earnedCashback != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 9, color: _green),
                              const SizedBox(width: 2),
                              Text('$earnedCashback back',
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: _green)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Amount + Leave Review button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  txn['amount'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _red),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _showActivityReviewSheet(context, txn),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _amber.withOpacity(0.5)),
                    ),
                    child: Text('Leave Review',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _amber)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Review sheet (activity screen) ──────────────────────
  void _showActivityReviewSheet(BuildContext context, Map<String, dynamic> txn) {
    final rawTitle = txn['title'] as String;
    final String partnerName;
    if (rawTitle.startsWith('Spent at ')) {
      partnerName = rawTitle.substring(9);
    } else if (rawTitle.contains(' — Cashback')) {
      partnerName = rawTitle.split(' — ')[0];
    } else {
      partnerName = rawTitle;
    }
    final transactionId = txn['id'] as String? ?? '';
    final amountValue = (txn['amountValue'] as num?)?.toDouble() ??
        double.tryParse(
            (txn['amount'] as String).replaceAll(RegExp(r'[£+\-]'), '')) ??
        0.0;

    int selectedStars = 0;
    bool submitted = false;
    bool isSubmitting = false;
    final reviewController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> handleSubmit() async {
            if (isSubmitting) return;
            if (selectedStars == 0) {
              GoOutsSheet.warning(context,
                title: 'Please tap a star',
                message: 'Please tap a star to rate your visit first.',
              );
              return;
            }
            setSheetState(() => isSubmitting = true);
            try {
              final saved = await TransactionService().addReview(
                merchant: partnerName,
                rating: selectedStars,
                review: reviewController.text.trim(),
                amount: amountValue.abs(),
                cashback: 0,
                transactionId: transactionId,
              );
              if (!ctx.mounted) return;
              if (!saved) {
                // Already reviewed — remove from pending list
                setSheetState(() => isSubmitting = false);
                if (transactionId.isNotEmpty) {
                  setState(() => _reviewedTxnIds.add(transactionId));
                }
                Navigator.pop(ctx);
                GoOutsSheet.info(context,
                  title: 'Already Reviewed',
                  message: 'You have already reviewed this visit.',
                );
                return;
              }
              // Update points
              final userData = await UserService().getCurrentUser();
              final int curPoints =
                  (userData?['reviewPoints'] as num?)?.toInt() ?? 0;
              final int newPoints =
                  (curPoints + _pointsPerReview).clamp(0, _pointsForBonus);
              await UserService().updateUser({'reviewPoints': newPoints});
              if (!ctx.mounted) return;
              setState(() {
                _reviewPoints = newPoints;
                if (transactionId.isNotEmpty) {
                  _reviewedTxnIds.add(transactionId);
                }
              });
              setSheetState(() {
                isSubmitting = false;
                submitted = true;
              });
            } catch (_) {
              if (!ctx.mounted) return;
              setSheetState(() => isSubmitting = false);
              GoOutsSheet.error(context,
                title: 'Could not submit. Please',
                message: 'Could not submit. Please try again.',
              );
            }
          }

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: submitted
                  ? _buildActivityReviewSuccess(ctx, partnerName)
                  : _buildActivityReviewForm(
                      ctx,
                      partnerName,
                      selectedStars,
                      reviewController,
                      (stars) => setSheetState(() => selectedStars = stars),
                      handleSubmit,
                      isSubmitting: isSubmitting,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityReviewForm(
    BuildContext ctx,
    String partnerName,
    int selectedStars,
    TextEditingController controller,
    void Function(int) onStarTap,
    Future<void> Function() onSubmit, {
    bool isSubmitting = false,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          // Points progress pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: _green, size: 15),
                const SizedBox(width: 6),
                Text(
                    '$_reviewPoints/$_pointsForBonus pts — review earns +$_pointsPerReview pts',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _green)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('🎉 How was your visit to',
              style: GoogleFonts.inter(
                  fontSize: 14, color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text(partnerName,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _dark)),
          const SizedBox(height: 20),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < selectedStars;
              return GestureDetector(
                onTap: () => onStarTap(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: filled ? Colors.amber : Colors.grey[300],
                    size: 40,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            selectedStars == 0
                ? 'Tap a star to rate'
                : selectedStars == 5
                    ? 'Excellent!'
                    : selectedStars == 4
                        ? 'Very Good!'
                        : selectedStars == 3
                            ? 'Good'
                            : selectedStars == 2
                                ? 'Fair'
                                : 'Poor',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selectedStars == 0
                    ? Colors.grey[400]
                    : Colors.amber[700]),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: controller,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14, color: _dark),
              decoration: InputDecoration(
                hintText: 'Share your experience... (optional)',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[400]),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : () => onSubmit(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSubmitting
                    ? Colors.grey[300]
                    : selectedStars > 0
                        ? _primary
                        : _primary.withOpacity(0.45),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text('Submit Review',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Maybe Later',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey[500])),
          ),
        ],
      );

  Widget _buildActivityReviewSuccess(
      BuildContext ctx, String partnerName) {
    final pts = _reviewPoints.clamp(0, _pointsForBonus);
    final remaining = _pointsForBonus - pts;
    final bonusUnlocked = pts >= _pointsForBonus;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
              color: _green.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded,
              color: _green, size: 38),
        ),
        const SizedBox(height: 14),
        Text('Review Submitted!',
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _dark)),
        const SizedBox(height: 6),
        Text('Thank you for reviewing $partnerName',
            style:
                GoogleFonts.inter(fontSize: 13, color: Colors.grey[500])),
        const SizedBox(height: 20),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_rounded,
                  color: _green, size: 18),
              const SizedBox(width: 6),
              Text('+$_pointsPerReview Points Earned',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _green)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFE0A500), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    bonusUnlocked
                        ? '🎉 £10 Bonus Unlocked!'
                        : '$pts / $_pointsForBonus pts — £10 Bonus',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _dark),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pts / _pointsForBonus,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFE0A500)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bonusUnlocked
                    ? '£10 bonus has been added to your wallet!'
                    : '$remaining more points to earn your £10 bonus!',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Done',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
import '../widgets/goouts_sheet.dart';
}
