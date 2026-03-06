import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProvider extends ChangeNotifier {
  int _pendingRequests = 0;
  int _totalOwners = 0;

  int get pendingRequests => _pendingRequests;
  int get totalOwners => _totalOwners;

  AdminProvider() {
    _listenToStats();
  }

  void _listenToStats() {
    // Listen to pending requests
    FirebaseFirestore.instance
        .collection('owner_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
          _pendingRequests = snapshot.docs.length;
          notifyListeners();
        });

    // Listen to total owners
    FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'owner')
        .snapshots()
        .listen((snapshot) {
          _totalOwners = snapshot.docs.length;
          notifyListeners();
        });
  }

  Future<void> refreshStats() async {
    // Manual refresh if needed
    notifyListeners();
  }
}
