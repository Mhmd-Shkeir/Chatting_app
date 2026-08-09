# Lumina Chat — Status Report (Day 8)

**Project:** Lumina Chat — Android messaging application
**Stack:** Flutter, Riverpod, GoRouter, Firebase (Authentication, Cloud Firestore, Realtime Database), Cloudflare Workers (Gemini proxy, ImageKit auth, push notifications), `cryptography` + `flutter_secure_storage`
**Period covered:** Day 8

## Summary

With v1.0 shipped and out for testing, Day 8 picked four items off the "What's Next" list from the Day 7 report — Google Sign-In, typing indicators, @mentions, and a Basic E2EE MVP — and delivered them in steps, each verified live against the real Firebase project before moving to the next. All four are built, tested on two real devices/accounts, `flutter analyze` clean, and ready to commit.

## Google Sign-In

Added `google_sign_in` (v7.2.0, the new singleton `GoogleSignIn.instance` API) alongside the existing email/password flow. First-time sign-in creates the same Firestore user document as email registration. Logout now also signs out of the Google session.

- **Bug found and fixed**: the new-user Firestore write used `user.photoUrl`, which doesn't exist on Firebase Auth's `User` object — the correct field is `photoURL` (capital URL). Caught by `flutter analyze`, fixed immediately.
- Verified live: signed in with a Google account on a real device, confirmed the Firestore user doc was created correctly and login/logout round-tripped cleanly.

## Typing Indicators

Realtime Database-backed, since Firestore writes are too expensive for something this high-frequency.

- **Bug found and fixed (permissions)**: the RTDB rule only granted `.read` at `typing/$conversationId/$uid`, but the app reads the parent path `typing/$conversationId` (the whole map) to see who's typing. RTDB rules don't cascade read access from a child rule to its parent, so this silently permission-denied and the indicator just never showed anything, with no visible error. Fixed by moving `.read` to the `$conversationId` level.
- **Bug found and fixed (stuck indicator)**: after the permissions fix, the indicator worked but never cleared once the other person stopped typing. Rather than rely on an explicit (and unawaited-write-race-prone) "stopped typing" signal, switched the write from a boolean to `ServerValue.timestamp` and added a client-side 1-second ticker that re-evaluates staleness (6-second cutoff) on every rebuild — the indicator is now self-healing regardless of whether a clean "stopped" signal ever arrives.
- Verified live between two real accounts on two devices.

## @Mentions

`@name` autocomplete when composing in a group chat, highlighted rendering in the bubble, and a per-user unread-mention flag denormalized onto the conversation document for a badge on the conversation list.

- **Bug found and fixed (badge layout)**: the mention badge was stacked above the existing numeric unread badge in a `Column`, overflowing the `ListTile`'s trailing area by 11px. Fixed by switching to a side-by-side `Row`.
- **Bug found and fixed (highlighting missing under translation)**: mentions rendered correctly in the bubble's default text path, but a message that also needed translation used a separate `_TranslatableText` widget with its own `Text()` render, which never got the mention-highlighting treatment. Fixed by threading the mention names/color through to that widget's "original text" branch.
- Verified live: mention triggers autocomplete correctly, highlights render (including on translated messages after the fix), and the conversation-list badge appears/clears correctly.

## Basic E2EE MVP

Scoped deliberately narrow, per explicit direction: 1:1 text messages only, opt-in per conversation, using an established protocol rather than inventing one.

**Design:** X25519 (ECDH) for key exchange + AES-256-GCM for authenticated encryption, via the `cryptography` package. Each device generates its own key pair on first use; the private key lives only in `flutter_secure_storage` (Android Keystore-backed) and never leaves the device. Only the public key is published to the user's own Firestore document. A message is encrypted client-side before the Firestore write and decrypted client-side on read — Firestore only ever stores ciphertext for these messages.

**What's covered while encryption is on:** reply, edit, delete, reactions, and read/delivery receipts all continue to work on encrypted messages. Forward is disabled for encrypted messages (ciphertext from one conversation's shared secret is meaningless in another). Translation is unavailable for encrypted messages, and push notifications/list previews show a generic "New encrypted message" rather than real content — both are intentional, not oversights, so no plaintext ever reaches the server.

