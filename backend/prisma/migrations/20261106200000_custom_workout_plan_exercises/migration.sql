CREATE TABLE "CustomPlanExercise" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "daysPerWeek" INTEGER NOT NULL,
    "dayIndex" INTEGER NOT NULL,
    "exerciseId" TEXT NOT NULL,
    "targetSets" INTEGER NOT NULL,
    "targetReps" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CustomPlanExercise_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "CustomPlanExercise_userId_daysPerWeek_dayIndex_exerciseId_key"
ON "CustomPlanExercise"("userId", "daysPerWeek", "dayIndex", "exerciseId");

CREATE INDEX "CustomPlanExercise_userId_daysPerWeek_dayIndex_idx"
ON "CustomPlanExercise"("userId", "daysPerWeek", "dayIndex");

ALTER TABLE "CustomPlanExercise"
ADD CONSTRAINT "CustomPlanExercise_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "User"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomPlanExercise"
ADD CONSTRAINT "CustomPlanExercise_exerciseId_fkey"
FOREIGN KEY ("exerciseId") REFERENCES "Exercise"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
