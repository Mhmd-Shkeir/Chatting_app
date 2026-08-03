# Project Conventions

## Goal

Build a clean, production-oriented messaging application within five days.

Keep the project simple, consistent, and maintainable.

---

# Architecture

- Follow the existing architecture.
- Do not change folder structure without approval.
- Use the Repository Pattern.
- Use Riverpod only.
- Do not introduce additional architectures.

---

# File Organization

- One responsibility per file.
- Create reusable widgets only when they are used more than once.
- Keep widgets small and readable.
- Avoid unnecessary folders.

---

# Coding Style

- Use strong typing.
- Prefer immutable models.
- Use meaningful names.
- Avoid duplicated code.
- Write readable code before clever code.

---

# Dependencies

- Do not add new packages unless necessary.
- Explain why a new dependency is needed.
- Prefer official Flutter/Firebase packages.

---

# Firebase

- Never access Firebase directly from UI widgets.
- Always go through repositories.
- Follow the Firestore schema.
- Respect Firebase Security Rules.

---

# UI

- Material 3
- Original design
- Dark-first
- Smooth but subtle animations
- Consistent spacing and colors

---

# AI Rules

When implementing a feature:

1. Work only on the requested feature.
2. Do not modify unrelated files.
3. Explain affected files before coding.
4. Return complete code for modified files.
5. Finish with a manual testing checklist.

---

# Definition of Done

A feature is complete only if:

- It works.
- It follows the architecture.
- It handles loading and errors.
- It has been manually tested.