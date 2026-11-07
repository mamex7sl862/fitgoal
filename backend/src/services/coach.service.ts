import { GoalType } from '@prisma/client';

interface GoalInput {
  currentWeightKg: number;
  heightCm: number;
  age: number;
  gender: 'male' | 'female';
  activityLevel: 'sedentary' | 'light' | 'moderate' | 'very_active';
  primaryGoal: GoalType;
  fitnessLevel: string;
}

export function calculateNutritionPlan(input: GoalInput) {
  const { currentWeightKg, heightCm, age, gender, activityLevel, primaryGoal } = input;

  // 1. Calculate BMR (Mifflin-St Jeor Equation)
  let bmr = (10 * currentWeightKg) + (6.25 * heightCm) - (5 * age);
  bmr += gender === 'male' ? 5 : -161;

  // 2. Apply Activity Multiplier for TDEE
  const multipliers: Record<GoalInput['activityLevel'], number> = {
    sedentary: 1.2,
    light: 1.375,
    moderate: 1.55,
    very_active: 1.725,
  };
  const tdee = Math.round(bmr * multipliers[activityLevel]);

  // 3. Adjust Calories based on Primary Goal
  let dailyCalorieTarget = tdee;
  if (primaryGoal === 'FAT_LOSS') {
    dailyCalorieTarget -= 500; // 500 kcal deficit
  } else if (primaryGoal === 'MUSCLE_GAIN') {
    dailyCalorieTarget += 350; // 350 kcal surplus
  }

  // 4. Calculate Macros (Protein, Carbs, Fats)
  // Protein: ~2.0g per kg of body weight for fitness goals
  const proteinGrams = Math.round(currentWeightKg * 2.0);
  const proteinCalories = proteinGrams * 4;

  // Fats: ~25% of total calories
  const fatCalories = dailyCalorieTarget * 0.25;
  const fatGrams = Math.round(fatCalories / 9);

  // Carbs: Remaining calories
  const carbCalories = dailyCalorieTarget - (proteinCalories + fatCalories);
  const carbGrams = Math.max(50, Math.round(carbCalories / 4));

  return {
    bmr: Math.round(bmr),
    tdee,
    dailyCalorieTarget,
    proteinGrams,
    carbGrams,
    fatGrams,
  };
}