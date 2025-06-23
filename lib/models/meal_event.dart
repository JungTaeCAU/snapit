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
      default:
        return '';
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
} 