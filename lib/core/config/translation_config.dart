/// Gemini's API key can't live in the Flutter app, so translation requests
/// go through a small, free Cloudflare Worker (see
/// /cloudflare-worker/gemini-translate-worker.js) that holds the key as a
/// Worker secret and proxies the actual Gemini call — same reasoning and
/// shape as [imageKitAuthEndpoint] in imagekit_config.dart.
///
/// This URL assumes the Worker is named exactly `lumina-gemini-translate`
/// under the same Cloudflare account as the ImageKit Worker (same
/// `*.workers.dev` subdomain) — update this constant if Cloudflare assigns
/// a different one once the Worker is actually deployed.
const geminiTranslateEndpoint =
    'https://lumina-gemini-translate.mhmd2004shkeir.workers.dev';
