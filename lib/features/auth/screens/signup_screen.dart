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
    final width = size.width;
    final height = size.height;

    // Responsive breakpoints
    final bool isMobile = width < 600;
    final bool isTablet = width >= 600 && width < 1100;
    final bool isDesktop = width >= 1100;

    // Dynamic horizontal padding
    double horizontalPadding = isMobile
        ? 16
        : (isTablet ? width * 0.20 : width * 0.35);

    // Card width constraints
    double cardWidth = isMobile ? width : (isTablet ? 480 : 520);

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
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
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
                              _buildHeader(isMobile, isDesktop),

                              SizedBox(height: isMobile ? 24 : 32),

                              _buildFormCard(isMobile, isDesktop),

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
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isDesktop) {
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
          child:
              Icon(
                UniconsLine.user_plus,
                size: isMobile ? 60 : (isDesktop ? 80 : 70),
                color: Colors.white,
              ).animate().scale(
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
              ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFB794F4)],
          ).createShader(bounds),
          child: Text(
            "Create Account",
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
          "Join Bizora today",
          style: TextStyle(
            color: Colors.white70,
            fontSize: isMobile ? 14 : 16,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(bool isMobile, bool isDesktop) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAnimatedTextField(
                controller: emailController,
                hint: "Email Address",
                icon: UniconsLine.envelope,
                error: emailError,
                isMobile: isMobile,
              ),

              const SizedBox(height: 16),

              ValueListenableBuilder<bool>(
                valueListenable: isPasswordVisible,
                builder: (context, visible, child) {
                  return _buildAnimatedTextField(
                    controller: passController,
                    hint: "Password",
                    icon: UniconsLine.lock,
                    isPassword: true,
                    isPasswordVisible: visible,
                    onToggleVisibility: () =>
                        isPasswordVisible.value = !isPasswordVisible.value,
                    error: passwordError,
                    isMobile: isMobile,
                  );
                },
              ),

              const SizedBox(height: 16),

              ValueListenableBuilder<bool>(
                valueListenable: isConfirmVisible,
                builder: (context, visible, child) {
                  return _buildAnimatedTextField(
                    controller: confirmController,
                    hint: "Confirm Password",
                    icon: UniconsLine.lock,
                    isPassword: true,
                    isPasswordVisible: visible,
                    onToggleVisibility: () =>
                        isConfirmVisible.value = !isConfirmVisible.value,
                    error: confirmError,
                    isMobile: isMobile,
                  );
                },
              ),

              if (confirmController.text.isNotEmpty)
                _buildConfirmIndicator(isMobile),

              if (passController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildPasswordStrength(isMobile),
                const SizedBox(height: 10),
                _buildPasswordRequirements(isMobile),
              ],

              const SizedBox(height: 28),

              _buildSignUpButton(isMobile),

              const SizedBox(height: 20),

              _buildLoginLink(isMobile),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
            controller: controller,
            obscureText: isPassword ? !isPasswordVisible : false,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Colors.white70,
                size: isMobile ? 20 : 22,
              ),

              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? UniconsLine.eye
                            : UniconsLine.eye_slash,
                        color: Colors.white70,
                        size: isMobile ? 20 : 22,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,

              hintText: hint,
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

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),

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

              errorText: error,

              errorStyle: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),

              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),

              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.redAccent, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements(bool isMobile) {
    final password = passController.text;
    final hasMinLength = password.length >= 6;
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    final hasLetter = password.contains(RegExp(r'[a-zA-Z]'));

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Password must contain:",
            style: TextStyle(
              color: Colors.white70,
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildRequirementChip("6+ characters", hasMinLength, isMobile),
              _buildRequirementChip("Number", hasNumber, isMobile),
              _buildRequirementChip("Letter", hasLetter, isMobile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrength(bool isMobile) {
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
        const SizedBox(height: 10),

        Row(
          children: [
            Text(
              "Password Strength: ",
              style: TextStyle(
                color: Colors.white70,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        Row(
          children: List.generate(5, (index) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 6,
                decoration: BoxDecoration(
                  color: index < strength
                      ? color
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRequirementChip(String text, bool isMet, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: (isMet ? Colors.green : Colors.red).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
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
            size: isMobile ? 14 : 16,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : Colors.red,
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton(bool isMobile) {
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
        onPressed: isLoading ? null : validateAndSignup,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    "Create Account",
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

  Widget _buildLoginLink(bool isMobile) {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Already have an account? ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
              Text(
                "Sign In",
                style: TextStyle(
                  color: const Color(0xFFB794F4),
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                color: const Color(0xFFB794F4),
                fontWeight: FontWeight.bold,

                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Text(
      "By continuing, you agree to our Terms of Service and Privacy Policy",
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white54, fontSize: isMobile ? 11 : 12),
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
            'role': 'customer', // Default role
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

  Widget _buildConfirmIndicator(bool isMobile) {
    final password = passController.text;
    final confirm = confirmController.text;

    final bool isMatch = password == confirm && confirm.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isMobile ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: (isMatch ? Colors.green : Colors.red).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isMatch ? Colors.green : Colors.red).withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isMatch ? Icons.check_circle : Icons.cancel,
            color: isMatch ? Colors.green : Colors.red,
            size: isMobile ? 16 : 18,
          ),
          const SizedBox(width: 8),
          Text(
            isMatch ? "Passwords match" : "Passwords do not match",
            style: TextStyle(
              color: isMatch ? Colors.green : Colors.red,
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
