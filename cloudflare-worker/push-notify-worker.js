/**
 * Push-notification Worker.
 *
 * Sends an FCM push for a single new message. The Flutter app calls this
 * itself right after a message write succeeds (no polling, no Cloud
 * Functions, no persistent server) — near-instant, and free.
 *
 *   Flutter A --(writes message)--> Firestore
 *            \--(POST, Firebase ID token)--> this Worker --(FCM v1)--> FCM --> Flutter B
 *
 * This Worker never reads Firestore and never sees chat content beyond the
 * title/body the client already computed for the notification preview — it
 * only proves the caller is a real signed-in user (verifying their Firebase
 * ID token) and then relays the send to FCM using a service account it
 * holds as a secret. FCM credentials never touch the Flutter app.
 *
 * Deploy (Cloudflare dashboard, no local tooling needed):
 *   1. Workers & Pages -> Create -> Create Worker -> name it exactly
 *      "lumina-push-notify" (must match
 *      lib/core/config/notification_config.dart's pushNotifyEndpoint, or
 *      that constant needs updating to whatever URL Cloudflare assigns).
 *   2. Edit code -> paste this whole file, replacing the default template
 *      -> Deploy.
 *   3. Firebase Console -> Project settings -> Service accounts -> Generate
 *      new private key. This downloads a JSON file — do not put it in the
 *      Flutter app or commit it anywhere.
 *   4. Worker -> Settings -> Variables and Secrets -> Add -> name it
 *      FIREBASE_SERVICE_ACCOUNT_JSON, paste the ENTIRE contents of that
 *      JSON file as the value, type "Secret" -> Save.
 *   5. Copy the Worker's *.workers.dev URL into
 *      lib/core/config/notification_config.dart's pushNotifyEndpoint.
 */

// Module-scope caches: reused across requests hitting the same warm
// isolate, so a burst of sends doesn't re-fetch Google's public certs or
// re-mint an OAuth token (valid for an hour) every single time.
let cachedGoogleCerts = null; // { fetchedAt, keys: Map<kid, JsonWebKey> }
let cachedAccessToken = null; // { token, expiresAt }

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return new Response('Invalid JSON body', { status: 400 });
    }

    const { token, title, body: messageBody, conversationId, senderId, type } = body;
    if (!token || !title || !messageBody || !conversationId || !senderId) {
      return new Response('Missing required field', { status: 400 });
    }

    const authHeader = request.headers.get('Authorization') || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!idToken) {
      return new Response('Missing Authorization header', { status: 401 });
    }

    let serviceAccount;
    try {
      serviceAccount = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
    } catch {
      return new Response('Worker misconfigured: bad service account secret', { status: 500 });
    }

    let claims;
    try {
      claims = await verifyFirebaseIdToken(idToken, serviceAccount.project_id);
    } catch (error) {
      return new Response(`Invalid ID token: ${error.message}`, { status: 401 });
    }

    // Cheap tamper check: the claimed sender must be the token's own
    // subject — nobody can send a push "from" a different user.
    if (claims.sub !== senderId) {
      return new Response('senderId does not match ID token', { status: 403 });
    }

    let accessToken;
    try {
      accessToken = await getFcmAccessToken(serviceAccount);
    } catch (error) {
      return new Response(`Failed to authenticate with FCM: ${error.message}`, { status: 502 });
    }

    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body: messageBody },
            data: {
              conversationId,
              senderId,
              type: type || 'text',
            },
            android: { priority: 'high' },
          },
        }),
      },
    );

    if (!fcmResponse.ok) {
      const errorBody = await fcmResponse.text();
      return new Response(`FCM send failed: ${errorBody}`, { status: 502 });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
    });
  },
};

/** Verifies a Firebase Auth ID token's signature and standard claims against
 * Google's public certs, entirely with Web Crypto (no external libraries —
 * this file is pasted directly into the Cloudflare dashboard, no bundler).
 * Returns the decoded payload (in particular `.sub`, the uid) on success. */
async function verifyFirebaseIdToken(idToken, projectId) {
  const parts = idToken.split('.');
  if (parts.length !== 3) throw new Error('malformed token');
  const [headerB64, payloadB64, signatureB64] = parts;

  const header = JSON.parse(base64UrlDecodeToString(headerB64));
  const payload = JSON.parse(base64UrlDecodeToString(payloadB64));

  if (header.alg !== 'RS256') throw new Error('unexpected alg');

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp <= now) throw new Error('token expired');
  if (payload.iat > now + 60) throw new Error('token issued in the future');
  if (payload.aud !== projectId) throw new Error('aud mismatch');
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new Error('iss mismatch');
  }
  if (!payload.sub) throw new Error('missing sub');

  const jwk = await getGoogleCertJwk(header.kid);
  const publicKey = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  const signedData = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = base64UrlDecode(signatureB64);
  const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', publicKey, signature, signedData);
  if (!valid) throw new Error('bad signature');

  return payload;
}

async function getGoogleCertJwk(kid) {
  const isStale = !cachedGoogleCerts || Date.now() - cachedGoogleCerts.fetchedAt > 60 * 60 * 1000;
  if (isStale) {
    const response = await fetch(
      'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
    );
    if (!response.ok) throw new Error('could not fetch Google public certs');
    const { keys } = await response.json();
    cachedGoogleCerts = { fetchedAt: Date.now(), keys: new Map(keys.map((k) => [k.kid, k])) };
  }
  const jwk = cachedGoogleCerts.keys.get(kid);
  if (!jwk) throw new Error('unknown key id');
  return jwk;
}

/** Mints (and caches for its lifetime) an OAuth2 access token for the
 * service account, scoped to sending FCM messages, via the self-signed JWT
 * flow — the standard way to authenticate as a service account without the
 * Node-only firebase-admin SDK. */
async function getFcmAccessToken(serviceAccount) {
  if (cachedAccessToken && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.token;
  }

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const headerB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(header)));
  const claimsB64 = base64UrlEncode(new TextEncoder().encode(JSON.stringify(claims)));
  const unsigned = `${headerB64}.${claimsB64}`;

  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64UrlEncode(new Uint8Array(signatureBuffer))}`;

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!tokenResponse.ok) {
    throw new Error(await tokenResponse.text());
  }
  const { access_token, expires_in } = await tokenResponse.json();
  cachedAccessToken = { token: access_token, expiresAt: Date.now() + expires_in * 1000 };
  return access_token;
}

function pemToArrayBuffer(pem) {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

function base64UrlEncode(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function base64UrlDecode(base64Url) {
  const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64UrlDecodeToString(base64Url) {
  return new TextDecoder().decode(base64UrlDecode(base64Url));
}
