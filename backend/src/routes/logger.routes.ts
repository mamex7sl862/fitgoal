import { Router, Response } from 'express';
import { PrismaClient } from '@prisma/client';
import {
  AuthenticatedRequest,
  authenticateToken,
} from '../middleware/auth.middleware';

const router = Router();
const prisma = new PrismaClient();

function getTodayRange() {
  const start = new Date();
  start.setHours(0, 0, 0, 0);

  const end = new Date(start);
  end.setDate(end.getDate() + 1);

  return { start, end };
}

router.get(
  '/daily-summary',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const userId = req.user?.userId;
      if (!userId) {
        return res.status(401).json({ message: 'Unauthorized request.' });
      }

      const { start, end } = getTodayRange();
      const [meals, habit] = await Promise.all([
        prisma.mealLog.findMany({
          where: { userId, loggedAt: { gte: start, lt: end } },
          orderBy: { loggedAt: 'desc' },
        }),
        prisma.habitLog.findUnique({
          where: { userId_date: { userId, date: start } },
        }),
      ]);

      return res.json({
        meals,
        habit: habit ?? {
          waterGoalMet: false,
          workoutCompleted: false,
          sleepGoalMet: false,
        },
      });
    } catch (error) {
      console.error('Failed to fetch daily summary:', error);
      return res.status(500).json({ message: 'Failed to fetch daily summary.' });
    }
  },
);

router.get(
  '/history',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ message: 'Unauthorized request.' });
    }

    try {
      const meals = await prisma.mealLog.findMany({
        where: { userId },
        orderBy: { loggedAt: 'desc' },
        take: 200,
        select: {
          id: true,
          name: true,
          calories: true,
          protein: true,
          carbs: true,
          fats: true,
          loggedAt: true,
        },
      });
      return res.json(meals);
    } catch (error) {
      console.error('Failed to fetch meal history:', error);
      return res.status(500).json({ message: 'Failed to fetch meal history.' });
    }
  },
);

router.post(
  '/meals',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const userId = req.user?.userId;
      const { name, calories, protein = 0, carbs = 0, fats = 0 } = req.body;

      if (
        !userId ||
        typeof name !== 'string' ||
        name.trim().length === 0 ||
        ![calories, protein, carbs, fats].every(Number.isInteger)
      ) {
        return res.status(400).json({ message: 'Invalid meal details.' });
      }

      const meal = await prisma.mealLog.create({
        data: {
          userId,
          name: name.trim(),
          calories,
          protein,
          carbs,
          fats,
        },
      });

      return res.status(201).json(meal);
    } catch (error) {
      console.error('Failed to log meal:', error);
      return res.status(500).json({ message: 'Failed to log meal.' });
    }
  },
);

router.put(
  '/habits',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const userId = req.user?.userId;
      const { waterGoalMet, workoutCompleted, sleepGoalMet } = req.body;
      const updates = { waterGoalMet, workoutCompleted, sleepGoalMet };
      const providedUpdates = Object.fromEntries(
        Object.entries(updates).filter(([, value]) => value !== undefined),
      );

      if (
        !userId ||
        Object.keys(providedUpdates).length === 0 ||
        Object.values(providedUpdates).some(
          (value) => typeof value !== 'boolean',
        )
      ) {
        return res.status(400).json({ message: 'Invalid habit updates.' });
      }

      const { start } = getTodayRange();
      const habit = await prisma.habitLog.upsert({
        where: { userId_date: { userId, date: start } },
        create: {
          userId,
          date: start,
          waterGoalMet: waterGoalMet ?? false,
          workoutCompleted: workoutCompleted ?? false,
          sleepGoalMet: sleepGoalMet ?? false,
        },
        update: providedUpdates,
      });

      return res.json(habit);
    } catch (error) {
      console.error('Failed to update daily habits:', error);
      return res.status(500).json({ message: 'Failed to update daily habits.' });
    }
  },
);

export default router;
