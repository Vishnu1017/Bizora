import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:bizora/core/utils/profile_image_notifier.dart';
import 'package:bizora/features/auth/screens/splash_screen.dart';
import 'package:bizora/features/customer/screens/become_seller_info.dart';
import 'package:bizora/services/security_service.dart';
import 'package:bizora/widgets/logout_confirmation_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ImageAction { gallery, camera, remove }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Security
  final SecurityService _securityService = SecurityService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  // ignore: unused_field
  bool _isBiometricAvailable = false;
  bool _useBiometric = false;
  String? _sessionToken;

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1100;
  static const double largeDesktopBreakpoint = 1600;
  static const double ultraWideBreakpoint = 2000;

  // User data
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isOwner = false;
  bool _isLoading = true;
  bool _hasPendingApplication = false;
  bool _isUploading = false;

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  late AnimationController _refreshController;
  late Animation<double> _fadeAnimation;

  // Session management
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initializeSecurity();
    _loadUserData();
    _listenToUserChanges();
    _startSessionTimer();
  }

  void _initializeAnimations() {
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _refreshController, curve: Curves.easeIn),
    );

    _refreshController.forward();
  }

  // Helper methods for responsive design
  bool isMobile(double width) => width < mobileBreakpoint;
  bool isTablet(double width) =>
      width >= mobileBreakpoint && width < tabletBreakpoint;
  bool isSmallDesktop(double width) =>
      width >= tabletBreakpoint && width < desktopBreakpoint;
  bool isDesktop(double width) =>
      width >= desktopBreakpoint && width < largeDesktopBreakpoint;
  bool isLargeDesktop(double width) =>
      width >= largeDesktopBreakpoint && width < ultraWideBreakpoint;
  bool isUltraWide(double width) => width >= ultraWideBreakpoint;

  double getResponsiveHorizontalPadding(double width) {
    if (isUltraWide(width)) return width * 0.35;
    if (isLargeDesktop(width)) return width * 0.3;
    if (isDesktop(width)) return width * 0.25;
    if (isSmallDesktop(width)) return width * 0.2;
    if (isTablet(width)) return width * 0.15;
    return 20.0;
  }

  double getResponsiveVerticalSpacing(double width) {
    if (isUltraWide(width)) return 40.0;
    if (isLargeDesktop(width)) return 36.0;
    if (isDesktop(width)) return 32.0;
    if (isSmallDesktop(width)) return 28.0;
    if (isTablet(width)) return 24.0;
    return 20.0;
  }

  double getResponsiveFontSize(
    double width, {
    double mobile = 14.0,
    double tablet = 15.0,
    double smallDesktop = 16.0,
    double desktop = 17.0,
    double largeDesktop = 18.0,
    double ultraWide = 20.0,
  }) {
    if (isUltraWide(width)) return ultraWide;
    if (isLargeDesktop(width)) return largeDesktop;
    if (isDesktop(width)) return desktop;
    if (isSmallDesktop(width)) return smallDesktop;
    if (isTablet(width)) return tablet;
    return mobile;
  }

  double getResponsiveIconSize(double width) {
    if (isUltraWide(width)) return 32.0;
    if (isLargeDesktop(width)) return 28.0;
    if (isDesktop(width)) return 24.0;
    if (isSmallDesktop(width)) return 22.0;
    if (isTablet(width)) return 20.0;
    return 18.0;
  }

  double getResponsiveAvatarSize(double width) {
    if (isUltraWide(width)) return 80.0;
    if (isLargeDesktop(width)) return 70.0;
    if (isDesktop(width)) return 60.0;
    if (isSmallDesktop(width)) return 52.0;
    if (isTablet(width)) return 48.0;
    return 40.0;
  }

  double getResponsiveBorderRadius(double width) {
    if (isUltraWide(width)) return 32.0;
    if (isLargeDesktop(width)) return 28.0;
    if (isDesktop(width)) return 24.0;
    if (isSmallDesktop(width)) return 22.0;
    if (isTablet(width)) return 20.0;
    return 16.0;
  }

  double getResponsiveCardSpacing(double width) {
    if (isUltraWide(width)) return 20.0;
    if (isLargeDesktop(width)) return 18.0;
    if (isDesktop(width)) return 16.0;
    if (isSmallDesktop(width)) return 14.0;
    if (isTablet(width)) return 12.0;
    return 10.0;
  }

  EdgeInsets getResponsiveInsets(double width) {
    if (isUltraWide(width)) return const EdgeInsets.all(36.0);
    if (isLargeDesktop(width)) return const EdgeInsets.all(32.0);
    if (isDesktop(width)) return const EdgeInsets.all(28.0);
    if (isSmallDesktop(width)) return const EdgeInsets.all(24.0);
    if (isTablet(width)) return const EdgeInsets.all(20.0);
    return const EdgeInsets.all(16.0);
  }

  Future<void> _initializeSecurity() async {
    await _checkBiometricAvailability();
    if (_user != null) {
      await _initializeSession();
    }
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      _isBiometricAvailable =
          await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();

      final useBiometric = await _secureStorage.read(key: 'use_biometric');
      setState(() {
        _useBiometric = useBiometric == 'true';
      });
    } catch (e) {
      print('Biometric check failed: $e');
    }
  }

  Future<void> _initializeSession() async {
    if (_user != null) {
      _sessionToken = await _securityService.createSession(_user!.uid);
    }
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(minutes: 30), () {
      if (mounted) {
        _showSessionTimeoutDialog();
      }
    });
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _startSessionTimer();
  }

  void _showSessionTimeoutDialog() {
    final width = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(getResponsiveBorderRadius(width)),
        ),
        title: const Text('Session Expired'),
        content: const Text(
          'Your session has expired for security reasons. Please login again.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Login Again'),
          ),
        ],
      ),
    );
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to change sensitive information',
        biometricOnly: true,
      );
    } catch (e) {
      print('Biometric auth failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return await _securityService.getDeviceInfo();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    _user = FirebaseAuth.instance.currentUser;

    try {
      if (_user != null) {
        // Rate limiting check
        if (!_securityService.checkRateLimit(_user!.uid, 'load_profile')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              FirebaseSnackbar.error(
                context,
                'Too many attempts. Please try later.',
              );
            }
          });
          return;
        }

        // Validate session
        if (_sessionToken != null) {
          final isValid = await _securityService.validateSession(
            _user!.uid,
            _sessionToken!,
          );

          if (!isValid) {
            _showSessionTimeoutDialog();
            return;
          }
        }

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;

          // Account locked check
          if (data['accountLocked'] == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                FirebaseSnackbar.error(
                  context,
                  'Account locked: ${data['lockReason'] ?? 'Security reason'}',
                );
              }
            });
            return;
          }

          // Data integrity check
          final storedHash = data['dataHash'];

          if (storedHash != null) {
            final dataWithoutHash = Map<String, dynamic>.from(data)
              ..remove('dataHash');

            final isValid = _securityService.verifyDataIntegrity(
              dataWithoutHash,
              storedHash,
            );

            if (!isValid) {
              print("⚠️ Data hash mismatch detected. Regenerating hash.");

              try {
                final newHash = _securityService.generateAuditHash(
                  dataWithoutHash,
                );

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_user!.uid)
                    .update({"dataHash": newHash});

                print("✅ Hash regenerated successfully");
              } catch (e) {
                print("❌ Failed to regenerate hash: $e");
              }
            }
          }

          setState(() {
            _userData = data;

            final role = _userData?['role']?.toString().toLowerCase();
            final isApproved = _userData?['isApproved'] ?? false;

            _isOwner = role == 'owner' && isApproved;

            _hasPendingApplication =
                _userData?['hasAppliedForOwner'] == true &&
                _userData?['applicationStatus'] == 'pending';

            _nameController.text =
                _userData?['displayName'] ?? _user?.displayName ?? '';

            _phoneController.text =
                _userData?['phone'] ?? _user?.phoneNumber ?? '';

            _bioController.text = _userData?['bio'] ?? '';
          });

          _initializeTimestamps();
        }
      }
    } catch (e) {
      print('Error loading user data: $e');

      if (_user != null) {
        await _securityService.logSuspiciousActivity(
          _user!.uid,
          'Failed to load profile: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeTimestamps() {
    if (_userData != null && _user != null) {
      if (_userData!['phone'] != null &&
          _userData!['phoneLastUpdated'] == null) {
        FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
          'phoneLastUpdated': FieldValue.serverTimestamp(),
        });
      }
      if (_userData!['email'] != null &&
          _userData!['emailLastUpdated'] == null) {
        FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
          'emailLastUpdated': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> _saveProfileChangesWithEmail({
    required String name,
    required String phone,
    required String email,
    required String bio,
  }) async {
    if (_user == null) return;

    // Rate limiting check
    if (!_securityService.checkRateLimit(_user!.uid, 'update_profile')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FirebaseSnackbar.error(
            context,
            'Too many update attempts. Please try later.',
          );
        }
      });
      return;
    }

    // Validate session
    if (_sessionToken != null) {
      final isValid = await _securityService.validateSession(
        _user!.uid,
        _sessionToken!,
      );
      if (!isValid) {
        _showSessionTimeoutDialog();
        return;
      }
    }

    // Biometric authentication for sensitive changes
    if (_useBiometric &&
        (phone != _userData?['phone'] || email != _userData?['email'])) {
      final authenticated = await _authenticateWithBiometrics();
      if (!authenticated) {
        await _securityService.logSuspiciousActivity(
          _user!.uid,
          'Failed biometric auth for profile update',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            FirebaseSnackbar.error(context, 'Biometric authentication failed');
          }
        });
        return;
      }
    }

    try {
      // Get timestamps
      final Timestamp? phoneLastUpdated = _userData?['phoneLastUpdated'];
      final Timestamp? emailLastUpdated = _userData?['emailLastUpdated'];
      final now = DateTime.now();

      // Check cooldown periods
      bool canUpdatePhone = true;
      bool canUpdateEmail = true;
      int phoneDaysLeft = 0;
      int emailDaysLeft = 0;

      if (phoneLastUpdated != null) {
        final lastUpdate = phoneLastUpdated.toDate();
        final daysSinceUpdate = now.difference(lastUpdate).inDays;
        canUpdatePhone = daysSinceUpdate >= 30;
        phoneDaysLeft = 30 - daysSinceUpdate;
      }

      if (emailLastUpdated != null) {
        final lastUpdate = emailLastUpdated.toDate();
        final daysSinceUpdate = now.difference(lastUpdate).inDays;
        canUpdateEmail = daysSinceUpdate >= 30;
        emailDaysLeft = 30 - daysSinceUpdate;
      }

      // Determine if this is first time saving contact info
      final bool hasPhone =
          _userData?['phone'] != null &&
          _userData!['phone'].toString().isNotEmpty;
      final bool hasEmail =
          _userData?['email'] != null &&
          _userData!['email'].toString().isNotEmpty;

      // Flags to track if we should block save
      bool blockSave = false;

      if (hasPhone && phone.isNotEmpty && phone != _userData?['phone']) {
        if (!canUpdatePhone) {
          blockSave = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              FirebaseSnackbar.warning(
                context,
                'For security, phone can be changed in $phoneDaysLeft days',
              );
            }
          });
        }
      }

      if (hasEmail && email.isNotEmpty && email != _userData?['email']) {
        if (!canUpdateEmail) {
          blockSave = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              FirebaseSnackbar.warning(
                context,
                'For security, email can be changed in $emailDaysLeft days',
              );
            }
          });
        }
      }

      if (blockSave) {
        setState(() => _isLoading = false);
        return;
      }

      // Prepare update data
      Map<String, dynamic> updateData = {
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (phone.isNotEmpty) {
        if (!hasPhone || (canUpdatePhone && phone != _userData?['phone'])) {
          updateData['phone'] = phone;
          updateData['phoneLastUpdated'] = FieldValue.serverTimestamp();
        }
      }

      if (email.isNotEmpty) {
        if (!hasEmail || (canUpdateEmail && email != _userData?['email'])) {
          updateData['email'] = email;
          updateData['emailLastUpdated'] = FieldValue.serverTimestamp();
        }
      }

      if (name.isNotEmpty && name != _userData?['displayName']) {
        updateData['displayName'] = name;
      }

      if (bio != _userData?['bio']) {
        updateData['bio'] = bio;
      }

      // Add security metadata
      updateData['lastProfileUpdate'] = FieldValue.serverTimestamp();
      updateData['lastUpdateDevice'] = await _getDeviceInfo();
      updateData['lastUpdateSession'] = _sessionToken;

      // Generate audit hash
      final dataForHash = Map<String, dynamic>.from(updateData)
        ..remove('updatedAt')
        ..remove('lastProfileUpdate')
        ..remove('lastUpdateDevice')
        ..remove('lastUpdateSession');
      updateData['dataHash'] = _securityService.generateAuditHash(dataForHash);

      // Update Firestore
      if (updateData.length > 1) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .update(updateData);
      }

      // Update Auth if needed
      if (name.isNotEmpty && name != _user?.displayName) {
        await _user!.updateDisplayName(name);
      }

      if (updateData.containsKey('email') && email != _user?.email) {
        await _user!.verifyBeforeUpdateEmail(email);

        await _securityService.logSuspiciousActivity(
          _user!.uid,
          'Email change requested',
        );
      }

      // Reload data
      await _user?.reload();
      _user = FirebaseAuth.instance.currentUser;
      await _loadUserData();

      // Update UI
      setState(() {
        _nameController.text = name;
        _phoneController.text = phone;
        _bioController.text = bio;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FirebaseSnackbar.success(context, 'Profile updated securely!');
        }
      });
      _resetSessionTimer();
    } catch (e) {
      print('Error in secure save: $e');
      await _securityService.logSuspiciousActivity(
        _user!.uid,
        'Failed profile update: $e',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FirebaseSnackbar.error(context, 'Security error: Update failed');
        }
      });
    }
  }

  void _listenToUserChanges() {
    _user = FirebaseAuth.instance.currentUser;

    if (_user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .snapshots()
          .listen((doc) {
            if (doc.exists) {
              setState(() {
                _userData = doc.data();
                final role = _userData?['role']?.toString().toLowerCase();
                final isApproved = _userData?['isApproved'] ?? false;
                _isOwner = role == 'owner' && isApproved;
                _hasPendingApplication =
                    _userData?['hasAppliedForOwner'] == true &&
                    _userData?['applicationStatus'] == 'pending';
              });
            }
          });
    }
  }

  Future<void> _pickImage() async {
    if (_isUploading) return;

    try {
      final action = await showDialog<ImageAction>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Profile Picture'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageAction.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageAction.camera),
                ),
                if (_user?.photoURL != null)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Remove Photo'),
                    onTap: () => Navigator.pop(context, ImageAction.remove),
                  ),
              ],
            ),
          );
        },
      );

      if (action == null) return;

      if (action == ImageAction.remove) {
        _removeProfilePicture();
        return;
      }

      final source = action == ImageAction.camera
          ? ImageSource.camera
          : ImageSource.gallery;

      await Future.delayed(const Duration(milliseconds: 200));

      final picker = ImagePicker();
      final image = await picker.pickImage(source: source, imageQuality: 80);

      if (image != null) {
        await _uploadImageToFirebase(File(image.path));
      }
    } catch (e) {
      print("Image pick error: $e");
    }
  }

  Future<void> _uploadImageToFirebase(File imageFile) async {
    try {
      setState(() => _isUploading = true);

      final uid = _user!.uid;

      // 🔥 COMPRESS IMAGE (FAST)
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: 50,
        minWidth: 720,
        minHeight: 720,
        format: CompressFormat.jpeg,
      );

      // 🔥 STORAGE PATH
      final ref = FirebaseStorage.instance.ref().child(
        'profile_images/$uid/profile.jpg',
      );

      // 🔥 FAST UPLOAD
      final uploadTask = ref.putData(
        compressedBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 🔥 UPDATE AUTH
      await _user?.updatePhotoURL(downloadUrl);
      await _user?.reload();
      _user = FirebaseAuth.instance.currentUser;

      // 🔥 UPDATE FIRESTORE
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "photoURL": downloadUrl,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      // 🚀🔥 INSTANT UI UPDATE (KEY PART)
      profileImageNotifier.value = downloadUrl;

      if (mounted) {
        setState(() => _isUploading = false);

        FirebaseSnackbar.success(
          context,
          "Profile picture updated successfully!",
        );

        await _loadUserData();
      }
    } catch (e) {
      print("Upload error: $e");

      if (mounted) {
        setState(() => _isUploading = false);
        FirebaseSnackbar.error(context, "Upload failed");
      }
    }
  }

  void _removeProfilePicture() {
    final width = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              getResponsiveBorderRadius(width),
            ),
          ),
          title: const Text('Remove Profile Picture'),
          content: const Text(
            'Are you sure you want to remove your profile picture?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isUploading = true);

                try {
                  // Update Firebase Auth
                  await _user?.updatePhotoURL(null);

                  // Update Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_user!.uid)
                      .update({
                        'photoURL': null,
                        'photoRemovedAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                  // Delete from Storage if exists
                  try {
                    final storageRef = FirebaseStorage.instance.ref().child(
                      'profile_images/${_user!.uid}',
                    );
                    await storageRef.listAll().then((result) {
                      for (var item in result.items) {
                        item.delete();
                      }
                    });
                  } catch (e) {
                    print('Error deleting storage files: $e');
                  }

                  await _user?.reload();
                  _user = FirebaseAuth.instance.currentUser;

                  setState(() => _isUploading = false);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      FirebaseSnackbar.success(
                        context,
                        'Profile picture removed',
                      );
                    }
                  });
                  await _loadUserData();
                } catch (e) {
                  setState(() => _isUploading = false);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      FirebaseSnackbar.error(context, 'Error removing picture');
                    }
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  // Add this logout function here
  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showLogoutConfirmationDialog(
      context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out of your account?',
      confirmText: 'Sign Out',
      cancelText: 'Cancel',
      icon: Icons.person_rounded,
      primaryColor: const Color(0xFFFF416C),
      infoText: 'You will be redirected to the login screen',
      onConfirm: () async {
        try {
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              );
            },
          );

          // End session if exists
          if (_sessionToken != null && _user != null) {
            await _securityService.endSession(_user!.uid, _sessionToken!);
          }

          // Clear secure storage
          await _secureStorage.deleteAll();

          // Sign out from Firebase
          await FirebaseAuth.instance.signOut();

          // Sign out from Google (important for Google Sign-In)
          final GoogleSignIn googleSignIn = GoogleSignIn();
          if (await googleSignIn.isSignedIn()) {
            await googleSignIn.disconnect();
            await googleSignIn.signOut();
          }

          // Close loading dialog
          if (context.mounted) {
            Navigator.pop(context); // Close loading dialog

            // Navigate to splash screen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const SplashScreen()),
              (Route<dynamic> route) => false,
            );
          }
        } catch (e) {
          // Handle any errors
          if (context.mounted) {
            // Close loading dialog if it's showing
            Navigator.pop(context);

            // Show error message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                FirebaseSnackbar.error(
                  context,
                  'Error logging out: ${e.toString()}',
                );
              }
            });
          }
        }
      },
    );

    if (shouldLogout == true) {
      // The logout is handled in onConfirm callback
      // No additional code needed here
    }
  }

  void _showEditProfileDialog() {
    // Create controllers for all fields
    final TextEditingController nameController = TextEditingController(
      text: _nameController.text,
    );

    // Strip +91 from phone number if it exists
    String storedPhone = _phoneController.text;
    String displayPhone = storedPhone.startsWith('+91')
        ? storedPhone.substring(3) // Remove the +91 prefix
        : storedPhone;

    final TextEditingController phoneController = TextEditingController(
      text: displayPhone,
    );

    final TextEditingController emailController = TextEditingController(
      text: _userData?['email'] ?? _user?.email ?? '',
    );
    final TextEditingController bioController = TextEditingController(
      text: _bioController.text,
    );

    // Determine login method more reliably
    final bool loggedInWithPhone =
        _userData?['phone'] != null &&
        _userData!['phone'].toString().isNotEmpty &&
        _userData!['phone'].toString() != '';

    final bool loggedInWithEmail =
        _user?.email != null && _user!.email!.isNotEmpty && _user!.email! != '';

    // Check if phone exists in Firebase Auth user
    final bool hasPhoneInAuth =
        _user?.phoneNumber != null && _user!.phoneNumber!.isNotEmpty;

    // Combined condition - if user has phone in either place, treat as phone login
    final bool isPhoneUser = loggedInWithPhone || hasPhoneInAuth;
    final bool isEmailUser = loggedInWithEmail && !isPhoneUser;

    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    bool isLoading = false;

    final size = MediaQuery.of(context).size;
    final double width = size.width;
    final bool isMobileDevice = isMobile(width);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25.0),
                  topRight: Radius.circular(25.0),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12.0),
                    width: 40.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1.0),

                  // Edit form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            // Profile Image
                            Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius:
                                        getResponsiveAvatarSize(width) * 0.75,
                                    backgroundColor: Colors.deepPurple.shade100,
                                    backgroundImage: _user?.photoURL != null
                                        ? NetworkImage(_user!.photoURL!)
                                        : null,
                                    child: _user?.photoURL == null
                                        ? Text(
                                            nameController.text.isNotEmpty
                                                ? nameController.text[0]
                                                      .toUpperCase()
                                                : (_user?.email?[0]
                                                          .toUpperCase() ??
                                                      "U"),
                                            style: TextStyle(
                                              fontSize:
                                                  getResponsiveAvatarSize(
                                                    width,
                                                  ) *
                                                  0.38,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.deepPurple,
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 1,
                                    right: 0,
                                    child: Container(
                                      width:
                                          getResponsiveAvatarSize(width) * 0.55,
                                      height:
                                          getResponsiveAvatarSize(width) * 0.55,
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width:
                                              getResponsiveBorderRadius(width) *
                                              0.12,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius:
                                                getResponsiveBorderRadius(
                                                  width,
                                                ) *
                                                0.22,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _pickImage();
                                          },
                                          child: Center(
                                            child: Icon(
                                              Icons.camera_alt,
                                              color: Colors.white,
                                              size:
                                                  getResponsiveIconSize(width) *
                                                  0.75,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              height: getResponsiveVerticalSpacing(width),
                            ),

                            // Name field
                            _buildEditableField(
                              label: 'Display Name',
                              icon: Icons.person_outline,
                              controller: nameController,
                              isMobile: isMobileDevice,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Name is required';
                                }
                                if (value.length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: getResponsiveCardSpacing(width)),

                            // Phone field with +91 prefix in UI only
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(
                                  getResponsiveBorderRadius(width) * 0.6,
                                ),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 16.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.shade50,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12.0),
                                        bottomLeft: Radius.circular(12.0),
                                      ),
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.phone_outlined,
                                          color: Colors.deepPurple.shade300,
                                          size:
                                              getResponsiveIconSize(width) *
                                              0.9,
                                        ),
                                        const SizedBox(width: 4.0),
                                        const Text(
                                          '+91',
                                          style: TextStyle(
                                            color: Colors.deepPurple,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: phoneController,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      enabled: true, // Always enabled now
                                      validator: (value) {
                                        // If logged in with email, phone is optional
                                        if (isEmailUser) {
                                          if (value == null || value.isEmpty) {
                                            return null; // Phone is optional for email users
                                          }
                                        } else {
                                          // If logged in with phone, phone is required and cannot be empty
                                          if (value == null || value.isEmpty) {
                                            return 'Phone number is required';
                                          }
                                        }

                                        // Validate format if value is provided
                                        if (value.isNotEmpty) {
                                          if (!RegExp(
                                            r'^[0-9]{10}$',
                                          ).hasMatch(value)) {
                                            return 'Enter valid 10-digit phone number';
                                          }
                                        }
                                        return null;
                                      },
                                      decoration: InputDecoration(
                                        hintText: isEmailUser
                                            ? 'Optional'
                                            : '9876543210',
                                        counterText: '',
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 12.0,
                                            ),
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: getResponsiveCardSpacing(width)),

                            // Email field
                            _buildEditableField(
                              label: 'Email Address',
                              icon: Icons.email_outlined,
                              controller: emailController,
                              isMobile: isMobileDevice,
                              keyboardType: TextInputType.emailAddress,
                              enabled: true, // Always enabled now
                              validator: (value) {
                                // If logged in with phone, email is optional
                                if (isPhoneUser) {
                                  if (value == null || value.isEmpty) {
                                    return null; // Email is optional for phone users
                                  }
                                } else {
                                  // If logged in with email, email is required and cannot be empty
                                  if (value == null || value.isEmpty) {
                                    return 'Email is required';
                                  }
                                }

                                // Validate format if value is provided
                                if (value.isNotEmpty) {
                                  if (!RegExp(
                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                  ).hasMatch(value)) {
                                    return 'Enter a valid email address';
                                  }
                                }
                                return null;
                              },
                            ),

                            SizedBox(height: getResponsiveCardSpacing(width)),

                            // Bio field
                            _buildEditableField(
                              label: 'Bio',
                              icon: Icons.info_outline,
                              controller: bioController,
                              isMobile: isMobileDevice,
                              maxLines: 3,
                              validator: (value) {
                                if (value != null && value.length > 200) {
                                  return 'Bio cannot exceed 200 characters';
                                }
                                return null;
                              },
                            ),

                            SizedBox(
                              height: getResponsiveVerticalSpacing(width),
                            ),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              height: getResponsiveAvatarSize(width) * 1.2,
                              child: ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        if (formKey.currentState!.validate()) {
                                          setState(() => isLoading = true);

                                          // Get the phone number without +91 (only if changed)
                                          String phoneWithoutCode =
                                              phoneController.text.trim();
                                          String fullPhoneNumber =
                                              phoneWithoutCode.isNotEmpty
                                              ? '+91$phoneWithoutCode'
                                              : '';

                                          // For email users, phone can be empty
                                          if (isEmailUser &&
                                              phoneWithoutCode.isEmpty) {
                                            fullPhoneNumber = '';
                                          }

                                          // Only validate phone if:
                                          // 1. It's being changed
                                          // 2. User didn't log in with phone
                                          // 3. It's not empty
                                          if (!isPhoneUser &&
                                              fullPhoneNumber !=
                                                  _phoneController.text &&
                                              fullPhoneNumber.isNotEmpty) {
                                            String? phoneError =
                                                await _validatePhoneUniqueness(
                                                  fullPhoneNumber,
                                                );
                                            if (phoneError != null) {
                                              setState(() => isLoading = false);
                                              FirebaseSnackbar.error(
                                                context,
                                                phoneError,
                                              );
                                              return;
                                            }
                                          }

                                          // Only validate email if:
                                          // 1. It's being changed
                                          // 2. User didn't log in with email
                                          // 3. It's not empty
                                          if (!isEmailUser &&
                                              emailController.text.trim() !=
                                                  _user?.email &&
                                              emailController.text
                                                  .trim()
                                                  .isNotEmpty) {
                                            String? emailError =
                                                await _validateEmailUniqueness(
                                                  emailController.text.trim(),
                                                );
                                            if (emailError != null) {
                                              setState(() => isLoading = false);
                                              FirebaseSnackbar.error(
                                                context,
                                                emailError,
                                              );
                                              return;
                                            }
                                          }

                                          Navigator.pop(context);
                                          await _saveProfileChangesWithEmail(
                                            name: nameController.text.trim(),
                                            phone: fullPhoneNumber,
                                            email: emailController.text.trim(),
                                            bio: bioController.text.trim(),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      getResponsiveBorderRadius(width) * 0.6,
                                    ),
                                  ),
                                  elevation: 2.0,
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 20.0,
                                        height: 20.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditableField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool isMobile,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double fontSize = getResponsiveFontSize(width);
    final double iconSize = getResponsiveIconSize(width);
    final double borderRadius = getResponsiveBorderRadius(width) * 0.6;

    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.grey.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: enabled ? Colors.grey.shade200 : Colors.grey.shade300,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        validator: validator,
        style: TextStyle(fontSize: fontSize),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: enabled ? Colors.grey.shade600 : Colors.grey.shade500,
            fontSize: fontSize * 0.9,
          ),
          prefixIcon: Icon(
            icon,
            color: enabled ? Colors.deepPurple.shade300 : Colors.grey.shade400,
            size: iconSize,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
        ),
      ),
    );
  }

  Future<String?> _validatePhoneUniqueness(String fullPhoneNumber) async {
    // Skip if phone hasn't changed
    String currentFullNumber = '+91${_phoneController.text}';
    if (fullPhoneNumber == currentFullNumber) {
      return null;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: fullPhoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty &&
          querySnapshot.docs.first.id != _user?.uid) {
        return 'This phone number is already registered with another account';
      }
    } catch (e) {
      print('Error checking phone: $e');

      // If permission denied, allow the update (user can't check)
      if (e.toString().contains('permission-denied')) {
        print('Permission denied - allowing phone update');
        return null;
      }

      return 'Error validating phone number';
    }
    return null;
  }

  Future<String?> _validateEmailUniqueness(String email) async {
    // Skip if email hasn't changed
    if (email == _user?.email) {
      return null;
    }

    try {
      // Check Firebase Auth first
      try {
        final signInMethods = await FirebaseAuth.instance
            .fetchSignInMethodsForEmail(email);

        if (signInMethods.isNotEmpty) {
          // Email exists in Auth
          return 'This email is already registered with another account';
        }
      } catch (e) {
        // Auth check failed, try Firestore
        print('Auth check failed: $e');
      }

      // Check Firestore
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty &&
            querySnapshot.docs.first.id != _user?.uid) {
          return 'This email is already associated with another account';
        }
      } catch (e) {
        print('Firestore check failed: $e');
        if (e.toString().contains('permission-denied')) {
          return null; // Allow if can't check
        }
      }
    } catch (e) {
      print('Error checking email: $e');
      return null; // Allow on error
    }
    return null;
  }

  Future<Uint8List> compressImageFast(File file) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: 50, // 🔥 reduce more (big speed boost)
      minWidth: 720, // 🔥 smaller size = faster upload
      minHeight: 720,
      format: CompressFormat.jpeg,
    );

    return result!;
  }

  double uploadProgress = 0;

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
    bool isDisabled = false,
    required bool isMobile,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double fontSize = getResponsiveFontSize(width);
    final double iconSize = getResponsiveIconSize(width);
    final double borderRadius = getResponsiveBorderRadius(width);
    final double cardSpacing = getResponsiveCardSpacing(width);

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: cardSpacing * 0.6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isDisabled ? null : onTap,
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(borderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10.0,
                          offset: const Offset(0.0, 2.0),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: (iconColor ?? Colors.deepPurple).withOpacity(
                              0.1,
                            ),
                            borderRadius: BorderRadius.circular(
                              borderRadius * 0.6,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: iconColor ?? Colors.deepPurple,
                            size: iconSize,
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                              color: isDisabled ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ),
                        if (trailing != null)
                          trailing
                        else
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16.0,
                            color: isDisabled
                                ? Colors.grey.shade400
                                : Colors.grey,
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
    final double width = size.width;

    final bool isMobileDevice = isMobile(width);
    final bool isTabletDevice = isTablet(width);
    final bool isSmallDesktopDevice = isSmallDesktop(width);
    final bool isDesktopDevice = isDesktop(width);
    final bool isLargeDesktopDevice = isLargeDesktop(width);
    final bool isUltraWideDevice = isUltraWide(width);

    final double horizontalPadding = getResponsiveHorizontalPadding(width);
    final double verticalSpacing = getResponsiveVerticalSpacing(width);
    final double bodyFontSize = getResponsiveFontSize(width);
    final double headingFontSize = getResponsiveFontSize(
      width,
      mobile: 18.0,
      tablet: 20.0,
      smallDesktop: 22.0,
      desktop: 24.0,
      largeDesktop: 28.0,
      ultraWide: 32.0,
    );
    final double borderRadius = getResponsiveBorderRadius(width);
    final double cardSpacing = getResponsiveCardSpacing(width);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalSpacing,
                  horizontalPadding,
                  verticalSpacing * 1.5,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isUltraWideDevice
                          ? 1200.0
                          : (isLargeDesktopDevice
                                ? 1000.0
                                : (isDesktopDevice
                                      ? 900.0
                                      : (isSmallDesktopDevice
                                            ? 800.0
                                            : (isTabletDevice
                                                  ? 700.0
                                                  : double.infinity)))),
                    ),
                    child: Column(
                      children: [
                        _buildProfileHeader(
                          isMobile: isMobileDevice,
                          isTablet: isTabletDevice,
                          isDesktop:
                              isDesktopDevice ||
                              isLargeDesktopDevice ||
                              isUltraWideDevice,
                          bodyFontSize: bodyFontSize,
                          headingFontSize: headingFontSize,
                        ),
                        SizedBox(height: verticalSpacing),

                        if (_bioController.text.isNotEmpty)
                          _buildBioSection(
                            isMobile: isMobileDevice,
                            bodyFontSize: bodyFontSize,
                          ),
                        SizedBox(height: verticalSpacing),

                        _buildStatsCards(
                          isMobile: isMobileDevice,
                          bodyFontSize: bodyFontSize,
                        ),
                        SizedBox(height: verticalSpacing),

                        _buildSectionHeader(
                          "Account",
                          Icons.person_outline,
                          headingFontSize: headingFontSize * 0.8,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.shopping_bag_outlined,
                          title: "My Orders",
                          iconColor: Colors.blue,
                          onTap: () {},
                          trailing: _buildBadge(3, isMobile: isMobileDevice),
                          isMobile: isMobileDevice,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.location_on_outlined,
                          title: "My Addresses",
                          iconColor: Colors.green,
                          onTap: () {},
                          isMobile: isMobileDevice,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.account_balance_wallet_outlined,
                          title: "Wallet",
                          iconColor: Colors.orange,
                          onTap: () {},
                          trailing: _buildWalletBalance(
                            isMobile: isMobileDevice,
                            bodyFontSize: bodyFontSize,
                          ),
                          isMobile: isMobileDevice,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.notifications_outlined,
                          title: "Notifications",
                          iconColor: Colors.purple,
                          onTap: () {},
                          trailing: _buildBadge(2, isMobile: isMobileDevice),
                          isMobile: isMobileDevice,
                        ),

                        SizedBox(height: cardSpacing),

                        if (_isOwner || !_hasPendingApplication) ...[
                          _buildSectionHeader(
                            "Business",
                            Icons.business_center,
                            headingFontSize: headingFontSize * 0.8,
                          ),

                          if (!_isOwner && !_hasPendingApplication)
                            _buildMenuItem(
                              context: context,
                              icon: Icons.storefront_outlined,
                              title: "Become a Seller",
                              iconColor: Colors.deepPurple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const BecomeSellerInfoScreen(),
                                  ),
                                ).then((_) => _loadUserData());
                              },
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 6.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(
                                    borderRadius * 0.8,
                                  ),
                                ),
                                child: Text(
                                  "Start Selling",
                                  style: TextStyle(
                                    color: Colors.deepPurple,
                                    fontSize: bodyFontSize * 0.8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              isMobile: isMobileDevice,
                            ),

                          if (!_isOwner && _hasPendingApplication)
                            _buildApplicationStatusCard(
                              isMobile: isMobileDevice,
                              bodyFontSize: bodyFontSize,
                            ),

                          if (_isOwner)
                            _buildMenuItem(
                              context: context,
                              icon: Icons.dashboard_customize,
                              title: "Owner Dashboard",
                              iconColor: Colors.teal,
                              onTap: () {
                                Navigator.pushNamed(context, '/owner-home');
                              },
                              trailing: Container(
                                padding: const EdgeInsets.all(6.0),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(
                                    borderRadius * 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      color: Colors.teal,
                                      size: 14.0,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      "Active",
                                      style: TextStyle(
                                        color: Colors.teal,
                                        fontSize: bodyFontSize * 0.75,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              isMobile: isMobileDevice,
                            ),
                        ],

                        SizedBox(height: cardSpacing),

                        _buildSectionHeader(
                          "Settings",
                          Icons.settings,
                          headingFontSize: headingFontSize * 0.8,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.settings_outlined,
                          title: "App Settings",
                          iconColor: Colors.grey,
                          onTap: () {},
                          isMobile: isMobileDevice,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.help_outline,
                          title: "Help & Support",
                          iconColor: Colors.blueGrey,
                          onTap: () {},
                          isMobile: isMobileDevice,
                        ),

                        _buildMenuItem(
                          context: context,
                          icon: Icons.info_outline,
                          title: "About Us",
                          iconColor: Colors.indigo,
                          onTap: () {},
                          isMobile: isMobileDevice,
                        ),

                        SizedBox(height: verticalSpacing * 1.5),

                        _buildLogoutButton(
                          isMobile: isMobileDevice,
                          bodyFontSize: bodyFontSize,
                        ),

                        SizedBox(height: verticalSpacing),

                        Column(
                          children: [
                            Image.asset(
                              'assets/logo.png',
                              height: 30.0,
                              errorBuilder: (context, error, stack) =>
                                  const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              "Bizora v1.0.0",
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade400,
                                fontSize: bodyFontSize * 0.8,
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
    );
  }

  Widget _buildProfileHeader({
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
    required double bodyFontSize,
    required double headingFontSize,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double avatarRadius = getResponsiveAvatarSize(width);
    final double iconSize = getResponsiveIconSize(width);
    final double borderRadius = getResponsiveBorderRadius(width);
    final double horizontalPadding = getResponsiveHorizontalPadding(width);
    final double verticalSpacing = getResponsiveVerticalSpacing(width);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 20.0,
            offset: const Offset(0.0, 8.0),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20.0,
            right: -20.0,
            child: Container(
              width: 100.0,
              height: 120.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -30.0,
            left: -30.0,
            child: Container(
              width: 150.0,
              height: 150.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 13.0 : 17.0),
            child: Row(
              children: [
                // Profile Image
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: avatarRadius * 0.5,
                        backgroundColor: Colors.white,
                        backgroundImage: _user?.photoURL != null
                            ? NetworkImage(_user!.photoURL!)
                            : null,
                        child: _user?.photoURL == null
                            ? Text(
                                _nameController.text.isNotEmpty
                                    ? _nameController.text[0].toUpperCase()
                                    : (_user?.email?[0].toUpperCase() ?? "U"),
                                style: TextStyle(
                                  fontSize: avatarRadius * 0.4,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              )
                            : null,
                      ),
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 30.0,
                                height: 30.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12.0),

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.isNotEmpty
                            ? _nameController.text
                            : (_user?.displayName ?? "User"),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: headingFontSize * 0.75,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4.0),

                      /// Display phone number if available
                      if (_phoneController.text.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: bodyFontSize * 0.75,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              _phoneController.text,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: bodyFontSize * 0.65,
                              ),
                            ),
                          ],
                        ),

                      /// Display email if available
                      if (_user?.email != null && _user!.email!.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: bodyFontSize * 0.75,
                              color: Colors.white.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4.0),
                            Expanded(
                              child: Text(
                                _user!.email!,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: bodyFontSize * 0.65,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 8.0),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding * 0.4,
                          vertical: verticalSpacing * 0.18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isOwner ? Icons.verified : Icons.person,
                              size: bodyFontSize * 0.75,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              _isOwner ? "Seller Account" : "Customer Account",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: bodyFontSize * 0.65,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit Button
                Container(
                  width: getResponsiveAvatarSize(width) * 0.75,
                  height: getResponsiveAvatarSize(width) * 0.75,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: borderRadius * 0.08,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: borderRadius * 0.15,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _showEditProfileDialog,
                      child: Center(
                        child: Icon(
                          _isUploading ? Icons.hourglass_empty : Icons.edit,
                          color: Colors.white,
                          size: iconSize * 0.75,
                        ),
                      ),
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

  Widget _buildBioSection({
    required bool isMobile,
    required double bodyFontSize,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double borderRadius = getResponsiveBorderRadius(width);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10.0,
            offset: const Offset(0.0, 2.0),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(borderRadius * 0.6),
            ),
            child: const Icon(Icons.info, color: Colors.deepPurple, size: 20.0),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bio',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.0),
                ),
                const SizedBox(height: 4.0),
                Text(
                  _bioController.text,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: bodyFontSize * 0.9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards({
    required bool isMobile,
    required double bodyFontSize,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double statFontSize = getResponsiveFontSize(
      width,
      mobile: 18.0,
      tablet: 20.0,
      smallDesktop: 22.0,
      desktop: 24.0,
    );
    final double labelFontSize = getResponsiveFontSize(
      width,
      mobile: 11.0,
      tablet: 12.0,
      smallDesktop: 13.0,
      desktop: 14.0,
    );
    final double cardSpacing = getResponsiveCardSpacing(width);

    return Row(
      children: [
        _buildStatCard(
          "Orders",
          "24",
          Icons.shopping_bag,
          Colors.blue,
          isMobile: isMobile,
          statFontSize: statFontSize,
          labelFontSize: labelFontSize,
        ),
        SizedBox(width: cardSpacing),
        _buildStatCard(
          "Wishlist",
          "12",
          Icons.favorite,
          Colors.red,
          isMobile: isMobile,
          statFontSize: statFontSize,
          labelFontSize: labelFontSize,
        ),
        SizedBox(width: cardSpacing),
        _buildStatCard(
          "Coupons",
          "5",
          Icons.discount,
          Colors.green,
          isMobile: isMobile,
          statFontSize: statFontSize,
          labelFontSize: labelFontSize,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required bool isMobile,
    required double statFontSize,
    required double labelFontSize,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double iconSize = getResponsiveIconSize(width);
    final double padding = getResponsiveCardSpacing(width);
    final double borderRadius = getResponsiveBorderRadius(width);

    return Expanded(
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12.0,
              offset: const Offset(0.0, 4.0),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            const SizedBox(height: 8.0),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: statFontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: labelFontSize,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    required double headingFontSize,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double iconSize = getResponsiveIconSize(width);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 8.0),
      child: Row(
        children: [
          Icon(icon, size: iconSize * 0.9, color: Colors.deepPurple.shade300),
          const SizedBox(width: 8.0),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: headingFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(int count, {required bool isMobile}) {
    final width = MediaQuery.of(context).size.width;
    final double borderRadius = getResponsiveBorderRadius(width);
    final double fontSize = getResponsiveFontSize(width) * 0.8;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(borderRadius * 0.6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: Colors.red.shade700,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWalletBalance({
    required bool isMobile,
    required double bodyFontSize,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double borderRadius = getResponsiveBorderRadius(width);
    final double fontSize = getResponsiveFontSize(width) * 0.9;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(borderRadius * 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.currency_rupee, size: 14.0, color: Colors.green),
          Text(
            "1,250",
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatusCard({
    required bool isMobile,
    required double bodyFontSize,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double borderRadius = getResponsiveBorderRadius(width);
    final double fontSize = getResponsiveFontSize(width) * 0.8;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade50, Colors.amber.shade50],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty,
              color: Colors.orange,
              size: 24.0,
            ),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Application Pending",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
                const SizedBox(height: 4.0),
                Text(
                  "Your seller application is under review",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: bodyFontSize * 0.9,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 6.0,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Text(
              "Pending",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton({
    required bool isMobile,
    required double bodyFontSize,
  }) {
    final width = MediaQuery.of(context).size.width;
    final double borderRadius = getResponsiveBorderRadius(width);
    final double height = getResponsiveAvatarSize(width) * 1.2;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red,
          elevation: 0.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(color: Colors.red.shade200),
          ),
        ),
        icon: const Icon(Icons.logout, size: 20.0),
        label: Text(
          "Logout",
          style: GoogleFonts.inter(
            fontSize: bodyFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () => _logout(context),
      ),
    );
  }
}
