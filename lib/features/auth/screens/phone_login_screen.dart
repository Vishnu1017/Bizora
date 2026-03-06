import 'dart:ui';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/auth_state.dart';
import 'package:bizora/features/auth/screens/otp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bizora/features/auth/auth_bloc.dart';
import 'package:bizora/features/auth/auth_event.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final phoneController = TextEditingController();
  final FocusNode phoneFocus = FocusNode();
  String? phoneError;

  /// ================================
  /// PHONE VALIDATION
  /// ================================
  bool isValidPhone(String phone) {
    return RegExp(r'^[6-9]\d{9}$').hasMatch(phone);
  }

  /// ================================
  /// SEND OTP
  /// ================================
  void sendOtp(BuildContext context) {
    final phone = phoneController.text.trim();

    if (phone.isEmpty) {
      FirebaseSnackbar.error(context, "Phone number required");
      return;
    }

    if (!isValidPhone(phone)) {
      FirebaseSnackbar.error(context, "Enter valid Indian mobile number");
      return;
    }

    FocusScope.of(context).unfocus();

    context.read<AuthBloc>().add(PhoneLoginRequested(phone: "+91$phone"));
  }

  void validatePhone() {
    final phone = phoneController.text.trim();

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

    setState(() {});
  }

  /// ================================
  /// CLEANUP
  /// ================================
  @override
  void dispose() {
    phoneController.dispose();
    phoneFocus.dispose();
    super.dispose();
  }

  /// ================================
  /// BUILD
  /// ================================
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;

    final bool isTablet = size.width >= 600;
    final bool isDesktop = size.width >= 1100;

    final double horizontalPadding = isDesktop
        ? size.width * 0.35
        : isTablet
        ? size.width * 0.25
        : 14;

    final double titleSize = isDesktop
        ? 32
        : isTablet
        ? 28
        : 24;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        /// SAFE AREA
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 20,
                    ),

                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          /// =====================================
                          /// HEADER
                          /// =====================================
                          Column(
                            children: [
                              const Icon(
                                Icons.phone_android,
                                size: 60,
                                color: Colors.white,
                              ),

                              const SizedBox(height: 10),

                              Text(
                                "Login with Phone",
                                style: TextStyle(
                                  fontSize: titleSize,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                "Enter your mobile number to continue",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          /// =====================================
                          /// GLASS CARD
                          /// =====================================
                          ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),

                              child: Container(
                                padding: const EdgeInsets.all(22),

                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),

                                child: Column(
                                  children: [
                                    /// PHONE FIELD
                                    Row(
                                      children: [
                                        /// COUNTRY CODE
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.08,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            "+91",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 10),

                                        /// INPUT
                                        Expanded(
                                          child: TextField(
                                            controller: phoneController,
                                            focusNode: phoneFocus,
                                            keyboardType: TextInputType.number,
                                            maxLength: 10,

                                            /// 🔒 ONLY NUMBERS ALLOWED
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                10,
                                              ),
                                            ],

                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),

                                            decoration: InputDecoration(
                                              counterText: "",
                                              hintText: "Enter 10-digit number",
                                              hintStyle: const TextStyle(
                                                color: Colors.white54,
                                              ),
                                              filled: true,
                                              fillColor: Colors.white
                                                  .withOpacity(0.08),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 22),

                                    /// SEND OTP BUTTON
                                    SizedBox(
                                      width: double.infinity,
                                      height: 55,

                                      child: ElevatedButton(
                                        onPressed: state is AuthLoading
                                            ? null
                                            : () {
                                                validatePhone();

                                                if (phoneError != null) return;

                                                final phone = phoneController
                                                    .text
                                                    .trim();

                                                context.read<AuthBloc>().add(
                                                  PhoneLoginRequested(
                                                    phone: "+91$phone",
                                                  ),
                                                );
                                              },

                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),

                                        child: Ink(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF7F00FF),
                                                Color(0xFFE100FF),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),

                                          child: Center(
                                            child: state is AuthLoading
                                                ? const SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Text(
                                                    "Send OTP",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 15),

                                    /// BACK BUTTON
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        "Back to Login",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          /// TERMS
                          const Text(
                            "By continuing, you agree to our Terms & Privacy Policy",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
}
