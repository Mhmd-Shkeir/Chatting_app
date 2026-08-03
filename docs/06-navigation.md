# Navigation Flow

## Navigation System

The application uses GoRouter for navigation.

Protected routes require an authenticated user.

---

# Route Structure

Splash

↓

Login

↓

Register

↓

Home

↓

Chat

↓

Profile

↓

Settings

---

# Public Routes

/

Splash Screen

/login

Login Screen

/register

Register Screen

---

# Protected Routes

/home

Conversation List

/chat/:conversationId

Individual Chat

/profile

User Profile

/settings

Application Settings

---

# Authentication Flow

Application Launch

↓

Splash Screen

↓

Check Authentication

↓

Authenticated?

├── YES → Home
└── NO → Login

---

# Login Flow

Login

↓

Firebase Authentication

↓

Profile Exists?

├── YES → Home
└── NO → Create Profile

---

# Registration Flow

Register

↓

Firebase Authentication

↓

Create User Document

↓

Home

---

# Chat Flow

Home

↓

Select Conversation

↓

Open Chat

↓

Send / Receive Messages

↓

Back to Home

---

# Search Flow

Home

↓

Search Users

↓

Select User

↓

Create Conversation

↓

Open Chat

---

# Notification Flow

Push Notification

↓

Tap Notification

↓

Open Application

↓

Navigate to Chat

---

# Logout Flow

Settings

↓

Logout

↓

Firebase Sign Out

↓

Login Screen

---

# Navigation Principles

- Authentication guards
- Deep-link support
- Predictable back navigation
- No duplicated routes
- Minimal navigation stack