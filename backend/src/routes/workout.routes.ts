import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import {
  AuthenticatedRequest,
  authenticateToken,
} from '../middleware/auth.middleware';
import { getLatestExerciseProgress } from '../services/progression.service';
import { getTrainingWeekProgress } from '../services/fitness_level.service';

const router = Router();
const prisma = new PrismaClient();
const equipmentOptions = new Set([
  'BARBELL',
  'DUMBBELL',
  'BODYWEIGHT',
  'CABLE',
  'MACHINE',
]);
const fullBodyMuscles = [
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Legs',
  'Quads',
  'Hamstrings',
  'Glutes',
  'Calves',
  'Core',
];

router.post(
  '/plan/day-exercises',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    const { daysPerWeek, dayIndex, exercises: requestedExercises } =
      req.body ?? {};

    if (
      !userId ||
      !Number.isInteger(daysPerWeek) ||
      daysPerWeek < 2 ||
      daysPerWeek > 6 ||
      !Number.isInteger(dayIndex) ||
      dayIndex < 0 ||
      dayIndex > 6 ||
      !Array.isArray(requestedExercises) ||
      requestedExercises.length < 1 ||
      requestedExercises.length > 30 ||
      requestedExercises.some((item: unknown) => {
        if (typeof item !== 'object' || item === null) return true;
        const exercise = item as Record<string, unknown>;
        return (
          typeof exercise.exerciseId !== 'string' ||
          exercise.exerciseId.length === 0 ||
          !Number.isInteger(exercise.targetSets) ||
          Number(exercise.targetSets) < 1 ||
          Number(exercise.targetSets) > 20 ||
          !Number.isInteger(exercise.targetReps) ||
          Number(exercise.targetReps) < 1 ||
          Number(exercise.targetReps) > 100
        );
      })
    ) {
      return res.status(400).json({
        message: 'Choose a scheduled workout day and valid exercises.',
      });
    }

    const scheduledDayIndexes = new Set<number>();
    getTrainingSplit(daysPerWeek).forEach((_, index) => {
      scheduledDayIndexes.add(Math.round((index * 7) / daysPerWeek));
    });
    if (!scheduledDayIndexes.has(dayIndex)) {
      return res.status(400).json({
        message: 'Exercises can only be added to a scheduled workout day.',
      });
    }

    const uniqueExercises = [
      ...new Map(
        requestedExercises.map(
          (item: {
            exerciseId: string;
            targetSets: number;
            targetReps: number;
          }) => [item.exerciseId, item],
        ),
      ).values(),
    ];

    try {
      const exerciseCount = await prisma.exercise.count({
        where: {
          id: { in: uniqueExercises.map((exercise) => exercise.exerciseId) },
        },
      });
      if (exerciseCount !== uniqueExercises.length) {
        return res.status(404).json({
          message: 'One or more selected exercises were not found.',
        });
      }

      const result = await prisma.customPlanExercise.createMany({
        data: uniqueExercises.map((exercise) => ({
          userId,
          daysPerWeek,
          dayIndex,
          exerciseId: exercise.exerciseId,
          targetSets: exercise.targetSets,
          targetReps: exercise.targetReps,
        })),
        skipDuplicates: true,
      });
      return res.status(201).json({ addedCount: result.count });
    } catch (error) {
      console.error('Failed to add exercises to workout plan day:', error);
      return res.status(500).json({
        message: 'Failed to save exercises to your workout plan.',
      });
    }
  },
);

router.delete(
  '/plan/day-exercises/:customPlanExerciseId',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    const { customPlanExerciseId } = req.params;
    if (!userId) return res.status(401).json({ message: 'Unauthorized.' });
    try {
      const deleted = await prisma.customPlanExercise.deleteMany({
        where: { id: customPlanExerciseId, userId },
      });
      if (deleted.count === 0) return res.status(404).json({ message: 'Exercise not found in your plan.' });
      return res.json({ message: 'Exercise removed from plan.' });
    } catch (error) {
      console.error('Failed to remove custom plan exercise:', error);
      return res.status(500).json({ message: 'Failed to remove exercise.' });
    }
  },
);

