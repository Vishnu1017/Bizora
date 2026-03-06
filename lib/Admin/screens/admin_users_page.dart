import 'dart:async';
import 'dart:math' as math;
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/services/owner_request_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enterprise-Grade Admin Users Management
/// Built for scale, performance, and exceptional UX
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ============== ADVANCED STATE MANAGEMENT ==============
  late final AnimationController _headerController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  late final ScrollController _scrollController;
  late final FocusNode _searchFocusNode;

  // Search and filters with debouncing
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';
  String _selectedStatusFilter = 'all';
  String _selectedSortField = 'displayName';
  bool _sortAscending = true;

  // View mode with responsive grid calculations
  bool _isGridView = false;
  int _gridCrossAxisCount = 1;
  double _gridChildAspectRatio = 1.3;

  // Selection with smart batch operations
  final Set<String> _selectedUsers = {};
  bool _isSelectionMode = false;

  // Performance optimization
  final Set<String> _loadingUsers = {};
  final Map<String, bool> _expandedCards = {};
  final int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Store all loaded documents for pagination
  List<DocumentSnapshot> _allDocs = [];
  bool _isInitialLoad = true;

  // Real-time stats with animations
  late final Map<String, ValueNotifier<int>> _statsNotifiers;
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _ownerUsers = 0;
  int _newUsersToday = 0;
  int _suspendedUsers = 0;
  int _adminUsers = 0;

  // Advanced features
  bool _isRefreshing = false;
  bool _showAdvancedFilters = false;
  List<String> _recentSearches = [];
  final Map<String, Timer> _actionTimers = {};

  User? _currentUser;
  Map<String, dynamic>? _userData;

  final OwnerRequestService _ownerRequestService = OwnerRequestService();
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeStatsNotifiers();
    _loadStats();
    _loadRecentSearches();
    _loadInitialUsers();
    WidgetsBinding.instance.addObserver(this);
  }

  void _initializeControllers() {
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scrollController = ScrollController()..addListener(_onScroll);

    _searchFocusNode = FocusNode();
  }

  void _initializeStatsNotifiers() {
    _statsNotifiers = {
      'total': ValueNotifier<int>(0),
      'active': ValueNotifier<int>(0),
      'owners': ValueNotifier<int>(0),
      'new': ValueNotifier<int>(0),
      'suspended': ValueNotifier<int>(0),
      'admins': ValueNotifier<int>(0),
    };
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _headerController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _actionTimers.forEach((_, timer) => timer.cancel());
    _actionTimers.clear();
    _statsNotifiers.values.forEach((notifier) => notifier.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============== ENHANCED DATA LOADING ==============
  Future<void> _loadInitialUsers() async {
    _isInitialLoad = true;
    _allDocs.clear();
    _lastDocument = null;
    _hasMoreData = true;
    await _loadMoreUsers(reset: true);
    _isInitialLoad = false;
  }

  Future<void> _loadStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final totalCount = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();

      final activeCount = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      final ownersCount = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'owner')
          .count()
          .get();

      final newTodayCount = await FirebaseFirestore.instance
          .collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .count()
          .get();

      final suspendedCount = await FirebaseFirestore.instance
          .collection('users')
          .where('isActive', isEqualTo: false)
          .count()
          .get();

      final adminsCount = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .count()
          .get();

      setState(() {
        _totalUsers = totalCount.count!;
        _activeUsers = activeCount.count!;
        _ownerUsers = ownersCount.count!;
        _newUsersToday = newTodayCount.count!;
        _suspendedUsers = suspendedCount.count!;
        _adminUsers = adminsCount.count!;
      });

      // Update notifiers for animations
      _statsNotifiers['total']!.value = _totalUsers;
      _statsNotifiers['active']!.value = _activeUsers;
      _statsNotifiers['owners']!.value = _ownerUsers;
      _statsNotifiers['new']!.value = _newUsersToday;
      _statsNotifiers['suspended']!.value = _suspendedUsers;
      _statsNotifiers['admins']!.value = _adminUsers;
    } catch (e) {
      _handleError('Error loading stats', e);
    }
  }

  void _loadRecentSearches() {
    // Load from shared preferences or local storage
    // This is a placeholder for actual implementation
    _recentSearches = [];
  }

  void _saveRecentSearch(String query) {
    if (query.isEmpty) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 5) {
        _recentSearches = _recentSearches.sublist(0, 5);
      }
    });
    // Save to persistent storage
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreUsers();
    }
  }

  Future<void> _loadMoreUsers({bool reset = false}) async {
    if (_isLoadingMore || (!_hasMoreData && !reset)) return;

    setState(() => _isLoadingMore = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      // Apply filters
      if (_selectedRoleFilter != 'all') {
        query = query.where('role', isEqualTo: _selectedRoleFilter);
      }

      if (_selectedStatusFilter != 'all') {
        final isActive = _selectedStatusFilter == 'active';
        query = query.where('isActive', isEqualTo: isActive);
      }

      // Apply pagination
      if (!reset && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (reset) {
        _allDocs = snapshot.docs;
      } else {
        _allDocs.addAll(snapshot.docs);
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMoreData = snapshot.docs.length == _pageSize;
      } else {
        _hasMoreData = false;
      }

      setState(() {});
    } catch (e) {
      print('Error loading more users: $e');
      _handleError('Error loading more users', e);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // ============== ENHANCED USER OPERATIONS ==============
  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    _startActionTimer(userId);
    setState(() => _loadingUsers.add(userId));

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) throw Exception('User not found');

        transaction.update(userRef, {
          'isActive': !currentStatus,
          'statusUpdatedAt': FieldValue.serverTimestamp(),
          'statusUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
          'statusChangeReason': 'Admin action',
          'metadata.lastModified': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      _showSuccessNotification(
        !currentStatus
            ? 'User activated successfully'
            : 'User suspended successfully',
      );

      await _loadInitialUsers(); // 🔥 refresh list instantly
      _loadStats();
      _hapticFeedback();
    } catch (e) {
      _handleError('Failed to update user status', e);
    } finally {
      _cancelActionTimer(userId);
      if (mounted) {
        setState(() => _loadingUsers.remove(userId));
      }
    }
  }

  Future<void> _changeUserRole(String userId, String newRole) async {
    _startActionTimer(userId);
    setState(() => _loadingUsers.add(userId));

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) throw Exception('User not found');

        final updates = <String, dynamic>{
          'role': newRole,
          'roleUpdatedAt': FieldValue.serverTimestamp(),
          'roleUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
          'metadata.lastModified': FieldValue.serverTimestamp(),
        };

        if (newRole == 'owner') {
          updates.addAll({
            'isApproved': true,
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': FirebaseAuth.instance.currentUser?.uid,
            'ownerSince': FieldValue.serverTimestamp(),
          });
        }

        transaction.update(userRef, updates);
      });

      if (!mounted) return;

      // Sync with owner_requests collection
      await _ownerRequestService.syncUserRoleWithOwnerRequest(
        userId: userId,
        newRole: newRole,
        adminId: FirebaseAuth.instance.currentUser?.uid ?? '',
        adminEmail: FirebaseAuth.instance.currentUser?.email ?? '',
        reason: 'Role changed via admin panel',
      );

      _showSuccessNotification('User role changed to $newRole');

      await _loadInitialUsers(); // 🔥 refresh list
      _loadStats();
      _hapticFeedback();
    } catch (e) {
      _handleError('Failed to change user role', e);
    } finally {
      _cancelActionTimer(userId);
      if (mounted) {
        setState(() => _loadingUsers.remove(userId));
      }
    }
  }

  Future<void> _deleteUser(String userId, String userEmail) async {
    final confirm = await _showConfirmationDialog(
      title: 'Delete User',
      message:
          'Are you sure you want to delete "$userEmail"?\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirm != true) return;

    _startActionTimer(userId);
    setState(() => _loadingUsers.add(userId));

    try {
      // First check if current user is admin
      final currentUser = FirebaseAuth.instance.currentUser;
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();

      final isAdmin = currentUserDoc.data()?['role'] == 'admin';

      if (!isAdmin) {
        throw Exception('Only admins can delete users');
      }

      // Use transaction for data integrity
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Delete user document
        transaction.delete(
          FirebaseFirestore.instance.collection('users').doc(userId),
        );

        // Delete user's related data (optional)
        final userShops = await FirebaseFirestore.instance
            .collection('shops')
            .where('ownerId', isEqualTo: userId)
            .get();

        for (var shop in userShops.docs) {
          transaction.delete(shop.reference);
        }
      });

      if (!mounted) return;

      _showSuccessNotification('User deleted permanently');

      await _loadInitialUsers(); // 🔥 refresh list
      _loadStats();
      _hapticFeedback();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _showErrorNotification(
          'Permission denied. Make sure you are an admin.',
        );
      } else {
        _handleError('Failed to delete user', e);
      }
    } catch (e) {
      _handleError('Failed to delete user', e);
    } finally {
      _cancelActionTimer(userId);
      if (mounted) {
        setState(() => _loadingUsers.remove(userId));
      }
    }
  }

  // ============== ADVANCED BATCH OPERATIONS ==============
  Future<void> _batchOperation({
    required String operation,
    required Map<String, dynamic> updates,
    required String successMessage,
  }) async {
    if (_selectedUsers.isEmpty) {
      _showWarningNotification('No users selected');
      return;
    }

    final confirm = await _showConfirmationDialog(
      title: 'Batch $operation',
      message:
          'Are you sure you want to ${operation.toLowerCase()} ${_selectedUsers.length} selected user(s)?',
      confirmText: operation,
    );

    if (confirm != true) return;

    setState(() {
      _loadingUsers.addAll(_selectedUsers);
    });

    int successCount = 0;
    int failCount = 0;
    final List<String> failedUsers = [];

    // Process in batches for performance
    final batches = _chunkList(_selectedUsers.toList(), 10);

    for (var batch in batches) {
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          for (String userId in batch) {
            transaction.update(
              FirebaseFirestore.instance.collection('users').doc(userId),
              updates,
            );
          }
        });
        successCount += batch.length;
      } catch (e) {
        failCount += batch.length;
        failedUsers.addAll(batch);
      }
    }

    setState(() {
      _loadingUsers.clear();
      _selectedUsers.clear();
      _isSelectionMode = false;
    });

    if (successCount > 0) {
      _showSuccessNotification('$successMessage $successCount user(s)');
    }

    if (failCount > 0) {
      _showErrorNotification(
        'Failed to $operation $failCount user(s)',
        details: failedUsers.take(3).join(', '),
      );
    }

    await _loadInitialUsers(); // 🔥 refresh list
    _loadStats();
    _hapticFeedback();
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    return List.generate(
      (list.length / chunkSize).ceil(),
      (i) => list.sublist(
        i * chunkSize,
        math.min((i + 1) * chunkSize, list.length),
      ),
    );
  }

  // ============== ENHANCED UI COMPONENTS ==============
  @override
  Widget build(BuildContext context) {
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildResponsiveLayout(constraints);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1100;
    final isDesktop = width >= 1100;
    final isLargeDesktop = width >= 1600;

    // Optimize grid layout based on screen size
    if (isLargeDesktop) {
      _gridCrossAxisCount = 4;
      _gridChildAspectRatio = 1.2;
    } else if (isDesktop) {
      _gridCrossAxisCount = 3;
      _gridChildAspectRatio = 1.25;
    } else if (isTablet) {
      _gridCrossAxisCount = 2;
      _gridChildAspectRatio = 1.3;
    } else {
      _gridCrossAxisCount = 1;
      _gridChildAspectRatio = 1.35;
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile
            ? 12
            : isDesktop
            ? 32
            : 24,
        vertical: isMobile ? 12 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - fixed height
          _buildHeader(isMobile, isDesktop),

          const SizedBox(height: 16),

          // Stats section - fixed height (wrap with ConstrainedBox to limit height)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: isMobile ? 140 : 180),
            child: _buildStatsSection(isMobile, isDesktop),
          ),

          const SizedBox(height: 16),

          // Search and filters - fixed height
          _buildSearchAndFilters(isMobile, isDesktop),

          const SizedBox(height: 12),

          // Action bar - fixed height (when visible)
          _buildActionBar(isMobile),

          const SizedBox(height: 12),

          // Users content - takes remaining space
          Expanded(child: _buildUsersContent(isMobile, isDesktop)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isDesktop) {
    return FadeTransition(
      opacity: _headerController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: _headerController,
                curve: Curves.easeOutCubic,
              ),
            ),
        child: Row(
          children: [
            // Animated logo/brand element
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * value),
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 10 : 14),
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
                      size: isMobile ? 24 : 32,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            // Title with dynamic typography
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                    "Users Management",
                    style: TextStyle(
                      fontSize: isMobile
                          ? 24
                          : isDesktop
                          ? 32
                          : 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      foreground: Paint()
                        ..shader = const LinearGradient(
                          colors: [Colors.deepPurple, Colors.purple],
                        ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                    ),
                  ),
                  Text(
                    "Enterprise user control center",
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Action buttons with tooltips
            Row(
              children: [
                _buildHeaderAction(
                  icon: _isSelectionMode
                      ? Icons.close_rounded
                      : Icons.checklist_rounded,
                  tooltip: _isSelectionMode
                      ? 'Cancel selection'
                      : 'Select mode',
                  onPressed: _toggleSelectionMode,
                  color: _isSelectionMode ? Colors.red : Colors.deepPurple,
                  isMobile: isMobile,
                ),
                const SizedBox(width: 8),
                _buildHeaderAction(
                  icon: Icons.download_rounded,
                  tooltip: 'Export data',
                  onPressed: _exportUserData,
                  color: Colors.green,
                  isMobile: isMobile,
                ),
                const SizedBox(width: 8),
                _buildHeaderAction(
                  icon: _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  tooltip: _isGridView ? 'List view' : 'Grid view',
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  color: Colors.blue,
                  isMobile: isMobile,
                ),
                const SizedBox(width: 8),
                _buildHeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh data',
                  onPressed: _refreshData,
                  color: Colors.orange,
                  isMobile: isMobile,
                  showLoader: _isRefreshing,
                ),
              ],
            ),
          ],
        ),
      ),
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
              borderRadius: BorderRadius.circular(14),
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
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final showFullStats = constraints.maxWidth > 800;

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
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildStatCard(
                        "Total Users",
                        _statsNotifiers['total']!,
                        Colors.deepPurple,
                        Icons.people_rounded,
                        isMobile,
                        showFullStats,
                      ),
                      _buildStatCard(
                        "Active",
                        _statsNotifiers['active']!,
                        Colors.green,
                        Icons.check_circle_rounded,
                        isMobile,
                        showFullStats,
                      ),
                      _buildStatCard(
                        "Owners",
                        _statsNotifiers['owners']!,
                        Colors.orange,
                        Icons.store_rounded,
                        isMobile,
                        showFullStats,
                      ),
                      _buildStatCard(
                        "New Today",
                        _statsNotifiers['new']!,
                        Colors.blue,
                        Icons.today_rounded,
                        isMobile,
                        showFullStats,
                      ),
                      if (showFullStats) ...[
                        _buildStatCard(
                          "Suspended",
                          _statsNotifiers['suspended']!,
                          Colors.red,
                          Icons.pause_circle_rounded,
                          isMobile,
                          showFullStats,
                        ),
                        _buildStatCard(
                          "Admins",
                          _statsNotifiers['admins']!,
                          Colors.purple,
                          Icons.admin_panel_settings_rounded,
                          isMobile,
                          showFullStats,
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
    bool showFullStats,
  ) {
    return Container(
      width: showFullStats ? null : 140,
      constraints: BoxConstraints(
        minWidth: showFullStats ? 140 : 120,
        maxWidth: showFullStats ? 200 : 140,
      ),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Animated icon container
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: isMobile ? 18 : 22),
                  ),
                  const SizedBox(width: 12),
                  // Count with animation
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: countNotifier,
                          builder: (context, count, _) {
                            return AnimatedCount(
                              count: count,
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 22,
                                fontWeight: FontWeight.bold,
                                color: color,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 12,
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

  Widget _buildSearchAndFilters(bool isMobile, bool isDesktop) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                  // Search bar with suggestions
                  _buildSearchBar(isMobile),
                  if (_recentSearches.isNotEmpty && _searchFocusNode.hasFocus)
                    _buildSearchSuggestions(isMobile),
                  const SizedBox(height: 12),
                  // Filter chips
                  _buildFilterChips(isMobile),
                  const SizedBox(height: 8),
                  // Advanced filters toggle
                  _buildAdvancedFiltersToggle(isMobile),
                  if (_showAdvancedFilters) _buildAdvancedFilters(isMobile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _searchFocusNode.hasFocus
              ? Colors.deepPurple
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search_rounded,
            color: _searchFocusNode.hasFocus
                ? Colors.deepPurple
                : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: "Search by name, email, phone, or ID...",
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: isMobile ? 14 : 16,
                ),
              ),
              style: TextStyle(fontSize: isMobile ? 14 : 16),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
              onPressed: _clearSearch,
            ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.tune_rounded, color: Colors.deepPurple.shade300),
              onPressed: () {
                setState(() => _showAdvancedFilters = !_showAdvancedFilters);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions(bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Recent searches',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((search) {
              return FilterChip(
                label: Text(search),
                onSelected: (_) {
                  _searchController.text = search;
                  _onSearchChanged(search);
                  _searchFocusNode.unfocus();
                },
                backgroundColor: Colors.white,
                deleteIcon: Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    _recentSearches.remove(search);
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChipGroup(
            'Role',
            [
              {'label': 'All', 'value': 'all'},
              {'label': 'Users', 'value': 'user'},
              {'label': 'Owners', 'value': 'owner'},
              {'label': 'Admins', 'value': 'admin'},
            ],
            _selectedRoleFilter,
            (value) {
              setState(() {
                _selectedRoleFilter = value;
                _loadInitialUsers();
              });
            },
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.grey.shade300,
          ),
          _buildFilterChipGroup(
            'Status',
            [
              {'label': 'All', 'value': 'all'},
              {'label': 'Active', 'value': 'active'},
              {'label': 'Suspended', 'value': 'suspended'},
            ],
            _selectedStatusFilter,
            (value) {
              setState(() {
                _selectedStatusFilter = value;
                _loadInitialUsers();
              });
            },
          ),
          Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.grey.shade300,
          ),
          _buildFilterChipGroup(
            'Sort by',
            [
              {'label': 'Name', 'value': 'displayName'},
              {'label': 'Joined', 'value': 'createdAt'},
              {'label': 'Last active', 'value': 'lastLogin'},
              {'label': 'Email', 'value': 'email'},
            ],
            _selectedSortField,
            (value) => setState(() => _selectedSortField = value),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              _sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 18,
              color: Colors.deepPurple,
            ),
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            tooltip: _sortAscending ? 'Ascending' : 'Descending',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipGroup(
    String label,
    List<Map<String, String>> options,
    String selectedValue,
    Function(String) onSelected, {
    Color color = Colors.deepPurple,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with modern styling
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Filter chips in a wrap for better responsiveness
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option['value'];
            final optionColor = _getOptionColor(option['value'] ?? '', color);

            return InkWell(
              onTap: () => onSelected(option['value']!),
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? optionColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? optionColor.withOpacity(0.05)
                      : Colors.transparent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Optional icon based on option
                    if (_getOptionIcon(option['value'] ?? '') != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          _getOptionIcon(option['value'] ?? ''),
                          size: 14,
                          color: isSelected
                              ? optionColor
                              : Colors.grey.shade500,
                        ),
                      ),

                    // Label
                    Text(
                      option['label']!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected ? optionColor : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Helper methods for additional features
  Color _getOptionColor(String value, Color defaultColor) {
    switch (value) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inactive':
      case 'suspended':
        return Colors.red;
      case 'admin':
        return Colors.purple;
      case 'owner':
        return Colors.orange;
      case 'user':
        return Colors.blue;
      default:
        return defaultColor;
    }
  }

  IconData? _getOptionIcon(String value) {
    switch (value) {
      case 'active':
        return Icons.check_circle_rounded;
      case 'inactive':
      case 'suspended':
        return Icons.pause_circle_rounded;
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'owner':
        return Icons.store_rounded;
      case 'user':
        return Icons.person_rounded;
      case 'all':
        return Icons.people_rounded;
      default:
        return null;
    }
  }

  Widget _buildAdvancedFiltersToggle(bool isMobile) {
    return GestureDetector(
      onTap: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _showAdvancedFilters
                  ? 'Hide advanced filters'
                  : 'Show advanced filters',
              style: TextStyle(
                fontSize: 12,
                color: Colors.deepPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              _showAdvancedFilters
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAdvancedFilterField(
                  label: 'Min. join date',
                  hint: 'From',
                  icon: Icons.calendar_today_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAdvancedFilterField(
                  label: 'Max. join date',
                  hint: 'To',
                  icon: Icons.calendar_today_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAdvancedFilterField(
                  label: 'Min. orders',
                  hint: '0',
                  icon: Icons.shopping_bag_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAdvancedFilterField(
                  label: 'Min. spent',
                  hint: '\$0',
                  icon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // Clear advanced filters
                },
                child: const Text('Clear all'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Apply advanced filters
                  setState(() => _showAdvancedFilters = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Apply filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFilterField({
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  keyboardType: keyboardType,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(bool isMobile) {
    if (!_isSelectionMode || _selectedUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 12 : 16,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(20),
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
                // Selection count with animation
                TweenAnimationBuilder<int>(
                  duration: const Duration(milliseconds: 200),
                  tween: IntTween(begin: 0, end: _selectedUsers.length),
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
                          fontSize: 14,
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
                          label: "Activate all",
                          icon: Icons.check_circle_rounded,
                          color: Colors.green,
                          onPressed: () => _batchOperation(
                            operation: 'Activate',
                            updates: {
                              'isActive': true,
                              'statusUpdatedAt': FieldValue.serverTimestamp(),
                              'statusUpdatedBy':
                                  FirebaseAuth.instance.currentUser?.uid,
                            },
                            successMessage: 'Activated',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildActionChip(
                          label: "Suspend all",
                          icon: Icons.pause_circle_rounded,
                          color: Colors.orange,
                          onPressed: () => _batchOperation(
                            operation: 'Suspend',
                            updates: {
                              'isActive': false,
                              'statusUpdatedAt': FieldValue.serverTimestamp(),
                              'statusUpdatedBy':
                                  FirebaseAuth.instance.currentUser?.uid,
                            },
                            successMessage: 'Suspended',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildActionChip(
                          label: "Make owners",
                          icon: Icons.store_rounded,
                          color: Colors.amber,
                          onPressed: () => _batchOperation(
                            operation: 'Make owners',
                            updates: {
                              'role': 'owner',
                              'roleUpdatedAt': FieldValue.serverTimestamp(),
                              'roleUpdatedBy':
                                  FirebaseAuth.instance.currentUser?.uid,
                            },
                            successMessage: 'Updated',
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildActionChip(
                          label: "Clear selection",
                          icon: Icons.clear_rounded,
                          color: Colors.white,
                          onPressed: _toggleSelectionMode,
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
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsersContent(bool isMobile, bool isDesktop) {
    if (_isInitialLoad && _allDocs.isEmpty) {
      return _buildLoadingShimmer(isMobile);
    }

    final docs = _filterDocs(_allDocs);

    if (docs.isEmpty) {
      return _buildEmptyState(isMobile, search: _searchQuery.isNotEmpty);
    }

    if (_isSelectionMode) {
      return Column(
        children: [
          _buildSelectAllHeader(docs),
          const SizedBox(height: 12),
          Expanded(
            child: _isGridView
                ? _buildResponsiveGrid(docs, isMobile, isDesktop)
                : _buildResponsiveList(docs, isMobile, isDesktop),
          ),
        ],
      );
    }

    return _isGridView
        ? _buildResponsiveGrid(docs, isMobile, isDesktop)
        : _buildResponsiveList(docs, isMobile, isDesktop);
  }

  List<DocumentSnapshot> _filterDocs(List<DocumentSnapshot> docs) {
    List<DocumentSnapshot> filtered = List.from(docs);

    // 🔎 Search filtering
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final searchableFields = [
          data['email']?.toString().toLowerCase() ?? '',
          data['displayName']?.toString().toLowerCase() ?? '',
          (data['phone'] ?? data['phoneNumber'])?.toString() ?? '',
          data['userId']?.toString() ?? '',
        ];
        return searchableFields.any((field) => field.contains(_searchQuery));
      }).toList();
    }

    // 🔄 Client-side sorting
    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      dynamic valueA = dataA[_selectedSortField];
      dynamic valueB = dataB[_selectedSortField];

      if (valueA == null && valueB == null) return 0;
      if (valueA == null) return 1;
      if (valueB == null) return -1;

      if (valueA is Timestamp && valueB is Timestamp) {
        return _sortAscending
            ? valueA.compareTo(valueB)
            : valueB.compareTo(valueA);
      }

      final comparison = valueA.toString().compareTo(valueB.toString());
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Widget _buildSelectAllHeader(List<DocumentSnapshot> docs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Custom checkbox
          GestureDetector(
            onTap: () {
              setState(() {
                if (_selectedUsers.length == docs.length) {
                  _selectedUsers.clear();
                } else {
                  _selectedUsers.clear();
                  _selectedUsers.addAll(docs.map((doc) => doc.id));
                }
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _selectedUsers.length == docs.length
                    ? Colors.deepPurple
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedUsers.length == docs.length
                      ? Colors.deepPurple
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: _selectedUsers.length == docs.length
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Select All',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          // Selection info with animation
          TweenAnimationBuilder<int>(
            duration: const Duration(milliseconds: 200),
            tween: IntTween(begin: 0, end: _selectedUsers.length),
            builder: (context, count, child) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count selected',
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveList(
    List<DocumentSnapshot> docs,
    bool isMobile,
    bool isDesktop,
  ) {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: docs.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == docs.length) {
          return _buildLoadingMoreIndicator();
        }

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 1000)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: _buildUserCard(docs[index], isMobile, isDesktop),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildResponsiveGrid(
    List<DocumentSnapshot> docs,
    bool isMobile,
    bool isDesktop,
  ) {
    return GridView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridCrossAxisCount,
        childAspectRatio: _gridChildAspectRatio,
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
      ),
      itemCount: docs.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == docs.length) {
          return _buildGridLoadingMoreIndicator();
        }

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 30).clamp(0, 1000)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.9 + (0.1 * value),
                child: _buildUserGridCard(docs[index], isMobile, isDesktop),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserCard(DocumentSnapshot doc, bool isMobile, bool isDesktop) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = doc.id;
    final isLoading = _loadingUsers.contains(userId);
    final isSelected = _selectedUsers.contains(userId);
    final isExpanded = _expandedCards[userId] ?? false;
    final isActive = data['isActive'] ?? true;
    final role = data['role'] ?? 'user';
    final email = data['email'] ?? 'No email';
    final displayName = data['displayName'] ?? email.split('@')[0];
    final phoneNumber = data['phone'] ?? data['phoneNumber'] ?? 'No phone';
    final createdAt = data['createdAt'] as Timestamp?;
    final lastLogin = data['lastLogin'] as Timestamp?;
    final photoURL = data['photoURL'];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: _isSelectionMode
          ? null
          : () {
              _hapticFeedback();
              setState(() {
                _isSelectionMode = true;
                _selectedUsers.add(userId);
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurple
                : isActive
                ? Colors.transparent
                : Colors.red.withOpacity(0.3),
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
        child: IntrinsicHeight(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main card content
              Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selection checkbox
                    if (_isSelectionMode)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildCheckbox(isSelected, userId),
                      ),

                    // Avatar with loading state
                    _buildAvatarWithLoading(
                      userId: userId,
                      displayName: displayName,
                      photoURL: photoURL,
                      role: role,
                      isLoading: isLoading,
                      size: isMobile ? 50 : 60,
                    ),

                    const SizedBox(width: 16),

                    // User details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name and badges row
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.black87
                                      : Colors.grey,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              _buildRoleBadge(role),
                              _buildStatusBadge(isActive),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Email
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Phone
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  phoneNumber,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Timestamps
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildTimestampChip(
                                icon: Icons.access_time_rounded,
                                label: _formatTimestamp(createdAt),
                                color: Colors.blue,
                              ),
                              if (lastLogin != null)
                                _buildTimestampChip(
                                  icon: Icons.login_rounded,
                                  label: 'Last: ${_formatTimestamp(lastLogin)}',
                                  color: Colors.green,
                                ),
                            ],
                          ),

                          if (isExpanded)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: SingleChildScrollView(
                                child: _buildExpandedDetails(data),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Actions menu
                    if (!_isSelectionMode)
                      _buildCardActions(
                        userId,
                        isActive,
                        role,
                        email,
                        isLoading,
                      ),
                  ],
                ),
              ),

              // Expand/collapse indicator
              if (!_isSelectionMode)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _expandedCards[userId] = !isExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isExpanded ? 'Show less' : 'Show more',
                          style: TextStyle(
                            fontSize: 12,
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserGridCard(
    DocumentSnapshot doc,
    bool isMobile,
    bool isDesktop,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = doc.id;
    final isLoading = _loadingUsers.contains(userId);
    final isSelected = _selectedUsers.contains(userId);
    final isActive = data['isActive'] ?? true;
    final role = data['role'] ?? 'user';
    final email = data['email'] ?? 'No email';
    final displayName = data['displayName'] ?? email.split('@')[0];
    final photoURL = data['photoURL'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? Colors.deepPurple
              : isActive
              ? Colors.transparent
              : Colors.red.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Selection checkbox for grid mode
          if (_isSelectionMode)
            Positioned(
              top: 12,
              right: 12,
              child: _buildCheckbox(isSelected, userId),
            ),

          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                _buildAvatarWithLoading(
                  userId: userId,
                  displayName: displayName,
                  photoURL: photoURL,
                  role: role,
                  isLoading: isLoading,
                  size: isMobile ? 60 : 70,
                ),

                const SizedBox(height: 12),

                // Name
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.black87 : Colors.grey,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 4),

                // Email
                Text(
                  email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                // Role and status badges
                Wrap(
                  spacing: 6,
                  children: [
                    _buildRoleBadge(role, small: true),
                    _buildStatusBadge(isActive, small: true),
                  ],
                ),

                const SizedBox(height: 12),

                // Action buttons (only when not in selection mode)
                if (!_isSelectionMode)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildGridActionButton(
                        icon: isActive
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: isActive ? Colors.orange : Colors.green,
                        onPressed: () => _toggleUserStatus(userId, isActive),
                        tooltip: isActive ? 'Suspend' : 'Activate',
                        isLoading: isLoading && _loadingUsers.contains(userId),
                      ),
                      _buildGridActionButton(
                        icon: Icons.swap_horiz_rounded,
                        color: Colors.blue,
                        onPressed: () => _showRoleDialog(userId, role),
                        tooltip: 'Change Role',
                        isLoading: false,
                      ),
                      _buildGridActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red,
                        onPressed: () => _deleteUser(userId, email),
                        tooltip: 'Delete User',
                        isLoading: false,
                      ),
                    ],
                  ),

                if (isLoading && !_isSelectionMode)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(bool isSelected, String userId) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedUsers.remove(userId);
          } else {
            _selectedUsers.add(userId);
          }
        });
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : null,
      ),
    );
  }

  Widget _buildAvatarWithLoading({
    required String userId,
    required String displayName,
    required String? photoURL,
    required String role,
    required bool isLoading,
    required double size,
  }) {
    return Stack(
      children: [
        // Avatar
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _getRoleGradient(role),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getRoleGradient(role).first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.4,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Loading indicator
        if (isLoading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardActions(
    String userId,
    bool isActive,
    String role,
    String email,
    bool isLoading,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick action buttons
        _buildQuickActionButton(
          icon: isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: isActive ? Colors.orange : Colors.green,
          onPressed: () => _toggleUserStatus(userId, isActive),
          tooltip: isActive ? 'Suspend' : 'Activate',
        ),
        const SizedBox(width: 4),

        // Menu button
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            onSelected: (value) {
              switch (value) {
                case 'activate':
                case 'suspend':
                  _toggleUserStatus(userId, isActive);
                  break;
                case 'make_user':
                case 'make_owner':
                case 'make_admin':
                  _changeUserRole(userId, value.replaceAll('make_', ''));
                  break;
                case 'delete':
                  _deleteUser(userId, email);
                  break;
                case 'details':
                  _showUserDetails(userId);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (!isActive)
                PopupMenuItem(
                  value: 'activate',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text('Activate'),
                    ],
                  ),
                ),
              if (isActive)
                PopupMenuItem(
                  value: 'suspend',
                  child: Row(
                    children: [
                      Icon(
                        Icons.pause_circle_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text('Suspend'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              if (role != 'user')
                PopupMenuItem(
                  value: 'make_user',
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Text('Make User'),
                    ],
                  ),
                ),
              if (role != 'owner')
                PopupMenuItem(
                  value: 'make_owner',
                  child: Row(
                    children: [
                      Icon(Icons.store_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Text('Make Owner'),
                    ],
                  ),
                ),
              if (role != 'admin')
                PopupMenuItem(
                  value: 'make_admin',
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.purple,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text('Make Admin'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.info_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text('View Details'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGridActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
    required bool isLoading,
  }) {
    return Container(
      width: 40,
      height: 40,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role, {bool small = false}) {
    Color color;
    IconData icon;
    String label;

    switch (role) {
      case 'admin':
        color = Colors.purple;
        icon = Icons.admin_panel_settings_rounded;
        label = 'Admin';
        break;
      case 'owner':
        color = Colors.orange;
        icon = Icons.store_rounded;
        label = 'Owner';
        break;
      default:
        color = Colors.blue;
        icon = Icons.person_rounded;
        label = 'User';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 4 : 6,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: small ? 10 : 11),
          const SizedBox(width: 2),
          Text(
            small ? (role.isNotEmpty ? role[0].toUpperCase() : 'U') : label,
            style: TextStyle(
              color: color,
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive, {bool small = false}) {
    final color = isActive ? Colors.green : Colors.red;
    final icon = isActive
        ? Icons.check_circle_rounded
        : Icons.pause_circle_rounded;
    final label = isActive ? 'Active' : 'Suspended';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 4 : 6,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: small ? 10 : 11),
          const SizedBox(width: 2),
          Text(
            small ? (isActive ? 'A' : 'S') : label,
            style: TextStyle(
              color: color,
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDetailStat(
                  label: 'Orders',
                  value: (data['orderCount'] ?? 0).toString(),
                  icon: Icons.shopping_bag_rounded,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildDetailStat(
                  label: 'Spent',
                  value: '₹${(data['totalSpent'] ?? 0).toStringAsFixed(2)}',
                  icon: Icons
                      .currency_rupee_rounded, // Flutter's built-in rupee icon
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _buildDetailStat(
                  label: 'Reviews',
                  value: (data['reviewCount'] ?? 0).toString(),
                  icon: Icons.star_rounded,
                  color: Colors.orange,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Metadata
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (data['userId'] != null)
                _buildMetadataChip(
                  label: 'ID: ${data['userId']}',
                  icon: Icons.fingerprint_rounded,
                ),
              if (data['deviceInfo'] != null)
                _buildMetadataChip(
                  label:
                      'Device: ${data['deviceInfo']['platform'] ?? 'Unknown'}',
                  icon: Icons.devices_rounded,
                ),
              if (data['appVersion'] != null)
                _buildMetadataChip(
                  label: 'App v${data['appVersion']}',
                  icon: Icons.info_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 8, color: color.withOpacity(0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============== HELPER METHODS ==============
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.toLowerCase().trim();
      });
      if (query.isNotEmpty) {
        _saveRecentSearch(query);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _loadInitialUsers();
    await _loadStats();
    setState(() => _isRefreshing = false);
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedUsers.clear();
      }
    });
  }

  Future<void> _exportUserData() async {
    try {
      _showInfoNotification('Preparing export...');

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      // Generate CSV
      _generateCSV(snapshot.docs);

      // In production, save to file or share
      _showSuccessNotification('Exported ${snapshot.docs.length} users');
    } catch (e) {
      _handleError('Export failed', e);
    }
  }

  String _generateCSV(List<DocumentSnapshot> docs) {
    final headers = ['ID', 'Name', 'Email', 'Role', 'Status', 'Joined'];
    final rows = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return [
        doc.id,
        data['displayName'] ?? '',
        data['email'] ?? '',
        data['role'] ?? 'user',
        (data['isActive'] ?? true) ? 'Active' : 'Suspended',
        _formatTimestamp(data['createdAt'] as Timestamp?),
      ].join(',');
    }).toList();

    return [headers.join(','), ...rows].join('\n');
  }

  void _showUserDetails(String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailsSheet(
        userId: userId,
        onShowRoleDialog: _showRoleDialog,
        onToggleStatus: _toggleUserStatus,
        onDelete: _deleteUser,
      ),
    );
  }

  void _showRoleDialog(String userId, String currentRole) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Change User Role',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildRoleOption(
                role: 'user',
                icon: Icons.person_rounded,
                color: Colors.blue,
                description: 'Regular customer',
                isSelected: currentRole == 'user',
                onTap: () {
                  Navigator.pop(context);
                  _changeUserRole(userId, 'user');
                },
              ),
              _buildRoleOption(
                role: 'owner',
                icon: Icons.store_rounded,
                color: Colors.orange,
                description: 'Shop owner / seller',
                isSelected: currentRole == 'owner',
                onTap: () {
                  Navigator.pop(context);
                  _changeUserRole(userId, 'owner');
                },
              ),
              _buildRoleOption(
                role: 'admin',
                icon: Icons.admin_panel_settings_rounded,
                color: Colors.purple,
                description: 'Administrator',
                isSelected: currentRole == 'admin',
                onTap: () {
                  Navigator.pop(context);
                  _changeUserRole(userId, 'admin');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleOption({
    required String role,
    required IconData icon,
    required Color color,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        role[0].toUpperCase() + role.substring(1),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(description),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: color)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  List<Color> _getRoleGradient(String role) {
    switch (role) {
      case 'admin':
        return [Colors.purple.shade400, Colors.deepPurple.shade700];
      case 'owner':
        return [Colors.orange.shade400, Colors.deepOrange.shade600];
      default:
        return [Colors.blue.shade400, Colors.blue.shade700];
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  void _startActionTimer(String userId) {
    _actionTimers[userId] = Timer(const Duration(seconds: 10), () {
      if (_loadingUsers.contains(userId)) {
        setState(() => _loadingUsers.remove(userId));
        _showErrorNotification('Operation timed out');
      }
    });
  }

  void _cancelActionTimer(String userId) {
    _actionTimers[userId]?.cancel();
    _actionTimers.remove(userId);
  }

  void _hapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            if (isDestructive)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer(bool isMobile) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
      },
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

  Widget _buildGridLoadingMoreIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile, {bool search = false}) {
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
                      search
                          ? Icons.search_off_rounded
                          : Icons.people_outline_rounded,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              search ? "No users found" : "No users yet",
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              search
                  ? "Try adjusting your search or filters"
                  : "Users will appear here once they register",
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey.shade600,
              ),
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

  void _handleError(String message, Object error) {
    print('$message: $error');
    _showErrorNotification(message);
  }

  void _showSuccessNotification(String message) {
    if (!mounted) return;
    FirebaseSnackbar.success(context, message);
  }

  void _showErrorNotification(String message, {String? details}) {
    if (!mounted) return;
    final displayMessage = details != null ? '$message: $details' : message;
    FirebaseSnackbar.error(context, displayMessage);
  }

  void _showWarningNotification(String message) {
    if (!mounted) return;
    FirebaseSnackbar.warning(context, message);
  }

  void _showInfoNotification(String message) {
    if (!mounted) return;
    FirebaseSnackbar.info(context, message);
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

class _UserDetailsSheet extends StatefulWidget {
  final String userId;
  final Function(String, String) onShowRoleDialog;
  final Function(String, bool) onToggleStatus;
  final Function(String, String) onDelete;

  const _UserDetailsSheet({
    required this.userId,
    required this.onShowRoleDialog,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  State<_UserDetailsSheet> createState() => __UserDetailsSheetState();
}

class __UserDetailsSheetState extends State<_UserDetailsSheet> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<DocumentSnapshot> _userShops = [];
  List<DocumentSnapshot> _userOrders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _error = 'User not found';
          _isLoading = false;
        });
        return;
      }

      _userData = userDoc.data();

      // Load user's shops with permission check
      try {
        final shopsSnapshot = await FirebaseFirestore.instance
            .collection('shops')
            .where('ownerId', isEqualTo: widget.userId)
            .limit(5)
            .get();
        _userShops = shopsSnapshot.docs;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          print('Permission denied for shops collection');
        }
      }

      // Load user's recent orders with permission check
      try {
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: widget.userId)
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
        _userOrders = ordersSnapshot.docs;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          print('Permission denied for orders collection');
        }
      }
    } on FirebaseException catch (e) {
      setState(() {
        _error = 'Firebase error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading details: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'User Details',
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

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorState()
                : _buildDetailsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserDetails,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent() {
    if (_userData == null) return const SizedBox.shrink();

    final email = _userData!['email'] ?? 'No email';
    final displayName = _userData!['displayName'] ?? email.split('@')[0];
    final phoneNumber =
        _userData!['phone'] ?? _userData!['phoneNumber'] ?? 'Not provided';
    final role = _userData!['role'] ?? 'user';
    final isActive = _userData!['isActive'] ?? true;
    final createdAt = _userData!['createdAt'] as Timestamp?;
    final lastLogin = _userData!['lastLogin'] as Timestamp?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _getRoleGradient(role),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getRoleGradient(role).first.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDetailsBadge(
                      label: role.toUpperCase(),
                      color: _getRoleColor(role),
                    ),
                    const SizedBox(width: 8),
                    _buildDetailsBadge(
                      label: isActive ? 'ACTIVE' : 'SUSPENDED',
                      color: isActive ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Contact information
          _buildDetailsSection(
            title: 'Contact Information',
            icon: Icons.contact_mail_rounded,
            children: [
              _buildInfoRow(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: phoneNumber,
              ),
              _buildInfoRow(
                icon: Icons.email_rounded,
                label: 'Email',
                value: email,
              ),
              if (_userData!['alternatePhone'] != null)
                _buildInfoRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Alternate',
                  value: _userData!['alternatePhone'],
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Account information
          _buildDetailsSection(
            title: 'Account Information',
            icon: Icons.account_circle_rounded,
            children: [
              _buildInfoRow(
                icon: Icons.badge_rounded,
                label: 'User ID',
                value: widget.userId,
                isMonospace: true,
              ),
              _buildInfoRow(
                icon: Icons.access_time_rounded,
                label: 'Joined',
                value: _formatFullDate(createdAt),
              ),
              if (lastLogin != null)
                _buildInfoRow(
                  icon: Icons.login_rounded,
                  label: 'Last Login',
                  value: _formatFullDate(lastLogin),
                ),
              _buildInfoRow(
                icon: Icons.update_rounded,
                label: 'Last Updated',
                value: _formatFullDate(_userData!['updatedAt'] as Timestamp?),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Statistics
          _buildDetailsSection(
            title: 'Statistics',
            icon: Icons.analytics_rounded,
            children: [
              _buildStatRow(
                icon: Icons.shopping_bag_rounded,
                label: 'Total Orders',
                value: (_userData!['orderCount'] ?? 0).toString(),
                color: Colors.blue,
              ),
              _buildStatRow(
                icon: Icons.currency_rupee_rounded,
                label: 'Total Spent',
                value: '₹${(_userData!['totalSpent'] ?? 0).toStringAsFixed(2)}',
                color: Colors.green,
              ),
              _buildStatRow(
                icon: Icons.star_rounded,
                label: 'Reviews',
                value: (_userData!['reviewCount'] ?? 0).toString(),
                color: Colors.orange,
              ),
              _buildStatRow(
                icon: Icons.store_rounded,
                label: 'Shops',
                value: _userShops.length.toString(),
                color: Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Shops section
          if (_userShops.isNotEmpty)
            _buildDetailsSection(
              title: 'Shops (${_userShops.length})',
              icon: Icons.store_rounded,
              children: _userShops.map((shop) {
                final shopData = shop.data() as Map<String, dynamic>;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    shopData['shopName'] ?? 'Unnamed Shop',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Status: ${shopData['isActive'] == true ? 'Active' : 'Inactive'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: shopData['isActive'] == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  trailing: Text(
                    '₹${(shopData['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // Recent orders
          if (_userOrders.isNotEmpty)
            _buildDetailsSection(
              title: 'Recent Orders (${_userOrders.length})',
              icon: Icons.shopping_bag_rounded,
              children: _userOrders.map((order) {
                final orderData = order.data() as Map<String, dynamic>;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_rounded,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _formatFullDate(orderData['createdAt'] as Timestamp?),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Text(
                    '₹${(orderData['total'] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),

          // Device info if available
          if (_userData!['deviceInfo'] != null)
            _buildDetailsSection(
              title: 'Device Information',
              icon: Icons.devices_rounded,
              children: [
                _buildInfoRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Platform',
                  value: _userData!['deviceInfo']['platform'] ?? 'Unknown',
                ),
                _buildInfoRow(
                  icon: Icons.info_rounded,
                  label: 'App Version',
                  value: _userData!['appVersion'] ?? 'Unknown',
                ),
              ],
            ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onShowRoleDialog(widget.userId, role);
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Change Role'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: isActive
                ? OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onToggleStatus(widget.userId, isActive);
                    },
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Suspend User'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onToggleStatus(widget.userId, isActive);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Activate User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onDelete(widget.userId, email);
              },
              icon: const Icon(Icons.delete_rounded),
              label: const Text('Delete User Permanently'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailsSection({
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMonospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getRoleGradient(String role) {
    switch (role) {
      case 'admin':
        return [Colors.purple.shade400, Colors.deepPurple.shade700];
      case 'owner':
        return [Colors.orange.shade400, Colors.deepOrange.shade600];
      default:
        return [Colors.blue.shade400, Colors.blue.shade700];
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'owner':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _formatFullDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';

    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Animated count widget for smooth number transitions
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
