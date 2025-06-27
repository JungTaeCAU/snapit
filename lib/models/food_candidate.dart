class FoodCandidate {
  final String name;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;

  FoodCandidate({
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory FoodCandidate.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return FoodCandidate(
      name: json['name'] as String,
      calories: parseDouble(json['calories']),
      protein: parseDouble(json['protein']),
      fat: parseDouble(json['fat']),
      carbs: parseDouble(json['carbs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
  }

  @override
  String toString() {
    return '$name ($calories kcal, $protein g P, $fat g F, $carbs g C)';
  }
}
