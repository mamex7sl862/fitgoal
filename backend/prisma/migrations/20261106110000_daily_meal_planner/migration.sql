ALTER TABLE "MealPlan"
ADD COLUMN "planDate" DATE;

WITH "rankedPlans" AS (
    SELECT
        "id",
        (ROW_NUMBER() OVER (PARTITION BY "userId" ORDER BY "id") - 1)::integer AS "dayOffset"
    FROM "MealPlan"
)
UPDATE "MealPlan"
SET "planDate" = CURRENT_DATE - "rankedPlans"."dayOffset"
FROM "rankedPlans"
WHERE "MealPlan"."id" = "rankedPlans"."id";

ALTER TABLE "MealPlan"
ALTER COLUMN "planDate" SET NOT NULL,
ALTER COLUMN "planDate" SET DEFAULT CURRENT_DATE;

CREATE UNIQUE INDEX "MealPlan_userId_planDate_key"
ON "MealPlan"("userId", "planDate");

ALTER TABLE "MealLog"
ADD COLUMN "planMealId" TEXT;

CREATE UNIQUE INDEX "MealLog_planMealId_key"
ON "MealLog"("planMealId");

ALTER TABLE "MealLog"
ADD CONSTRAINT "MealLog_planMealId_fkey"
FOREIGN KEY ("planMealId") REFERENCES "Meal"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
