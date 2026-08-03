# Feature Prompt Template

Copy this template and fill it in for each individual feature request. One feature per prompt — do not bundle multiple features together.

---

## Feature

<!-- Short name, e.g. "Send text message" -->

## Goal

<!-- One or two sentences: what the user should be able to do after this feature lands. -->

## Context / Current State

<!-- What already exists that this feature builds on (e.g. "auth flow and user model already implemented"). -->

## Requirements

<!-- Bullet list of concrete behavior. Be specific about what's in scope. -->

-
-
-

## Explicitly Out of Scope

<!-- What NOT to touch or implement as part of this prompt, even if related. -->

-

## Expected Affected Files

<!-- Your best guess at which files/folders this should touch. Claude should confirm or correct this before writing code. -->

-

## Data / State Notes

<!-- Any Firestore/Storage/Riverpod state shape relevant to this feature, if known. -->

## Acceptance Criteria

<!-- How you'll know it's done and correct. -->

-
-

## Required States to Handle

- [ ] Loading
- [ ] Empty
- [ ] Offline
- [ ] Error

## Reminder to Claude

Before writing code: explain the affected files and data flow, and confirm the plan. Return complete code only for files created or modified. End with a manual testing checklist.



Implement ONLY the requested feature.

Before writing code:

1. Read the project documentation.
2. Explain the data flow.
3. List every affected file.
4. Explain why each file changes.

Wait for approval.

After approval:

- Generate complete code.
- Do not modify unrelated files.
- Follow the existing architecture.
- Finish with a testing checklist.