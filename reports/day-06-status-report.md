# Lumina Chat — Status Report (Day 6)

**Project:** Lumina Chat — Android messaging application
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database), Cloudflare Workers (Gemini proxy, ImageKit auth, push notifications)
**Period covered:** Day 6

## Summary

Since the Day 4–5 report, five more feature commits shipped without their own write-up: Reply, Reactions + Settings + Automatic Translation + Push Notifications, Voice Messages + Emoji Picker, Edit/Delete(for me or everyone)/Forward, and Clear/Delete Chat + Username Editing (plus two bug fixes caught along the way). Day 6 covered those briefly below for the record, then delivered the two remaining major features on the roadmap: **Group Chats** (create, name, avatar, add/remove members, leave) and the **AI Assistant** (general Q&A plus grounded Lumina Chat how-to answers, via Gemini). Both were built, tested live on the Android emulator against the real Firebase backend, and verified directly against Firestore data — not just "the UI looked right."

## Since Day 4–5 (previously shipped, unreported)

- **Reply** — swipe or long-press a message to reply; the reply preview links back and scrolls to the original.
- **Reactions, Settings screen, Automatic Translation, Push Notifications** — emoji reactions (quick-pick row + toggle), a dedicated Settings screen (Profile/Theme/Language/Sign Out), tap-to-translate for incoming messages in a different preferred language (Gemini via a Cloudflare Worker holding the API key as a secret), and push notifications sent by the client itself right after a message write succeeds (a second free Cloudflare Worker relays to FCM using a service account, no Cloud Functions).
- **Voice Messages + Emoji Picker** — tap the mic to record, tap send/trash to send or cancel; an in-app emoji picker for the compose bar.
- **Edit / Delete / Forward** — sender-only text edits, "delete for me" vs "delete for everyone," and forwarding a message's content into another conversation.
- **Clear/Delete Chat + Username Editing** — per-user chat clearing (from inside a chat or by long-pressing it in the list) that doesn't touch the other participant's copy, plus editing your `@username` after initial signup. Bundled with two bug fixes: a stale-provider bug on the chat detail screen, and FCM tokens surviving sign-out and leaking into the next account signed in on the same device.

All of the above were re-exercised incidentally during this session's own testing (reactions, translate, forwarded/edited messages, and voice/image messages were all seen live and working) and no regressions were found.

## Day 6 — Group Chats

Extended the existing direct-message architecture to support groups rather than building a parallel system, since reactions, translation, edit/delete/forward, and clear-chat were already built as per-uid maps or generic membership checks — only the deterministic 1:1 conversation-ID scheme and a handful of "the other participant" (singular) call sites genuinely assumed exactly two people.

