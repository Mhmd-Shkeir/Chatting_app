# Lumina Chat — Status Report (Day 4–5)

**Project:** Lumina Chat — Android messaging application
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database)
**Period covered:** Day 4–5

## Summary

Day 4 delivered email verification, but getting it fully correct took much longer than expected — two subtle, hard-to-reproduce bugs surfaced during testing and needed real investigation, not just quick patches. Day 5 added self-service account deletion to the Profile screen and turned into an extended bug-fixing pass: because Firebase's free tier gives no way to make a multi-step deletion atomic, real time was spent finding and closing every way that process could be interrupted and leave the app in an inconsistent state. A second, more serious deletion bug then surfaced from real-world-speed testing after that work shipped, and was fixed the same day. Day 5 continued on into Profile Pictures and Image Messages — both built, both switched mid-stream from the originally planned storage provider to a different one for a real-world access reason (below), and both verified live against the actual backend, not just visually. One known issue (image messages not failing fast enough with no internet) was found late and is still open — documented honestly at the bottom rather than glossed over.

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

## Day 5 (continued) — A Second Deletion Bug, Found by Real-World Testing

- The account-deletion work above was tested carefully but deliberately, one step at a time. Testing it again afterward at normal, real-world speed — delete an account, then immediately register a new one and start using it — surfaced a second, more serious bug the careful testing hadn't hit.
- Root cause: the same automatic recovery check that finishes an interrupted deletion could, in a narrow timing window, mistake a brand new, completely unrelated account that had just signed in on the same device for the one that was being deleted, and delete *that* account instead — confirmed live by watching a real second test account actually disappear this way.
- Fixed by making that recovery check verify whose account is actually signed in at the exact moment it's about to act, refusing to do anything at all if it's no longer the account it was meant for. Verified fixed by deliberately reproducing the original fast-paced sequence again and confirming both accounts survived correctly this time.

## Day 5 (continued) — Profile Pictures

- Users can now set a profile picture from the camera or gallery, shown everywhere another person's identity appears: their own profile, search results, the conversation list, and — newly added — the chat header, which previously had no picture at all.
- The original plan was Cloudinary for image storage (Firebase's own storage requires upgrading to a paid plan). Cloudinary's signup turned out to be blocked in the project owner's country, so this pivoted to **ImageKit** instead, paired with a small, free Cloudflare Worker to handle the one piece ImageKit requires that Cloudinary didn't: a secure signature generated with a private key that must never be embedded in the app itself. Both services stay on their free tiers, no card on file for either.
- Removing a photo correctly falls back to the existing colored-initial avatar everywhere, and a deleted account's photo correctly disappears the same way, automatically, with no special-case code needed for that combination.
- Verified live end-to-end: uploaded from one account, confirmed it appeared instantly on that account's own profile and, separately, on another real account's search results, conversation list, and chat header.

## Day 5 (continued) — Image Messages

- Users can now send pictures inside a chat, not just set a profile picture. Reuses the same ImageKit pipeline; sending shows the picture immediately with a loading indicator while it uploads, resolves to the real image for both people once it's done, and can be tapped to view full-screen with pinch-to-zoom.
- Images are automatically compressed before upload (capped to a reasonable size and quality) so a full-size 12–20MB camera photo is never sent as-is, and each upload gets a clean, organized name on ImageKit's side tied to which conversation it came from, instead of the device's own generic filename.
- Verified against the real backend directly, not just by looking at the screen: confirmed the message data, the image's naming pattern, and the conversation preview text all saved correctly, and that the uploaded image is genuinely live and publicly viewable.

## Known Issue — Not Yet Resolved

- Real-world testing (deliberately turning off Wi-Fi mid-send) found that sending an image with no internet connection can leave it spinning indefinitely instead of failing within a reasonable time and offering a retry. A first attempted fix didn't fully resolve it and was deliberately rolled back rather than shipped half-working — this is being investigated further before being reattempted. Sending with a normal connection is unaffected.

## Later Today / Next Up (planned)

- Resolve the offline image-send issue above
- Voice messages and automatic message translation, next on the roadmap
- Push notifications and a final polish pass remain scoped for after that

## Status

Email Verification, Delete Account, Profile Pictures, and Image Messages are all built and verified against real accounts and the real backend. One known issue (above) remains open in Image Messages' offline handling. Everything else has no known blockers.
