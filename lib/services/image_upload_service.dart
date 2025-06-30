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
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final AuthService _authService = AuthService.instance;
  final String _apiUrl = dotenv.env['API_URL'] ??
      (throw Exception('API_URL not found in .env file'));

  String get _getUploadUrlEndpoint => '$_apiUrl/upload-url';
  String get _analysisEndpoint => '$_apiUrl/analyze';
  String get _saveMealEndpoint => '$_apiUrl/food-logs';

  Future<Map<String, dynamic>?> uploadImage(XFile imageFile) async {
    try {
      // Bearer 토큰 가져오기
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('인증 토큰을 가져올 수 없습니다. 다시 로그인해주세요.');
      }

      // 1단계: GET으로 업로드 URL과 objectKey 받기
      final uploadData = await _getUploadUrl(token);
      if (uploadData == null) {
        throw Exception('업로드 데이터를 받아올 수 없습니다.');
      }

      final uploadUrl = uploadData['uploadUrl'];
      final objectKey = uploadData['objectKey'];

      if (uploadUrl == null || objectKey == null) {
        throw Exception('업로드 URL 또는 objectKey가 null입니다.');
      }

      print('Upload URL: $uploadUrl'); // 디버깅용 로그
      print('Object Key: $objectKey'); // 디버깅용 로그

      // 2단계: 받은 URL로 이미지 업로드
      final uploadSuccess = await _uploadToUrl(imageFile, uploadUrl);
      if (!uploadSuccess) {
        throw Exception('이미지 업로드에 실패했습니다.');
      }

      // 3단계: 분석 API 호출
      final analysisResult = await _callAnalysisApi(token, objectKey);

      return {
        'candidates': analysisResult,
        'objectKey': objectKey,
      };
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
          'protein': event.food.protein,
          'carbs': event.food.carbs,
          'fat': event.food.fat,
          'meal_type': event.mealType.name, // 'breakfast', 'lunch', etc.
          'eaten_at': event.timestamp.toIso8601String(),
          'imageUrl': event.imageFile.path, // objectKey를 imageUrl로 전달
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
        print('Upload URL response: $jsonResponse'); // 디버깅용 로그

        final uploadUrl = jsonResponse['uploadUrl']?.toString();
        final objectKey = jsonResponse['objectKey']?.toString();

        if (uploadUrl == null || objectKey == null) {
          throw Exception('uploadUrl 또는 objectKey가 null입니다. 응답: $jsonResponse');
        }

        return {
          'uploadUrl': uploadUrl,
          'objectKey': objectKey,
        };
      } else {
        print('Upload URL error response: ${response.body}'); // 디버깅용 로그
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
      final mimeType =
          lookupMimeType(imageFile.name) ?? 'application/octet-stream';

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
      if (objectKey.isEmpty) {
        throw Exception('objectKey가 비어있습니다.');
      }

      print('Calling analysis API with objectKey: $objectKey'); // 디버깅용 로그

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

      print('Analysis API response status: ${response.statusCode}'); // 디버깅용 로그
      print('Analysis API response body: ${response.body}'); // 디버깅용 로그

      if (response.statusCode == 202) {
        // 202 Accepted: Polling required
        final jsonResponse = json.decode(response.body);
        final String analysisId = jsonResponse['analysisId'];
        print('Analysis accepted, polling for result. analysisId: $analysisId');
        // Polling logic
        const int maxAttempts = 10;
        const Duration interval = Duration(seconds: 1);
        for (int i = 0; i < maxAttempts; i++) {
          await Future.delayed(interval);
          final pollResponse = await http.get(
            Uri.parse('$_analysisEndpoint/$analysisId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
          print('Polling attempt ${i + 1}: status ${pollResponse.statusCode}');
          if (pollResponse.statusCode == 200) {
            final pollJson = json.decode(pollResponse.body);
            if (pollJson['status'] == 'FAILED') {
              throw Exception('분석에 실패했습니다.');
            }
            if (pollJson['status'] == 'COMPLETED') {
              final result = pollJson['result'];
              List<dynamic>? candidatesJson;
              if (result is List) {
                candidatesJson = result;
              } else if (result is Map && result['candidates'] is List) {
                candidatesJson = result['candidates'];
              }
              if (candidatesJson == null) throw Exception('분석 결과가 없습니다.');
              return candidatesJson
                  .map((json) => FoodCandidate.fromJson(json))
                  .toList();
            }
          }
        }
        throw Exception('분석이 10초 내에 완료되지 않았습니다. 잠시 후 다시 시도해 주세요.');
      } else {
        throw Exception(
            'Analysis failed: ${response.statusCode} - ${response.body}');
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