function getTrainingSplit(daysPerWeek: number) {
  if (daysPerWeek <= 3) {
    return Array.from({ length: daysPerWeek }, (_, index) => ({
      title: `Full Body ${String.fromCharCode(65 + index)}`,
      targetMuscles: fullBodyMuscles,
    }));
  }
  if (daysPerWeek === 4) {
    return [
      { title: 'Upper Body A', targetMuscles: ['Chest', 'Back', 'Shoulders', 'Arms'] },
      { title: 'Lower Body A', targetMuscles: ['Legs', 'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Core'] },
      { title: 'Upper Body B', targetMuscles: ['Chest', 'Back', 'Shoulders', 'Arms'] },
      { title: 'Lower Body B', targetMuscles: ['Legs', 'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Core'] },
    ];
  }

  const push = { title: 'Push', targetMuscles: ['Chest', 'Shoulders', 'Triceps'] };
  const pull = { title: 'Pull', targetMuscles: ['Back', 'Biceps', 'Arms'] };
  const legs = { title: 'Legs', targetMuscles: ['Legs', 'Quads', 'Hamstrings', 'Glutes', 'Calves', 'Core'] };
  return daysPerWeek === 5
    ? [push, pull, legs, { ...push, title: 'Upper Body' }, { ...legs, title: 'Lower Body' }]
    : [push, pull, legs, push, pull, legs];
}

function getTrainingPrescription(
  primaryGoal: string,
  fitnessLevel: string,
): { sets: number; reps: number; guidance: string } {
  const levelSets =
    fitnessLevel === 'BEGINNER'
      ? 2
      : fitnessLevel === 'INTERMEDIATE'
        ? 3
        : 4;

  switch (primaryGoal) {
    case 'FAT_LOSS':
      return {
        sets: levelSets,
        reps: fitnessLevel === 'BEGINNER' ? 10 : 12,
        guidance:
          'Strength training supports your fat-loss goal. Pair workouts with your daily calorie and protein targets.',
      };
    case 'MUSCLE_GAIN':
      return {
        sets: levelSets,
        reps: fitnessLevel === 'BEGINNER' ? 8 : 10,
        guidance:
          'Progressive strength training supports muscle growth. Log your sets and aim to improve gradually while following your nutrition targets.',
      };
    case 'STRENGTH':
      return {
        sets: fitnessLevel === 'BEGINNER' ? 3 : 4,
        reps: 5,
        guidance:
          'Compound-focused training supports strength. Use controlled reps, log each set, and increase loads gradually.',
      };
    default:
      return {
        sets: levelSets,
        reps: 10,
        guidance:
          'Balanced strength training supports weight maintenance and fitness. Follow your daily nutrition targets and log each set.',
      };
  }
}

