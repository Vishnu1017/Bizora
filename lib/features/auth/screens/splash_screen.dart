import 'dart:async';
import 'dart:math';
import 'package:bizora/features/auth/screens/UnifiedNavbar.dart';
import 'package:bizora/features/auth/screens/login_screen.dart';
import 'package:bizora/features/auth/screens/waiting_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<Offset> _slideFromLeft;
  late Animation<Offset> _slideFromRight;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _slideFromLeft = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _slideFromRight = Tween<Offset>(
      begin: const Offset(0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted || _hasNavigated) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _navigateToLogin();
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!mounted || _hasNavigated) return;

      final data = doc.data();

      if (data == null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'role': 'customer',
          'isApproved': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _navigateToCustomer();
        return;
      }

      final role = data['role']?.toString().toLowerCase() ?? "customer";
      final isApproved = data['isApproved'] ?? true;
      final hasAppliedForOwner = data['hasAppliedForOwner'] ?? false;

      if (role == "admin") {
        _navigateToAdmin();
        return;
      }

      if (role == "owner") {
        if (isApproved) {
          _navigateToOwner();
        } else {
          _navigateToWaiting(
            message: "Your owner application is being reviewed",
          );
        }

        return;
      }

      if (hasAppliedForOwner) {
        _navigateToWaiting(
          message: "Your owner application is pending approval",
        );
        return;
      }

      _navigateToCustomer();
    } catch (e) {
      if (!mounted || _hasNavigated) return;

      _navigateToCustomer();
    }
  }

  /// SAFE NAVIGATION WRAPPER
  void _safeNavigate(Widget page) {
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  void _navigateToLogin() {
    _safeNavigate(LoginScreen());
  }

  void _navigateToAdmin() {
    _safeNavigate(const UnifiedNavbar());
  }

  void _navigateToOwner() {
    _safeNavigate(const UnifiedNavbar());
  }

  void _navigateToCustomer() {
    _safeNavigate(const UnifiedNavbar());
  }

  void _navigateToWaiting({
    String message = "Your application is being reviewed",
  }) {
    _safeNavigate(WaitingScreen(message: message));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background with particles
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF16213e),
                  const Color(0xFF0f3460),
                ],
              ),
            ),
            child: Stack(
              children: List.generate(20, (index) {
                return Positioned(
                  left: (index * 37) % MediaQuery.of(context).size.width,
                  top: (index * 23) % MediaQuery.of(context).size.height,
                  child: TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: Duration(seconds: 3 + (index % 3)),
                    curve: Curves.easeInOut,
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: (0.1 + (value * 0.2)),
                        child: Container(
                          width: 2 + (index % 4),
                          height: 2 + (index % 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),

          // Animated waves at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 3),
              curve: Curves.easeInOut,
              builder: (context, double value, child) {
                return Opacity(
                  opacity: 0.3,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with scale and fade
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: SweepGradient(
                          colors: [
                            Colors.purple.withOpacity(0.3),
                            Colors.blue.withOpacity(0.3),
                            Colors.pink.withOpacity(0.3),
                            Colors.purple.withOpacity(0.3),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 2,
                            offset: const Offset(5, 5),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          "B",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 70,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(color: Colors.white70, blurRadius: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Animated text lines
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SlideTransition(
                      position: _slideFromLeft,
                      child: const Text(
                        "BIZ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(color: Colors.purple, blurRadius: 15),
                          ],
                        ),
                      ),
                    ),
                    SlideTransition(
                      position: _slideFromRight,
                      child: const Text(
                        "ORA",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          shadows: [Shadow(color: Colors.blue, blurRadius: 15)],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Tagline with animation
                FadeTransition(
                  opacity: _fade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.purple.shade200, Colors.blue.shade200],
                      ).createShader(bounds),
                      child: const Text(
                        "Empower Your Business",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // Modern loading indicator
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.linear,
                  builder: (context, double value, child) {
                    return SizedBox(
                      width: 60,
                      height: 60,
                      child: CustomPaint(
                        painter: _CustomProgressPainter(
                          progress: value,
                          color1: Colors.purple,
                          color2: Colors.blue,
                        ),
                      ),
                    );
                  },
                  onEnd: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          // Top-right decorative element
          Positioned(
            top: 50,
            right: 30,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutBack,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.purple.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom-left decorative element
          Positioned(
            bottom: 50,
            left: 30,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutBack,
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),

          // Version number
          Positioned(
            bottom: 20,
            right: 20,
            child: Text(
              'v1.0.0',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomProgressPainter extends CustomPainter {
  final double progress;
  final Color color1;
  final Color color2;

  _CustomProgressPainter({
    required this.progress,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius - 2, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color1, color2],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -90 * (3.14159 / 180),
      360 * progress * (3.14159 / 180),
      false,
      progressPaint,
    );

    // Inner dots
    if (progress > 0) {
      final angle = 360 * progress - 90;
      final radian = angle * (3.14159 / 180);
      final dotX = center.dx + (radius - 8) * cos(radian);
      final dotY = center.dy + (radius - 8) * sin(radian);

      final dotPaint = Paint()
        ..color = color2
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);

      // Glow effect
      final glowPaint = Paint()
        ..color = color2.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

      canvas.drawCircle(Offset(dotX, dotY), 6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CustomProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
