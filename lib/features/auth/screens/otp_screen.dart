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

class OtpScreen extends StatefulWidget {
  final String verificationId;

  const OtpScreen({required this.verificationId, super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with CodeAutoFill {
  final List<TextEditingController> controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  int seconds = 30;
  Timer? timer;

  @override
  void initState() {
    super.initState();

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

    for (var c in controllers) {
      c.dispose();
    }

    for (var f in focusNodes) {
      f.dispose();
    }

    super.dispose();
  }

  void moveNext(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }
  }

  void _changePhoneNumber() {
    final phoneController = TextEditingController();
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 420 : size.width * 0.9,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                          ),
                          child: const Icon(
                            Icons.phone_iphone_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "Change Phone Number",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 22 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Enter a new number to receive OTP",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 24),

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
                                  horizontal: 14,
                                  vertical: 16,
                                ),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    right: BorderSide(color: Colors.white24),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Text(
                                      "🇮🇳",
                                      style: TextStyle(fontSize: 18),
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
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: "98765 43210",
                                    hintStyle: TextStyle(color: Colors.white54),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),

                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (phoneController.text.trim().length !=
                                      10) {
                                    FirebaseSnackbar.error(
                                      context,
                                      "Enter valid 10 digit phone number",
                                    );
                                    return;
                                  }

                                  Navigator.pop(context);

                                  final phone =
                                      "+91${phoneController.text.trim()}";

                                  context.read<AuthBloc>().add(
                                    PhoneLoginRequested(phone: phone),
                                  );

                                  setState(() {
                                    seconds = 30;
                                  });

                                  startTimer();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final isTablet = size.width > 600;

    final otpSize = size.width < 360 ? 45.0 : 50.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
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
              }
            },
            builder: (context, state) {
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? size.width * 0.28 : 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      children: [
                        /// ICON
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(.1),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          "OTP Verification",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          "Enter the 6 digit code sent to your phone",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),

                        const SizedBox(height: 40),

                        /// GLASS CARD
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.08),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.15),
                                ),
                              ),
                              child: Column(
                                children: [
                                  /// OTP BOXES
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(6, (index) {
                                      return SizedBox(
                                        width: otpSize,
                                        height: otpSize,
                                        child: TextField(
                                          controller: controllers[index],
                                          focusNode: focusNodes[index],
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          maxLength: 1,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            counterText: "",
                                            filled: true,
                                            fillColor: Colors.white.withOpacity(
                                              .08,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                          onChanged: (value) {
                                            moveNext(index, value);
                                          },
                                        ),
                                      );
                                    }),
                                  ),

                                  const SizedBox(height: 30),

                                  /// VERIFY BUTTON
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton(
                                      onPressed: state is AuthLoading
                                          ? null
                                          : () {
                                              final otp = getOtp();

                                              if (otp.length != 6) {
                                                FirebaseSnackbar.warning(
                                                  context,
                                                  "Enter complete OTP",
                                                );
                                                return;
                                              }

                                              context.read<AuthBloc>().add(
                                                VerifyOtpRequested(
                                                  verificationId:
                                                      widget.verificationId,
                                                  otp: otp,
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
                                              ? const CircularProgressIndicator(
                                                  color: Colors.white,
                                                )
                                              : const Text(
                                                  "Verify OTP",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  /// RESEND TIMER
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
                                          : "Resend in $seconds s",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),

                                  /// CHANGE NUMBER
                                  TextButton(
                                    onPressed: _changePhoneNumber,
                                    child: const Text(
                                      "Change Number",
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

  @override
  void codeUpdated() {
    final String? code = this.code;

    if (code != null && code.length == 6) {
      for (int i = 0; i < 6; i++) {
        controllers[i].text = code[i];
      }

      context.read<AuthBloc>().add(
        VerifyOtpRequested(verificationId: widget.verificationId, otp: code),
      );
    }
  }
}
