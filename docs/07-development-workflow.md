# Development Workflow

## Development Philosophy

The project follows a review-first workflow.

Architecture is decided before implementation.

Implementation happens feature by feature.

---

# Team Roles

## ChatGPT

Acts as Technical Lead.

Responsibilities

- Architecture
- Firestore schema
- Security review
- Code review
- Performance review
- Debugging
- Interview preparation

---

## Claude

Acts as Senior Flutter Engineer.

Responsibilities

- Flutter implementation
- Firebase integration
- Widget creation
- Refactoring
- Tests

Claude must not modify the project architecture without approval.

---

## Developer

Responsibilities

- Run project
- Test features
- Approve implementations
- Git commits
- Final decisions

---

# Feature Workflow

1.

Define feature

↓

2.

Review architecture

↓

3.

Claude proposes affected files

↓

4.

Implementation

↓

5.

Manual testing

↓

6.

Code review

↓

7.

Merge

---

# Rules

Never implement multiple features together.

Never rewrite unrelated files.

Keep commits small.

Test after every feature.

Review every implementation before continuing.

---

# Code Standards

- Strong typing
- Immutable models
- Reusable widgets
- Repository Pattern
- Riverpod only
- Feature-first organization

---

# Git Strategy

Main branch

↓

Small commits

↓

Descriptive commit messages

Example

feat(auth): implement email login

fix(chat): correct timestamp ordering

refactor(profile): simplify provider