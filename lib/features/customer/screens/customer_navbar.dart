import 'dart:async';
import 'dart:ui';
import 'package:bizora/features/auth/screens/waiting_screen.dart';
import 'package:bizora/features/customer/screens/customer_home.dart';
import 'package:bizora/features/customer/screens/orders_page.dart';
import 'package:bizora/features/customer/screens/profile_page.dart';
import 'package:bizora/features/customer/screens/search_page.dart';
import 'package:bizora/features/customer/screens/wishlist_page.dart';
import 'package:bizora/features/owner/screens/owner_navbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerNavbar extends StatefulWidget {
  const CustomerNavbar({super.key});

  @override
  State<CustomerNavbar> createState() => _CustomerNavbarState();
}

class _CustomerNavbarState extends State<CustomerNavbar>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isAppBarExpanded = true;

  // User role states
  bool _isOwner = false;
  bool _hasAppliedForOwner = false;
  String _applicationStatus = ''; // 'pending', 'approved', 'rejected'
  late StreamSubscription<DocumentSnapshot>? _userSubscription;

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _pulseAnimation;

  // Add owner page to pages list
  late final List<Widget> _pages;

  final List<NavItem> _navItems = [
    NavItem(Icons.window_rounded, Icons.window_outlined, "Home", Colors.blue),
    NavItem(
      Icons.travel_explore_rounded,
      Icons.travel_explore_outlined,
      "Search",
      Colors.purple,
    ),
    NavItem(
      Icons.local_mall_rounded,
      Icons.local_mall_outlined,
      "Orders",
      Colors.teal,
    ),
    NavItem(
      Icons.favorite_rounded,
      Icons.favorite_border_rounded,
      "Wishlist",
      Colors.red,
    ),
    NavItem(
      Icons.person_rounded,
      Icons.person_outline_rounded,
      "Profile",
      Colors.orange,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeAnimations();
    _checkUserRole();
    _initializePages();
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

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, .08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  void _initializePages() {
    _pages = [
      const CustomerHome(),
      const SearchPage(),
      const OrdersPage(),
      const WishlistPage(),
      const ProfilePage(),
    ];
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Listen to real-time role changes
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data()!;
              final role = data['role'];
              final isApproved = data['isApproved'] ?? false;
              final hasApplied = data['hasAppliedForOwner'] ?? false;
              final applicationStatus = data['applicationStatus'] ?? '';

              setState(() {
                _isOwner = role == 'owner' && isApproved;
                _hasAppliedForOwner = hasApplied;
                _applicationStatus = applicationStatus;
              });

              print(
                'User status - Owner: $_isOwner, Applied: $_hasAppliedForOwner, Status: $_applicationStatus',
              );
            }
          });
    }
  }

  void _handleOwnerButtonPress() {
    if (_isOwner) {
      // Approved owner - go to OwnerNavbar
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OwnerNavbar()),
      ).then((_) {
        // Refresh UI when returning from owner portal
        setState(() {});
      });
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
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    _fadeController.reset();
    _slideController.reset();

    setState(() {
      _currentIndex = index;
    });

    _fadeController.forward();
    _slideController.forward();
  }

  void _toggleAppBar() {
    setState(() {
      _isAppBarExpanded = !_isAppBarExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;

    final isTablet = width > 600;
    final isFoldable = width > 900;

    final navbarHeight = isTablet ? 90.0 : 76.0;
    final iconSize = isTablet ? 28.0 : 24.0;

    final gradient = LinearGradient(
      colors: [Colors.blue.shade400, Colors.purple.shade400],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      extendBody: true,

      /// PAGE BODY
      body: Stack(
        children: [
          /// animated background
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFFF5F7FF), Colors.white],
                radius: 1,
              ),
            ),
          ),

          /// page content
          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _pages[_currentIndex],
              ),
            ),
          ),
        ],
      ),

      /// APPBAR
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_isAppBarExpanded ? 100 : 70),
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _toggleAppBar,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _navItems[_currentIndex].label,
                          style: TextStyle(
                            fontSize: isTablet ? 26 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                /// OWNER BUTTON - Shows different states based on application status
                if (_hasAppliedForOwner || _isOwner) ...[
                  if (_isOwner)
                    _buildOwnerButton() // Full owner access - goes to OwnerNavbar
                  else if (_applicationStatus == 'pending')
                    _buildPendingButton() // Waiting for approval - goes to WaitingScreen
                  else if (_applicationStatus == 'rejected')
                    _buildRejectedButton() // Application rejected - shows dialog
                  else
                    _buildAppliedButton(), // Applied but status unknown - shows info
                  const SizedBox(width: 8),
                ],

                /// notification
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: _navItems[_currentIndex].color,
                      ),
                      onPressed: () {},
                    ),

                    /// badge
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

                /// Profile Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                  ),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      /// NAVBAR
      bottomNavigationBar: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            isFoldable ? width * .25 : 16,
            0,
            isFoldable ? width * .25 : 16,
            12,
          ),
          height: navbarHeight,

          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),

            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),

              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.85),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: _navItems[_currentIndex].color.withOpacity(.25),
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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? item.color.withOpacity(.15)
                                    : Colors.transparent,
                              ),

                              child: Icon(
                                selected ? item.selectedIcon : item.icon,
                                size: iconSize,
                                color: selected ? item.color : Colors.grey,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              item.shortLabel,
                              style: TextStyle(
                                fontSize: 11,
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
    );
  }

  /// Full Owner Button (Approved) - Navigates to OwnerNavbar
  Widget _buildOwnerButton() {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.amber, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.storefront, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                'Owner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pending Application Button (Waiting for approval) - Navigates to WaitingScreen
  Widget _buildPendingButton() {
    return GestureDetector(
      onTap: _handleOwnerButtonPress, // This will now show WaitingScreen
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orange.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Under Review',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rejected Application Button
  Widget _buildRejectedButton() {
    return GestureDetector(
      onTap: _handleOwnerButtonPress, // This will show rejection dialog
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 14),
            const SizedBox(width: 4),
            Text(
              'Rejected',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Applied but status unknown button
  Widget _buildAppliedButton() {
    return GestureDetector(
      onTap: _handleOwnerButtonPress, // This will show status dialog
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, color: Colors.blue.shade700, size: 14),
            const SizedBox(width: 4),
            Text(
              'Applied',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return "Good Morning ☀️";
    if (hour < 17) return "Good Afternoon 🌤️";
    if (hour < 22) return "Good Evening 🌙";
    return "Good Night ✨";
  }
}

class NavItem {
  final IconData selectedIcon;
  final IconData icon;
  final String label;
  final Color color;

  String get shortLabel {
    if (label == "Wishlist") return "Wish";
    if (label == "Profile") return "Me";
    return label;
  }

  const NavItem(this.selectedIcon, this.icon, this.label, this.color);
}
