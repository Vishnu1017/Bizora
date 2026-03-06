import 'dart:convert';
import 'dart:math';
import 'package:bizora/core/utils/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

enum SecurityLevel { low, medium, high, maximum }

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Rate limiting
  final Map<String, List<DateTime>> _actionTimestamps = {};
  static const int _maxAttempts = 3;
  static const Duration _rateLimitWindow = Duration(minutes: 15);

  // Suspicious activity tracking
  final Map<String, int> _suspiciousActivities = {};
  static const int _maxSuspiciousActivities = 3;

  // Encryption key (in production, this should be stored in secure hardware)
  static const String _encryptionKey = 'your-32-character-encryption-key!!';
  late final encrypt.Encrypter _encrypter;
  late final encrypt.IV _iv;

  SecurityService._internal() {
    final key = encrypt.Key.fromUtf8(_encryptionKey);
    _iv = encrypt.IV.fromLength(16);
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  /// Rate limiting check
  bool checkRateLimit(String userId, String action) {
    final key = '$userId:$action';
    final now = DateTime.now();

    if (!_actionTimestamps.containsKey(key)) {
      _actionTimestamps[key] = [now];
      return true;
    }

    // Remove old timestamps
    _actionTimestamps[key] = _actionTimestamps[key]!
        .where((time) => now.difference(time) < _rateLimitWindow)
        .toList();

    if (_actionTimestamps[key]!.length >= _maxAttempts) {
      return false;
    }

    _actionTimestamps[key]!.add(now);
    return true;
  }

  /// Log suspicious activity
  Future<void> logSuspiciousActivity(String userId, String activity) async {
    _suspiciousActivities[userId] = (_suspiciousActivities[userId] ?? 0) + 1;

    // Get device info
    final deviceInfo = await getDeviceInfo();

    // Store in Firestore for security audit
    await FirebaseFirestore.instance.collection('security_logs').add({
      'userId': userId,
      'activity': activity,
      'timestamp': FieldValue.serverTimestamp(),
      'deviceInfo': deviceInfo,
      'appVersion': await getAppVersion(),
      'severity': 'WARNING',
    });

    // If too many suspicious activities, lock account
    if (_suspiciousActivities[userId]! >= _maxSuspiciousActivities) {
      await lockAccount(userId, 'Multiple suspicious activities detected');
    }
  }

  /// Lock account
  Future<void> lockAccount(String userId, String reason) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'accountLocked': true,
      'lockReason': reason,
      'lockedAt': FieldValue.serverTimestamp(),
      'securityLevel': SecurityLevel.maximum.index,
    });
  }

  /// Generate audit hash
  String generateAuditHash(Map<String, dynamic> data) {
    final jsonString = jsonEncode(FirestoreConverter.convert(data));
    return sha256.convert(utf8.encode(jsonString)).toString();
  }

  /// Verify data integrity
  bool verifyDataIntegrity(Map<String, dynamic> data, String hash) {
    final computedHash = generateAuditHash(data);
    return computedHash == hash;
  }

  /// Encrypt sensitive data
  String encryptData(String data) {
    return _encrypter.encrypt(data, iv: _iv).base64;
  }

  /// Decrypt sensitive data
  String decryptData(String encryptedData) {
    try {
      return _encrypter.decrypt64(encryptedData, iv: _iv);
    } catch (e) {
      return '';
    }
  }

  /// Get device fingerprint
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return {
        'deviceId': iosInfo.identifierForVendor,
        'model': iosInfo.model,
        'systemVersion': iosInfo.systemVersion,
        'platform': 'iOS',
      };
    } else {
      final androidInfo = await _deviceInfo.androidInfo;
      return {
        'deviceId': androidInfo.id,
        'model': androidInfo.model,
        'systemVersion': androidInfo.version.release,
        'platform': 'Android',
      };
    }
  }

  /// Get app version
  Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Store biometric key
  Future<void> storeBiometricKey(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// Retrieve biometric key
  Future<String?> getBiometricKey(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// Generate secure random token
  String generateSecureToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Validate session
  Future<bool> validateSession(String userId, String sessionToken) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('sessions')
          .doc('$userId:$sessionToken')
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final expiry = (data['expiry'] as Timestamp).toDate();

      return expiry.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  /// Create session
  Future<String> createSession(String userId) async {
    final sessionToken = generateSecureToken();
    final expiry = DateTime.now().add(const Duration(hours: 24));

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc('$userId:$sessionToken')
        .set({
          'userId': userId,
          'sessionToken': sessionToken,
          'createdAt': FieldValue.serverTimestamp(),
          'expiry': Timestamp.fromDate(expiry),
          'deviceInfo': await getDeviceInfo(),
        });

    return sessionToken;
  }

  /// End session
  Future<void> endSession(String userId, String sessionToken) async {
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc('$userId:$sessionToken')
        .delete();
  }
}
