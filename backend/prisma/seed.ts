import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const allowedCategories = new Set(['COMPOUND', 'ISOLATION']);
const allowedEquipment = new Set([
  'BARBELL',
  'DUMBBELL',
  'BODYWEIGHT',
  'CABLE',
  'MACHINE',
]);

interface ExerciseInput {
  id?: string;
  name: string;
  targetMuscle: string;
  category: string;
  equipmentRequired: string[];
  instructions: string;
  caloriesPerMin?: number;
}

const sampleExercises: ExerciseInput[] = [
  {
    name: 'Barbell Bench Press',
    targetMuscle: 'Chest',
    category: 'COMPOUND',
    equipmentRequired: ['BARBELL'],
    caloriesPerMin: 8.5,
    instructions: 'Lower the bar with control to the mid-chest, then press while keeping the shoulders stable.',
  },
  {
    name: 'Conventional Deadlift',
    targetMuscle: 'Back',
    category: 'COMPOUND',
    equipmentRequired: ['BARBELL'],
    caloriesPerMin: 10,
    instructions: 'Brace, keep the bar close, and stand by extending the hips and knees together.',
  },
  {
    name: 'Barbell Back Squat',
    targetMuscle: 'Legs',
    category: 'COMPOUND',
    equipmentRequired: ['BARBELL'],
    caloriesPerMin: 9.5,
    instructions: 'Brace your trunk, sit between your hips, and keep the whole foot planted as you stand.',
  },
  {
    name: 'Pull-Ups',
    targetMuscle: 'Back',
    category: 'COMPOUND',
    equipmentRequired: ['BODYWEIGHT'],
    caloriesPerMin: 8,
    instructions: 'Pull your chest toward the bar without swinging, then lower under control.',
  },
  {
    name: 'Overhead Shoulder Press',
    targetMuscle: 'Shoulders',
    category: 'COMPOUND',
    equipmentRequired: ['BARBELL'],
    caloriesPerMin: 7.5,
    instructions: 'Brace your core and press the bar overhead without leaning back.',
  },
  {
    name: 'Plank Hold',
    targetMuscle: 'Core',
    category: 'ISOLATION',
    equipmentRequired: ['BODYWEIGHT'],
    caloriesPerMin: 5,
    instructions: 'Keep a straight line from head to heels while bracing the core.',
  },
];

function parseExercises(value: unknown): ExerciseInput[] {
  if (!Array.isArray(value)) {
    throw new Error('Exercise data must be a JSON array.');
  }

  return value.map((item, index) => {
    if (typeof item !== 'object' || item === null) {
      throw new Error(`Exercise row ${index + 1} must be an object.`);
    }
    const row = item as Record<string, unknown>;
    const equipmentRequired = row.equipmentRequired;
    const category =
      typeof row.category === 'string' ? row.category.toUpperCase() : '';
    if (
      typeof row.name !== 'string' ||
      row.name.trim().length === 0 ||
      typeof row.targetMuscle !== 'string' ||
      row.targetMuscle.trim().length === 0 ||
      typeof row.instructions !== 'string' ||
      row.instructions.trim().length === 0 ||
      !allowedCategories.has(category) ||
      (row.caloriesPerMin !== undefined &&
        (typeof row.caloriesPerMin !== 'number' ||
          !Number.isFinite(row.caloriesPerMin) ||
          row.caloriesPerMin < 0)) ||
      !Array.isArray(equipmentRequired) ||
      equipmentRequired.some(
        (equipment) =>
          typeof equipment !== 'string' ||
          !allowedEquipment.has(equipment.toUpperCase()),
      )
    ) {
      throw new Error(`Exercise row ${index + 1} has invalid fields.`);
    }
    return {
      id: typeof row.id === 'string' ? row.id : undefined,
      name: row.name.trim(),
      targetMuscle: row.targetMuscle.trim(),
      category,
      equipmentRequired: equipmentRequired.map((equipment: string) =>
        equipment.toUpperCase(),
      ),
      instructions: row.instructions.trim(),
      caloriesPerMin:
        typeof row.caloriesPerMin === 'number' ? row.caloriesPerMin : 0,
    };
  });
}

function stableId(exercise: ExerciseInput): string {
  if (exercise.id) return exercise.id;
  const identity = [
    exercise.name,
    exercise.targetMuscle,
    exercise.category,
    [...exercise.equipmentRequired].sort().join(','),
  ].join('|');
  return `exercise_${createHash('sha256').update(identity).digest('hex').slice(0, 32)}`;
}

function exerciseSignature(
  exercise: Pick<
    ExerciseInput,
    'name' | 'targetMuscle' | 'category' | 'equipmentRequired'
  >,
): string {
  return [
    exercise.name.trim().toLowerCase(),
    exercise.targetMuscle.trim().toLowerCase(),
    exercise.category.toUpperCase(),
    [...exercise.equipmentRequired].map((item) => item.toUpperCase()).sort().join(','),
  ].join('|');
}

async function main() {
  const dataPath = resolve(
    process.env.EXERCISE_DATA_FILE ?? 'prisma/data/exercises.json',
  );
  const hasExternalCatalog = existsSync(dataPath);
  if (process.env.EXERCISE_DATA_FILE && !hasExternalCatalog) {
    throw new Error(`Exercise data file not found: ${dataPath}`);
  }
  const exercises = hasExternalCatalog
    ? parseExercises(JSON.parse(readFileSync(dataPath, 'utf8')))
    : sampleExercises;

  if (exercises.length === 0) {
    throw new Error('No exercise records were provided.');
  }
  if (hasExternalCatalog && exercises.length < 4000) {
    throw new Error(
      `The external exercise catalog must contain at least 4,000 records; found ${exercises.length}.`,
    );
  }

  const rows = exercises.map((exercise) => ({
    id: stableId(exercise),
    name: exercise.name,
    targetMuscle: exercise.targetMuscle,
    category: exercise.category,
    equipmentRequired: exercise.equipmentRequired,
    instructions: exercise.instructions,
    caloriesPerMin: new Prisma.Decimal(exercise.caloriesPerMin ?? 0),
  }));
  const existingExercises = await prisma.exercise.findMany({
    select: {
      id: true,
      name: true,
      targetMuscle: true,
      category: true,
      equipmentRequired: true,
    },
  });
  const knownIds = new Set(existingExercises.map((exercise) => exercise.id));
  const knownSignatures = new Set(
    existingExercises.map(exerciseSignature),
  );
  const newRows = rows.filter((exercise) => {
    const signature = exerciseSignature(exercise);
    if (knownIds.has(exercise.id) || knownSignatures.has(signature)) return false;
    knownIds.add(exercise.id);
    knownSignatures.add(signature);
    return true;
  });
  const result = await prisma.exercise.createMany({
    data: newRows,
    skipDuplicates: true,
  });

  console.log(
    `Imported ${result.count} new exercises; ${rows.length - result.count} matching or duplicate records were skipped.`,
  );
  if (!hasExternalCatalog) {
    console.warn(
      'No external catalog found; seeded only the six built-in examples. Provide an appropriately licensed 4,000+ row JSON file at prisma/data/exercises.json or set EXERCISE_DATA_FILE.',
    );
  }
}

main()
  .catch((error) => {
    console.error('Exercise import failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
