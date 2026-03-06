// ignore_for_file: unused_local_variable

import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/services/owner_request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AdminHome extends StatefulWidget {
  final VoidCallback onToggleAppBar;

  const AdminHome({super.key, required this.onToggleAppBar});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ============== SERVICES ==============
  final OwnerRequestService _ownerRequestService = OwnerRequestService();

  // ============== ADVANCED STATE MANAGEMENT ==============
  AnimationController? _headerController;
  AnimationController? _pulseController;
  AnimationController? _shimmerController;

  late final ScrollController _scrollController;
  FocusNode? _searchFocusNode;
  late final AnimationController _refreshController;
  // ignore: unused_field
  late final Animation<double> _fadeAnimation;

  // Track loading states for each request
  final Set<String> _loadingRequests = {};

  // Filter and sort states
  bool _useSorting = true;
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Debounce for search
  Timer? _debounceTimer;

  // Stats counters with animation
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _totalCount = 0;

  // Performance metrics
  int _averageResponseTime = 0;
  int _approvalRate = 0;

  // View mode
  bool _isGridView = false;
  bool _isCompactMode = false;

  // Selected items for bulk actions
  final Set<String> _selectedRequests = {};

  // Sort options
  String _selectedSortBy = 'createdAt';
  bool _sortAscending = false;

  // Pagination
  final int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  List<DocumentSnapshot> _allRequests = [];

  // Statistics history for charts
  // ignore: unused_field
  List<Map<String, dynamic>> _statsHistory = [];

  // Real-time stats notifiers
  Map<String, ValueNotifier<int>>? _statsNotifiers;

  // Action timers for timeout handling
  final Map<String, Timer> _actionTimers = {};

  // Expanded cards state
  final Map<String, bool> _expandedCards = {};

  // Real-time subscriptions
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  User? _currentUser;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();

    // Initialize ALL controllers FIRST
    _scrollController = ScrollController();
    _searchFocusNode = FocusNode();

    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _refreshController, curve: Curves.easeIn),
    );

    _scrollController.addListener(_onScroll);

    _headerController!.forward();
    _pulseController!.repeat(reverse: true);
    _shimmerController!.repeat();
    _refreshController.forward();

    _initializeStatsNotifiers();
    _setupRealTimeListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadStats();
        _loadStatsHistory();
        _calculateMetrics();
        _loadInitialRequests();
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  void _initializeStatsNotifiers() {
    _statsNotifiers = {
      'pending': ValueNotifier<int>(0),
      'approved': ValueNotifier<int>(0),
      'rejected': ValueNotifier<int>(0),
      'total': ValueNotifier<int>(0),
    };
  }

  void _setupRealTimeListener() {
    _requestsSubscription = _ownerRequestService.listenToOwnerRequests().listen(
      (snapshot) {
        if (mounted) {
          // Update stats when data changes
          _loadStats();
          _loadStatsHistory();
          _calculateMetrics();

          // Refresh the list if needed
          if (_allRequests.isNotEmpty) {
            _loadInitialRequests();
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _debounceTimer?.cancel();
    _headerController?.dispose();
    _pulseController?.dispose();
    _shimmerController?.dispose();
    _refreshController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode?.dispose();
    _actionTimers.forEach((_, timer) => timer.cancel());
    _actionTimers.clear();
    _statsNotifiers!.values.forEach((notifier) => notifier.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============== ENHANCED DATA LOADING ==============
  Future<void> _loadInitialRequests() async {
    _allRequests.clear();
    _lastDocument = null;
    _hasMoreData = true;
    await _loadMoreRequests(reset: true);
  }

  Future<void> _loadMoreRequests({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMoreData && !reset)) return;

    setState(() => _isLoadingMore = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('owner_requests')
          .orderBy(_selectedSortBy, descending: !_sortAscending)
          .limit(_pageSize);

      if (_selectedFilter != 'all') {
        query = query.where('status', isEqualTo: _selectedFilter);
      }

      if (!reset && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (reset) {
        _allRequests = snapshot.docs;
      } else {
        _allRequests.addAll(snapshot.docs);
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMoreData = snapshot.docs.length == _pageSize;
      } else {
        _hasMoreData = false;
      }

      setState(() {});
    } catch (e) {
      print('Error loading more requests: $e');
      if (mounted) {
        FirebaseSnackbar.error(context, 'Error loading requests');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreRequests();
    }
  }

  Future<void> _loadStats() async {
    try {
      final pending = await FirebaseFirestore.instance
          .collection('owner_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      final approved = await FirebaseFirestore.instance
          .collection('owner_requests')
          .where('status', isEqualTo: 'approved')
          .count()
          .get();

      final rejected = await FirebaseFirestore.instance
          .collection('owner_requests')
          .where('status', isEqualTo: 'rejected')
          .count()
          .get();

      final total = await FirebaseFirestore.instance
          .collection('owner_requests')
          .count()
          .get();

      setState(() {
        _pendingCount = pending.count!;
        _approvedCount = approved.count!;
        _rejectedCount = rejected.count!;
        _totalCount = total.count!;
      });

      _statsNotifiers?['pending']?.value = _pendingCount;
      _statsNotifiers?['approved']?.value = _approvedCount;
      _statsNotifiers?['rejected']?.value = _rejectedCount;
      _statsNotifiers?['total']?.value = _totalCount;
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  Future<void> _loadStatsHistory() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await FirebaseFirestore.instance
          .collection('owner_requests')
          .where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .orderBy('createdAt', descending: false)
          .get();

      final Map<String, Map<String, int>> dailyStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['createdAt'] as Timestamp?;
        if (timestamp == null) continue;

        final date = DateFormat('yyyy-MM-dd').format(timestamp.toDate());

        if (!dailyStats.containsKey(date)) {
          dailyStats[date] = {'pending': 0, 'approved': 0, 'rejected': 0};
        }

        final status = data['status'] ?? 'pending';
        dailyStats[date]![status] = (dailyStats[date]![status] ?? 0) + 1;
      }

      _statsHistory = dailyStats.entries.map((entry) {
        return {'date': entry.key, ...entry.value};
      }).toList();
    } catch (e) {
      print('Error loading stats history: $e');
    }
  }

  Future<void> _calculateMetrics() async {
    try {
      final processedRequests = await FirebaseFirestore.instance
          .collection('owner_requests')
          .where('status', whereIn: ['approved', 'rejected'])
          .limit(100)
          .get();

      int totalResponseTime = 0;
      int processedCount = 0;

      for (var doc in processedRequests.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        final processedAt =
            (data['approvedAt'] ?? data['rejectedAt']) as Timestamp?;

        if (createdAt != null && processedAt != null) {
          final responseTime = processedAt
              .toDate()
              .difference(createdAt.toDate())
              .inHours;
          totalResponseTime += responseTime;
          processedCount++;
        }
      }

      if (processedCount > 0) {
        setState(() {
          _averageResponseTime = (totalResponseTime / processedCount).round();
        });
      }

      if (_totalCount > 0) {
        setState(() {
          _approvalRate = ((_approvedCount / _totalCount) * 100).round();
        });
      }
    } catch (e) {
      print('Error calculating metrics: $e');
    }
  }

  // ============== ENHANCED ACTION METHODS ==============
  void _startActionTimer(String requestId) {
    _actionTimers[requestId] = Timer(const Duration(seconds: 15), () {
      if (_loadingRequests.contains(requestId) && mounted) {
        setState(() => _loadingRequests.remove(requestId));
        FirebaseSnackbar.error(context, 'Operation timed out');
      }
    });
  }

  void _cancelActionTimer(String requestId) {
    _actionTimers[requestId]?.cancel();
    _actionTimers.remove(requestId);
  }

  Future<void> approveOwner(
    BuildContext context,
    String requestId,
    String userId, {
    bool isBulk = false,
    String? adminNote,
  }) async {
    if (!isBulk) {
      _startActionTimer(requestId);
      setState(() => _loadingRequests.add(requestId));
    }

    final firestore = FirebaseFirestore.instance;

    try {
      final batch = firestore.batch();

      final requestRef = firestore.collection("owner_requests").doc(requestId);
      batch.update(requestRef, {
        "status": "approved",
        "approvedAt": FieldValue.serverTimestamp(),
        "approvedBy": FirebaseAuth.instance.currentUser?.uid,
        "approvedByEmail": FirebaseAuth.instance.currentUser?.email,
        "adminNote": adminNote ?? '',
        "responseTime": FieldValue.serverTimestamp(),
      });

      final userRef = firestore.collection("users").doc(userId);
      batch.update(userRef, {
        "role": "owner",
        "isApproved": true,
        "approvedAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
        "approvedBy": FirebaseAuth.instance.currentUser?.uid,
      });

      final logRef = firestore.collection("admin_activity").doc();
      batch.set(logRef, {
        "type": "approve_owner",
        "requestId": requestId,
        "userId": userId,
        "adminId": FirebaseAuth.instance.currentUser?.uid,
        "adminEmail": FirebaseAuth.instance.currentUser?.email,
        "timestamp": FieldValue.serverTimestamp(),
        "details": "Owner application approved",
      });

      await batch.commit();

      if (!mounted) return;

      if (!isBulk) {
        FirebaseSnackbar.success(context, "Owner approved successfully");
      }

      _loadStats();
      _calculateMetrics();
      _loadStatsHistory();

      setState(() {
        _allRequests.removeWhere((doc) => doc.id == requestId);
      });
    } catch (e) {
      print("Approval error: $e");

      if (!mounted) return;

      if (!isBulk) {
        FirebaseSnackbar.error(context, "Approval failed: ${e.toString()}");
      }
    } finally {
      if (!isBulk && mounted) {
        _cancelActionTimer(requestId);
        setState(() => _loadingRequests.remove(requestId));
      }
    }
  }

  Future<void> _batchApprove() async {
    if (_selectedRequests.isEmpty) {
      FirebaseSnackbar.warning(context, "No requests selected");
      return;
    }

    String? adminNote;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _BatchActionDialog(
        title: "Batch Approve",
        count: _selectedRequests.length,
        actionColor: Colors.green,
        onNoteChanged: (note) => adminNote = note,
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loadingRequests.addAll(_selectedRequests);
    });

    int successCount = 0;
    int failCount = 0;

    for (String requestId in _selectedRequests) {
      try {
        final requestDoc = await FirebaseFirestore.instance
            .collection('owner_requests')
            .doc(requestId)
            .get();

        if (requestDoc.exists) {
          final userId = requestDoc.data()?['userId'];
          if (userId != null) {
            await approveOwner(
              context,
              requestId,
              userId,
              isBulk: true,
              adminNote: adminNote,
            );
            successCount++;
          }
        }
      } catch (e) {
        failCount++;
      }
    }

    setState(() {
      _loadingRequests.clear();
      _selectedRequests.clear();
    });

    if (successCount > 0) {
      FirebaseSnackbar.success(
        context,
        "Successfully approved $successCount request(s)",
      );
    }

    if (failCount > 0) {
      FirebaseSnackbar.error(
        context,
        "Failed to approve $failCount request(s)",
      );
    }
  }

  Future<void> rejectOwner(
    BuildContext context,
    String requestId, {
    bool isBulk = false,
    String? rejectionReason,
  }) async {
    if (!isBulk) {
      _startActionTimer(requestId);
      setState(() => _loadingRequests.add(requestId));
    }

    try {
      final batch = FirebaseFirestore.instance.batch();

      final requestRef = FirebaseFirestore.instance
          .collection("owner_requests")
          .doc(requestId);

      batch.update(requestRef, {
        "status": "rejected",
        "rejectedAt": FieldValue.serverTimestamp(),
        "rejectedBy": FirebaseAuth.instance.currentUser?.uid,
        "rejectedByEmail": FirebaseAuth.instance.currentUser?.email,
        "rejectionReason": rejectionReason ?? 'Not specified',
        "responseTime": FieldValue.serverTimestamp(),
      });

      final logRef = FirebaseFirestore.instance
          .collection("admin_activity")
          .doc();
      batch.set(logRef, {
        "type": "reject_owner",
        "requestId": requestId,
        "adminId": FirebaseAuth.instance.currentUser?.uid,
        "adminEmail": FirebaseAuth.instance.currentUser?.email,
        "timestamp": FieldValue.serverTimestamp(),
        "reason": rejectionReason,
      });

      await batch.commit();

      if (!mounted) return;

      if (!isBulk) {
        FirebaseSnackbar.warning(context, "Application rejected");
      }

      _loadStats();
      _calculateMetrics();
      _loadStatsHistory();

      setState(() {
        _allRequests.removeWhere((doc) => doc.id == requestId);
      });
    } catch (e) {
      print("Reject error: $e");

      if (!mounted) return;

      if (!isBulk) {
        FirebaseSnackbar.error(context, "Reject failed: ${e.toString()}");
      }
    } finally {
      if (!isBulk && mounted) {
        _cancelActionTimer(requestId);
        setState(() => _loadingRequests.remove(requestId));
      }
    }
  }

  Future<void> _batchReject() async {
    if (_selectedRequests.isEmpty) {
      FirebaseSnackbar.warning(context, "No requests selected");
      return;
    }

    String? rejectionReason;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _BatchActionDialog(
        title: "Batch Reject",
        count: _selectedRequests.length,
        actionColor: Colors.red,
        onNoteChanged: (reason) => rejectionReason = reason,
        hintText: "Enter rejection reason (optional)",
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loadingRequests.addAll(_selectedRequests);
    });

    int successCount = 0;
    int failCount = 0;

    for (String requestId in _selectedRequests) {
      try {
        await rejectOwner(
          context,
          requestId,
          isBulk: true,
          rejectionReason: rejectionReason,
        );
        successCount++;
      } catch (e) {
        failCount++;
      }
    }

    setState(() {
      _loadingRequests.clear();
      _selectedRequests.clear();
    });

    if (successCount > 0) {
      FirebaseSnackbar.success(
        context,
        "Successfully rejected $successCount request(s)",
      );
    }

    if (failCount > 0) {
      FirebaseSnackbar.error(context, "Failed to reject $failCount request(s)");
    }
  }

  Future<void> _viewRequestDetails(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RequestDetailsSheet(
        requestData: data,
        requestId: doc.id,
        onApprove: () {
          Navigator.pop(context);
          approveOwner(context, doc.id, data["userId"] ?? "");
        },
        onReject: () {
          Navigator.pop(context);
          rejectOwner(context, doc.id);
        },
      ),
    );
  }

  void _toggleViewMode() {
    setState(() => _isGridView = !_isGridView);
  }

  void _toggleCompactMode() {
    setState(() => _isCompactMode = !_isCompactMode);
  }

  void _clearSelection() {
    setState(() => _selectedRequests.clear());
  }

  Future<void> _exportData() async {
    try {
      FirebaseSnackbar.info(context, "Preparing export...");

      final snapshot = await FirebaseFirestore.instance
          .collection('owner_requests')
          .get();

      final csv = _generateCSV(snapshot.docs);

      FirebaseSnackbar.success(
        context,
        "Exported ${snapshot.docs.length} requests",
      );

      print(csv);
    } catch (e) {
      FirebaseSnackbar.error(context, "Export failed: $e");
    }
  }

  String _generateCSV(List<DocumentSnapshot> docs) {
    final headers = [
      'ID',
      'Shop Name',
      'Owner Name',
      'Email',
      'Phone',
      'Category',
      'Status',
      'Created At',
      'Approved At',
    ];

    final rows = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return [
        doc.id,
        data['shopName'] ?? '',
        data['ownerName'] ?? '',
        data['email'] ?? '',
        data['phone'] ?? '',
        data['category'] ?? '',
        data['status'] ?? 'pending',
        _formatDate(data['createdAt'] as Timestamp?),
        _formatDate(data['approvedAt'] as Timestamp?),
      ].join(',');
    }).toList();

    return [headers.join(','), ...rows].join('\n');
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate());
  }

  // ============== ENHANCED UI ==============
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1100;
    final isDesktop = size.width >= 1100;
    final isLargeDesktop = size.width >= 1600;
    final isSmallPhone = size.width < 360;

    double horizontalPadding = isSmallPhone ? 8 : 16;
    if (isTablet) horizontalPadding = 24;
    if (isDesktop) horizontalPadding = 32;
    if (isLargeDesktop) horizontalPadding = 48;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.deepPurple.shade50, Colors.white, Colors.white],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: isMobile ? 12 : 16,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildHeader(
                          isMobile,
                          isDesktop,
                          isLargeDesktop,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: isMobile ? 12 : 16),
                      ),
                      SliverToBoxAdapter(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: isMobile ? 90 : 100,
                            maxWidth: constraints.maxWidth,
                          ),
                          child: _buildStatsSection(isMobile, isDesktop),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: isMobile ? 12 : 16),
                      ),
                      SliverToBoxAdapter(child: _buildMetricsRow(isMobile)),
                      SliverToBoxAdapter(
                        child: SizedBox(height: isMobile ? 12 : 16),
                      ),
                      SliverToBoxAdapter(
                        child: _buildSearchAndFilterBar(isMobile, isTablet),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(child: _buildViewOptionsBar(isMobile)),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(child: _buildActionBar(isMobile)),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      _isGridView
                          ? _buildResponsiveGridSliver(
                              isMobile,
                              isDesktop,
                              isLargeDesktop,
                            )
                          : _buildResponsiveListSliver(isMobile),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveListSliver(bool isMobile) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getQueryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _allRequests.isEmpty) {
          return SliverToBoxAdapter(child: _buildLoadingShimmer(isMobile));
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(child: _buildErrorState(snapshot.error));
        }

        List<DocumentSnapshot> docs = _allRequests;

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['shopName']?.toString().toLowerCase() ?? '').contains(
                  _searchQuery,
                ) ||
                (data['ownerName']?.toString().toLowerCase() ?? '').contains(
                  _searchQuery,
                ) ||
                (data['email']?.toString().toLowerCase() ?? '').contains(
                  _searchQuery,
                ) ||
                (data['phone']?.toString() ?? '').contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(search: _searchQuery.isNotEmpty),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == docs.length && _hasMoreData) {
              return _buildLoadingMoreIndicator();
            }
            if (index >= docs.length) return null;

            return TweenAnimationBuilder<double>(
              duration: Duration(
                milliseconds: 300 + (index * 50).clamp(0, 1000),
              ),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _isCompactMode
                          ? _buildCompactRequestCard(docs[index], isMobile)
                          : _buildRequestCard(docs[index], isMobile),
                    ),
                  ),
                );
              },
            );
          }, childCount: docs.length + (_hasMoreData ? 1 : 0)),
        );
      },
    );
  }

  Widget _buildResponsiveGridSliver(
    bool isMobile,
    bool isDesktop,
    bool isLargeDesktop,
  ) {
    int crossAxisCount = 1;
    if (isLargeDesktop)
      crossAxisCount = 4;
    else if (isDesktop)
      crossAxisCount = 3;
    else if (!isMobile)
      crossAxisCount = 2;

    return StreamBuilder<QuerySnapshot>(
      stream: _getQueryStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _allRequests.isEmpty) {
          return SliverToBoxAdapter(child: _buildLoadingShimmer(isMobile));
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(child: _buildErrorState(snapshot.error));
        }

        List<DocumentSnapshot> docs = _allRequests;

        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return (data['shopName']?.toString().toLowerCase() ?? '').contains(
                  _searchQuery,
                ) ||
                (data['ownerName']?.toString().toLowerCase() ?? '').contains(
                  _searchQuery,
                ) ||
                (data['email']?.toString().toLowerCase() ?? '').contains(
                  _searchQuery,
                ) ||
                (data['phone']?.toString() ?? '').contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(search: _searchQuery.isNotEmpty),
          );
        }

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: _isCompactMode ? 1.0 : 1.2,
            crossAxisSpacing: isMobile ? 12 : 16,
            mainAxisSpacing: isMobile ? 12 : 16,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= docs.length) return null;

            return TweenAnimationBuilder<double>(
              duration: Duration(
                milliseconds: 300 + (index * 30).clamp(0, 1000),
              ),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.9 + (0.1 * value),
                    child: _isCompactMode
                        ? _buildCompactGridRequestCard(docs[index], isMobile)
                        : _buildGridRequestCard(docs[index], isMobile),
                  ),
                );
              },
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile, bool isDesktop, bool isLargeDesktop) {
    return FadeTransition(
      opacity: _headerController!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 12 : 14),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.deepPurple, Colors.purple],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                  spreadRadius: -5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Colors.white,
                              size: isMobile ? 24 : 28,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              color: Colors.deepPurple.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Owner Applications",
                            style: TextStyle(
                              fontSize: isMobile
                                  ? 24
                                  : isDesktop
                                  ? 32
                                  : 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              foreground: Paint()
                                ..shader =
                                    const LinearGradient(
                                      colors: [
                                        Colors.deepPurple,
                                        Colors.purple,
                                      ],
                                    ).createShader(
                                      const Rect.fromLTWH(0, 0, 200, 70),
                                    ),
                            ),
                          ),
                          Text(
                            "Manage seller requests",
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderActions(isMobile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(bool isMobile) {
    return Row(
      children: [
        if (_selectedRequests.isNotEmpty)
          _buildHeaderAction(
            icon: Icons.close_rounded,
            tooltip: "Clear selection",
            onPressed: _clearSelection,
            color: Colors.red,
            isMobile: isMobile,
          ),
        if (_selectedRequests.isNotEmpty) const SizedBox(width: 8),
        _buildHeaderAction(
          icon: Icons.download_rounded,
          tooltip: "Export data",
          onPressed: _exportData,
          color: Colors.green,
          isMobile: isMobile,
        ),
        const SizedBox(width: 8),
        _buildHeaderAction(
          icon: _isCompactMode
              ? Icons.view_stream_rounded
              : Icons.view_cozy_rounded,
          tooltip: _isCompactMode ? "Comfortable view" : "Compact view",
          onPressed: _toggleCompactMode,
          color: Colors.teal,
          isMobile: isMobile,
        ),
        const SizedBox(width: 8),
        _buildHeaderAction(
          icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
          tooltip: _isGridView ? "List view" : "Grid view",
          onPressed: _toggleViewMode,
          color: Colors.blue,
          isMobile: isMobile,
        ),
        const SizedBox(width: 8),
        _buildHeaderAction(
          icon: Icons.refresh_rounded,
          tooltip: "Refresh",
          onPressed: () {
            _refreshController.reset();
            _refreshController.forward();
            _loadStats();
            _loadStatsHistory();
            _calculateMetrics();
            _loadInitialRequests();
            FirebaseSnackbar.info(context, "Refreshed");
          },
          color: Colors.orange,
          isMobile: isMobile,
          showLoader: _isLoadingMore,
        ),
      ],
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color color,
    required bool isMobile,
    bool showLoader = false,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 10),
                  child: showLoader
                      ? SizedBox(
                          width: isMobile ? 20 : 24,
                          height: isMobile ? 20 : 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      : Icon(icon, color: color, size: isMobile ? 20 : 24),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsSection(bool isMobile, bool isDesktop) {
    if (_statsNotifiers == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showFullStats = constraints.maxWidth > 700;

        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatCard(
                        "Pending",
                        _statsNotifiers!['pending']!,
                        Colors.orange,
                        Icons.pending_actions_rounded,
                        isMobile,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        "Approved",
                        _statsNotifiers!['approved']!,
                        Colors.green,
                        Icons.check_circle_rounded,
                        isMobile,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        "Rejected",
                        _statsNotifiers!['rejected']!,
                        Colors.red,
                        Icons.cancel_rounded,
                        isMobile,
                      ),
                      const SizedBox(width: 8),
                      _buildStatCard(
                        "Total",
                        _statsNotifiers!['total']!,
                        Colors.deepPurple,
                        Icons.numbers_rounded,
                        isMobile,
                      ),
                      if (showFullStats) ...[
                        const SizedBox(width: 8),
                        _buildMetricCard(
                          "Avg. Response",
                          "$_averageResponseTime hrs",
                          Icons.timer_rounded,
                          Colors.blue,
                          isMobile,
                        ),
                        const SizedBox(width: 8),
                        _buildMetricCard(
                          "Approval Rate",
                          "$_approvalRate%",
                          Icons.analytics_rounded,
                          Colors.teal,
                          isMobile,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    ValueNotifier<int> countNotifier,
    Color color,
    IconData icon,
    bool isMobile,
  ) {
    return Container(
      constraints: BoxConstraints(
        minWidth: isMobile ? 100 : 120,
        maxWidth: isMobile ? 130 : 150,
      ),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                    spreadRadius: -3,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: isMobile ? 16 : 20),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: countNotifier,
                          builder: (context, count, _) {
                            return AnimatedCount(
                              count: count,
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            );
                          },
                        ),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 10,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Container(
      constraints: BoxConstraints(
        minWidth: isMobile ? 100 : 120,
        maxWidth: isMobile ? 130 : 150,
      ),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: -3,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: isMobile ? 16 : 20),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isMobile ? 8 : 9,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMiniMetric(
            icon: Icons.timer_rounded,
            label: "Response",
            value: "$_averageResponseTime hrs",
            color: Colors.blue,
          ),
          const SizedBox(width: 12),
          _buildMiniMetric(
            icon: Icons.analytics_rounded,
            label: "Approval",
            value: "$_approvalRate%",
            color: Colors.teal,
          ),
          const SizedBox(width: 12),
          _buildMiniMetric(
            icon: Icons.trending_up_rounded,
            label: "Conversion",
            value: _totalCount > 0
                ? "${((_approvedCount / _totalCount) * 100).toStringAsFixed(1)}%"
                : "0%",
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(bool isMobile, bool isTablet) {
    if (_searchFocusNode == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _searchFocusNode!.hasFocus
                    ? Colors.deepPurple
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(
                  Icons.search_rounded,
                  color: _searchFocusNode!.hasFocus
                      ? Colors.deepPurple
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: "Search by shop name, owner, email, phone...",
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                    style: TextStyle(fontSize: isMobile ? 14 : 15),
                    onChanged: _onSearchChanged,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: _clearSearch,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("All", "all", _selectedFilter, (val) {
                  setState(() => _selectedFilter = val);
                  _loadInitialRequests();
                }),
                const SizedBox(width: 8),
                _buildFilterChip("Pending", "pending", _selectedFilter, (val) {
                  setState(() => _selectedFilter = val);
                  _loadInitialRequests();
                }, color: Colors.orange),
                const SizedBox(width: 8),
                _buildFilterChip("Approved", "approved", _selectedFilter, (
                  val,
                ) {
                  setState(() => _selectedFilter = val);
                  _loadInitialRequests();
                }, color: Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip("Rejected", "rejected", _selectedFilter, (
                  val,
                ) {
                  setState(() => _selectedFilter = val);
                  _loadInitialRequests();
                }, color: Colors.red),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: Colors.grey.shade300),
                const SizedBox(width: 8),
                _buildSortChip("Date", "createdAt", _selectedSortBy, (val) {
                  setState(() => _selectedSortBy = val);
                  _loadInitialRequests();
                }),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    _sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    setState(() => _sortAscending = !_sortAscending);
                    _loadInitialRequests();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onSelected, {
    Color color = Colors.deepPurple,
  }) {
    final isSelected = selectedValue == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? color : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onSelected, {
    Color color = Colors.deepPurple,
    IconData? icon,
  }) {
    final isSelected = selectedValue == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? color : Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  _sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.toLowerCase().trim();
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Widget _buildViewOptionsBar(bool isMobile) {
    return Row(
      children: [
        _buildViewOptionChip(
          icon: _isCompactMode
              ? Icons.view_stream_rounded
              : Icons.view_cozy_rounded,
          label: _isCompactMode ? "Compact" : "Comfortable",
          isSelected: true,
          onTap: _toggleCompactMode,
        ),
        const SizedBox(width: 8),
        _buildViewOptionChip(
          icon: _isGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
          label: _isGridView ? "Grid" : "List",
          isSelected: true,
          onTap: _toggleViewMode,
        ),
        const Spacer(),
        if (_selectedRequests.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(
                  "${_selectedRequests.length} selected",
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: _clearSelection,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.deepPurple,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildViewOptionChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.deepPurple, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.deepPurple,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(bool isMobile) {
    if (_selectedRequests.isEmpty) return const SizedBox.shrink();

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                TweenAnimationBuilder<int>(
                  duration: const Duration(milliseconds: 200),
                  tween: IntTween(begin: 0, end: _selectedRequests.length),
                  builder: (context, count, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '$count selected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildActionChip(
                          label: "Approve",
                          icon: Icons.check_circle_rounded,
                          color: Colors.green,
                          onPressed: _batchApprove,
                        ),
                        const SizedBox(width: 8),
                        _buildActionChip(
                          label: "Reject",
                          icon: Icons.cancel_rounded,
                          color: Colors.red,
                          onPressed: _batchReject,
                        ),
                        const SizedBox(width: 8),
                        _buildActionChip(
                          label: "Clear",
                          icon: Icons.clear_rounded,
                          color: Colors.white,
                          onPressed: _clearSelection,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color == Colors.white ? Colors.deepPurple : color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color == Colors.white ? Colors.deepPurple : color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getQueryStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'owner_requests',
    );

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    if (_useSorting) {
      query = query.orderBy(_selectedSortBy, descending: !_sortAscending);
    }

    return query.snapshots();
  }

  Widget _buildRequestCard(DocumentSnapshot doc, bool isMobile) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final userId = data["userId"] ?? "";
    final isLoading = _loadingRequests.contains(requestId);
    final isSelected = _selectedRequests.contains(requestId);
    final isExpanded = _expandedCards[requestId] ?? false;
    final status = data["status"] ?? "pending";

    return GestureDetector(
      onLongPress: () {
        setState(() {
          if (isSelected) {
            _selectedRequests.remove(requestId);
          } else {
            _selectedRequests.add(requestId);
          }
        });
      },
      onTap: () => _viewRequestDetails(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isMobile ? 16 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? Colors.deepPurple : Colors.black)
                  .withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                Expanded(
                  child: Text(
                    data["shopName"] ?? "Unnamed Shop",
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.person_outline_rounded,
              data["ownerName"] ?? "N/A",
              isMobile,
            ),
            _buildDetailRow(
              Icons.phone_outlined,
              data["phone"] ?? "N/A",
              isMobile,
            ),
            _buildDetailRow(
              Icons.email_outlined,
              data["email"] ?? "N/A",
              isMobile,
            ),
            _buildDetailRow(
              Icons.category_outlined,
              data["category"] ?? "N/A",
              isMobile,
            ),
            if (!isExpanded) ...[
              _buildDetailRow(
                Icons.delivery_dining_outlined,
                data["deliveryType"] ?? "N/A",
                isMobile,
              ),
            ],
            if (isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Address:",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data["address"] ?? "No address provided",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (data["description"]?.toString().isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Description:",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data["description"],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (data["gstNumber"] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "GST: ${data["gstNumber"]}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(data["createdAt"] as Timestamp?),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedCards[requestId] = !isExpanded;
                    });
                  },
                  child: Row(
                    children: [
                      Text(
                        isExpanded ? "Show less" : "Show more",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: "Approve",
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      isLoading: isLoading,
                      onPressed: () => approveOwner(context, requestId, userId),
                      isMobile: isMobile,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      label: "Reject",
                      icon: Icons.close_rounded,
                      color: Colors.red,
                      isLoading: isLoading,
                      onPressed: () => rejectOwner(context, requestId),
                      isOutlined: true,
                      isMobile: isMobile,
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved' && data["approvedAt"] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Approved by ${data["approvedByEmail"]?.toString().split('@')[0] ?? 'Admin'}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _formatShortDate(data["approvedAt"] as Timestamp?),
                      style: const TextStyle(fontSize: 10, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ] else if (status == 'rejected' && data["rejectedAt"] != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Rejected by ${data["rejectedByEmail"]?.toString().split('@')[0] ?? 'Admin'}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatShortDate(data["rejectedAt"] as Timestamp?),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (data["rejectionReason"] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Reason: ${data["rejectionReason"]}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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

  Widget _buildCompactRequestCard(DocumentSnapshot doc, bool isMobile) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final userId = data["userId"] ?? "";
    final isLoading = _loadingRequests.contains(requestId);
    final isSelected = _selectedRequests.contains(requestId);
    final status = data["status"] ?? "pending";

    return GestureDetector(
      onLongPress: () {
        setState(() {
          if (isSelected) {
            _selectedRequests.remove(requestId);
          } else {
            _selectedRequests.add(requestId);
          }
        });
      },
      onTap: () => _viewRequestDetails(doc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 10),
              ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _getStatusGradient(status)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  (data["shopName"] ?? "S")[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data["shopName"] ?? "Unnamed Shop",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(status, small: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${data["ownerName"] ?? "N/A"} • ${data["phone"] ?? "N/A"}",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (status == 'pending')
              Row(
                children: [
                  _buildMiniActionButton(
                    icon: Icons.check,
                    color: Colors.green,
                    isLoading: isLoading,
                    onPressed: () => approveOwner(context, requestId, userId),
                  ),
                  const SizedBox(width: 4),
                  _buildMiniActionButton(
                    icon: Icons.close,
                    color: Colors.red,
                    isLoading: isLoading,
                    onPressed: () => rejectOwner(context, requestId),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridRequestCard(DocumentSnapshot doc, bool isMobile) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final userId = data["userId"] ?? "";
    final isLoading = _loadingRequests.contains(requestId);
    final isSelected = _selectedRequests.contains(requestId);
    final status = data["status"] ?? "pending";

    return GestureDetector(
      onLongPress: () {
        setState(() {
          if (isSelected) {
            _selectedRequests.remove(requestId);
          } else {
            _selectedRequests.add(requestId);
          }
        });
      },
      onTap: () => _viewRequestDetails(doc),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data["shopName"] ?? "Unnamed Shop",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildGridInfoRow(
              Icons.person_outline_rounded,
              data["ownerName"] ?? "N/A",
            ),
            _buildGridInfoRow(Icons.phone_outlined, data["phone"] ?? "N/A"),
            _buildGridInfoRow(
              Icons.category_outlined,
              data["category"] ?? "N/A",
            ),
            const SizedBox(height: 8),
            _buildStatusChip(status),
            const Spacer(),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatShortTimestamp(data["createdAt"] as Timestamp?),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const Spacer(),
                if (status == 'pending')
                  Row(
                    children: [
                      _buildMiniActionButton(
                        icon: Icons.check,
                        color: Colors.green,
                        isLoading: isLoading,
                        onPressed: () =>
                            approveOwner(context, requestId, userId),
                      ),
                      const SizedBox(width: 4),
                      _buildMiniActionButton(
                        icon: Icons.close,
                        color: Colors.red,
                        isLoading: isLoading,
                        onPressed: () => rejectOwner(context, requestId),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactGridRequestCard(DocumentSnapshot doc, bool isMobile) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final userId = data["userId"] ?? "";
    final isLoading = _loadingRequests.contains(requestId);
    final isSelected = _selectedRequests.contains(requestId);
    final status = data["status"] ?? "pending";

    return GestureDetector(
      onLongPress: () {
        setState(() {
          if (isSelected) {
            _selectedRequests.remove(requestId);
          } else {
            _selectedRequests.add(requestId);
          }
        });
      },
      onTap: () => _viewRequestDetails(doc),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getStatusGradient(status),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      (data["shopName"] ?? "S")[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data["shopName"] ?? "Shop",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip(status, small: true),
                Text(
                  _formatShortTimestamp(data["createdAt"] as Timestamp?),
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: isMobile ? 14 : 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: isMobile ? 13 : 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, {bool small = false}) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_rounded;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending_rounded;
        label = 'Pending';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: small ? 10 : 12),
          const SizedBox(width: 4),
          Text(
            small ? (status.isNotEmpty ? status[0].toUpperCase() : 'P') : label,
            style: TextStyle(
              color: color,
              fontSize: small ? 9 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onPressed,
    bool isOutlined = false,
    required bool isMobile,
  }) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: isLoading ? Colors.grey : color,
          side: BorderSide(color: isLoading ? Colors.grey : color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
        ),
        child: isLoading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: isMobile ? 16 : 18),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: isMobile ? 13 : 14)),
                ],
              ),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
      ),
      child: isLoading
          ? SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isMobile ? 16 : 18),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: isMobile ? 13 : 14)),
              ],
            ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isLoading ? Colors.grey.shade200 : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLoading ? Colors.grey : color.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, color: color, size: 14),
        ),
      ),
    );
  }

  List<Color> _getStatusGradient(String status) {
    switch (status) {
      case 'approved':
        return [Colors.green.shade400, Colors.green.shade700];
      case 'rejected':
        return [Colors.red.shade400, Colors.red.shade700];
      default:
        return [Colors.orange.shade400, Colors.deepOrange.shade600];
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat('dd MMM yyyy').format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatShortTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inMinutes}m';
    }
  }

  String _formatShortDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('dd MMM').format(timestamp.toDate());
  }

  Widget _buildLoadingShimmer(bool isMobile) {
    return Column(
      children: List.generate(5, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool search = false}) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      search ? Icons.search_off_rounded : Icons.inbox_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              search ? "No matching applications found" : "No applications yet",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              search
                  ? "Try adjusting your search or filter"
                  : "New applications will appear here",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (search)
              ElevatedButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Something went wrong",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                error?.toString() ?? 'Failed to load applications',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadInitialRequests,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = _userData?['name'] ?? _currentUser?.displayName ?? 'Admin';
    final firstName = name.split(' ')[0];

    String greeting;
    if (hour < 12)
      greeting = "Good Morning";
    else if (hour < 17)
      greeting = "Good Afternoon";
    else if (hour < 22)
      greeting = "Good Evening";
    else
      greeting = "Good Night";

    return "$greeting, $firstName 👋";
  }
}

// ============== CUSTOM DIALOGS ==============
class _BatchActionDialog extends StatefulWidget {
  final String title;
  final int count;
  final Color actionColor;
  final Function(String) onNoteChanged;
  final String hintText;

  const _BatchActionDialog({
    required this.title,
    required this.count,
    required this.actionColor,
    required this.onNoteChanged,
    this.hintText = "Enter admin note (optional)",
  });

  @override
  State<_BatchActionDialog> createState() => __BatchActionDialogState();
}

class __BatchActionDialogState extends State<_BatchActionDialog> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.actionColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.title.contains("Approve")
                  ? Icons.check_circle_rounded
                  : Icons.warning_rounded,
              color: widget.actionColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Are you sure you want to ${widget.title.toLowerCase()} ${widget.count} selected request(s)?",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: 2,
            onChanged: widget.onNoteChanged,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.actionColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(widget.title),
        ),
      ],
    );
  }
}

class _RequestDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final String requestId;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestDetailsSheet({
    required this.requestData,
    required this.requestId,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shopName = requestData["shopName"] ?? "Unnamed Shop";
    final ownerName = requestData["ownerName"] ?? "N/A";
    final email = requestData["email"] ?? "N/A";
    final phone = requestData["phone"] ?? "N/A";
    final category = requestData["category"] ?? "N/A";
    final deliveryType = requestData["deliveryType"] ?? "N/A";
    final address = requestData["address"] ?? "No address provided";
    final description = requestData["description"];
    final gstNumber = requestData["gstNumber"];
    final status = requestData["status"] ?? "pending";
    final createdAt = requestData["createdAt"] as Timestamp?;

    return Container(
      height: size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Application Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.purple.shade600,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              shopName.isNotEmpty
                                  ? shopName[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          shopName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusChip(status, large: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildDetailSection(
                    title: 'Owner Information',
                    icon: Icons.person_rounded,
                    children: [
                      _buildDetailItem('Name', ownerName),
                      _buildDetailItem('Email', email),
                      _buildDetailItem('Phone', phone),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailSection(
                    title: 'Shop Information',
                    icon: Icons.store_rounded,
                    children: [
                      _buildDetailItem('Category', category),
                      _buildDetailItem('Delivery Type', deliveryType),
                      if (gstNumber != null)
                        _buildDetailItem('GST Number', gstNumber),
                      _buildDetailItem('Address', address, isMultiline: true),
                    ],
                  ),
                  if (description != null &&
                      description.toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      title: 'Description',
                      icon: Icons.description_rounded,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            description,
                            style: const TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildDetailSection(
                    title: 'Timeline',
                    icon: Icons.access_time_rounded,
                    children: [
                      _buildTimelineItem(
                        'Applied',
                        _formatFullDate(createdAt),
                        Icons.edit_calendar_rounded,
                        Colors.blue,
                        isFirst: true,
                      ),
                      if (requestData["approvedAt"] != null)
                        _buildTimelineItem(
                          'Approved',
                          _formatFullDate(
                            requestData["approvedAt"] as Timestamp?,
                          ),
                          Icons.check_circle_rounded,
                          Colors.green,
                        ),
                      if (requestData["rejectedAt"] != null)
                        _buildTimelineItem(
                          'Rejected',
                          _formatFullDate(
                            requestData["rejectedAt"] as Timestamp?,
                          ),
                          Icons.cancel_rounded,
                          Colors.red,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (status == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onApprove();
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onReject();
                            },
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, {bool large = false}) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        icon = Icons.cancel_rounded;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        icon = Icons.pending_rounded;
        label = 'Pending';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 10,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: large ? 18 : 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: large ? 14 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value, {
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              maxLines: isMultiline ? null : 2,
              overflow: isMultiline
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    String time,
    IconData icon,
    Color color, {
    bool isFirst = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: 8, top: isFirst ? 0 : 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class AnimatedCount extends StatelessWidget {
  final int count;
  final TextStyle style;
  final Duration duration;

  const AnimatedCount({
    super.key,
    required this.count,
    required this.style,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      duration: duration,
      tween: IntTween(begin: 0, end: count),
      builder: (context, value, child) {
        return Text(value.toString(), style: style);
      },
    );
  }
}
