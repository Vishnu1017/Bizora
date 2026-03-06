import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreConverter {
  static dynamic convert(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is Map) {
      return value.map((key, val) => MapEntry(key, convert(val)));
    }

    if (value is List) {
      return value.map((e) => convert(e)).toList();
    }

    return value;
  }
}
