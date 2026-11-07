ALTER TABLE "Exercise"
ADD COLUMN "equipmentRequired" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

UPDATE "Exercise"
SET "category" = CASE
    WHEN "name" = 'Plank Hold' THEN 'ISOLATION'
    ELSE 'COMPOUND'
END;

UPDATE "Exercise"
SET "equipmentRequired" = CASE "name"
    WHEN 'Barbell Bench Press' THEN ARRAY['BARBELL']::TEXT[]
    WHEN 'Conventional Deadlift' THEN ARRAY['BARBELL']::TEXT[]
    WHEN 'Barbell Back Squat' THEN ARRAY['BARBELL']::TEXT[]
    WHEN 'Pull-Ups' THEN ARRAY['BODYWEIGHT']::TEXT[]
    WHEN 'Overhead Shoulder Press' THEN ARRAY['BARBELL']::TEXT[]
    WHEN 'Plank Hold' THEN ARRAY['BODYWEIGHT']::TEXT[]
    ELSE ARRAY[]::TEXT[]
END;

CREATE INDEX "Exercise_targetMuscle_idx" ON "Exercise"("targetMuscle");
CREATE INDEX "Exercise_category_idx" ON "Exercise"("category");
CREATE INDEX "Exercise_equipmentRequired_idx"
ON "Exercise" USING GIN ("equipmentRequired");

ALTER TABLE "WorkoutExercise"
ALTER COLUMN "dayId" DROP NOT NULL,
ALTER COLUMN "targetSets" SET DEFAULT 0,
ALTER COLUMN "targetReps" SET DEFAULT 0,
ADD COLUMN "sessionId" TEXT;

CREATE INDEX "WorkoutExercise_sessionId_idx" ON "WorkoutExercise"("sessionId");
CREATE INDEX "WorkoutExercise_exerciseId_idx" ON "WorkoutExercise"("exerciseId");

CREATE TABLE "WorkoutSession" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "endedAt" TIMESTAMP(3),
    "status" TEXT NOT NULL DEFAULT 'ACTIVE',
    CONSTRAINT "WorkoutSession_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "WorkoutSession_status_check" CHECK ("status" IN ('ACTIVE', 'COMPLETED'))
);

CREATE INDEX "WorkoutSession_userId_status_startedAt_idx"
ON "WorkoutSession"("userId", "status", "startedAt");

CREATE TABLE "ExerciseSet" (
    "id" TEXT NOT NULL,
    "workoutExerciseId" TEXT NOT NULL,
    "setNumber" INTEGER NOT NULL,
    "weightKg" DECIMAL(8,2) NOT NULL,
    "reps" INTEGER NOT NULL,
    "rpe" DECIMAL(3,1),
    "completed" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ExerciseSet_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "ExerciseSet_setNumber_check" CHECK ("setNumber" > 0),
    CONSTRAINT "ExerciseSet_weightKg_check" CHECK ("weightKg" >= 0),
    CONSTRAINT "ExerciseSet_reps_check" CHECK ("reps" > 0),
    CONSTRAINT "ExerciseSet_rpe_check" CHECK ("rpe" IS NULL OR ("rpe" >= 1 AND "rpe" <= 10))
);

CREATE UNIQUE INDEX "ExerciseSet_workoutExerciseId_setNumber_key"
ON "ExerciseSet"("workoutExerciseId", "setNumber");
CREATE INDEX "ExerciseSet_workoutExerciseId_completed_idx"
ON "ExerciseSet"("workoutExerciseId", "completed");

ALTER TABLE "WorkoutExercise"
ADD CONSTRAINT "WorkoutExercise_sessionId_fkey"
FOREIGN KEY ("sessionId") REFERENCES "WorkoutSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "WorkoutSession"
ADD CONSTRAINT "WorkoutSession_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ExerciseSet"
ADD CONSTRAINT "ExerciseSet_workoutExerciseId_fkey"
FOREIGN KEY ("workoutExerciseId") REFERENCES "WorkoutExercise"("id") ON DELETE CASCADE ON UPDATE CASCADE;
