import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create an owner request when a user is manually promoted to owner by admin
  Future<void> createOwnerRequestFromPromotion({
    required String userId,
    required String adminId,
    required String adminEmail,
    String? adminNote,
  }) async {
    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;

      // Check if an owner request already exists
      final existingRequest = await _firestore
          .collection('owner_requests')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        // Update existing request
        final requestId = existingRequest.docs.first.id;
        await _firestore.collection('owner_requests').doc(requestId).update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': adminId,
          'approvedByEmail': adminEmail,
          'adminNote': adminNote ?? 'Promoted to owner by admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new owner request with complete data
        await _firestore.collection('owner_requests').add({
          'userId': userId,
          'email': userData['email'] ?? '',
          'phone': userData['phone'] ?? userData['phoneNumber'] ?? '',
          'displayName': userData['displayName'] ?? '',
          'shopName':
              userData['shopName'] ??
              '${userData['displayName'] ?? 'User'}\'s Shop',
          'ownerName': userData['displayName'] ?? '',
          'category': userData['businessCategory'] ?? 'General',
          'deliveryType': userData['deliveryType'] ?? 'Standard',
          'address': userData['address'] ?? '',
          'description': userData['businessDescription'] ?? '',
          'gstNumber': userData['gstNumber'] ?? '',
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': adminId,
          'approvedByEmail': adminEmail,
          'adminNote': adminNote ?? 'Promoted to owner by admin',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Log activity
      await _firestore.collection('admin_activity').add({
        'type': 'owner_promotion',
        'userId': userId,
        'adminId': adminId,
        'adminEmail': adminEmail,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'User promoted to owner role',
        'note': adminNote,
      });
    } catch (e) {
      print('Error creating owner request from promotion: $e');
      rethrow;
    }
  }

  /// Update owner request status when user role is changed
  Future<void> syncUserRoleWithOwnerRequest({
    required String userId,
    required String newRole,
    required String adminId,
    required String adminEmail,
    String? reason,
  }) async {
    try {
      // Find existing owner request
      final requestQuery = await _firestore
          .collection('owner_requests')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (requestQuery.docs.isEmpty) {
        // No existing request, create one if role is owner
        if (newRole == 'owner') {
          await createOwnerRequestFromPromotion(
            userId: userId,
            adminId: adminId,
            adminEmail: adminEmail,
            adminNote: reason,
          );
        }
        return;
      }

      final requestDoc = requestQuery.docs.first;
      final requestId = requestDoc.id;

      // Update based on new role
      if (newRole == 'owner') {
        // If role changed to owner, approve the request
        await _firestore.collection('owner_requests').doc(requestId).update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': adminId,
          'approvedByEmail': adminEmail,
          'adminNote': reason ?? 'Role changed to owner',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (newRole == 'user') {
        // If role changed from owner to user, mark as rejected
        await _firestore.collection('owner_requests').doc(requestId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': adminId,
          'rejectedByEmail': adminEmail,
          'rejectionReason': reason ?? 'Owner role revoked',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error syncing role with owner request: $e');
      rethrow;
    }
  }

  /// Get pending owner requests count
  Future<int> getPendingRequestsCount() async {
    try {
      final snapshot = await _firestore
          .collection('owner_requests')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('Error getting pending count: $e');
      return 0;
    }
  }

  /// Listen to real-time changes in owner requests
  Stream<QuerySnapshot> listenToOwnerRequests() {
    return _firestore
        .collection('owner_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
