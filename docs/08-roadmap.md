# Development Roadmap

## Phase 0

Planning

✔ Requirements

✔ Architecture

✔ Firestore Schema

✔ Security

✔ Navigation

✔ Design System

✔ Workflow

---

## Phase 1

Project Setup

- Create Flutter project
- Configure Firebase
- Install dependencies
- Configure Android
- Configure GoRouter
- Configure Riverpod

---

## Phase 2

Authentication

- Login
- Register
- Logout
- Session persistence
- User profile creation

Acceptance

Users can authenticate successfully.

---

## Phase 3

Messaging Core

- User model
- User search
- Conversations
- Real-time messaging

Acceptance

Two devices can find each other by search and exchange real-time messages.

Status

- Implementation: ✅ Complete
- Architecture: ✅ Complete
- Verification: ✅ Complete (with one noted limitation)

Remaining limitation

- End-to-end messaging has not yet been verified simultaneously between two live Flutter instances.
- Current verification uses one live Flutter client and one authenticated Firestore REST client, which successfully validates the real-time listener architecture.
- A full two-device verification will be performed when a second emulator or physical device is available.

---

## Phase 4

Presence & Receipts

- Online/offline presence (Realtime Database)
- Read/Seen receipts

Acceptance

Presence updates live between two devices, and message status reflects sent/delivered/seen correctly.

---

## Phase 5

Polish

- Loading states
- Error states
- Empty states
- Performance
- UI polish
- Security review

---

## Phase 6

Release

- Release APK
- GitHub cleanup
- README
- Screenshots
- Architecture diagram
- Demo video
- Final testing

---

## Post-MVP (v1.1)

Not implemented, designed, or scoped during the MVP. Listed here only so the plan isn't lost.

### Voice calls (WebRTC)

Documented as a future enhancement only. No implementation, architecture, or roadmap work happens during the MVP.

### Push notifications

Chat functionality must remain completely independent of this backend — if the notification server is unavailable, messaging must continue to function normally.

```
Flutter
    │
    ├────────────► Firestore
    │
    └────────────► Node.js + Express API
                       │
                       ▼
              Firebase Admin SDK
                       │
                       ▼
                      FCM
                       │
                       ▼
                  Android Device
```

- The Node.js backend exposes exactly one endpoint: `POST /notify`.
- Its sole responsibility is sending FCM notifications.
- No Cloud Functions — this is a separate, self-hosted service, kept outside Firebase billing entirely.

### Image/File sharing

Requires Firebase Storage (Blaze plan) — see `01-project-requirements.md` Constraints.

### Profile pictures

Same Storage dependency as image/file sharing above.