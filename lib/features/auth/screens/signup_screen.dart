import 'dart:ui';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unicons/unicons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmController = TextEditingController();

  final ValueNotifier<bool> isPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isConfirmVisible = ValueNotifier<bool>(false);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? emailError;
  String? passwordError;
  String? confirmError;

  bool isLoading = false;

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
    passController.addListener(() {
      setState(() {});
    });

    confirmController.addListener(() {
      setState(() {});
    });

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
    confirmController.dispose();
    isPasswordVisible.dispose();
    isConfirmVisible.dispose();
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
    return width.toDouble();
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

  EdgeInsets getResponsiveInsets(double width) {
    if (isMobileSmall(width)) return const EdgeInsets.all(12.0);
    if (isMobileMedium(width)) return const EdgeInsets.all(14.0);
    if (isMobileLarge(width)) return const EdgeInsets.all(16.0);
    if (isMobileStandard(width)) return const EdgeInsets.all(18.0);
    if (isTabletSmall(width)) return const EdgeInsets.all(20.0);
    if (isTabletMedium(width)) return const EdgeInsets.all(22.0);
    if (isTabletLarge(width)) return const EdgeInsets.all(24.0);
    if (isDesktopSmall(width)) return const EdgeInsets.all(26.0);
    if (isDesktopMedium(width)) return const EdgeInsets.all(28.0);
    if (isDesktopLarge(width)) return const EdgeInsets.all(30.0);
    if (isDesktopXL(width)) return const EdgeInsets.all(32.0);
    if (isDesktopXXL(width)) return const EdgeInsets.all(34.0);
    if (isDesktopXXXL(width)) return const EdgeInsets.all(36.0);
    return const EdgeInsets.all(18.0);
  }

  bool isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  void validateAndSignup() async {
    setState(() {
      emailError = null;
      passwordError = null;
      confirmError = null;
      isLoading = true;
    });

    if (!isValidEmail(emailController.text.trim())) {
      emailError = "Enter a valid email address";
    }

    if (passController.text.length < 6) {
      passwordError = "Password must be at least 6 characters";
    }

    if (confirmController.text != passController.text) {
      confirmError = "Passwords don't match";
    }

    if (emailError == null && passwordError == null && confirmError == null) {
      await _signup(context);
    } else {
      setState(() => isLoading = false);
    }
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
    final double bodyFontSize = getResponsiveFontSize(width);
    final double smallFontSize = getResponsiveFontSize(width) * 0.9;
    final double chipFontSize = getResponsiveFontSize(width) * 0.8;
    final double iconSize = getResponsiveIconSize(width);
    final double buttonIconSize = getResponsiveIconSize(width) * 1.1;

    // Spacing
    final double sectionSpacing = getResponsiveSpacing(width, factor: 2.0);
    final double elementSpacing = getResponsiveSpacing(width, factor: 1.5);
    final double smallSpacing = getResponsiveSpacing(width, factor: 1.0);

    // Button heights
    final double buttonHeight = getResponsiveButtonHeight(width);

    // Border radius
    final double cardBorderRadius = getResponsiveBorderRadius(width) * 1.5;
    final double fieldBorderRadius = getResponsiveBorderRadius(width);
    final double buttonBorderRadius = getResponsiveBorderRadius(width) * 1.2;
    final double chipBorderRadius = getResponsiveBorderRadius(width) * 0.8;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
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
                                _buildHeader(
                                  logoIconSize: logoIconSize,
                                  titleFontSize: titleFontSize,
                                  subtitleFontSize: subtitleFontSize,
                                  isMobileDevice: isMobileDevice,
                                  isDesktopDevice: isDesktopDevice,
                                  iconSize: iconSize,
                                ),

                                SizedBox(
                                  height: isMobileDevice ? 8.0 : sectionSpacing,
                                ),

                                _buildFormCard(
                                  isMobileDevice: isMobileDevice,
                                  isTabletDevice: isTabletDevice,
                                  isDesktopDevice: isDesktopDevice,
                                  responsiveInsets: responsiveInsets,
                                  bodyFontSize: bodyFontSize,
                                  smallFontSize: smallFontSize,
                                  chipFontSize: chipFontSize,
                                  elementSpacing: elementSpacing,
                                  smallSpacing: smallSpacing,
                                  iconSize: iconSize,
                                  buttonIconSize: buttonIconSize,
                                  buttonHeight: buttonHeight,
                                  cardBorderRadius: cardBorderRadius,
                                  fieldBorderRadius: fieldBorderRadius,
                                  buttonBorderRadius: buttonBorderRadius,
                                  chipBorderRadius: chipBorderRadius,
                                ),

                                SizedBox(
                                  height: isMobileDevice
                                      ? 20.0
                                      : sectionSpacing * 0.8,
                                ),

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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required double logoIconSize,
    required double titleFontSize,
    required double subtitleFontSize,
    required bool isMobileDevice,
    required bool isDesktopDevice,
    required double iconSize,
  }) {
    return Column(
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
                UniconsLine.user_plus,
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
            isMobileDevice ? "Sign Up" : "Create Account",
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Text(
          isMobileDevice ? "Join Bizora" : "Join Bizora today",
          style: TextStyle(
            color: Colors.white70,
            fontSize: subtitleFontSize,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard({
    required bool isMobileDevice,
    required bool isTabletDevice,
    required bool isDesktopDevice,
    required EdgeInsets responsiveInsets,
    required double bodyFontSize,
    required double smallFontSize,
    required double chipFontSize,
    required double elementSpacing,
    required double smallSpacing,
    required double iconSize,
    required double buttonIconSize,
    required double buttonHeight,
    required double cardBorderRadius,
    required double fieldBorderRadius,
    required double buttonBorderRadius,
    required double chipBorderRadius,
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
              _buildAnimatedTextField(
                controller: emailController,
                hint: isMobileDevice ? "Email" : "Email Address",
                icon: UniconsLine.envelope,
                error: emailError,
                isMobile: isMobileDevice,
                isTablet: isTabletDevice,
                bodyFontSize: bodyFontSize,
                iconSize: iconSize,
                fieldBorderRadius: fieldBorderRadius,
              ),

              SizedBox(height: elementSpacing),

              ValueListenableBuilder<bool>(
                valueListenable: isPasswordVisible,
                builder: (context, visible, child) {
                  return _buildAnimatedTextField(
                    controller: passController,
                    hint: isMobileDevice ? "Password" : "Password",
                    icon: UniconsLine.lock,
                    isPassword: true,
                    isPasswordVisible: visible,
                    onToggleVisibility: () =>
                        isPasswordVisible.value = !isPasswordVisible.value,
                    error: passwordError,
                    isMobile: isMobileDevice,
                    isTablet: isTabletDevice,
                    bodyFontSize: bodyFontSize,
                    iconSize: iconSize,
                    fieldBorderRadius: fieldBorderRadius,
                  );
                },
              ),

              SizedBox(height: elementSpacing),

              ValueListenableBuilder<bool>(
                valueListenable: isConfirmVisible,
                builder: (context, visible, child) {
                  return _buildAnimatedTextField(
                    controller: confirmController,
                    hint: isMobileDevice ? "Confirm" : "Confirm Password",
                    icon: UniconsLine.lock,
                    isPassword: true,
                    isPasswordVisible: visible,
                    onToggleVisibility: () =>
                        isConfirmVisible.value = !isConfirmVisible.value,
                    error: confirmError,
                    isMobile: isMobileDevice,
                    isTablet: isTabletDevice,
                    bodyFontSize: bodyFontSize,
                    iconSize: iconSize,
                    fieldBorderRadius: fieldBorderRadius,
                  );
                },
              ),

              if (confirmController.text.isNotEmpty)
                _buildConfirmIndicator(
                  isMobile: isMobileDevice,
                  smallFontSize: smallFontSize,
                  chipBorderRadius: chipBorderRadius,
                ),

              if (passController.text.isNotEmpty) ...[
                SizedBox(height: smallSpacing),
                _buildPasswordStrength(
                  isMobile: isMobileDevice,
                  smallFontSize: smallFontSize,
                ),
                SizedBox(height: smallSpacing * 0.8),
                _buildPasswordRequirements(
                  isMobile: isMobileDevice,
                  chipFontSize: chipFontSize,
                  smallFontSize: smallFontSize,
                  chipBorderRadius: chipBorderRadius,
                  fieldBorderRadius: fieldBorderRadius,
                ),
              ],

              SizedBox(height: elementSpacing * 1.5),

              _buildSignUpButton(
                isMobile: isMobileDevice,
                buttonHeight: buttonHeight,
                bodyFontSize: bodyFontSize,
                buttonIconSize: buttonIconSize,
                buttonBorderRadius: buttonBorderRadius,
              ),

              SizedBox(height: elementSpacing),

              _buildLoginLink(
                isMobile: isMobileDevice,
                smallFontSize: smallFontSize,
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
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onToggleVisibility,
    String? error,
    required bool isMobile,
    required bool isTablet,
    required double bodyFontSize,
    required double iconSize,
    required double fieldBorderRadius,
  }) {
    final double horizontalPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 18.0);
    final double verticalPadding = isMobile ? 12.0 : (isTablet ? 14.0 : 16.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(fieldBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.1),
                blurRadius: 10.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? !isPasswordVisible : false,
            style: TextStyle(color: Colors.white, fontSize: bodyFontSize),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white70, size: iconSize),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? UniconsLine.eye
                            : UniconsLine.eye_slash,
                        color: Colors.white70,
                        size: iconSize,
                      ),
                      onPressed: onToggleVisibility,
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
              errorText: error,
              errorStyle: TextStyle(
                color: Colors.redAccent,
                fontSize: bodyFontSize * 0.9,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldBorderRadius),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldBorderRadius),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 2.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements({
    required bool isMobile,
    required double chipFontSize,
    required double smallFontSize,
    required double chipBorderRadius,
    required double fieldBorderRadius, // Add this parameter
  }) {
    final password = passController.text;
    final hasMinLength = password.length >= 6;
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasLetter = password.contains(RegExp(r'[a-zA-Z]'));

    return Container(
      padding: EdgeInsets.all(isMobile ? 10.0 : 14.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(
          fieldBorderRadius * 0.6,
        ), // Now fieldBorderRadius is defined
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMobile ? "Password must:" : "Password must contain:",
            style: TextStyle(
              color: Colors.white70,
              fontSize: smallFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 12.0,
            runSpacing: 6.0,
            children: [
              _buildRequirementChip(
                "6+ chars",
                hasMinLength,
                isMobile,
                chipFontSize,
                chipBorderRadius,
              ),
              _buildRequirementChip(
                "Number",
                hasNumber,
                isMobile,
                chipFontSize,
                chipBorderRadius,
              ),
              _buildRequirementChip(
                "Letter",
                hasLetter,
                isMobile,
                chipFontSize,
                chipBorderRadius,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(
    String text,
    bool isMet,
    bool isMobile,
    double chipFontSize,
    double chipBorderRadius,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6.0 : 8.0,
        vertical: isMobile ? 2.0 : 4.0,
      ),
      decoration: BoxDecoration(
        color: (isMet ? Colors.green : Colors.red).withOpacity(0.2),
        borderRadius: BorderRadius.circular(chipBorderRadius),
        border: Border.all(
          color: (isMet ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: chipFontSize * 1.2,
          ),
          const SizedBox(width: 2.0),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.red,
              fontSize: chipFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrength({
    required bool isMobile,
    required double smallFontSize,
  }) {
    final password = passController.text;

    int strength = 0;

    if (password.length >= 6) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength++;

    String label = "Weak";
    Color color = Colors.red;

    if (strength >= 3) {
      label = "Strong";
      color = Colors.green;
    } else if (strength == 2) {
      label = "Medium";
      color = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8.0),
        Row(
          children: [
            Text(
              isMobile ? "Strength:" : "Password Strength: ",
              style: TextStyle(color: Colors.white70, fontSize: smallFontSize),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: smallFontSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Row(
          children: List.generate(5, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.0),
                height: 4.0,
                decoration: BoxDecoration(
                  color: index < strength
                      ? color
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildConfirmIndicator({
    required bool isMobile,
    required double smallFontSize,
    required double chipBorderRadius,
  }) {
    final password = passController.text;
    final confirm = confirmController.text;

    final bool isMatch = password == confirm && confirm.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: isMobile ? 6.0 : 8.0,
      ),
      decoration: BoxDecoration(
        color: (isMatch ? Colors.green : Colors.red).withOpacity(0.15),
        borderRadius: BorderRadius.circular(chipBorderRadius * 0.6),
        border: Border.all(
          color: (isMatch ? Colors.green : Colors.red).withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle : Icons.cancel,
            color: isMatch ? Colors.green : Colors.red,
            size: smallFontSize * 1.3,
          ),
          const SizedBox(width: 6.0),
          Text(
            isMatch
                ? (isMobile ? "Match" : "Passwords match")
                : (isMobile ? "No match" : "Passwords do not match"),
            style: TextStyle(
              color: isMatch ? Colors.green : Colors.red,
              fontSize: smallFontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton({
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
        onPressed: isLoading ? null : validateAndSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
        ),
        child: isLoading
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
                    Icons.person_add_rounded,
                    color: Colors.white,
                    size: buttonIconSize,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    isMobile ? "Sign Up" : "Create Account",
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

  Widget _buildLoginLink({
    required bool isMobile,
    required double smallFontSize,
  }) {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 8.0 : 12.0,
            horizontal: isMobile ? 12.0 : 16.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.0),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isMobile ? "Have account? " : "Already have an account? ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: smallFontSize,
                ),
              ),
              Text(
                "Sign In",
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

  Widget _buildFooter({
    required double smallFontSize,
    required bool isMobileDevice,
  }) {
    return Text(
      isMobileDevice
          ? "By continuing, you agree to our Terms & Privacy"
          : "By continuing, you agree to our Terms of Service and Privacy Policy",
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white54, fontSize: smallFontSize * 0.9),
    );
  }

  Future<void> _signup(BuildContext context) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(cred.user!.uid)
          .set({
            'email': emailController.text.trim(),
            'role': 'customer',
            'isApproved': true,
            'createdAt': FieldValue.serverTimestamp(),
            'displayName': emailController.text.trim().split('@')[0],
          });

      if (mounted) {
        FirebaseSnackbar.success(context, "Welcome to Bizora! 🎉");
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);

      String message = "Something went wrong";

      switch (e.code) {
        case 'email-already-in-use':
          message = "Email already registered. Please login.";
          FirebaseSnackbar.error(context, message);
          break;
        case 'weak-password':
          message = "Password should be at least 6 characters.";
          FirebaseSnackbar.error(context, message);
          break;
        case 'invalid-email':
          message = "Please enter a valid email address.";
          FirebaseSnackbar.error(context, message);
          break;
        default:
          FirebaseSnackbar.error(context, message);
      }
    } catch (e) {
      setState(() => isLoading = false);
      FirebaseSnackbar.error(context, "Error: ${e.toString()}");
    }
  }
}
