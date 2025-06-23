import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import '../models/food_candidate.dart';
import '../models/meal_event.dart';
import 'auth_service.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final AuthService _authService = AuthService.instance;

  // 업로드 URL을 받기 위한 API 엔드포인트
  static const String _getUploadUrlEndpoint =
      'https://t2n2c874oj.execute-api.us-east-1.amazonaws.com/v1/upload-url';

  // 분석 URL을 호출하기 위한 API 엔드포인트 (이미지 업로드 성공 후)
  static const String _analysisEndpoint =
      'https://t2n2c874oj.execute-api.us-east-1.amazonaws.com/v1/analyze';

  // 식사 기록을 저장하기 위한 API 엔드포인트
  static const String _saveMealEndpoint =
      'https://t2n2c874oj.execute-api.us-east-1.amazonaws.com/v1/food-logs';

  Future<List<FoodCandidate>?> uploadImage(XFile imageFile) async {
    try {
      // Bearer 토큰 가져오기
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('인증 토큰을 가져올 수 없습니다. 다시 로그인해주세요.');
      }

      // 1단계: GET으로 업로드 URL과 objectKey 받기
      final uploadData = await _getUploadUrl(token);
      if (uploadData == null ||
          uploadData['uploadUrl'] == null ||
          uploadData['objectKey'] == null) {
        throw Exception('업로드 URL 또는 objectKey를 받아올 수 없습니다.');
      }
      final uploadUrl = uploadData['uploadUrl']!;
      final objectKey = uploadData['objectKey']!;

      // 2단계: 받은 URL로 이미지 업로드
      final uploadSuccess = await _uploadToUrl(imageFile, uploadUrl);
      if (!uploadSuccess) {
        throw Exception('이미지 업로드에 실패했습니다.');
      }

      // 3단계: 분석 API 호출
      final analysisResult = await _callAnalysisApi(token, objectKey);
      return analysisResult;
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  Future<void> saveMealEvent(MealEvent event) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('인증 토큰을 가져올 수 없습니다. 다시 로그인해주세요.');
      }

      final response = await http.post(
        Uri.parse(_saveMealEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
        body: json.encode({
          'food_name': event.food.name,
          'calories': event.food.calories,
          'meal_type': event.mealType.name, // 'breakfast', 'lunch', etc.
          'eaten_at': event.timestamp.toIso8601String(),
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to save meal event: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error saving meal event: $e');
    }
  }

  // GET으로 업로드 URL 받기 (Bearer 토큰 포함)
  Future<Map<String, String?>?> _getUploadUrl(String token) async {
    try {
      final response = await http.get(
        Uri.parse(_getUploadUrlEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return {
          'uploadUrl': jsonResponse['uploadUrl'],
          'objectKey': jsonResponse['objectKey'],
        };
      } else {
        throw Exception('Failed to get upload URL: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting upload URL: $e');
    }
  }

  // 받은 URL로 이미지 업로드
  Future<bool> _uploadToUrl(XFile imageFile, String uploadUrl) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final mimeType = lookupMimeType(imageFile.name) ?? 'application/octet-stream';

      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'Content-Type': mimeType,
        },
        body: imageBytes,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print(e);
      throw Exception('Error uploading to URL: $e');
    }
  }

  // 분석 API 호출 (Bearer 토큰 포함)
  Future<List<FoodCandidate>?> _callAnalysisApi(
      String token, String objectKey) async {
    try {
      final response = await http.post(
        Uri.parse(_analysisEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'objectKey': objectKey,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> candidatesJson = jsonResponse['candidates'];
        return candidatesJson
            .map((json) => FoodCandidate.fromJson(json))
            .toList();
      } else {
        throw Exception('Analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error calling analysis API: $e');
    }
  }

  // 이미지 압축 (선택사항)
  Future<File> compressImage(File imageFile) async {
    // TODO: 이미지 압축 로직 구현
    // image_compression 패키지를 사용할 수 있습니다
    return imageFile;
  }
}
