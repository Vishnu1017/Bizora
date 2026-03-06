import 'dart:ui';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/auth_bloc.dart';
import 'package:bizora/features/auth/auth_event.dart';
import 'package:bizora/features/auth/auth_state.dart';
import 'package:bizora/features/auth/screens/UnifiedNavbar.dart';
import 'package:bizora/features/auth/screens/otp_screen.dart';
import 'package:bizora/features/auth/screens/phone_login_screen.dart';
import 'package:bizora/features/auth/screens/signup_screen.dart';
import 'package:bizora/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:unicons/unicons.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passController = TextEditingController();

  bool obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final isTablet = width > 600;
    final horizontalPadding = isTablet ? width * 0.30 : 14.0;

    return BlocProvider(
      create: (_) => AuthBloc(AuthRepository()),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthSuccess) {
                  final role = state.role;

                  if (role == "owner") {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const UnifiedNavbar()),
                    );
                  } else if (role == "admin") {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const UnifiedNavbar()),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const UnifiedNavbar()),
                    );
                  }
                }

                if (state is AuthFailure) {
                  FirebaseSnackbar.error(context, state.message);
                }

                if (state is OtpSent) {
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
              },

              builder: (context, state) {
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.storefront,
                            size: 70,
                            color: Colors.white,
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            "Bizora",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 6),

                          const Text(
                            "Smart Local Marketplace",
                            style: TextStyle(color: Colors.white70),
                          ),

                          const SizedBox(height: 20),

                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Welcome Back 👋",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),

                                    const SizedBox(height: 15),

                                    _buildTextField(
                                      controller: emailController,
                                      hint: "Email",
                                      icon: Icons.email_outlined,
                                    ),

                                    const SizedBox(height: 12),

                                    _buildTextField(
                                      controller: passController,
                                      hint: "Password",
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                    ),

                                    const SizedBox(height: 5),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      const SignupScreen(),
                                                ),
                                              );
                                            },
                                            child: const Text.rich(
                                              TextSpan(
                                                text: "No account yet? ",
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: "Sign up",
                                                    style: TextStyle(
                                                      color:
                                                          Colors.purpleAccent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        TextButton(
                                          onPressed: () {
                                            _showResetDialog(context);
                                          },
                                          child: const Text(
                                            "Forgot Password?",
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                          ),
                                        ),

                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Text(
                                            "OR",
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),

                                        Expanded(
                                          child: Container(
                                            height: 1,
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 20),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 55,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          context.read<AuthBloc>().add(
                                            GoogleLoginRequested(),
                                          );
                                        },
                                        icon: const Icon(UniconsLine.google),
                                        label: const Text(
                                          "Continue with Google",
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black87,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 55,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => BlocProvider.value(
                                                value: context.read<AuthBloc>(),
                                                child: const PhoneLoginScreen(),
                                              ),
                                            ),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: Colors.white70,
                                            width: 1.5,
                                          ),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          "Login with Phone OTP",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 24),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 55,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (emailController.text.isEmpty ||
                                              passController.text.isEmpty) {
                                            FirebaseSnackbar.error(
                                              context,
                                              "Please fill all fields",
                                            );
                                            return;
                                          }

                                          context.read<AuthBloc>().add(
                                            LoginRequested(
                                              email: emailController.text
                                                  .trim(),
                                              password: passController.text
                                                  .trim(),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black87,
                                          elevation: 6, // Higher elevation
                                          shadowColor: Colors.purple
                                              .withOpacity(
                                                0.4,
                                              ), // Colored shadow
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: const BorderSide(
                                              // Subtle border
                                              color: Color(0xFF7F00FF),
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Small icon to make it distinct
                                            Container(
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              child: const Icon(
                                                Icons.login_rounded,
                                                color: Color(0xFF7F00FF),
                                                size: 20,
                                              ),
                                            ),
                                            const Text(
                                              "Login",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w700, // Bolder
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "By continuing you agree to our Terms & Privacy Policy",
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscurePassword : false,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              )
            : null,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    final resetController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: SingleChildScrollView(
              child: Container(
                width: screenWidth > 600 ? 420 : double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1E2E), const Color(0xFF2D2D3A)]
                        : [Colors.white, Colors.grey.shade50],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// HEADER
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade700,
                            Colors.deepPurpleAccent.shade400,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_reset, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            "Reset Password",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    /// CONTENT
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            "Enter your registered email address and we'll send you a password reset link.",
                            style: TextStyle(fontSize: 13),
                          ),

                          const SizedBox(height: 20),

                          TextField(
                            controller: resetController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.email_outlined),
                              hintText: "Enter your email",
                            ),
                          ),

                          const SizedBox(height: 25),

                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cancel"),
                                ),
                              ),

                              const SizedBox(width: 12),

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
                                        "Password reset link sent to your email",
                                      );
                                    } catch (e) {
                                      FirebaseSnackbar.error(
                                        context,
                                        "Failed to send reset email",
                                      );
                                    }
                                  },
                                  child: const Text("Send Link"),
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
          ),
        );
      },
    );
  }
}
