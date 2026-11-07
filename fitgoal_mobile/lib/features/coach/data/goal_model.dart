class GoalResponse {
  final String id;
  final String userId;
  final int age;
  final String gender;
  final double heightCm;
  final String fitnessLevel;
  final double weightKg;
  final String activityLevel;
  final String goal;
  final double bmr;
  final double tdee;
  final double targetCalories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatsGrams;

  GoalResponse({
    required this.id,
    required this.userId,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.fitnessLevel,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
  });

  factory GoalResponse.fromJson(Map<String, dynamic> json) {
    final goalRecord = json['goal'] is Map
        ? Map<String, dynamic>.from(json['goal'] as Map)
        : json;

    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int asInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return GoalResponse(
      id: goalRecord['id']?.toString() ?? '',
      userId: goalRecord['userId']?.toString() ?? '',
      age: asInt(json['age'] ?? goalRecord['age']),
      gender: (json['gender'] ?? goalRecord['gender'])?.toString() ?? '',
      heightCm: asDouble(goalRecord['heightCm']),
      fitnessLevel: goalRecord['fitnessLevel']?.toString() ?? 'INTERMEDIATE',
      weightKg: asDouble(
        goalRecord['currentWeightKg'] ?? goalRecord['weightKg'],
      ),
      activityLevel:
          (json['activityLevel'] ?? goalRecord['activityLevel'])?.toString() ??
          '',
      goal: (goalRecord['primaryGoal'] ?? json['goal'])?.toString() ?? '',
      bmr: asDouble(json['bmr']),
      tdee: asDouble(json['tdee']),
      targetCalories: asDouble(
        json['targetCalories'] ?? goalRecord['dailyCalorieTarget'],
      ),
      proteinGrams: asDouble(goalRecord['proteinGrams']),
      carbsGrams: asDouble(goalRecord['carbGrams'] ?? goalRecord['carbsGrams']),
      fatsGrams: asDouble(goalRecord['fatGrams'] ?? goalRecord['fatsGrams']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'age': age,
      'gender': gender,
      'heightCm': heightCm,
      'fitnessLevel': fitnessLevel,
      'currentWeightKg': weightKg,
      'activityLevel': activityLevel,
      'primaryGoal': goal,
      'bmr': bmr,
      'tdee': tdee,
      'targetCalories': targetCalories,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatsGrams': fatsGrams,
    };
  }
}
