import { PrismaClient } from '@prisma/client';

const promotionStandards: Record<
  string,
  { nextLevel: string; sessions: number; spanDays: number }
> = {
  BEGINNER: { nextLevel: 'INTERMEDIATE', sessions: 12, spanDays: 21 },
  INTERMEDIATE: { nextLevel: 'ADVANCED', sessions: 20, spanDays: 35 },
};

export async function getTrainingWeekProgress(
  prisma: PrismaClient,
  userId: string,
  since: Date,
  plannedDayIndexes: number[],
) {
  const sessions = await prisma.workoutSession.findMany({
    where: {
      userId,
      status: { in: ['ACTIVE', 'COMPLETED'] },
      startedAt: { gte: since },
    },
    orderBy: { startedAt: 'asc' },
    select: {
      status: true,
      trainingWeek: true,
      planDayIndex: true,
    },
  });

  const completedByWeek = new Map<number, Set<number>>();
  const legacySessions: typeof sessions = [];
  let latestTaggedWeek = 1;
  for (const session of sessions) {
    if (session.trainingWeek == null || session.planDayIndex == null) {
      if (session.status === 'COMPLETED') {
        legacySessions.push(session);
      }
      continue;
    }

    latestTaggedWeek = Math.max(latestTaggedWeek, session.trainingWeek);
    if (
      session.status !== 'COMPLETED' ||
      !plannedDayIndexes.includes(session.planDayIndex)
    ) {
      continue;
    }

    const completedDays =
      completedByWeek.get(session.trainingWeek) ?? new Set<number>();
    completedDays.add(session.planDayIndex);
    completedByWeek.set(session.trainingWeek, completedDays);
  }

  let inferredWeek = 1;
  for (const session of legacySessions) {
    let completedDays =
      completedByWeek.get(inferredWeek) ?? new Set<number>();
    while (
      plannedDayIndexes.length > 0 &&
      plannedDayIndexes.every((index) => completedDays.has(index))
    ) {
      inferredWeek += 1;
      completedDays =
        completedByWeek.get(inferredWeek) ?? new Set<number>();
    }

    const nextDay = plannedDayIndexes.find(
      (index) => !completedDays.has(index),
    );
    if (nextDay != null) {
      completedDays.add(nextDay);
      completedByWeek.set(inferredWeek, completedDays);
    }
  }

  const trainingWeek = Math.max(latestTaggedWeek, inferredWeek);
  const completedDays = completedByWeek.get(trainingWeek) ?? new Set<number>();
  if (
    plannedDayIndexes.length > 0 &&
    plannedDayIndexes.every((index) => completedDays.has(index))
  ) {
    return {
      trainingWeek: trainingWeek + 1,
      completedPlanDaysInWeek: [] as number[],
    };
  }

  return {
    trainingWeek,
    completedPlanDaysInWeek: [...completedDays].sort((a, b) => a - b),
  };
}

export async function evaluateFitnessLevelPromotion(
  prisma: PrismaClient,
  userId: string,
) {
  const goal = await prisma.userGoal.findUnique({ where: { userId } });
  if (!goal) return null;

  const standard = promotionStandards[goal.fitnessLevel];
  if (!standard) return null;

  const qualifyingSessions = await prisma.workoutSession.findMany({
    where: {
      userId,
      status: 'COMPLETED',
      startedAt: { gte: goal.fitnessLevelUpdatedAt },
    },
    orderBy: { startedAt: 'asc' },
    select: {
      startedAt: true,
      exercises: {
        select: {
          targetSets: true,
          sets: { where: { completed: true }, select: { id: true } },
        },
      },
    },
  });
  const qualified = qualifyingSessions.filter((session) => {
    const plannedSets = session.exercises.reduce(
      (total, exercise) => total + exercise.targetSets,
      0,
    );
    const completedSets = session.exercises.reduce(
      (total, exercise) => total + exercise.sets.length,
      0,
    );
    return plannedSets > 0 && completedSets / plannedSets >= 0.75;
  });

  if (qualified.length < standard.sessions) return null;
  const firstSession = qualified[0];
  const lastSession = qualified[qualified.length - 1];
  const spanDays =
    (lastSession.startedAt.getTime() - firstSession.startedAt.getTime()) /
    (24 * 60 * 60 * 1000);
  if (spanDays < standard.spanDays) return null;

  const updated = await prisma.userGoal.updateMany({
    where: {
      userId,
      fitnessLevel: goal.fitnessLevel,
      fitnessLevelUpdatedAt: goal.fitnessLevelUpdatedAt,
    },
    data: {
      fitnessLevel: standard.nextLevel,
      fitnessLevelUpdatedAt: new Date(),
    },
  });
  if (updated.count !== 1) return null;

  const currentLabel =
    goal.fitnessLevel.charAt(0) + goal.fitnessLevel.slice(1).toLowerCase();
  const nextLabel =
    standard.nextLevel.charAt(0) +
    standard.nextLevel.slice(1).toLowerCase();
  return {
    fitnessLevel: standard.nextLevel,
    message: `Great consistency! Your coach has promoted you from ${currentLabel} to ${nextLabel}. Your next workout plan will reflect your new level.`,
  };
}
