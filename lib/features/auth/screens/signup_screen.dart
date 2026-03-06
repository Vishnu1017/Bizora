import 'dart:ui';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  final confirmController = TextEditingController();

  final ValueNotifier<String> selectedRole = ValueNotifier<String>("customer");

  bool obscurePassword = true;
  bool obscureConfirm = true;

  String? emailError;
  String? passwordError;
  String? confirmError;

  bool isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  void validateAndSignup() async {
    setState(() {
      emailError = null;
      passwordError = null;
      confirmError = null;
    });

    if (!isValidEmail(emailController.text.trim())) {
      emailError = "Enter valid email";
    }

    if (passController.text.length < 6) {
      passwordError = "Minimum 6 characters required";
    }

    if (confirmController.text != passController.text) {
      confirmError = "Passwords do not match";
    }

    if (emailError == null && passwordError == null && confirmError == null) {
      await _signup(context);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final bool isMobile = size.width < 600;
    final bool isTablet = size.width >= 600 && size.width < 1100;
    final bool isDesktop = size.width >= 1100;

    double horizontalPadding = 14;

    if (isTablet) {
      horizontalPadding = size.width * 0.25;
    } else if (isDesktop) {
      horizontalPadding = size.width * 0.35;
    }

    /// RESPONSIVE CARD WIDTH
    double cardWidth = size.width;

    if (isMobile) {
      cardWidth = size.width;
    } else if (isTablet) {
      cardWidth = 420;
    } else {
      cardWidth = 450;
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 30,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          /// HEADER
                          Column(
                            children: [
                              const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 65,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                "Let’s Get Started 🚀",
                                style: TextStyle(
                                  fontSize: 26,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                "Create your account",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 35),

                          /// GLASS CARD
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    /// EMAIL
                                    _buildTextField(
                                      controller: emailController,
                                      hint: "Email",
                                      icon: Icons.email_outlined,
                                      error: emailError,
                                    ),

                                    const SizedBox(height: 18),

                                    /// PASSWORD
                                    _buildTextField(
                                      controller: passController,
                                      hint: "Password",
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                      error: passwordError,
                                      suffix: IconButton(
                                        icon: Icon(
                                          obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.white70,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            obscurePassword = !obscurePassword;
                                          });
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 18),

                                    /// CONFIRM PASSWORD
                                    _buildTextField(
                                      controller: confirmController,
                                      hint: "Confirm Password",
                                      icon: Icons.lock_outline,
                                      isPassword: true,
                                      error: confirmError,
                                      suffix: IconButton(
                                        icon: Icon(
                                          obscureConfirm
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.white70,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            obscureConfirm = !obscureConfirm;
                                          });
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 30),

                                    /// SIGNUP BUTTON
                                    SizedBox(
                                      width: double.infinity,
                                      height: 55,
                                      child: ElevatedButton(
                                        onPressed: validateAndSignup,
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
                                          child: const Center(
                                            child: Text(
                                              "Create Account",
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    /// LOGIN NAVIGATION
                                    Center(
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => LoginScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text.rich(
                                          TextSpan(
                                            text: "Already have an account? ",
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: "Login",
                                                style: TextStyle(
                                                  color: Colors.purpleAccent,
                                                  fontWeight: FontWeight.bold,
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
                          ),

                          const SizedBox(height: 25),

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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// TEXTFIELD (UNCHANGED)
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Widget? suffix,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText:
              isPassword &&
              (hint == "Password" ? obscurePassword : obscureConfirm),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white70),
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: Text(
              error,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// SIGNUP FUNCTION (UNCHANGED)
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
            'role': selectedRole.value,
            'isApproved': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

      FirebaseSnackbar.success(context, "Signup successful");

      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong";

      if (e.code == 'email-already-in-use') {
        message = "Email already registered. Please login.";
      } else if (e.code == 'weak-password') {
        message = "Password should be at least 6 characters.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format.";
      }

      FirebaseSnackbar.error(context, message);
    } catch (e) {
      FirebaseSnackbar.error(context, "Error: ${e.toString()}");
    }
  }
}
