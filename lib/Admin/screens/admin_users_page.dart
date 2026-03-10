import 'dart:async';
import 'dart:math' as math;
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/services/owner_request_service.dart';
import 'package:bizora/widgets/ai_search_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final ValueNotifier<List<DocumentSnapshot>> _aiSearchResults = ValueNotifier(
    [],
  );
  List<DocumentSnapshot> _cachedDocs = [];
  bool _isFirstLoad = true;

  // Responsive scaling factors
  late double _screenWidth;
  // ignore: unused_field
  late double _screenHeight;
  late double _textScaleFactor;
  // ignore: unused_field
  late double _paddingScaleFactor;

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
  // ignore: unused_field
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
  // ignore: unused_field
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
  // ignore: unused_field
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

    // IMPORTANT: Initialize with default values FIRST (synchronous)
    _initializeStatsWithDefaultValues();

    // Then try to load cached stats (asynchronous)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCachedStats().then((_) {
        // After loading cache, update UI if needed
        if (mounted) {
          setState(() {});
        }
      });
    });

    // Load cached data immediately (if any)
    _loadCachedData();

    // Load fresh data in the background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadStats(); // This will update with fresh data
        _loadRecentSearches();
        _loadInitialUsers();
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  // Update this method to ensure notifiers are updated
  void _initializeStatsWithDefaultValues() {
    // Try to load from SharedPreferences or use defaults
    _totalUsers = 0;
    _activeUsers = 0;
    _ownerUsers = 0;
    _newUsersToday = 0;
    _suspendedUsers = 0;
    _adminUsers = 0;

    // IMPORTANT: Update notifiers with default values immediately
    _statsNotifiers['total']?.value = _totalUsers;
    _statsNotifiers['active']?.value = _activeUsers;
    _statsNotifiers['owners']?.value = _ownerUsers;
    _statsNotifiers['new']?.value = _newUsersToday;
    _statsNotifiers['suspended']?.value = _suspendedUsers;
    _statsNotifiers['admins']?.value = _adminUsers;
  }

  // Add this new method
  void _loadCachedData() {
    // If you have cached data from a previous session, load it here
    // For now, we'll just use an empty list to show UI immediately
    setState(() {
      _allDocs = [];
      _isFirstLoad = true;
    });
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

    // Show cached data immediately while loading fresh data
    if (_cachedDocs.isNotEmpty) {
      setState(() {
        _allDocs = List.from(_cachedDocs);
      });
    }

    _allDocs.clear();
    _lastDocument = null;
    _hasMoreData = true;
    await _loadMoreUsers(reset: true);

    // Update cache with fresh data
    setState(() {
      _cachedDocs = List.from(_allDocs);
      _isInitialLoad = false;
      _isFirstLoad = false;
    });
  }

  Future<void> _loadStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Use regular queries instead of count() if count() is failing
      // Run all queries in parallel for better performance
      final results =
          await Future.wait([
            FirebaseFirestore.instance
                .collection('users')
                .get()
                .then((snap) => snap.size),
            FirebaseFirestore.instance
                .collection('users')
                .where('isActive', isEqualTo: true)
                .get()
                .then((snap) => snap.size),
            FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'owner')
                .get()
                .then((snap) => snap.size),
            FirebaseFirestore.instance
                .collection('users')
                .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
                .get()
                .then((snap) => snap.size),
            FirebaseFirestore.instance
                .collection('users')
                .where('isActive', isEqualTo: false)
                .get()
                .then((snap) => snap.size),
            FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'admin')
                .get()
                .then((snap) => snap.size),
          ]).catchError((error) {
            print('Error in parallel queries: $error');
            // Return default values if queries fail
            return [0, 0, 0, 0, 0, 0];
          });

      if (mounted) {
        setState(() {
          _totalUsers = results[0];
          _activeUsers = results[1];
          _ownerUsers = results[2];
          _newUsersToday = results[3];
          _suspendedUsers = results[4];
          _adminUsers = results[5];
        });

        // Update notifiers
        _statsNotifiers['total']?.value = _totalUsers;
        _statsNotifiers['active']?.value = _activeUsers;
        _statsNotifiers['owners']?.value = _ownerUsers;
        _statsNotifiers['new']?.value = _newUsersToday;
        _statsNotifiers['suspended']?.value = _suspendedUsers;
        _statsNotifiers['admins']?.value = _adminUsers;
      }

      // Save to cache
      _cacheStats();
    } catch (e) {
      print('Error loading stats: $e');
      // Try to load from cache as fallback
      await _loadCachedStats();
    }
  }

  void _loadRecentSearches() {
    // Load from shared preferences or local storage
    // This is a placeholder for actual implementation
    _recentSearches = [];
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

      if (mounted) {
        setState(() {});
      }
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
    if (mounted) {
      setState(() => _loadingUsers.add(userId));
    }

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
    if (mounted) {
      setState(() => _loadingUsers.add(userId));
    }

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
    if (mounted) {
      setState(() => _loadingUsers.add(userId));
    }

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

    if (mounted) {
      setState(() {
        _loadingUsers.addAll(_selectedUsers);
      });
    }

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

    if (mounted) {
      setState(() {
        _loadingUsers.clear();
        _selectedUsers.clear();
        _isSelectionMode = false;
      });
    }

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
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _textScaleFactor = MediaQuery.of(context).textScaleFactor;
    _paddingScaleFactor = math.min(_screenWidth / 375, 1.3);

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
    final bool isSmallestPhone = width < 360;
    final bool isSmallPhone = width >= 360 && width < 400;
    final bool isMediumPhone = width >= 400 && width < 480;
    final bool isLargePhone = width >= 480 && width < 600;
    final bool isTablet = width >= 600 && width < 900;
    final bool isDesktop = width >= 900;
    final bool isLargeDesktop = width >= 1200;

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

    double horizontalPadding = _getResponsiveValue(
      base: 24,
      largePhone: 20,
      mediumPhone: 16,
      smallPhone: 14,
      smallestPhone: 12,
      tablet: 28,
      desktop: 32,
    );

    double verticalPadding = _getResponsiveValue(
      base: 20,
      largePhone: 18,
      mediumPhone: 16,
      smallPhone: 14,
      smallestPhone: 12,
      tablet: 24,
      desktop: 28,
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Header
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

          // Stats section
          SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _getResponsiveValue(
                  base: 180,
                  largePhone: 160,
                  mediumPhone: 150,
                  smallPhone: 140,
                  smallestPhone: 130,
                ),
              ),
              child: _buildStatsSection(
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
                isTablet: isTablet,
                isDesktop: isDesktop,
              ),
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

          // Search and filters
          SliverToBoxAdapter(
            child: _buildSearchAndFilters(
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
                base: 12,
                smallPhone: 10,
                smallestPhone: 8,
              ),
            ),
          ),

          // Action bar (when in selection mode)
          SliverToBoxAdapter(
            child: _buildActionBar(
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

          // Users content - now as sliver
          _buildUsersSliverContent(
            isSmallestPhone: isSmallestPhone,
            isSmallPhone: isSmallPhone,
            isMediumPhone: isMediumPhone,
            isLargePhone: isLargePhone,
            isTablet: isTablet,
            isDesktop: isDesktop,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildListItemsAsWidgets(
    List<DocumentSnapshot> docs, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
    return docs.asMap().entries.map((entry) {
      final index = entry.key;
      final doc = entry.value;

      return TweenAnimationBuilder<double>(
        key: ValueKey(doc.id),
        duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 1000)),
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
                child: _buildUserCard(
                  doc,
                  isSmallestPhone: isSmallestPhone,
                  isSmallPhone: isSmallPhone,
                  isMediumPhone: isMediumPhone,
                  isLargePhone: isLargePhone,
                  isTablet: isTablet,
                  isDesktop: isDesktop,
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildGridItemsAsWidgets(
    List<DocumentSnapshot> docs, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
    double spacing = _getResponsiveValue(
      base: 16,
      largePhone: 14,
      mediumPhone: 12,
      smallPhone: 10,
      smallestPhone: 8,
    );

    // Calculate grid layout manually
    List<Widget> gridItems = [];

    // Group items into rows based on cross axis count
    for (int i = 0; i < docs.length; i += _gridCrossAxisCount) {
      List<Widget> rowChildren = [];
      for (int j = 0; j < _gridCrossAxisCount; j++) {
        int index = i + j;
        if (index < docs.length) {
          final doc = docs[index];
          rowChildren.add(
            Expanded(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(doc.id),
                duration: Duration(
                  milliseconds: 300 + (index * 30).clamp(0, 1000),
                ),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.9 + (0.1 * value),
                      child: _buildUserGridCard(
                        doc,
                        isSmallestPhone: isSmallestPhone,
                        isSmallPhone: isSmallPhone,
                        isMediumPhone: isMediumPhone,
                        isLargePhone: isLargePhone,
                        isTablet: isTablet,
                        isDesktop: isDesktop,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          // Add empty placeholder to maintain grid structure
          rowChildren.add(const Expanded(child: SizedBox()));
        }
      }

      // Add the row with spacing
      gridItems.add(
        Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowChildren,
          ),
        ),
      );
    }

    return gridItems;
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

    double titleSize = _getResponsiveFontSize(
      base: 32,
      largePhone: 28,
      mediumPhone: 26,
      smallPhone: 24,
      smallestPhone: 22,
      tablet: 30,
      desktop: 34,
    );

    double greetingSize = _getResponsiveFontSize(
      base: 12,
      smallPhone: 10,
      smallestPhone: 9,
    );

    double subtitleSize = _getResponsiveFontSize(
      base: 12,
      smallPhone: 10,
      smallestPhone: 9,
    );

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
            // Title with dynamic typography
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      fontSize: greetingSize,
                      color: Colors.deepPurple.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(
                    height: _getResponsiveValue(base: 2, smallestPhone: 1),
                  ),
                  Text(
                    "Users Management",
                    style: TextStyle(
                      fontSize: titleSize,
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
                      fontSize: subtitleSize,
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
                  isSmallestPhone: isSmallestPhone,
                  isSmallPhone: isSmallPhone,
                  isMediumPhone: isMediumPhone,
                  isLargePhone: isLargePhone,
                  iconSize: iconSize,
                  padding: padding,
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 8,
                    smallPhone: 6,
                    smallestPhone: 4,
                  ),
                ),
                _buildHeaderAction(
                  icon: Icons.download_rounded,
                  tooltip: 'Export data',
                  onPressed: _exportUserData,
                  color: Colors.green,
                  isSmallestPhone: isSmallestPhone,
                  isSmallPhone: isSmallPhone,
                  isMediumPhone: isMediumPhone,
                  isLargePhone: isLargePhone,
                  iconSize: iconSize,
                  padding: padding,
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 8,
                    smallPhone: 6,
                    smallestPhone: 4,
                  ),
                ),
                _buildHeaderAction(
                  icon: _isGridView
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  tooltip: _isGridView ? 'List view' : 'Grid view',
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  color: Colors.blue,
                  isSmallestPhone: isSmallestPhone,
                  isSmallPhone: isSmallPhone,
                  isMediumPhone: isMediumPhone,
                  isLargePhone: isLargePhone,
                  iconSize: iconSize,
                  padding: padding,
                ),
                SizedBox(
                  width: _getResponsiveValue(
                    base: 8,
                    smallPhone: 6,
                    smallestPhone: 4,
                  ),
                ),
                _buildHeaderAction(
                  icon: Icons.refresh_rounded,
                  tooltip: 'Refresh data',
                  onPressed: _refreshData,
                  color: Colors.orange,
                  isSmallestPhone: isSmallestPhone,
                  isSmallPhone: isSmallPhone,
                  isMediumPhone: isMediumPhone,
                  isLargePhone: isLargePhone,
                  showLoader: _isRefreshing,
                  iconSize: iconSize,
                  padding: padding,
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
    required double iconSize, // Now using passed parameter
    required double padding, // Now using passed parameter
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
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
                _getResponsiveValue(
                  base: 12, // Same as first version
                  smallPhone: 10, // Same as first version
                  smallestPhone: 8, // Same as first version
                ),
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
                    base: 12, // Same as first version
                    smallPhone: 10, // Same as first version
                    smallestPhone: 8, // Same as first version
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.all(padding), // Using passed padding
                  child: showLoader
                      ? SizedBox(
                          width: iconSize * 0.8,
                          height: iconSize * 0.8,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      : Icon(
                          icon,
                          color: color,
                          size: iconSize,
                        ), // Using passed iconSize
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
    // Recalculate users on every build to ensure it's up to date
    final usersNotifier = ValueNotifier<int>(_calculateRegularUsers());

    // Safely get notifiers with fallbacks
    final totalNotifier = _statsNotifiers['total'] ?? ValueNotifier<int>(0);
    final activeNotifier = _statsNotifiers['active'] ?? ValueNotifier<int>(0);
    final ownersNotifier = _statsNotifiers['owners'] ?? ValueNotifier<int>(0);
    final newNotifier = _statsNotifiers['new'] ?? ValueNotifier<int>(0);
    final suspendedNotifier =
        _statsNotifiers['suspended'] ?? ValueNotifier<int>(0);
    final adminsNotifier = _statsNotifiers['admins'] ?? ValueNotifier<int>(0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildCompactStatCard(
            "Total",
            totalNotifier,
            Colors.deepPurple,
            Icons.people_rounded,
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
          _buildCompactStatCard(
            "Active",
            activeNotifier,
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
          _buildCompactStatCard(
            "Users",
            usersNotifier, // Use the recalculated notifier
            Colors.blue,
            Icons.person_rounded,
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
          _buildCompactStatCard(
            "Owners",
            ownersNotifier,
            Colors.orange,
            Icons.store_rounded,
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
          _buildCompactStatCard(
            "New",
            newNotifier,
            Colors.teal,
            Icons.today_rounded,
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
          _buildCompactStatCard(
            "Suspended",
            suspendedNotifier,
            Colors.red,
            Icons.pause_circle_rounded,
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
          _buildCompactStatCard(
            "Admins",
            adminsNotifier,
            Colors.purple,
            Icons.admin_panel_settings_rounded,
            isSmallestPhone: isSmallestPhone,
            isSmallPhone: isSmallPhone,
            isMediumPhone: isMediumPhone,
            isLargePhone: isLargePhone,
          ),
        ],
      ),
    );
  }

  // Add this helper method to calculate regular users count
  int _calculateRegularUsers() {
    return _totalUsers - (_ownerUsers + _adminUsers);
  }

  Widget _buildCompactStatCard(
    String label,
    ValueNotifier<int> countNotifier,
    Color color,
    IconData icon, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    // Responsive sizing based on screen size
    double cardWidth = _getResponsiveValue(
      base: 95,
      largePhone: 90,
      mediumPhone: 85,
      smallPhone: 80,
      smallestPhone: 75,
    );

    double iconSize = _getResponsiveValue(
      base: 22,
      largePhone: 20,
      mediumPhone: 18,
      smallPhone: 16,
      smallestPhone: 14,
    );

    double iconContainerSize = _getResponsiveValue(
      base: 36,
      largePhone: 34,
      mediumPhone: 32,
      smallPhone: 30,
      smallestPhone: 28,
    );

    double fontSize = _getResponsiveFontSize(
      base: 16,
      largePhone: 15,
      mediumPhone: 14,
      smallPhone: 13,
      smallestPhone: 12,
    );

    double labelSize = _getResponsiveFontSize(
      base: 10,
      largePhone: 9.5,
      mediumPhone: 9,
      smallPhone: 8.5,
      smallestPhone: 8,
    );

    double borderRadius = _getResponsiveValue(
      base: 14,
      largePhone: 12,
      mediumPhone: 10,
      smallPhone: 8,
      smallestPhone: 6,
    );

    double padding = _getResponsiveValue(
      base: 8,
      largePhone: 7,
      mediumPhone: 6,
      smallPhone: 5,
      smallestPhone: 4,
    );

    // Use a simple ValueListenableBuilder without animation for immediate display
    return ValueListenableBuilder<int>(
      valueListenable: countNotifier,
      builder: (context, count, _) {
        return Container(
          width: cardWidth,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, color.withOpacity(0.03)],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: color.withOpacity(0.15), width: 1),
          ),
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: iconContainerSize,
                  height: iconContainerSize,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                ),

                SizedBox(height: padding),

                // Count - show immediately without animation
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),

                // Label
                Text(
                  label,
                  style: TextStyle(
                    fontSize: labelSize,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadCachedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final total = prefs.getInt('total_users') ?? 0;
      final active = prefs.getInt('active_users') ?? 0;
      final owners = prefs.getInt('owner_users') ?? 0;
      final newToday = prefs.getInt('new_users') ?? 0;
      final suspended = prefs.getInt('suspended_users') ?? 0;
      final admins = prefs.getInt('admin_users') ?? 0;

      // Only update if values are different and valid
      if (total != _totalUsers ||
          active != _activeUsers ||
          owners != _ownerUsers ||
          newToday != _newUsersToday ||
          suspended != _suspendedUsers ||
          admins != _adminUsers) {
        setState(() {
          _totalUsers = total;
          _activeUsers = active;
          _ownerUsers = owners;
          _newUsersToday = newToday;
          _suspendedUsers = suspended;
          _adminUsers = admins;
        });

        // Update notifiers
        _statsNotifiers['total']?.value = _totalUsers;
        _statsNotifiers['active']?.value = _activeUsers;
        _statsNotifiers['owners']?.value = _ownerUsers;
        _statsNotifiers['new']?.value = _newUsersToday;
        _statsNotifiers['suspended']?.value = _suspendedUsers;
        _statsNotifiers['admins']?.value = _adminUsers;
      }
    } catch (e) {
      print('Error loading cached stats: $e');
      // Fallback to default values
      _initializeStatsWithDefaultValues();
    }
  }

  Future<void> _cacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('total_users', _totalUsers);
      await prefs.setInt('active_users', _activeUsers);
      await prefs.setInt('owner_users', _ownerUsers);
      await prefs.setInt('new_users', _newUsersToday);
      await prefs.setInt('suspended_users', _suspendedUsers);
      await prefs.setInt('admin_users', _adminUsers);
    } catch (e) {
      print('Error caching stats: $e');
    }
  }

  Widget _buildSearchAndFilters({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
    double padding = _getResponsiveValue(
      base: 20,
      largePhone: 18,
      mediumPhone: 16,
      smallPhone: 14,
      smallestPhone: 12,
    );

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  _getResponsiveValue(
                    base: 24,
                    smallPhone: 20,
                    smallestPhone: 18,
                  ),
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
                    },
                    data: _allDocs,
                    searchResultsNotifier: _aiSearchResults,
                    hintText:
                        'AI Search: Find by name, email, phone, or role...',
                    autoFocus: false,
                    showSuggestions: true,
                    showFilters:
                        false, // Disable built-in filters to use custom ones
                    showHistory: true,
                    enableVoice: false,
                    enableLearning: true,
                    maxSuggestions: 8,
                    maxHistoryItems: 20,
                    debounceDuration: const Duration(milliseconds: 300),
                    accentColor: Colors.deepPurple,
                    searchFields: const [
                      'displayName',
                      'email',
                      'phone',
                      'phoneNumber',
                      'role',
                      'userId',
                    ],
                    fieldWeights: const {
                      'displayName': 2.5,
                      'email': 2.0,
                      'phone': 1.8,
                      'phoneNumber': 1.8,
                      'role': 1.5,
                      'userId': 1.2,
                    },
                    fuzzyThreshold: 0.4,
                    customActions: [
                      // You can add custom icons here if needed
                    ],
                  ),

                  SizedBox(
                    height: _getResponsiveValue(
                      base: 12,
                      smallPhone: 10,
                      smallestPhone: 8,
                    ),
                  ),

                  // Custom filter chips (preserved)
                  _buildFilterChips(
                    isSmallestPhone: isSmallestPhone,
                    isSmallPhone: isSmallPhone,
                    isMediumPhone: isMediumPhone,
                    isLargePhone: isLargePhone,
                  ),

                  SizedBox(
                    height: _getResponsiveValue(
                      base: 8,
                      smallPhone: 6,
                      smallestPhone: 4,
                    ),
                  ),

                  // Advanced filters toggle
                  _buildAdvancedFiltersToggle(
                    isSmallestPhone: isSmallestPhone,
                    isSmallPhone: isSmallPhone,
                    isMediumPhone: isMediumPhone,
                  ),

                  if (_showAdvancedFilters)
                    _buildAdvancedFilters(
                      isSmallestPhone: isSmallestPhone,
                      isSmallPhone: isSmallPhone,
                      isMediumPhone: isMediumPhone,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersSliverContent({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
    return ValueListenableBuilder<List<DocumentSnapshot>>(
      valueListenable: _aiSearchResults,
      builder: (context, searchResults, child) {
        // Use search results if available, otherwise use all docs with filters
        final docs = searchResults.isNotEmpty
            ? searchResults
            : _filterDocs(_allDocs);

        // SHOW DATA IMMEDIATELY - don't show shimmer on first load
        if (docs.isEmpty && !_isFirstLoad) {
          return SliverFillRemaining(
            child: _buildEmptyState(
              isSmallestPhone: isSmallestPhone,
              isSmallPhone: isSmallPhone,
              isMediumPhone: isMediumPhone,
              isLargePhone: isLargePhone,
              search: _searchQuery.isNotEmpty || searchResults.isNotEmpty,
            ),
          );
        }

        if (_isSelectionMode) {
          // Build the list of widgets for selection mode
          List<Widget> children = [
            // Select all header
            _buildSelectAllHeader(
              docs,
              isSmallestPhone: isSmallestPhone,
              isSmallPhone: isSmallPhone,
              isMediumPhone: isMediumPhone,
              isLargePhone: isLargePhone,
            ),
            // Spacing
            SizedBox(
              height: _getResponsiveValue(
                base: 12,
                smallPhone: 10,
                smallestPhone: 8,
              ),
            ),
          ];

          // Add the grid or list items
          if (_isGridView) {
            children.addAll(
              _buildGridItemsAsWidgets(
                docs,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
                isTablet: isTablet,
                isDesktop: isDesktop,
              ),
            );
          } else {
            children.addAll(
              _buildListItemsAsWidgets(
                docs,
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
                isLargePhone: isLargePhone,
                isTablet: isTablet,
                isDesktop: isDesktop,
              ),
            );
          }

          // Add loading indicator if needed (only when not searching)
          if (_hasMoreData && searchResults.isEmpty) {
            children.add(
              _buildLoadingMoreIndicator(
                isSmallestPhone: isSmallestPhone,
                isSmallPhone: isSmallPhone,
                isMediumPhone: isMediumPhone,
              ),
            );
          }

          return SliverList(delegate: SliverChildListDelegate(children));
        }

        // Non-selection mode
        List<Widget> children = [];

        // Add the grid or list items
        if (_isGridView) {
          children.addAll(
            _buildGridItemsAsWidgets(
              docs,
              isSmallestPhone: isSmallestPhone,
              isSmallPhone: isSmallPhone,
              isMediumPhone: isMediumPhone,
              isLargePhone: isLargePhone,
              isTablet: isTablet,
              isDesktop: isDesktop,
            ),
          );
        } else {
          children.addAll(
            _buildListItemsAsWidgets(
              docs,
              isSmallestPhone: isSmallestPhone,
              isSmallPhone: isSmallPhone,
              isMediumPhone: isMediumPhone,
              isLargePhone: isLargePhone,
              isTablet: isTablet,
              isDesktop: isDesktop,
            ),
          );
        }

        // Add loading indicator if needed (only when not searching)
        if (_hasMoreData && searchResults.isEmpty) {
          children.add(
            _buildLoadingMoreIndicator(
              isSmallestPhone: isSmallestPhone,
              isSmallPhone: isSmallPhone,
              isMediumPhone: isMediumPhone,
            ),
          );
        }

        return SliverList(delegate: SliverChildListDelegate(children));
      },
    );
  }

  // Also update the _filterDocs method to work with the search:

  List<DocumentSnapshot> _filterDocs(List<DocumentSnapshot> docs) {
    List<DocumentSnapshot> filtered = List.from(docs);

    // Apply role filter (this works in addition to AI search)
    if (_selectedRoleFilter != 'all') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'] == _selectedRoleFilter;
      }).toList();
    }

    // Apply status filter (this works in addition to AI search)
    if (_selectedStatusFilter != 'all') {
      final isActive = _selectedStatusFilter == 'active';
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['isActive'] == isActive;
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

  Widget _buildFilterChips({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    double fontSize = _getResponsiveFontSize(
      base: 12,
      largePhone: 11.5,
      mediumPhone: 11,
      smallPhone: 10.5,
      smallestPhone: 10,
    );

    double padding = _getResponsiveValue(
      base: 8,
      largePhone: 7,
      mediumPhone: 6,
      smallPhone: 5,
      smallestPhone: 4,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
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
            fontSize: fontSize,
            padding: padding,
          ),
          Container(
            width: 1,
            height: _getResponsiveValue(
              base: 30,
              smallPhone: 25,
              smallestPhone: 20,
            ),
            margin: EdgeInsets.symmetric(horizontal: padding * 1.5),
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
            fontSize: fontSize,
            padding: padding,
          ),
          Container(
            width: 1,
            height: _getResponsiveValue(
              base: 30,
              smallPhone: 25,
              smallestPhone: 20,
            ),
            margin: EdgeInsets.symmetric(horizontal: padding * 1.5),
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
            fontSize: fontSize,
            padding: padding,
          ),
          SizedBox(width: padding),
          IconButton(
            icon: Icon(
              _sortAscending
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: fontSize * 1.5,
              color: Colors.deepPurple,
            ),
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            tooltip: _sortAscending ? 'Ascending' : 'Descending',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: fontSize * 2,
              minHeight: fontSize * 2,
            ),
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
    required double fontSize,
    required double padding,
    Color color = Colors.deepPurple,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with modern styling
        Padding(
          padding: EdgeInsets.only(left: padding * 0.5, bottom: padding),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize * 0.9,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Filter chips in a wrap for better responsiveness
        Wrap(
          spacing: padding,
          runSpacing: padding,
          children: options.map((option) {
            final isSelected = selectedValue == option['value'];
            final optionColor = _getOptionColor(option['value'] ?? '', color);

            return InkWell(
              onTap: () => onSelected(option['value']!),
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: EdgeInsets.symmetric(
                  horizontal: padding * 2,
                  vertical: padding,
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
                        padding: EdgeInsets.only(right: padding * 0.75),
                        child: Icon(
                          _getOptionIcon(option['value'] ?? ''),
                          size: fontSize,
                          color: isSelected
                              ? optionColor
                              : Colors.grey.shade500,
                        ),
                      ),

                    // Label
                    Text(
                      option['label']!,
                      style: TextStyle(
                        fontSize: fontSize,
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

  Widget _buildAdvancedFiltersToggle({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
  }) {
    double fontSize = _getResponsiveFontSize(
      base: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    return GestureDetector(
      onTap: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: _getResponsiveValue(
            base: 8,
            smallPhone: 6,
            smallestPhone: 4,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _showAdvancedFilters
                  ? 'Hide advanced filters'
                  : 'Show advanced filters',
              style: TextStyle(
                fontSize: fontSize,
                color: Colors.deepPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              _showAdvancedFilters
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: fontSize * 1.3,
              color: Colors.deepPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedFilters({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
  }) {
    double fontSize = _getResponsiveFontSize(
      base: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double spacing = _getResponsiveValue(
      base: 16,
      smallPhone: 14,
      smallestPhone: 12,
    );

    return Container(
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 16, smallPhone: 14, smallestPhone: 12),
        ),
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
                  fontSize: fontSize,
                ),
              ),
              SizedBox(width: spacing * 0.75),
              Expanded(
                child: _buildAdvancedFilterField(
                  label: 'Max. join date',
                  hint: 'To',
                  icon: Icons.calendar_today_rounded,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(
                child: _buildAdvancedFilterField(
                  label: 'Min. orders',
                  hint: '0',
                  icon: Icons.shopping_bag_rounded,
                  keyboardType: TextInputType.number,
                  fontSize: fontSize,
                ),
              ),
              SizedBox(width: spacing * 0.75),
              Expanded(
                child: _buildAdvancedFilterField(
                  label: 'Min. spent',
                  hint: '\$0',
                  icon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  // Clear advanced filters
                },
                child: Text('Clear all', style: TextStyle(fontSize: fontSize)),
              ),
              SizedBox(width: spacing * 0.5),
              ElevatedButton(
                onPressed: () {
                  // Apply advanced filters
                  setState(() => _showAdvancedFilters = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      _getResponsiveValue(
                        base: 12,
                        smallPhone: 10,
                        smallestPhone: 8,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing,
                    vertical: spacing * 0.5,
                  ),
                ),
                child: Text(
                  'Apply filters',
                  style: TextStyle(fontSize: fontSize),
                ),
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
    required double fontSize,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize * 0.9,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: fontSize * 0.4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
            ),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              SizedBox(width: fontSize),
              Icon(icon, size: fontSize * 1.2, color: Colors.grey.shade400),
              SizedBox(width: fontSize * 0.7),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: fontSize,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  style: TextStyle(fontSize: fontSize),
                  keyboardType: keyboardType,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar({
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
  }) {
    if (!_isSelectionMode || _selectedUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    double fontSize = _getResponsiveFontSize(
      base: 14,
      largePhone: 13,
      mediumPhone: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double iconSize = _getResponsiveValue(
      base: 16,
      largePhone: 15,
      mediumPhone: 14,
      smallPhone: 13,
      smallestPhone: 12,
    );

    double padding = _getResponsiveValue(
      base: 20,
      largePhone: 18,
      mediumPhone: 16,
      smallPhone: 14,
      smallestPhone: 12,
    );

    double verticalPadding = _getResponsiveValue(
      base: 16,
      largePhone: 14,
      mediumPhone: 12,
      smallPhone: 10,
      smallestPhone: 8,
    );

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.deepPurple, Colors.purple],
              ),
              borderRadius: BorderRadius.circular(
                _getResponsiveValue(
                  base: 20,
                  smallPhone: 18,
                  smallestPhone: 16,
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
                // Selection count with animation
                TweenAnimationBuilder<int>(
                  duration: const Duration(milliseconds: 200),
                  tween: IntTween(begin: 0, end: _selectedUsers.length),
                  builder: (context, count, child) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: padding * 0.6,
                        vertical: padding * 0.3,
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
                SizedBox(width: padding * 0.8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
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
                          fontSize: fontSize,
                          iconSize: iconSize,
                          padding: padding * 0.4,
                        ),
                        SizedBox(width: padding * 0.4),
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
                          fontSize: fontSize,
                          iconSize: iconSize,
                          padding: padding * 0.4,
                        ),
                        SizedBox(width: padding * 0.4),
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
                          fontSize: fontSize,
                          iconSize: iconSize,
                          padding: padding * 0.4,
                        ),
                        SizedBox(width: padding * 0.4),
                        _buildActionChip(
                          label: "Clear selection",
                          icon: Icons.clear_rounded,
                          color: Colors.white,
                          onPressed: _toggleSelectionMode,
                          fontSize: fontSize,
                          iconSize: iconSize,
                          padding: padding * 0.4,
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

  Widget _buildSelectAllHeader(
    List<DocumentSnapshot> docs, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
  }) {
    double fontSize = _getResponsiveFontSize(
      base: 15,
      largePhone: 14,
      mediumPhone: 13,
      smallPhone: 12,
      smallestPhone: 11,
    );

    double padding = _getResponsiveValue(
      base: 16,
      largePhone: 14,
      mediumPhone: 12,
      smallPhone: 10,
      smallestPhone: 8,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.75,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 16, smallPhone: 14, smallestPhone: 12),
        ),
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
              width: fontSize * 1.6,
              height: fontSize * 1.6,
              decoration: BoxDecoration(
                color: _selectedUsers.length == docs.length
                    ? Colors.deepPurple
                    : Colors.white,
                borderRadius: BorderRadius.circular(
                  _getResponsiveValue(base: 8, smallPhone: 7, smallestPhone: 6),
                ),
                border: Border.all(
                  color: _selectedUsers.length == docs.length
                      ? Colors.deepPurple
                      : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: _selectedUsers.length == docs.length
                  ? Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: fontSize,
                    )
                  : null,
            ),
          ),
          SizedBox(width: padding * 0.75),
          Text(
            'Select All',
            style: TextStyle(
              fontSize: fontSize,
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
                padding: EdgeInsets.symmetric(
                  horizontal: padding * 0.6,
                  vertical: padding * 0.25,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                    _getResponsiveValue(
                      base: 20,
                      smallPhone: 18,
                      smallestPhone: 16,
                    ),
                  ),
                ),
                child: Text(
                  '$count selected',
                  style: TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: fontSize * 0.85,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    DocumentSnapshot doc, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
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
      base: 14,
      largePhone: 13,
      mediumPhone: 12,
      smallPhone: 11,
      smallestPhone: 10,
    );

    double avatarSize = _getResponsiveValue(
      base: 60,
      largePhone: 55,
      mediumPhone: 50,
      smallPhone: 45,
      smallestPhone: 40,
    );

    double padding = _getResponsiveValue(
      base: 20,
      largePhone: 18,
      mediumPhone: 16,
      smallPhone: 14,
      smallestPhone: 12,
    );

    double spacing = _getResponsiveValue(
      base: 16,
      largePhone: 14,
      mediumPhone: 12,
      smallPhone: 10,
      smallestPhone: 8,
    );

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
        margin: EdgeInsets.only(bottom: spacing),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 24, smallPhone: 20, smallestPhone: 18),
          ),
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
                padding: EdgeInsets.all(padding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selection checkbox
                    if (_isSelectionMode)
                      Padding(
                        padding: EdgeInsets.only(right: spacing * 0.75),
                        child: _buildCheckbox(isSelected, userId),
                      ),

                    // Avatar with loading state
                    _buildAvatarWithLoading(
                      userId: userId,
                      displayName: displayName,
                      photoURL: photoURL,
                      role: role,
                      isLoading: isLoading,
                      size: avatarSize,
                    ),

                    SizedBox(width: spacing),

                    // User details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Name and badges row
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: spacing * 0.25,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.black87
                                      : Colors.grey,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              _buildRoleBadge(
                                role,
                                small: true,
                                fontSize: smallTextSize,
                                iconSize: iconSize * 0.8,
                              ),
                              _buildStatusBadge(
                                isActive,
                                small: true,
                                fontSize: smallTextSize,
                                iconSize: iconSize * 0.8,
                              ),
                            ],
                          ),

                          SizedBox(height: spacing * 0.4),

                          // Email
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: iconSize,
                                color: Colors.grey.shade500,
                              ),
                              SizedBox(width: spacing * 0.4),
                              Flexible(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: normalTextSize,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: spacing * 0.25),

                          // Phone
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: iconSize,
                                color: Colors.grey.shade500,
                              ),
                              SizedBox(width: spacing * 0.4),
                              Flexible(
                                child: Text(
                                  phoneNumber,
                                  style: TextStyle(
                                    fontSize: normalTextSize,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: spacing * 0.5),

                          // Timestamps
                          Wrap(
                            spacing: spacing * 0.5,
                            runSpacing: spacing * 0.25,
                            children: [
                              _buildTimestampChip(
                                icon: Icons.access_time_rounded,
                                label: _formatTimestamp(createdAt),
                                color: Colors.blue,
                                fontSize: smallTextSize,
                                iconSize: iconSize * 0.8,
                              ),
                              if (lastLogin != null)
                                _buildTimestampChip(
                                  icon: Icons.login_rounded,
                                  label: 'Last: ${_formatTimestamp(lastLogin)}',
                                  color: Colors.green,
                                  fontSize: smallTextSize,
                                  iconSize: iconSize * 0.8,
                                ),
                            ],
                          ),

                          if (isExpanded)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: _getResponsiveValue(
                                  base: 200,
                                  largePhone: 180,
                                  mediumPhone: 160,
                                  smallPhone: 140,
                                  smallestPhone: 120,
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: _buildExpandedDetails(
                                  data,
                                  fontSize: smallTextSize,
                                  iconSize: iconSize,
                                  spacing: spacing * 0.5,
                                ),
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
                        iconSize: iconSize,
                        spacing: spacing * 0.25,
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
                    padding: EdgeInsets.symmetric(vertical: spacing * 0.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(
                          _getResponsiveValue(
                            base: 24,
                            smallPhone: 20,
                            smallestPhone: 18,
                          ),
                        ),
                        bottomRight: Radius.circular(
                          _getResponsiveValue(
                            base: 24,
                            smallPhone: 20,
                            smallestPhone: 18,
                          ),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isExpanded ? 'Show less' : 'Show more',
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
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserGridCard(
    DocumentSnapshot doc, {
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool isTablet,
    required bool isDesktop,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = doc.id;
    final isLoading = _loadingUsers.contains(userId);
    final isSelected = _selectedUsers.contains(userId);
    final isActive = data['isActive'] ?? true;
    final role = data['role'] ?? 'user';
    final email = data['email'] ?? 'No email';
    final displayName = data['displayName'] ?? email.split('@')[0];
    final photoURL = data['photoURL'];

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

    double iconSize = _getResponsiveValue(
      base: 16,
      largePhone: 15,
      mediumPhone: 14,
      smallPhone: 13,
      smallestPhone: 12,
    );

    double avatarSize = _getResponsiveValue(
      base: 70,
      largePhone: 65,
      mediumPhone: 60,
      smallPhone: 55,
      smallestPhone: 50,
    );

    double padding = _getResponsiveValue(
      base: 20,
      largePhone: 18,
      mediumPhone: 16,
      smallPhone: 14,
      smallestPhone: 12,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 24, smallPhone: 20, smallestPhone: 18),
        ),
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
              top: padding * 0.6,
              right: padding * 0.6,
              child: _buildCheckbox(isSelected, userId),
            ),

          Padding(
            padding: EdgeInsets.all(padding),
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
                  size: avatarSize,
                ),

                SizedBox(height: padding * 0.6),

                // Name
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.black87 : Colors.grey,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: padding * 0.2),

                // Email
                Text(
                  email,
                  style: TextStyle(
                    fontSize: textSize,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: padding * 0.4),

                // Role and status badges
                Wrap(
                  spacing: padding * 0.3,
                  children: [
                    _buildRoleBadge(
                      role,
                      small: true,
                      fontSize: textSize * 0.9,
                      iconSize: iconSize * 0.8,
                    ),
                    _buildStatusBadge(
                      isActive,
                      small: true,
                      fontSize: textSize * 0.9,
                      iconSize: iconSize * 0.8,
                    ),
                  ],
                ),

                SizedBox(height: padding * 0.6),

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
                        iconSize: iconSize,
                      ),
                      _buildGridActionButton(
                        icon: Icons.swap_horiz_rounded,
                        color: Colors.blue,
                        onPressed: () => _showRoleDialog(userId, role),
                        tooltip: 'Change Role',
                        isLoading: false,
                        iconSize: iconSize,
                      ),
                      _buildGridActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red,
                        onPressed: () => _deleteUser(userId, email),
                        tooltip: 'Delete User',
                        isLoading: false,
                        iconSize: iconSize,
                      ),
                    ],
                  ),

                if (isLoading && !_isSelectionMode)
                  Padding(
                    padding: EdgeInsets.only(top: padding * 0.4),
                    child: const LinearProgressIndicator(
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
        width: _getResponsiveValue(base: 24, smallPhone: 22, smallestPhone: 20),
        height: _getResponsiveValue(
          base: 24,
          smallPhone: 22,
          smallestPhone: 20,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.white,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 8, smallPhone: 7, smallestPhone: 6),
          ),
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
            ? Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: _getResponsiveValue(
                  base: 16,
                  smallPhone: 14,
                  smallestPhone: 12,
                ),
              )
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
    bool isLoading, {
    required double iconSize,
    required double spacing,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick action buttons
        _buildQuickActionButton(
          icon: isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: isActive ? Colors.orange : Colors.green,
          onPressed: () => _toggleUserStatus(userId, isActive),
          tooltip: isActive ? 'Suspend' : 'Activate',
          iconSize: iconSize,
        ),
        SizedBox(width: spacing),

        // Menu button
        Container(
          width: iconSize * 2.5,
          height: iconSize * 2.5,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(
              _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
            ),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: iconSize),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                _getResponsiveValue(
                  base: 16,
                  smallPhone: 14,
                  smallestPhone: 12,
                ),
              ),
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
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Text(
                        'Activate',
                        style: TextStyle(fontSize: iconSize * 0.9),
                      ),
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
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Text(
                        'Suspend',
                        style: TextStyle(fontSize: iconSize * 0.9),
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              if (role != 'user')
                PopupMenuItem(
                  value: 'make_user',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        color: Colors.blue,
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Text(
                        'Make User',
                        style: TextStyle(fontSize: iconSize * 0.9),
                      ),
                    ],
                  ),
                ),
              if (role != 'owner')
                PopupMenuItem(
                  value: 'make_owner',
                  child: Row(
                    children: [
                      Icon(
                        Icons.store_rounded,
                        color: Colors.orange,
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Text(
                        'Make Owner',
                        style: TextStyle(fontSize: iconSize * 0.9),
                      ),
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
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Text(
                        'Make Admin',
                        style: TextStyle(fontSize: iconSize * 0.9),
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_rounded,
                      color: Colors.blue,
                      size: iconSize,
                    ),
                    SizedBox(width: spacing),
                    Text(
                      'View Details',
                      style: TextStyle(fontSize: iconSize * 0.9),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_rounded,
                      color: Colors.red,
                      size: iconSize,
                    ),
                    SizedBox(width: spacing),
                    Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: iconSize * 0.9,
                        color: Colors.red,
                      ),
                    ),
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
    required double iconSize,
  }) {
    return Container(
      width: iconSize * 2.5,
      height: iconSize * 2.5,
      margin: EdgeInsets.only(right: iconSize * 0.25),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
          ),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
              ),
            ),
            child: Icon(icon, color: color, size: iconSize),
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
    required double iconSize,
  }) {
    return Container(
      width: iconSize * 2.2,
      height: iconSize * 2.2,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
        ),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
          ),
          splashColor: color.withOpacity(0.2),
          highlightColor: color.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
              ),
            ),
            child: isLoading
                ? SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(
    String role, {
    required bool small,
    required double fontSize,
    required double iconSize,
  }) {
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

    double horizontalPadding = small ? fontSize * 0.8 : fontSize;
    double verticalPadding = small ? fontSize * 0.3 : fontSize * 0.4;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(width: fontSize * 0.2),
          Text(
            small ? (role.isNotEmpty ? role[0].toUpperCase() : 'U') : label,
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

  Widget _buildStatusBadge(
    bool isActive, {
    required bool small,
    required double fontSize,
    required double iconSize,
  }) {
    final color = isActive ? Colors.green : Colors.red;
    final icon = isActive
        ? Icons.check_circle_rounded
        : Icons.pause_circle_rounded;
    final label = isActive ? 'Active' : 'Suspended';

    double horizontalPadding = small ? fontSize * 0.8 : fontSize;
    double verticalPadding = small ? fontSize * 0.3 : fontSize * 0.4;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(width: fontSize * 0.2),
          Text(
            small ? (isActive ? 'A' : 'S') : label,
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

  Widget _buildTimestampChip({
    required IconData icon,
    required String label,
    required Color color,
    required double fontSize,
    required double iconSize,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.6,
        vertical: fontSize * 0.2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: fontSize * 0.2),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails(
    Map<String, dynamic> data, {
    required double fontSize,
    required double iconSize,
    required double spacing,
  }) {
    return Container(
      margin: EdgeInsets.only(top: spacing),
      padding: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 16, smallPhone: 14, smallestPhone: 12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildDetailStat(
                  label: 'Orders',
                  value: (data['orderCount'] ?? 0).toString(),
                  icon: Icons.shopping_bag_rounded,
                  color: Colors.blue,
                  fontSize: fontSize,
                  iconSize: iconSize,
                ),
                SizedBox(width: spacing),
                _buildDetailStat(
                  label: 'Spent',
                  value: '₹${(data['totalSpent'] ?? 0).toStringAsFixed(2)}',
                  icon: Icons.currency_rupee_rounded,
                  color: Colors.green,
                  fontSize: fontSize,
                  iconSize: iconSize,
                ),
                SizedBox(width: spacing),
                _buildDetailStat(
                  label: 'Reviews',
                  value: (data['reviewCount'] ?? 0).toString(),
                  icon: Icons.star_rounded,
                  color: Colors.orange,
                  fontSize: fontSize,
                  iconSize: iconSize,
                ),
              ],
            ),
          ),

          SizedBox(height: spacing),

          // Metadata
          Wrap(
            spacing: spacing * 0.5,
            runSpacing: spacing * 0.5,
            children: [
              if (data['userId'] != null)
                _buildMetadataChip(
                  label: 'ID: ${data['userId']}',
                  icon: Icons.fingerprint_rounded,
                  fontSize: fontSize * 0.9,
                  iconSize: iconSize * 0.8,
                ),
              if (data['deviceInfo'] != null)
                _buildMetadataChip(
                  label:
                      'Device: ${data['deviceInfo']['platform'] ?? 'Unknown'}',
                  icon: Icons.devices_rounded,
                  fontSize: fontSize * 0.9,
                  iconSize: iconSize * 0.8,
                ),
              if (data['appVersion'] != null)
                _buildMetadataChip(
                  label: 'App v${data['appVersion']}',
                  icon: Icons.info_rounded,
                  fontSize: fontSize * 0.9,
                  iconSize: iconSize * 0.8,
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
    required double fontSize,
    required double iconSize,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.7,
        vertical: fontSize * 0.3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 8, smallPhone: 7, smallestPhone: 6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(width: fontSize * 0.3),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize * 0.8,
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip({
    required String label,
    required IconData icon,
    required double fontSize,
    required double iconSize,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.8,
        vertical: fontSize * 0.3,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: Colors.grey.shade700),
          SizedBox(width: fontSize * 0.3),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============== HELPER METHODS ==============

  void _clearSearch() {
    _searchController.clear();
    if (mounted) {
      setState(() {
        _searchQuery = '';
      });
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() => _isRefreshing = true);
    }
    await _loadInitialUsers();
    await _loadStats();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
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
      if (mounted) {
        _showSuccessNotification('Exported ${snapshot.docs.length} users');
      }
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            _getResponsiveValue(base: 24, smallPhone: 20, smallestPhone: 18),
          ),
        ),
      ),
      builder: (context) {
        double fontSize = _getResponsiveFontSize(base: 20);
        double textSize = _getResponsiveFontSize(base: 14);
        double iconSize = _getResponsiveValue(base: 24);
        double padding = _getResponsiveValue(base: 20);

        return Container(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change User Role',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: padding),
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
                fontSize: textSize,
                iconSize: iconSize,
                padding: padding,
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
                fontSize: textSize,
                iconSize: iconSize,
                padding: padding,
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
                fontSize: textSize,
                iconSize: iconSize,
                padding: padding,
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
    required double fontSize,
    required double iconSize,
    required double padding,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(padding * 0.5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: iconSize),
      ),
      title: Text(
        role[0].toUpperCase() + role.substring(1),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(description, style: TextStyle(fontSize: fontSize * 0.9)),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: color, size: iconSize)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          _getResponsiveValue(base: 12, smallPhone: 10, smallestPhone: 8),
        ),
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
        if (mounted) {
          setState(() => _loadingUsers.remove(userId));
        }
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
    double fontSize = _getResponsiveFontSize(base: 14);
    double iconSize = _getResponsiveValue(base: 40);

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _getResponsiveValue(base: 24, smallPhone: 20, smallestPhone: 18),
          ),
        ),
        title: Column(
          children: [
            if (isDestructive)
              Container(
                padding: EdgeInsets.all(iconSize * 0.4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: iconSize,
                ),
              ),
            SizedBox(height: fontSize),
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize * 1.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: fontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700, fontSize: fontSize),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  _getResponsiveValue(
                    base: 12,
                    smallPhone: 10,
                    smallestPhone: 8,
                  ),
                ),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: fontSize * 1.5,
                vertical: fontSize * 0.8,
              ),
            ),
            child: Text(confirmText, style: TextStyle(fontSize: fontSize)),
          ),
        ],
      ),
    );
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
    required bool isSmallestPhone,
    required bool isSmallPhone,
    required bool isMediumPhone,
    required bool isLargePhone,
    required bool search,
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
        physics: const BouncingScrollPhysics(),
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
                        search
                            ? Icons.search_off_rounded
                            : Icons.people_outline_rounded,
                        size: iconSize,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: spacing),
              Text(
                search ? "No users found" : "No users yet",
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(height: spacing * 0.33),
              Text(
                search
                    ? "Try adjusting your search or filters"
                    : "Users will appear here once they register",
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
                      horizontal: spacing,
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

  // Responsive helpers
  late double _screenWidth;
  late double _textScaleFactor;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  double _getResponsiveValue({
    required double base,
    double? largePhone,
    double? mediumPhone,
    double? smallPhone,
    double? smallestPhone,
  }) {
    if (_screenWidth < 360 && smallestPhone != null) return smallestPhone;
    if (_screenWidth < 400 && smallPhone != null) return smallPhone;
    if (_screenWidth < 480 && mediumPhone != null) return mediumPhone;
    if (_screenWidth < 600 && largePhone != null) return largePhone;
    return base;
  }

  double _getResponsiveFontSize({required double base}) {
    double size = _getResponsiveValue(base: base);
    return size * _textScaleFactor.clamp(0.8, 1.2);
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
    _screenWidth = MediaQuery.of(context).size.width;
    _textScaleFactor = MediaQuery.of(context).textScaleFactor;

    double titleSize = _getResponsiveFontSize(base: 20);
    double headingSize = _getResponsiveFontSize(base: 16);
    double textSize = _getResponsiveFontSize(base: 13);
    double smallTextSize = _getResponsiveFontSize(base: 12);
    double iconSize = _getResponsiveValue(base: 20);
    double padding = _getResponsiveValue(base: 20);
    double avatarSize = _getResponsiveValue(base: 100);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_getResponsiveValue(base: 24)),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: padding * 0.5, bottom: padding * 0.4),
            width: _screenWidth * 0.15,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(padding),
            child: Row(
              children: [
                Text(
                  'User Details',
                  style: TextStyle(
                    fontSize: titleSize,
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

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorState(textSize: textSize, iconSize: iconSize)
                : _buildDetailsContent(
                    titleSize: titleSize,
                    headingSize: headingSize,
                    textSize: textSize,
                    smallTextSize: smallTextSize,
                    iconSize: iconSize,
                    padding: padding,
                    avatarSize: avatarSize,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState({
    required double textSize,
    required double iconSize,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: iconSize * 2,
            color: Colors.red.shade300,
          ),
          SizedBox(height: textSize),
          Text(
            _error!,
            style: TextStyle(color: Colors.grey.shade600, fontSize: textSize),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: textSize),
          ElevatedButton(
            onPressed: _loadUserDetails,
            child: Text('Try Again', style: TextStyle(fontSize: textSize)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent({
    required double titleSize,
    required double headingSize,
    required double textSize,
    required double smallTextSize,
    required double iconSize,
    required double padding,
    required double avatarSize,
  }) {
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
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          Center(
            child: Column(
              children: [
                // Avatar
                Container(
                  width: avatarSize,
                  height: avatarSize,
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: avatarSize * 0.4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: padding),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: padding * 0.2),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: textSize,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: padding * 0.4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDetailsBadge(
                      label: role.toUpperCase(),
                      color: _getRoleColor(role),
                      fontSize: smallTextSize,
                    ),
                    SizedBox(width: padding * 0.4),
                    _buildDetailsBadge(
                      label: isActive ? 'ACTIVE' : 'SUSPENDED',
                      color: isActive ? Colors.green : Colors.red,
                      fontSize: smallTextSize,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: padding * 1.2),

          // Contact information
          _buildDetailsSection(
            title: 'Contact Information',
            icon: Icons.contact_mail_rounded,
            children: [
              _buildInfoRow(
                icon: Icons.phone_rounded,
                label: 'Phone',
                value: phoneNumber,
                textSize: textSize,
                iconSize: iconSize,
              ),
              _buildInfoRow(
                icon: Icons.email_rounded,
                label: 'Email',
                value: email,
                textSize: textSize,
                iconSize: iconSize,
              ),
              if (_userData!['alternatePhone'] != null)
                _buildInfoRow(
                  icon: Icons.phone_android_rounded,
                  label: 'Alternate',
                  value: _userData!['alternatePhone'],
                  textSize: textSize,
                  iconSize: iconSize,
                ),
            ],
            iconSize: iconSize,
            headingSize: headingSize,
            padding: padding * 0.8,
            spacing: padding,
          ),

          SizedBox(height: padding),

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
                textSize: textSize,
                iconSize: iconSize,
              ),
              _buildInfoRow(
                icon: Icons.access_time_rounded,
                label: 'Joined',
                value: _formatFullDate(createdAt),
                textSize: textSize,
                iconSize: iconSize,
              ),
              if (lastLogin != null)
                _buildInfoRow(
                  icon: Icons.login_rounded,
                  label: 'Last Login',
                  value: _formatFullDate(lastLogin),
                  textSize: textSize,
                  iconSize: iconSize,
                ),
              _buildInfoRow(
                icon: Icons.update_rounded,
                label: 'Last Updated',
                value: _formatFullDate(_userData!['updatedAt'] as Timestamp?),
                textSize: textSize,
                iconSize: iconSize,
              ),
            ],
            iconSize: iconSize,
            headingSize: headingSize,
            padding: padding * 0.8,
            spacing: padding,
          ),

          SizedBox(height: padding),

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
                textSize: textSize,
                iconSize: iconSize,
              ),
              _buildStatRow(
                icon: Icons.currency_rupee_rounded,
                label: 'Total Spent',
                value: '₹${(_userData!['totalSpent'] ?? 0).toStringAsFixed(2)}',
                color: Colors.green,
                textSize: textSize,
                iconSize: iconSize,
              ),
              _buildStatRow(
                icon: Icons.star_rounded,
                label: 'Reviews',
                value: (_userData!['reviewCount'] ?? 0).toString(),
                color: Colors.orange,
                textSize: textSize,
                iconSize: iconSize,
              ),
              _buildStatRow(
                icon: Icons.store_rounded,
                label: 'Shops',
                value: _userShops.length.toString(),
                color: Colors.purple,
                textSize: textSize,
                iconSize: iconSize,
              ),
            ],
            iconSize: iconSize,
            headingSize: headingSize,
            padding: padding * 0.8,
            spacing: padding,
          ),

          SizedBox(height: padding),

          // Shops section
          if (_userShops.isNotEmpty)
            _buildDetailsSection(
              title: 'Shops (${_userShops.length})',
              icon: Icons.store_rounded,
              children: _userShops.map((shop) {
                final shopData = shop.data() as Map<String, dynamic>;
                return ListTile(
                  leading: Container(
                    width: iconSize * 2,
                    height: iconSize * 2,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        _getResponsiveValue(base: 8),
                      ),
                    ),
                    child: Icon(
                      Icons.store_rounded,
                      color: Colors.orange,
                      size: iconSize,
                    ),
                  ),
                  title: Text(
                    shopData['shopName'] ?? 'Unnamed Shop',
                    style: TextStyle(
                      fontSize: textSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Status: ${shopData['isActive'] == true ? 'Active' : 'Inactive'}',
                    style: TextStyle(
                      fontSize: smallTextSize,
                      color: shopData['isActive'] == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  trailing: Text(
                    '₹${(shopData['totalRevenue'] ?? 0).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: textSize,
                    ),
                  ),
                );
              }).toList(),
              iconSize: iconSize,
              headingSize: headingSize,
              padding: padding * 0.8,
              spacing: padding,
            ),

          SizedBox(height: padding),

          // Recent orders
          if (_userOrders.isNotEmpty)
            _buildDetailsSection(
              title: 'Recent Orders (${_userOrders.length})',
              icon: Icons.shopping_bag_rounded,
              children: _userOrders.map((order) {
                final orderData = order.data() as Map<String, dynamic>;
                return ListTile(
                  leading: Container(
                    width: iconSize * 2,
                    height: iconSize * 2,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        _getResponsiveValue(base: 8),
                      ),
                    ),
                    child: Icon(
                      Icons.receipt_rounded,
                      color: Colors.blue,
                      size: iconSize,
                    ),
                  ),
                  title: Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: TextStyle(
                      fontSize: textSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _formatFullDate(orderData['createdAt'] as Timestamp?),
                    style: TextStyle(
                      fontSize: smallTextSize,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Text(
                    '₹${(orderData['total'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: textSize,
                    ),
                  ),
                );
              }).toList(),
              iconSize: iconSize,
              headingSize: headingSize,
              padding: padding * 0.8,
              spacing: padding,
            ),

          SizedBox(height: padding),

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
                  textSize: textSize,
                  iconSize: iconSize,
                ),
                _buildInfoRow(
                  icon: Icons.info_rounded,
                  label: 'App Version',
                  value: _userData!['appVersion'] ?? 'Unknown',
                  textSize: textSize,
                  iconSize: iconSize,
                ),
              ],
              iconSize: iconSize,
              headingSize: headingSize,
              padding: padding * 0.8,
              spacing: padding,
            ),

          SizedBox(height: padding * 1.2),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onShowRoleDialog(widget.userId, role);
                  },
                  icon: Icon(Icons.swap_horiz_rounded, size: iconSize),
                  label: Text(
                    'Change Role',
                    style: TextStyle(fontSize: textSize),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: padding * 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        _getResponsiveValue(base: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: padding * 0.6),

          SizedBox(
            width: double.infinity,
            child: isActive
                ? OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onToggleStatus(widget.userId, isActive);
                    },
                    icon: Icon(Icons.pause_rounded, size: iconSize),
                    label: Text(
                      'Suspend User',
                      style: TextStyle(fontSize: textSize),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: EdgeInsets.symmetric(vertical: padding * 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _getResponsiveValue(base: 12),
                        ),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onToggleStatus(widget.userId, isActive);
                    },
                    icon: Icon(Icons.play_arrow_rounded, size: iconSize),
                    label: Text(
                      'Activate User',
                      style: TextStyle(fontSize: textSize),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: padding * 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _getResponsiveValue(base: 12),
                        ),
                      ),
                    ),
                  ),
          ),

          SizedBox(height: padding * 0.6),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onDelete(widget.userId, email);
              },
              icon: Icon(Icons.delete_rounded, size: iconSize),
              label: Text(
                'Delete User Permanently',
                style: TextStyle(fontSize: textSize),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: EdgeInsets.symmetric(vertical: padding * 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    _getResponsiveValue(base: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsBadge({
    required String label,
    required Color color,
    required double fontSize,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.8,
        vertical: fontSize * 0.3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(_getResponsiveValue(base: 20)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDetailsSection({
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
        borderRadius: BorderRadius.circular(_getResponsiveValue(base: 16)),
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required double textSize,
    required double iconSize,
    bool isMonospace = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: textSize * 0.6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: iconSize, color: Colors.grey.shade600),
          SizedBox(width: textSize),
          SizedBox(
            width: textSize * 6.5,
            child: Text(
              label,
              style: TextStyle(fontSize: textSize, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: textSize,
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
    required double textSize,
    required double iconSize,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: textSize * 0.6),
      padding: EdgeInsets.all(textSize),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(_getResponsiveValue(base: 12)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(textSize * 0.6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_getResponsiveValue(base: 8)),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          SizedBox(width: textSize),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: textSize, color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: textSize * 1.1,
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
