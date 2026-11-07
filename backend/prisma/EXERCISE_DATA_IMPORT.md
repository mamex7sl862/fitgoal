# Exercise catalog import

The repository includes six original example exercises for local development; it does not bundle a 4,000-row catalog. Add an appropriately licensed catalog as `prisma/data/exercises.json` (or set `EXERCISE_DATA_FILE` to its path), then run `npm run db:seed` from `backend`.

The file must be a JSON array with at least 4,000 entries. Each entry has this shape:

```json
{
  "name": "Dumbbell Floor Press",
  "targetMuscle": "Chest",
  "category": "COMPOUND",
  "equipmentRequired": ["DUMBBELL"],
  "instructions": "Lower the dumbbells under control, then press back to the start."
}
```

Allowed categories are `COMPOUND` and `ISOLATION`. Allowed equipment tags are `BARBELL`, `DUMBBELL`, `BODYWEIGHT`, `CABLE`, and `MACHINE`. `caloriesPerMin` is optional. The importer assigns stable IDs when `id` is omitted and skips existing IDs, so rerunning an import does not delete user or catalog data.

After adding the schema migration, deploy it with `npx prisma migrate deploy` and regenerate the Prisma client with `npx prisma generate`.
