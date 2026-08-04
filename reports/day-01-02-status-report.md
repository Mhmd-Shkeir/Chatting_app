# Lumina Chat — Status Report (Day 1–2)

**Project:** Lumina Chat — Android messaging application
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database)
**Period covered:** Day 1–2

## Summary

In the first two days, we finalized the technical architecture, stood up the full Firebase backend, and delivered a working authentication and real-time one-to-one messaging core, verified end-to-end with real accounts.

## Day 1 — Architecture, Setup, Authentication

- Finalized product requirements, system architecture, Firestore schema, security rules, navigation flow, and coding conventions before writing any application code
- Chose Firebase (Spark / free tier) as the backend to fit the project timeline, with Firestore security rules enforced from day one — never left in test/open mode
- Initialized the Flutter project on a feature-first architecture with the Repository Pattern, using Riverpod for state management and GoRouter for navigation
- Implemented email/password authentication: registration, login, logout, and persistent sessions
- A user profile document is created automatically in Firestore on registration
- Verified on a live Android emulator: account creation, correct Firestore data, login/logout

## Day 2 — Real-Time Messaging Core

- User search by display name
- One-to-one conversations, with duplicate conversations structurally prevented by design (not just discouraged by convention)
- Real-time messaging: messages are delivered live through Firestore's real-time listeners, with atomic writes so the conversation list and message history can never fall out of sync with each other
- Found and fixed one security-rules bug that blocked first-time conversation creation, caught during testing before it could reach real use
- Verified end-to-end with two real test accounts: search, conversation creation, live message delivery, conversation previews, and timestamps all confirmed correct
- All code passes static analysis with zero issues

## Scope Decisions

- Deferred to a later release: voice calls, push notifications, image/file sharing, and profile pictures. None of these are required for a working messaging experience, and keeping them out for now let the two most important flows — authentication and real-time messaging — be built correctly and tested thoroughly first
- Visual design currently uses Flutter's default Material 3 theme; final branding and color will be applied once core functionality is complete, so that design decisions are made against real, working screens rather than guesswork

## Status

Day 1–2 objectives are complete. Two items are tracked, non-blocking, for the next phase: presence/online status and read receipts, and a full concurrent two-device verification once a second test device is available.
