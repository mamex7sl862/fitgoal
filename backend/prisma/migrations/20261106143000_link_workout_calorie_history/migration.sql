ALTER TABLE "WorkoutLog"
ADD COLUMN "sessionId" TEXT;

CREATE UNIQUE INDEX "WorkoutLog_sessionId_key"
ON "WorkoutLog"("sessionId");

ALTER TABLE "WorkoutLog"
ADD CONSTRAINT "WorkoutLog_sessionId_fkey"
FOREIGN KEY ("sessionId") REFERENCES "WorkoutSession"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "WorkoutSession"
ADD COLUMN "trainingWeek" INTEGER,
ADD COLUMN "planDayIndex" INTEGER;

CREATE INDEX "WorkoutSession_userId_trainingWeek_planDayIndex_status_idx"
ON "WorkoutSession"("userId", "trainingWeek", "planDayIndex", "status");
