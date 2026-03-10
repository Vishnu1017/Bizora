// ignore_for_file: unused_local_variable

import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/services/owner_request_service.dart';
import 'package:bizora/widgets/ai_search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

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
  final ValueNotifier<List<DocumentSnapshot>> _aiSearchResults = ValueNotifier(
    [],
  );
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

  // Responsive scaling factors
  late double _screenWidth;
  // ignore: unused_field
  late double _screenHeight;
  late double _textScaleFactor;
  // ignore: unused_field
  late double _paddingScaleFactor;

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

    // SET INITIAL VALUES IMMEDIATELY (SYNCHRONOUS)
    _pendingCount = 0;
    _approvedCount = 0;
    _rejectedCount = 0;
    _totalCount = 0;
    _averageResponseTime = 0;
    _approvalRate = 0;

    // Initialize stats notifiers
    _statsNotifiers = {
      'pending': ValueNotifier<int>(0),
      'approved': ValueNotifier<int>(0),
      'rejected': ValueNotifier<int>(0),
      'total': ValueNotifier<int>(0),
      'avgResponse': ValueNotifier<int>(0),
      'approvalRate': ValueNotifier<int>(0),
    };

    // Mark as initialized immediately
    _isFirstLoad = true;

    _aiSearchResults.addListener(_onSearchResultsChanged);
    _setupRealTimeListener();

    // LOAD FROM CACHE FIRST (fastest)
    _loadCachedStats().then((_) {
      // After cache loads, update UI if needed
      if (mounted) {
        setState(() {});
      }
    });

    // Then load fresh data from Firebase
    _loadStats().then((_) {
      // Cache the fresh stats
      _cacheStats();
    });
    _loadStatsHistory();
    _calculateMetrics().then((_) {
      _cacheStats();
    });
    _loadInitialRequests();

    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _cacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt('cached_pending_count', _pendingCount);
      await prefs.setInt('cached_approved_count', _approvedCount);
      await prefs.setInt('cached_rejected_count', _rejectedCount);
      await prefs.setInt('cached_total_count', _totalCount);
      await prefs.setInt('cached_avg_response', _averageResponseTime);
      await prefs.setInt('cached_approval_rate', _approvalRate);
      await prefs.setInt(
        'stats_cache_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error caching stats: $e');
    }
  }

  Future<void> _loadCachedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached stats
      final pending = prefs.getInt('cached_pending_count');
      final approved = prefs.getInt('cached_approved_count');
      final rejected = prefs.getInt('cached_rejected_count');
      final total = prefs.getInt('cached_total_count');
      final avgResponse = prefs.getInt('cached_avg_response');
      final approvalRate = prefs.getInt('cached_approval_rate');
      final cacheTimestamp = prefs.getInt('stats_cache_timestamp') ?? 0;

      // Only use cache if it has values
      if (pending != null &&
          approved != null &&
          rejected != null &&
          total != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTimestamp;
        final cacheIsValid = cacheAge < 5 * 60 * 1000; // 5 minutes
        if (mounted) {
          setState(() {
            _pendingCount = pending;
            _approvedCount = approved;
            _rejectedCount = rejected;
            _totalCount = total;
            if (avgResponse != null) _averageResponseTime = avgResponse;
            if (approvalRate != null) _approvalRate = approvalRate;
          });

          // Update notifiers
          _statsNotifiers?['pending']?.value = _pendingCount;
          _statsNotifiers?['approved']?.value = _approvedCount;
          _statsNotifiers?['rejected']?.value = _rejectedCount;
          _statsNotifiers?['total']?.value = _totalCount;
          _statsNotifiers?['avgResponse']?.value = _averageResponseTime;
          _statsNotifiers?['approvalRate']?.value = _approvalRate;
        }
      } else {
        print('📦 No cached stats found, using defaults (0)');
      }
    } catch (e) {
      print('Error loading cached stats: $e');
    }
  }

  void _onSearchResultsChanged() {
    // Handle search results change if needed
    if (mounted) {
      setState(() {});
    }
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
      onError: (error) {
        print('Error in real-time listener: $error');
      },
    );
  }

  @override
  void dispose() {
    _aiSearchResults.removeListener(_onSearchResultsChanged);
    _aiSearchResults.dispose();
    _requestsSubscription?.cancel();
    _debounceTimer?.cancel();
    _headerController?.dispose();
    _pulseController?.dispose();
    _shimmerController?.dispose();
    _refreshController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode?.dispose();

    // Cancel all action timers
    for (var timer in _actionTimers.values) {
      timer.cancel();
    }
    _actionTimers.clear();

    // Dispose all notifiers
    for (var notifier in _statsNotifiers!.values) {
      notifier.dispose();
    }
    _statsNotifiers?.clear();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============== ENHANCED DATA LOADING ==============
  Future<void> _loadMoreRequests({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMoreData && !reset)) return;

    if (mounted) {
      setState(() => _isLoadingMore = true);
    }

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
        _cachedRequests = snapshot.docs; // Update cache
      } else {
        _allRequests.addAll(snapshot.docs);
        _cachedRequests.addAll(snapshot.docs); // Update cache
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMoreData = snapshot.docs.length == _pageSize;
      } else {
        _hasMoreData = false;
      }

      // Update UI immediately
      if (mounted) {
        setState(() {});
      }
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
      // Run queries in parallel for better performance
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('owner_requests')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('owner_requests')
            .where('status', isEqualTo: 'approved')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('owner_requests')
            .where('status', isEqualTo: 'rejected')
            .count()
            .get(),
        FirebaseFirestore.instance.collection('owner_requests').count().get(),
      ]);

      if (mounted) {
        setState(() {
          _pendingCount = results[0].count!;
          _approvedCount = results[1].count!;
          _rejectedCount = results[2].count!;
          _totalCount = results[3].count!;
        });

        // Update notifiers
        _statsNotifiers?['pending']?.value = _pendingCount;
        _statsNotifiers?['approved']?.value = _approvedCount;
        _statsNotifiers?['rejected']?.value = _rejectedCount;
        _statsNotifiers?['total']?.value = _totalCount;
      }
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

      if (mounted) {
        _statsHistory = dailyStats.entries.map((entry) {
          return {'date': entry.key, ...entry.value};
        }).toList();
      }
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

      if (mounted) {
        setState(() {
          if (processedCount > 0) {
            _averageResponseTime = (totalResponseTime / processedCount).round();
          }
          if (_totalCount > 0) {
            _approvalRate = ((_approvedCount / _totalCount) * 100).round();
          }
        });

        _statsNotifiers?['avgResponse']?.value = _averageResponseTime;
        _statsNotifiers?['approvalRate']?.value = _approvalRate;
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
        if (mounted) {
          FirebaseSnackbar.error(context, 'Operation timed out');
        }
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
      if (mounted) {
        setState(() => _loadingRequests.add(requestId));
      }
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

      if (mounted) {
        setState(() {
          _allRequests.removeWhere((doc) => doc.id == requestId);
        });
      }
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
      if (mounted) {
        FirebaseSnackbar.warning(context, "No requests selected");
      }
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

    if (mounted) {
      setState(() {
        _loadingRequests.addAll(_selectedRequests);
      });
    }

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

    if (mounted) {
      setState(() {
        _loadingRequests.clear();
        _selectedRequests.clear();
      });
    }

    if (successCount > 0 && mounted) {
      FirebaseSnackbar.success(
        context,
        "Successfully approved $successCount request(s)",
      );
    }

    if (failCount > 0 && mounted) {
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
      if (mounted) {
        setState(() => _loadingRequests.add(requestId));
      }
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

      if (mounted) {
        setState(() {
          _allRequests.removeWhere((doc) => doc.id == requestId);
        });
      }
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
      if (mounted) {
        FirebaseSnackbar.warning(context, "No requests selected");
      }
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

    if (mounted) {
      setState(() {
        _loadingRequests.addAll(_selectedRequests);
      });
    }

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

    if (mounted) {
      setState(() {
        _loadingRequests.clear();
        _selectedRequests.clear();
      });
    }

    if (successCount > 0 && mounted) {
      FirebaseSnackbar.success(
        context,
        "Successfully rejected $successCount request(s)",
      );
    }

    if (failCount > 0 && mounted) {
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
      if (mounted) {
        FirebaseSnackbar.info(context, "Preparing export...");
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('owner_requests')
          .get();

      final csv = _generateCSV(snapshot.docs);

      if (mounted) {
        FirebaseSnackbar.success(
          context,
          "Exported ${snapshot.docs.length} requests",
        );
      }

      print(csv);
    } catch (e) {
      if (mounted) {
        FirebaseSnackbar.error(context, "Export failed: $e");
      }
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

  // ============== ENHANCED RESPONSIVE UI ==============
  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _textScaleFactor = MediaQuery.of(context).textScaleFactor;
    _paddingScaleFactor = math.min(_screenWidth / 375, 1.3);

    // Responsive breakpoints
    final bool isSmallestPhone = _screenWidth < 360;
    final bool isSmallPhone = _screenWidth >= 360 && _screenWidth < 400;
    final bool isMediumPhone = _screenWidth >= 400 && _screenWidth < 480;
    final bool isLargePhone = _screenWidth >= 480 && _screenWidth < 600;
    final bool isTablet = _screenWidth >= 600 && _screenWidth < 900;
    final bool isDesktop = _screenWidth >= 900;

    // Dynamic padding based on screen size
    double horizontalPadding = isSmallestPhone
        ? 8
        : isSmallPhone
        ? 12
        : isMediumPhone
        ? 14
        : isLargePhone
        ? 16
        : isTablet
        ? 24
        : 32;

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
                vertical: _getResponsiveValue(
                  base: 16,
                  smallPhone: 12,
                  smallestPhone: 10,
                ),
              ),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(
                      isSmallestPhone: isSmallestPhone,
                      isSmallPhone: isSmallPhone,
                      isMediumPhone: isMediumPhone,
                      isLargePhone: isLargePhone,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _getResponsiveValue(
                        base: 16,
                        smallPhone: 12,
                        smallestPhone: 10,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildStatsSection(
                      isSmallestPhone: isSmallestPhone,
                      isSmallPhone: isSmallPhone,
                      isMediumPhone: isMediumPhone,
                      isLargePhone: isLargePhone,
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _getResponsiveValue(
                        base: 16,
                        smallPhone: 12,
                        smallestPhone: 10,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildMetricsRow(
                      isSmallestPhone: isSmallestPhone,
                      isSmallPhone: isSmallPhone,
                      isMediumPhone: isMediumPhone,
                      isLargePhone: isLargePhone,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _getResponsiveValue(
                        base: 16,
                        smallPhone: 12,
                        smallestPhone: 10,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildSearchAndFilterBar(
                      isSmallestPhone: isSmallestPhone,
                      isSmallPhone: isSmallPhone,
                      isMediumPhone: isMediumPhone,
                      isLargePhone: isLargePhone,
                      isTablet: isTablet,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _getResponsiveValue(
                        base: 12,
                        smallPhone: 10,
                        smallestPhone: 8,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildViewOptionsBar(
                      isSmallestPhone: isSmallestPhone,
                      isSmallPhone: isSmallPhone,
                      isMediumPhone: isMediumPhone,
                      isLargePhone: isLargePhone,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _getResponsiveValue(
                        base: 12,
                        smallPhone: 10,
                        smallestPhone: 8,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildActionBar(
                      isSmallestPhone: isSmallestPhone,
                      isSmallPhone: isSmallPhone,
                      isMediumPhone: isMediumPhone,
                      isLargePhone: isLargePhone,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: _getResponsiveValue(
                        base: 12,
                        smallPhone: 10,
                        smallestPhone: 8,
                      ),
                    ),
                  ),
                  _isGridView
                      ? _buildResponsiveGridSliver(
                          isSmallestPhone: isSmallestPhone,
                          isSmallPhone: isSmallPhone,
                          isMediumPhone: isMediumPhone,
                          isLargePhone: isLargePhone,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                        )
                      : _buildResponsiveListSliver(
                          isSmallestPhone: isSmallestPhone,
                          isSmallPhone: isSmallPhone,
                          isMediumPhone: isMediumPhone,
                          isLargePhone: isLargePhone,
                          isTablet: isTablet,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method for responsive values
  double _getResponsiveValue({
    required double base,
    double? largePhone,
    double? mediumPhone,
    double? smallPhone,
    double? smallestPhone,
    double? tablet,
    double? desktop,
  }) {
    if (_screenWidth < 360 && smallestPhone != null) return smallestPhone;
    if (_screenWidth < 400 && smallPhone != null) return smallPhone;
    if (_screenWidth < 480 && mediumPhone != null) return mediumPhone;
    if (_screenWidth < 600 && largePhone != null) return largePhone;
    if (_screenWidth < 900 && tablet != null) return tablet;
    if (_screenWidth >= 900 && desktop != null) return desktop;
    return base;
  }

  // Responsive font size helper
  double _getResponsiveFontSize({
    required double base,
    double? largePhone,
    double? mediumPhone,
    double? smallPhone,
    double? smallestPhone,
    double? tablet,
    double? desktop,
  }) {
    double size = _getResponsiveValue(
      base: base,
      largePhone: largePhone,
      mediumPhone: mediumPhone,
      smallPhone: smallPhone,
      smallestPhone: smallestPhone,
      tablet: tablet,
      desktop: desktop,
    );
    return size * _textScaleFactor.clamp(0.8, 1.2);
  }

  Widget _buildHeader({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
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
                            padding: EdgeInsets.all(
                              _getResponsiveValue(
                                base: 14,
                                largePhone: 13,
                                mediumPhone: 12,
                                smallPhone: 11,
                                smallestPhone: 10,
                              ),
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.deepPurple, Colors.purple],
                              ),
                              borderRadius: BorderRadius.circular(
                                _getResponsiveValue(
                                  base: 18,
                                  smallPhone: 16,
                                  smallestPhone: 14,
                                ),
                              ),
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
                              size: _getResponsiveValue(
                                base: 28,
                                largePhone: 26,
                                mediumPhone: 24,
                                smallPhone: 22,
                                smallestPhone: 20,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      width: _getResponsiveValue(
                        base: 10,
                        smallPhone: 8,
                        smallestPhone: 6,
                      ),
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(
                                base: 12,
                                smallPhone: 10,
                                smallestPhone: 9,
                              ),
                              color: Colors.deepPurple.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(
                            height: _getResponsiveValue(
                              base: 2,
                              smallestPhone: 1,
                            ),
                          ),
                          Text(
                            "Owner Applications",
                            style: TextStyle(
                              fontSize: _getResponsiveFontSize(
                                base: 32,
                                largePhone: 28,
                                mediumPhone: 26,
                                smallPhone: 24,
                                smallestPhone: 22,
                                tablet: 30,
                                desktop: 34,
                              ),
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
                              fontSize: _getResponsiveFontSize(
                                base: 14,
                                smallPhone: 12,
                                smallestPhone: 11,
                              ),
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
              _buildHeaderActions(
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    double iconSize = _getResponsiveValue(
      base: 24,
      largePhone: 22,
      mediumPhone: 20,
      smallPhone: 18,
      smallestPhone: 16,
    );

    double padding = _getResponsiveValue(
      base: 10,
      largePhone: 9,
      mediumPhone: 8,
      smallPhone: 7,
      smallestPhone: 6,
    );

    return Row(
      children: [
        if (_selectedRequests.isNotEmpty)
          _buildHeaderAction(
            icon: Icons.close_rounded,
            tooltip: "Clear selection",
            onPressed: _clearSelection,
            color: Colors.red,
            iconSize: iconSize,
            padding: padding,
          ),
        if (_selectedRequests.isNotEmpty)
          SizedBox(
            width: _getResponsiveValue(
              base: 8,
              smallPhone: 6,
              smallestPhone: 4,
            ),
          ),
        _buildHeaderAction(
          icon: Icons.download_rounded,
          tooltip: "Export data",
          onPressed: _exportData,
          color: Colors.green,
          iconSize: iconSize,
          padding: padding,
        ),
        SizedBox(
          width: _getResponsiveValue(base: 8, smallPhone: 6, smallestPhone: 4),
        ),
        _buildHeaderAction(
          icon: _isCompactMode
              ? Icons.view_stream_rounded
              : Icons.view_cozy_rounded,
          tooltip: _isCompactMode ? "Comfortable view" : "Compact view",
          onPressed: _toggleCompactMode,
          color: Colors.teal,
          iconSize: iconSize,
          padding: padding,
        ),
        SizedBox(
          width: _getResponsiveValue(base: 8, smallPhone: 6, smallestPhone: 4),
        ),
        _buildHeaderAction(
          icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
          tooltip: _isGridView ? "List view" : "Grid view",
          onPressed: _toggleViewMode,
          color: Colors.blue,
          iconSize: iconSize,
          padding: padding,
        ),
        SizedBox(
          width: _getResponsiveValue(base: 8, smallPhone: 6, smallestPhone: 4),
        ),
        _buildHeaderAction(
          icon: Icons.refresh_rounded,
          tooltip: "Refresh",
          onPressed: () {
            if (mounted) {
              _refreshController.reset();
              _refreshController.forward();
              _loadStats();
              _loadStatsHistory();
              _calculateMetrics();
              _loadInitialRequests();
              FirebaseSnackbar.info(context, "Refreshed");
            }
          },
          color: Colors.orange,
          iconSize: iconSize,
          padding: padding,
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
    required double iconSize,
    required double padding,
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
              borderRadius: BorderRadius.circular(
                _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
              ),
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
                borderRadius: BorderRadius.circular(
                  _getResponsiveValue(
                    base: 12,
                    smallPhone: 10,
                    smallestPhone: 8,
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.all(padding),
                  child: showLoader
                      ? SizedBox(
                          width: iconSize * 0.8,
                          height: iconSize * 0.8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      : Icon(icon, color: color, size: iconSize),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsSection({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
    return Stack(
      children: [
        // Your existing stats section
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatCard(
                "Pending",
                _pendingCount,
                Colors.orange,
                Icons.pending_actions_rounded,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
              SizedBox(
                width: _getResponsiveValue(
                  base: 8,
                  smallPhone: 6,
                  smallestPhone: 4,
                ),
              ),
              _buildStatCard(
                "Approved",
                _approvedCount,
                Colors.green,
                Icons.check_circle_rounded,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
              SizedBox(
                width: _getResponsiveValue(
                  base: 8,
                  smallPhone: 6,
                  smallestPhone: 4,
                ),
              ),
              _buildStatCard(
                "Rejected",
                _rejectedCount,
                Colors.red,
                Icons.cancel_rounded,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
              SizedBox(
                width: _getResponsiveValue(
                  base: 8,
                  smallPhone: 6,
                  smallestPhone: 4,
                ),
              ),
              _buildStatCard(
                "Total",
                _totalCount,
                Colors.deepPurple,
                Icons.numbers_rounded,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
              // Always show metric cards with current values
              SizedBox(
                width: _getResponsiveValue(
                  base: 8,
                  smallPhone: 6,
                  smallestPhone: 4,
                ),
              ),
              _buildMetricCard(
                "Avg. Response",
                "$_averageResponseTime hrs",
                Icons.timer_rounded,
                Colors.blue,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
              SizedBox(
                width: _getResponsiveValue(
                  base: 8,
                  smallPhone: 6,
                  smallestPhone: 4,
                ),
              ),
              _buildMetricCard(
                "Approval Rate",
                "$_approvalRate%",
                Icons.analytics_rounded,
                Colors.teal,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
            ],
          ),
        ),
        if (_isLoadingMore)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    double iconSize = _getResponsiveValue(
      base: 20,
      largePhone: 18,
      mediumPhone: 16,
      smallPhone: 14,
      smallestPhone: 12,
    );

    double fontSize = _getResponsiveFontSize(
      base: 16,
      largePhone: 15,
      mediumPhone: 14,
      smallPhone: 13,
      smallestPhone: 12,
    );

    double labelSize = _getResponsiveFontSize(
      base: 9,
      largePhone: 8.5,
      mediumPhone: 8,
      smallPhone: 7.5,
      smallestPhone: 7,
    );

    double padding = _getResponsiveValue(
      base: 12,
      largePhone: 11,
      mediumPhone: 10,
      smallPhone: 9,
      smallestPhone: 8,
    );

    double iconPadding = _getResponsiveValue(
      base: 8,
      largePhone: 7,
      mediumPhone: 6,
      smallPhone: 5,
      smallestPhone: 4,
    );

    return Container(
      constraints: BoxConstraints(
        minWidth: _getResponsiveValue(
          base: 120,
          largePhone: 110,
          mediumPhone: 100,
          smallPhone: 90,
          smallestPhone: 80,
        ),
        maxWidth: _getResponsiveValue(
          base: 150,
          largePhone: 140,
          mediumPhone: 130,
          smallPhone: 120,
          smallestPhone: 100,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 16, smallPhone: 14, smallestPhone: 12),
          ),
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
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  _getResponsiveValue(
                    base: 10,
                    smallPhone: 8,
                    smallestPhone: 6,
                  ),
                ),
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            SizedBox(
              width: _getResponsiveValue(
                base: 8,
                smallPhone: 6,
                smallestPhone: 4,
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: labelSize,
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

  Widget _buildMetricsRow({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    double iconSize = _getResponsiveValue(
      base: 14,
      largePhone: 13,
      mediumPhone: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double valueSize = _getResponsiveFontSize(
      base: 12,
      largePhone: 11,
      mediumPhone: 10.5,
      smallPhone: 10,
      smallestPhone: 9,
    );

    double labelSize = _getResponsiveFontSize(
      base: 8,
      largePhone: 7.5,
      mediumPhone: 7,
      smallPhone: 6.5,
      smallestPhone: 6,
    );

    double spacing = _getResponsiveValue(
      base: 12,
      largePhone: 10,
      mediumPhone: 8,
      smallPhone: 6,
      smallestPhone: 4,
    );

    // Calculate conversion rate safely
    String conversionRate = "0%";
    if (_totalCount > 0) {
      conversionRate =
          "${((_approvedCount / _totalCount) * 100).toStringAsFixed(1)}%";
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMiniMetric(
            icon: Icons.timer_rounded,
            label: "Response",
            value: "$_averageResponseTime hrs",
            color: Colors.blue,
            iconSize: iconSize,
            valueSize: valueSize,
            labelSize: labelSize,
          ),
          SizedBox(width: spacing),
          _buildMiniMetric(
            icon: Icons.analytics_rounded,
            label: "Approval",
            value: "$_approvalRate%",
            color: Colors.teal,
            iconSize: iconSize,
            valueSize: valueSize,
            labelSize: labelSize,
          ),
          SizedBox(width: spacing),
          _buildMiniMetric(
            icon: Icons.trending_up_rounded,
            label: "Conversion",
            value: conversionRate,
            color: Colors.green,
            iconSize: iconSize,
            valueSize: valueSize,
            labelSize: labelSize,
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
    required double iconSize,
    required double valueSize,
    required double labelSize,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getResponsiveValue(
          base: 8,
          smallPhone: 6,
          smallestPhone: 4,
        ),
        vertical: _getResponsiveValue(base: 6, smallPhone: 5, smallestPhone: 4),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
        ),
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
          Icon(icon, color: color, size: iconSize),
          SizedBox(width: _getResponsiveValue(base: 4, smallestPhone: 2)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    int count,
    Color color,
    IconData icon, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    double iconSize = _getResponsiveValue(
      base: 20,
      largePhone: 18,
      mediumPhone: 16,
      smallPhone: 14,
      smallestPhone: 12,
    );

    double fontSize = _getResponsiveFontSize(
      base: 18,
      largePhone: 16,
      mediumPhone: 15,
      smallPhone: 14,
      smallestPhone: 13,
    );

    double labelSize = _getResponsiveFontSize(
      base: 10,
      largePhone: 9,
      mediumPhone: 8.5,
      smallPhone: 8,
      smallestPhone: 7,
    );

    double padding = _getResponsiveValue(
      base: 12,
      largePhone: 11,
      mediumPhone: 10,
      smallPhone: 9,
      smallestPhone: 8,
    );

    double iconPadding = _getResponsiveValue(
      base: 8,
      largePhone: 7,
      mediumPhone: 6,
      smallPhone: 5,
      smallestPhone: 4,
    );

    return Container(
      constraints: BoxConstraints(
        minWidth: _getResponsiveValue(
          base: 120,
          largePhone: 110,
          mediumPhone: 100,
          smallPhone: 90,
          smallestPhone: 80,
        ),
        maxWidth: _getResponsiveValue(
          base: 150,
          largePhone: 140,
          mediumPhone: 130,
          smallPhone: 120,
          smallestPhone: 100,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 16, smallPhone: 14, smallestPhone: 12),
          ),
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
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  _getResponsiveValue(
                    base: 10,
                    smallPhone: 8,
                    smallestPhone: 6,
                  ),
                ),
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            SizedBox(
              width: _getResponsiveValue(
                base: 8,
                smallPhone: 6,
                smallestPhone: 4,
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: labelSize,
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

  Widget _buildSearchAndFilterBar({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
  }) {
    if (_searchFocusNode == null) {
      return const SizedBox.shrink();
    }

    double padding = _getResponsiveValue(
      base: 16,
      largePhone: 14,
      mediumPhone: 12,
      smallPhone: 10,
      smallestPhone: 8,
    );

    double fontSize = _getResponsiveFontSize(
      base: 14,
      largePhone: 13,
      mediumPhone: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 20, smallPhone: 16, smallestPhone: 14),
        ),
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
          // AI Search Bar
          AISearchBar(
            onSearch: (query) {
              // Handle search if needed
            },
            onFilterChange: (filters) {
              // Handle filter changes if needed
              print('Filters changed: $filters');
            },
            data: _allRequests,
            searchResultsNotifier: _aiSearchResults,
            hintText: 'AI Search: Find by shop, owner, email, phone...',
            autoFocus: false,
            showSuggestions: true,
            showFilters: false, // Disable built-in filters to use custom ones
            showHistory: true,
            enableVoice: false,
            enableLearning: true,
            maxSuggestions: 8,
            maxHistoryItems: 20,
            debounceDuration: const Duration(milliseconds: 300),
            accentColor: Colors.deepPurple,
            searchFields: const [
              'shopName',
              'ownerName',
              'email',
              'phone',
              'category',
              'address',
              'description',
              'status',
              'gstNumber',
              'deliveryType',
            ],
            fieldWeights: const {
              'shopName': 2.5,
              'ownerName': 2.0,
              'email': 1.8,
              'phone': 1.8,
              'category': 1.5,
              'address': 1.2,
              'description': 1.0,
              'status': 1.0,
              'gstNumber': 1.2,
              'deliveryType': 1.0,
            },
            fuzzyThreshold: 0.4,
            onVoiceSearch: (query) {
              FirebaseSnackbar.info(context, 'Voice search: $query');
            },
          ),

          SizedBox(
            height: _getResponsiveValue(
              base: 8,
              smallPhone: 6,
              smallestPhone: 4,
            ),
          ),

          // Your existing filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  "All",
                  "all",
                  _selectedFilter,
                  (val) {
                    setState(() => _selectedFilter = val);
                    _loadInitialRequests();
                  },
                  fontSize: fontSize * 0.9,
                  padding: _getResponsiveValue(
                    base: 10,
                    smallPhone: 8,
                    smallestPhone: 6,
                  ),
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 8,
                    smallPhone: 6,
                    smallestPhone: 4,
                  ),
                ),
                _buildFilterChip(
                  "Pending",
                  "pending",
                  _selectedFilter,
                  (val) {
                    setState(() => _selectedFilter = val);
                    _loadInitialRequests();
                  },
                  color: Colors.orange,
                  fontSize: fontSize * 0.9,
                  padding: _getResponsiveValue(
                    base: 10,
                    smallPhone: 8,
                    smallestPhone: 6,
                  ),
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 8,
                    smallPhone: 6,
                    smallestPhone: 4,
                  ),
                ),
                _buildFilterChip(
                  "Approved",
                  "approved",
                  _selectedFilter,
                  (val) {
                    setState(() => _selectedFilter = val);
                    _loadInitialRequests();
                  },
                  color: Colors.green,
                  fontSize: fontSize * 0.9,
                  padding: _getResponsiveValue(
                    base: 10,
                    smallPhone: 8,
                    smallestPhone: 6,
                  ),
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 8,
                    smallPhone: 6,
                    smallestPhone: 4,
                  ),
                ),
                _buildFilterChip(
                  "Rejected",
                  "rejected",
                  _selectedFilter,
                  (val) {
                    setState(() => _selectedFilter = val);
                    _loadInitialRequests();
                  },
                  color: Colors.red,
                  fontSize: fontSize * 0.9,
                  padding: _getResponsiveValue(
                    base: 10,
                    smallPhone: 8,
                    smallestPhone: 6,
                  ),
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 8,
                    smallPhone: 6,
                    smallestPhone: 4,
                  ),
                ),
                Container(
                  width: 1,
                  height: _getResponsiveValue(
                    base: 24,
                    smallPhone: 20,
                    smallestPhone: 18,
                  ),
                  color: Colors.grey.shade300,
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 8,
                    smallPhone: 6,
                    smallestPhone: 4,
                  ),
                ),
                _buildSortChip(
                  "Date",
                  "createdAt",
                  _selectedSortBy,
                  (val) {
                    setState(() => _selectedSortBy = val);
                    _loadInitialRequests();
                  },
                  fontSize: fontSize * 0.9,
                  padding: _getResponsiveValue(
                    base: 10,
                    smallPhone: 8,
                    smallestPhone: 6,
                  ),
                ),
                SizedBox(width: _getResponsiveValue(base: 4, smallestPhone: 2)),
                IconButton(
                  icon: Icon(
                    _sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: fontSize * 1.2,
                    color: Colors.deepPurple,
                  ),
                  onPressed: () {
                    setState(() => _sortAscending = !_sortAscending);
                    _loadInitialRequests();
                  },
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: fontSize * 2,
                    minHeight: fontSize * 2,
                  ),
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
    required double fontSize,
    required double padding,
  }) {
    final isSelected = selectedValue == value;

    return Padding(
      padding: EdgeInsets.only(
        right: _getResponsiveValue(base: 8, smallPhone: 6, smallestPhone: 4),
      ),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: padding * 1.6,
            vertical: padding,
          ),
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
              fontSize: fontSize,
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
    required double fontSize,
    required double padding,
  }) {
    final isSelected = selectedValue == value;

    return Padding(
      padding: EdgeInsets.only(
        right: _getResponsiveValue(base: 8, smallPhone: 6, smallestPhone: 4),
      ),
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: padding * 1.6,
            vertical: padding,
          ),
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
                  size: fontSize * 1.2,
                  color: isSelected ? color : Colors.grey.shade500,
                ),
                SizedBox(width: padding * 0.6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: padding * 0.6),
                child: Icon(
                  _sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: fontSize * 1.1,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveListSliver({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
  }) {
    return ValueListenableBuilder<List<DocumentSnapshot>>(
      valueListenable: _aiSearchResults,
      builder: (context, searchResults, child) {
        // Start with search results if available, otherwise all requests
        List<DocumentSnapshot> docs = searchResults.isNotEmpty
            ? List.from(searchResults)
            : List.from(_allRequests);

        // Apply status filter to the docs
        if (_selectedFilter != 'all') {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == _selectedFilter;
          }).toList();
        }

        // Apply sorting
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          final valueA = dataA[_selectedSortBy];
          final valueB = dataB[_selectedSortBy];

          if (valueA is Timestamp && valueB is Timestamp) {
            return _sortAscending
                ? valueA.compareTo(valueB)
                : valueB.compareTo(valueA);
          }

          final comparison = valueA.toString().compareTo(valueB.toString());
          return _sortAscending ? comparison : -comparison;
        });

        // Always show data if available, even during first load
        if (docs.isEmpty) {
          // Only show empty state or shimmer if there's truly no data
          if (_isFirstLoad) {
            // Show loading indicator but don't block data display
            return SliverToBoxAdapter(
              child: _buildShimmerLoading(
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
            );
          } else {
            return SliverToBoxAdapter(
              child: _buildEmptyState(
                search: _searchQuery.isNotEmpty || searchResults.isNotEmpty,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
              ),
            );
          }
        }

        // Show actual data
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == docs.length &&
                  _hasMoreData &&
                  searchResults.isEmpty) {
                return _buildLoadingMoreIndicator(
                  isSmallestPhone: isSmallestPhone,
                  isSmallPhone: isSmallPhone,
                  isMediumPhone: isMediumPhone,
                );
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
                        padding: EdgeInsets.only(
                          bottom: _getResponsiveValue(
                            base: 12,
                            smallPhone: 10,
                            smallestPhone: 8,
                          ),
                        ),
                        child: _isCompactMode
                            ? _buildCompactRequestCard(
                                docs[index],
                                isSmallestPhone: isSmallestPhone,
                                isSmallPhone: isSmallPhone,
                                isMediumPhone: isMediumPhone,
                                isLargePhone: isLargePhone,
                                isTablet: isTablet,
                              )
                            : _buildRequestCard(
                                docs[index],
                                isSmallestPhone: isSmallestPhone,
                                isSmallPhone: isSmallPhone,
                                isMediumPhone: isMediumPhone,
                                isLargePhone: isLargePhone,
                                isTablet: isTablet,
                              ),
                      ),
                    ),
                  );
                },
              );
            },
            childCount:
                docs.length + (_hasMoreData && searchResults.isEmpty ? 1 : 0),
          ),
        );
      },
    );
  }

  Widget _buildShimmerLoading({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    return Column(
      children: List.generate(5, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: _getResponsiveValue(
              base: 12,
              smallPhone: 10,
              smallestPhone: 8,
            ),
          ),
          child: Container(
            height: _getResponsiveValue(
              base: 100,
              smallPhone: 90,
              smallestPhone: 80,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                _getResponsiveValue(
                  base: 20,
                  smallPhone: 18,
                  smallestPhone: 16,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(
                _getResponsiveValue(
                  base: 16,
                  smallPhone: 14,
                  smallestPhone: 12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: _getResponsiveValue(
                      base: 40,
                      smallPhone: 36,
                      smallestPhone: 32,
                    ),
                    height: _getResponsiveValue(
                      base: 40,
                      smallPhone: 36,
                      smallestPhone: 32,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(
                        _getResponsiveValue(
                          base: 10,
                          smallPhone: 8,
                          smallestPhone: 6,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _getResponsiveValue(
                      base: 12,
                      smallPhone: 10,
                      smallestPhone: 8,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          height: _getResponsiveValue(
                            base: 16,
                            smallPhone: 14,
                            smallestPhone: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(
                          height: _getResponsiveValue(
                            base: 8,
                            smallPhone: 6,
                            smallestPhone: 4,
                          ),
                        ),
                        Container(
                          width: _getResponsiveValue(
                            base: 200,
                            smallPhone: 180,
                            smallestPhone: 160,
                          ),
                          height: _getResponsiveValue(
                            base: 12,
                            smallPhone: 10,
                            smallestPhone: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResponsiveGridSliver({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
    int crossAxisCount = 1;
    if (isDesktop)
      crossAxisCount = 4;
    else if (isTablet)
      crossAxisCount = 3;
    else if (isLargePhone)
      crossAxisCount = 2;
    else if (isMediumPhone)
      crossAxisCount = 1;
    else if (isSmallPhone)
      crossAxisCount = 1;
    else if (isSmallestPhone)
      crossAxisCount = 1;

    double childAspectRatio = _isCompactMode
        ? _getResponsiveValue(base: 1.0, smallPhone: 0.9, smallestPhone: 0.85)
        : _getResponsiveValue(base: 1.2, smallPhone: 1.1, smallestPhone: 1.0);

    double spacing = _getResponsiveValue(
      base: 16,
      largePhone: 14,
      mediumPhone: 12,
      smallPhone: 10,
      smallestPhone: 8,
    );

    return ValueListenableBuilder<List<DocumentSnapshot>>(
      valueListenable: _aiSearchResults,
      builder: (context, searchResults, child) {
        // Start with search results if available, otherwise all requests
        List<DocumentSnapshot> docs = searchResults.isNotEmpty
            ? List.from(searchResults)
            : List.from(_allRequests);

        // Apply status filter to the docs (whether from search or all)
        if (_selectedFilter != 'all') {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['status'] == _selectedFilter;
          }).toList();
        }

        // Apply sorting
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          final valueA = dataA[_selectedSortBy];
          final valueB = dataB[_selectedSortBy];

          if (valueA is Timestamp && valueB is Timestamp) {
            return _sortAscending
                ? valueA.compareTo(valueB)
                : valueB.compareTo(valueA);
          }

          final comparison = valueA.toString().compareTo(valueB.toString());
          return _sortAscending ? comparison : -comparison;
        });

        // SHOW DATA IMMEDIATELY - don't check for empty on first load
        if (docs.isEmpty && !_isFirstLoad) {
          return SliverToBoxAdapter(
            child: _buildEmptyState(
              search: _searchQuery.isNotEmpty || searchResults.isNotEmpty,
              isSmallestPhone: isSmallestPhone,
              isSmallPhone: isSmallPhone,
              isMediumPhone: isMediumPhone,
              isLargePhone: isLargePhone,
            ),
          );
        }

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
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
                        ? _buildCompactGridRequestCard(
                            docs[index],
                            isSmallestPhone: isSmallestPhone,
                            isSmallPhone: isSmallPhone,
                            isMediumPhone: isMediumPhone,
                            isLargePhone: isLargePhone,
                          )
                        : _buildGridRequestCard(
                            docs[index],
                            isSmallestPhone: isSmallestPhone,
                            isSmallPhone: isSmallPhone,
                            isMediumPhone: isMediumPhone,
                            isLargePhone: isLargePhone,
                          ),
                  ),
                );
              },
            );
          }, childCount: docs.length),
        );
      },
    );
  }

  // Add a simple cache
  List<DocumentSnapshot> _cachedRequests = [];
  bool _isFirstLoad = true;

  Future<void> _loadInitialRequests() async {
    // Clear search results when loading new data
    _aiSearchResults.value = [];

    _lastDocument = null;
    _hasMoreData = true;

    try {
      await _loadMoreRequests(reset: true);
      _isFirstLoad = false; // Mark as loaded after first batch
    } catch (e) {
      print('Error loading requests: $e');
      // Show cached data on error
      if (_cachedRequests.isNotEmpty && mounted) {
        setState(() {
          _allRequests = List.from(_cachedRequests);
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    if (mounted) {
      setState(() {
        _searchQuery = '';
      });
    }
  }

  Widget _buildViewOptionsBar({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    double fontSize = _getResponsiveFontSize(
      base: 12,
      largePhone: 11,
      mediumPhone: 10.5,
      smallPhone: 10,
      smallestPhone: 9,
    );

    double iconSize = _getResponsiveValue(
      base: 16,
      largePhone: 15,
      mediumPhone: 14,
      smallPhone: 13,
      smallestPhone: 12,
    );

    return Row(
      children: [
        _buildViewOptionChip(
          icon: _isCompactMode
              ? Icons.view_stream_rounded
              : Icons.view_cozy_rounded,
          label: _isCompactMode ? "Compact" : "Comfortable",
          isSelected: true,
          onTap: _toggleCompactMode,
          fontSize: fontSize,
          iconSize: iconSize,
          padding: _getResponsiveValue(
            base: 6,
            smallPhone: 5,
            smallestPhone: 4,
          ),
        ),
        SizedBox(
          width: _getResponsiveValue(base: 8, smallPhone: 6, smallestPhone: 4),
        ),
        _buildViewOptionChip(
          icon: _isGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
          label: _isGridView ? "Grid" : "List",
          isSelected: true,
          onTap: _toggleViewMode,
          fontSize: fontSize,
          iconSize: iconSize,
          padding: _getResponsiveValue(
            base: 6,
            smallPhone: 5,
            smallestPhone: 4,
          ),
        ),
        const Spacer(),
        if (_selectedRequests.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: _getResponsiveValue(
                base: 10,
                smallPhone: 8,
                smallestPhone: 6,
              ),
              vertical: _getResponsiveValue(
                base: 4,
                smallPhone: 3,
                smallestPhone: 2,
              ),
            ),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                _getResponsiveValue(
                  base: 16,
                  smallPhone: 14,
                  smallestPhone: 12,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  "${_selectedRequests.length} selected",
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize * 0.9,
                  ),
                ),
                SizedBox(width: _getResponsiveValue(base: 4, smallestPhone: 2)),
                GestureDetector(
                  onTap: _clearSelection,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.deepPurple,
                    size: iconSize * 0.9,
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
    required double fontSize,
    required double iconSize,
    required double padding,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: padding * 2,
          vertical: padding,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 20, smallPhone: 18, smallestPhone: 16),
          ),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.deepPurple, size: iconSize),
            SizedBox(width: padding),
            Text(
              label,
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    if (_selectedRequests.isEmpty) return const SizedBox.shrink();

    double fontSize = _getResponsiveFontSize(
      base: 12,
      largePhone: 11,
      mediumPhone: 10.5,
      smallPhone: 10,
      smallestPhone: 9,
    );

    double iconSize = _getResponsiveValue(
      base: 16,
      largePhone: 15,
      mediumPhone: 14,
      smallPhone: 13,
      smallestPhone: 12,
    );

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _getResponsiveValue(
                base: 16,
                largePhone: 14,
                mediumPhone: 12,
                smallPhone: 10,
                smallestPhone: 8,
              ),
              vertical: _getResponsiveValue(
                base: 12,
                largePhone: 11,
                mediumPhone: 10,
                smallPhone: 9,
                smallestPhone: 8,
              ),
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(
                _getResponsiveValue(
                  base: 16,
                  smallPhone: 14,
                  smallestPhone: 12,
                ),
              ),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: _getResponsiveValue(
                          base: 12,
                          smallPhone: 10,
                          smallestPhone: 8,
                        ),
                        vertical: _getResponsiveValue(
                          base: 6,
                          smallPhone: 5,
                          smallestPhone: 4,
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(
                          _getResponsiveValue(
                            base: 30,
                            smallPhone: 25,
                            smallestPhone: 20,
                          ),
                        ),
                      ),
                      child: Text(
                        '$count selected',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: fontSize,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 16,
                    smallPhone: 12,
                    smallestPhone: 8,
                  ),
                ),
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
                          fontSize: fontSize,
                          iconSize: iconSize,
                          padding: _getResponsiveValue(
                            base: 8,
                            smallPhone: 7,
                            smallestPhone: 6,
                          ),
                        ),
                        SizedBox(
                          width: _getResponsiveValue(
                            base: 8,
                            smallPhone: 6,
                            smallestPhone: 4,
                          ),
                        ),
                        _buildActionChip(
                          label: "Reject",
                          icon: Icons.cancel_rounded,
                          color: Colors.red,
                          onPressed: _batchReject,
                          fontSize: fontSize,
                          iconSize: iconSize,
                          padding: _getResponsiveValue(
                            base: 8,
                            smallPhone: 7,
                            smallestPhone: 6,
                          ),
                        ),
                        SizedBox(
                          width: _getResponsiveValue(
                            base: 8,
                            smallPhone: 6,
                            smallestPhone: 4,
                          ),
                        ),
                        _buildActionChip(
                          label: "Clear",
                          icon: Icons.clear_rounded,
                          color: Colors.white,
                          onPressed: _clearSelection,
                          fontSize: fontSize,
                          iconSize: iconSize,
                          padding: _getResponsiveValue(
                            base: 8,
                            smallPhone: 7,
                            smallestPhone: 6,
                          ),
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
    required double fontSize,
    required double iconSize,
    required double padding,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: padding * 1.75,
            vertical: padding,
          ),
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
                size: iconSize,
              ),
              SizedBox(width: padding * 0.75),
              Text(
                label,
                style: TextStyle(
                  color: color == Colors.white ? Colors.deepPurple : color,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(
    DocumentSnapshot doc, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final userId = data["userId"] ?? "";
    final isLoading = _loadingRequests.contains(requestId);
    final isSelected = _selectedRequests.contains(requestId);
    final isExpanded = _expandedCards[requestId] ?? false;
    final status = data["status"] ?? "pending";

    double titleSize = _getResponsiveFontSize(
      base: 18,
      largePhone: 17,
      mediumPhone: 16,
      smallPhone: 15,
      smallestPhone: 14,
    );

    double normalTextSize = _getResponsiveFontSize(
      base: 13,
      largePhone: 12,
      mediumPhone: 11.5,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double smallTextSize = _getResponsiveFontSize(
      base: 11,
      largePhone: 10.5,
      mediumPhone: 10,
      smallPhone: 9.5,
      smallestPhone: 9,
    );

    double iconSize = _getResponsiveValue(
      base: 16,
      largePhone: 15,
      mediumPhone: 14,
      smallPhone: 13,
      smallestPhone: 12,
    );

    double padding = _getResponsiveValue(
      base: 18,
      largePhone: 16,
      mediumPhone: 14,
      smallPhone: 12,
      smallestPhone: 10,
    );

    double spacing = _getResponsiveValue(
      base: 12,
      largePhone: 11,
      mediumPhone: 10,
      smallPhone: 9,
      smallestPhone: 8,
    );

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
        margin: EdgeInsets.only(bottom: spacing),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 20, smallPhone: 18, smallestPhone: 16),
          ),
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
                    margin: EdgeInsets.only(right: spacing * 0.67),
                    padding: EdgeInsets.all(spacing * 0.33),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: iconSize * 0.75,
                    ),
                  ),
                Expanded(
                  child: Text(
                    data["shopName"] ?? "Unnamed Shop",
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusChip(status, small: false),
              ],
            ),
            SizedBox(height: spacing),
            _buildDetailRow(
              Icons.person_outline_rounded,
              data["ownerName"] ?? "N/A",
              iconSize: iconSize,
              textSize: normalTextSize,
            ),
            _buildDetailRow(
              Icons.phone_outlined,
              data["phone"] ?? "N/A",
              iconSize: iconSize,
              textSize: normalTextSize,
            ),
            _buildDetailRow(
              Icons.email_outlined,
              data["email"] ?? "N/A",
              iconSize: iconSize,
              textSize: normalTextSize,
            ),
            _buildDetailRow(
              Icons.category_outlined,
              data["category"] ?? "N/A",
              iconSize: iconSize,
              textSize: normalTextSize,
            ),
            if (!isExpanded) ...[
              _buildDetailRow(
                Icons.delivery_dining_outlined,
                data["deliveryType"] ?? "N/A",
                iconSize: iconSize,
                textSize: normalTextSize,
              ),
            ],
            if (isExpanded) ...[
              SizedBox(height: spacing * 0.67),
              Container(
                padding: EdgeInsets.all(spacing),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(
                    _getResponsiveValue(
                      base: 12,
                      smallPhone: 10,
                      smallestPhone: 8,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Address:",
                      style: TextStyle(
                        fontSize: smallTextSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: spacing * 0.33),
                    Text(
                      data["address"] ?? "No address provided",
                      style: TextStyle(
                        fontSize: normalTextSize * 0.95,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (data["description"]?.toString().isNotEmpty ??
                        false) ...[
                      SizedBox(height: spacing * 0.67),
                      Text(
                        "Description:",
                        style: TextStyle(
                          fontSize: smallTextSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: spacing * 0.33),
                      Text(
                        data["description"],
                        style: TextStyle(
                          fontSize: normalTextSize * 0.95,
                          color: Colors.grey.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (data["gstNumber"] != null) ...[
                      SizedBox(height: spacing * 0.67),
                      Text(
                        "GST: ${data["gstNumber"]}",
                        style: TextStyle(
                          fontSize: smallTextSize,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: iconSize * 0.875,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(width: spacing * 0.33),
                      Text(
                        _formatTimestamp(data["createdAt"] as Timestamp?),
                        style: TextStyle(
                          fontSize: smallTextSize,
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
                          fontSize: smallTextSize,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: iconSize,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (status == 'pending') ...[
              SizedBox(height: spacing),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: "Approve",
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      isLoading: isLoading,
                      onPressed: () => approveOwner(context, requestId, userId),
                      fontSize: normalTextSize,
                      iconSize: iconSize,
                      padding: _getResponsiveValue(
                        base: 12,
                        smallPhone: 10,
                        smallestPhone: 8,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing * 0.83),
                  Expanded(
                    child: _buildActionButton(
                      label: "Reject",
                      icon: Icons.close_rounded,
                      color: Colors.red,
                      isLoading: isLoading,
                      onPressed: () => rejectOwner(context, requestId),
                      isOutlined: true,
                      fontSize: normalTextSize,
                      iconSize: iconSize,
                      padding: _getResponsiveValue(
                        base: 12,
                        smallPhone: 10,
                        smallestPhone: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved' && data["approvedAt"] != null) ...[
              SizedBox(height: spacing * 0.67),
              Container(
                padding: EdgeInsets.all(spacing * 0.83),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    _getResponsiveValue(
                      base: 12,
                      smallPhone: 10,
                      smallestPhone: 8,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: iconSize,
                    ),
                    SizedBox(width: spacing * 0.67),
                    Expanded(
                      child: Text(
                        "Approved by ${data["approvedByEmail"]?.toString().split('@')[0] ?? 'Admin'}",
                        style: TextStyle(
                          fontSize: smallTextSize,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _formatShortDate(data["approvedAt"] as Timestamp?),
                      style: TextStyle(
                        fontSize: smallTextSize * 0.9,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (status == 'rejected' && data["rejectedAt"] != null) ...[
              SizedBox(height: spacing * 0.67),
              Container(
                padding: EdgeInsets.all(spacing * 0.83),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    _getResponsiveValue(
                      base: 12,
                      smallPhone: 10,
                      smallestPhone: 8,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cancel_rounded,
                          color: Colors.red,
                          size: iconSize,
                        ),
                        SizedBox(width: spacing * 0.67),
                        Text(
                          "Rejected by ${data["rejectedByEmail"]?.toString().split('@')[0] ?? 'Admin'}",
                          style: TextStyle(
                            fontSize: smallTextSize,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatShortDate(data["rejectedAt"] as Timestamp?),
                          style: TextStyle(
                            fontSize: smallTextSize * 0.9,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (data["rejectionReason"] != null) ...[
                      SizedBox(height: spacing * 0.33),
                      Text(
                        "Reason: ${data["rejectionReason"]}",
                        style: TextStyle(
                          fontSize: smallTextSize * 0.9,
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

  Widget _buildCompactRequestCard(
    DocumentSnapshot doc, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final userId = data["userId"] ?? "";
    final isLoading = _loadingRequests.contains(requestId);
    final isSelected = _selectedRequests.contains(requestId);
    final status = data["status"] ?? "pending";

    double titleSize = _getResponsiveFontSize(
      base: 14,
      largePhone: 13,
      mediumPhone: 12.5,
      smallPhone: 12,
      smallestPhone: 11,
    );

    double subtitleSize = _getResponsiveFontSize(
      base: 11,
      largePhone: 10.5,
      mediumPhone: 10,
      smallPhone: 9.5,
      smallestPhone: 9,
    );

    double iconSize = _getResponsiveValue(
      base: 14,
      largePhone: 13,
      mediumPhone: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double avatarSize = _getResponsiveValue(
      base: 40,
      largePhone: 36,
      mediumPhone: 32,
      smallPhone: 28,
      smallestPhone: 24,
    );

    double padding = _getResponsiveValue(
      base: 12,
      largePhone: 11,
      mediumPhone: 10,
      smallPhone: 9,
      smallestPhone: 8,
    );

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
        margin: EdgeInsets.only(
          bottom: _getResponsiveValue(base: 8, smallPhone: 6, smallestPhone: 4),
        ),
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 16, smallPhone: 14, smallestPhone: 12),
          ),
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
                margin: EdgeInsets.only(right: padding * 0.67),
                padding: EdgeInsets.all(padding * 0.25),
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: iconSize * 0.7,
                ),
              ),
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _getStatusGradient(status)),
                borderRadius: BorderRadius.circular(
                  _getResponsiveValue(
                    base: 10,
                    smallPhone: 8,
                    smallestPhone: 6,
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  (data["shopName"] ?? "S")[0].toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: avatarSize * 0.4,
                  ),
                ),
              ),
            ),
            SizedBox(width: padding),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data["shopName"] ?? "Unnamed Shop",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: titleSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: padding * 0.5),
                      _buildStatusChip(status, small: true),
                    ],
                  ),
                  SizedBox(height: padding * 0.33),
                  Text(
                    "${data["ownerName"] ?? "N/A"} • ${data["phone"] ?? "N/A"}",
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: Colors.grey.shade600,
                    ),
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
                    size: iconSize,
                  ),
                  SizedBox(width: padding * 0.33),
                  _buildMiniActionButton(
                    icon: Icons.close,
                    color: Colors.red,
                    isLoading: isLoading,
                    onPressed: () => rejectOwner(context, requestId),
                    size: iconSize,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridRequestCard(
    DocumentSnapshot doc, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final userId = data["userId"] ?? "";
    final isLoading = _loadingRequests.contains(requestId);
    final isSelected = _selectedRequests.contains(requestId);
    final status = data["status"] ?? "pending";

    double titleSize = _getResponsiveFontSize(
      base: 16,
      largePhone: 15,
      mediumPhone: 14,
      smallPhone: 13,
      smallestPhone: 12,
    );

    double textSize = _getResponsiveFontSize(
      base: 12,
      largePhone: 11,
      mediumPhone: 10.5,
      smallPhone: 10,
      smallestPhone: 9,
    );

    double smallTextSize = _getResponsiveFontSize(
      base: 10,
      largePhone: 9.5,
      mediumPhone: 9,
      smallPhone: 8.5,
      smallestPhone: 8,
    );

    double iconSize = _getResponsiveValue(
      base: 14,
      largePhone: 13,
      mediumPhone: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double padding = _getResponsiveValue(
      base: 16,
      largePhone: 14,
      mediumPhone: 12,
      smallPhone: 10,
      smallestPhone: 8,
    );

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
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 20, smallPhone: 18, smallestPhone: 16),
          ),
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
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(padding * 0.125),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: iconSize * 0.6,
                    ),
                  ),
              ],
            ),
            SizedBox(height: padding * 0.5),
            _buildGridInfoRow(
              Icons.person_outline_rounded,
              data["ownerName"] ?? "N/A",
              iconSize: iconSize * 0.9,
              textSize: textSize,
            ),
            _buildGridInfoRow(
              Icons.phone_outlined,
              data["phone"] ?? "N/A",
              iconSize: iconSize * 0.9,
              textSize: textSize,
            ),
            _buildGridInfoRow(
              Icons.category_outlined,
              data["category"] ?? "N/A",
              iconSize: iconSize * 0.9,
              textSize: textSize,
            ),
            SizedBox(height: padding * 0.5),
            _buildStatusChip(status, small: true),
            const Spacer(),
            Divider(height: padding * 1.25, color: Colors.grey.shade200),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: iconSize * 0.8,
                  color: Colors.grey.shade400,
                ),
                SizedBox(width: padding * 0.25),
                Text(
                  _formatShortTimestamp(data["createdAt"] as Timestamp?),
                  style: TextStyle(
                    fontSize: smallTextSize,
                    color: Colors.grey.shade500,
                  ),
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
                        size: iconSize,
                      ),
                      SizedBox(width: padding * 0.25),
                      _buildMiniActionButton(
                        icon: Icons.close,
                        color: Colors.red,
                        isLoading: isLoading,
                        onPressed: () => rejectOwner(context, requestId),
                        size: iconSize,
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

  Widget _buildCompactGridRequestCard(
    DocumentSnapshot doc, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final userId = data["userId"] ?? "";
    final isLoading = _loadingRequests.contains(requestId);
    final isSelected = _selectedRequests.contains(requestId);
    final status = data["status"] ?? "pending";

    double titleSize = _getResponsiveFontSize(
      base: 13,
      largePhone: 12,
      mediumPhone: 11.5,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double textSize = _getResponsiveFontSize(
      base: 9,
      largePhone: 8.5,
      mediumPhone: 8,
      smallPhone: 7.5,
      smallestPhone: 7,
    );

    double avatarSize = _getResponsiveValue(
      base: 32,
      largePhone: 30,
      mediumPhone: 28,
      smallPhone: 26,
      smallestPhone: 24,
    );

    double iconSize = _getResponsiveValue(
      base: 12,
      largePhone: 11,
      mediumPhone: 10,
      smallPhone: 9,
      smallestPhone: 8,
    );

    double padding = _getResponsiveValue(
      base: 12,
      largePhone: 11,
      mediumPhone: 10,
      smallPhone: 9,
      smallestPhone: 8,
    );

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
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 16, smallPhone: 14, smallestPhone: 12),
          ),
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
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getStatusGradient(status),
                    ),
                    borderRadius: BorderRadius.circular(
                      _getResponsiveValue(
                        base: 8,
                        smallPhone: 7,
                        smallestPhone: 6,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (data["shopName"] ?? "S")[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: avatarSize * 0.4,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: padding * 0.67),
                Expanded(
                  child: Text(
                    data["shopName"] ?? "Shop",
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: EdgeInsets.all(padding * 0.17),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: iconSize * 0.67,
                    ),
                  ),
              ],
            ),
            SizedBox(height: padding * 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip(status, small: true),
                Text(
                  _formatShortTimestamp(data["createdAt"] as Timestamp?),
                  style: TextStyle(
                    fontSize: textSize,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String text, {
    required double iconSize,
    required double textSize,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _getResponsiveValue(
          base: 3,
          smallPhone: 2,
          smallestPhone: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: Colors.grey.shade600),
          SizedBox(
            width: _getResponsiveValue(
              base: 8,
              smallPhone: 6,
              smallestPhone: 4,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: textSize),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridInfoRow(
    IconData icon,
    String text, {
    required double iconSize,
    required double textSize,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _getResponsiveValue(
          base: 2,
          smallPhone: 1.5,
          smallestPhone: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: iconSize, color: Colors.grey.shade500),
          SizedBox(
            width: _getResponsiveValue(
              base: 4,
              smallPhone: 3,
              smallestPhone: 2,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: textSize),
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

    double iconSize = small
        ? _getResponsiveValue(base: 10, smallPhone: 9, smallestPhone: 8)
        : _getResponsiveValue(base: 12, smallPhone: 11, smallestPhone: 10);

    double fontSize = small
        ? _getResponsiveFontSize(base: 9, smallPhone: 8.5, smallestPhone: 8)
        : _getResponsiveFontSize(base: 11, smallPhone: 10, smallestPhone: 9);

    double horizontalPadding = small
        ? _getResponsiveValue(base: 8, smallPhone: 7, smallestPhone: 6)
        : _getResponsiveValue(base: 10, smallPhone: 9, smallestPhone: 8);

    double verticalPadding = small
        ? _getResponsiveValue(base: 3, smallPhone: 2.5, smallestPhone: 2)
        : _getResponsiveValue(base: 4, smallPhone: 3.5, smallestPhone: 3);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 20, smallPhone: 18, smallestPhone: 16),
        ),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(width: _getResponsiveValue(base: 4, smallestPhone: 2)),
          Text(
            small ? (status.isNotEmpty ? status[0].toUpperCase() : 'P') : label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
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
    required double fontSize,
    required double iconSize,
    required double padding,
  }) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: isLoading ? Colors.grey : color,
          side: BorderSide(color: isLoading ? Colors.grey : color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
            ),
          ),
          padding: EdgeInsets.symmetric(vertical: padding),
        ),
        child: isLoading
            ? SizedBox(
                height: iconSize,
                width: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: iconSize),
                  SizedBox(
                    width: _getResponsiveValue(base: 4, smallestPhone: 2),
                  ),
                  Text(label, style: TextStyle(fontSize: fontSize)),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: padding),
      ),
      child: isLoading
          ? SizedBox(
              height: iconSize,
              width: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: iconSize),
                SizedBox(width: _getResponsiveValue(base: 4, smallestPhone: 2)),
                Text(label, style: TextStyle(fontSize: fontSize)),
              ],
            ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback onPressed,
    required double size,
  }) {
    double containerSize = size * 2.2;

    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: isLoading ? Colors.grey.shade200 : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 8, smallPhone: 7, smallestPhone: 6),
        ),
        border: Border.all(
          color: isLoading ? Colors.grey : color.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 8, smallPhone: 7, smallestPhone: 6),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: size * 1.2,
                  height: size * 1.2,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(icon, color: color, size: size),
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

  Widget _buildLoadingMoreIndicator({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: _getResponsiveValue(
          base: 20,
          smallPhone: 15,
          smallestPhone: 10,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool search,
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    double iconSize = _getResponsiveValue(
      base: 64,
      largePhone: 58,
      mediumPhone: 52,
      smallPhone: 46,
      smallestPhone: 40,
    );

    double titleSize = _getResponsiveFontSize(
      base: 20,
      largePhone: 18,
      mediumPhone: 17,
      smallPhone: 16,
      smallestPhone: 15,
    );

    double subtitleSize = _getResponsiveFontSize(
      base: 14,
      largePhone: 13,
      mediumPhone: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double buttonFontSize = _getResponsiveFontSize(
      base: 14,
      largePhone: 13,
      mediumPhone: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double spacing = _getResponsiveValue(
      base: 24,
      largePhone: 22,
      mediumPhone: 20,
      smallPhone: 18,
      smallestPhone: 16,
    );

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(spacing),
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
                      padding: EdgeInsets.all(iconSize * 0.5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        search ? Icons.search_off_rounded : Icons.inbox_rounded,
                        size: iconSize,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: spacing),
              Text(
                search
                    ? "No matching applications found"
                    : "No applications yet",
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: spacing * 0.33),
              Text(
                search
                    ? "Try adjusting your search or filter"
                    : "New applications will appear here",
                style: TextStyle(
                  fontSize: subtitleSize,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing),
              if (search)
                ElevatedButton.icon(
                  onPressed: _clearSearch,
                  icon: Icon(Icons.clear_rounded, size: buttonFontSize * 1.2),
                  label: Text(
                    'Clear search',
                    style: TextStyle(fontSize: buttonFontSize),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        _getResponsiveValue(
                          base: 16,
                          smallPhone: 14,
                          smallestPhone: 12,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing * 0.8,
                      vertical: spacing * 0.4,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final textScale = MediaQuery.of(context).textScaleFactor;

    double iconSize = screenWidth < 360
        ? 32
        : screenWidth < 400
        ? 36
        : 40;
    double titleSize = screenWidth < 360
        ? 16
        : screenWidth < 400
        ? 18
        : 20;
    double textSize = screenWidth < 360
        ? 12
        : screenWidth < 400
        ? 13
        : 14;
    double padding = screenWidth < 360
        ? 12
        : screenWidth < 400
        ? 14
        : 16;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(screenWidth < 360 ? 20 : 24),
      ),
      title: Column(
        children: [
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: widget.actionColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.title.contains("Approve")
                  ? Icons.check_circle_rounded
                  : Icons.warning_rounded,
              color: widget.actionColor,
              size: iconSize,
            ),
          ),
          SizedBox(height: padding * 0.75),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: titleSize * textScale.clamp(0.8, 1.2),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Are you sure you want to ${widget.title.toLowerCase()} ${widget.count} selected request(s)?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: textSize * textScale.clamp(0.8, 1.2)),
          ),
          SizedBox(height: padding),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(padding * 0.75),
              ),
              contentPadding: EdgeInsets.all(padding * 0.75),
            ),
            style: TextStyle(fontSize: textSize * textScale.clamp(0.8, 1.2)),
            maxLines: 2,
            onChanged: widget.onNoteChanged,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: textSize * textScale.clamp(0.8, 1.2),
              color: Colors.grey.shade700,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.actionColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(padding * 0.75),
            ),
          ),
          child: Text(
            widget.title,
            style: TextStyle(fontSize: textSize * textScale.clamp(0.8, 1.2)),
          ),
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
    final screenWidth = size.width;
    final screenHeight = size.height;
    final textScale = MediaQuery.of(context).textScaleFactor;

    double titleSize = screenWidth < 360
        ? 18
        : screenWidth < 400
        ? 19
        : 20;
    double headingSize = screenWidth < 360
        ? 15
        : screenWidth < 400
        ? 16
        : 17;
    double textSize = screenWidth < 360
        ? 12
        : screenWidth < 400
        ? 13
        : 14;
    double smallTextSize = screenWidth < 360
        ? 10
        : screenWidth < 400
        ? 11
        : 12;
    double padding = screenWidth < 360
        ? 12
        : screenWidth < 400
        ? 16
        : 20;
    double spacing = screenWidth < 360
        ? 12
        : screenWidth < 400
        ? 14
        : 16;
    double iconSize = screenWidth < 360
        ? 16
        : screenWidth < 400
        ? 18
        : 20;
    double avatarSize = screenWidth < 360
        ? 60
        : screenWidth < 400
        ? 70
        : 80;

    return Container(
      height: screenHeight * (screenWidth < 360 ? 0.95 : 0.9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(screenWidth < 360 ? 20 : 24),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: padding * 0.5, bottom: padding * 0.4),
            width: screenWidth * 0.15,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                Text(
                  'Application Details',
                  style: TextStyle(
                    fontSize: titleSize * textScale.clamp(0.8, 1.2),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: iconSize),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: iconSize * 1.5,
                    minHeight: iconSize * 1.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: avatarSize,
                          height: avatarSize,
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
                              (requestData["shopName"] ?? "S")
                                      .toString()
                                      .isNotEmpty
                                  ? requestData["shopName"][0].toUpperCase()
                                  : 'S',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: avatarSize * 0.4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: spacing),
                        Text(
                          requestData["shopName"] ?? "Unnamed Shop",
                          style: TextStyle(
                            fontSize: titleSize * textScale.clamp(0.8, 1.2),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: spacing * 0.5),
                        _buildStatusChip(
                          requestData["status"] ?? "pending",
                          large: true,
                          textSize: textSize,
                          iconSize: iconSize,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing * 1.5),
                  _buildDetailSection(
                    title: 'Owner Information',
                    icon: Icons.person_rounded,
                    children: [
                      _buildDetailItem(
                        'Name',
                        requestData["ownerName"] ?? "N/A",
                        textSize: textSize,
                        smallTextSize: smallTextSize,
                      ),
                      _buildDetailItem(
                        'Email',
                        requestData["email"] ?? "N/A",
                        textSize: textSize,
                        smallTextSize: smallTextSize,
                      ),
                      _buildDetailItem(
                        'Phone',
                        requestData["phone"] ?? "N/A",
                        textSize: textSize,
                        smallTextSize: smallTextSize,
                      ),
                    ],
                    iconSize: iconSize,
                    headingSize: headingSize,
                    padding: padding * 0.8,
                    spacing: spacing,
                  ),
                  SizedBox(height: spacing),
                  _buildDetailSection(
                    title: 'Shop Information',
                    icon: Icons.store_rounded,
                    children: [
                      _buildDetailItem(
                        'Category',
                        requestData["category"] ?? "N/A",
                        textSize: textSize,
                        smallTextSize: smallTextSize,
                      ),
                      _buildDetailItem(
                        'Delivery Type',
                        requestData["deliveryType"] ?? "N/A",
                        textSize: textSize,
                        smallTextSize: smallTextSize,
                      ),
                      if (requestData["gstNumber"] != null)
                        _buildDetailItem(
                          'GST Number',
                          requestData["gstNumber"],
                          textSize: textSize,
                          smallTextSize: smallTextSize,
                        ),
                      _buildDetailItem(
                        'Address',
                        requestData["address"] ?? "No address provided",
                        isMultiline: true,
                        textSize: textSize,
                        smallTextSize: smallTextSize,
                      ),
                    ],
                    iconSize: iconSize,
                    headingSize: headingSize,
                    padding: padding * 0.8,
                    spacing: spacing,
                  ),
                  if (requestData["description"] != null &&
                      requestData["description"].toString().isNotEmpty) ...[
                    SizedBox(height: spacing),
                    _buildDetailSection(
                      title: 'Description',
                      icon: Icons.description_rounded,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(padding * 0.6),
                          child: Text(
                            requestData["description"],
                            style: TextStyle(
                              fontSize: textSize * textScale.clamp(0.8, 1.2),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      iconSize: iconSize,
                      headingSize: headingSize,
                      padding: padding * 0.8,
                      spacing: spacing,
                    ),
                  ],
                  SizedBox(height: spacing),
                  _buildDetailSection(
                    title: 'Timeline',
                    icon: Icons.access_time_rounded,
                    children: [
                      _buildTimelineItem(
                        'Applied',
                        _formatFullDate(requestData["createdAt"] as Timestamp?),
                        Icons.edit_calendar_rounded,
                        Colors.blue,
                        isFirst: true,
                        textSize: textSize,
                        smallTextSize: smallTextSize,
                        iconSize: iconSize,
                        spacing: spacing,
                      ),
                      if (requestData["approvedAt"] != null)
                        _buildTimelineItem(
                          'Approved',
                          _formatFullDate(
                            requestData["approvedAt"] as Timestamp?,
                          ),
                          Icons.check_circle_rounded,
                          Colors.green,
                          textSize: textSize,
                          smallTextSize: smallTextSize,
                          iconSize: iconSize,
                          spacing: spacing,
                        ),
                      if (requestData["rejectedAt"] != null)
                        _buildTimelineItem(
                          'Rejected',
                          _formatFullDate(
                            requestData["rejectedAt"] as Timestamp?,
                          ),
                          Icons.cancel_rounded,
                          Colors.red,
                          textSize: textSize,
                          smallTextSize: smallTextSize,
                          iconSize: iconSize,
                          spacing: spacing,
                        ),
                    ],
                    iconSize: iconSize,
                    headingSize: headingSize,
                    padding: padding * 0.8,
                    spacing: spacing,
                  ),
                  SizedBox(height: spacing * 1.5),
                  if ((requestData["status"] ?? "pending") == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onApprove();
                            },
                            icon: Icon(Icons.check_rounded, size: iconSize),
                            label: Text(
                              'Approve',
                              style: TextStyle(
                                fontSize: textSize * textScale.clamp(0.8, 1.2),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: padding * 0.7,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  padding * 0.75,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: padding * 0.75),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onReject();
                            },
                            icon: Icon(Icons.close_rounded, size: iconSize),
                            label: Text(
                              'Reject',
                              style: TextStyle(
                                fontSize: textSize * textScale.clamp(0.8, 1.2),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: EdgeInsets.symmetric(
                                vertical: padding * 0.7,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  padding * 0.75,
                                ),
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

  Widget _buildStatusChip(
    String status, {
    bool large = false,
    required double textSize,
    required double iconSize,
  }) {
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

    double horizontalPadding = large ? textSize * 1.2 : textSize * 0.8;
    double verticalPadding = large ? textSize * 0.6 : textSize * 0.3;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize * (large ? 1.1 : 0.9)),
          SizedBox(width: textSize * 0.3),
          Text(
            large ? label : (status.isNotEmpty ? status[0].toUpperCase() : 'P'),
            style: TextStyle(
              color: color,
              fontSize: large ? textSize * 1.1 : textSize * 0.85,
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
    required double iconSize,
    required double headingSize,
    required double padding,
    required double spacing,
  }) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(padding),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: iconSize, color: Colors.deepPurple),
              SizedBox(width: spacing * 0.5),
              Text(
                title,
                style: TextStyle(
                  fontSize: headingSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing * 0.75),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value, {
    bool isMultiline = false,
    required double textSize,
    required double smallTextSize,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: textSize * 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: textSize * 8,
            child: Text(
              label,
              style: TextStyle(
                fontSize: smallTextSize,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: textSize, fontWeight: FontWeight.w500),
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
    required double textSize,
    required double smallTextSize,
    required double iconSize,
    required double spacing,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: spacing * 0.5,
        top: isFirst ? 0 : spacing * 0.75,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(spacing * 0.5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          SizedBox(width: spacing * 0.75),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: textSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: smallTextSize,
                    color: Colors.grey.shade600,
                  ),
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
