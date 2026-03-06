import 'dart:ui';
import 'package:bizora/Admin/screens/admin_home.dart';
import 'package:bizora/Admin/screens/admin_orders_page.dart';
import 'package:bizora/Admin/screens/admin_settings_page.dart';
import 'package:bizora/Admin/screens/admin_shops_page.dart';
import 'package:bizora/Admin/screens/admin_users_page.dart';
import 'package:flutter/material.dart';

class AdminNavbar extends StatefulWidget {
  const AdminNavbar({super.key});

  @override
  State<AdminNavbar> createState() => _AdminNavbarState();
}

class _AdminNavbarState extends State<AdminNavbar>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isAppBarExpanded = true;

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final AnimationController _bounceController;
  late final AnimationController _pulseController;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  // Store the pages with their builders
  late final List<Widget> pages;

  final List<NavItem> navItems = const [
    NavItem(
      Icons.dashboard_rounded,
      Icons.dashboard_outlined,
      "Dashboard",
      Colors.deepPurple,
    ),
    NavItem(Icons.people, Icons.people_outline, "Users", Colors.blue),
    NavItem(Icons.storefront, Icons.storefront_outlined, "Shops", Colors.teal),
    NavItem(
      Icons.receipt_long,
      Icons.receipt_long_outlined,
      "Orders",
      Colors.orange,
    ),
    NavItem(Icons.settings, Icons.settings_outlined, "Settings", Colors.red),
  ];

  @override
  void initState() {
    super.initState();

    // Initialize pages with context and state access
    pages = [
      AdminHome(onToggleAppBar: _toggleAppBar),
      const AdminUsersPage(),
      const AdminShopsPage(),
      const AdminOrdersPage(),
      const AdminSettingsPage(),
    ];

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _scaleAnimation = Tween<double>(begin: .9, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _bounceController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;

    _fadeController.reset();
    _slideController.reset();
    _bounceController.reset();

    setState(() {
      _currentIndex = index;
    });

    _fadeController.forward();
    _slideController.forward();
    _bounceController.forward();
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
    final iconSize = width < 360 ? 22.0 : 26.0;

    return Scaffold(
      extendBody: true,

      /// BODY
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFFF5F7FF), Colors.white],
                radius: 1,
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: pages[_currentIndex],
                ),
              ),
            ),
          ),
        ],
      ),

      /// NO APPBAR - Let each page handle its own header
      appBar: null,

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
            borderRadius: BorderRadius.circular(35),

            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),

              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.85),
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: navItems[_currentIndex].color.withOpacity(.25),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),

                child: Row(
                  children: List.generate(navItems.length, (index) {
                    final item = navItems[index];
                    final selected = _currentIndex == index;

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
    if (label == "Dashboard") return "Dashboard";
    if (label == "Settings") return "Config";
    return label;
  }

  const NavItem(this.selectedIcon, this.icon, this.label, this.color);
}
