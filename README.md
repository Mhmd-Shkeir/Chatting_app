# Lumina Chat

A real-time Android messaging app built with Flutter and Firebase — direct messages and group chats, media/voice messages, translation, push notifications, and a built-in AI assistant, all on free-tier infrastructure.

**Why "Lumina"?** Communication is about bringing people closer and making conversations clearer — Lumina represents light, connection, and a bright space for people to communicate. The brand mark (an L built from a glowing bar and a spark) carries that through the launcher icon, splash screen, and in-app touches.

## Status: Version 1.0

Feature-complete and tested end-to-end against the live Firebase project on both an emulator and a physical device. See `reports/` for the full day-by-day build history, including bugs found and how they were fixed.

## Features

**Messaging**
- Real-time 1:1 and group conversations, with read/delivered receipts and presence (online/last seen)
- Text, image, and voice messages; reply, edit, delete (for me / for everyone), forward
- Emoji reactions and an in-app emoji picker
- Automatic message translation (tap-to-translate, per-message, into your preferred language)
- Clear chat / delete chat (per-user, non-destructive to the other participant)

**Groups**
- Create a group with a name and photo, add members at creation or later
- Remove a member (admin/creator only) and leave a group (any member, including the creator)
- Sender names on incoming group messages; full feature parity with 1:1 chats

**AI Assistant**
- A floating-button entry point to a dedicated assistant chat
- Answers general questions like any AI assistant, and answers "how do I…" questions about Lumina Chat itself, grounded in the app's actual current features (not invented)

**Account & Profile**
- Email/password auth with email verification, session persistence
- Username system (claim + edit, race-safe uniqueness), display name, profile photo
- Self-service account deletion with full cleanup (Firestore, Realtime Database, Auth)
- Settings: Light/Dark/System theme, preferred language

**Notifications**
- Push notifications for new messages, sent client-side (no server, no Cloud Functions)

## Architecture

Feature-first structure (`lib/features/<feature>/{data,presentation}`), repository pattern, Riverpod for state/DI, GoRouter for navigation. Everything runs on **free-tier services only** — no paid Firebase plan, no dedicated backend server:

| Concern | Service | Why |
|---|---|---|
| Auth, database, presence | Firebase Auth, Cloud Firestore, Realtime Database | Free (Spark) tier |
| Media (photos, voice messages) | ImageKit | Firebase Storage requires the paid Blaze plan |
| ImageKit upload signing | Cloudflare Worker | Keeps ImageKit's private key out of the app |
| Translation + AI Assistant | Gemini, via a Cloudflare Worker | Keeps the Gemini API key out of the app; both features share one Worker, dispatched by request shape |
| Push notifications | Cloudflare Worker → FCM | Client-triggered after a message send succeeds — no polling, no Cloud Functions |

Each Cloudflare Worker's source lives in `cloudflare-worker/` and is deployed by pasting it into the Cloudflare dashboard (no build tooling needed) — see the comment block at the top of each file for exact deploy steps.

## Repository Layout

- `lib/` — the Flutter app (feature-first: `lib/features/<feature>/{data,presentation}`, shared code in `lib/core/`)
- `android/` — native Android project (launcher icon, splash, manifest)
- `cloudflare-worker/` — source for the three Workers described above
- `docs/` — original product requirements, architecture decisions, data model, design system notes
- `reports/` — day-by-day build reports: what shipped, what broke, how it was fixed, verified against the real backend
- `prompts/` — AI prompts used during development

## Running it

1. `flutter pub get`
2. Firebase: this repo's `lib/firebase_options.dart` and `android/app/google-services.json` point at the project's own Firebase project (Spark/free tier) — swap in your own via `flutterfire configure` to run against a different project.
3. Deploy the three Cloudflare Workers in `cloudflare-worker/` (see each file's header comment) and set their secrets (ImageKit private key, Gemini API key, Firebase service account JSON). Update the corresponding endpoint constants in `lib/core/config/` if your Worker URLs differ.
4. `flutter run`

## Known Limitations

- Sending an image with no network connectivity can leave it stuck "sending" instead of failing fast with a retry prompt — open, documented in `reports/day-04-05-status-report.md`.
- The AI Assistant's conversation history is in-memory only for the current app session (not persisted).
- Group chat rename, changing a group's photo after creation, and promoting a new admin are intentionally not built yet (the data model already has room for them).
- The debug/release APK is currently signed with a debug key (no dedicated release keystore) — fine for sideloading to testers, not for a Play Store submission as-is.

## What's Next (under consideration, not started)

Google Sign-In, typing indicators, pinned messages, file/document sharing, voice calls, video calls, call history, voice message transcription, @mentions, end-to-end encryption, advanced group administration, and further AI Assistant capabilities. None of these are scoped or scheduled yet — v1.0's priority now is real-world testing and feedback before adding anything new.
