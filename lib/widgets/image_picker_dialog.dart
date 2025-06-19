import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerDialog extends StatelessWidget {
  const ImagePickerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('사진 선택'),
      content: const Text('사진을 촬영하거나 갤러리에서 선택하세요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('camera'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 8),
              Text('카메라'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('gallery'),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library),
              SizedBox(width: 8),
              Text('갤러리'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pickImageFromCamera() async {
    try {
      // 카메라 권한 요청
      var status = await Permission.camera.request();
      if (status.isDenied) {
        throw Exception('카메라 권한이 필요합니다.');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // 이미지 품질 설정
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('카메라 오류: $e');
    }
  }

  static Future<File?> pickImageFromGallery() async {
    try {
      // 갤러리 권한 요청
      var status = await Permission.photos.request();
      if (status.isDenied) {
        throw Exception('갤러리 권한이 필요합니다.');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 이미지 품질 설정
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      throw Exception('갤러리 오류: $e');
    }
  }

  static Future<File?> showImagePickerDialog(BuildContext context) async {
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
