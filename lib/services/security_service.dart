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

// 🔥 ONLY CHANGES INSIDE THIS FILE (NO FUNCTION REMOVED)

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // ✅ IMPROVED RATE LIMITING
  final Map<String, List<DateTime>> _actionTimestamps = {};
  static const int _maxAttempts = 5; // 🔥 increased
  static const Duration _rateLimitWindow = Duration(minutes: 15);

  // ✅ IMPROVED SUSPICIOUS TRACKING
  final Map<String, int> _suspiciousActivities = {};
  final Map<String, DateTime> _lastSuspiciousReset = {};

  static const int _maxSuspiciousActivities = 8; // 🔥 increased (important)
  static const Duration _suspiciousCooldown = Duration(minutes: 30);

  // Encryption
  static const String _encryptionKey = 'your-32-character-encryption-key!!';
  late final encrypt.Encrypter _encrypter;
  late final encrypt.IV _iv;

  SecurityService._internal() {
    final key = encrypt.Key.fromUtf8(_encryptionKey);
    _iv = encrypt.IV.fromLength(16);
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  /// ✅ RATE LIMIT (SAFE)
  bool checkRateLimit(String userId, String action) {
    final key = '$userId:$action';
    final now = DateTime.now();

    if (!_actionTimestamps.containsKey(key)) {
      _actionTimestamps[key] = [now];
      return true;
    }

    _actionTimestamps[key] = _actionTimestamps[key]!
        .where((time) => now.difference(time) < _rateLimitWindow)
        .toList();

    if (_actionTimestamps[key]!.length >= _maxAttempts) {
      return false;
    }

    _actionTimestamps[key]!.add(now);
    return true;
  }

  /// ✅ FIXED SUSPICIOUS ACTIVITY (NO RANDOM LOCKS)
  Future<void> logSuspiciousActivity(String userId, String activity) async {
    final now = DateTime.now();

    // 🔥 RESET COUNTER AFTER COOLDOWN
    if (_lastSuspiciousReset[userId] == null ||
        now.difference(_lastSuspiciousReset[userId]!) > _suspiciousCooldown) {
      _suspiciousActivities[userId] = 0;
      _lastSuspiciousReset[userId] = now;
    }

    _suspiciousActivities[userId] = (_suspiciousActivities[userId] ?? 0) + 1;

    final deviceInfo = await getDeviceInfo();

    // 🔥 ALWAYS LOG (for audit)
    await FirebaseFirestore.instance.collection('security_logs').add({
      'userId': userId,
      'activity': activity,
      'timestamp': FieldValue.serverTimestamp(),
      'deviceInfo': deviceInfo,
      'appVersion': await getAppVersion(),
      'severity': 'WARNING',
    });

    print("⚠️ Suspicious count for $userId = ${_suspiciousActivities[userId]}");

    // ✅ 🔥 ONLY LOCK IF REALLY EXCESSIVE
    if (_suspiciousActivities[userId]! >= _maxSuspiciousActivities) {
      print("🚨 High suspicious activity detected (not locking immediately)");

      // 🔥 Instead of locking immediately → just alert
      await FirebaseFirestore.instance.collection('security_alerts').add({
        'userId': userId,
        'message': 'High suspicious activity detected',
        'count': _suspiciousActivities[userId],
        'timestamp': FieldValue.serverTimestamp(),
      });

      // ❗ OPTIONAL HARD LOCK (VERY STRICT)
      // Uncomment ONLY if needed:
      /*
      await lockAccount(
        userId,
        'Excessive suspicious activity detected',
      );
      */
    }
  }

  /// 🔒 LOCK ACCOUNT (UNCHANGED)
  Future<void> lockAccount(String userId, String reason) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'accountLocked': true,
      'lockReason': reason,
      'lockedAt': FieldValue.serverTimestamp(),
      'securityLevel': SecurityLevel.maximum.index,
    });
  }

  /// HASH (UNCHANGED)
  String generateAuditHash(Map<String, dynamic> data) {
    final jsonString = jsonEncode(FirestoreConverter.convert(data));
    return sha256.convert(utf8.encode(jsonString)).toString();
  }

  bool verifyDataIntegrity(Map<String, dynamic> data, String hash) {
    final computedHash = generateAuditHash(data);
    return computedHash == hash;
  }

  /// ENCRYPTION (UNCHANGED)
  String encryptData(String data) {
    return _encrypter.encrypt(data, iv: _iv).base64;
  }

  String decryptData(String encryptedData) {
    try {
      return _encrypter.decrypt64(encryptedData, iv: _iv);
    } catch (e) {
      return '';
    }
  }

  /// DEVICE INFO (UNCHANGED)
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

  Future<String> getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<void> storeBiometricKey(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> getBiometricKey(String key) async {
    return await _secureStorage.read(key: key);
  }

  String generateSecureToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// SESSION VALIDATION (UNCHANGED)
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

  Future<void> endSession(String userId, String sessionToken) async {
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc('$userId:$sessionToken')
        .delete();
  }
}
