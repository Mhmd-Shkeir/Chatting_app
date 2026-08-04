# System Architecture

## Overview

The application follows a feature-first architecture combined with the Repository Pattern.

The primary goals are:

- Scalability
- Maintainability
- Separation of concerns
- Testability
- Clean code
- Easy future maintenance

Firebase is treated as an infrastructure dependency, not part of the UI.

The presentation layer never communicates directly with Firebase.

---

# High-Level Architecture

```
Flutter UI
      │
      ▼
Riverpod Providers
      │
      ▼
Repositories
      │
      ▼
Firebase Services
      │
      ▼
Firebase Backend
```

Each layer has a single responsibility.

---

# Architecture Layers

## 1. Presentation Layer

Responsible for:

- Screens
- Widgets
- User interactions
- Navigation
- UI state

Presentation communicates only with Riverpod providers.

It never communicates directly with Firebase.

---

## 2. State Management Layer

Riverpod manages:

- Authentication state
- Chat state
- Conversation state
- Loading state
- Error state
- Theme state

Providers communicate with repositories.

Providers should not contain Firebase logic.

---

## 3. Repository Layer

Repositories are the bridge between the application and Firebase.

Responsibilities:

- Authentication
- Reading data
- Writing data
- Uploading images
- Updating conversations
- Updating message status

Example

```
Chat Screen

↓

Chat Provider

↓

Chat Repository

↓

Firebase
```

If the backend changes in the future, repository implementations can change without affecting the UI.

---

## 4. Infrastructure Layer

Infrastructure consists of:

- Firebase Authentication
- Cloud Firestore
- Firebase Realtime Database (Presence is part of the MVP, so this is active infrastructure, not optional)

Firebase Storage, Firebase Cloud Messaging, and Cloud Functions are not part of the MVP — see Post-MVP (v1.1) below.

---

# Folder Structure

```
lib/

├── app/
│   ├── app.dart
│   ├── router.dart
│   └── bootstrap.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── services/
│   ├── theme/
│   ├── utils/
│   └── widgets/
│
├── features/
│
│   ├── authentication/
│   ├── chat/
│   ├── conversations/
│   ├── notifications/
│   ├── profile/
│   ├── search/
│   └── settings/
│
└── main.dart
```

---

# Feature Structure

Each feature follows the same structure.

Example

```
chat/

├── data/
│   ├── models/
│   ├── repositories/
│   └── services/ (only if needed)
│
└── presentation/
    ├── providers/
    ├── screens/
    └── widgets/
```

## data

Contains

- Models
- Repository implementations
- Firebase access
- Data mapping

## presentation

Contains

- Screens
- Widgets
- Riverpod providers
- Controllers (only if needed)

This project intentionally avoids a separate Domain layer to keep the architecture simple while preserving a clean Repository Pattern.

---

# Dependency Direction

Allowed

```
Presentation

↓

Repository

↓

Firebase
```

Not Allowed

```
Presentation

↓

Firebase
```

The UI should never know where data comes from.

---

# State Management

Riverpod is the only state management solution.

Do not introduce

- Provider
- Bloc
- GetX
- GetIt

Riverpod manages

- Authentication
- Conversations
- Chat
- Search
- Notifications
- Theme

---

# Navigation

GoRouter manages navigation.

Public Routes

- Splash
- Login
- Register

Protected Routes

- Home
- Chat
- Profile
- Settings

---

# Error Handling

Every asynchronous operation should handle

- Loading
- Success
- Empty
- Offline
- Error

Errors should never crash the application.

---

# Firebase Responsibilities

## Firebase Authentication

Responsible for

- Register
- Login
- Logout
- Current User
- Session persistence

---

## Cloud Firestore

Responsible for

- Users
- Conversations
- Messages
- Read status
- Metadata

---

## Realtime Database

Responsible for

- Online status
- Last seen
- Presence

Firestore has no `onDisconnect` equivalent, which is why presence uses Realtime Database instead of Firestore.

---

## Post-MVP (v1.1) — Not active infrastructure

These are documented for continuity only. Nothing below is implemented, configured, or depended on during the MVP.

### Firebase Storage

Would be responsible for profile pictures and chat images. Requires the Blaze plan — out of reach while the project stays on Spark.

### Firebase Cloud Messaging / Cloud Functions

Push notifications move to a separate, self-hosted Node.js + Express service using the Firebase Admin SDK instead of a Cloud Function, specifically to avoid requiring Blaze. See `08-roadmap.md` for the architecture diagram. The `firebase_messaging` client package is already installed (added during Phase 2's dependency setup) but is not wired into any provider or screen yet — it stays dormant until this phase.

---

# Data Flow

Sending a message

```
User

↓

Chat Screen

↓

Chat Provider

↓

Chat Repository

↓

Firebase

↓

Stream Update

↓

Provider

↓

UI Refresh
```

---

# Coding Standards

- Feature-first architecture
- Repository Pattern
- Small reusable widgets
- Strong typing
- Immutable models
- Single Responsibility Principle
- No duplicated logic
- Consistent naming

---

# Naming Conventions

Files

snake_case

Classes

PascalCase

Variables

camelCase

Providers

featureProvider

Repositories

FeatureRepository

Models

FeatureModel

Firestore Collections

lowercase

---

# Performance Guidelines

- Paginate messages
- Cache images
- Avoid unnecessary rebuilds
- Use lazy lists
- Minimize Firestore reads

---

# Security Principles

- Never trust the client
- Firebase Security Rules are mandatory
- UI validation is not security
- Never expose secrets
- Restrict Firestore and Storage access properly

---

# Future Scalability

The architecture should support replacing Firebase with another backend in the future while minimizing changes to the presentation layer.

---

# Definition of Done

A feature is complete only if

- Implementation is complete
- UI is responsive
- Loading state exists
- Error handling exists
- Empty state exists
- Manual testing passes
- Architecture rules are respected
- No unnecessary rebuilds occur