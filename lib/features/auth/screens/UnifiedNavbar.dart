// ignore_for_file: unused_field

import 'dart:async';
import 'dart:ui';
import 'package:bizora/Admin/screens/admin_home.dart';
import 'package:bizora/Admin/screens/admin_orders_page.dart';
import 'package:bizora/Admin/screens/admin_settings_page.dart';
import 'package:bizora/Admin/screens/admin_shops_page.dart';
import 'package:bizora/Admin/screens/admin_users_page.dart';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/screens/waiting_screen.dart';
import 'package:bizora/features/customer/screens/customer_home.dart';
import 'package:bizora/features/customer/screens/orders_page.dart';
import 'package:bizora/features/customer/screens/profile_page.dart';
import 'package:bizora/features/customer/screens/search_page.dart';
import 'package:bizora/features/customer/screens/wishlist_page.dart';
import 'package:bizora/features/owner/screens/owner_home.dart';
import 'package:bizora/features/owner/screens/owner_products.dart';
import 'package:bizora/features/owner/screens/owner_orders.dart';
import 'package:bizora/features/owner/screens/owner_analytics.dart';
import 'package:bizora/features/owner/screens/owner_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UnifiedNavbar extends StatefulWidget {
  const UnifiedNavbar({super.key});

  @override
  State<UnifiedNavbar> createState() => _UnifiedNavbarState();
}

