import 'package:bizora/services/security_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityQuestion {
  final String id;
  final String question;
  final String answerHash;
  final DateTime createdAt;

  SecurityQuestion({
    required this.id,
    required this.question,
    required this.answerHash,
    required this.createdAt,
  });

  factory SecurityQuestion.fromJson(Map<String, dynamic> json) {
    return SecurityQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      answerHash: json['answerHash'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answerHash': answerHash,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class LoginHistory {
  final String id;
  final DateTime timestamp;
  final String deviceInfo;
  final String location;
  final String ipAddress;
  final bool success;
  final String failureReason;

  LoginHistory({
    required this.id,
    required this.timestamp,
    required this.deviceInfo,
    required this.location,
    required this.ipAddress,
    required this.success,
    this.failureReason = '',
  });

  factory LoginHistory.fromJson(Map<String, dynamic> json) {
    return LoginHistory(
      id: json['id'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deviceInfo: json['deviceInfo'] ?? '',
      location: json['location'] ?? '',
      ipAddress: json['ipAddress'] ?? '',
      success: json['success'] ?? false,
      failureReason: json['failureReason'] ?? '',
    );
  }
}

class SecuritySettings {
  final bool twoFactorEnabled;
  final bool loginNotifications;
  final bool suspiciousActivityAlerts;
  final List<String> trustedDevices;
  final DateTime? lastPasswordChange;
  final SecurityLevel securityLevel;
  final int maxLoginAttempts;
  final bool requireBiometrics;
  final int sessionTimeoutMinutes;

  SecuritySettings({
    required this.twoFactorEnabled,
    required this.loginNotifications,
    required this.suspiciousActivityAlerts,
    required this.trustedDevices,
    this.lastPasswordChange,
    required this.securityLevel,
    this.maxLoginAttempts = 5,
    this.requireBiometrics = false,
    this.sessionTimeoutMinutes = 30,
  });

  factory SecuritySettings.default_() {
    return SecuritySettings(
      twoFactorEnabled: false,
      loginNotifications: true,
      suspiciousActivityAlerts: true,
      trustedDevices: [],
      securityLevel: SecurityLevel.medium,
    );
  }

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      twoFactorEnabled: json['twoFactorEnabled'] ?? false,
      loginNotifications: json['loginNotifications'] ?? true,
      suspiciousActivityAlerts: json['suspiciousActivityAlerts'] ?? true,
      trustedDevices: List<String>.from(json['trustedDevices'] ?? []),
      lastPasswordChange: json['lastPasswordChange'] != null
          ? (json['lastPasswordChange'] as Timestamp).toDate()
          : null,
      securityLevel: SecurityLevel
          .values[json['securityLevel'] ?? SecurityLevel.medium.index],
      maxLoginAttempts: json['maxLoginAttempts'] ?? 5,
      requireBiometrics: json['requireBiometrics'] ?? false,
      sessionTimeoutMinutes: json['sessionTimeoutMinutes'] ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'twoFactorEnabled': twoFactorEnabled,
      'loginNotifications': loginNotifications,
      'suspiciousActivityAlerts': suspiciousActivityAlerts,
      'trustedDevices': trustedDevices,
      'lastPasswordChange': lastPasswordChange != null
          ? Timestamp.fromDate(lastPasswordChange!)
          : null,
      'securityLevel': securityLevel.index,
      'maxLoginAttempts': maxLoginAttempts,
      'requireBiometrics': requireBiometrics,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,
    };
  }
}
