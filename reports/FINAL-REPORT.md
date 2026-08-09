# Lumina Chat — Final Project Report

**Project:** Lumina Chat — a real-time Android messaging application
**Author:** Mohammad Ali Shkeir
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database), Cloudflare Workers, ImageKit
**Development period:** Day 1 through Day 9 (see `reports/day-*.md` for the full build history, bugs found, and how each was fixed)

## Executive Summary

Lumina Chat is a feature-complete, real-time messaging app built entirely on free-tier infrastructure — no paid Firebase plan, no dedicated backend server. It supports direct and group conversations, media and voice messages, translation, push notifications, a built-in AI assistant, and an opt-in basic end-to-end encryption mode for 1:1 chats. Every feature listed below was built and then verified live against the real Firebase backend and real devices — not just visually reviewed — with bugs found during that verification documented honestly rather than glossed over (see the day-by-day reports).

## Feature List

### Messaging
- Real-time 1:1 and group conversations, with delivered/read receipts and presence (online/last seen)
- Text, image, and voice messages
- Reply, edit, delete (for me / for everyone), forward
- Emoji reactions and an in-app emoji picker
- Automatic per-message translation into the viewer's preferred language
- Clear chat / delete chat (per-user, non-destructive to the other participant)
- Typing indicators (self-healing — clears automatically even if no explicit "stopped typing" signal arrives)
- @mentions in group chats, with autocomplete, highlighted rendering, and a dedicated unread-mention badge
- Group read receipts that only turn "read" once *every* current member has actually read the message — not just the first one

### Groups
- Create a group with a name and photo; add members at creation or later
- Remove a member (admin/creator only) and leave a group (any member, including the creator)
- A dedicated "Groups" filter that always shows every group you belong to, even one whose history you've cleared
- Full feature parity with 1:1 chats (media, reactions, replies, translation, etc.)

### Security
- Basic end-to-end encryption (opt-in, toggled per 1:1 conversation): X25519 key exchange + AES-256-GCM, private keys device-only (Android Keystore-backed via `flutter_secure_storage`), Firestore only ever sees ciphertext for these messages. Explicitly scoped as an MVP — documented limitations (no forward secrecy, no key rotation, no multi-device support, no MITM protection without key verification) are in the README, not hidden.

### AI Assistant
- A floating-button entry point to a dedicated assistant chat, backed by Gemini via a Cloudflare Worker
- Answers general questions like any AI assistant, and answers "how do I…" questions about Lumina Chat itself, grounded in the app's actual current features

### Account & Profile
- Email/password authentication with email verification, session persistence
- Google Sign-In alongside email/password
- Username system (claim + edit, race-safe uniqueness), display name, profile photo — all changes propagate live everywhere the name/photo is shown, not just on the user's own screen
- Self-service account deletion with full cleanup across Firestore, Realtime Database, and Auth
- Settings: Light/Dark/System theme, preferred language

### Notifications & Offline Behavior
- Push notifications for new messages, sent client-side (no server, no Cloud Functions)
- Full offline messaging support: text/emoji/replies queue automatically (via Firestore's own durable, ordered offline write queue) and send the moment connectivity returns; image/voice messages fail fast when known-offline and automatically retry on reconnect; a small "No internet connection" indicator appears when offline; clearing/deleting a conversation while offline no longer crashes the app

## Architecture

Feature-first structure (`lib/features/<feature>/{data,presentation}`), repository pattern, Riverpod for state/DI, GoRouter for navigation. Full technical detail — including the Firestore schema, security rules, design system, and navigation structure — lives in `docs/`:

| Doc | Covers |
|---|---|
| `docs/01-project-requirements.md` | Original product requirements |
| `docs/02-system-architecture.md` | High-level architecture decisions |
| `docs/03-firestore-schema.md` | Full Firestore data model |
| `docs/04-security-rules.md` | Firestore/Realtime Database security rules reasoning |
| `docs/05-design-system.md` | Colors, typography, the Lumina brand mark |
| `docs/06-navigation.md` | Screen/route map |
| `docs/07-development-workflow.md` | How the project is built/run/deployed |
| `docs/08-roadmap.md` | Feature roadmap and what's deferred |
| `docs/09-project-conventions.md` | Code conventions |

Everything runs on **free-tier services only**:

| Concern | Service | Why |
|---|---|---|
| Auth, database, presence | Firebase Auth, Cloud Firestore, Realtime Database | Free (Spark) tier |
| Media (photos, voice messages) | ImageKit | Firebase Storage requires the paid Blaze plan |
| ImageKit upload signing | Cloudflare Worker | Keeps ImageKit's private key out of the app |
| Translation + AI Assistant | Gemini, via a Cloudflare Worker | One Worker, dispatched by request shape, keeps the API key server-side |
| Push notifications | Cloudflare Worker → FCM | Client-triggered, no polling, no Cloud Functions |

## Development Timeline

| Day(s) | Delivered |
|---|---|
| 1–2 | Architecture, Firebase setup, authentication, real-time 1:1 messaging core |
| 3 | Presence/last-seen, read receipts |
| 4–5 | Email verification, account deletion, profile pictures, image messages |
| 6 (unreported catch-up + new) | Reply, reactions, settings, translation, push notifications, voice messages, emoji picker, edit/delete/forward, clear/delete chat, username editing — then Group Chats and the AI Assistant |
| 7 | Brand identity (logo, splash, icons), release APK — **Version 1.0** |
| 8 | Google Sign-In, typing indicators, @mentions, Basic E2EE MVP |
| 9 | Group read-receipt fix, Groups filter, group clear/delete fix, display-name propagation fix, offline crash fix, full offline messaging support |

Full detail, including every bug found and exactly how it was diagnosed and fixed, is in the corresponding `reports/day-*.md` file.

## Known Limitations

Documented honestly rather than omitted:

- Basic E2EE MVP scope limitations (see Security above and the README's dedicated section) — not production-grade, by design and by explicit original request.
- AI Assistant conversation history is in-memory only, not persisted across app restarts.
- Group rename, changing a group's photo after creation, and promoting a new admin are intentionally not built yet (the data model already has room for them).
- The current APK is signed with a debug/local key, not a dedicated Play Store release key — fine for sideloaded testing, not for a Play Store submission as-is.
- A minor cosmetic status lag was observed once on an offline-queued image (briefly showed a single checkmark before catching up) — functionally correct, not investigated further given time constraints.

## Repository Layout

- `lib/` — the Flutter app
- `android/` — native Android project (launcher icon, splash, manifest)
- `cloudflare-worker/` — source for the three Workers described above
- `docs/` — architecture, schema, design system, and conventions documentation
- `reports/` — day-by-day build reports, plus this final report
- `prompts/` — AI prompts used during development

## Try It

See the README's "Running it" section for local setup, or download the APK from this repository's Releases page to try it directly on an Android device.