class _UnifiedNavbarState extends State<UnifiedNavbar>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isAppBarExpanded = true;
  bool _isSearchVisible = false;

  // Add a loading state
  bool _isLoading = true;

  // Add a mode toggle - true for owner mode, false for customer mode
  bool _isOwnerMode = false;

  // User role states
  bool _isOwner = false;
  bool _hasAppliedForOwner = false;
  String _applicationStatus = ''; // 'pending', 'approved', 'rejected'
  String _userRole = ''; // For admin/owner/customer differentiation
  String? _shopName;
  String _userName = '';
  String _userPhotoUrl = '';

  late StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Animation controllers
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _pulseController;
  late final AnimationController _scaleController;
  late final AnimationController _glowController;
  late final AnimationController _searchController;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _searchAnimation;

  // Pages based on role and mode
  List<Widget> _pages = [];

  // Nav items based on role and mode
  List<NavItem> _navItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();

    // Initialize with default customer navigation first
    _initializeDefaultNavigation();

    // Then check actual user role
    _checkUserRole();
  }

  void _initializeDefaultNavigation() {
    // Set default customer navigation while loading
    _pages = [
      const CustomerHome(),
      const SearchPage(),
      const OrdersPage(),
      const WishlistPage(),
      const ProfilePage(),
    ];
    _navItems = [
      NavItem(
        Icons.home_rounded,
        Icons.home_outlined,
        "Home",
        const Color(0xFF3B82F6),
      ),
      NavItem(
        Icons.search_rounded,
        Icons.search_outlined,
        "Search",
        const Color(0xFF8B5CF6),
      ),
      NavItem(
        Icons.shopping_bag_rounded,
        Icons.shopping_bag_outlined,
        "Orders",
        const Color(0xFF10B981),
      ),
      NavItem(
        Icons.favorite_rounded,
        Icons.favorite_border,
        "Wishlist",
        const Color(0xFFEF4444),
      ),
      NavItem(
        Icons.person_rounded,
        Icons.person_outline,
        "Profile",
        const Color(0xFFF59E0B),
      ),
    ];
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _searchAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _searchController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;

          final role = data['role'] ?? 'customer';
          final isApproved = data['isApproved'] ?? false;
          final hasApplied = data['hasAppliedForOwner'] ?? false;
          final applicationStatus = data['applicationStatus'] ?? '';

          bool isActuallyOwner = false;

          // ADMIN CHECK
          if (role == 'admin') {
            setState(() {
              _userRole = 'admin';
              _isOwner = false;
              _hasAppliedForOwner = false;
              _applicationStatus = '';
              _userName = data['name'] ?? user.displayName ?? 'Admin';
              _userPhotoUrl = data['photoUrl'] ?? user.photoURL ?? '';
              _isOwnerMode = false;
              _initializeNavigation();
              _isLoading = false;
            });
          } else {
            // OWNER CHECK
            if (role == 'owner') {
              if (applicationStatus == 'approved' || isApproved == true) {
                isActuallyOwner = true;
              }
            }

            setState(() {
              _userRole = isActuallyOwner ? 'owner' : 'customer';
              _isOwner = isActuallyOwner;
              _hasAppliedForOwner = hasApplied || applicationStatus.isNotEmpty;
              _applicationStatus = applicationStatus.isEmpty
                  ? (hasApplied ? 'pending' : '')
                  : applicationStatus;
              _userName = data['name'] ?? user.displayName ?? 'User';
              _userPhotoUrl = data['photoUrl'] ?? user.photoURL ?? '';
              _isOwnerMode = false;
              _initializeNavigation();
              _isLoading = false;
            });

            if (_isOwner) {
              _loadShopData();
            }
          }

          print(
            'User status - Role: $_userRole | Owner: $_isOwner | Applied: $_hasAppliedForOwner | Status: $_applicationStatus',
          );
        } else {
          setState(() {
            _userRole = 'customer';
            _isOwner = false;
            _hasAppliedForOwner = false;
            _applicationStatus = '';
            _userName = user.displayName ?? 'User';
            _userPhotoUrl = user.photoURL ?? '';
            _isOwnerMode = false;
            _initializeNavigation();
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');

        setState(() {
          _userRole = 'customer';
          _isOwner = false;
          _hasAppliedForOwner = false;
          _applicationStatus = '';
          _userName = user.displayName ?? 'User';
          _userPhotoUrl = user.photoURL ?? '';
          _isOwnerMode = false;
          _initializeNavigation();
          _isLoading = false;
        });
      }

      // REAL-TIME LISTENER
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (snapshot) {
              if (snapshot.exists && mounted) {
                final data = snapshot.data()!;
                final role = data['role'] ?? 'customer';
                final isApproved = data['isApproved'] ?? false;
                final hasApplied = data['hasAppliedForOwner'] ?? false;
                final applicationStatus = data['applicationStatus'] ?? '';

                bool isActuallyOwner = false;

                if (role == 'admin') {
                  setState(() {
                    _userRole = 'admin';
                    _isOwner = false;
                    _initializeNavigation();
                  });
                  return;
                }

                if (role == 'owner') {
                  if (applicationStatus == 'approved' || isApproved == true) {
                    isActuallyOwner = true;
                  }
                }

                setState(() {
                  _userRole = isActuallyOwner ? 'owner' : 'customer';
                  _isOwner = isActuallyOwner;
                  _hasAppliedForOwner =
                      hasApplied || applicationStatus.isNotEmpty;
                  _applicationStatus = applicationStatus.isEmpty
                      ? (hasApplied ? 'pending' : '')
                      : applicationStatus;
                  _userName = data['name'] ?? user.displayName ?? 'User';
                  _userPhotoUrl = data['photoUrl'] ?? user.photoURL ?? '';

                  _initializeNavigation();
                });

                if (_isOwner) {
                  _loadShopData();
                }
              }
            },
            onError: (error) {
              print('Error in user stream: $error');
            },
          );
    } else {
      setState(() {
        _userRole = 'customer';
        _isOwner = false;
        _hasAppliedForOwner = false;
        _applicationStatus = '';
        _isOwnerMode = false;
        _initializeNavigation();
        _isLoading = false;
      });
    }
  }

  void _initializeNavigation() {
    // Check if user is admin first (admin always sees admin navigation)
    if (_userRole == 'admin') {
      _pages = [
        AdminHome(onToggleAppBar: _toggleAppBar),
        const AdminUsersPage(),
        const AdminShopsPage(),
        const AdminOrdersPage(),
        const AdminSettingsPage(),
      ];
      _navItems = [
        NavItem(
          Icons.dashboard_rounded,
          Icons.dashboard_outlined,
          "Dashboard",
          const Color(0xFF8B5CF6),
        ),
        NavItem(
          Icons.people_rounded,
          Icons.people_outline_rounded,
          "Users",
          const Color(0xFF3B82F6),
        ),
        NavItem(
          Icons.store_rounded,
          Icons.store_outlined,
          "Shops",
          const Color(0xFF10B981),
        ),
        NavItem(
          Icons.receipt_rounded,
          Icons.receipt_outlined,
          "Orders",
          const Color(0xFFF59E0B),
        ),
        NavItem(
          Icons.settings_rounded,
          Icons.settings_outlined,
          "Settings",
          const Color(0xFFEF4444),
        ),
      ];
      return;
    }

    // For non-admin users, check if they're in owner mode and are actually an owner
    if (_isOwnerMode && _isOwner) {
      // Owner mode - show owner navigation
      _pages = [
        const OwnerHome(),
        const OwnerProducts(),
        const OwnerOrders(),
        const OwnerAnalytics(),
        const OwnerProfile(),
      ];
      _navItems = [
        NavItem(
          Icons.dashboard_rounded,
          Icons.dashboard_outlined,
          "Dashboard",
          const Color(0xFF3B82F6),
        ),
        NavItem(
          Icons.inventory_rounded,
          Icons.inventory_outlined,
          "Products",
          const Color(0xFF8B5CF6),
        ),
        NavItem(
          Icons.shopping_bag_rounded,
          Icons.shopping_bag_outlined,
          "Orders",
          const Color(0xFF10B981),
        ),
        NavItem(
          Icons.analytics_rounded,
          Icons.analytics_outlined,
          "Analytics",
          const Color(0xFFF59E0B),
        ),
        NavItem(
          Icons.person_rounded,
          Icons.person_outline,
          "Profile",
          const Color(0xFFEF4444),
        ),
      ];
    } else {
      // Customer mode - show customer navigation (for both customers and owners in customer mode)
      _pages = [
        const CustomerHome(),
        const SearchPage(),
        const OrdersPage(),
        const WishlistPage(),
        const ProfilePage(),
      ];
      _navItems = [
        NavItem(
          Icons.home_rounded,
          Icons.home_outlined,
          "Home",
          const Color(0xFF3B82F6),
        ),
        NavItem(
          Icons.search_rounded,
          Icons.search_outlined,
          "Search",
          const Color(0xFF8B5CF6),
        ),
        NavItem(
          Icons.shopping_bag_rounded,
          Icons.shopping_bag_outlined,
          "Orders",
          const Color(0xFF10B981),
        ),
        NavItem(
          Icons.favorite_rounded,
          Icons.favorite_border,
          "Wishlist",
          const Color(0xFFEF4444),
        ),
        NavItem(
          Icons.person_rounded,
          Icons.person_outline,
          "Profile",
          const Color(0xFFF59E0B),
        ),
      ];
    }

    // Reset current index when switching modes to avoid index out of bounds
    if (_currentIndex >= _navItems.length) {
      _currentIndex = 0;
    }
  }

  Future<void> _loadShopData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('owner_requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'approved')
            .limit(1)
            .get();

        if (doc.docs.isNotEmpty && mounted) {
          setState(() {
            _shopName = doc.docs.first.data()['shopName'] ?? 'My Shop';
          });
        }
      } catch (e) {
        print('Error loading shop data: $e');
      }
    }
  }

  void _handleOwnerButtonPress() {
    if (_isOwner) {
      // Toggle between owner mode and customer mode
      setState(() {
        _isOwnerMode = !_isOwnerMode;
        _currentIndex = 0; // Reset to first tab when switching
        _initializeNavigation();
      });

      // Animate the transition
      _fadeController.reset();
      _slideController.reset();
      _scaleController.reset();
      _fadeController.forward();
      _slideController.forward();
      _scaleController.forward();

      // Show a snackbar to indicate mode change
      if (_isOwnerMode) {
        FirebaseSnackbar.success(context, "Switched to Owner Mode");
      } else {
        FirebaseSnackbar.info(context, "Switched to Customer Mode");
      }
    } else if (_hasAppliedForOwner) {
      if (_applicationStatus == 'pending') {
        // Pending application - show WaitingScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WaitingScreen()),
        ).then((_) {
          // Refresh when returning
          setState(() {});
        });
      } else if (_applicationStatus == 'rejected') {
        // Rejected - show dialog
        _showRejectedDialog();
      } else {
        // Applied but status unknown - show info dialog
        _showApplicationStatus();
      }
    }
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.cancel, color: Colors.red),
            SizedBox(width: 8),
            Text('Application Rejected'),
          ],
        ),
        content: const Text(
          'Your seller application was not approved. Please visit Profile for more details or contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to profile page
              setState(() {
                _currentIndex = 4; // Profile page index
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Go to Profile'),
          ),
        ],
      ),
    );
  }

  void _showApplicationStatus() {
    if (_hasAppliedForOwner) {
      String title = '';
      String message = '';
      Color color = Colors.orange;

      switch (_applicationStatus) {
        case 'pending':
          title = 'Application Pending';
          message =
              'Your seller application is under review. We\'ll notify you within 24-48 hours.';
          color = Colors.orange;
          break;
        case 'approved':
          title = 'Application Approved!';
          message =
              'Congratulations! You are now a seller. Click the Owner button to access your seller dashboard.';
          color = Colors.green;
          break;
        case 'rejected':
          title = 'Application Rejected';
          message =
              'Your seller application was not approved. Please visit Profile for more details.';
          color = Colors.red;
          break;
        default:
          title = 'Application Submitted';
          message =
              'Your seller application has been submitted. We\'ll review it soon.';
          color = Colors.blue;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                _applicationStatus == 'approved'
                    ? Icons.check_circle
                    : _applicationStatus == 'rejected'
                    ? Icons.cancel
                    : Icons.access_time,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            if (_applicationStatus == 'approved')
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleOwnerButtonPress();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text('Go to Owner Portal'),
              ),
            if (_applicationStatus == 'pending')
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleOwnerButtonPress(); // This will now show WaitingScreen
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Check Status'),
              ),
          ],
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh role check when app returns to foreground
    if (state == AppLifecycleState.resumed) {
      _checkUserRole();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userSubscription?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    _fadeController.reset();
    _slideController.reset();
    _scaleController.reset();

    setState(() {
      _currentIndex = index;
      _isSearchVisible = false;
    });

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  void _toggleAppBar() {
    setState(() {
      _isAppBarExpanded = !_isAppBarExpanded;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning ☀️";
    if (hour < 17) return "Good Afternoon 🌤️";
    if (hour < 22) return "Good Evening 🌙";
    return "Good Night ✨";
  }

  String _getTitlePrefix() {
    if (_userRole == 'admin') {
      return 'Admin';
    }
    if (_isOwnerMode) {
      return _shopName ?? 'Owner Dashboard';
    }
    return '';
  }

  String _getPageTitle() {
    if (_userRole == 'admin' || _isOwnerMode) {
      return _navItems[_currentIndex].label;
    }
    return _userName.split(' ')[0];
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching user data
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
      );
    }

    // Safety check - should never happen after loading
    if (_navItems.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Error loading navigation')),
      );
    }

    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final padding = media.padding;

    // Responsive breakpoints
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 900;
    final isDesktop = width >= 900;

    // Dynamic sizing
    final horizontalPadding = isDesktop ? 32.0 : (isTablet ? 24.0 : 16.0);
    final navbarHeight = isMobile ? 60.0 : (isTablet ? 68.0 : 76.0);
    final iconSize = isMobile ? 20.0 : (isTablet ? 22.0 : 24.0);
    final avatarSize = isMobile ? 36.0 : (isTablet ? 40.0 : 44.0);
    final bottomPadding = padding.bottom > 0
        ? padding.bottom
        : (isMobile ? 8.0 : 12.0);

    final currentColor = _navItems[_currentIndex].color;
    final bool hideAppBarForAdmin =
        _userRole == 'admin' && (_currentIndex == 0 || _currentIndex == 1);

    final gradient = LinearGradient(
      colors: [Colors.blue.shade400, Colors.purple.shade400],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      extendBody: true,

      /// BODY
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: _userRole == 'admin'
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.deepPurple.shade50,
                        Colors.white,
                        Colors.white,
                      ],
                    )
                  : RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.5,
                      colors: [
                        _navItems[_currentIndex].color.withOpacity(0.08),
                        Colors.white,
                        const Color(0xFFF8FAFC),
                      ],
                    ),
            ),
          ),

          // Abstract geometric patterns
          CustomPaint(
            size: Size(width, height),
            painter: _BackgroundPatternPainter(color: currentColor),
          ),

          // Content
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _pages[_currentIndex],
                ),
              ),
            ),
          ),
        ],
      ),

      /// APPBAR
      appBar: hideAppBarForAdmin
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(
                _isAppBarExpanded
                    ? (isMobile ? 100 : 120)
                    : (isMobile ? 80 : 90),
              ),
              child: SafeArea(
                bottom: false,
                child: Container(
                  margin: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    12,
                    horizontalPadding,
                    8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: currentColor.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: isMobile ? 8 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.5),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Left Section
                            Expanded(
                              child: GestureDetector(
                                onTap: _toggleAppBar,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_userRole == 'admin' ||
                                        _isOwnerMode) ...[
                                      // Admin/Owner mode - show role badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: currentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _userRole == 'admin'
                                                  ? Icons
                                                        .admin_panel_settings_rounded
                                                  : Icons.store_rounded,
                                              size: 16,
                                              color: currentColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _getTitlePrefix(),
                                              style: TextStyle(
                                                fontSize: isMobile ? 12 : 13,
                                                color: currentColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _getPageTitle(),
                                        style: TextStyle(
                                          fontSize: isMobile
                                              ? 20
                                              : (isTablet ? 24 : 28),
                                          fontWeight: FontWeight.bold,
                                          color: currentColor,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ] else ...[
                                      // Customer mode - show greeting and name
                                      Text(
                                        _getGreeting(),
                                        style: TextStyle(
                                          fontSize: isMobile ? 13 : 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _getPageTitle(),
                                        style: TextStyle(
                                          fontSize: isMobile
                                              ? 20
                                              : (isTablet ? 24 : 28),
                                          fontWeight: FontWeight.bold,
                                          color: currentColor,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // Right Section - Actions
                            Row(
                              children: [
                                /// OWNER BUTTON - Show for customers who applied AND for owners
                                if (_userRole != 'admin' &&
                                    (_hasAppliedForOwner || _isOwner)) ...[
                                  if (_applicationStatus == 'approved' ||
                                      _isOwner)
                                    _buildOwnerButton(isMobile)
                                  else if (_applicationStatus == 'pending')
                                    _buildPendingButton(isMobile)
                                  else if (_applicationStatus == 'rejected')
                                    _buildRejectedButton(isMobile)
                                  else if (_hasAppliedForOwner)
                                    _buildAppliedButton(isMobile),
                                  const SizedBox(width: 8),
                                ],

                                // Notification
                                Stack(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.notifications_none,
                                        color: _navItems[_currentIndex].color,
                                        size: isMobile ? 22 : 24,
                                      ),
                                      onPressed: () {},
                                    ),
                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(width: 4),

                                /// Profile Avatar
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentIndex = 4; // Profile page index
                                    });

                                    _fadeController.reset();
                                    _slideController.reset();
                                    _scaleController.reset();

                                    _fadeController.forward();
                                    _slideController.forward();
                                    _scaleController.forward();
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: gradient,
                                    ),
                                    child: CircleAvatar(
                                      radius: avatarSize / 2,
                                      backgroundColor: Colors.transparent,
                                      child: _userPhotoUrl.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    avatarSize / 2,
                                                  ),
                                              child: Image.network(
                                                _userPhotoUrl,
                                                fit: BoxFit.cover,
                                                width: avatarSize,
                                                height: avatarSize,
                                              ),
                                            )
                                          : Icon(
                                              _isOwnerMode
                                                  ? Icons.store
                                                  : _userRole == 'admin'
                                                  ? Icons.admin_panel_settings
                                                  : Icons.person,
                                              color: Colors.white,
                                              size: avatarSize * 0.5,
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
                  ),
                ),
              ),
            ),

      /// NAVBAR
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Container(
            margin: EdgeInsets.fromLTRB(
              isDesktop ? width * 0.25 : horizontalPadding,
              0,
              isDesktop ? width * 0.25 : horizontalPadding,
              8,
            ),
            height: navbarHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: _navItems[_currentIndex].color.withOpacity(0.25),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: List.generate(_navItems.length, (index) {
                      final selected = _currentIndex == index;
                      final item = _navItems[index];

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onTabTapped(index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? item.color.withOpacity(0.15)
                                      : Colors.transparent,
                                ),
                                child: Icon(
                                  selected ? item.selectedIcon : item.icon,
                                  size: iconSize,
                                  color: selected ? item.color : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.shortLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: selected ? item.color : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Button builders

  Widget _buildOwnerButton(bool isMobile) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTap: _handleOwnerButtonPress,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 4 : 6,
          ),
          decoration: BoxDecoration(
            gradient: _isOwnerMode
                ? const LinearGradient(
                    colors: [Colors.purple, Colors.deepPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Colors.amber, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _isOwnerMode
                    ? Colors.purple.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isOwnerMode ? Icons.person : Icons.storefront,
                color: Colors.white,
                size: isMobile ? 16 : 18,
              ),
              const SizedBox(width: 4),
              Text(
                _isOwnerMode ? 'Customer' : 'Owner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingButton(bool isMobile) {
    return GestureDetector(
      onTap: _handleOwnerButtonPress,
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: isMobile ? 14 : 16,
                height: isMobile ? 14 : 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isMobile ? 'Review' : 'Under Review',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: isMobile ? 10 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedButton(bool isMobile) {
    return GestureDetector(
      onTap: _handleOwnerButtonPress,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: isMobile ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade700,
              size: isMobile ? 12 : 14,
            ),
            const SizedBox(width: 4),
            Text(
              'Rejected',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppliedButton(bool isMobile) {
    return GestureDetector(
      onTap: _handleOwnerButtonPress,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 12,
          vertical: isMobile ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              color: Colors.blue.shade700,
              size: isMobile ? 12 : 14,
            ),
            const SizedBox(width: 4),
            Text(
              'Applied',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Background Pattern Painter
class _BackgroundPatternPainter extends CustomPainter {
  final Color color;

  _BackgroundPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path();
    for (double i = 0; i < size.width; i += 40) {
      path.moveTo(i, 0);
      path.lineTo(i + 20, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// NavItem Class
class NavItem {
  final IconData selectedIcon;
  final IconData icon;
  final String label;
  final Color color;

  String get shortLabel {
    if (label == "Dashboard") return "Home";
    if (label == "Settings") return "Config";
    if (label == "Wishlist") return "Wish";
    if (label == "Profile") return "Me";
    if (label == "Products") return "Shop";
    if (label == "Analytics") return "Stats";
    if (label == "Search") return "Find";
    return label;
  }

  const NavItem(this.selectedIcon, this.icon, this.label, this.color);
}
