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

Only conversation participants may

- Read conversations
- Create messages
- Read messages
- Update read status

Non-participants cannot access private conversations.

---

# Messages

Sender must equal authenticated user.

Messages cannot impersonate another user.

Message fields must be validated.

Maximum message length should be limited.

---

# Storage

Only authenticated users may upload.

Allowed types

- jpg
- jpeg
- png
- webp

Maximum file size should be limited.

Uploads belong only to the uploader.

---

# General Principles

Never leave Firestore in test mode.

Never leave Storage in test mode.

Do not expose privileged Firebase credentials.

Validate on both

- Client
- Security Rules

Security Rules are the final authority.