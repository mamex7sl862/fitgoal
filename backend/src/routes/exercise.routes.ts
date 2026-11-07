import { Router, Response } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import {
  AuthenticatedRequest,
  authenticateToken,
} from '../middleware/auth.middleware';

const router = Router();
const prisma = new PrismaClient();
const allowedCategories = new Set(['COMPOUND', 'ISOLATION']);
const allowedEquipment = new Set([
  'BARBELL',
  'DUMBBELL',
  'BODYWEIGHT',
  'CABLE',
  'MACHINE',
]);

function queryValues(value: unknown): string[] {
  const values = Array.isArray(value) ? value : [value];
  return values
    .flatMap((entry) => (typeof entry === 'string' ? entry.split(',') : []))
    .map((entry) => entry.trim())
    .filter(Boolean);
}

router.get(
  '/',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const muscles = queryValues(req.query.muscle ?? req.query.muscles);
    const equipment = queryValues(req.query.equipment).map((value) =>
      value.toUpperCase(),
    );
    const category = queryValues(req.query.category)[0]?.toUpperCase();
    const search = queryValues(req.query.search ?? req.query.q)[0];
    const page = Number(req.query.page ?? 1);
    const pageSize = Number(req.query.pageSize ?? 30);

    if (
      !Number.isInteger(page) ||
      page < 1 ||
      !Number.isInteger(pageSize) ||
      pageSize < 1 ||
      pageSize > 100 ||
      equipment.some((item) => !allowedEquipment.has(item)) ||
      (category !== undefined && !allowedCategories.has(category))
    ) {
      return res.status(400).json({ message: 'Invalid exercise filters.' });
    }

    const where: Prisma.ExerciseWhereInput = {
      ...(muscles.length > 0
        ? { targetMuscle: { in: muscles, mode: 'insensitive' } }
        : {}),
      ...(equipment.length > 0
        ? { equipmentRequired: { hasSome: equipment } }
        : {}),
      ...(category ? { category } : {}),
      ...(search
        ? { name: { contains: search, mode: 'insensitive' } }
        : {}),
    };

    try {
      const [items, total] = await Promise.all([
        prisma.exercise.findMany({
          where,
          orderBy: { name: 'asc' },
          skip: (page - 1) * pageSize,
          take: pageSize,
        }),
        prisma.exercise.count({ where }),
      ]);

      return res.json({
        items,
        page,
        pageSize,
        total,
        hasMore: page * pageSize < total,
      });
    } catch (error) {
      console.error('Failed to query exercise library:', error);
      return res.status(500).json({ message: 'Failed to load exercise library.' });
    }
  },
);

export default router;