**Verification, live against two real accounts:**
1. Enabled encryption on a 1:1 chat via the overflow menu; the 🔒 lock icon appeared in the header as expected.
2. Sent a message; confirmed in the Firebase Console that the message document's `text` field is genuine ciphertext (`nonce.mac.cipherText`, base64, dot-joined) — e.g. `N9s+lE4o/hYhnRW9.A+C2cLLvFq3OetDvDtazUg==.0w=...` — with `encrypted: true` and the conversation doc's `lastMessage` showing the generic placeholder, never the real text.
3. Confirmed `status: "read"` still updates correctly on encrypted messages.
4. Confirmed the recipient's device decrypts and displays the message as normal readable text.

**Explicitly not in scope for this MVP** (per the original ask, and documented in the README): forward secrecy, key rotation, multi-device support, key-verification UI, or group encryption. Without key verification, this protects against a passive server reading message content — it does **not** protect against a sophisticated active man-in-the-middle at the key-exchange step. Full detail in the README's [Security: Basic E2EE MVP](../README.md#security-basic-e2ee-mvp) section.

## Build Environment Bug: Android SDK Platform "37"

Adding `flutter_secure_storage` (initially resolved to v11.0.0) broke local Android builds with `Failed to find Platform SDK with path: platforms;android-37`, on both the user's laptop and a second machine.

- Root cause: `flutter_secure_storage` 11.0.0's own Android Gradle module hardcodes `compileSdk = 37` — unrelated to the app's own `compileSdk` (36, via `flutter.compileSdkVersion`). Gradle requires every module's declared compileSdk platform to be physically installed, so this one dependency's own pin forced the requirement.
- First attempted fix — installing the platform via `sdkmanager` — hit a second, more interesting snag: the Android SDK repository no longer publishes a package literally named `platforms;android-37`; only decimal-versioned variants exist (`platforms;android-37.0`, `37.1`, etc.), which install to a differently-named folder than the literal `android-37` path Gradle's plugin resolution actually looks for. Installing `37.0` did not resolve the error.
- Real fix: pinned `flutter_secure_storage` down to `10.3.1` in `pubspec.yaml` (last version before the `compileSdk = 37` bump, per the package changelog), which targets `compileSdk = 36` — already installed, no SDK changes needed. Confirmed via `flutter pub get` and a successful `flutter build apk --debug`.
- Also encountered a one-off transient Kotlin compile-daemon crash caused by running a Gradle build from this session's tooling and an Android Studio build concurrently against the same project — resolved by not running both at once, consistent with the resource-contention pattern already noted in Day 7.

## Verification Summary

| Area | Verified how |
|---|---|
| Google Sign-In | Live sign-in on a real device, Firestore user-doc creation confirmed |
| Typing indicators | Live between two real accounts/devices, including the staleness self-heal |
| @mentions | Live: autocomplete, highlighted rendering (plain and translated), conversation-list badge |
| E2EE — ciphertext in Firestore | Live: Firebase Console field inspection on a real sent message |
| E2EE — cross-device decryption | Live: recipient device displays correct plaintext |
| E2EE — read receipts survive encryption | Live: `status: "read"` confirmed updating |
| `flutter analyze` | Clean at every stage |
| Local Android build (post `flutter_secure_storage` downgrade) | `flutter build apk --debug` succeeded |

## Known Limitations

- Carried over from Day 7 (unchanged): stuck "sending" image state on lost connectivity; AI Assistant history is in-memory only; group rename/photo-change/admin-promotion still unbuilt; debug-key-signed APK.
- E2EE MVP limitations are by design, not oversights — see the dedicated section above and the README.
- `flutter_secure_storage` is pinned to `10.3.1` rather than the latest `^11.0.0` specifically to avoid the `compileSdk = 37` SDK-platform-availability issue; revisit this pin once the Android SDK ecosystem catches up with a stable `platforms;android-37` package.

## Status

Google Sign-In, typing indicators, @mentions, and a Basic E2EE MVP are complete and live-verified. Remaining post-v1.0 candidates (pinned messages, file/document sharing, voice/video calls, call history, voice transcription, advanced group administration, further AI Assistant capabilities) remain unscoped and unscheduled.
