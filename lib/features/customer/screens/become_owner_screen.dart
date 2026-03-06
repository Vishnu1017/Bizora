import 'dart:io';

import 'package:bizora/core/utils/firebase_snackbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class BecomeOwnerScreen extends StatefulWidget {
  const BecomeOwnerScreen({super.key});

  @override
  State<BecomeOwnerScreen> createState() => _BecomeOwnerScreenState();
}

class _BecomeOwnerScreenState extends State<BecomeOwnerScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Step management
  int _currentStep = 1;
  final int _totalSteps = 5;

  // Controllers
  final shopNameController = TextEditingController();
  final ownerNameController = TextEditingController();
  final phoneController = TextEditingController();
  final alternatePhoneController = TextEditingController();
  final addressController = TextEditingController();
  final descriptionController = TextEditingController();
  final emailController = TextEditingController();
  final gstController = TextEditingController();
  final panController = TextEditingController();
  final websiteController = TextEditingController();

  // Selection values
  String? selectedCategory;
  String? selectedSubCategory;
  String? businessType;
  String? experienceLevel;
  String? shopSize;
  String? operatingHours;
  String? deliveryRadius;
  String? minimumOrderValue;

  // Multi-select for delivery options
  final Set<String> selectedDeliveryOptions = {};
  final Set<String> selectedPaymentMethods = {};
  final Set<String> selectedDays = {};

  bool agreeTerms = false;
  bool agreePrivacy = false;
  bool agreeCommission = false;
  bool receiveUpdates = true;
  bool isSubmitting = false;

  // Step completion flags
  bool _isBasicInfoComplete = false;
  bool _isBusinessDetailsComplete = false;
  bool _isDeliveryComplete = false;
  bool _isDocumentsComplete = false;

  // Categories with subcategories
  final Map<String, List<String>> categoryMap = {
    "Grocery": [
      "Fresh Vegetables",
      "Fresh Fruits",
      "Dairy Products",
      "Bakery Items",
      "Beverages",
      "Snacks",
      "Household Items",
      "Organic Products",
      "Imported Items",
    ],
    "Electronics": [
      "Mobile Phones",
      "Laptops & Computers",
      "Audio Devices",
      "Wearables",
      "Cameras",
      "Gaming",
      "Home Appliances",
      "Accessories",
    ],
    "Fashion": [
      "Men's Clothing",
      "Women's Clothing",
      "Kids Clothing",
      "Footwear",
      "Accessories",
      "Jewelry",
      "Bags & Luggage",
    ],
    "Food & Beverages": [
      "Restaurant",
      "Cafe",
      "Fast Food",
      "Bakery",
      "Cloud Kitchen",
      "Meal Prep",
      "Beverages",
      "Ice Cream Parlor",
    ],
    "Health & Beauty": [
      "Pharmacy",
      "Cosmetics",
      "Salon Products",
      "Healthcare",
      "Wellness",
      "Fitness Equipment",
    ],
    "Home & Living": [
      "Furniture",
      "Home Decor",
      "Kitchenware",
      "Bed & Bath",
      "Gardening",
    ],
    "Books & Stationery": ["Books", "Stationery", "Art Supplies", "Gifts"],
    "Sports & Outdoors": [
      "Sports Equipment",
      "Fitness Gear",
      "Outdoor Gear",
      "Cycling",
    ],
  };

  // Delivery options with icons and descriptions
  final List<Map<String, dynamic>> deliveryOptions = [
    {
      "value": "home_delivery",
      "label": "Home Delivery",
      "icon": Icons.delivery_dining,
      "description": "Deliver products to customer's doorstep",
      "color": Colors.blue,
    },
    {
      "value": "store_pickup",
      "label": "Store Pickup",
      "icon": Icons.store,
      "description": "Customers can pickup from your store",
      "color": Colors.green,
    },
    {
      "value": "same_day",
      "label": "Same Day Delivery",
      "icon": Icons.timer,
      "description": "Deliver within 24 hours",
      "color": Colors.orange,
    },
    {
      "value": "next_day",
      "label": "Next Day Delivery",
      "icon": Icons.schedule,
      "description": "Guaranteed next day delivery",
      "color": Colors.purple,
    },
    {
      "value": "express",
      "label": "Express Delivery",
      "icon": Icons.flash_on,
      "description": "2-3 hour delivery (extra charges)",
      "color": Colors.red,
    },
    {
      "value": "scheduled",
      "label": "Scheduled Delivery",
      "icon": Icons.calendar_today,
      "description": "Customer can choose delivery time",
      "color": Colors.teal,
    },
  ];

  // Payment methods
  final List<Map<String, dynamic>> paymentMethods = [
    {
      "value": "cash",
      "label": "Cash on Delivery",
      "icon": Icons.money,
      "color": Colors.green,
    },
    {
      "value": "card",
      "label": "Card Payment (POS)",
      "icon": Icons.credit_card,
      "color": Colors.blue,
    },
    {
      "value": "upi",
      "label": "UPI / QR Code",
      "icon": Icons.qr_code,
      "color": Colors.purple,
    },
    {
      "value": "online",
      "label": "Online Payment",
      "icon": Icons.payments,
      "color": Colors.orange,
    },
    {
      "value": "wallet",
      "label": "Digital Wallet",
      "icon": Icons.account_balance_wallet,
      "color": Colors.teal,
    },
  ];

  // Business types
  final List<Map<String, dynamic>> businessTypes = [
    {
      "value": "individual",
      "label": "Individual / Sole Proprietor",
      "icon": Icons.person,
    },
    {"value": "partnership", "label": "Partnership Firm", "icon": Icons.people},
    {
      "value": "llp",
      "label": "Limited Liability Partnership (LLP)",
      "icon": Icons.business,
    },
    {
      "value": "pvt_ltd",
      "label": "Private Limited Company",
      "icon": Icons.apartment,
    },
    {
      "value": "public_ltd",
      "label": "Public Limited Company",
      "icon": Icons.corporate_fare,
    },
  ];

  // Experience levels
  final List<Map<String, dynamic>> experienceLevels = [
    {"value": "0-1", "label": "Beginner (0-1 years)", "icon": Icons.eco},
    {
      "value": "1-3",
      "label": "Intermediate (1-3 years)",
      "icon": Icons.trending_up,
    },
    {"value": "3-5", "label": "Experienced (3-5 years)", "icon": Icons.star},
    {
      "value": "5-10",
      "label": "Advanced (5-10 years)",
      "icon": Icons.workspace_premium,
    },
    {
      "value": "10+",
      "label": "Expert (10+ years)",
      "icon": Icons.military_tech,
    },
  ];

  // Shop sizes
  final List<Map<String, dynamic>> shopSizes = [
    {"value": "home", "label": "Home-based", "icon": Icons.home},
    {"value": "small", "label": "Small (under 200 sq ft)", "icon": Icons.store},
    {
      "value": "medium",
      "label": "Medium (200-500 sq ft)",
      "icon": Icons.store_mall_directory,
    },
    {
      "value": "large",
      "label": "Large (500-1000 sq ft)",
      "icon": Icons.business_center,
    },
    {
      "value": "warehouse",
      "label": "Warehouse (1000+ sq ft)",
      "icon": Icons.warehouse,
    },
  ];

  // Operating hours
  final List<String> operatingHoursList = [
    "9 AM - 6 PM",
    "9 AM - 9 PM",
    "10 AM - 8 PM",
    "10 AM - 10 PM",
    "11 AM - 11 PM",
    "24 Hours",
    "Custom Hours",
  ];

  // Delivery radius
  final List<String> radiusOptions = [
    "Within 2 km",
    "Within 5 km",
    "Within 10 km",
    "Within 20 km",
    "City-wide",
    "State-wide",
    "Nation-wide",
  ];

  // Minimum order value
  final List<String> minOrderOptions = [
    "No minimum",
    "₹100",
    "₹200",
    "₹300",
    "₹500",
    "₹1000",
    "Custom",
  ];

  // Operating days
  final List<String> weekDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  // Document upload state
  final Map<String, File?> _documentFiles = {
    'gst': null,
    'pan': null,
    'address_proof': null,
    'shop_photos': null,
  };

  final Map<String, String?> _documentUrls = {
    'gst': null,
    'pan': null,
    'address_proof': null,
    'shop_photos': null,
  };

  final Map<String, bool> _documentUploading = {
    'gst': false,
    'pan': false,
    'address_proof': false,
    'shop_photos': false,
  };

  final Map<String, String?> _documentNames = {
    'gst': null,
    'pan': null,
    'address_proof': null,
    'shop_photos': null,
  };

  // Multiple shop photos
  final List<File> _shopPhotos = [];
  List<String> _shopPhotoUrls = [];

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  get path => null;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _prefillUserData();

    // Default selections
    selectedDays.addAll(weekDays); // All days selected by default
    selectedDeliveryOptions.add("home_delivery"); // Default delivery option
    selectedPaymentMethods.add("cash"); // Default payment method
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  void _prefillUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.email != null) emailController.text = user.email!;
      if (user.displayName != null)
        ownerNameController.text = user.displayName!;
      if (user.phoneNumber != null) {
        phoneController.text = user.phoneNumber!.replaceAll('+91', '');
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    shopNameController.dispose();
    ownerNameController.dispose();
    phoneController.dispose();
    alternatePhoneController.dispose();
    addressController.dispose();
    descriptionController.dispose();
    emailController.dispose();
    gstController.dispose();
    panController.dispose();
    websiteController.dispose();
    super.dispose();
  }

  // Check if current step is valid before proceeding
  bool _isStepValid() {
    switch (_currentStep) {
      case 1: // Basic Info
        return _formKey.currentState?.validate() ?? false;

      case 2: // Business Details
        return selectedCategory != null && businessType != null;

      case 3: // Delivery
        return selectedDeliveryOptions.isNotEmpty &&
            selectedPaymentMethods.isNotEmpty;

      case 4: // Documents & Operating
        return addressController.text.isNotEmpty &&
            descriptionController.text.isNotEmpty &&
            operatingHours != null;

      case 5: // Review
        return agreeTerms && agreePrivacy && agreeCommission;

      default:
        return false;
    }
  }

  // Save current step data
  void _saveStepData() {
    switch (_currentStep) {
      case 1: // Basic Info
        setState(() {
          _isBasicInfoComplete = true;
        });
        break;

      case 2: // Business Details
        setState(() {
          _isBusinessDetailsComplete = true;
        });
        break;

      case 3: // Delivery
        setState(() {
          _isDeliveryComplete = true;
        });
        break;

      case 4: // Documents
        setState(() {
          _isDocumentsComplete = true;
        });
        break;
    }
  }

  // Go to next step
  void _nextStep() {
    if (_isStepValid()) {
      _saveStepData();
      if (_currentStep < _totalSteps) {
        setState(() {
          _currentStep++;
        });

        // Scroll to top
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
        );
      }
    } else {
      _showStepError();
    }
  }

  // Go to previous step
  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });

      // Scroll to top
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  // Show error for current step
  void _showStepError() {
    String message = "";
    switch (_currentStep) {
      case 1:
        message = "Please fill all required fields in Basic Information";
        break;
      case 2:
        message = "Please select Category and Business Type";
        break;
      case 3:
        message =
            "Please select at least one Delivery Option and Payment Method";
        break;
      case 4:
        message = "Please complete Address, Description and Operating Hours";
        break;
      case 5:
        message = "Please agree to all Terms & Conditions";
        break;
    }
    FirebaseSnackbar.warning(context, message);
  }

  // Submit final form
  Future<void> submitForm() async {
    if (!_isStepValid()) {
      _showStepError();
      return;
    }

    // Check if documents are uploaded (optional but recommended)
    if (_documentUrls['gst'] == null &&
        _documentUrls['pan'] == null &&
        _documentUrls['address_proof'] == null &&
        _shopPhotoUrls.isEmpty) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Documents Not Uploaded"),
          content: const Text(
            "You haven't uploaded any documents. You can upload them now or continue without documents. "
            "Note: Your application may be delayed without required documents.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Upload Now"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text("Continue Anyway"),
            ),
          ],
        ),
      );

      if (shouldContinue == false) {
        setState(() => isSubmitting = false);
        return;
      }
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        FirebaseSnackbar.error(context, "You must be logged in to apply");
        setState(() => isSubmitting = false);
        return;
      }

      // Check for existing applications
      try {
        final existingRequest = await FirebaseFirestore.instance
            .collection("owner_requests")
            .where("userId", isEqualTo: user.uid)
            .where("status", whereIn: ["pending", "approved"])
            .limit(1)
            .get();

        if (existingRequest.docs.isNotEmpty) {
          final status = existingRequest.docs.first.data()["status"];
          setState(() => isSubmitting = false);

          if (status == "pending") {
            FirebaseSnackbar.warning(
              context,
              "You already have a pending application. Please wait for admin review.",
            );
          } else {
            FirebaseSnackbar.info(
              context,
              "You are already registered as a shop owner on Bizora.",
            );
          }
          return;
        }
      } catch (e) {
        print("Note: Could not check existing requests: $e");
      }

      // Prepare comprehensive application data
      final Map<String, dynamic> applicationData = {
        "userId": user.uid,
        "userEmail": user.email,
        "userName": user.displayName,

        // Basic Information
        "shopName": shopNameController.text.trim(),
        "ownerName": ownerNameController.text.trim(),
        "phone": phoneController.text.trim(),
        "alternatePhone": alternatePhoneController.text.trim().isEmpty
            ? null
            : alternatePhoneController.text.trim(),
        "email": emailController.text.trim(),

        // Business Details
        "category": selectedCategory,
        "subCategory": selectedSubCategory,
        "businessType": businessType,
        "experienceLevel": experienceLevel,
        "shopSize": shopSize,
        "gstNumber": gstController.text.trim().isEmpty
            ? null
            : gstController.text.trim().toUpperCase(),
        "panNumber": panController.text.trim().isEmpty
            ? null
            : panController.text.trim().toUpperCase(),
        "website": websiteController.text.trim().isEmpty
            ? null
            : websiteController.text.trim(),

        // Location
        "address": addressController.text.trim(),
        "addressGeoPoint": null,
        "operatingHours": operatingHours,
        "operatingDays": selectedDays.toList(),

        // Delivery & Services
        "deliveryOptions": selectedDeliveryOptions.toList(),
        "deliveryRadius": deliveryRadius,
        "minimumOrderValue": minimumOrderValue,
        "paymentMethods": selectedPaymentMethods.toList(),

        // Shop Details
        "description": descriptionController.text.trim(),

        // Documents with URLs if uploaded
        "documents": {
          "gst": {
            "url": _documentUrls['gst'],
            "fileName": _documentNames['gst'],
            "verified": false,
            "uploadedAt": _documentUrls['gst'] != null
                ? FieldValue.serverTimestamp()
                : null,
          },
          "pan": {
            "url": _documentUrls['pan'],
            "fileName": _documentNames['pan'],
            "verified": false,
            "uploadedAt": _documentUrls['pan'] != null
                ? FieldValue.serverTimestamp()
                : null,
          },
          "addressProof": {
            "url": _documentUrls['address_proof'],
            "fileName": _documentNames['address_proof'],
            "verified": false,
            "uploadedAt": _documentUrls['address_proof'] != null
                ? FieldValue.serverTimestamp()
                : null,
          },
          "shopPhotos": _shopPhotoUrls
              .map((url) => {"url": url, "verified": false})
              .toList(),
        },

        // Document verification status
        "documentVerification": {
          "gstVerified": false,
          "panVerified": false,
          "addressVerified": false,
          "photosVerified": false,
        },

        // Has documents flag for easy querying
        "hasDocuments":
            _documentUrls['gst'] != null ||
            _documentUrls['pan'] != null ||
            _documentUrls['address_proof'] != null ||
            _shopPhotoUrls.isNotEmpty,

        // Preferences
        "receiveUpdates": receiveUpdates,

        // Application Status
        "status": "pending",
        "applicationStage": "submitted",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),

        // Metadata
        "appVersion": "1.0.0",
        "platform": Theme.of(context).platform.toString(),
        "submittedFrom": "mobile_app",
      };

      // Save to Firestore
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection("owner_requests")
          .add(applicationData);

      // Update user document
      try {
        await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
          "hasAppliedForOwner": true,
          "applicationStatus": "pending",
          "applicationDate": FieldValue.serverTimestamp(),
          "lastUpdated": FieldValue.serverTimestamp(),
          "role": "user",
          "ownerRequestId": docRef.id, // Store the request ID for reference
          "hasDocuments": applicationData["hasDocuments"],
        }, SetOptions(merge: true));
      } catch (e) {
        print("User doc update error: $e");
      }

      setState(() => isSubmitting = false);

      if (!mounted) return;

      // Show success message with document info
      String successMessage = "Application submitted successfully! ";
      if (applicationData["hasDocuments"]) {
        successMessage += "Your documents will be verified within 24-48 hours.";
      } else {
        successMessage +=
            "Please upload your documents later to complete verification.";
      }

      FirebaseSnackbar.success(context, successMessage);

      // Navigate back after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(
            context,
            true,
          ); // Return true to indicate successful submission
        }
      });
    } catch (e) {
      print("Application error: $e");
      setState(() => isSubmitting = false);

      if (e.toString().contains("permission-denied")) {
        FirebaseSnackbar.error(
          context,
          "Permission error. Please check if you're logged in correctly.",
        );
      } else if (e.toString().contains("network")) {
        FirebaseSnackbar.error(
          context,
          "Network error. Please check your internet connection.",
        );
      } else {
        FirebaseSnackbar.error(
          context,
          "Failed to submit application. Please try again.",
        );
      }
    }
  }

  Future<void> _pickDocument(String documentType) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80, // Initial quality from image_picker
      );

      if (pickedFile != null) {
        // Show loading indicator
        setState(() {
          _documentUploading[documentType] = true;
        });

        // Get the file
        File originalFile = File(pickedFile.path);

        // Compress the image further
        File? compressedFile = await _compressImage(
          originalFile,
          quality: 60, // 60% quality for good balance
        );

        if (compressedFile != null) {
          // Log file size reduction
          String originalSize = await _getFileSize(originalFile);
          String compressedSize = await _getFileSize(compressedFile);
          print("Document $documentType: $originalSize -> $compressedSize");

          setState(() {
            _documentFiles[documentType] = compressedFile;
            _documentNames[documentType] = pickedFile.name;
            _documentUploading[documentType] = false;
          });

          // Automatically upload after picking and compression
          await _uploadDocument(documentType);
        } else {
          setState(() {
            _documentFiles[documentType] = originalFile;
            _documentNames[documentType] = pickedFile.name;
            _documentUploading[documentType] = false;
          });
          await _uploadDocument(documentType);
        }
      }
    } catch (e) {
      setState(() {
        _documentUploading[documentType] = false;
      });
      FirebaseSnackbar.error(context, "Error picking document: $e");
    }
  }

  Future<void> _pickMultipleShopPhotos() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (pickedFiles.isNotEmpty) {
        if (_shopPhotos.length + pickedFiles.length > 5) {
          FirebaseSnackbar.warning(context, "Maximum 5 photos allowed");
          return;
        }

        // Show loading indicator
        setState(() {
          _documentUploading['shop_photos'] = true;
        });

        // Process each image with compression
        List<File> compressedFiles = [];

        for (var pickedFile in pickedFiles) {
          File originalFile = File(pickedFile.path);

          // Compress the image
          File? compressedFile = await _compressImage(
            originalFile,
            quality: 70, // Slightly higher quality for shop photos
          );

          if (compressedFile != null) {
            compressedFiles.add(compressedFile);

            // Log file size reduction
            String originalSize = await _getFileSize(originalFile);
            String compressedSize = await _getFileSize(compressedFile);
            print("Shop photo: $originalSize -> $compressedSize");
          } else {
            compressedFiles.add(originalFile);
          }
        }

        setState(() {
          _shopPhotos.addAll(compressedFiles);
          _documentUploading['shop_photos'] = false;
        });

        // Upload all shop photos
        await _uploadShopPhotos();
      }
    } catch (e) {
      setState(() {
        _documentUploading['shop_photos'] = false;
      });
      FirebaseSnackbar.error(context, "Error picking photos: $e");
    }
  }

  Future<void> _uploadDocument(String documentType) async {
    final file = _documentFiles[documentType];
    if (file == null) return;

    setState(() {
      _documentUploading[documentType] = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Get file extension
      String filePath = file.path;
      String extension = filePath.contains('.')
          ? '.${filePath.split('.').last}'
          : '.jpg';

      // Create a unique filename
      final fileName =
          '${documentType}_${user.uid}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('owner_documents')
          .child(user.uid)
          .child(fileName);

      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'compressed': 'true',
          'originalName': _documentNames[documentType] ?? '',
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // Upload file with metadata
      final uploadTask = storageRef.putFile(file, metadata);

      // Show upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print(
          'Upload progress for $documentType: ${(progress * 100).toStringAsFixed(0)}%',
        );
      });

      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _documentUrls[documentType] = downloadUrl;
        _documentUploading[documentType] = false;
      });

      FirebaseSnackbar.success(
        context,
        "${_getDocumentDisplayName(documentType)} uploaded successfully",
      );
    } catch (e) {
      print("Upload error: $e");
      setState(() {
        _documentUploading[documentType] = false;
      });
      FirebaseSnackbar.error(context, "Failed to upload document: $e");
    }
  }

  Future<void> _uploadShopPhotos() async {
    if (_shopPhotos.isEmpty) return;

    setState(() {
      _documentUploading['shop_photos'] = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      List<String> uploadedUrls = [];

      for (int i = 0; i < _shopPhotos.length; i++) {
        final file = _shopPhotos[i];

        // Get file extension
        String filePath = file.path;
        String extension = filePath.contains('.')
            ? '.${filePath.split('.').last}'
            : '.jpg';

        final fileName =
            'shop_photo_${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i$extension';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('owner_documents')
            .child(user.uid)
            .child('shop_photos')
            .child(fileName);

        // Set metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'compressed': 'true',
            'photoIndex': '$i',
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        final uploadTask = storageRef.putFile(file, metadata);
        final snapshot = await uploadTask.whenComplete(() => {});
        final downloadUrl = await snapshot.ref.getDownloadURL();
        uploadedUrls.add(downloadUrl);

        // Update progress
        print('Uploaded shop photo ${i + 1}/${_shopPhotos.length}');
      }

      setState(() {
        _shopPhotoUrls = uploadedUrls;
        _documentUploading['shop_photos'] = false;
      });

      FirebaseSnackbar.success(
        context,
        "${uploadedUrls.length} shop photos uploaded successfully",
      );
    } catch (e) {
      print("Upload error: $e");
      setState(() {
        _documentUploading['shop_photos'] = false;
      });
      FirebaseSnackbar.error(context, "Failed to upload shop photos: $e");
    }
  }

  String _getDocumentDisplayName(String type) {
    switch (type) {
      case 'gst':
        return 'GST Certificate';
      case 'pan':
        return 'PAN Card';
      case 'address_proof':
        return 'Address Proof';
      case 'shop_photos':
        return 'Shop Photos';
      default:
        return type;
    }
  }

  // Compress image before upload
  Future<File?> _compressImage(File file, {int quality = 60}) async {
    try {
      // Get temporary directory
      final dir = await getTemporaryDirectory();

      // Create a unique filename for compressed image
      final targetPath =
          '${dir.absolute.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: quality, // 60% quality (reduces file size significantly)
        minWidth: 1920, // Max width
        minHeight: 1080, // Max height
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        print(
          "Original size: ${await file.length()}, Compressed size: ${await result.length()}",
        );
        return File(result.path);
      }
      return file; // Return original if compression fails
    } catch (e) {
      print("Compression error: $e");
      return file; // Return original on error
    }
  }

  // Get file size in readable format
  Future<String> _getFileSize(File file) async {
    int bytes = await file.length();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _removeDocument(String documentType) {
    setState(() {
      _documentFiles[documentType] = null;
      _documentUrls[documentType] = null;
      _documentNames[documentType] = null;
    });
  }

  void _removeShopPhoto(int index) {
    setState(() {
      _shopPhotos.removeAt(index);
      if (index < _shopPhotoUrls.length) {
        _shopPhotoUrls.removeAt(index);
      }
    });
  }

  Widget _buildDocumentUploadTile({
    required String type,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    bool isImage = true,
  }) {
    final file = _documentFiles[type];
    final isUploading = _documentUploading[type] ?? false;
    final fileName = _documentNames[type];
    final hasUrl = _documentUrls[type] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUrl)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "Uploaded",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (file != null || hasUrl) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    isImage ? Icons.image : Icons.description,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName ?? 'Document selected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                    onPressed: () => _removeDocument(type),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          if (isUploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (!hasUrl)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDocument(type),
                    icon: Icon(Icons.upload_file, size: 16, color: color),
                    label: Text(
                      file == null ? "Upload Document" : "Change Document",
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildShopPhotosSection() {
    final isUploading = _documentUploading['shop_photos'] ?? false;
    final hasPhotos = _shopPhotoUrls.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Shop Photos",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Interior & exterior photos (2-5 images)",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPhotos)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${_shopPhotoUrls.length} uploaded",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Photo preview grid (if photos exist)
          if (_shopPhotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _shopPhotos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: FileImage(_shopPhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeShopPhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                    if (index < _shopPhotoUrls.length)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],

          const SizedBox(height: 16),

          // Upload button (styled like other document buttons)
          if (isUploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_shopPhotos.length < 5)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickMultipleShopPhotos,
                    icon: Icon(
                      _shopPhotos.isEmpty
                          ? Icons.add_photo_alternate
                          : Icons.add,
                      size: 16,
                      color: Colors.purple,
                    ),
                    label: Text(
                      _shopPhotos.isEmpty
                          ? "Add Shop Photos"
                          : "Add More Photos (${_shopPhotos.length}/5)",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.purple,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (_shopPhotos.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Clear All Photos"),
                            content: const Text(
                              "Are you sure you want to remove all shop photos?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _shopPhotos.clear();
                                    _shopPhotoUrls.clear();
                                  });
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text("Clear All"),
                              ),
                            ],
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(Icons.delete_outline, size: 18),
                    ),
                  ),
                ],
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Maximum 5 photos reached",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearAllPhotos,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text(
                      "Replace",
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),

          // Helper text for better UX
          if (_shopPhotos.isNotEmpty && _shopPhotos.length < 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 12,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "Add at least 2 photos for better visibility",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade700,
                        fontStyle: FontStyle.italic,
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

  void _clearAllPhotos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Photos"),
        content: const Text("Are you sure you want to remove all shop photos?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _shopPhotos.clear();
                _shopPhotoUrls.clear();
              });
              Navigator.pop(context);
              FirebaseSnackbar.success(context, "All photos removed");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isDesktop = size.width > 1100;
    final isSmallPhone = size.width < 360;

    double horizontalPadding = isSmallPhone ? 12 : 20;
    if (isTablet) horizontalPadding = size.width * 0.15;
    if (isDesktop) horizontalPadding = size.width * 0.25;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.support_agent,
                  size: 18,
                  color: Colors.deepPurple.shade300,
                ),
                const SizedBox(width: 4),
                Text(
                  "Help",
                  style: TextStyle(
                    color: Colors.deepPurple.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildProgressIndicator(),
                          const SizedBox(height: 24),

                          // Step content
                          _buildCurrentStepContent(),

                          const SizedBox(height: 30),

                          // Navigation buttons
                          _buildNavigationButtons(),

                          const SizedBox(height: 20),
                          _buildTrustBadges(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            "Become a Partner",
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Join India's fastest growing marketplace",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  "10,000+ Active Sellers",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStep(1, "Basic", _isStepComplete(1)),
              _buildStep(2, "Business", _isStepComplete(2)),
              _buildStep(3, "Delivery", _isStepComplete(3)),
              _buildStep(4, "Documents", _isStepComplete(4)),
              _buildStep(5, "Review", _isStepComplete(5)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _currentStep / _totalSteps,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Step $_currentStep of $_totalSteps",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  bool _isStepComplete(int step) {
    if (step < _currentStep) return true;
    if (step == _currentStep) {
      switch (step) {
        case 1:
          return _isBasicInfoComplete;
        case 2:
          return _isBusinessDetailsComplete;
        case 3:
          return _isDeliveryComplete;
        case 4:
          return _isDocumentsComplete;
        case 5:
          return agreeTerms && agreePrivacy && agreeCommission;
        default:
          return false;
      }
    }
    return false;
  }

  Widget _buildStep(int number, String label, bool isComplete) {
    final isActive = _currentStep == number;
    final isPast = number < _currentStep;

    Color backgroundColor;
    Color textColor;
    IconData? icon;

    if (isComplete || isPast) {
      backgroundColor = Colors.green;
      textColor = Colors.white;
      icon = Icons.check;
    } else if (isActive) {
      backgroundColor = Colors.deepPurple;
      textColor = Colors.white;
      icon = null;
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade600;
      icon = null;
    }

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            border: !isActive && !isComplete
                ? Border.all(color: Colors.grey.shade400)
                : null,
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 18)
                : Text(
                    number.toString(),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isActive
                ? Colors.deepPurple
                : isComplete
                ? Colors.green
                : Colors.grey.shade500,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildBasicInfoSection();
      case 2:
        return _buildBusinessDetailsSection();
      case 3:
        return Column(
          children: [
            _buildDeliverySection(),
            const SizedBox(height: 20),
            _buildPaymentSection(),
          ],
        );
      case 4:
        return Column(
          children: [
            _buildOperatingSection(),
            const SizedBox(height: 20),
            _buildDocumentsSection(),
          ],
        );
      case 5:
        return _buildReviewSection();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 1)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("Previous"),
            ),
          ),
        if (_currentStep > 1) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStep == _totalSteps ? submitForm : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _currentStep == _totalSteps ? "Submit Application" : "Continue",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: "Basic Information",
      icon: Icons.info_outline,
      child: Column(
        children: [
          _buildAnimatedTextField(
            label: "Shop Name",
            controller: shopNameController,
            icon: Icons.store,
            validator: (value) {
              if (value == null || value.isEmpty)
                return "Shop name is required";
              if (value.length < 3) return "Minimum 3 characters";
              if (value.length > 50) return "Maximum 50 characters";
              return null;
            },
          ),
          _buildAnimatedTextField(
            label: "Owner Name",
            controller: ownerNameController,
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty)
                return "Owner name is required";
              if (!RegExp(r'^[a-zA-Z\s\.]+$').hasMatch(value)) {
                return "Only letters, spaces, and dots allowed";
              }
              return null;
            },
          ),
          Row(
            children: [
              Expanded(
                child: _buildAnimatedTextField(
                  label: "Phone Number",
                  controller: phoneController,
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Phone required";
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                      return "Invalid Indian mobile number";
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnimatedTextField(
                  label: "Alternate Phone",
                  controller: alternatePhoneController,
                  icon: Icons.phone_android,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  required: false,
                ),
              ),
            ],
          ),
          _buildAnimatedTextField(
            label: "Email Address",
            controller: emailController,
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return "Email required";
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value)) {
                return "Invalid email format";
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessDetailsSection() {
    return _buildSectionCard(
      title: "Business Details",
      icon: Icons.business_center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown(
            label: "Business Type",
            value: businessType,
            items: businessTypes,
            onChanged: (value) => setState(() => businessType = value),
          ),
          const SizedBox(height: 16),
          _buildCategorySelector(),
          const SizedBox(height: 16),
          _buildExperienceSelector(),
          const SizedBox(height: 16),
          _buildShopSizeSelector(),
          const SizedBox(height: 16),
          _buildAnimatedTextField(
            label: "GST Number (Optional)",
            controller: gstController,
            icon: Icons.receipt,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
              LengthLimitingTextInputFormatter(15),
            ],
            required: false,
          ),
          _buildAnimatedTextField(
            label: "PAN Number (Optional)",
            controller: panController,
            icon: Icons.assignment_ind,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
              UpperCaseTextFormatter(),
              LengthLimitingTextInputFormatter(10),
            ],
            required: false,
          ),
          _buildAnimatedTextField(
            label: "Website / Social Media (Optional)",
            controller: websiteController,
            icon: Icons.language,
            keyboardType: TextInputType.url,
            required: false,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return _buildSectionCard(
      title: "Delivery & Services",
      icon: Icons.local_shipping,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Delivery Options (Select all that apply)",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: deliveryOptions.length,
            itemBuilder: (context, index) {
              final option = deliveryOptions[index];
              final isSelected = selectedDeliveryOptions.contains(
                option["value"],
              );

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedDeliveryOptions.remove(option["value"]);
                    } else {
                      selectedDeliveryOptions.add(option["value"]);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? option["color"].withOpacity(0.1)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? option["color"]
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option["icon"],
                        color: isSelected
                            ? option["color"]
                            : Colors.grey.shade600,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option["label"],
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? option["color"]
                              : Colors.grey.shade700,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          _buildDropdown(
            label: "Delivery Radius",
            value: deliveryRadius,
            items: radiusOptions
                .map((e) => {"value": e, "label": e, "icon": Icons.radar})
                .toList(),
            onChanged: (value) => setState(() => deliveryRadius = value),
          ),
          _buildDropdown(
            label: "Minimum Order Value",
            value: minimumOrderValue,
            items: minOrderOptions
                .map(
                  (e) => {"value": e, "label": e, "icon": Icons.currency_rupee},
                )
                .toList(),
            onChanged: (value) => setState(() => minimumOrderValue = value),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return _buildSectionCard(
      title: "Payment Methods",
      icon: Icons.payment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Accepted Payment Methods",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: paymentMethods.map((method) {
              final isSelected = selectedPaymentMethods.contains(
                method["value"],
              );
              return FilterChip(
                selected: isSelected,
                label: Text(method["label"]),
                avatar: Icon(method["icon"], size: 18),
                backgroundColor: Colors.grey.shade50,
                selectedColor: method["color"].withOpacity(0.1),
                checkmarkColor: method["color"],
                labelStyle: TextStyle(
                  color: isSelected ? method["color"] : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedPaymentMethods.add(method["value"]);
                    } else {
                      selectedPaymentMethods.remove(method["value"]);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatingSection() {
    return _buildSectionCard(
      title: "Operating Hours",
      icon: Icons.access_time,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown(
            label: "Operating Hours",
            value: operatingHours,
            items: operatingHoursList
                .map((e) => {"value": e, "label": e, "icon": Icons.schedule})
                .toList(),
            onChanged: (value) => setState(() => operatingHours = value),
          ),
          const SizedBox(height: 16),
          const Text(
            "Operating Days",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: weekDays.map((day) {
              final isSelected = selectedDays.contains(day);
              return ChoiceChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(day.substring(0, 3)),
                  ],
                ),
                backgroundColor: Colors.grey.shade50,
                selectedColor: Colors.deepPurple,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      selectedDays.add(day);
                    } else {
                      selectedDays.remove(day);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _buildAnimatedTextField(
            label: "Complete Address",
            controller: addressController,
            icon: Icons.location_on,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) return "Address required";
              if (value.length < 15) return "Please enter complete address";
              return null;
            },
          ),
          _buildAnimatedTextField(
            label: "Shop Description",
            controller: descriptionController,
            icon: Icons.description,
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) return "Description required";
              if (value.length < 30) return "Minimum 30 characters";
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return _buildSectionCard(
      title: "Documents & Verification",
      icon: Icons.verified,
      child: Column(
        children: [
          _buildDocumentUploadTile(
            type: 'gst',
            title: "GST Certificate",
            description: "Required for businesses with > ₹40L turnover",
            icon: Icons.receipt_long,
            color: Colors.orange,
          ),

          _buildDocumentUploadTile(
            type: 'pan',
            title: "PAN Card",
            description: "Required for all businesses",
            icon: Icons.credit_card,
            color: Colors.blue,
          ),

          _buildDocumentUploadTile(
            type: 'address_proof',
            title: "Address Proof",
            description: "Electricity bill / Rent agreement",
            icon: Icons.home_work,
            color: Colors.green,
          ),

          _buildShopPhotosSection(),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.amber.shade800,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "All documents will be verified within 24-48 hours. Make sure they are clear and legible.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade900,
                      height: 1.4,
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

  Widget _buildReviewSection() {
    return _buildSectionCard(
      title: "Review & Submit",
      icon: Icons.reviews,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Review
          _buildReviewTile("Basic Information", Icons.info_outline, [
            "Shop: ${shopNameController.text}",
            "Owner: ${ownerNameController.text}",
            "Phone: ${phoneController.text}",
            "Email: ${emailController.text}",
          ]),

          // Business Details Review
          _buildReviewTile("Business Details", Icons.business_center, [
            "Category: $selectedCategory",
            if (selectedSubCategory != null)
              "Sub-category: $selectedSubCategory",
            "Business Type: $businessType",
            if (experienceLevel != null) "Experience: $experienceLevel",
            if (shopSize != null) "Shop Size: $shopSize",
          ]),

          // Delivery Review
          _buildReviewTile("Delivery & Services", Icons.local_shipping, [
            "Delivery Options: ${selectedDeliveryOptions.length} selected",
            "Payment Methods: ${selectedPaymentMethods.length} selected",
            if (deliveryRadius != null) "Radius: $deliveryRadius",
            if (minimumOrderValue != null) "Min Order: $minimumOrderValue",
          ]),

          // Operating Review
          _buildReviewTile("Operating Hours", Icons.access_time, [
            "Hours: ${operatingHours ?? 'Not set'}",
            "Days: ${selectedDays.length} days",
            "Address: ${addressController.text.length > 30 ? '${addressController.text.substring(0, 30)}...' : addressController.text}",
          ]),

          // Documents Review Section
          _buildDocumentsReviewTile(),

          const SizedBox(height: 20),

          // Terms Section
          _buildTermsSection(),
        ],
      ),
    );
  }

  Widget _buildDocumentsReviewTile() {
    // Count uploaded documents
    int uploadedCount = 0;
    if (_documentUrls['gst'] != null) uploadedCount++;
    if (_documentUrls['pan'] != null) uploadedCount++;
    if (_documentUrls['address_proof'] != null) uploadedCount++;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.upload_file, size: 18, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Text(
                "Documents",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: uploadedCount > 0
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$uploadedCount/4 Uploaded",
                  style: TextStyle(
                    fontSize: 12,
                    color: uploadedCount > 0
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Document Status List
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // GST Status
                _buildDocumentStatusTile(
                  icon: Icons.receipt_long,
                  title: "GST Certificate",
                  status: _documentUrls['gst'] != null,
                  color: Colors.orange,
                ),
                const Divider(height: 16),

                // PAN Status
                _buildDocumentStatusTile(
                  icon: Icons.credit_card,
                  title: "PAN Card",
                  status: _documentUrls['pan'] != null,
                  color: Colors.blue,
                ),
                const Divider(height: 16),

                // Address Proof Status
                _buildDocumentStatusTile(
                  icon: Icons.home_work,
                  title: "Address Proof",
                  status: _documentUrls['address_proof'] != null,
                  color: Colors.green,
                ),
                const Divider(height: 16),

                // Shop Photos Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.photo_camera,
                        size: 16,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Shop Photos",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _shopPhotoUrls.isNotEmpty
                                ? "${_shopPhotoUrls.length} photos uploaded"
                                : "Not uploaded",
                            style: TextStyle(
                              fontSize: 11,
                              color: _shopPhotoUrls.isNotEmpty
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _shopPhotoUrls.isNotEmpty
                          ? Icons.check_circle
                          : Icons.error_outline,
                      size: 16,
                      color: _shopPhotoUrls.isNotEmpty
                          ? Colors.green
                          : Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Shop Photos Preview (if available)
          if (_shopPhotoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              "Shop Photos Preview",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _shopPhotos.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                      image: DecorationImage(
                        image: FileImage(_shopPhotos[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: index < _shopPhotoUrls.length
                        ? Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentStatusTile({
    required IconData icon,
    required String title,
    required bool status,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                status ? "Uploaded" : "Not uploaded",
                style: TextStyle(
                  fontSize: 11,
                  color: status ? Colors.green.shade700 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Icon(
          status ? Icons.check_circle : Icons.error_outline,
          size: 16,
          color: status ? Colors.green : Colors.grey.shade400,
        ),
      ],
    );
  }

  Widget _buildReviewTile(String title, IconData icon, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: agreeTerms,
            title: Text(
              "I agree to the Seller Terms & Conditions",
              style: GoogleFonts.inter(fontSize: 14),
            ),
            subtitle: Text(
              "Review our marketplace policies and commission structure",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => agreeTerms = value!),
          ),
          CheckboxListTile(
            value: agreePrivacy,
            title: Text(
              "Privacy Policy & Data Processing",
              style: GoogleFonts.inter(fontSize: 14),
            ),
            subtitle: Text(
              "How we handle your business information",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => agreePrivacy = value!),
          ),
          CheckboxListTile(
            value: agreeCommission,
            title: Text(
              "Commission & Fee Structure",
              style: GoogleFonts.inter(fontSize: 14),
            ),
            subtitle: Text(
              "Standard commission: 5-15% based on category",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => agreeCommission = value!),
          ),
          const Divider(height: 30),
          SwitchListTile(
            value: receiveUpdates,
            title: Text(
              "Receive Application Updates",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              "Get notified about your application status",
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            activeColor: Colors.deepPurple,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() => receiveUpdates = value),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadges() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTrustBadge(Icons.security, "Secure"),
        Container(width: 1, height: 20, color: Colors.grey.shade300),
        _buildTrustBadge(Icons.verified_user, "Verified"),
        Container(width: 1, height: 20, color: Colors.grey.shade300),
        _buildTrustBadge(Icons.support_agent, "Support"),
      ],
    );
  }

  Widget _buildTrustBadge(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.deepPurple, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
    bool required = true,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Focus(
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator ?? (required ? _defaultValidator(label) : null),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            prefixIcon: Icon(icon, color: Colors.deepPurple.shade300),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.deepPurple, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  String? Function(String?) _defaultValidator(String label) {
    return (value) {
      if (value == null || value.isEmpty) {
        return "$label is required";
      }
      return null;
    };
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              hint: Text("Select $label"),
              items: items.map<DropdownMenuItem<String>>((item) {
                return DropdownMenuItem<String>(
                  value: item["value"] as String?,
                  child: Row(
                    children: [
                      if (item.containsKey("icon"))
                        Icon(
                          item["icon"] as IconData,
                          size: 20,
                          color: Colors.deepPurple.shade300,
                        ),
                      if (item.containsKey("icon")) const SizedBox(width: 12),
                      Text(item["label"] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Business Category *",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
            ),
            hint: const Text("Select Category"),
            items: categoryMap.keys.map((category) {
              return DropdownMenuItem(value: category, child: Text(category));
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value;
                selectedSubCategory = null;
              });
            },
          ),
        ),
        if (selectedCategory != null) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonFormField<String>(
              value: selectedSubCategory,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              hint: const Text("Select Sub-category"),
              items: categoryMap[selectedCategory]!.map((subCat) {
                return DropdownMenuItem(value: subCat, child: Text(subCat));
              }).toList(),
              onChanged: (value) => setState(() => selectedSubCategory = value),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExperienceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Experience Level",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: experienceLevels.map((level) {
            final isSelected = experienceLevel == level["value"];
            return ChoiceChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(level["icon"], size: 16),
                  const SizedBox(width: 4),
                  Text(level["label"]),
                ],
              ),
              backgroundColor: Colors.grey.shade50,
              selectedColor: Colors.deepPurple.withOpacity(0.1),
              labelStyle: TextStyle(
                color: isSelected ? Colors.deepPurple : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected) setState(() => experienceLevel = level["value"]);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildShopSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Shop Size",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: shopSizes.map((size) {
            final isSelected = shopSize == size["value"];
            return FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(size["icon"], size: 16),
                  const SizedBox(width: 4),
                  Text(size["label"]),
                ],
              ),
              backgroundColor: Colors.grey.shade50,
              selectedColor: Colors.deepPurple.withOpacity(0.1),
              checkmarkColor: Colors.deepPurple,
              labelStyle: TextStyle(
                color: isSelected ? Colors.deepPurple : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected) setState(() => shopSize = size["value"]);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Custom TextFormatter for uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
