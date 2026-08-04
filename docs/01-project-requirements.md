# Project Requirements

## Project Overview

Build a production-oriented Android messaging application inspired by the interaction patterns of modern messaging platforms such as WhatsApp, Telegram, Signal, and iMessage.

This is not a clone of any existing application. The objective is to demonstrate modern Flutter development, Firebase integration, clean architecture, and software engineering best practices within a five-day development timeline.

This is NOT a clone of any existing application. The objective is to demonstrate software engineering practices, modern Flutter architecture, and real-time communication using Firebase services.

---

# Objectives

- Deliver a production-ready Android APK.
- Build a modern and intuitive messaging application.
- Demonstrate scalable Flutter architecture.
- Use established backend infrastructure.
- Produce a portfolio-quality project.

---

# Target Users

- Technical recruiters
- Mobile development interviewers
- Assignment evaluators

---

# Functional Requirements

## Authentication

- Register
- Login
- Logout
- Persistent sessions

## Profile

- Display name
- Text-only profile (no profile picture in MVP)

## Users

- Search registered users
- Start one-to-one conversation

## Messaging

- Real-time text messaging
- Read/Seen receipts
- Message timestamps

## Conversations

- Conversation list
- Latest message preview
- Unread count

## Presence

- Online/Offline status
- Last seen

---

# Non Functional Requirements

- Clean architecture
- Responsive UI
- Smooth animations
- Offline support
- Secure Firebase rules
- Minimal dependencies
- Repository Pattern for maintainability
---

# Constraints

- Flutter only
- Firebase backend (Spark / free plan only — no Storage, no Cloud Functions)
- Android APK
- Five-day implementation

---

# Out of Scope

- Video calls
- Stories
- Channels
- Communities
- Phone contacts
- End-to-end encryption
- Large group chats

---

# Post-MVP (v1.1)

Planned, but deliberately deferred until after the core MVP ships. No implementation, architecture, or roadmap work happens on these during the MVP.

- Voice calls (WebRTC)
- Push notifications — via a separate Node.js + Firebase Admin SDK service, not Cloud Functions. See `08-roadmap.md` for the architecture.
- Image/File sharing
- Profile pictures

Firebase Storage and Cloud Functions are not part of the MVP as a direct consequence of this list — nothing in the MVP requires either.

---

# Success Criteria
The project is complete when:

- Two users can register and log in successfully.
- A user can search for another registered user and start a conversation.
- Two Android devices can exchange real-time text messages.
- Read/seen receipts and online/offline presence update correctly.
- The application builds as a signed Android APK.
- Documentation and README are complete.