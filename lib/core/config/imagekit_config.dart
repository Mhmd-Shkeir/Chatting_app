/// ImageKit is used for user-uploaded images (profile pictures, later image
/// messages) instead of Firebase Storage, which now requires the paid Blaze
/// plan on any project created after Google's October 2024 policy change —
/// off the table for this project's free-tier-only constraint. Cloudinary
/// was the original choice but its signup is blocked in the project owner's
/// country.
///
/// Unlike Cloudinary's unsigned upload presets, ImageKit has no fully
/// unsigned client upload mode — every upload needs a signature/token/expire
/// triple generated with the account's PRIVATE key, which must never live in
/// this app. [imageKitAuthEndpoint] points at a small, free Cloudflare
/// Worker (see /cloudflare-worker/imagekit-auth-worker.js) that holds that
/// private key as a Worker secret and does only that one thing: hand back a
/// fresh {token, expire, signature} for this app to attach to its own
/// upload request straight to ImageKit. [imageKitPublicKey] is, like a
/// Cloudinary cloud name, meant to be public and embeddable.
const imageKitPublicKey = 'public_DAYIKux94ujAiUVrR8V47oyivLs=';

/// Not used by the upload flow itself (the upload response already returns
/// a full usable URL) — kept for later, once transformation URLs are needed
/// (e.g. resized chat-image thumbnails).
const imageKitUrlEndpoint = 'https://ik.imagekit.io/luminachat2026';

const imageKitAuthEndpoint = 'https://lumina-imagekit-auth.mhmd2004shkeir.workers.dev';
