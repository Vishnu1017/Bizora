import 'dart:io';

import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/features/auth/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage>
    with TickerProviderStateMixin {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoggingOut = false;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // User data
  String _displayName = '';
  String _email = '';
  String _phone = '';
  String _photoURL = '';

  // Editing controllers
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  // Password visibility toggles
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Password strength indicators
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  double _passwordStrength = 0.0;

  // Animation controllers - declare them first
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _passwordStrengthController;
  late final AnimationController _currentPasswordFocusController;
  late final AnimationController _newPasswordFocusController;
  late final AnimationController _confirmPasswordFocusController;
  late final AnimationController _slideController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers FIRST
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _passwordStrengthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _currentPasswordFocusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _newPasswordFocusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _confirmPasswordFocusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Initialize text controllers
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    // Add listeners for password fields
    _newPasswordController.addListener(_checkPasswordStrength);
    _confirmPasswordController.addListener(_checkPasswordMatch);

    _fadeController.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    // Dispose text controllers
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    // Dispose animation controllers
    _fadeController.dispose();
    _passwordStrengthController.dispose();
    _currentPasswordFocusController.dispose();
    _newPasswordFocusController.dispose();
    _confirmPasswordFocusController.dispose();
    _slideController.dispose();

    super.dispose();
  }

  void _checkPasswordStrength() {
    final password = _newPasswordController.text;

    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

      // Calculate strength (0.0 to 1.0)
      int strength = 0;
      if (_hasMinLength) strength++;
      if (_hasUpperCase) strength++;
      if (_hasNumber) strength++;
      if (_hasSpecialChar) strength++;

      _passwordStrength = strength / 4.0;
    });

    // Animate strength bar
    if (_passwordStrength > 0) {
      _passwordStrengthController.forward();
    } else {
      _passwordStrengthController.reverse();
    }
  }

  void _checkPasswordMatch() {
    if (_newPasswordController.text.isNotEmpty) {
      // Just trigger rebuild for match check
      setState(() {});
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _displayName = user.displayName ?? 'Admin User';
        _email = user.email ?? 'admin@example.com';
        _phone = user.phoneNumber ?? 'No phone';
        _photoURL = user.photoURL ?? '';
        _nameController.text = _displayName;
        _phoneController.text = _phone;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });

        await _uploadProfileImage();
      }
    } catch (e) {
      _showSnackBar('Image selection failed');
    }
  }

  Future<void> _uploadProfileImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _selectedImage == null) return;

      setState(() => _isSaving = true);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      await storageRef.putFile(_selectedImage!);

      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firebase Auth
      await user.updatePhotoURL(downloadUrl);

      // Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoURL': downloadUrl},
      );

      setState(() {
        _photoURL = downloadUrl;
      });

      _showSnackBar('Profile image updated', isError: false);
    } catch (e) {
      _showSnackBar('Image upload failed');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_validateInputs()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      // ✅ SAVES TO FIREBASE AUTHENTICATION
      if (_nameController.text != _displayName) {
        await user.updateDisplayName(_nameController.text); // Saves to Auth
      }

      // ✅ SAVES TO FIREBASE AUTHENTICATION (if password changed)
      if (_newPasswordController.text.isNotEmpty) {
        // Re-authenticate first
        final credential = EmailAuthProvider.credential(
          email: _email,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);

        // Update password in Auth
        await user.updatePassword(_newPasswordController.text); // Saves to Auth
      }

      // ✅ SAVES TO FIRESTORE (your custom data)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'displayName': _nameController.text,
            'phone': _phoneController.text,
            'updatedAt': FieldValue.serverTimestamp(),
          }); // Saves to Firestore

      // Update local state
      setState(() {
        _displayName = _nameController.text;
        _phone = _phoneController.text;
        _isEditing = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      _showSnackBar('Profile updated successfully', isError: false);
    } catch (e) {
      _showSnackBar('Update failed: ${e.toString()}');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  bool _validateInputs() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Name cannot be empty');
      return false;
    }

    if (_newPasswordController.text.isNotEmpty) {
      if (_currentPasswordController.text.isEmpty) {
        _showSnackBar('Current password is required to change password');
        return false;
      }

      if (_newPasswordController.text.length < 6) {
        _showSnackBar('New password must be at least 6 characters');
        return false;
      }

      if (_newPasswordController.text != _confirmPasswordController.text) {
        _showSnackBar('New passwords do not match');
        return false;
      }
    }

    return true;
  }

  Future<void> _showLogoutConfirmation() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => _buildLogoutConfirmationDialog(),
    );

    if (shouldLogout == true) {
      _performLogout();
    }
  }

  Future<void> _performLogout() async {
    setState(() => _isLoggingOut = true);

    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Sign out from Google
      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.disconnect();
        await googleSignIn.signOut();
      }

      if (!mounted) return;

      // Navigate to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoggingOut = false);
      _showSnackBar('Logout failed: ${e.toString()}');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (isError) {
      FirebaseSnackbar.error(context, message);
    } else {
      FirebaseSnackbar.success(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final isDesktop = size.width >= 900;
    final isSmallPhone = size.width < 360;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildHeader(
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                      isSmallPhone: isSmallPhone,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Profile Card
                SliverToBoxAdapter(
                  child: _buildProfileCard(
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    isSmallPhone: isSmallPhone,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // Edit Form (when editing)
                if (_isEditing)
                  SliverToBoxAdapter(
                    child: _buildEditForm(
                      isTablet: isTablet,
                      isDesktop: isDesktop,
                      isSmallPhone: isSmallPhone,
                    ),
                  ),

                // Action Buttons
                SliverToBoxAdapter(
                  child: _buildActionButtons(
                    isTablet: isTablet,
                    isDesktop: isDesktop,
                    isSmallPhone: isSmallPhone,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),

          // Global Loading Overlay
          if (_isLoggingOut)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(child: _buildLogoutLoadingIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required bool isTablet,
    required bool isDesktop,
    required bool isSmallPhone,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
        vertical: 20,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallPhone ? 10 : 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4158D0), Color(0xFFC850C0)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4158D0).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: isSmallPhone ? 20 : 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin Profile',
                style: TextStyle(
                  fontSize: isSmallPhone ? 24 : 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Manage your account details',
                style: TextStyle(
                  fontSize: isSmallPhone ? 12 : 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required bool isTablet,
    required bool isDesktop,
    required bool isSmallPhone,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
      ),
      padding: EdgeInsets.all(isSmallPhone ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Image
          Stack(
            children: [
              Container(
                width: isSmallPhone ? 100 : 120,
                height: isSmallPhone ? 100 : 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4158D0), Color(0xFFC850C0)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4158D0).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _selectedImage != null
                    ? ClipOval(
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : _photoURL.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _photoURL,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : Center(
                        child: Text(
                          _displayName.isNotEmpty
                              ? _displayName[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallPhone ? 40 : 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              if (!_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: isSmallPhone ? 18 : 20,
                        color: const Color(0xFF4158D0),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Profile Info
          Text(
            _displayName,
            style: TextStyle(
              fontSize: isSmallPhone ? 20 : 24,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: isSmallPhone ? 14 : 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Administrator',
                  style: TextStyle(
                    fontSize: isSmallPhone ? 12 : 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Email
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: isSmallPhone ? 18 : 20,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _email,
                    style: TextStyle(
                      fontSize: isSmallPhone ? 14 : 16,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Phone
          if (_phone.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: isSmallPhone ? 18 : 20,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _phone,
                      style: TextStyle(
                        fontSize: isSmallPhone ? 14 : 16,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditForm({
    required bool isTablet,
    required bool isDesktop,
    required bool isSmallPhone,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
      ),
      padding: EdgeInsets.all(isSmallPhone ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4158D0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF4158D0),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Name Field
          _buildInputField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
            isSmallPhone: isSmallPhone,
          ),

          const SizedBox(height: 16),

          // Phone Field
          _buildInputField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            isSmallPhone: isSmallPhone,
          ),

          const SizedBox(height: 24),

          // Password Change Section with Animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change Password',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 16),

                // Current Password with animation
                AnimatedBuilder(
                  animation: _currentPasswordFocusController,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(
                        0,
                        _currentPasswordFocusController.isCompleted ? -5 : 0,
                        0,
                      ),
                      child: _buildPasswordField(
                        controller: _currentPasswordController,
                        label: 'Current Password',
                        icon: Icons.lock_outline_rounded,
                        isVisible: _showCurrentPassword,
                        onToggleVisibility: () {
                          setState(
                            () => _showCurrentPassword = !_showCurrentPassword,
                          );
                        },
                        isSmallPhone: isSmallPhone,
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            _currentPasswordFocusController.forward();
                          } else {
                            _currentPasswordFocusController.reverse();
                          }
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // New Password with animation
                AnimatedBuilder(
                  animation: _newPasswordFocusController,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(
                        0,
                        _newPasswordFocusController.isCompleted ? -5 : 0,
                        0,
                      ),
                      child: Column(
                        children: [
                          _buildPasswordField(
                            controller: _newPasswordController,
                            label: 'New Password',
                            icon: Icons.lock_reset_rounded,
                            isVisible: _showNewPassword,
                            onToggleVisibility: () {
                              setState(
                                () => _showNewPassword = !_showNewPassword,
                              );
                            },
                            isSmallPhone: isSmallPhone,
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                _newPasswordFocusController.forward();
                              } else {
                                _newPasswordFocusController.reverse();
                              }
                            },
                          ),

                          // Password Strength Indicator
                          if (_newPasswordController.text.isNotEmpty)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(top: 12),
                              child: Column(
                                children: [
                                  // Strength Bar
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: _passwordStrength,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  _getStrengthColor(),
                                                ),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${(_passwordStrength * 100).round()}%',
                                        style: TextStyle(
                                          fontSize: isSmallPhone ? 10 : 12,
                                          color: _getStrengthColor(),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Password Requirements
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      _buildRequirementChip(
                                        '8+ characters',
                                        _hasMinLength,
                                        isSmallPhone,
                                      ),
                                      _buildRequirementChip(
                                        'Uppercase',
                                        _hasUpperCase,
                                        isSmallPhone,
                                      ),
                                      _buildRequirementChip(
                                        'Number',
                                        _hasNumber,
                                        isSmallPhone,
                                      ),
                                      _buildRequirementChip(
                                        'Special',
                                        _hasSpecialChar,
                                        isSmallPhone,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Confirm Password with animation and match indicator
                AnimatedBuilder(
                  animation: _confirmPasswordFocusController,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(
                        0,
                        _confirmPasswordFocusController.isCompleted ? -5 : 0,
                        0,
                      ),
                      child: _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Confirm New Password',
                        icon: Icons.check_circle_outline_rounded,
                        isVisible: _showConfirmPassword,
                        onToggleVisibility: () {
                          setState(
                            () => _showConfirmPassword = !_showConfirmPassword,
                          );
                        },
                        isSmallPhone: isSmallPhone,
                        onFocusChange: (hasFocus) {
                          if (hasFocus) {
                            _confirmPasswordFocusController.forward();
                          } else {
                            _confirmPasswordFocusController.reverse();
                          }
                        },
                        suffixWidget: _confirmPasswordController.text.isNotEmpty
                            ? AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  _newPasswordController.text ==
                                          _confirmPasswordController.text
                                      ? Icons.check_circle_rounded
                                      : Icons.error_rounded,
                                  color:
                                      _newPasswordController.text ==
                                          _confirmPasswordController.text
                                      ? Colors.green
                                      : Colors.red,
                                  size: isSmallPhone ? 18 : 20,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 8),

                // Password Match Message
                if (_newPasswordController.text.isNotEmpty &&
                    _confirmPasswordController.text.isNotEmpty)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          _newPasswordController.text ==
                              _confirmPasswordController.text
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            _newPasswordController.text ==
                                _confirmPasswordController.text
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _newPasswordController.text ==
                                  _confirmPasswordController.text
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color:
                              _newPasswordController.text ==
                                  _confirmPasswordController.text
                              ? Colors.green
                              : Colors.red,
                          size: isSmallPhone ? 16 : 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _newPasswordController.text ==
                                    _confirmPasswordController.text
                                ? 'Passwords match'
                                : 'Passwords do not match',
                            style: TextStyle(
                              fontSize: isSmallPhone ? 11 : 12,
                              color:
                                  _newPasswordController.text ==
                                      _confirmPasswordController.text
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Helper Text
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: isSmallPhone ? 10 : 12,
                    color: Colors.grey.shade600,
                  ),
                  child: const Text(
                    'Leave password fields empty if you don\'t want to change it',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(String text, bool isMet, bool isSmallPhone) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallPhone ? 8 : 10,
        vertical: isSmallPhone ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: isMet ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMet ? Colors.green.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: isSmallPhone ? 10 : 12,
            color: isMet ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: isSmallPhone ? 8 : 10,
              color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStrengthColor() {
    if (_passwordStrength < 0.25) return Colors.red;
    if (_passwordStrength < 0.5) return Colors.orange;
    if (_passwordStrength < 0.75) return Colors.amber;
    return Colors.green;
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    required bool isSmallPhone,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: isSmallPhone ? 14 : 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: isSmallPhone ? 12 : 14,
          ),
          prefixIcon: Icon(icon, size: isSmallPhone ? 18 : 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isSmallPhone ? 12 : 16,
            vertical: isSmallPhone ? 12 : 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required bool isSmallPhone,
    Function(bool)? onFocusChange,
    Widget? suffixWidget,
  }) {
    return Focus(
      onFocusChange: onFocusChange,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: controller,
          obscureText: !isVisible,
          style: TextStyle(fontSize: isSmallPhone ? 14 : 16),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isSmallPhone ? 12 : 14,
            ),
            prefixIcon: Icon(icon, size: isSmallPhone ? 18 : 20),
            suffixIcon:
                suffixWidget ??
                IconButton(
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: isSmallPhone ? 18 : 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: onToggleVisibility,
                ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallPhone ? 12 : 16,
              vertical: isSmallPhone ? 12 : 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required bool isTablet,
    required bool isDesktop,
    required bool isSmallPhone,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : (isTablet ? 24 : 16),
        vertical: 16,
      ),
      child: Column(
        children: [
          if (_isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    label: 'Cancel',
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _nameController.text = _displayName;
                        _phoneController.text = _phone;
                        _currentPasswordController.clear();
                        _newPasswordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    isOutlined: true,
                    isSmallPhone: isSmallPhone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    label: 'Save Changes',
                    onPressed: _isSaving ? null : _updateProfile,
                    isLoading: _isSaving,
                    gradient: const [Color(0xFF4158D0), Color(0xFFC850C0)],
                    isSmallPhone: isSmallPhone,
                  ),
                ),
              ],
            ),
          ] else ...[
            _buildActionButton(
              label: 'Edit Profile',
              onPressed: () => setState(() => _isEditing = true),
              icon: Icons.edit_rounded,
              gradient: const [Color(0xFF4158D0), Color(0xFFC850C0)],
              isSmallPhone: isSmallPhone,
              fullWidth: true,
            ),

            const SizedBox(height: 12),

            _buildActionButton(
              label: 'Sign Out',
              onPressed: _showLogoutConfirmation,
              icon: Icons.logout_rounded,
              gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
              isSmallPhone: isSmallPhone,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    List<Color>? gradient,
    bool isOutlined = false,
    bool isLoading = false,
    bool fullWidth = false,
    required bool isSmallPhone,
  }) {
    if (isOutlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(vertical: isSmallPhone ? 12 : 14),
          minimumSize: fullWidth ? const Size(double.infinity, 0) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSmallPhone ? 14 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: EdgeInsets.zero,
        minimumSize: fullWidth ? const Size(double.infinity, 0) : null,
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient != null
              ? LinearGradient(colors: gradient)
              : LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade500],
                ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmallPhone ? 12 : 14),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: isSmallPhone ? 18 : 20,
                  height: isSmallPhone ? 18 : 20,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: Colors.white,
                        size: isSmallPhone ? 18 : 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallPhone ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildLogoutConfirmationDialog() {
    // Get screen size for responsive calculations
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;
    final isTablet = screenSize.width >= 600 && screenSize.width < 900;
    final isDesktop = screenSize.width >= 900;

    // Responsive sizing
    double getResponsiveValue({
      required double mobile,
      double? tablet,
      double? desktop,
    }) {
      if (isDesktop && desktop != null) return desktop;
      if (isTablet && tablet != null) return tablet;
      return mobile;
    }

    final double dialogWidth = getResponsiveValue(
      mobile: isSmallScreen ? 320 : 360,
      tablet: 400,
      desktop: 440,
    );

    final double iconSize = getResponsiveValue(
      mobile: isSmallScreen ? 40 : 48,
      tablet: 56,
      desktop: 64,
    );

    final double titleSize = getResponsiveValue(
      mobile: isSmallScreen ? 20 : 22,
      tablet: 24,
      desktop: 26,
    );

    final double messageSize = getResponsiveValue(
      mobile: isSmallScreen ? 14 : 15,
      tablet: 16,
      desktop: 17,
    );

    final double buttonHeight = getResponsiveValue(
      mobile: 44,
      tablet: 48,
      desktop: 52,
    );

    final double buttonFontSize = getResponsiveValue(
      mobile: 15,
      tablet: 16,
      desktop: 17,
    );

    final double spacing = getResponsiveValue(
      mobile: 20,
      tablet: 24,
      desktop: 28,
    );

    final double padding = getResponsiveValue(
      mobile: 24,
      tablet: 28,
      desktop: 32,
    );

    final double borderRadius = getResponsiveValue(
      mobile: 24,
      tablet: 28,
      desktop: 32,
    );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFFDFDFD)],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 50,
              offset: const Offset(0, 25),
              spreadRadius: -5,
            ),
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Warning Icon with Glow Effect
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 600),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Container(
                        width: iconSize * 1.8,
                        height: iconSize * 1.8,
                        decoration: BoxDecoration(
                          gradient: SweepGradient(
                            colors: [
                              Colors.red.shade50,
                              Colors.red.shade100,
                              Colors.red.shade50,
                            ],
                            transform: GradientRotation(value * 2),
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(
                                0.3 - (value * 0.1),
                              ),
                              blurRadius: 20 * value,
                              spreadRadius: 5 * value,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: iconSize * 1.2,
                            height: iconSize * 1.2,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.2),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.logout_rounded,
                                color: Colors.red.shade600,
                                size: iconSize * 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: spacing * 0.8),

                // Title with Gradient
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.red.shade700, Colors.red.shade500],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: spacing * 0.4),

                // Message with enhanced readability
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing * 0.3),
                  child: Text(
                    'Are you sure you want to sign out of your account?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: messageSize,
                      color: Colors.grey.shade700,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),

                // Session info for enterprise context
                SizedBox(height: spacing * 0.6),

                Container(
                  padding: EdgeInsets.all(spacing * 0.5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(borderRadius * 0.5),
                    border: Border.all(color: Colors.grey.shade200, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.security_rounded,
                        size: messageSize * 1.2,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(width: spacing * 0.3),
                      Flexible(
                        child: Text(
                          'You will be redirected to the login screen',
                          style: TextStyle(
                            fontSize: messageSize * 0.9,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: spacing),

                // Buttons with enhanced design
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: _buildDialogButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.pop(context, false),
                        isPrimary: false,
                        height: buttonHeight,
                        fontSize: buttonFontSize,
                        borderRadius: borderRadius * 0.5,
                      ),
                    ),

                    SizedBox(width: spacing * 0.5),

                    // Sign Out Button
                    Expanded(
                      child: _buildDialogButton(
                        label: 'Sign Out',
                        onPressed: () => Navigator.pop(context, true),
                        isPrimary: true,
                        height: buttonHeight,
                        fontSize: buttonFontSize,
                        borderRadius: borderRadius * 0.5,
                      ),
                    ),
                  ],
                ),

                // Enterprise footer
                SizedBox(height: spacing * 0.5),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Secure Session • v2.0.1',
                      style: TextStyle(
                        fontSize: messageSize * 0.8,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 6),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced button widget with hover effects for desktop
  Widget _buildDialogButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
    required double height,
    required double fontSize,
    required double borderRadius,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: StatefulBuilder(
        builder: (context, setState) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: height,
            decoration: BoxDecoration(
              gradient: isPrimary
                  ? LinearGradient(
                      colors: [Colors.red.shade600, Colors.red.shade500],
                    )
                  : null,
              color: isPrimary ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
              border: isPrimary
                  ? null
                  : Border.all(color: Colors.grey.shade300, width: 1.5),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                onHover: (hover) {
                  setState(() as VoidCallback);
                },
                borderRadius: BorderRadius.circular(borderRadius),
                splashColor: isPrimary
                    ? Colors.white.withOpacity(0.2)
                    : Colors.red.withOpacity(0.1),
                highlightColor: Colors.transparent,
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPrimary)
                        Icon(
                          Icons.logout_rounded,
                          size: fontSize * 1.2,
                          color: Colors.white,
                        ),
                      if (isPrimary) SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: isPrimary
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontSize: fontSize,
                          fontWeight: isPrimary
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.3,
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
    );
  }

  Widget _buildLogoutLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Circular Progress
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              children: [
                // Background circle
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                ),

                // Animated progress
                Center(
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF416C),
                      ),
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ),

                // Icon in center
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: const Color(0xFFFF416C),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Loading text
          const Text(
            'Signing Out',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 8),

          Text(
            'Please wait while we securely log you out...',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
