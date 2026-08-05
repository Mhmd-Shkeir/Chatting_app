# Lumina Chat — Status Report (Day 3)

**Project:** Lumina Chat — Android messaging application
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database)
**Period covered:** Day 3

## Summary

Day 3 focused on presence and read receipts — the details that make a messaging app feel finished rather than just functional. Online/offline status and "last seen" are complete and verified live; read receipts are in progress. Two real bugs were caught and fixed during testing, and one build-performance issue (non-blocking) was diagnosed.

## Presence & Last Seen — Complete

- New Firebase Realtime Database instance created and secured, separate from Firestore, purpose-built for presence (an industry-standard split, not something we do differently for style)
- Online/offline status updates automatically the instant a device disconnects (app closed, network lost) — the server detects this, not the client, so it can't be missed or spoofed
- "Last seen" timestamp shown when a contact isn't currently online
- Shown live in two places: the chat screen header ("Online" / "Last seen 5m ago") and a status dot on each conversation in the list
- Verified live: real login/logout with a real account, plus a simulated second device confirmed the on-screen status updates instantly with no manual refresh — the same rigor used to verify messaging on Day 2

## Bugs Found and Fixed

Two real issues were caught during hands-on testing — not theoretical, actually reproduced and fixed:

1. A conflict between Firebase's automatic startup configuration and our own could crash the app on launch under specific conditions. Fixed with the standard, documented handling for this exact case.
2. Logging out wasn't correctly recording a user as offline — a timing issue where the "go offline" signal was being sent a moment too late to be accepted. Fixed by reordering so it happens at the right moment.

## In Progress: Read Receipts

Message status (sent → read) was already modeled in the data layer on Day 2; the permission rule allowing a recipient to mark a message read is drafted but not yet deployed or built into the app. Continuing next session.

## Build Performance — Diagnosed, Not Blocking

A recurring slow build (several minutes instead of seconds) was traced to a mismatch between where the project lives and where Flutter's package cache lives on this machine — a local environment detail, not a bug in our code. It does not affect the app's correctness (every feature tested has worked correctly regardless), only how long some builds take. A fix is scoped and ready, pending a decision on whether to apply it now or later.

## Status

Presence and Last Seen are complete, verified, and committed. Read Receipts and Unread Badge verification are the next two items. No blockers.