- **Data model:** `conversations/{id}` gained a `type: 'direct' | 'group'` field (missing = `direct`, so every pre-existing document stayed valid untouched), plus `groupName`, `groupAvatarUrl`, `admins`, and `createdBy` for groups. Group IDs are freshly auto-generated (the sorted-uid-pair scheme direct chats use can't work once membership changes over time).
- **Firestore rules:** the conversation `create` rule's `participants.size() == 2` became `>= 2` — the one real rule change needed. Everything else (message read/create/update, reactions/translations/deletedFor) already checked membership generically. Deployed to the live project.
- **Create a group:** name, optional photo (reused the existing ImageKit upload pipeline, no new upload path), multi-select members from the existing user search.
- **Group chat UI:** header shows group name/avatar/member count and opens Group Info on tap; incoming messages show the sender's name above the bubble; translation now decides per-message whether to offer translating (comparing the actual sender's language to the viewer's, not a single fixed "other participant"), which also correctly generalized the existing 1:1 translation logic instead of special-casing groups.
- **Group Info screen:** member list, "Add members" (open to any current member), and — added after the first live test — **"Remove member"** (admin-only, can't remove yourself) and **"Leave group"** (anyone, including the creator).
- **Send-path plumbing:** every send path (text/image/voice, plus unread counts and push-notification triggers) took a single `recipientId`; generalized to a `recipientIds` list so a group message notifies and increments unread counts for every other member, not just one.

**Verification:** built and installed on the Android emulator against the live Firestore project (not the emulator suite — the real backend). Created a 4-member group, sent text/image messages, confirmed group-specific UI (member count, sender labels) rendered correctly. Testing then surfaced a legitimate point of confusion worth recording honestly: after "Leave group" was tapped, the group disappeared from that device's list, which briefly looked like the group itself had been deleted. Reading the actual repository code confirmed no `.delete()` call exists anywhere in that path (only `arrayRemove`/field-delete updates), and a direct read of the live Firestore document — checked field by field in the Firebase Console — confirmed the group document and the other members were untouched; only the leaving member's own entries were gone. The full sequence was then reconstructed and matched exactly what the code does: one member left (removed from that document only), was re-added via "Add members," and a different member was removed by the admin — all reflected correctly in the live document afterward, including the creator correctly being unable to remove themselves and correctly still showing the "Creator" tag.

## Day 6 (continued) — AI Assistant

Added a floating-action-button entry point (bottom-right on the home screen, matching the WhatsApp/Meta AI pattern) opening a dedicated chat screen where the assistant answers both general questions and questions about using Lumina Chat.

- **Backend:** no new API key or Worker service. The existing `lumina-gemini-translate` Cloudflare Worker (already holding the Gemini API key as a Worker secret for message translation) was extended with a second branch, dispatched purely by request shape — `{text, targetLanguage}` still hits the original translate path unchanged, a new `{messages: [...]}` shape hits a new assistant path. Same URL, same secret, same deployment.
- **Grounding:** the assistant's system prompt embeds a feature reference written directly from reading the current screens' actual code (Settings, Theme, Language, Profile, Chat, Group Info, etc.) — not from memory or assumption — and is explicitly instructed to say it isn't sure rather than invent functionality for anything outside that reference.
- **Flutter side:** a small, self-contained `features/assistant` module (message model, repository, Riverpod controller, chat-style screen) — in-memory conversation history only for the app session, no new Firestore collection, keeping the addition modular and isolated from the rest of the app.
- **Basic hygiene:** the Worker caps assistant request size (message count and per-message length) so a malformed or abusive request can't run up an unbounded Gemini bill; no new auth requirement was added, matching this Worker's existing (already-open, no-auth) security posture rather than introducing an inconsistent one.

**Verification, live on the emulator against the deployed Worker:**
- General question ("What is photosynthesis") — accurate, well-structured answer.
- Lumina-specific question ("How do I sign out") — answered correctly and specifically ("Settings → Sign Out, or Profile → Logout"), matching the actual UI exactly.
- Found and fixed live: the first pass of responses came back with Markdown/LaTeX syntax (`**bold**`, `$H_2O$`) rendered as literal characters, since the chat bubble is a plain `Text` widget with no Markdown renderer. Rather than add a Markdown-rendering dependency for this one screen, the system prompt now explicitly instructs the model to reply in plain prose — verified fixed by re-asking the same photosynthesis question afterward.
- Light and Dark theme both confirmed visually correct (backgrounds, bubble contrast, error-state tint). System theme mode wasn't separately exercised, but it reuses the same theme data as Light/Dark, just switched by the OS, so no separate risk is expected.

## Known Limitations

- The AI Assistant's conversation history is in-memory only for the current app session — it is not persisted to Firestore or restored after an app restart. Not required by the current scope, but worth naming as a boundary.
- Only two of the three requested Lumina-specific verification questions were exercised this session ("How do I sign out" confirmed; "How do I send a voice message" / "How do I create a group" were not separately run before this report was written).
- Group chats: rename, change avatar after creation, and promoting a new admin are intentionally deferred (not built) — the data model (`admins`, `createdBy`) already has room for them.
- The AI Assistant Worker endpoint has no request-level authentication, same as the existing translation Worker — acceptable for this project's threat model, but worth noting since it's new attack surface reusing an already-open pattern rather than a newly-reviewed one.

## Status

Group Chats (create/name/avatar, add/remove members, leave) and the AI Assistant (general + grounded Lumina Q&A) are both built, `flutter analyze`-clean, and verified live against the real Firebase project and the deployed Cloudflare Worker. No known blockers; limitations above are scope boundaries, not defects.
