import { MealType, Prisma, PrismaClient } from '@prisma/client';
import { Router, Response } from 'express';
import {
  AuthenticatedRequest,
  authenticateToken,
} from '../middleware/auth.middleware';

const router = Router();
const prisma = new PrismaClient();

const mealTemplates = [
  {
    mealType: MealType.BREAKFAST,
    title: 'Greek yogurt, oats and berries',
    recipe:
      'Combine plain Greek yogurt, rolled oats and berries. Add a small portion of nuts or seeds if desired.',
    share: 25,
  },
  {
    mealType: MealType.LUNCH,
    title: 'Chicken, grain and vegetable bowl',
    recipe:
      'Serve grilled chicken with brown rice or quinoa and a generous portion of mixed vegetables.',
    share: 30,
  },
  {
    mealType: MealType.DINNER,
    title: 'Salmon, potatoes and greens',
    recipe:
      'Bake or pan-cook salmon and serve with potatoes and green vegetables. Season with herbs and lemon.',
    share: 30,
  },
  {
    mealType: MealType.SNACK,
    title: 'Cottage cheese and fruit',
    recipe:
      'Serve cottage cheese with a piece of fruit. Adjust the portion to fit your remaining daily targets.',
    share: 15,
  },
];

function parsePlanDate(value: unknown): Date | null {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return null;
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  return date.toISOString().slice(0, 10) === value ? date : null;
}

function splitTarget(total: number): number[] {
  const portions = mealTemplates.map((meal) =>
    Math.round((total * meal.share) / 100),
  );
  portions[portions.length - 1] += total - portions.reduce((sum, item) => sum + item, 0);
  return portions;
}

router.get(
  '/today',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    const requestedDate =
      req.query.date ?? new Date().toISOString().slice(0, 10);
    const planDate = parsePlanDate(requestedDate);
    if (!userId) return res.status(401).json({ message: 'Unauthorized request.' });
    if (!planDate) {
      return res.status(400).json({ message: 'Provide a valid plan date.' });
    }

    try {
      const goal = await prisma.userGoal.findUnique({ where: { userId } });
      if (!goal) {
        return res.status(400).json({
          message: 'Please set up your fitness goal before generating a meal plan.',
        });
      }

      let plan = await prisma.mealPlan.findUnique({
        where: { userId_planDate: { userId, planDate } },
        include: { meals: { include: { mealLog: true }, orderBy: { mealType: 'asc' } } },
      });

      if (!plan) {
        const calories = splitTarget(goal.dailyCalorieTarget);
        const protein = splitTarget(goal.proteinGrams);
        const carbs = splitTarget(goal.carbGrams);
        const fats = splitTarget(goal.fatGrams);
        try {
          plan = await prisma.mealPlan.create({
            data: {
              userId,
              planDate,
              name: 'Personalized daily meal plan',
              targetKcal: goal.dailyCalorieTarget,
              meals: {
                create: mealTemplates.map((template, index) => ({
                  mealType: template.mealType,
                  title: template.title,
                  recipe: template.recipe,
                  calories: calories[index],
                  protein: protein[index],
                  carbs: carbs[index],
                  fats: fats[index],
                })),
              },
            },
            include: {
              meals: {
                include: { mealLog: true },
                orderBy: { mealType: 'asc' },
              },
            },
          });
        } catch (error) {
          if (
            !(error instanceof Prisma.PrismaClientKnownRequestError) ||
            error.code !== 'P2002'
          ) {
            throw error;
          }
          plan = await prisma.mealPlan.findUniqueOrThrow({
            where: { userId_planDate: { userId, planDate } },
            include: {
              meals: {
                include: { mealLog: true },
                orderBy: { mealType: 'asc' },
              },
            },
          });
        }
      }

      return res.json(plan);
    } catch (error) {
      console.error('Failed to generate daily meal plan:', error);
      return res.status(500).json({ message: 'Failed to generate meal plan.' });
    }
  },
);

router.patch(
  '/:mealId',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const userId = req.user?.userId;
    const mealId = String(req.params.mealId);
    const { eaten } = req.body ?? {};
    if (!userId) return res.status(401).json({ message: 'Unauthorized request.' });
    if (typeof eaten !== 'boolean') {
      return res.status(400).json({ message: 'Provide an eaten boolean value.' });
    }
    const intakeFields = ['calories', 'protein', 'carbs', 'fats'] as const;
    for (const field of intakeFields) {
      const value = req.body?.[field];
      if (
        value !== undefined &&
        (!Number.isInteger(value) || value < 0 || value > 10000)
      ) {
        return res.status(400).json({
          message: `Provide a whole-number value from 0 to 10000 for ${field}.`,
        });
      }
    }

    try {
      const meal = await prisma.meal.findFirst({
        where: { id: mealId, mealPlan: { userId } },
      });
      if (!meal) {
        return res.status(404).json({ message: 'Planned meal not found.' });
      }

      if (eaten) {
        await prisma.mealLog.upsert({
          where: { planMealId: meal.id },
          create: {
            userId,
            planMealId: meal.id,
            name: meal.title,
            calories: req.body.calories ?? meal.calories,
            protein: req.body.protein ?? Math.round(Number(meal.protein)),
            carbs: req.body.carbs ?? Math.round(Number(meal.carbs)),
            fats: req.body.fats ?? Math.round(Number(meal.fats)),
          },
          update: {
            calories: req.body.calories ?? meal.calories,
            protein: req.body.protein ?? Math.round(Number(meal.protein)),
            carbs: req.body.carbs ?? Math.round(Number(meal.carbs)),
            fats: req.body.fats ?? Math.round(Number(meal.fats)),
          },
        });
      } else {
        await prisma.mealLog.deleteMany({
          where: { userId, planMealId: meal.id },
        });
      }

      const updatedMeal = await prisma.meal.findUniqueOrThrow({
        where: { id: meal.id },
        include: { mealLog: true },
      });
      return res.json(updatedMeal);
    } catch (error) {
      console.error('Failed to update planned meal:', error);
      return res.status(500).json({ message: 'Failed to update planned meal.' });
    }
  },
);

export default router;
