import 'dart:ui';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/auth_state.dart';
import 'package:bizora/features/auth/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bizora/features/auth/auth_bloc.dart';
import 'package:bizora/features/auth/auth_event.dart';
import 'package:unicons/unicons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen>
    with TickerProviderStateMixin {
  final phoneController = TextEditingController();
  final FocusNode phoneFocus = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? phoneError;
  String? phoneNumber = '';

  // Responsive breakpoints
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
    phoneController.dispose();
    phoneFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Device detection methods
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
    return width;
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

  bool isValidPhone(String phone) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
  }

  void validatePhone() {
    setState(() {
      final phone = phoneController.text.trim();
      phoneNumber = phone;

      if (phone.isEmpty) {
        phoneError = "Phone number is required";
      } else if (!RegExp(r'^[0-9]+$').hasMatch(phone)) {
        phoneError = "Only numbers allowed";
      } else if (phone.length != 10) {
        phoneError = "Enter 10 digit phone number";
      } else if (!RegExp(r'^[6-9]').hasMatch(phone)) {
        phoneError = "Invalid Indian mobile number";
      } else {
        phoneError = null;
      }
    });
  }

  void sendOtp(BuildContext context) {
    validatePhone();

    if (phoneError != null) {
      FirebaseSnackbar.error(context, phoneError!);
      return;
    }

    FocusScope.of(context).unfocus();
    final phone = phoneController.text.trim();

    // Ensure proper format: +91XXXXXXXXXX (no spaces)
    final formattedPhone = "+91$phone";
    print("Sending OTP to: $formattedPhone"); // Debug print

    context.read<AuthBloc>().add(PhoneLoginRequested(phone: formattedPhone));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final double width = media.size.width;
    final double height = media.size.height;

    final bool isMobileDevice = isMobile(width);
    final bool isTabletDevice = isTablet(width);
    final bool isDesktopDevice = isDesktop(width);

    // Dynamic values
    final double horizontalPadding = getResponsivePadding(width);
    final double cardWidth = getResponsiveCardWidth(width);
    final EdgeInsets responsiveInsets = getResponsiveInsets(width);

    // Font sizes
    final double logoIconSize = getResponsiveIconSize(width) * 2.5;
    final double titleFontSize = getResponsiveFontSize(width) * 2.0;
    final double subtitleFontSize = getResponsiveFontSize(width) * 1.1;
    final double bodyFontSize = getResponsiveFontSize(width);
    final double smallFontSize = getResponsiveFontSize(width) * 0.9;
    final double iconSize = getResponsiveIconSize(width);
    final double buttonIconSize = getResponsiveIconSize(width) * 1.2;

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
    final double codeContainerBorderRadius = getResponsiveBorderRadius(width);

    // Loading indicator sizes
    final double indicatorSize = isMobileDevice ? 16.0 : 20.0;
    final double loadingSize = isMobileDevice ? 12.0 : 14.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.transparent,
      body: Container(
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
          child: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is OtpSent) {
                FirebaseSnackbar.success(context, "OTP sent successfully");

                // Navigate to OTP screen with proper error handling
                try {
                  if (!mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OtpScreen(
                        verificationId: state.verificationId,
                        phoneNumber: phoneNumber,
                      ),
                    ),
                  );
                } catch (e) {
                  print("Navigation error: $e");
                  // This won't catch the hot reload warning
                }
              }
              if (state is AuthFailure) {
                FirebaseSnackbar.error(context, state.message);
              }
            },
            builder: (context, state) {
              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Center(
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
                                  isMobileDevice: isMobileDevice,
                                  isDesktopDevice: isDesktopDevice,
                                  logoIconSize: logoIconSize,
                                  titleFontSize: titleFontSize,
                                  subtitleFontSize: subtitleFontSize,
                                  iconSize: iconSize,
                                  indicatorSize: indicatorSize,
                                  loadingSize: loadingSize,
                                  state: state,
                                ),
                                SizedBox(
                                  height: isMobileDevice
                                      ? 20.0
                                      : sectionSpacing,
                                ),
                                _buildPhoneCard(
                                  context,
                                  isMobileDevice: isMobileDevice,
                                  isTabletDevice: isTabletDevice,
                                  isDesktopDevice: isDesktopDevice,
                                  responsiveInsets: responsiveInsets,
                                  bodyFontSize: bodyFontSize,
                                  smallFontSize: smallFontSize,
                                  elementSpacing: elementSpacing,
                                  smallSpacing: smallSpacing,
                                  iconSize: iconSize,
                                  buttonIconSize: buttonIconSize,
                                  buttonHeight: buttonHeight,
                                  cardBorderRadius: cardBorderRadius,
                                  fieldBorderRadius: fieldBorderRadius,
                                  buttonBorderRadius: buttonBorderRadius,
                                  codeContainerBorderRadius:
                                      codeContainerBorderRadius,
                                  state: state,
                                ),
                                SizedBox(
                                  height: isMobileDevice
                                      ? 16.0
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required bool isMobileDevice,
    required bool isDesktopDevice,
    required double logoIconSize,
    required double titleFontSize,
    required double subtitleFontSize,
    required double iconSize,
    required double indicatorSize,
    required double loadingSize,
    required AuthState state,
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                UniconsLine.mobile_android,
                size: logoIconSize,
                color: Colors.white,
              ),
              if (state is AuthLoading)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: indicatorSize,
                    height: indicatorSize,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: loadingSize,
                        height: loadingSize,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ).animate().scale(
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
        ),
        SizedBox(height: isMobileDevice ? 12.0 : 16.0),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB794F4)],
          ).createShader(bounds),
          child: Text(
            "Phone Login",
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(height: isMobileDevice ? 4.0 : 8.0),
        Text(
          "Verify your mobile number",
          style: TextStyle(
            color: Colors.white70,
            fontSize: subtitleFontSize,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneCard(
    BuildContext context, {
    required bool isMobileDevice,
    required bool isTabletDevice,
    required bool isDesktopDevice,
    required EdgeInsets responsiveInsets,
    required double bodyFontSize,
    required double smallFontSize,
    required double elementSpacing,
    required double smallSpacing,
    required double iconSize,
    required double buttonIconSize,
    required double buttonHeight,
    required double cardBorderRadius,
    required double fieldBorderRadius,
    required double buttonBorderRadius,
    required double codeContainerBorderRadius,
    required AuthState state,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardBorderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          padding: EdgeInsets.all(isMobileDevice ? 16.0 : 24.0),
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
            children: [
              /// Phone Input Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCountryCode(
                    isMobile: isMobileDevice,
                    isTablet: isTabletDevice,
                    bodyFontSize: bodyFontSize,
                    iconSize: iconSize,
                    fieldBorderRadius: fieldBorderRadius,
                    state: state,
                  ),
                  SizedBox(width: isMobileDevice ? 8.0 : 12.0),
                  Expanded(
                    child: _buildPhoneField(
                      isMobile: isMobileDevice,
                      isTablet: isTabletDevice,
                      bodyFontSize: bodyFontSize,
                      iconSize: iconSize,
                      fieldBorderRadius: fieldBorderRadius,
                      state: state,
                    ),
                  ),
                ],
              ),
              if (phoneError != null) ...[
                SizedBox(height: smallSpacing),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobileDevice ? 10.0 : 12.0,
                    vertical: isMobileDevice ? 4.0 : 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      fieldBorderRadius * 0.5,
                    ),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        UniconsLine.exclamation_triangle,
                        color: Colors.redAccent,
                        size: smallFontSize * 1.2,
                      ),
                      SizedBox(width: isMobileDevice ? 4.0 : 6.0),
                      Expanded(
                        child: Text(
                          phoneError!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: smallFontSize,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: elementSpacing),

              /// Phone Preview
              if (phoneNumber != null &&
                  phoneNumber!.length == 10 &&
                  phoneError == null)
                Container(
                  padding: EdgeInsets.all(isMobileDevice ? 10.0 : 14.0),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(fieldBorderRadius),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: buttonIconSize,
                      ),
                      SizedBox(width: isMobileDevice ? 6.0 : 8.0),
                      Flexible(
                        child: Text(
                          isMobileDevice
                              ? "OTP to sent +91 $phoneNumber"
                              : "OTP will be sent to +91 $phoneNumber",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: bodyFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: elementSpacing),

              /// Send OTP Button
              _buildSendOtpButton(
                context,
                isMobile: isMobileDevice,
                buttonHeight: buttonHeight,
                bodyFontSize: bodyFontSize,
                buttonIconSize: buttonIconSize,
                buttonBorderRadius: buttonBorderRadius,
                state: state,
              ),
              SizedBox(height: elementSpacing * 0.8),

              /// Back Button
              _buildBackButton(
                isMobile: isMobileDevice,
                smallFontSize: smallFontSize,
              ),
              SizedBox(height: elementSpacing * 0.6),

              /// Info Text
              _buildInfoText(
                isMobile: isMobileDevice,
                smallFontSize: smallFontSize,
                fieldBorderRadius: fieldBorderRadius,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryCode({
    required bool isMobile,
    required bool isTablet,
    required double bodyFontSize,
    required double iconSize,
    required double fieldBorderRadius,
    required AuthState state,
  }) {
    final double horizontalPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 18.0);
    final double verticalPadding = isMobile ? 13.0 : (isTablet ? 15.0 : 17.0);

    return Container(
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
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(fieldBorderRadius),
          border: Border.all(
            color: Colors.white.withOpacity(state is AuthLoading ? 0.3 : 0.2),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_outlined,
                size: iconSize,
                color: state is AuthLoading ? Colors.white54 : Colors.white70,
              ),
              SizedBox(width: isMobile ? 6.0 : 8.0),
              Text(
                "+91",
                style: TextStyle(
                  color: state is AuthLoading ? Colors.white54 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: bodyFontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField({
    required bool isMobile,
    required bool isTablet,
    required double bodyFontSize,
    required double iconSize,
    required double fieldBorderRadius,
    required AuthState state,
  }) {
    final double horizontalPadding = isMobile ? 12.0 : (isTablet ? 16.0 : 18.0);

    return Container(
      height: 56.0,
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
        controller: phoneController,
        focusNode: phoneFocus,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        enabled: state is! AuthLoading,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        style: TextStyle(color: Colors.white, fontSize: bodyFontSize),
        cursorColor: Colors.white,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          counterText: "",
          prefixIcon: Icon(
            Icons.phone_outlined,
            color: Colors.white70,
            size: iconSize,
          ),
          suffixIcon: phoneController.text.length == 10
              ? Icon(Icons.check_circle, color: Colors.green, size: iconSize)
              : null,
          hintText: isMobile ? "10-digit number" : "Enter 10-digit number",
          hintStyle: TextStyle(
            color: Colors.white54,
            fontSize: bodyFontSize * 0.95,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          contentPadding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 0.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(fieldBorderRadius),
            borderSide: BorderSide.none,
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
          errorText: phoneError,
          errorStyle: TextStyle(
            color: Colors.redAccent,
            fontSize: bodyFontSize * 0.9,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(fieldBorderRadius),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(fieldBorderRadius),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
          ),
          isDense: true,
        ),
        onChanged: (value) {
          if (phoneError != null) {
            setState(() {
              phoneError = null;
            });
          }
          setState(() {
            phoneNumber = value;
          });
        },
      ),
    );
  }

  Widget _buildSendOtpButton(
    BuildContext context, {
    required bool isMobile,
    required double buttonHeight,
    required double bodyFontSize,
    required double buttonIconSize,
    required double buttonBorderRadius,
    required AuthState state,
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
        onPressed: state is AuthLoading ? null : () => sendOtp(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
        ),
        child: state is AuthLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: buttonIconSize,
                    width: buttonIconSize,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: isMobile ? 8.0 : 12.0),
                  Text(
                    isMobile ? "Sending..." : "Sending OTP...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: bodyFontSize,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    UniconsLine.message,
                    color: Colors.white,
                    size: buttonIconSize,
                  ),
                  SizedBox(width: isMobile ? 8.0 : 10.0),
                  Text(
                    isMobile ? "Send" : "Send OTP",
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

  Widget _buildBackButton({
    required bool isMobile,
    required double smallFontSize,
  }) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 8.0 : 12.0,
            horizontal: isMobile ? 16.0 : 20.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              UniconsLine.arrow_left,
              color: Colors.white70,
              size: smallFontSize * 1.3,
            ),
            SizedBox(width: isMobile ? 4.0 : 6.0),
            Text(
              isMobile ? "Back" : "Back to Login",
              style: TextStyle(color: Colors.white70, fontSize: smallFontSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText({
    required bool isMobile,
    required double smallFontSize,
    required double fieldBorderRadius,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10.0 : 14.0),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(fieldBorderRadius * 0.6),
      ),
      child: Row(
        children: [
          Icon(
            UniconsLine.info_circle,
            color: Colors.blueAccent,
            size: smallFontSize * 1.2,
          ),
          SizedBox(width: isMobile ? 6.0 : 8.0),
          Expanded(
            child: Text(
              isMobile
                  ? "You'll receive a 6-digit OTP via SMS"
                  : "You'll receive a 6-digit OTP via SMS to verify your number",
              style: TextStyle(
                color: Colors.blueAccent.shade100,
                fontSize: smallFontSize * 0.9,
              ),
              maxLines: isMobile ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
              ? "By continuing, you agree to our"
              : "By continuing, you agree to our",
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
}
