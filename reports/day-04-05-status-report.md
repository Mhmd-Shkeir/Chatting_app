# Lumina Chat — Status Report (Day 4–5)

**Project:** Lumina Chat — Android messaging application
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database)
**Period covered:** Day 4–5

## Summary

Day 4 delivered email verification, but getting it fully correct took much longer than expected — two subtle, hard-to-reproduce bugs surfaced during testing and needed real investigation, not just quick patches. Day 5 added self-service account deletion to the Profile screen and turned into an extended bug-fixing pass: because Firebase's free tier gives no way to make a multi-step deletion atomic, real time was spent finding and closing every way that process could be interrupted and leave the app in an inconsistent state. Both features are complete and verified live with real accounts.

## Day 4 — Email Verification (harder than it looked)

- Registration now sends a verification email, with a dedicated "Verify your email" screen (resend link, manual "I've verified" check, and a logout option) gating access to the rest of the app until it's confirmed
- Two real bugs made this take significantly longer than planned:
  1. Checking whether the email had been verified didn't reliably work while the app was running — the on-device check kept reporting "not verified" no matter how many times it was refreshed, even though the server already had the correct value (only a full app restart ever picked it up correctly). Traced to using the wrong Firebase API for this check; switching to the correct one (a live update stream instead of a manual refresh-and-reread) fixed it for good.
  2. A more serious issue: the automatic logic that decides which screen to show the user could, under certain conditions, trigger a sign-out several times in a very short burst. This corrupted the session badly enough that every login attempt afterward failed until the app was fully restarted — a scary thing to hit mid-testing, since it looked like login itself was broken. The root cause was a live action (signing out) being triggered from inside a routing-decision function that the navigation framework can call multiple times while resolving a single screen change. Fixed by moving that action out to a separate mechanism that only ever fires once per real change, keeping the routing logic itself passive.
- Status: complete, tested, and committed.

## Day 5 — Delete Account + Extended Bug-Fixing Pass

- Built self-service account deletion in the Profile screen: the user confirms their password, then the app removes their name, email, photo, and bio, marks the account permanently deleted, strips their online status, permanently reserves their username so nobody can ever claim it again, and finally deletes their actual sign-in credentials — while leaving their past conversations intact, showing the other person "Deleted Account" instead of a broken reference.
- Firebase's free tier has no way to make all of those steps happen as one all-or-nothing operation, so a real chunk of Day 5 went into deliberately trying to break this process — killing the app mid-deletion, simulating failures at each step — and closing every gap found:
  - A failed cleanup step could block the real deletion from ever running
  - A leftover background listener could make a deleted account look "online" again right after deletion
  - Nothing existed to recover if the app was closed at exactly the wrong moment mid-deletion
  - The confirmation dialog closed instantly regardless of whether deletion actually succeeded, so a failed attempt looked identical to a successful one
  - A timing gap in how the database confirms writes could lose the deletion record entirely in rare cases
  - The most serious issue, found only through careful step-by-step tracing: a background safety check was reacting to the very first, not-yet-confirmed step of the deletion process and signing the user out before the real account deletion had actually run — meaning the visible result looked successful, but the underlying account was quietly left behind, not actually deleted.
- All of the above are fixed. The deletion process now shares one single, careful "finishing" routine between a normal deletion and an automatic recovery check that completes any interrupted deletion the next time the app is opened — so there is no longer a scenario where the process can be left stuck halfway.
- Verified live, end-to-end, with two real test accounts on the emulator: after deletion, signing back in with the same email and password is correctly rejected (proving the account is genuinely gone, not just signed out), and the other person's chat correctly shows "Deleted Account" with no online status, while every earlier message in the conversation stayed intact and readable.

## Later Today (planned)

- Another design pass on the chat and home screens, next on the existing roadmap
- Push notifications, media sharing (Cloudinary), and a final polish pass remain scoped for after that

## Status

Email Verification and Delete Account are both complete, verified, and ready to commit. No blockers.
