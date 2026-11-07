import { Router, Response } from 'express';
import { Prisma, PrismaClient } from '@prisma/client';
import {
  AuthenticatedRequest,
  authenticateToken,
} from '../middleware/auth.middleware';

const router = Router();
const prisma = new PrismaClient();
const upstreamUrl = 'https://oss.exercisedb.dev/api/v1/exercises';
const fallbackMediaByExerciseId: Record<string, string> = {
  edb_0I5fUyn: 'https://static.exercisedb.dev/media/k6tUeqS.gif',
  edb_0MlxeMn: 'https://static.exercisedb.dev/media/qdRxqCj.gif',
};
const allowedEquipment = new Set([
  'BARBELL',
  'DUMBBELL',
  'BODYWEIGHT',
  'CABLE',
  'MACHINE',
]);

interface ExerciseDbExercise {
  exerciseId: string;
  name: string;
  gifUrl: string;
  bodyParts?: string[];
  equipments?: string[];
  targetMuscles?: string[];
  instructions?: string[];
}

interface ExerciseDbResponse {
  success: boolean;
  data: ExerciseDbExercise[];
  meta: {
    total: number;
    hasNextPage: boolean;
    nextCursor?: string | null;
  };
}

interface ExerciseDbSearchResponse {
  success: boolean;
  data: ExerciseDbExercise[];
}

