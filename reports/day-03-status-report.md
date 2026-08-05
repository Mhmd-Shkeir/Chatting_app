# Lumina Chat — Status Report (Day 3)

**Project:** Lumina Chat — Android messaging application
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database)
**Period covered:** Day 3

## Summary

Day 3 focused on presence and read receipts — the details that make a messaging app feel finished rather than just functional. Online/offline status and "last seen" are complete and verified live; read receipts are also complete and verified live. Two real bugs were caught and fixed during testing, and one build-performance issue (non-blocking) was diagnosed.

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

## Read Receipts — Complete

- Three-state message status, WhatsApp-style: sent (single gray check) → delivered (double gray check) → read (double blue check)
- "Delivered" fires the moment the recipient's device observes the conversation update, piggybacked on the conversations stream that's already running for the whole session — no extra background listener needed
- "Read" fires only when the recipient actually opens that specific chat
- The permission rule (recipient may update only the status field, never the sender) was drafted earlier and has now been deployed
- The Firestore schema doc was updated to reflect the delivered state, which an earlier version of the doc had explicitly ruled out for v1 — updated deliberately once the spec required it
- Verified live: status correctly transitions to double blue on opening the chat, with "last seen" still correct alongside it

## Build Performance — Diagnosed, Not Blocking

A recurring slow build (several minutes instead of seconds) was traced to a mismatch between where the project lives and where Flutter's package cache lives on this machine — a local environment detail, not a bug in our code. It does not affect the app's correctness (every feature tested has worked correctly regardless), only how long some builds take. A fix is scoped and ready, pending a decision on whether to apply it now or later.

## Status

Presence & Last Seen and Read Receipts are both complete, verified, and committed. Unread Badge re-verification (untouched by Read Receipts as far as we know, but not yet re-checked) is the last item before Phase 4 closes. No blockers.
