import 'dart:async';
import 'dart:ui';
import 'package:bizora/features/owner/screens/owner_home.dart';
import 'package:bizora/features/owner/screens/owner_products.dart';
import 'package:bizora/features/owner/screens/owner_orders.dart';
import 'package:bizora/features/owner/screens/owner_analytics.dart';
import 'package:bizora/features/owner/screens/owner_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OwnerNavbar extends StatefulWidget {
  const OwnerNavbar({super.key});

  @override
  State<OwnerNavbar> createState() => _OwnerNavbarState();
}

class _OwnerNavbarState extends State<OwnerNavbar>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isAppBarExpanded = true;
  String? _shopName;

  // Initialize with default values first
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  late final List<Widget> _pages;

  final List<NavItem> _navItems = [
    NavItem(
      Icons.dashboard_rounded,
      Icons.dashboard_outlined,
      "Dashboard",
      Colors.blue,
    ),
    NavItem(
      Icons.inventory_2_rounded,
      Icons.inventory_2_outlined,
      "Products",
      Colors.deepPurple,
    ),
    NavItem(
      Icons.shopping_bag_rounded,
      Icons.shopping_bag_outlined,
      "Orders",
      Colors.teal,
    ),
    NavItem(
      Icons.bar_chart_rounded,
      Icons.bar_chart_outlined,
      "Analytics",
      Colors.orange,
    ),
    NavItem(Icons.person_rounded, Icons.person_outline, "Profile", Colors.red),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePages();
    _loadShopData();
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

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, .08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  void _initializePages() {
    _pages = [
      const OwnerHome(),
      const OwnerProducts(),
      const OwnerOrders(),
      const OwnerAnalytics(),
      const OwnerProfile(),
    ];
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

        if (doc.docs.isNotEmpty) {
          if (mounted) {
            setState(() {
              _shopName = doc.docs.first.data()['shopName'] ?? 'My Shop';
            });
          }
        }
      } catch (e) {
        print('Error loading shop data: $e');
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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
    final canPop = Navigator.canPop(context);

    final isTablet = width > 600;
    final isFoldable = width > 900;

    final navbarHeight = isTablet ? 90.0 : 76.0;
    final iconSize = isTablet ? 28.0 : 24.0;

    final gradient = LinearGradient(
      colors: [Colors.deepPurple.shade400, Colors.purple.shade400],
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
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              children: [
                /// Back Button (only appears if canPop)
                if (canPop) ...[
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: Colors.deepPurple.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                /// Shop Info & Title
                Expanded(
                  child: GestureDetector(
                    onTap: _toggleAppBar,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.storefront,
                              size: 16,
                              color: Colors.deepPurple.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _shopName ?? 'Owner Portal',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
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

                /// Notification Icon
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: _navItems[_currentIndex].color,
                      ),
                      onPressed: () {},
                    ),

                    /// Badge
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

                /// Shop Avatar with gradient
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                  ),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.store, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      /// NAVBAR (same as before)
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
}

class NavItem {
  final IconData selectedIcon;
  final IconData icon;
  final String label;
  final Color color;

  String get shortLabel {
    if (label == "Dashboard") return "Home";
    if (label == "Products") return "Shop";
    if (label == "Analytics") return "Stats";
    if (label == "Profile") return "Me";
    return label;
  }

  const NavItem(this.selectedIcon, this.icon, this.label, this.color);
}
