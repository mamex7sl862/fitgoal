import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { calculateNutritionPlan } from '../services/coach.service';
import { AuthenticatedRequest } from '../middleware/auth.middleware';

const prisma = new PrismaClient();

// Set or Update User Goal & Calculate Macros
export async function saveUserGoal(req: AuthenticatedRequest, res: Response): Promise<void> {
  try {
    const userId = req.user?.userId;
    const {
      primaryGoal,
      fitnessLevel,
      currentWeightKg,
      targetWeightKg,
      heightCm,
      age,
      gender,
      activityLevel,
    } = req.body;

    if (!userId) {
      res.status(401).json({ code: 'UNAUTHORIZED', message: 'Unauthorized request.' });
      return;
    }

    if (
      !primaryGoal ||
      (fitnessLevel !== undefined &&
        !['BEGINNER', 'INTERMEDIATE', 'ADVANCED'].includes(
          String(fitnessLevel).toUpperCase(),
        )) ||
      currentWeightKg == null ||
      heightCm == null ||
      age == null ||
      !gender ||
      !['sedentary', 'light', 'moderate', 'very_active'].includes(activityLevel)
    ) {
      res.status(400).json({ code: 'BAD_REQUEST', message: 'Missing required physical stats or goal parameters.' });
      return;
    }

    const normalizedFitnessLevel = String(
      fitnessLevel || 'INTERMEDIATE',
    ).toUpperCase();
    const existingGoal = await prisma.userGoal.findUnique({
      where: { userId },
      select: { fitnessLevel: true },
    });

    // Calculate smart nutrition targets
    const { bmr, tdee, ...nutrition } = calculateNutritionPlan({
      currentWeightKg: Number(currentWeightKg),
      heightCm: Number(heightCm),
      age: Number(age),
      gender,
      activityLevel: activityLevel || 'moderate',
      primaryGoal,
      fitnessLevel: normalizedFitnessLevel,
    });

    // Upsert user goal in database
    const userGoal = await prisma.userGoal.upsert({
      where: { userId },
      update: {
        primaryGoal,
        fitnessLevel: normalizedFitnessLevel,
        ...(existingGoal?.fitnessLevel !== normalizedFitnessLevel
          ? { fitnessLevelUpdatedAt: new Date() }
          : {}),
        currentWeightKg,
        targetWeightKg,
        heightCm,
        age: Number(age),
        gender: String(gender).toLowerCase(),
        activityLevel,
        bmr,
        tdee,
        ...nutrition,
      },
      create: {
        userId,
        primaryGoal,
        fitnessLevel: normalizedFitnessLevel,
        currentWeightKg,
        targetWeightKg,
        heightCm,
        age: Number(age),
        gender: String(gender).toLowerCase(),
        activityLevel,
        bmr,
        tdee,
        ...nutrition,
      },
    });

    res.status(200).json({
      message: 'Smart Coach goal and nutrition plan calculated successfully!',
      goal: userGoal,
      age: Number(age),
      gender,
      activityLevel,
      bmr,
      tdee,
    });
  } catch (error) {
    console.error('Goal calculation error:', error);
    res.status(500).json({ code: 'SERVER_ERROR', message: 'Internal server error calculating goal.' });
  }
}

export async function getUserGoal(
  req: AuthenticatedRequest,
  res: Response,
): Promise<void> {
  const userId = req.user?.userId;
  if (!userId) {
    res.status(401).json({ code: 'UNAUTHORIZED', message: 'Unauthorized request.' });
    return;
  }

  try {
    const goal = await prisma.userGoal.findUnique({ where: { userId } });
    if (!goal) {
      res.status(404).json({
        code: 'GOAL_NOT_FOUND',
        message: 'No saved fitness plan found. Please calculate your plan first.',
      });
      return;
    }

    res.json({
      goal,
      age: goal.age,
      gender: goal.gender,
      activityLevel: goal.activityLevel,
      bmr: goal.bmr,
      tdee: goal.tdee,
    });
  } catch (error) {
    console.error('Failed to load saved fitness goal:', error);
    res.status(500).json({
      code: 'SERVER_ERROR',
      message: 'Failed to load your saved fitness plan.',
    });
  }
}