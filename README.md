# Lumina Chat (working name)

Production-oriented Android messaging application built with Flutter and Firebase, demonstrating modern architecture for a technical interview / portfolio submission.

## Objective

Build a production-oriented Android messaging application that provides secure authentication, real-time one-to-one messaging, media sharing, and push notifications using Firebase services. The application should be scalable, maintainable, and demonstrate modern Flutter architecture.

## Status

Planning phase. No Flutter project has been created yet.

## Repository Layout

- `docs/` — product requirements, architecture decisions, data model, engineering rules
- `assets/images/` — source images for the app (illustrations, placeholders, etc.)
- `assets/icons/` — icon assets
- `design/` — design references, mockups, style/design system notes
- `prompts/` — AI prompts used during development

## Stack (frozen v1.0)

- Flutter / Dart, Material 3 with a custom design system
- Riverpod (state management / DI), GoRouter (navigation)
- Firebase Authentication, Cloud Firestore, Firebase Storage, Firebase Cloud Messaging
- Cloud Functions (minimal, notification trigger only)
- Firebase Realtime Database (P1, presence only)
- Feature-first architecture, Repository Pattern

## Scope

See `docs/` for full Product Requirements, P0/P1/P2 feature breakdown, and engineering rules.
