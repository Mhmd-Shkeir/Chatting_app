/**
 * ImageKit upload-authentication Worker.
 *
 * ImageKit's client-side upload API requires a signature/token/expire
 * triple generated with the account's PRIVATE key for every upload — there
 * is no unsigned mode like Cloudinary's. That key can never live in the
 * Flutter app, so this one-purpose, free Cloudflare Worker holds it instead
 * (as a Worker secret, never in this file) and hands back a fresh
 * {token, expire, signature} on request. The Flutter app then uploads
 * straight to ImageKit itself with those values — this Worker never sees
 * or touches the actual image.
 *
 * Signature formula (verified against ImageKit's own SDK source):
 *   signature = hex(HMAC-SHA1(privateKey, token + expire))
 *
 * Deploy (Cloudflare dashboard, no local tooling needed):
 *   1. workers.cloudflare.com -> sign up free (no card required).
 *   2. Workers & Pages -> Create -> Create Worker -> give it a name -> Deploy.
 *   3. Edit code -> paste this whole file, replacing the default template -> Deploy.
 *   4. Worker -> Settings -> Variables and Secrets -> Add -> name it
 *      IMAGEKIT_PRIVATE_KEY, paste your ImageKit private key, type "Secret" -> Save.
 *   5. Copy the Worker's *.workers.dev URL into
 *      lib/core/config/imagekit_config.dart's imageKitAuthEndpoint.
 */
export default {
  async fetch(request, env) {
    if (request.method !== 'GET') {
      return new Response('Method not allowed', { status: 405 });
    }

    const token = crypto.randomUUID();
    const expire = Math.floor(Date.now() / 1000) + 1800; // 30 minutes, well under ImageKit's 1-hour max

    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(env.IMAGEKIT_PRIVATE_KEY),
      { name: 'HMAC', hash: 'SHA-1' },
      false,
      ['sign'],
    );
    const signatureBuffer = await crypto.subtle.sign(
      'HMAC',
      key,
      new TextEncoder().encode(token + expire),
    );
    const signature = [...new Uint8Array(signatureBuffer)]
      .map((byte) => byte.toString(16).padStart(2, '0'))
      .join('');

    return new Response(JSON.stringify({ token, expire, signature }), {
      headers: {
        'Content-Type': 'application/json',
        // Harmless for a native Flutter client (CORS is browser-enforced,
        // not applicable to mobile HTTP calls) — kept permissive here only
        // so a future web build or browser-based testing isn't blocked.
        'Access-Control-Allow-Origin': '*',
      },
    });
  },
};
