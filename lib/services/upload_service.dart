import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UploadService {
  static Future<UploadTask> uploadCompressedImage({
    required File imageFile,
    required String uid,
  }) async {
    /// Compress image (reduces upload size drastically)
    Uint8List? compressed = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      minWidth: 800,
      minHeight: 800,
      quality: 65,
    );

    if (compressed == null) {
      throw Exception("Image compression failed");
    }

    String fileName =
        "profile_${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg";

    final ref = FirebaseStorage.instance
        .ref()
        .child("profile_pictures")
        .child(uid)
        .child(fileName);

    return ref.putData(compressed, SettableMetadata(contentType: "image/jpeg"));
  }
}
