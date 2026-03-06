import 'dart:async';

import 'package:bizora/features/owner/screens/owner_navbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bizora/features/customer/screens/customer_navbar.dart';

class WaitingScreen extends StatefulWidget {
  final String? message;
  final bool showCustomerOption;

  const WaitingScreen({
    super.key,
    this.message,
    this.showCustomerOption = true,
  });

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  int _secondsElapsed = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _listenApproval();
    _startTimer();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _getWaitingMessage() {
    if (_secondsElapsed < 30) {
      return "Your application is being reviewed";
    } else if (_secondsElapsed < 60) {
      return "Reviews typically take 24-48 hours";
    } else {
      return "Thank you for your patience";
    }
  }

  /// 🔥 REALTIME LISTENER
  void _listenApproval() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // If no user, redirect to login after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CustomerNavbar()),
          );
        }
      });
      return;
    }

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
          if (!mounted) return;
          if (!doc.exists) return;

          final data = doc.data();
          if (data == null) return;

          final role = data['role']?.toString().toLowerCase();
          final isApproved = data['isApproved'] ?? false;
          final applicationStatus = data['applicationStatus'] ?? 'pending';

          print("WaitingScreen - Role: $role, Approved: $isApproved");

          /// ✅ AUTO NAVIGATE WHEN APPROVED
          if (role == 'owner' && isApproved == true) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OwnerNavbar()),
            );
          }

          /// 🔄 If rejected, maybe show message
          if (applicationStatus == 'rejected') {
            _showRejectionDialog();
          }
        });
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Icon(Icons.cancel_outlined, color: Colors.red, size: 60),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Application Rejected",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your owner application has been rejected. You can continue as a customer or apply again later.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerNavbar()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Continue as Customer"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _goBack() {
    // Navigate back to customer navbar
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomerNavbar()),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _userSubscription?.cancel();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Allow back button and navigate to customer navbar
        _goBack();
        return false; // We handle navigation manually
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade800,
                Colors.deepPurple.shade600,
                Colors.purple.shade400,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /// 🔥 ANIMATED ICON
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer rotating ring
                        AnimatedBuilder(
                          animation: _rotateAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotateAnimation.value,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Middle pulsing ring
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 120 * _pulseAnimation.value,
                              height: 120 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.1),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),

                        // Inner icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.hourglass_empty,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    /// TITLE
                    const Text(
                      "APPLICATION UNDER REVIEW",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    /// MESSAGE
                    Text(
                      widget.message ?? _getWaitingMessage(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    /// TIMER INFO
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Colors.white70,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatWaitingTime(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// CUSTOM PROGRESS INDICATOR
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        backgroundColor: Colors.white.withOpacity(0.2),
                        strokeWidth: 3,
                      ),
                    ),

                    const SizedBox(height: 40),

                    /// STATUS CARD
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.white70,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "What happens next?",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStepIndicator(
                            "Admin reviews your application",
                            isCompleted: false,
                          ),
                          _buildStepIndicator(
                            "Verification of documents",
                            isCompleted: false,
                          ),
                          _buildStepIndicator(
                            "Final approval",
                            isCompleted: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    /// BACK TO CUSTOMER BUTTON
                    ElevatedButton.icon(
                      onPressed: _goBack,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text(
                        "Back to Customer Dashboard",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.15),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// CONTACT SUPPORT
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Need help? Contact support",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
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
  }

  String _formatWaitingTime() {
    if (_secondsElapsed < 60) {
      return "Waiting for ${_secondsElapsed}s";
    } else if (_secondsElapsed < 3600) {
      final minutes = (_secondsElapsed / 60).floor();
      return "Waiting for ${minutes}m";
    } else {
      final hours = (_secondsElapsed / 3600).floor();
      return "Waiting for ${hours}h";
    }
  }

  Widget _buildStepIndicator(String text, {required bool isCompleted}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? Colors.green : Colors.white.withOpacity(0.2),
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
