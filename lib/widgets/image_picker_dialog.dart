import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerDialog extends StatelessWidget {
  const ImagePickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Photo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Take a photo or choose from gallery'),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop('camera'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt),
                const SizedBox(width: 8),
                Text('Camera'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('gallery'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library),
                const SizedBox(width: 8),
                Text('Gallery'),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
      ],
      actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
    );
  }
}

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickImageFromCamera() async {
    try {
      if (!kIsWeb) {
        // 카메라 권한 요청
        var status = await Permission.camera.request();
        if (status.isDenied) {
          throw Exception('Camera permission is required.');
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // 이미지 품질 설정
      );

      return image;
    } catch (e) {
      throw Exception('Camera error: $e');
    }
  }

  static Future<XFile?> pickImageFromGallery() async {
    try {
      if (!kIsWeb) {
        // 갤러리 권한 요청
        var status = await Permission.photos.request();
        if (status.isDenied) {
          throw Exception('Gallery permission is required.');
        }
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 이미지 품질 설정
      );

      return image;
    } catch (e) {
      throw Exception('Gallery error: $e');
    }
  }

  static Future<XFile?> showImagePickerDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const ImagePickerDialog(),
    );

    if (result == 'camera') {
      return await pickImageFromCamera();
    } else if (result == 'gallery') {
      return await pickImageFromGallery();
    }
    return null;
  }
}
