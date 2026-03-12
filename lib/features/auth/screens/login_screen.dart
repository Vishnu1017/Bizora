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
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passController = TextEditingController();

  bool obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    emailController.dispose();
    passController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;

    // Responsive breakpoints
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1200;
    final isDesktop = width >= 1200;

    // Dynamic padding based on screen size
    final horizontalPadding = isDesktop
        ? width * 0.35
        : isTablet
        ? width * 0.20
        : 16.0;

    // Dynamic card width
    final cardWidth = isDesktop
        ? 480.0
        : isTablet
        ? 450.0
        : double.infinity;

    return BlocProvider(
      create: (_) => AuthBloc(AuthRepository()),
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0C29),
                  Color(0xFF302B63),
                  Color(0xFF24243E),
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return BlocConsumer<AuthBloc, AuthState>(
                    listener: (context, state) {
                      if (state is AuthSuccess) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UnifiedNavbar(),
                          ),
                        );
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
                              child: OtpScreen(
                                verificationId: state.verificationId,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    builder: (context, state) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: isMobile ? 16 : 24,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: cardWidth,
                              maxHeight: height * (isDesktop ? 0.9 : 0.95),
                            ),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildLogoSection(isMobile, isDesktop),

                                    SizedBox(height: isMobile ? 16 : 24),

                                    _buildGlassCard(
                                      context,
                                      state,
                                      isMobile,
                                      isDesktop,
                                    ),

                                    SizedBox(height: isMobile ? 16 : 20),

                                    _buildFooter(isMobile),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(bool isMobile, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
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
                  Icons.storefront_rounded,
                  size: isMobile ? 60 : (isDesktop ? 90 : 75),
                  color: Colors.white,
                ).animate().scale(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                ),
          ),
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFB794F4)],
            ).createShader(bounds),
            child: Text(
              "Bizora",
              style: TextStyle(
                fontSize: isMobile ? 32 : (isDesktop ? 48 : 40),
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Smart Local Marketplace",
            style: TextStyle(
              color: Colors.white70,
              fontSize: isMobile ? 14 : 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(
    BuildContext context,
    AuthState state,
    bool isMobile,
    bool isDesktop,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(isMobile ? 24 : 32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 20 : 32),
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
              Row(
                children: [
                  Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.amber,
                    size: isMobile ? 22 : 26,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Welcome Back!",
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              _buildAnimatedTextField(
                controller: emailController,
                hint: "Email Address",
                icon: UniconsLine.envelope,
                isMobile: isMobile,
              ),

              const SizedBox(height: 16),

              _buildAnimatedTextField(
                controller: passController,
                hint: "Password",
                icon: UniconsLine.lock,
                isPassword: true,
                isMobile: isMobile,
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _buildSignUpLink(context, isMobile),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _buildForgotPassword(context, isMobile),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLoginButton(context, state, isMobile),

              const SizedBox(height: 20),

              _buildOrDivider(isMobile),

              const SizedBox(height: 20),

              _buildSocialLoginButtons(context, isMobile, isDesktop),
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
    required bool isMobile,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? obscurePassword : false,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      cursorColor: Colors.white, // cursor color
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70, size: isMobile ? 20 : 22),

        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscurePassword ? UniconsLine.eye_slash : UniconsLine.eye,
                  color: Colors.white70,
                  size: isMobile ? 20 : 22,
                ),
                onPressed: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
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
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
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
      ),
    );
  }

  Widget _buildSignUpLink(BuildContext context, bool isMobile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignupScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "New here? ",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
              Text(
                "Sign Up",
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

  Widget _buildForgotPassword(BuildContext context, bool isMobile) {
    return TextButton(
      onPressed: () => _showResetDialog(context),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        "Forgot Password?",
        style: TextStyle(
          color: Colors.white70,
          fontSize: isMobile ? 13 : 14,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white38,
        ),
      ),
    );
  }

  Widget _buildOrDivider(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.white.withOpacity(0.3)],
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "OR",
            style: TextStyle(
              color: Colors.white70,
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.3), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons(
    BuildContext context,
    bool isMobile,
    bool isDesktop,
  ) {
    return Row(
      children: [
        // Google Button
        Expanded(
          child: _buildSocialButton(
            icon: UniconsLine.google,
            label: "Google Sign-In",
            onPressed: () {
              context.read<AuthBloc>().add(GoogleLoginRequested());
            },
            isMobile: isMobile,
            isDesktop: isDesktop,
          ),
        ),
        const SizedBox(width: 12),
        // Phone Button
        Expanded(
          child: _buildSocialButton(
            icon: UniconsLine.phone,
            label: "Phone",
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
            isMobile: isMobile,
            isDesktop: isDesktop,
            isOutlined: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isMobile,
    required bool isDesktop,
    bool isOutlined = false,
  }) {
    return Container(
      height: isMobile ? 48 : 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isOutlined
            ? null
            : const LinearGradient(colors: [Colors.white, Color(0xFFF5F5F5)]),
      ),
      child: isOutlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: isMobile ? 18 : 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 4,
                shadowColor: Colors.purple.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.purple, size: isMobile ? 18 : 20),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLoginButton(
    BuildContext context,
    AuthState state,
    bool isMobile,
  ) {
    return Container(
      width: double.infinity,
      height: isMobile ? 52 : 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
      ),
      child: ElevatedButton(
        onPressed: state is AuthLoading
            ? null
            : () {
                if (emailController.text.isEmpty ||
                    passController.text.isEmpty) {
                  FirebaseSnackbar.error(context, "Please fill all fields");
                  return;
                }
                context.read<AuthBloc>().add(
                  LoginRequested(
                    email: emailController.text.trim(),
                    password: passController.text.trim(),
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: state is AuthLoading
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
                  const Icon(Icons.login_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    "Login to Dashboard",
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

  Widget _buildFooter(bool isMobile) {
    return Column(
      children: [
        Text(
          "By continuing you agree to our",
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

  void _showResetDialog(BuildContext context) {
    final resetController = TextEditingController();
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
            borderRadius: BorderRadius.circular(24),
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
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_reset_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      "Reset Password",
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
                    Text(
                      "Enter your registered email address to receive a password reset link.",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isMobile ? 13 : 14,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: resetController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          UniconsLine.envelope,
                          color: Colors.white70,
                        ),
                        hintText: "your@email.com",
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

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
                                  "Reset link sent to your email",
                                );
                              } catch (e) {
                                FirebaseSnackbar.error(
                                  context,
                                  "Failed to send reset email",
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
    );
  }
}
