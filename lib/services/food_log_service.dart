import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/meal_event.dart';
import '../models/food_candidate.dart';
import 'auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FoodLogService {
  static final FoodLogService instance = FoodLogService._internal();
  factory FoodLogService() => instance;
  FoodLogService._internal();

  final AuthService _authService = AuthService.instance;

  static String? _baseUrl;
  String get baseUrl => _baseUrl ??= dotenv.env['API_URL']!;

  // 월별 캐시: '2025-06' -> List<MealEvent>
  final Map<String, List<MealEvent>> _monthCache = {};
  Map<String, List<MealEvent>> get monthCache => _monthCache;

  String _monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  Future<List<MealEvent>> getFoodLogs() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('인증 토큰을 가져올 수 없습니다. 다시 로그인해주세요.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/food-logs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': token,
        },
      );

      if (response.statusCode == 200) {
        final dynamic jsonResponse = json.decode(response.body);
        print('Food logs response: $jsonResponse'); // 디버깅용 로그

        // API 응답이 Map인 경우
        if (jsonResponse is Map<String, dynamic>) {
          // items 키가 있는지 확인
          if (jsonResponse.containsKey('items')) {
            final dynamic itemsData = jsonResponse['items'];
            if (itemsData is List) {
              return itemsData
                  .map((item) => _convertToMealEvent(item))
                  .toList();
            }
          }
          // food_logs 키가 있는지 확인 (기존 로직 유지)
          else if (jsonResponse.containsKey('food_logs')) {
            final dynamic foodLogsData = jsonResponse['food_logs'];
            if (foodLogsData is List) {
              return foodLogsData
                  .map((json) => MealEvent.fromJson(json))
                  .toList();
            }
          }
          // 다른 키가 있을 수 있으므로 첫 번째 배열을 찾음
          for (var value in jsonResponse.values) {
            if (value is List) {
              return value.map((json) => MealEvent.fromJson(json)).toList();
            }
          }
          throw Exception('API 응답에서 food logs 배열을 찾을 수 없습니다.');
        }
        // API 응답이 직접 배열인 경우
        else if (jsonResponse is List) {
          return jsonResponse.map((json) => MealEvent.fromJson(json)).toList();
        } else {
          throw Exception('예상치 못한 API 응답 형식입니다: ${jsonResponse.runtimeType}');
        }
      } else {
        print('Food logs error response: ${response.body}'); // 디버깅용 로그
        throw Exception('Failed to load food logs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching food logs: $e');
    }
  }

  // API 응답 구조를 MealEvent로 변환하는 헬퍼 메서드
  MealEvent _convertToMealEvent(Map<String, dynamic> item) {
    // FoodCandidate 생성
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final caloriesValue = item['calories'];
    double calories = parseDouble(caloriesValue);

    final food = FoodCandidate(
      name: item['food_name'] as String,
      calories: calories,
      protein: parseDouble(item['protein']),
      fat: parseDouble(item['fat']),
      carbs: parseDouble(item['carbs']),
    );

    // MealType 변환
    final mealTypeString = item['meal_type'] as String;
    final mealType = MealType.values.firstWhere(
      (e) => e.toString().split('.').last == mealTypeString,
      orElse: () => MealType.snack, // 기본값
    );

    // Timestamp 변환
    final timestamp = DateTime.parse(item['eaten_at'] as String);

    // imageFile은 objectKey가 없으므로 임시로 빈 파일 생성
    final imageFile = XFile('${item['image_url']}');

    return MealEvent(
      food: food,
      mealType: mealType,
      timestamp: timestamp,
      imageFile: imageFile,
    );
  }

  Future<List<MealEvent>> getFoodLogsForMonth(int year, int month) async {
    final key = _monthKey(year, month);
    if (_monthCache.containsKey(key)) {
      return _monthCache[key]!;
    }
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('인증 토큰을 가져올 수 없습니다. 다시 로그인해주세요.');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/food-logs?year=$year&month=$month'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': token,
      },
    );
    if (response.statusCode == 200) {
      final dynamic jsonResponse = json.decode(response.body);
      List<MealEvent> result = [];
      if (jsonResponse is Map<String, dynamic> &&
          jsonResponse.containsKey('items')) {
        final itemsData = jsonResponse['items'];
        if (itemsData is List) {
          result = itemsData.map((item) => _convertToMealEvent(item)).toList();
        }
      }
      _monthCache[key] = result;
      return result;
    } else {
      throw Exception('Failed to load food logs: ${response.statusCode}');
    }
  }

  Future<List<MealEvent>> getFoodLogsForDay(DateTime day,
      {bool force = false}) async {
    final key = _monthKey(day.year, day.month);
    List<MealEvent>? monthLogs = _monthCache[key];
    // 캐시가 없거나, 빈 리스트면 무조건 API 호출
    if (monthLogs == null || monthLogs.isEmpty) {
      monthLogs = await getFoodLogsForMonth(day.year, day.month);
    }
    return monthLogs
        .where((log) =>
            log.timestamp.year == day.year &&
            log.timestamp.month == day.month &&
            log.timestamp.day == day.day)
        .toList();
  }
}
