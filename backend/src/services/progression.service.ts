import { PrismaClient } from '@prisma/client';

export async function getLatestExerciseProgress(
  prisma: PrismaClient,
  userId: string,
  exerciseId: string,
) {
  const previous = await prisma.workoutSession.findFirst({
    where: {
      userId,
      status: 'COMPLETED',
      exercises: { some: { exerciseId } },
    },
    orderBy: { startedAt: 'desc' },
    include: {
      exercises: {
        where: { exerciseId },
        include: {
          exercise: { select: { name: true } },
          sets: {
            where: { completed: true },
            orderBy: { setNumber: 'asc' },
          },
        },
      },
    },
  });

  const previousExercise = previous?.exercises[0];
  const topSet = previousExercise?.sets.reduce<
    (typeof previousExercise.sets)[number] | undefined
  >((best, set) => (!best || set.weightKg.gt(best.weightKg) ? set : best), undefined);
  const weight = topSet ? Number(topSet.weightKg) : null;
  const rpe = topSet?.rpe == null ? null : Number(topSet.rpe);

  let recommendedWeightKg: number | null = null;
  if (weight !== null) {
    const adjustment = rpe !== null && rpe <= 7 ? 1.025 : rpe !== null && rpe >= 9 ? 0.975 : 1;
    recommendedWeightKg = Math.max(0, Math.round((weight * adjustment) / 0.5) * 0.5);
  }

  return {
    previousSessionAt: previous?.startedAt ?? null,
    previousSets: previousExercise?.sets.map((set) => ({
      setNumber: set.setNumber,
      weightKg: Number(set.weightKg),
      reps: set.reps,
      rpe: set.rpe == null ? null : Number(set.rpe),
    })) ?? [],
    recommendedWeightKg,
    recommendationReason:
      weight === null
        ? 'No completed session recorded yet.'
        : rpe !== null && rpe <= 7
          ? 'Last top set was at RPE 7 or below; increase by about 2.5%.'
          : rpe !== null && rpe >= 9
            ? 'Last top set was at RPE 9 or above; reduce by about 2.5%.'
            : 'Keep the previous load and aim for clean reps.',
  };
}
