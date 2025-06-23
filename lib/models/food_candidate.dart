class FoodCandidate {
  final String name;
  final int calories;

  FoodCandidate({required this.name, required this.calories});

  factory FoodCandidate.fromJson(Map<String, dynamic> json) {
    return FoodCandidate(
      name: json['name'] as String,
      calories: json['calories'] as int,
    );
  }

  @override
  String toString() {
    return '$name (${calories} kcal)';
  }
} 