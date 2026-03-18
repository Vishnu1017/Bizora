import 'dart:ui';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/auth_bloc.dart';
import 'package:bizora/features/auth/auth_event.dart';
import 'package:bizora/features/auth/auth_state.dart';
import 'package:bizora/features/auth/screens/UnifiedNavbar.dart';
import 'package:bizora/features/auth/screens/otp_screen.dart';
import 'package:bizora/features/auth/screens/phone_login_screen.dart';
import 'package:bizora/features/auth/screens/signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unicons/unicons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passController = TextEditingController();

  bool obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Comprehensive responsive breakpoints for all device types
  static const double mobileSmallBreakpoint = 360;
  static const double mobileMediumBreakpoint = 400;
  static const double mobileLargeBreakpoint = 480;
  static const double mobileBreakpoint = 600;
  static const double tabletSmallBreakpoint = 600;
  static const double tabletMediumBreakpoint = 720;
  static const double tabletLargeBreakpoint = 840;
  static const double desktopBreakpoint = 1024;
  static const double desktopMediumBreakpoint = 1280;
  static const double desktopLargeBreakpoint = 1440;
  static const double desktopXLBreaKpoint = 1600;
  static const double desktopXXLBreaKpoint = 1920;
  static const double desktopXXXLBreaKpoint = 2560;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Comprehensive device detection methods
  bool isMobileSmall(double width) => width < mobileSmallBreakpoint;
  bool isMobileMedium(double width) =>
      width >= mobileSmallBreakpoint && width < mobileMediumBreakpoint;
  bool isMobileLarge(double width) =>
      width >= mobileMediumBreakpoint && width < mobileLargeBreakpoint;
  bool isMobileStandard(double width) =>
      width >= mobileLargeBreakpoint && width < mobileBreakpoint;
  bool isMobile(double width) => width < mobileBreakpoint;

  bool isTabletSmall(double width) =>
      width >= tabletSmallBreakpoint && width < tabletMediumBreakpoint;
  bool isTabletMedium(double width) =>
      width >= tabletMediumBreakpoint && width < tabletLargeBreakpoint;
  bool isTabletLarge(double width) =>
      width >= tabletLargeBreakpoint && width < desktopBreakpoint;
  bool isTablet(double width) =>
      width >= tabletSmallBreakpoint && width < desktopBreakpoint;

  bool isDesktopSmall(double width) =>
      width >= desktopBreakpoint && width < desktopMediumBreakpoint;
  bool isDesktopMedium(double width) =>
      width >= desktopMediumBreakpoint && width < desktopLargeBreakpoint;
  bool isDesktopLarge(double width) =>
      width >= desktopLargeBreakpoint && width < desktopXLBreaKpoint;
  bool isDesktopXL(double width) =>
      width >= desktopXLBreaKpoint && width < desktopXXLBreaKpoint;
  bool isDesktopXXL(double width) =>
      width >= desktopXXLBreaKpoint && width < desktopXXXLBreaKpoint;
  bool isDesktopXXXL(double width) => width >= desktopXXXLBreaKpoint;
  bool isDesktop(double width) => width >= desktopBreakpoint;

  String getDeviceType(double width) {
    if (isMobileSmall(width)) return 'Mobile Small';
    if (isMobileMedium(width)) return 'Mobile Medium';
    if (isMobileLarge(width)) return 'Mobile Large';
    if (isMobileStandard(width)) return 'Mobile Standard';
    if (isTabletSmall(width)) return 'Tablet Small';
    if (isTabletMedium(width)) return 'Tablet Medium';
    if (isTabletLarge(width)) return 'Tablet Large';
    if (isDesktopSmall(width)) return 'Desktop Small';
    if (isDesktopMedium(width)) return 'Desktop Medium';
    if (isDesktopLarge(width)) return 'Desktop Large';
    if (isDesktopXL(width)) return 'Desktop XL';
    if (isDesktopXXL(width)) return 'Desktop XXL';
    if (isDesktopXXXL(width)) return 'Desktop XXXL';
    return 'Unknown';
  }

  double getResponsiveFontSize(
    double width, {
    double mobileSmall = 12.0,
    double mobileMedium = 13.0,
    double mobileLarge = 14.0,
    double mobileStandard = 14.0,
    double tabletSmall = 15.0,
    double tabletMedium = 16.0,
    double tabletLarge = 17.0,
    double desktopSmall = 18.0,
    double desktopMedium = 20.0,
    double desktopLarge = 22.0,
    double desktopXL = 24.0,
    double desktopXXL = 26.0,
    double desktopXXXL = 28.0,
  }) {
    if (isMobileSmall(width)) return mobileSmall;
    if (isMobileMedium(width)) return mobileMedium;
    if (isMobileLarge(width)) return mobileLarge;
    if (isMobileStandard(width)) return mobileStandard;
    if (isTabletSmall(width)) return tabletSmall;
    if (isTabletMedium(width)) return tabletMedium;
    if (isTabletLarge(width)) return tabletLarge;
    if (isDesktopSmall(width)) return desktopSmall;
    if (isDesktopMedium(width)) return desktopMedium;
    if (isDesktopLarge(width)) return desktopLarge;
    if (isDesktopXL(width)) return desktopXL;
    if (isDesktopXXL(width)) return desktopXXL;
    if (isDesktopXXXL(width)) return desktopXXXL;
    return 14.0;
  }

  double getResponsivePadding(double width) {
    if (isMobileSmall(width)) return 12.0;
    if (isMobileMedium(width)) return 14.0;
    if (isMobileLarge(width)) return 16.0;
    if (isMobileStandard(width)) return 16.0;
    if (isTabletSmall(width)) return width * 0.15;
    if (isTabletMedium(width)) return width * 0.18;
    if (isTabletLarge(width)) return width * 0.20;
    if (isDesktopSmall(width)) return width * 0.25;
    if (isDesktopMedium(width)) return width * 0.28;
    if (isDesktopLarge(width)) return width * 0.30;
    if (isDesktopXL(width)) return width * 0.32;
    if (isDesktopXXL(width)) return width * 0.35;
    if (isDesktopXXXL(width)) return width * 0.38;
    return 16.0;
  }

  double getResponsiveCardWidth(double width) {
    if (isMobileSmall(width)) return width * 0.95;
    if (isMobileMedium(width)) return width * 0.9;
    if (isMobileLarge(width)) return width * 0.85;
    if (isMobileStandard(width)) return width * 0.8;
    if (isTabletSmall(width)) return 480.0;
    if (isTabletMedium(width)) return 520.0;
    if (isTabletLarge(width)) return 560.0;
    if (isDesktopSmall(width)) return 600.0;
    if (isDesktopMedium(width)) return 650.0;
    if (isDesktopLarge(width)) return 700.0;
    if (isDesktopXL(width)) return 750.0;
    if (isDesktopXXL(width)) return 800.0;
    if (isDesktopXXXL(width)) return 850.0;
    return double.infinity;
  }

  double getResponsiveIconSize(double width) {
    if (isMobileSmall(width)) return 16.0;
    if (isMobileMedium(width)) return 18.0;
    if (isMobileLarge(width)) return 20.0;
    if (isMobileStandard(width)) return 22.0;
    if (isTabletSmall(width)) return 24.0;
    if (isTabletMedium(width)) return 26.0;
    if (isTabletLarge(width)) return 28.0;
    if (isDesktopSmall(width)) return 30.0;
    if (isDesktopMedium(width)) return 32.0;
    if (isDesktopLarge(width)) return 34.0;
    if (isDesktopXL(width)) return 36.0;
    if (isDesktopXXL(width)) return 38.0;
    if (isDesktopXXXL(width)) return 40.0;
    return 22.0;
  }

  double getResponsiveButtonHeight(double width) {
    if (isMobileSmall(width)) return 44.0;
    if (isMobileMedium(width)) return 48.0;
    if (isMobileLarge(width)) return 50.0;
    if (isMobileStandard(width)) return 52.0;
    if (isTabletSmall(width)) return 54.0;
    if (isTabletMedium(width)) return 56.0;
    if (isTabletLarge(width)) return 58.0;
    if (isDesktopSmall(width)) return 60.0;
    if (isDesktopMedium(width)) return 62.0;
    if (isDesktopLarge(width)) return 64.0;
    if (isDesktopXL(width)) return 66.0;
    if (isDesktopXXL(width)) return 68.0;
    if (isDesktopXXXL(width)) return 70.0;
    return 52.0;
  }

  double getResponsiveBorderRadius(double width) {
    if (isMobileSmall(width)) return 16.0;
    if (isMobileMedium(width)) return 18.0;
    if (isMobileLarge(width)) return 20.0;
    if (isMobileStandard(width)) return 22.0;
    if (isTabletSmall(width)) return 24.0;
    if (isTabletMedium(width)) return 26.0;
    if (isTabletLarge(width)) return 28.0;
    if (isDesktopSmall(width)) return 30.0;
    if (isDesktopMedium(width)) return 32.0;
    if (isDesktopLarge(width)) return 34.0;
    if (isDesktopXL(width)) return 36.0;
    if (isDesktopXXL(width)) return 38.0;
    if (isDesktopXXXL(width)) return 40.0;
    return 22.0;
  }

  double getResponsiveSpacing(double width, {double factor = 1.0}) {
    if (isMobileSmall(width)) return 8.0 * factor;
    if (isMobileMedium(width)) return 10.0 * factor;
    if (isMobileLarge(width)) return 12.0 * factor;
    if (isMobileStandard(width)) return 14.0 * factor;
    if (isTabletSmall(width)) return 16.0 * factor;
    if (isTabletMedium(width)) return 18.0 * factor;
    if (isTabletLarge(width)) return 20.0 * factor;
    if (isDesktopSmall(width)) return 22.0 * factor;
    if (isDesktopMedium(width)) return 24.0 * factor;
    if (isDesktopLarge(width)) return 26.0 * factor;
    if (isDesktopXL(width)) return 28.0 * factor;
    if (isDesktopXXL(width)) return 30.0 * factor;
    if (isDesktopXXXL(width)) return 32.0 * factor;
    return 14.0 * factor;
  }

  EdgeInsets getResponsiveInsets(double width, {double multiplier = 1.0}) {
    if (isMobileSmall(width)) return EdgeInsets.all(12.0 * multiplier);
    if (isMobileMedium(width)) return EdgeInsets.all(14.0 * multiplier);
    if (isMobileLarge(width)) return EdgeInsets.all(16.0 * multiplier);
    if (isMobileStandard(width)) return EdgeInsets.all(18.0 * multiplier);
    if (isTabletSmall(width)) return EdgeInsets.all(20.0 * multiplier);
    if (isTabletMedium(width)) return EdgeInsets.all(22.0 * multiplier);
    if (isTabletLarge(width)) return EdgeInsets.all(24.0 * multiplier);
    if (isDesktopSmall(width)) return EdgeInsets.all(26.0 * multiplier);
    if (isDesktopMedium(width)) return EdgeInsets.all(28.0 * multiplier);
    if (isDesktopLarge(width)) return EdgeInsets.all(30.0 * multiplier);
    if (isDesktopXL(width)) return EdgeInsets.all(32.0 * multiplier);
    if (isDesktopXXL(width)) return EdgeInsets.all(34.0 * multiplier);
    if (isDesktopXXXL(width)) return EdgeInsets.all(36.0 * multiplier);
    return EdgeInsets.all(16.0 * multiplier);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double width = size.width;
    final double height = size.height;

    final bool isMobileDevice = isMobile(width);
    final bool isTabletDevice = isTablet(width);
    final bool isDesktopDevice = isDesktop(width);

    // Dynamic values with comprehensive responsive calculations
    final double horizontalPadding = getResponsivePadding(width);
    final double cardWidth = getResponsiveCardWidth(width);
    final EdgeInsets responsiveInsets = getResponsiveInsets(width);

    // Font sizes
    final double logoIconSize = getResponsiveIconSize(width) * 2.5;
    final double titleFontSize = getResponsiveFontSize(width) * 2.0;
    final double subtitleFontSize = getResponsiveFontSize(width) * 1.1;
    final double headingFontSize = getResponsiveFontSize(width) * 1.5;
    final double bodyFontSize = getResponsiveFontSize(width);
    final double smallFontSize = getResponsiveFontSize(width) * 0.9;
    final double iconSize = getResponsiveIconSize(width);
    final double fieldIconSize = getResponsiveIconSize(width) * 0.9;
    final double buttonIconSize = getResponsiveIconSize(width) * 1.1;

    // Spacing
    final double sectionSpacing = getResponsiveSpacing(width, factor: 2.0);
    final double elementSpacing = getResponsiveSpacing(width, factor: 1.5);
    final double smallSpacing = getResponsiveSpacing(width, factor: 1.0);

    // Button heights
    final double buttonHeight = getResponsiveButtonHeight(width);
    final double socialButtonHeight = getResponsiveButtonHeight(width) * 0.9;

    // Border radius
    final double cardBorderRadius = getResponsiveBorderRadius(width) * 1.5;
    final double fieldBorderRadius = getResponsiveBorderRadius(width);
    final double buttonBorderRadius = getResponsiveBorderRadius(width) * 1.2;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return BlocConsumer<AuthBloc, AuthState>(
                  listener: (context, state) {
                    if (state is AuthSuccess) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UnifiedNavbar(),
                        ),
                      );
                    }
                    if (state is AuthFailure) {
                      FirebaseSnackbar.error(context, state.message);
                    }
                    if (state is OtpSent) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OtpScreen(verificationId: state.verificationId),
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    return Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: isMobileDevice ? 16.0 : 24.0,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: cardWidth,
                              maxHeight: isDesktopDevice
                                  ? height * 0.95
                                  : (isTabletDevice
                                        ? height * 0.98
                                        : height * 0.98),
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Logo Section
                                    _buildLogoSection(
                                      logoIconSize: logoIconSize,
                                      titleFontSize: titleFontSize,
                                      subtitleFontSize: subtitleFontSize,
                                      isMobileDevice: isMobileDevice,
                                      isDesktopDevice: isDesktopDevice,
                                      iconSize: iconSize,
                                    ),

                                    SizedBox(
                                      height: isMobileDevice
                                          ? 4.0
                                          : sectionSpacing,
                                    ),

                                    // Glass Card Section
                                    _buildGlassCard(
                                      context,
                                      state,
                                      isMobileDevice: isMobileDevice,
                                      isTabletDevice: isTabletDevice,
                                      isDesktopDevice: isDesktopDevice,
                                      headingFontSize: headingFontSize,
                                      bodyFontSize: bodyFontSize,
                                      smallFontSize: smallFontSize,
                                      elementSpacing: elementSpacing,
                                      smallSpacing: smallSpacing,
                                      responsiveInsets: responsiveInsets,
                                      fieldIconSize: fieldIconSize,
                                      buttonIconSize: buttonIconSize,
                                      buttonHeight: buttonHeight,
                                      socialButtonHeight: socialButtonHeight,
                                      cardBorderRadius: cardBorderRadius,
                                      fieldBorderRadius: fieldBorderRadius,
                                      buttonBorderRadius: buttonBorderRadius,
                                    ),

                                    SizedBox(
                                      height: isMobileDevice
                                          ? 16.0
                                          : sectionSpacing * 0.8,
                                    ),

                                    // Footer Section
                                    _buildFooter(
                                      smallFontSize: smallFontSize,
                                      isMobileDevice: isMobileDevice,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection({
    required double logoIconSize,
    required double titleFontSize,
    required double subtitleFontSize,
    required bool isMobileDevice,
    required bool isDesktopDevice,
    required double iconSize,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobileDevice ? 8.0 : 12.0),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isMobileDevice ? 12.0 : 16.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child:
                Icon(
                  Icons.storefront_rounded,
                  size: logoIconSize,
                  color: Colors.white,
                ).animate().scale(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                ),
          ),
          const SizedBox(height: 4.0),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFB794F4)],
            ).createShader(bounds),
            child: Text(
              "Bizora",
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            isMobileDevice ? "Smart Marketplace" : "Smart Local Marketplace",
            style: TextStyle(
              color: Colors.white70,
              fontSize: subtitleFontSize,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(
    BuildContext context,
    AuthState state, {
    required bool isMobileDevice,
    required bool isTabletDevice,
    required bool isDesktopDevice,
    required double headingFontSize,
    required double bodyFontSize,
    required double smallFontSize,
    required double elementSpacing,
    required double smallSpacing,
    required EdgeInsets responsiveInsets,
    required double fieldIconSize,
    required double buttonIconSize,
    required double buttonHeight,
    required double socialButtonHeight,
    required double cardBorderRadius,
    required double fieldBorderRadius,
    required double buttonBorderRadius,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardBorderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          padding: responsiveInsets,
          constraints: BoxConstraints(
            maxWidth: isDesktopDevice
                ? 700.0
                : (isTabletDevice ? 600.0 : 500.0),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(cardBorderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.1),
                blurRadius: 30.0,
                spreadRadius: 5.0,
                offset: const Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                children: [
                  Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.amber,
                    size: fieldIconSize,
                  ),
                  SizedBox(width: smallSpacing * 0.8),
                  Text(
                    isMobileDevice ? "Welcome!" : "Welcome Back!",
                    style: TextStyle(
                      fontSize: headingFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              SizedBox(height: elementSpacing),

              // Email Field
              _buildAnimatedTextField(
                controller: emailController,
                hint: isMobileDevice ? "Email" : "Email Address",
                icon: UniconsLine.envelope,
                isPassword: false,
                isMobile: isMobileDevice,
                isTablet: isTabletDevice,
                bodyFontSize: bodyFontSize,
                fieldIconSize: fieldIconSize,
                fieldBorderRadius: fieldBorderRadius,
              ),

              SizedBox(height: elementSpacing * 0.8),

              // Password Field
              _buildAnimatedTextField(
                controller: passController,
                hint: isMobileDevice ? "Password" : "Password",
                icon: UniconsLine.lock,
                isPassword: true,
                isMobile: isMobileDevice,
                isTablet: isTabletDevice,
                bodyFontSize: bodyFontSize,
                fieldIconSize: fieldIconSize,
                fieldBorderRadius: fieldBorderRadius,
              ),

              SizedBox(height: elementSpacing * 0.6),

              // Sign Up and Forgot Password Row
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildSignUpLink(
                        context,
                        isMobile: isMobileDevice,
                        smallFontSize: smallFontSize,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildForgotPassword(
                        context,
                        isMobile: isMobileDevice,
                        smallFontSize: smallFontSize,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: elementSpacing),

              // Login Button
              _buildLoginButton(
                context,
                state,
                isMobile: isMobileDevice,
                buttonHeight: buttonHeight,
                bodyFontSize: bodyFontSize,
                buttonIconSize: buttonIconSize,
                buttonBorderRadius: buttonBorderRadius,
              ),

              SizedBox(height: elementSpacing),

              // OR Divider
              _buildOrDivider(
                isMobile: isMobileDevice,
                smallFontSize: smallFontSize,
              ),

              SizedBox(height: elementSpacing),

              // Social Login Buttons
              _buildSocialLoginButtons(
                context,
                isMobile: isMobileDevice,
                isDesktop: isDesktopDevice,
                socialButtonHeight: socialButtonHeight,
                smallFontSize: smallFontSize,
                buttonIconSize: buttonIconSize,
                buttonBorderRadius: buttonBorderRadius,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPassword,
    required bool isMobile,
    required bool isTablet,
    required double bodyFontSize,
    required double fieldIconSize,
    required double fieldBorderRadius,
  }) {
    final double horizontalPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 18.0);
    final double verticalPadding = isMobile ? 12.0 : (isTablet ? 14.0 : 16.0);

    return TextField(
      controller: controller,
      obscureText: isPassword ? obscurePassword : false,
      style: TextStyle(color: Colors.white, fontSize: bodyFontSize),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70, size: fieldIconSize),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscurePassword ? UniconsLine.eye_slash : UniconsLine.eye,
                  color: Colors.white70,
                  size: fieldIconSize,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              )
            : null,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white54,
          fontSize: bodyFontSize * 0.95,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldBorderRadius),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldBorderRadius),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.15),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldBorderRadius),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 219, 219, 219),
            width: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(
    BuildContext context, {
    required bool isMobile,
    required double smallFontSize,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignupScreen()),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 6.0 : 8.0,
            horizontal: isMobile ? 10.0 : 14.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.0),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isMobile ? "New? " : "New here? ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: smallFontSize,
                ),
              ),
              Text(
                "Sign Up",
                style: TextStyle(
                  color: const Color(0xFFB794F4),
                  fontWeight: FontWeight.bold,
                  fontSize: smallFontSize,
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 4.0),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: const Color(0xFFB794F4),
                  size: smallFontSize * 1.2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword(
    BuildContext context, {
    required bool isMobile,
    required double smallFontSize,
  }) {
    return TextButton(
      onPressed: () => _showResetDialog(context, isMobile: isMobile),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8.0 : 14.0,
          vertical: isMobile ? 6.0 : 10.0,
        ),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        isMobile ? "Forgot?" : "Forgot Password?",
        style: TextStyle(
          color: Colors.white70,
          fontSize: smallFontSize,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white38,
        ),
      ),
    );
  }

  Widget _buildOrDivider({
    required bool isMobile,
    required double smallFontSize,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.white.withOpacity(0.3)],
              ),
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12.0 : 16.0,
            vertical: isMobile ? 2.0 : 4.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Text(
            "OR",
            style: TextStyle(
              color: Colors.white70,
              fontSize: smallFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1.0,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons(
    BuildContext context, {
    required bool isMobile,
    required bool isDesktop,
    required double socialButtonHeight,
    required double smallFontSize,
    required double buttonIconSize,
    required double buttonBorderRadius,
  }) {
    return Row(
      children: [
        // Google Button
        Expanded(
          child: _buildSocialButton(
            icon: UniconsLine.google,
            label: isMobile ? "Google Sign In" : "Google Sign In",
            onPressed: () {
              context.read<AuthBloc>().add(GoogleLoginRequested());
            },
            height: socialButtonHeight,
            fontSize: smallFontSize * 0.80,
            buttonIconSize: buttonIconSize,
            buttonBorderRadius: buttonBorderRadius,
            isOutlined: false,
          ),
        ),
        SizedBox(width: isMobile ? 8.0 : 12.0),
        // Phone Button
        Expanded(
          child: _buildSocialButton(
            icon: UniconsLine.phone,
            label: isMobile ? "Login with OTP" : "Login with OTP",
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
              );
            },
            height: socialButtonHeight,
            fontSize: smallFontSize * 0.80,
            buttonIconSize: buttonIconSize,
            buttonBorderRadius: buttonBorderRadius,
            isOutlined: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required double height,
    required double fontSize,
    required double buttonIconSize,
    required double buttonBorderRadius,
    required bool isOutlined,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(buttonBorderRadius),
        gradient: isOutlined
            ? null
            : const LinearGradient(colors: [Colors.white, Color(0xFFF5F5F5)]),
      ),
      child: isOutlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(buttonBorderRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: buttonIconSize * 0.80),
                  const SizedBox(width: 6.0),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 4.0,
                shadowColor: Colors.purple.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(buttonBorderRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.purple, size: buttonIconSize * 0.80),
                  const SizedBox(width: 6.0),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoginButton(
    BuildContext context,
    AuthState state, {
    required bool isMobile,
    required double buttonHeight,
    required double bodyFontSize,
    required double buttonIconSize,
    required double buttonBorderRadius,
  }) {
    return Container(
      width: double.infinity,
      height: buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(buttonBorderRadius),
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
      ),
      child: ElevatedButton(
        onPressed: state is AuthLoading
            ? null
            : () {
                if (emailController.text.isEmpty ||
                    passController.text.isEmpty) {
                  FirebaseSnackbar.error(context, "Please fill all fields");
                  return;
                }
                context.read<AuthBloc>().add(
                  LoginRequested(
                    email: emailController.text.trim(),
                    password: passController.text.trim(),
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
        ),
        child: state is AuthLoading
            ? SizedBox(
                height: buttonIconSize,
                width: buttonIconSize,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    color: Colors.white,
                    size: buttonIconSize,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    isMobile ? "Login" : "Login",
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter({
    required double smallFontSize,
    required bool isMobileDevice,
  }) {
    return Column(
      children: [
        Text(
          isMobileDevice
              ? "By continuing, you agree"
              : "By continuing you agree to our",
          style: TextStyle(
            color: Colors.white54,
            fontSize: smallFontSize * 0.9,
          ),
        ),
        const SizedBox(height: 4.0),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4.0,
          children: [
            Text(
              "Terms",
              style: TextStyle(
                color: Colors.white70,
                fontSize: smallFontSize * 0.9,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
            Text(
              " & ",
              style: TextStyle(
                color: Colors.white54,
                fontSize: smallFontSize * 0.9,
              ),
            ),
            Text(
              "Privacy",
              style: TextStyle(
                color: Colors.white70,
                fontSize: smallFontSize * 0.9,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context, {required bool isMobile}) {
    final resetController = TextEditingController();
    final double width = MediaQuery.of(context).size.width;
    final bool isMobileDevice = isMobile;

    final double dialogBorderRadius = getResponsiveBorderRadius(width) * 0.8;
    final double dialogPadding = getResponsiveInsets(width).left;
    final double dialogTitleFontSize = getResponsiveFontSize(width) * 1.2;
    final double dialogContentFontSize = getResponsiveFontSize(width) * 0.9;
    final double dialogButtonFontSize = getResponsiveFontSize(width) * 0.9;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobileDevice ? 16.0 : 32.0,
          vertical: 24.0,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktop(width) ? 500.0 : 400.0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1E1E2E), const Color(0xFF2D2D3A)],
            ),
            borderRadius: BorderRadius.circular(dialogBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 30.0,
                spreadRadius: 5.0,
                offset: const Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(dialogPadding),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.0),
                    topRight: Radius.circular(24.0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_reset_rounded,
                      color: Colors.white,
                      size: dialogTitleFontSize,
                    ),
                    const SizedBox(width: 12.0),
                    Text(
                      "Reset Password",
                      style: TextStyle(
                        fontSize: dialogTitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(dialogPadding),
                child: Column(
                  children: [
                    Text(
                      isMobileDevice
                          ? "Enter your email to reset password"
                          : "Enter your registered email address to receive a password reset link.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: dialogContentFontSize,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: dialogPadding),

                    TextField(
                      controller: resetController,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: dialogContentFontSize,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          UniconsLine.envelope,
                          color: Colors.white70,
                          size: dialogContentFontSize * 1.2,
                        ),
                        hintText: "your@email.com",
                        hintStyle: TextStyle(
                          color: Colors.white54,
                          fontSize: dialogContentFontSize,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            dialogBorderRadius * 0.5,
                          ),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    SizedBox(height: dialogPadding * 1.5),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: dialogPadding * 0.8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  dialogBorderRadius * 0.5,
                                ),
                              ),
                            ),
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: dialogButtonFontSize,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12.0),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final email = resetController.text.trim();
                              if (email.isEmpty) {
                                FirebaseSnackbar.error(
                                  context,
                                  "Please enter your email",
                                );
                                return;
                              }

                              try {
                                await FirebaseAuth.instance
                                    .sendPasswordResetEmail(email: email);
                                Navigator.pop(context);
                                FirebaseSnackbar.success(
                                  context,
                                  "Reset link sent",
                                );
                              } catch (e) {
                                FirebaseSnackbar.error(
                                  context,
                                  "Failed to send reset email",
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: dialogPadding * 0.8,
                              ),
                              backgroundColor: Colors.deepPurpleAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  dialogBorderRadius * 0.5,
                                ),
                              ),
                            ),
                            child: Text(
                              "Send Link",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: dialogButtonFontSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