router.post(
  '/generate',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    const daysPerWeek = req.body?.daysPerWeek ?? 4;
    const requestedEquipment = req.body?.availableEquipment;

    if (
      !userId ||
      !Number.isInteger(daysPerWeek) ||
      daysPerWeek < 2 ||
      daysPerWeek > 6 ||
      (requestedEquipment !== undefined &&
        (!Array.isArray(requestedEquipment) ||
          requestedEquipment.some(
            (item: unknown) =>
              typeof item !== 'string' ||
              !equipmentOptions.has(item.toUpperCase()),
          )))
    ) {
      return res.status(400).json({
        message: 'Choose 2-6 training days and valid available equipment.',
      });
    }

    const availableEquipment = requestedEquipment?.map((item: string) =>
      item.toUpperCase(),
    ) as string[] | undefined;

    try {
      const goal = await prisma.userGoal.findUnique({ where: { userId } });
      if (!goal) {
        return res.status(400).json({
          message: 'Please set up your fitness goal before generating a routine.',
        });
      }

      const fitnessLevel = [
        'BEGINNER',
        'INTERMEDIATE',
        'ADVANCED',
      ].includes(goal.fitnessLevel)
        ? goal.fitnessLevel
        : 'INTERMEDIATE';
      const maxDaysPerWeek =
        fitnessLevel === 'BEGINNER' ? 4 : fitnessLevel === 'INTERMEDIATE' ? 5 : 6;
      if (daysPerWeek > maxDaysPerWeek) {
        return res.status(400).json({
          message: `${fitnessLevel.toLowerCase()} plans support up to ${maxDaysPerWeek} training days per week.`,
        });
      }

      const split = getTrainingSplit(daysPerWeek);
      const trainingDays = new Map<number, (typeof split)[number]>();
      split.forEach((schedule, index) => {
        trainingDays.set(Math.round((index * 7) / daysPerWeek), schedule);
      });
      const completedPlanDays = await getTrainingWeekProgress(
        prisma,
        userId,
        goal.fitnessLevelUpdatedAt,
        [...trainingDays.keys()],
      );
      const trainingWeek = completedPlanDays.trainingWeek;
      const completedSessionsInWeek =
        completedPlanDays.completedPlanDaysInWeek.length;

      const exerciseLimit =
        fitnessLevel === 'BEGINNER' ? 5 : fitnessLevel === 'INTERMEDIATE' ? 6 : 7;
      const prescription = getTrainingPrescription(
        goal.primaryGoal,
        fitnessLevel,
      );
      const customExercises = await prisma.customPlanExercise.findMany({
        where: { userId, daysPerWeek },
        include: { exercise: true },
        orderBy: { createdAt: 'asc' },
      });
      const customExercisesByDay = new Map(
        [...trainingDays.keys()].map((dayIndex) => [
          dayIndex,
          customExercises.filter((item) => item.dayIndex === dayIndex),
        ]),
      );
      const weeklyRoutine = await Promise.all(
        Array.from({ length: 7 }, async (_, dayIndex) => {
          const schedule = trainingDays.get(dayIndex);
          if (!schedule) {
            return {
              dayTitle: `Day ${dayIndex + 1}: Recovery`,
              isRestDay: true,
              exercises: [],
            };
          }

          const candidates = await prisma.exercise.findMany({
            where: {
              targetMuscle: { in: schedule.targetMuscles, mode: 'insensitive' },
            },
            orderBy: { name: 'asc' },
          });
          const eligible = availableEquipment
            ? candidates.filter((exercise) =>
                exercise.equipmentRequired.every((item) =>
                  availableEquipment.includes(item),
                ),
              )
            : candidates;
          const ranked = [...eligible].sort((a, b) => {
            if (goal.primaryGoal === 'FAT_LOSS') {
              return Number(b.caloriesPerMin) - Number(a.caloriesPerMin);
            }
            if (
              goal.primaryGoal === 'MUSCLE_GAIN' ||
              goal.primaryGoal === 'STRENGTH'
            ) {
              const compoundRank = (category: string) =>
                category.toUpperCase() === 'COMPOUND' ? 0 : 1;
              return compoundRank(a.category) - compoundRank(b.category);
            }
            return 0;
          });
          const rotation =
            ranked.length === 0
              ? 0
              : ((trainingWeek - 1) * exerciseLimit) % ranked.length;
          const rotated = [...ranked.slice(rotation), ...ranked.slice(0, rotation)];
          const selected = rotated.slice(0, exerciseLimit);
          const customForDay = customExercisesByDay.get(dayIndex) ?? [];
          const customExerciseIds = new Set(
            customForDay.map((item) => item.exerciseId),
          );
          const exercises = await Promise.all([
            ...selected
              .filter((exercise) => !customExerciseIds.has(exercise.id))
              .map(async (exercise) => ({
                id: exercise.id,
                name: exercise.name,
                targetMuscle: exercise.targetMuscle,
                equipmentRequired: exercise.equipmentRequired,
                gifUrl: exercise.gifUrl,
                sets: prescription.sets,
                reps: prescription.reps,
                instructions: exercise.instructions,
                ...(await getLatestExerciseProgress(
                  prisma,
                  userId,
                  exercise.id,
                )),
              })),
            ...customForDay.map(async (item) => ({
              id: item.exercise.id,
              name: item.exercise.name,
              targetMuscle: item.exercise.targetMuscle,
              equipmentRequired: item.exercise.equipmentRequired,
              gifUrl: item.exercise.gifUrl,
              sets: item.targetSets,
              reps: item.targetReps,
              instructions: item.exercise.instructions,
              isCustomPlanExercise: true,
              customPlanExerciseId: item.id,
              ...(await getLatestExerciseProgress(
                prisma,
                userId,
                item.exerciseId,
              )),
            })),
          ]);

          return {
            dayTitle: `Day ${dayIndex + 1}: ${schedule.title}`,
            isRestDay: false,
            exercises,
          };
        }),
      );

      return res.json({
        primaryGoal: goal.primaryGoal,
        fitnessLevel,
        planGuidance: prescription.guidance,
        daysPerWeek,
        trainingWeek,
        completedSessionsInWeek,
        completedPlanDaysInWeek: completedPlanDays.completedPlanDaysInWeek,
        requiredSessionsPerWeek: daysPerWeek,
        availableEquipment: availableEquipment ?? null,
        weeklyRoutine,
      });
    } catch (error) {
      console.error('Failed to generate workout routine:', error);
      return res.status(500).json({ message: 'Failed to generate workout routine.' });
    }
  },
);

