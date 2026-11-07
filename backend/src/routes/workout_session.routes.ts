import { Router, Response } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import {
  AuthenticatedRequest,
  authenticateToken,
} from '../middleware/auth.middleware';
import { evaluateFitnessLevelPromotion } from '../services/fitness_level.service';
import { getLatestExerciseProgress } from '../services/progression.service';

const router = Router();
const prisma = new PrismaClient();

async function addProgressionData<T extends {
  exercises: Array<{ exerciseId: string; exercise: object }>;
}>(session: T, userId: string) {
  return {
    ...session,
    exercises: await Promise.all(
      session.exercises.map(async (item) => ({
        ...item,
        exercise: {
          ...item.exercise,
          ...(await getLatestExerciseProgress(prisma, userId, item.exerciseId)),
        },
      })),
    ),
  };
}

router.post(
  '/sessions',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    const requestedExercises = req.body?.exercises;
    const trainingWeek = req.body?.trainingWeek;
    const planDayIndex = req.body?.planDayIndex;

    if (
      !userId ||
      ((trainingWeek === undefined) !== (planDayIndex === undefined)) ||
      (trainingWeek !== undefined &&
        (!Number.isInteger(trainingWeek) || trainingWeek < 1)) ||
      (planDayIndex !== undefined &&
        (!Number.isInteger(planDayIndex) ||
          planDayIndex < 0 ||
          planDayIndex > 6)) ||
      !Array.isArray(requestedExercises) ||
      requestedExercises.length < 1 ||
      requestedExercises.length > 30 ||
      requestedExercises.some(
        (item: unknown) => {
          if (typeof item !== 'object' || item === null) return true;
          const value = item as Record<string, unknown>;
          return (
            typeof value.exerciseId !== 'string' ||
            (value.targetSets !== undefined &&
              (!Number.isInteger(value.targetSets) ||
                Number(value.targetSets) < 1 ||
                Number(value.targetSets) > 20)) ||
            (value.targetReps !== undefined &&
              (!Number.isInteger(value.targetReps) ||
                Number(value.targetReps) < 1 ||
                Number(value.targetReps) > 100))
          );
        },
      )
    ) {
      return res.status(400).json({ message: 'Select at least one valid exercise.' });
    }

    const exercises = requestedExercises.map(
      (item: Record<string, unknown>) => ({
        exerciseId: item.exerciseId as string,
        targetSets:
          Number.isInteger(item.targetSets) && Number(item.targetSets) > 0
            ? Number(item.targetSets)
            : 3,
        targetReps:
          Number.isInteger(item.targetReps) && Number(item.targetReps) > 0
            ? Number(item.targetReps)
            : 10,
      }),
    );

    try {
      const uniqueIds = [...new Set(exercises.map((item) => item.exerciseId))];
      const existingCount = await prisma.exercise.count({
        where: { id: { in: uniqueIds } },
      });
      if (existingCount !== uniqueIds.length) {
        return res.status(404).json({ message: 'One or more exercises were not found.' });
      }

      const session = await prisma.workoutSession.create({
        data: {
          userId,
          trainingWeek,
          planDayIndex,
          exercises: {
            create: exercises.map((exercise) => ({
              targetSets: exercise.targetSets,
              targetReps: exercise.targetReps,
              exercise: { connect: { id: exercise.exerciseId } },
            })),
          },
        },
        include: {
          exercises: {
            include: { exercise: true, sets: true },
          },
        },
      });
      return res.status(201).json(await addProgressionData(session, userId));
    } catch (error) {
      console.error('Failed to start workout session:', error);
      return res.status(500).json({ message: 'Failed to start workout session.' });
    }
  },
);

router.get(
  '/sessions/active',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    if (!userId) return res.status(401).json({ message: 'Unauthorized request.' });

    try {
      const session = await prisma.workoutSession.findFirst({
        where: { userId, status: 'ACTIVE' },
        orderBy: { startedAt: 'desc' },
        include: {
          exercises: {
            include: { exercise: true, sets: { orderBy: { setNumber: 'asc' } } },
          },
        },
      });
      return res.json({
        session: session ? await addProgressionData(session, userId) : null,
      });
    } catch (error) {
      console.error('Failed to load active workout session:', error);
      return res.status(500).json({ message: 'Failed to load active session.' });
    }
  },
);

router.get(
  '/sessions/history',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    if (!userId) return res.status(401).json({ message: 'Unauthorized request.' });

    try {
      const sessions = await prisma.workoutSession.findMany({
        where: { userId, status: 'COMPLETED' },
        orderBy: { endedAt: 'desc' },
        take: 10,
        include: {
          exercises: {
            include: {
              exercise: true,
              sets: {
                where: { completed: true },
                orderBy: { setNumber: 'asc' },
              },
            },
          },
        },
      });
      return res.json(sessions);
    } catch (error) {
      console.error('Failed to load workout history:', error);
      return res.status(500).json({ message: 'Failed to load workout history.' });
    }
  },
);

