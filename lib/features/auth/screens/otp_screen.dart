import 'dart:async';
import 'dart:ui';
import 'package:bizora/core/utils/firebase_snackbar.dart';
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

  const OtpScreen({required this.verificationId, super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with CodeAutoFill, TickerProviderStateMixin {
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
    startTimer();
    listenForCode();

    if (widget.verificationId == "AUTO_VERIFIED") {
      Future.microtask(() {
        context.read<AuthBloc>().add(
          VerifyOtpRequested(verificationId: "AUTO_VERIFIED", otp: "000000"),
        );
      });
    }
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
    cancel();
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
          _verifyOtp();
        });
      }
    }
  }

  void _verifyOtp() {
    final otp = getOtp();
    if (otp.length != 6) {
      FirebaseSnackbar.warning(context, "Enter complete OTP");
      return;
    }

    context.read<AuthBloc>().add(
      VerifyOtpRequested(verificationId: widget.verificationId, otp: otp),
    );
  }

  void _showChangeNumberDialog() {
    final phoneController = TextEditingController();
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: 24,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1E1E2E), const Color(0xFF2D2D3A)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        UniconsLine.phone,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Change Number",
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      "Enter your new phone number to receive OTP",
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Phone Input
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                        color: Colors.white.withOpacity(0.08),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.white24),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "+91",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
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
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: "98765 43210",
                                hintStyle: TextStyle(color: Colors.white54),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                counterText: "",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final phone = phoneController.text.trim();
                              if (phone.length != 10) {
                                FirebaseSnackbar.error(
                                  context,
                                  "Enter valid 10 digit number",
                                );
                                return;
                              }

                              Navigator.pop(context);
                              context.read<AuthBloc>().add(
                                PhoneLoginRequested(phone: "+91$phone"),
                              );

                              setState(() => seconds = 30);
                              startTimer();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.deepPurpleAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Send OTP",
                              style: TextStyle(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1100;
    final bool isDesktop = width >= 1100;

    final double horizontalPadding = isDesktop
        ? width * 0.35
        : isTablet
        ? width * 0.20
        : 16;

    final double otpBoxSize = isMobile
        ? (width < 360 ? 42.0 : 48.0)
        : (isTablet ? 55.0 : 60.0);

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
            },
            builder: (context, state) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: isMobile ? 20 : 30,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 480,
                      maxHeight: height * 0.95,
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildHeader(isMobile, isDesktop, state),

                            SizedBox(height: isMobile ? 24 : 32),

                            _buildOtpCard(context, state, isMobile, otpBoxSize),

                            SizedBox(height: isMobile ? 20 : 24),

                            _buildFooter(isMobile),
                          ],
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

  Widget _buildHeader(bool isMobile, bool isDesktop, AuthState state) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(
                UniconsLine.lock_access,
                size: isMobile ? 50 : (isDesktop ? 70 : 60),
                color: Colors.white,
              ),
            ),
            if (state is AuthLoading)
              const Positioned(
                right: 0,
                bottom: 0,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ).animate().scale(
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
        ),

        const SizedBox(height: 16),

        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB794F4)],
          ).createShader(bounds),
          child: Text(
            "OTP Verification",
            style: TextStyle(
              fontSize: isMobile ? 26 : (isDesktop ? 34 : 30),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Enter the 6-digit code sent to your phone",
          style: TextStyle(
            color: Colors.white70,
            fontSize: isMobile ? 14 : 16,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOtpCard(
    BuildContext context,
    AuthState state,
    bool isMobile,
    double otpBoxSize,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isMobile ? 24 : 32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(isMobile ? 24 : 32),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Phone Number Display
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      UniconsLine.message,
                      color: Colors.blueAccent,
                      size: isMobile ? 18 : 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Code sent to +91 XXXXX${widget.verificationId.substring(0, 3)}",
                      style: TextStyle(
                        color: Colors.blueAccent.shade100,
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              /// OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return Container(
                    width: otpBoxSize,
                    height: otpBoxSize,
                    decoration: BoxDecoration(
                      color: otpBoxColors[index],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: controllers[index],
                      focusNode: focusNodes[index],
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      enabled: state is! AuthLoading,
                      obscureText: !isOtpVisible,
                      obscuringCharacter: '•',
                      textAlign: TextAlign.center,
                      cursorColor: Colors.white,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: "",
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        contentPadding: EdgeInsets.zero,

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),

                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),

                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 219, 219, 219),
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => moveNext(index, value),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 30),

              /// Verify Button
              Container(
                width: double.infinity,
                height: isMobile ? 52 : 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: state is AuthLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: state is AuthLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
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
                              size: isMobile ? 18 : 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Verify OTP",
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              /// Resend + Change
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: seconds == 0
                        ? () {
                            setState(() => seconds = 30);
                            startTimer();
                          }
                        : null,
                    child: Text(
                      seconds == 0
                          ? "Resend OTP"
                          : "Resend in $seconds seconds",
                      style: TextStyle(
                        color: seconds == 0
                            ? Colors.purpleAccent
                            : Colors.white54,
                      ),
                    ),
                  ),

                  Container(width: 1, height: 20, color: Colors.white24),

                  TextButton(
                    onPressed: _showChangeNumberDialog,
                    child: const Text(
                      "Change Number",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              UniconsLine.shield_check,
              color: Colors.green,
              size: isMobile ? 14 : 16,
            ),
            const SizedBox(width: 6),
            Text(
              "OTP is secure and encrypted",
              style: TextStyle(
                color: Colors.white54,
                fontSize: isMobile ? 11 : 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Didn't receive the code? Check your SMS or try resending",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: isMobile ? 10 : 11),
        ),
      ],
    );
  }

  @override
  void codeUpdated() {
    final String? code = this.code;

    if (code != null && code.length == 6 && !isAutoFilling) {
      setState(() {
        isAutoFilling = true;
      });

      for (int i = 0; i < 6; i++) {
        controllers[i].text = code[i];
        otpBoxColors[i] = Colors.green.withOpacity(0.2);
      }

      // Auto verify after SMS detection
      Future.delayed(const Duration(milliseconds: 500), () {
        context.read<AuthBloc>().add(
          VerifyOtpRequested(verificationId: widget.verificationId, otp: code),
        );
      });
    }
  }
}