router.get(
  '/progress/history',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized request.' });
    }

    try {
      const logs = await prisma.workoutLog.findMany({
        where: { userId },
        orderBy: { completedAt: 'desc' },
        take: 100,
        select: {
          id: true,
          completedAt: true,
          durationMins: true,
          caloriesBurned: true,
          totalVolumeKg: true,
          session: {
            select: {
              startedAt: true,
              exercises: {
                select: {
                  exercise: { select: { name: true } },
                },
              },
            },
          },
        },
      });
      return res.json(logs);
    } catch (error) {
      console.error('Failed to load workout calorie history:', error);
      return res.status(500).json({
        message: 'Failed to load workout calorie history.',
      });
    }
  },
);

router.get(
  '/progress',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized request.' });
    }

    try {
      const today = new Date();
      const todayStart = new Date(today);
      todayStart.setHours(0, 0, 0, 0);
      const weekStart = new Date(todayStart);
      weekStart.setDate(weekStart.getDate() - 6);

      const [allTime, thisWeek, todayTotal, dailyLogs] = await Promise.all([
        prisma.workoutLog.aggregate({
          where: { userId },
          _sum: { caloriesBurned: true },
          _count: { _all: true },
        }),
        prisma.workoutLog.aggregate({
          where: { userId, completedAt: { gte: weekStart } },
          _sum: { caloriesBurned: true },
        }),
        prisma.workoutLog.aggregate({
          where: { userId, completedAt: { gte: todayStart } },
          _sum: { caloriesBurned: true },
        }),
        prisma.workoutLog.findMany({
          where: { userId, completedAt: { gte: weekStart } },
          select: { completedAt: true, caloriesBurned: true },
        }),
      ]);

      const dailyCalories = Array.from({ length: 7 }, (_, index) => {
        const date = new Date(weekStart);
        date.setDate(weekStart.getDate() + index);
        const dateKey = date.toDateString();
        return {
          date: date.toISOString(),
          calories: dailyLogs
            .filter((log) => log.completedAt.toDateString() === dateKey)
            .reduce((sum, log) => sum + log.caloriesBurned, 0),
        };
      });

      return res.json({
        todayCalories: todayTotal._sum.caloriesBurned ?? 0,
        weekCalories: thisWeek._sum.caloriesBurned ?? 0,
        allTimeCalories: allTime._sum.caloriesBurned ?? 0,
        completedWorkouts: allTime._count._all,
        dailyCalories,
      });
    } catch (error) {
      console.error('Failed to load workout calorie progress:', error);
      return res.status(500).json({
        message: 'Failed to load workout calorie progress.',
      });
    }
  },
);

export default router;
