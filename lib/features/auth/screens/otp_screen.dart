import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/screens/phone_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bizora/features/auth/auth_bloc.dart';
import 'package:bizora/features/auth/auth_event.dart';
import 'package:bizora/features/auth/auth_state.dart';
import 'package:bizora/features/auth/screens/splash_screen.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:unicons/unicons.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String? phoneNumber;

  const OtpScreen({required this.verificationId, this.phoneNumber, super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final List<TextEditingController> controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());
  final List<Color> otpBoxColors = List.generate(6, (_) => Colors.transparent);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int seconds = 30;
  Timer? timer;
  bool isAutoFilling = false;
  bool isOtpVisible = false;

  // Add state variable for current phone number
  String currentPhoneNumber = '';
  String currentVerificationId = '';

  // Responsive breakpoints for all device types
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

    currentVerificationId = widget.verificationId;
    String phone = widget.phoneNumber ?? '';
    if (phone.startsWith('+91')) {
      currentPhoneNumber = phone;
    } else {
      currentPhoneNumber = "+91${phone.replaceAll(RegExp(r'[^0-9]'), '')}";
    }

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
    startTimer();

    if (widget.verificationId == "AUTO_VERIFIED") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ignore: invalid_use_of_protected_member
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            focusNodes[0].requestFocus();
          });
        }
      });
    }
  }

  // Comprehensive device detection methods
  bool isMobileSmall(double width) => width < mobileSmallBreakpoint;
  bool isMobileMedium(double width) =>
      width >= mobileSmallBreakpoint && width < mobileMediumBreakpoint;
  bool isMobileLarge(double width) =>
      width >= mobileMediumBreakpoint && width < mobileLargeBreakpoint;
  bool isMobile(double width) =>
      width >= mobileLargeBreakpoint && width < mobileBreakpoint;
  bool isMobileStandard(double width) =>
      width >= mobileLargeBreakpoint && width < mobileBreakpoint;
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
    if (isMobile(width)) return 'Mobile';
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
    double mobile = 14.0,
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
    if (isMobile(width)) return mobile;
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
    if (isMobile(width)) return 16.0;
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
    if (isMobile(width)) return width * 0.8;
    if (isTabletSmall(width)) return 480.0;
    if (isTabletMedium(width)) return 500.0;
    if (isTabletLarge(width)) return 520.0;
    if (isDesktopSmall(width)) return 550.0;
    if (isDesktopMedium(width)) return 580.0;
    if (isDesktopLarge(width)) return 600.0;
    if (isDesktopXL(width)) return 650.0;
    if (isDesktopXXL(width)) return 700.0;
    if (isDesktopXXXL(width)) return 750.0;
    return 480.0;
  }

  double getResponsiveOtpBoxSize(double width) {
    double baseSize;

    if (isMobileSmall(width))
      baseSize = 40.0;
    else if (isMobileMedium(width))
      baseSize = 42.0;
    else if (isMobileLarge(width))
      baseSize = 45.0;
    else if (isMobileStandard(width))
      baseSize = 48.0;
    else if (isTabletSmall(width))
      baseSize = 50.0;
    else if (isTabletMedium(width))
      baseSize = 52.0;
    else if (isTabletLarge(width))
      baseSize = 54.0;
    else if (isDesktopSmall(width))
      baseSize = 56.0;
    else if (isDesktopMedium(width))
      baseSize = 58.0;
    else if (isDesktopLarge(width))
      baseSize = 60.0;
    else if (isDesktopXL(width))
      baseSize = 62.0;
    else if (isDesktopXXL(width))
      baseSize = 64.0;
    else if (isDesktopXXXL(width))
      baseSize = 66.0;
    else
      baseSize = 48.0;

    // Calculate maximum possible box size without overflow
    double availableWidth = width - (getResponsivePadding(width) * 2) - 48;
    double maxBoxSize = (availableWidth - (5 * 2)) / 6; // Minimum 2px spacing

    return baseSize.clamp(35.0, maxBoxSize);
  }

  double getResponsiveOtpFontSize(double width) {
    if (isMobileSmall(width)) return 16.0;
    if (isMobileMedium(width)) return 18.0;
    if (isMobileLarge(width)) return 20.0;
    if (isMobile(width)) return 22.0;
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

  double getResponsiveIconSize(double width) {
    if (isMobileSmall(width)) return 16.0;
    if (isMobileMedium(width)) return 18.0;
    if (isMobileLarge(width)) return 20.0;
    if (isMobile(width)) return 22.0;
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
    if (isMobile(width)) return 52.0;
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
    if (isMobile(width)) return 22.0;
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
    if (isMobile(width)) return 14.0 * factor;
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
    if (isMobile(width)) return const EdgeInsets.all(18.0);
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

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (seconds == 0) {
        t.cancel();
      } else {
        setState(() => seconds--);
      }
    });
  }

  String getOtp() {
    return controllers.map((e) => e.text).join();
  }

  @override
  void dispose() {
    timer?.cancel();
    _animationController.dispose();

    for (var c in controllers) {
      c.dispose();
    }

    for (var f in focusNodes) {
      f.dispose();
    }

    super.dispose();
  }

  void moveNext(int index, String value) {
    setState(() {
      otpBoxColors[index] = value.isNotEmpty
          ? Colors.green.withOpacity(0.2)
          : Colors.transparent;
    });

    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all digits are entered
    if (index == 5 && value.isNotEmpty) {
      final otp = getOtp();
      if (otp.length == 6) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _verifyOtp(otp);
        });
      }
    }
  }

  void _verifyOtp(String otp) {
    if (otp.length != 6) {
      FirebaseSnackbar.warning(context, "Enter complete OTP");
      return;
    }

    context.read<AuthBloc>().add(
      VerifyOtpRequested(
        verificationId: currentVerificationId, // ✅ FIXED
        otp: otp,
      ),
    );
  }

  void _showChangeNumberDialog() {
    final phoneController = TextEditingController();
    final double width = MediaQuery.of(context).size.width;
    bool isDialogLoading = false;

    final double dialogBorderRadius = getResponsiveBorderRadius(width) * 0.8;
    final double dialogPadding = getResponsiveInsets(width).left;
    final double dialogTitleFontSize = getResponsiveFontSize(width) * 1.2;
    final double dialogContentFontSize = getResponsiveFontSize(width) * 0.9;
    final double dialogButtonFontSize = getResponsiveFontSize(width) * 0.9;

    // Get the AuthBloc from the current context before showing dialog
    final authBloc = context.read<AuthBloc>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile(width) ? 16.0 : 32.0,
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
                        colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28.0),
                        topRight: Radius.circular(28.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(dialogPadding * 0.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            UniconsLine.phone,
                            color: Colors.white,
                            size: dialogTitleFontSize,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Text(
                          "Change Number",
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
                          "Enter your new phone number to receive OTP",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: dialogContentFontSize,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: dialogPadding),

                        // Phone Input
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              dialogBorderRadius * 0.6,
                            ),
                            border: Border.all(color: Colors.white24),
                            color: Colors.white.withOpacity(0.08),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: dialogPadding * 0.8,
                                  vertical: dialogPadding * 0.8,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: Colors.white24),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: dialogContentFontSize,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6.0),
                                    Text(
                                      "+91",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: dialogContentFontSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  enabled: !isDialogLoading,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: dialogContentFontSize,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "98765 43210",
                                    hintStyle: TextStyle(
                                      color: Colors.white54,
                                      fontSize: dialogContentFontSize * 0.9,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: dialogPadding * 0.8,
                                    ),
                                    counterText: "",
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: dialogPadding * 1.5),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: isDialogLoading
                                    ? null
                                    : () => Navigator.pop(dialogContext),
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
                                    color: isDialogLoading
                                        ? Colors.white38
                                        : Colors.white70,
                                    fontSize: dialogButtonFontSize,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isDialogLoading
                                    ? null
                                    : () {
                                        final phone = phoneController.text
                                            .trim();
                                        if (phone.length != 10) {
                                          FirebaseSnackbar.error(
                                            dialogContext,
                                            "Enter valid 10 digit number",
                                          );
                                          return;
                                        }

                                        // Show loading state
                                        setDialogState(() {
                                          isDialogLoading = true;
                                        });

                                        // Close dialog
                                        Navigator.pop(dialogContext);

                                        // Update the current phone number state
                                        setState(() {
                                          currentPhoneNumber = "+91$phone";
                                          seconds = 30;
                                        });

                                        // Clear OTP fields
                                        for (int i = 0; i < 6; i++) {
                                          controllers[i].clear();
                                          otpBoxColors[i] = Colors.transparent;
                                        }

                                        // Send new OTP
                                        authBloc.add(
                                          PhoneLoginRequested(
                                            phone: "+91$phone",
                                          ),
                                        );

                                        startTimer();

                                        // Focus on first OTP field - using a longer delay and safety checks
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (!mounted) return;
                                              focusNodes[0].requestFocus();
                                            });
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                    vertical: dialogPadding * 0.8,
                                  ),
                                  backgroundColor: isDialogLoading
                                      ? Colors.deepPurpleAccent.withOpacity(0.5)
                                      : Colors.deepPurpleAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      dialogBorderRadius * 0.5,
                                    ),
                                  ),
                                ),
                                child: isDialogLoading
                                    ? SizedBox(
                                        height: dialogButtonFontSize * 1.5,
                                        width: dialogButtonFontSize * 1.5,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        "Send OTP",
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;

    // Dynamic values with comprehensive responsive calculations
    final double horizontalPadding = getResponsivePadding(width);
    final double cardWidth = getResponsiveCardWidth(width);
    final double otpBoxSize = getResponsiveOtpBoxSize(width);
    final EdgeInsets responsiveInsets = getResponsiveInsets(width);

    // Font sizes
    final double logoIconSize = getResponsiveIconSize(width) * 2.5;
    final double titleFontSize = getResponsiveFontSize(width) * 2.0;
    final double subtitleFontSize = getResponsiveFontSize(width) * 1.1;
    final double bodyFontSize = getResponsiveFontSize(width);
    final double smallFontSize = getResponsiveFontSize(width) * 0.9;
    final double otpFontSize = getResponsiveOtpFontSize(width);
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
    final double otpBoxBorderRadius = getResponsiveBorderRadius(width) * 0.8;
    final double buttonBorderRadius = getResponsiveBorderRadius(width);
    final double phoneDisplayBorderRadius =
        getResponsiveBorderRadius(width) * 0.9;

    // Loading indicator size
    final double loadingSize = getResponsiveIconSize(width) * 0.8;

    return Scaffold(
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
              if (state is AuthSuccess) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
                );
              }
              if (state is AuthFailure) {
                FirebaseSnackbar.error(context, state.message);
                // Highlight incorrect OTP boxes
                setState(() {
                  for (int i = 0; i < 6; i++) {
                    otpBoxColors[i] = Colors.red.withOpacity(0.2);
                  }
                });
              }
              // Handle new OTP sent
              if (state is OtpSent) {
                setState(() {
                  currentPhoneNumber = state.phoneNumber;
                  currentVerificationId =
                      state.verificationId; // 🔥 CRITICAL FIX
                  print("Updated Phone: ${state.phoneNumber}");
                });

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  focusNodes[0].requestFocus();
                });

                FirebaseSnackbar.success(context, "OTP sent successfully");
              }
            },
            builder: (context, state) {
              return Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isMobile(width) ? 16.0 : 24.0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cardWidth,
                        maxHeight: isDesktop(width)
                            ? height * 0.95
                            : (isTablet(width) ? height * 0.98 : height * 0.98),
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
                                isMobileDevice: isMobile(width),
                                isDesktopDevice: isDesktop(width),
                                logoIconSize: logoIconSize,
                                titleFontSize: titleFontSize,
                                subtitleFontSize: subtitleFontSize,
                                iconSize: iconSize,
                                loadingSize: loadingSize,
                                state: state,
                              ),

                              SizedBox(
                                height: isMobile(width) ? 20.0 : sectionSpacing,
                              ),

                              _buildOtpCard(
                                context,
                                state,
                                isMobileDevice: isMobile(width),
                                isTabletDevice: isTablet(width),
                                isDesktopDevice: isDesktop(width),
                                responsiveInsets: responsiveInsets,
                                otpBoxSize: otpBoxSize,
                                otpFontSize: otpFontSize,
                                bodyFontSize: bodyFontSize,
                                smallFontSize: smallFontSize,
                                elementSpacing: elementSpacing,
                                smallSpacing: smallSpacing,
                                iconSize: iconSize,
                                buttonIconSize: buttonIconSize,
                                buttonHeight: buttonHeight,
                                cardBorderRadius: cardBorderRadius,
                                otpBoxBorderRadius: otpBoxBorderRadius,
                                buttonBorderRadius: buttonBorderRadius,
                                phoneDisplayBorderRadius:
                                    phoneDisplayBorderRadius,
                              ),

                              SizedBox(
                                height: isMobile(width)
                                    ? 16.0
                                    : sectionSpacing * 0.8,
                              ),

                              _buildFooter(
                                smallFontSize: smallFontSize,
                                isMobileDevice: isMobile(width),
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
    );
  }

  Widget _buildHeader({
    required bool isMobileDevice,
    required bool isDesktopDevice,
    required double logoIconSize,
    required double titleFontSize,
    required double subtitleFontSize,
    required double iconSize,
    required double loadingSize,
    required AuthState state,
  }) {
    return Column(
      children: [
        Stack(
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
              child: ScanningLockIcon(size: logoIconSize),
            ),
          ],
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
            "OTP Verification",
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
          "Enter the 6-digit code sent to your phone",
          style: TextStyle(
            color: Colors.white70,
            fontSize: subtitleFontSize,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOtpCard(
    BuildContext context,
    AuthState state, {
    required bool isMobileDevice,
    required bool isTabletDevice,
    required bool isDesktopDevice,
    required EdgeInsets responsiveInsets,
    required double otpBoxSize,
    required double otpFontSize,
    required double bodyFontSize,
    required double smallFontSize,
    required double elementSpacing,
    required double smallSpacing,
    required double iconSize,
    required double buttonIconSize,
    required double buttonHeight,
    required double cardBorderRadius,
    required double otpBoxBorderRadius,
    required double buttonBorderRadius,
    required double phoneDisplayBorderRadius,
  }) {
    // Extract just the last 4 digits

    if (currentPhoneNumber.length >= 4) {}

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
              /// Phone Number Display with Last 4 Digits
              Container(
                padding: EdgeInsets.all(isMobileDevice ? 10.0 : 14.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(phoneDisplayBorderRadius),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      UniconsLine.message,
                      color: Colors.blueAccent,
                      size: iconSize,
                    ),
                    SizedBox(width: isMobileDevice ? 6.0 : 8.0),
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        String phone = currentPhoneNumber;

                        if (state is OtpSent) {
                          phone = state.phoneNumber;
                        }

                        return Flexible(
                          child: Text(
                            phone.isNotEmpty
                                ? "Code sent to ${maskedPhone(phone)}"
                                : "Code sent to your phone",
                            style: TextStyle(
                              color: Colors.blueAccent.shade100,
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: elementSpacing),

              /// OTP Boxes - Using LayoutBuilder for perfect fit
              LayoutBuilder(
                builder: (context, constraints) {
                  // Get the max width available for all boxes + gaps
                  double maxWidth = constraints.maxWidth;

                  // Calculate optimal box size and gap
                  double optimalBoxSize =
                      (maxWidth - (5 * 4.0)) / 6; // Assuming 4px min gap
                  double boxSize = otpBoxSize.clamp(35.0, optimalBoxSize);

                  // Calculate actual gap after box size is determined
                  double actualGap = (maxWidth - (boxSize * 6)) / 5;
                  actualGap = actualGap.clamp(2.0, 16.0);

                  return Center(
                    child: SizedBox(
                      width: maxWidth,
                      child: PinFieldAutoFill(
                        codeLength: 6,
                        currentCode: "",

                        // 🔥 IMPORTANT: This gives you BOX UI like before
                        decoration: BoxLooseDecoration(
                          gapSpace: actualGap,
                          bgColorBuilder: FixedColorBuilder(
                            Colors.white.withOpacity(0.08),
                          ),
                          strokeColorBuilder: FixedColorBuilder(
                            Colors.white.withOpacity(0.15),
                          ),
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: otpFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        cursor: Cursor(
                          width: 2,
                          height: boxSize * 0.6,
                          color: Colors.white,
                          enabled: true,
                        ),

                        onCodeChanged: (code) {
                          if (code != null && code.length == 6) {
                            _verifyOtp(code);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: elementSpacing * 1.2),

              /// Verify Button
              Container(
                width: double.infinity,
                height: buttonHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(buttonBorderRadius),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                ),
                child: ElevatedButton(
                  onPressed: null,
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              UniconsLine.check_circle,
                              color: Colors.white,
                              size: buttonIconSize,
                            ),
                            SizedBox(width: isMobileDevice ? 8.0 : 10.0),
                            Text(
                              isMobileDevice ? "Verify" : "Verify OTP",
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              SizedBox(height: smallSpacing),

              /// Resend + Change - Production ready with perfect alignment
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate optimal layout based on available width
                      final double availableWidth = constraints.maxWidth;
                      final bool shouldStack =
                          availableWidth <
                          280; // Stack vertically on very small screens

                      if (shouldStack) {
                        // Vertical layout for very small screens
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Resend button
                            TextButton(
                              onPressed: seconds == 0
                                  ? () {
                                      setState(() => seconds = 30);
                                      startTimer();
                                      context.read<AuthBloc>().add(
                                        PhoneLoginRequested(
                                          phone: currentPhoneNumber,
                                        ),
                                      );
                                    }
                                  : null,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobileDevice ? 16.0 : 20.0,
                                  vertical: isMobileDevice ? 8.0 : 10.0,
                                ),
                                minimumSize: const Size(120, 40),
                              ),
                              child: Text(
                                seconds == 0
                                    ? "Resend OTP"
                                    : "Resend in $seconds${isMobileDevice ? 's' : 's'}",
                                style: TextStyle(
                                  color: seconds == 0
                                      ? Color(0xFFB794F4)
                                      : Colors.white54,
                                  fontSize: smallFontSize,
                                  fontWeight: seconds == 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),

                            SizedBox(height: smallSpacing * 0.5),

                            // Divider line
                            Container(
                              width: 40,
                              height: 1,
                              color: Colors.white24,
                            ),

                            SizedBox(height: smallSpacing * 0.5),

                            // Change number button
                            TextButton(
                              onPressed: _showChangeNumberDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobileDevice ? 16.0 : 20.0,
                                  vertical: isMobileDevice ? 8.0 : 10.0,
                                ),
                                minimumSize: const Size(120, 40),
                              ),
                              child: Text(
                                isMobileDevice ? "Change" : "Change Number",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: smallFontSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Horizontal layout with proper spacing
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Resend button
                            TextButton(
                              onPressed: seconds == 0
                                  ? () {
                                      setState(() => seconds = 30);
                                      startTimer();
                                      context.read<AuthBloc>().add(
                                        PhoneLoginRequested(
                                          phone: currentPhoneNumber,
                                        ),
                                      );
                                    }
                                  : null,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobileDevice ? 12.0 : 16.0,
                                  vertical: isMobileDevice ? 6.0 : 8.0,
                                ),
                                minimumSize: Size(
                                  isMobileDevice ? 100 : 120,
                                  40,
                                ),
                              ),
                              child: Text(
                                seconds == 0
                                    ? "Resend OTP"
                                    : "Resend in $seconds${isMobileDevice ? 's' : 's'}",
                                style: TextStyle(
                                  color: seconds == 0
                                      ? Color(0xFFB794F4)
                                      : Colors.white54,
                                  fontSize: smallFontSize,
                                  fontWeight: seconds == 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),

                            // Vertical divider
                            Container(
                              width: 1,
                              height: smallFontSize * 1.5,
                              margin: EdgeInsets.symmetric(horizontal: 8.0),
                              color: Colors.white24,
                            ),

                            // Change number button
                            TextButton(
                              onPressed: _showChangeNumberDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobileDevice ? 12.0 : 16.0,
                                  vertical: isMobileDevice ? 6.0 : 8.0,
                                ),
                                minimumSize: Size(
                                  isMobileDevice ? 100 : 120,
                                  40,
                                ),
                              ),
                              child: Text(
                                isMobileDevice ? "Change" : "Change Number",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: smallFontSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                  );
                },
                child: const Text(
                  "Go Back",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              UniconsLine.shield_check,
              color: Colors.green,
              size: smallFontSize * 1.2,
            ),
            const SizedBox(width: 6.0),
            Text(
              isMobileDevice ? "Secure OTP" : "OTP is secure and encrypted",
              style: TextStyle(
                color: Colors.white54,
                fontSize: smallFontSize * 0.9,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        Text(
          isMobileDevice
              ? "Didn't get code? Check SMS"
              : "Didn't receive the code? Check your SMS or try resending",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
            fontSize: smallFontSize * 0.85,
          ),
        ),
      ],
    );
  }

  String maskedPhone(String phone) {
    if (phone.length < 10) return phone;
    return "${phone.substring(0, 3)}XXXXXX${phone.substring(phone.length - 4)}";
  }
}

class ScanningLockIcon extends StatefulWidget {
  final double size;

  const ScanningLockIcon({super.key, required this.size});

  @override
  State<ScanningLockIcon> createState() => _ScanningLockIconState();
}

class _ScanningLockIconState extends State<ScanningLockIcon>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  late AnimationController _unlockController;
  late Animation<double> _unlockScaleAnimation;
  late Animation<double> _unlockGlowAnimation;
  late AnimationController _particleController;
  late Animation<double> _particleAnimation;
  late AnimationController _shieldGlowController;
  late Animation<double> _shieldGlowAnimation;

  bool unlocked = false;

  @override
  void initState() {
    super.initState();

    // Scan animation controller (radar style)
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Scanning line movement from top to bottom with easing
    _scanAnimation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(
              begin: -1.0,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 50.0,
          ),
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.0,
              end: -1.0,
            ).chain(CurveTween(curve: Curves.easeInOut)),
            weight: 50.0,
          ),
        ]).animate(
          CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
        );

    // Unlock animation controller
    _unlockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Unlock scale animation with multiple bounces
    _unlockScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.4,
          end: 0.8,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.8,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 0.9,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 10.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.9,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50.0,
      ),
    ]).animate(_unlockController);

    // Unlock glow animation
    _unlockGlowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.5,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 0.8,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30.0,
      ),
    ]).animate(_unlockController);

    // Particle animation controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );

    // Shield glow animation for locked state
    _shieldGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _shieldGlowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.3,
          end: 0.8,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.8,
          end: 0.3,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.3,
          end: 0.5,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.5,
          end: 0.3,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25.0,
      ),
    ]).animate(_shieldGlowController);

    startLoop();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _unlockController.dispose();
    _particleController.dispose();
    _shieldGlowController.dispose();
    super.dispose();
  }

  Future<void> startLoop() async {
    // Start shield glow continuously
    _shieldGlowController.repeat();

    while (mounted) {
      // LOCK STATE
      setState(() {
        unlocked = false;
      });

      // Reset controllers
      _unlockController.reset();
      _particleController.reset();

      // Play scan animation
      await _scanController.forward(from: 0.0);

      // UNLOCK STATE
      setState(() {
        unlocked = true;
      });

      // Play unlock and particle animations
      _unlockController.forward(from: 0.0);
      _particleController.forward(from: 0.0);

      // Wait before next cycle
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double iconSize = widget.size;

    // Responsive scan line height
    final double scanLineHeight = iconSize * 0.06;
    final double minScanLineHeight = 2.5;
    final double maxScanLineHeight = 5.0;
    final double adjustedScanLineHeight = scanLineHeight.clamp(
      minScanLineHeight,
      maxScanLineHeight,
    );

    final double scanLineRadius = adjustedScanLineHeight * 0.5;

    return SizedBox(
      height: iconSize,
      width: iconSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          /// Shield glow effect for locked state
          if (!unlocked)
            AnimatedBuilder(
              animation: _shieldGlowAnimation,
              builder: (context, child) {
                return Container(
                  width: iconSize * 1.2,
                  height: iconSize * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withOpacity(
                          _shieldGlowAnimation.value * 0.3,
                        ),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                );
              },
            ),

          /// Particle effects during unlock
          if (unlocked && _particleAnimation.value < 1.0)
            AnimatedBuilder(
              animation: _particleAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(iconSize * 1.5, iconSize * 1.5),
                  painter: ParticlePainter(
                    progress: _particleAnimation.value,
                    color: Colors.greenAccent,
                  ),
                );
              },
            ),

          /// LOCK / UNLOCK ICON
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation.drive(
                    Tween<double>(
                      begin: 0.3,
                      end: 1.0,
                    ).chain(CurveTween(curve: Curves.easeOutBack)),
                  ),
                  child: child,
                ),
              );
            },
            child: unlocked
                ? AnimatedBuilder(
                    animation: Listenable.merge([
                      _unlockController,
                      _unlockGlowAnimation,
                    ]),
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow effect
                          Container(
                            width: iconSize * 1.3,
                            height: iconSize * 1.3,
                            decoration: BoxDecoration(shape: BoxShape.circle),
                          ),
                          // Icon with scale
                          Transform.scale(
                            scale: _unlockScaleAnimation.value,
                            child: Icon(
                              Icons.verified_user_rounded,
                              key: const ValueKey("verified"),
                              size: iconSize,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : Stack(
                    key: const ValueKey("lock"),
                    alignment: Alignment.center,
                    children: [
                      // Shield background
                      Icon(
                        Icons.shield_outlined,
                        size: iconSize,
                        color: Colors.white,
                      ),

                      // Lock inside shield
                      Icon(
                        Icons.lock_outline_rounded,
                        size: iconSize * 0.35,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),

          /// SCANNING LINE with radar effect
          if (!unlocked)
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                final double scanPosition =
                    ((_scanAnimation.value + 1) / 2) *
                    (iconSize - adjustedScanLineHeight);

                return Positioned(
                  top: scanPosition,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: iconSize * 0.95,
                      height: adjustedScanLineHeight,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.35),
                            Colors.white,
                            Colors.white.withOpacity(0.35),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(scanLineRadius),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Custom painter for particle effects
class ParticlePainter extends CustomPainter {
  final double progress;
  final Color color;

  ParticlePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(1.0 - progress)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final random = DateTime.now().millisecondsSinceEpoch;

    // Draw 8 particles radiating outward
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 + random) * 3.14159 / 180;
      final distance = progress * size.width * 0.8;
      final dx = center.dx + distance * cos(angle);
      final dy = center.dy + distance * sin(angle);

      final particleSize = (1.0 - progress) * 6;
      canvas.drawCircle(Offset(dx, dy), particleSize, paint);
    }

    // Draw extra particles in random directions
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 + random + 15) * 3.14159 / 180;
      final distance = progress * size.width * 0.6;
      final dx = center.dx + distance * cos(angle);
      final dy = center.dy + distance * sin(angle);

      final particleSize = (1.0 - progress) * 4;
      canvas.drawCircle(Offset(dx, dy), particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
