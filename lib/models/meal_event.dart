import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'food_candidate.dart';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeExtension on MealType {
  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return '아침';
      case MealType.lunch:
        return '점심';
      case MealType.dinner:
        return '저녁';
      case MealType.snack:
        return '간식';
      }
  }
}

class MealEvent {
  final FoodCandidate food;
  final MealType mealType;
  final DateTime timestamp;
  final XFile imageFile;

  MealEvent({
    required this.food,
    required this.mealType,
    required this.timestamp,
    required this.imageFile,
  });

  factory MealEvent.fromJson(Map<String, dynamic> json) {
    return MealEvent(
      food: FoodCandidate.fromJson(json['food']),
      mealType: MealType.values.firstWhere(
        (e) => e.toString().split('.').last == json['mealType'],
      ),
      timestamp: DateTime.parse(json['timestamp']),
      imageFile: XFile(json['imageUrl']), // API에서는 imageUrl로 받음
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food': food.toJson(),
      'mealType': mealType.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'imageUrl': imageFile.path, // objectKey 값을 imageUrl로 전송
    };
  }
}
