import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
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

  Future<String?> uploadImage(File imageFile) async {
    try {
      // Bearer 토큰 가져오기
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('인증 토큰을 가져올 수 없습니다. 다시 로그인해주세요.');
      }

      // 1단계: GET으로 업로드 URL 받기
      final uploadUrl = await _getUploadUrl(token);
      if (uploadUrl == null) {
        throw Exception('업로드 URL을 받아올 수 없습니다.');
      }

      // 2단계: 받은 URL로 이미지 업로드
      final uploadSuccess = await _uploadToUrl(imageFile, uploadUrl);
      if (!uploadSuccess) {
        throw Exception('이미지 업로드에 실패했습니다.');
      }

      // 3단계: 분석 API 호출
      final analysisResult = await _callAnalysisApi(token);
      return analysisResult;
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  // GET으로 업로드 URL 받기 (Bearer 토큰 포함)
  Future<String?> _getUploadUrl(String token) async {
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
        return jsonResponse['uploadUrl']; // 서버 응답에서 업로드 URL 추출
      } else {
        throw Exception('Failed to get upload URL: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting upload URL: $e');
    }
  }

  // 받은 URL로 이미지 업로드
  Future<bool> _uploadToUrl(File imageFile, String uploadUrl) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // 파일 추가
      var stream = http.ByteStream(imageFile.openRead());
      var length = await imageFile.length();

      var multipartFile = http.MultipartFile(
        'image', // 서버에서 기대하는 필드명
        stream,
        length,
        filename: path.basename(imageFile.path),
      );

      request.files.add(multipartFile);

      // 요청 전송
      var response = await request.send();

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      throw Exception('Error uploading to URL: $e');
    }
  }

  // 분석 API 호출 (Bearer 토큰 포함)
  Future<String?> _callAnalysisApi(String token) async {
    try {
      final response = await http.post(
        Uri.parse(_analysisEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          // 필요한 경우 분석에 필요한 데이터를 여기에 추가
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['result']; // 분석 결과 반환
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
