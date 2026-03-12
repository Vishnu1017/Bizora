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
    context.read<AuthBloc>().add(PhoneLoginRequested(phone: "+91$phone"));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final width = size.width;
    final height = size.height;

    // Responsive breakpoints
    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1100;
    final bool isDesktop = width >= 1100;

    // Dynamic padding
    final double horizontalPadding = isDesktop
        ? width * 0.35
        : isTablet
        ? width * 0.20
        : 16;

    // Card width constraints
    final double cardWidth = isMobile ? width : (isTablet ? 480 : 520);

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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<AuthBloc>(),
                      child: OtpScreen(verificationId: state.verificationId),
                    ),
                  ),
                );
              }
              if (state is AuthFailure) {
                FirebaseSnackbar.error(context, state.message);
              }
            },
            builder: (context, state) {
              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isMobile ? 20 : 30,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cardWidth,
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

                              _buildPhoneCard(
                                context,
                                isMobile,
                                isDesktop,
                                state,
                              ),

                              SizedBox(height: isMobile ? 20 : 24),

                              _buildFooter(isMobile),
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

  Widget _buildHeader(bool isMobile, bool isDesktop, AuthState state) {
    return Column(
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                UniconsLine.mobile_android,
                size: isMobile ? 60 : (isDesktop ? 80 : 70),
                color: Colors.white,
              ),
              if (state is AuthLoading)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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

        const SizedBox(height: 16),

        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB794F4)],
          ).createShader(bounds),
          child: Text(
            "Phone Login",
            style: TextStyle(
              fontSize: isMobile ? 28 : (isDesktop ? 36 : 32),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Verify your mobile number",
          style: TextStyle(
            color: Colors.white70,
            fontSize: isMobile ? 14 : 16,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneCard(
    BuildContext context,
    bool isMobile,
    bool isDesktop,
    AuthState state,
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
              /// Phone Input Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCountryCode(isMobile),
                  const SizedBox(width: 12),
                  Expanded(child: _buildPhoneField(isMobile, state)),
                ],
              ),

              if (phoneError != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        UniconsLine.exclamation_triangle,
                        color: Colors.redAccent,
                        size: isMobile ? 14 : 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          phoneError!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              /// Phone Preview
              if (phoneNumber != null &&
                  phoneNumber!.length == 10 &&
                  phoneError == null)
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "OTP will be sent to +91 $phoneNumber",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              /// Send OTP Button
              _buildSendOtpButton(context, isMobile, state),

              const SizedBox(height: 16),

              /// Back Button
              _buildBackButton(isMobile),

              const SizedBox(height: 12),

              /// Info Text
              _buildInfoText(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryCode(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 18,
        vertical: isMobile ? 16 : 18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.phone_outlined,
            size: isMobile ? 18 : 20,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            "+91",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 16 : 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField(bool isMobile, AuthState state) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
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
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          counterText: "",

          prefixIcon: Icon(
            Icons.phone_outlined,
            color: Colors.white70,
            size: isMobile ? 20 : 22,
          ),

          suffixIcon: phoneController.text.length == 10
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : null,

          hintText: "Enter 10-digit number",
          hintStyle: TextStyle(
            color: Colors.white54,
            fontSize: isMobile ? 14 : 15,
          ),

          filled: true,
          fillColor: Colors.white.withOpacity(0.08),

          contentPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 20,
            vertical: isMobile ? 16 : 18,
          ),

          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 219, 219, 219),
              width: 2,
            ),
          ),

          errorText: phoneError,

          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),

          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
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
    BuildContext context,
    bool isMobile,
    AuthState state,
  ) {
    return Container(
      width: double.infinity,
      height: isMobile ? 52 : 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF7F00FF), Color(0xFFE100FF)],
        ),
      ),
      child: ElevatedButton(
        onPressed: state is AuthLoading ? null : () => sendOtp(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: state is AuthLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Sending OTP...",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 15 : 16,
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
                    size: isMobile ? 18 : 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Send OTP",
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
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

  Widget _buildBackButton(bool isMobile) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              UniconsLine.arrow_left,
              color: Colors.white70,
              size: isMobile ? 18 : 20,
            ),
            const SizedBox(width: 6),
            Text(
              "Back to Login",
              style: TextStyle(
                color: Colors.white70,
                fontSize: isMobile ? 14 : 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoText(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            UniconsLine.info_circle,
            color: Colors.blueAccent,
            size: isMobile ? 16 : 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You'll receive a 6-digit OTP via SMS to verify your number",
              style: TextStyle(
                color: Colors.blueAccent.shade100,
                fontSize: isMobile ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Column(
      children: [
        Text(
          "By continuing, you agree to our",
          style: TextStyle(color: Colors.white54, fontSize: isMobile ? 11 : 12),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Terms of Service",
              style: TextStyle(
                color: Colors.white70,
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
            Text(
              " and ",
              style: TextStyle(
                color: Colors.white54,
                fontSize: isMobile ? 11 : 12,
              ),
            ),
            Text(
              "Privacy Policy",
              style: TextStyle(
                color: Colors.white70,
                fontSize: isMobile ? 11 : 12,
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
