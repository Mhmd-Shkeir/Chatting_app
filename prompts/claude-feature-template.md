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

Before writing code: read the project documentation, explain the data flow, list every affected file and why it changes, and confirm the plan. Wait for approval before writing code. After approval, generate complete code only for files created or modified, do not touch unrelated files, follow the existing architecture, and finish with a manual testing checklist.