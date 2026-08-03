# Review Checklist — Lumina Chat

Run this against any implemented feature before marking it done, whether reviewing yourself, asking Claude, or asking ChatGPT.

## Scope

- [ ] Only the requested feature was implemented — nothing extra bundled in
- [ ] No unrelated files were rewritten or reformatted
- [ ] No architecture change without explicit prior approval
- [ ] No new dependency added without stated justification

## Architecture

- [ ] Feature-first folder placement is correct
- [ ] Repository pattern used for any Firebase access (no direct Firestore/Storage calls from widgets)
- [ ] State managed via Riverpod, not local setState for anything shared/async
- [ ] Models are immutable and typed (no raw `Map<String, dynamic>` leaking into UI code)
- [ ] Widgets are small, focused, and reusable where sensible

## Correctness

- [ ] Loading state handled
- [ ] Empty state handled
- [ ] Offline state handled
- [ ] Error state handled (and surfaced to the user, not just swallowed/logged)
- [ ] No invented Firebase APIs or packages — everything used actually exists in the declared stack

## Firebase-specific

- [ ] Firestore reads/writes match the frozen data model (no ad hoc schema drift)
- [ ] Security rules assumption respected — code doesn't rely on client-side trust
- [ ] Queries are indexed / won't silently fail in production (check for composite index requirements)
- [ ] Storage uploads scoped to the correct path/permissions

## Delivery

- [ ] Complete code returned only for files created or modified
- [ ] Affected files and data flow were explained before implementation
- [ ] Manual testing checklist included at the end
- [ ] Tested on two accounts/devices where the feature involves real-time sync

## Sign-off

- [ ] I ran it myself and it behaves as described, not just "looks right in the diff"




# Review Checklist

Before accepting a feature verify:

Architecture

- Repository Pattern respected
- Riverpod used correctly
- No Firebase inside UI

Code Quality

- No duplicated logic
- Good naming
- Strong typing
- Reusable widgets

UI

- Loading state
- Empty state
- Error state

Performance

- No unnecessary rebuilds
- Firestore reads minimized
- Images cached

Security

- Firebase rules respected
- No secrets exposed

Testing

- Manual tests completed
- Feature behaves correctly