function exerciseDbSearchTerms(name: string): string[] {
  const terms = [name];
  const simplifiedName = name
    .replace(/\b(hold|position|exercise)\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (simplifiedName && simplifiedName !== name) terms.push(simplifiedName);
  return [...new Set(terms)];
}

function queryValues(value: unknown): string[] {
  const values = Array.isArray(value) ? value : [value];
  return values
    .flatMap((entry) => (typeof entry === 'string' ? entry.split(',') : []))
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function toTitleCase(value: string): string {
  return value
    .split(/[\s_-]+/)
    .filter(Boolean)
    .map((part) => part[0].toUpperCase() + part.slice(1).toLowerCase())
    .join(' ');
}

function normalizeExercise(exercise: ExerciseDbExercise) {
  const equipmentRequired = (exercise.equipments ?? []).map((equipment) =>
    equipment.toUpperCase().replace(/[\s-]+/g, '_'),
  );
  const gifUrl = new URL(exercise.gifUrl);
  if (
    gifUrl.protocol !== 'https:' ||
    !['static.exercisedb.dev', 'assets.exercisedb.dev'].includes(gifUrl.hostname)
  ) {
    throw new Error(`ExerciseDB returned an unsupported media URL for ${exercise.exerciseId}.`);
  }

  return {
    id: `edb_${exercise.exerciseId}`,
    name: exercise.name,
    targetMuscle: toTitleCase(
      exercise.bodyParts?.[0] ??
        exercise.targetMuscles?.[0] ??
        'Other',
    ),
    category: 'STRENGTH',
    equipmentRequired,
    instructions: (exercise.instructions ?? []).join('\n'),
    gifUrl: gifUrl.toString(),
    mediaSource: 'ExerciseDB',
    caloriesPerMin: new Prisma.Decimal(0),
  };
}

router.get(
  '/:exerciseId/media',
  async (req: AuthenticatedRequest, res: Response) => {
    const exerciseId = req.params.exerciseId;
    if (
      typeof exerciseId !== 'string' ||
      !/^(?:edb_[A-Za-z0-9_-]+|[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i.test(
        exerciseId,
      )
    ) {
      return res.status(400).json({ message: 'Invalid animated exercise ID.' });
    }

    try {
      const exercise = await prisma.exercise.findUnique({
        where: { id: exerciseId },
        select: { name: true, gifUrl: true },
      });
      if (!exercise) {
        return res.status(404).json({ message: 'Exercise not found.' });
      }

      const fetchGif = async (url: string) => {
        const gifUrl = new URL(url);
        if (
          gifUrl.protocol !== 'https:' ||
          gifUrl.hostname !== 'static.exercisedb.dev' ||
          !gifUrl.pathname.startsWith('/media/')
        ) {
          return null;
        }

        const response = await fetch(gifUrl, {
          signal: AbortSignal.timeout(12000),
        });
        if (!response.ok) return null;

        const contentType = response.headers.get('content-type')?.split(';')[0];
        if (contentType !== 'image/gif') return null;

        const contentLength = Number(response.headers.get('content-length'));
        if (Number.isFinite(contentLength) && contentLength > 8 * 1024 * 1024) {
          return null;
        }

        const image = Buffer.from(await response.arrayBuffer());
        return image.length <= 8 * 1024 * 1024 ? { image, url } : null;
      };

      let media = exercise.gifUrl ? await fetchGif(exercise.gifUrl) : null;
      if (!media) {
        for (const searchTerm of exerciseDbSearchTerms(exercise.name)) {
          const searchParams = new URLSearchParams({ search: searchTerm });
          try {
            const searchResponse = await fetch(
              `https://oss.exercisedb.dev/api/v1/exercises/search?${searchParams}`,
              { signal: AbortSignal.timeout(12000) },
            );
            if (searchResponse.ok) {
              const searchPayload =
                (await searchResponse.json()) as ExerciseDbSearchResponse;
              const candidates =
                searchPayload.success && Array.isArray(searchPayload.data)
                  ? searchPayload.data
                      .filter((item) => item.gifUrl)
                      .sort((a, b) => {
                        const aExact =
                          a.name.trim().toLowerCase() ===
                          exercise.name.trim().toLowerCase();
                        const bExact =
                          b.name.trim().toLowerCase() ===
                          exercise.name.trim().toLowerCase();
                        return Number(bExact) - Number(aExact);
                      })
                      .slice(0, 5)
                  : [];
              for (const candidate of candidates) {
                media = await fetchGif(candidate.gifUrl);
                if (media) break;
              }
              if (media) break;
            } else {
              console.warn(
                `ExerciseDB search failed with status ${searchResponse.status}.`,
              );
            }
          } catch (error) {
            console.warn(
              `ExerciseDB search failed for "${searchTerm}":`,
              error,
            );
          }
        }

        const fallbackUrl = fallbackMediaByExerciseId[exerciseId];
        if (!media && fallbackUrl) {
          media = await fetchGif(fallbackUrl);
        }
      }

      if (!media) {
        console.error(`No working ExerciseDB animation found for ${exerciseId}.`);
        return res.status(502).json({ message: 'Exercise animation is unavailable.' });
      }

      if (media.url !== exercise.gifUrl) {
        await prisma.exercise.update({
          where: { id: exerciseId },
          data: { gifUrl: media.url },
        });
      }

      return res
        .set('Content-Type', 'image/gif')
        .set('Cache-Control', 'public, max-age=86400')
        .send(media.image);
    } catch (error) {
      console.error(`Failed to load exercise animation ${exerciseId}:`, error);
      return res.status(502).json({ message: 'Failed to load exercise animation.' });
    }
  },
);

router.get(
  '/',
  authenticateToken,
  async (req: AuthenticatedRequest, res: Response) => {
    const search = queryValues(req.query.search ?? req.query.q)[0];
    const muscles = queryValues(req.query.muscle ?? req.query.muscles);
    const equipment = queryValues(req.query.equipment).map((value) =>
      value.toUpperCase().replace(/[\s-]+/g, '_'),
    );
    const pageSize = Number(req.query.pageSize ?? 25);
    const cursor = queryValues(req.query.cursor)[0];

    if (
      !Number.isInteger(pageSize) ||
      pageSize < 1 ||
      pageSize > 25 ||
      equipment.some((item) => !allowedEquipment.has(item))
    ) {
      return res.status(400).json({ message: 'Invalid animated exercise filters.' });
    }

    const params = new URLSearchParams({ limit: String(pageSize) });
    if (search) params.set('name', search.slice(0, 100));
    if (muscles.length > 0) params.set('bodyParts', muscles.join(','));
    if (equipment.length > 0) {
      params.set(
        'equipments',
        equipment.map((value) => toTitleCase(value)).join(','),
      );
    }
    if (cursor) params.set('after', cursor);

    try {
      const response = await fetch(`${upstreamUrl}?${params}`, {
        signal: AbortSignal.timeout(12000),
      });
      if (!response.ok) {
        console.error(
          `ExerciseDB request failed with status ${response.status}.`,
        );
        return res.status(502).json({
          message: 'The animated exercise catalog is temporarily unavailable.',
        });
      }

      const payload = (await response.json()) as ExerciseDbResponse;
      if (!payload.success || !Array.isArray(payload.data) || !payload.meta) {
        console.error('ExerciseDB returned an unexpected response shape.');
        return res.status(502).json({
          message: 'The animated exercise catalog returned an invalid response.',
        });
      }

      const normalized = payload.data.map(normalizeExercise);
      await prisma.exercise.createMany({
        data: normalized,
        skipDuplicates: true,
      });

      const items = await prisma.exercise.findMany({
        where: { id: { in: normalized.map((exercise) => exercise.id) } },
        orderBy: { name: 'asc' },
      });

      return res.json({
        items,
        pageSize,
        total: payload.meta.total,
        hasMore: Boolean(payload.meta.hasNextPage && payload.meta.nextCursor),
        nextCursor: payload.meta.nextCursor ?? null,
        attribution: 'Exercise data and animated GIFs provided by ExerciseDB.',
        licenseNotice:
          'Review ExerciseDB terms before redistribution; free API access is not a public-domain license.',
      });
    } catch (error) {
      console.error('Failed to load animated exercises:', error);
      return res.status(502).json({
        message: 'Failed to load animated exercises. Please try again.',
      });
    }
  },
);

export default router;
