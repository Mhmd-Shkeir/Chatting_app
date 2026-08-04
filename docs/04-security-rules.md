# Firebase Security Strategy

## Philosophy

The client application is never trusted.

Security is enforced by Firebase Security Rules.

---

# Authentication

Only authenticated users may access application data.

Unauthenticated requests are rejected.

---

# Users

Users may

- Read public profile information
- Update only their own profile

Users may NOT

- Modify another user's profile
- Change another user's FCM token
- Change another user's online status

---

# Conversations

Creating a conversation

- A user may create a conversation document only if their own uid is included in `participants`.
- `participants` must contain exactly two uids for a one-to-one conversation.
- A user cannot create a conversation on behalf of two other users.

Only conversation participants may

- Read conversations
- Create messages
- Read messages
- Update read status

Non-participants cannot access private conversations.

Reading a conversation that doesn't exist yet

`getOrCreateConversation()` checks whether a conversation already exists before creating one. A naive rule of "auth.uid in resource.data.participants" throws instead of denying when the document doesn't exist yet, because `resource` is null — this blocked every first-time conversation until fixed. The `get` rule explicitly tolerates a non-existent document; `list` doesn't need the same guard since query results only ever contain documents that exist.

---

# Messages

Sender must equal authenticated user.

Messages cannot impersonate another user.

Message fields must be validated.

Maximum message length should be limited.

---

# Storage (Post-MVP v1.1 — not active)

Firebase Storage is not part of the MVP. These rules are drafted for when image/file sharing and profile pictures are implemented later, not enforced or deployed now.

Only authenticated users may upload.

Allowed types

- jpg
- jpeg
- png
- webp

Maximum file size should be limited.

Uploads belong only to the uploader.

---

# Realtime Database (Presence)

Realtime Database uses its own rules syntax (`database.rules.json`), separate from these Firestore rules. Not yet written — needed before Phase 4 (Presence & Receipts) ships. At minimum: a user may only write their own presence node, and any authenticated user may read presence data.

---

# General Principles

Never leave Firestore in test mode.

Never leave Storage in test mode.

Do not expose privileged Firebase credentials.

Validate on both

- Client
- Security Rules

Security Rules are the final authority.