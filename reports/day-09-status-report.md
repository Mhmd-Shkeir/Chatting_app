# Lumina Chat — Status Report (Day 9)

**Project:** Lumina Chat — Android messaging application
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database), Cloudflare Workers (Gemini proxy, ImageKit auth, push notifications), `connectivity_plus`
**Period covered:** Day 9

## Summary

Day 9 closed out three group-chat gaps found in real use after Day 8, fixed a display-name bug affecting both direct chats and groups, and then investigated and fixed a real offline crash — which led into a broader pass on offline messaging behavior. Every fix here was live-verified against the real Firebase project and real devices, not just reasoned about.

## Group Chats — Three Fixes

**1. Read receipts only turn blue once *everyone* has read it.** Previously a message's `status` was a single shared value, flipped to `'read'` the moment any one other participant opened the chat — correct for a direct conversation (exactly one other participant) but wrong for a group, where the first reader shouldn't make it look like the whole group saw it. Added a per-recipient `readBy` map (uid → read timestamp), the same per-uid-map shape already used by `reactions`/`deletedFor`. The blue double-tick now requires every *current* group member (not the sender, and not anyone who's since left) to have their own key present — computed live off the conversation's actual participant list, so someone leaving the group correctly drops them from the requirement. Direct chats are unaffected: one recipient, same behavior as before.

**2. A "Groups" filter that always finds every group you're in.** Added an All / 👥 Groups chip row under the home screen's app bar. Selecting Groups shows every group conversation the user belongs to, via a new `ConversationRepository.streamAllGroups` that deliberately does *not* apply the "cleared" filter `streamConversations` uses for the main list.

**3. Clearing/deleting a group no longer makes it disappear.** This turned out to be almost entirely a discoverability bug, not a data bug — clearing a chat was always just a per-uid timestamp (`clearedFor.$uid`) that never touched the group document itself, and sending was never gated on it. The only real problem was that the *only* list in the app respected that per-uid clear, so a cleared group had nowhere left to show up until new activity arrived. Fix #2 above fixes this directly: the group now stays permanently visible under Groups, with its name/avatar/members untouched, and can be reopened and messaged immediately.

## Display Name Propagation Bug

Editing a display name from the Profile screen updated that user's own `users/{uid}` document correctly (this is also why the username system, which already read live per-uid data, was never affected), but several screens were reading a different, *frozen* copy instead: `participantNames`, a snapshot written once onto a conversation/group document at creation time and never updated afterward. GroupInfoScreen's member list already did this correctly (`profile?.displayName ?? fallbackName`, live lookup first); that same pattern was applied to the four places that didn't:

- The home screen's conversation list (direct-chat name)
- The chat screen's header title
- Group sender labels and reply attribution inside message bubbles
- The "Forward to" target picker

## The Offline Crash — Root Cause and Fix

**Reported symptom:** clearing/deleting a group chat while offline crashed with `type 'null' is not a subtype of type 'Timestamp' in type cast`, and the app stayed stuck (even after restarting) until connectivity returned.

**Root cause:** `clearChatForMe` writes `clearedFor.$uid: FieldValue.serverTimestamp()`. A field written with `FieldValue.serverTimestamp()` reads back as `null` in the local cache until the server actually acknowledges that specific write — normal any time the write is still offline/pending, not a rare race. `Conversation.fromFirestore`'s parsing did `(value as Timestamp).toDate()` on every entry in that map with no null check, so as long as the device stayed offline, every snapshot of that conversation kept crashing the same way — explaining both why it recovered instantly on a machine with internet and why it stayed stuck indefinitely on the phone. The same unsafe pattern existed in the brand-new `readBy` field from the read-receipts fix above.

**Fix:** a shared `timestampMapFrom()` helper (`lib/core/utils/firestore_timestamp_map.dart`) that skips any map entry whose value isn't a `Timestamp` yet, instead of crashing — the affected uid is just treated as "not set yet" until the real write syncs and the listener fires again. Used by both `clearedFor` and `readBy` parsing. `flutter analyze` confirmed no other unsafe `as Timestamp` casts exist anywhere else in the codebase (every other Timestamp field already used a nullable cast).

## Offline Messaging — Investigation and Fixes

Fixing the crash led into the broader ask: make the app usable offline, without rewriting the existing architecture.

**What was already correct, and didn't need new code:** Firestore's own client SDK already provides a durable, ordered, automatic offline write queue — a write made while offline still lands in the local cache and the message list immediately, is queued on disk (survives an app restart), and is sent to the server automatically, strictly in the order it was made, once connectivity returns. This is exactly what items 2 (ordered offline queue) and most of item 5 (offline clear/delete) in the ask were asking for — Firestore already does it, so no custom local queue was built.

**What was actually broken:** `ChatRepository.sendMessage()` (used by text, emoji, and replies) writes the message and the conversation's last-message preview together in one atomic `WriteBatch`. The Future returned by `WriteBatch.commit()` can hang indefinitely while offline — even though the batch's writes land in the local cache instantly — because the plugin's Future only resolves once the batch reaches the server. Since the compose bar's send button was disabled while its controller's state stayed `AsyncLoading`, and that state was awaiting the batch commit directly, the practical effect was: the first offline send appeared to work, and then the Send button stayed stuck disabled for every message after it. Single-document writes (used by image/voice pending messages, and by clear/delete) don't have this problem, which is why those already worked correctly offline.

**Fix:** `ChatRepository._commitBatch()` now wraps every `WriteBatch.commit()` call in the file with a 5-second timeout that treats a timeout as success rather than an error. This doesn't cancel the underlying write — it's already durably queued locally either way — it just stops the caller (and therefore the send button) from waiting on the network round-trip.

**Also added, for images/voice specifically** (the one message type that genuinely needs a live network call, since ImageKit upload is HTTP, not a Firestore write):
- `isOnlineProvider` (`connectivity_plus`) — a simple online/offline signal, seeded from an initial check so there's no loading flash.
- A small "No internet connection" banner shown on the home screen and inside a chat while offline.
- `SendImageMessageController`/`SendVoiceMessageController` now fail fast (skip straight to the existing failed/retry state) when already known offline, instead of waiting out the upload's own ~15s timeout.
- ChatScreen listens for the offline → online transition and automatically retries any failed image/voice message that still has its local file cached for the session — closing the "automatically resend once connectivity returns" gap without needing to persist a new queue of its own.

## Verification Summary

| Area | Verified how |
|---|---|
| Group read receipts (blue only when all have read) | Live, multi-account, cross-checked against `readBy` in the Firebase Console |
| Groups filter always finds a cleared group | Live: cleared a group, confirmed it stayed under Groups and reopened/sent immediately |
| Display name propagation | Live: edited a display name, confirmed it updated in the other account's conversation list, chat header, and group sender label |
| Offline crash (clear a group offline) | Live on the physical phone, offline: no crash, no stuck state |
| Offline text/emoji/reply sending | Live: disconnected, sent several messages, confirmed the send button stayed usable and messages queued and synced in order on reconnect |
| Offline image/voice sending | Live: disconnected, sent an image and a voice message, confirmed fast failure + automatic resend on reconnect |
| `flutter analyze` | Clean at every stage |

## Known Limitations

- A minor cosmetic lag was observed after an offline-queued image synced: its status briefly showed a single checkmark instead of the expected double before catching up. Not investigated further this session (time-boxed, functionally correct — the message did send and sync); worth a closer look in a future pass if it recurs.
- Carried over, unchanged: stuck "sending" state for images specifically without the offline handling above is now fixed, but the original Day 4–5 image-retry UX limitations otherwise stand; AI Assistant history is in-memory only; group rename/photo-change/admin-promotion remain unbuilt; debug-key-signed APK for sideloaded testing.

## Status

All three group-chat fixes, the display-name propagation fix, and the offline crash + offline-messaging pass are complete and live-verified. This closes out the last of the reported bugs from Day 8's post-release testing round.
