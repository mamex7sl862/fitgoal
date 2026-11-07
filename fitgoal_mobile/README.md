# fitgoal_mobile

## Animated exercise demonstrations

The exercise library loads animated exercise demonstrations from the backend's
authenticated `GET /api/animated-exercises` endpoint. The backend caches exercise
metadata locally and proxies GIFs through
`GET /api/animated-exercises/:exerciseId/media` to avoid browser CORS restrictions.
The free upstream catalog contains about 1,500 exercises; this is not a
4,000-exercise dataset.

Exercise data and GIFs are provided by
[ExerciseDB](https://docs.ascendapi.com/products/edb-v1/overview.md). Free API
access does not establish a public-domain or redistribution license; review the
provider's current terms before publishing or redistributing these assets.

The exercise demo's spoken repetition guide uses on-device text-to-speech. It
paces a count alongside the looping animation; it does not detect or verify
movement.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