router.post(
  '/sessions/:sessionId/exercises/:workoutExerciseId/sets',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    const sessionId = String(req.params.sessionId);
    const workoutExerciseId = String(req.params.workoutExerciseId);
    const { setNumber, weightKg, reps, rpe, completed = true } = req.body ?? {};
    const parsedWeight = Number(weightKg);
    const parsedRpe = rpe == null ? null : Number(rpe);

    if (
      !userId ||
      !Number.isInteger(setNumber) ||
      setNumber < 1 ||
      !Number.isFinite(parsedWeight) ||
      parsedWeight < 0 ||
      !Number.isInteger(reps) ||
      reps < 1 ||
      reps > 100 ||
      parsedWeight > 2000 ||
      (parsedRpe !== null &&
        (!Number.isFinite(parsedRpe) || parsedRpe < 1 || parsedRpe > 10)) ||
      typeof completed !== 'boolean'
    ) {
      return res.status(400).json({ message: 'Invalid set details.' });
    }

    try {
      const exercise = await prisma.workoutExercise.findFirst({
        where: {
          id: workoutExerciseId,
          sessionId,
          session: { userId, status: 'ACTIVE' },
        },
      });
      if (!exercise) {
        return res.status(404).json({ message: 'Active workout exercise not found.' });
      }
      if (setNumber > exercise.targetSets) {
        return res.status(400).json({ message: 'Set number exceeds the planned sets.' });
      }

      const setDetails = {
        weightKg: new Prisma.Decimal(parsedWeight),
        reps,
        rpe: parsedRpe == null ? null : new Prisma.Decimal(parsedRpe),
        completed,
      };
      const upsertSet = () =>
        prisma.exerciseSet.upsert({
          where: {
            workoutExerciseId_setNumber: { workoutExerciseId, setNumber },
          },
          create: { workoutExerciseId, setNumber, ...setDetails },
          update: setDetails,
        });

      let set;
      try {
        set = await upsertSet();
      } catch (error) {
        if (
          !(error instanceof Prisma.PrismaClientKnownRequestError) ||
          error.code !== 'P2002'
        ) {
          throw error;
        }
        set = await upsertSet();
      }
      return res.json(set);
    } catch (error) {
      console.error('Failed to log workout set:', error);
      return res.status(500).json({ message: 'Failed to log workout set.' });
    }
  },
);

router.patch(
  '/sessions/:sessionId/complete',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    const sessionId = String(req.params.sessionId);
    if (!userId) return res.status(401).json({ message: 'Unauthorized request.' });

    try {
      const session = await prisma.workoutSession.findFirst({
        where: { id: sessionId, userId, status: 'ACTIVE' },
      });
      if (!session) {
        return res.status(404).json({ message: 'Active workout session not found.' });
      }

      const endedAt = new Date();
      const sessionExercises = await prisma.workoutExercise.findMany({
        where: {
          sessionId,
        },
        select: {
          exercise: { select: { caloriesPerMin: true } },
          sets: {
            where: { completed: true },
            select: { weightKg: true, reps: true },
          },
        },
      });
      const completedSets = sessionExercises.flatMap(
        (exercise) => exercise.sets,
      );
      const totalVolumeKg = completedSets.reduce(
        (total, set) => total + Number(set.weightKg) * set.reps,
        0,
      );
      const durationMins = Math.max(
        1,
        Math.ceil((endedAt.getTime() - session.startedAt.getTime()) / 60000),
      );
      const activeExercises = sessionExercises.filter(
        (exercise) => exercise.sets.length > 0,
      );
      const calorieExercises =
        activeExercises.length > 0 ? activeExercises : sessionExercises;
      const averageCaloriesPerMinute =
        calorieExercises.length === 0
          ? 5
          : calorieExercises.reduce((total, exercise) => {
              const rate = Number(exercise.exercise.caloriesPerMin);
              return total + (rate > 0 ? rate : 5);
            }, 0) / calorieExercises.length;
      const estimatedCalories = Math.round(
        averageCaloriesPerMinute * durationMins,
      );

      const completedSession = await prisma.$transaction(async (transaction) => {
        const updated = await transaction.workoutSession.update({
          where: { id: sessionId },
          data: { status: 'COMPLETED', endedAt },
          include: {
            exercises: {
              include: { exercise: true, sets: { orderBy: { setNumber: 'asc' } } },
            },
          },
        });
        await transaction.workoutLog.create({
          data: {
            userId,
            sessionId,
            durationMins,
            caloriesBurned: estimatedCalories,
            totalVolumeKg: new Prisma.Decimal(totalVolumeKg),
          },
        });
        const habitDate = new Date(endedAt);
        habitDate.setHours(0, 0, 0, 0);
        await transaction.habitLog.upsert({
          where: { userId_date: { userId, date: habitDate } },
          create: {
            userId,
            date: habitDate,
            workoutCompleted: true,
          },
          update: { workoutCompleted: true },
        });
        return updated;
      });
      let levelPromotion = null;
      let levelCheckMessage = null;
      try {
        levelPromotion = await evaluateFitnessLevelPromotion(prisma, userId);
      } catch (error) {
        console.error('Failed to evaluate fitness level progression:', error);
        levelCheckMessage =
          'Workout saved, but your coach could not check your level progression. It will try again after your next workout.';
      }

      return res.json({
        ...completedSession,
        caloriesBurned: estimatedCalories,
        levelPromotion,
        levelCheckMessage,
      });
    } catch (error) {
      console.error('Failed to complete workout session:', error);
      return res.status(500).json({ message: 'Failed to complete workout session.' });
    }
  },
);

router.get(
  '/exercises/:exerciseId/history',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    if (!userId) return res.status(401).json({ message: 'Unauthorized request.' });

    try {
      const progress = await getLatestExerciseProgress(
        prisma,
        userId,
        String(req.params.exerciseId),
      );
      return res.json(progress);
    } catch (error) {
      console.error('Failed to load exercise history:', error);
      return res.status(500).json({ message: 'Failed to load exercise history.' });
    }
  },
);

export default router;
