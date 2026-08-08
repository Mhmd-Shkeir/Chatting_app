/**
 * Gemini translation proxy Worker.
 *
 * Gemini's API key can't live in the Flutter app (same reasoning as
 * imagekit-auth-worker.js for ImageKit's private key), so this small, free
 * Cloudflare Worker holds it as a Worker secret and proxies the actual
 * Gemini call. The Flutter app POSTs { text, targetLanguage } and gets back
 * { translatedText }; this Worker never stores anything.
 *
 * Deploy (Cloudflare dashboard, no local tooling needed):
 *   1. workers.cloudflare.com -> sign up free (no card required), or reuse
 *      the account already used for the ImageKit Worker.
 *   2. Get a free Gemini API key at aistudio.google.com/apikey (Google
 *      account, no card required for the free tier).
 *   3. Workers & Pages -> Create -> Create Worker -> name it exactly
 *      "lumina-gemini-translate" (this must match
 *      lib/core/config/translation_config.dart's geminiTranslateEndpoint,
 *      or that constant needs updating to whatever URL Cloudflare assigns).
 *   4. Edit code -> paste this whole file, replacing the default template
 *      -> Deploy.
 *   5. Worker -> Settings -> Variables and Secrets -> Add -> name it
 *      GEMINI_API_KEY, paste your Gemini API key, type "Secret" -> Save.
 */

const LANGUAGE_NAMES = {
  en: 'English',
  ar: 'Arabic',
  fr: 'French',
};

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

    const text = typeof body.text === 'string' ? body.text.trim() : '';
    const targetLanguage = LANGUAGE_NAMES[body.targetLanguage];
    if (!text || !targetLanguage) {
      return new Response('Missing or invalid "text"/"targetLanguage"', { status: 400 });
    }

    const prompt =
      `Translate the following message to ${targetLanguage}. ` +
      'Output only the translated text, with no quotes, labels, or extra commentary:\n\n' +
      text;

    const geminiResponse = await fetch(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': env.GEMINI_API_KEY,
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
        }),
      },
    );

    if (!geminiResponse.ok) {
      const errorBody = await geminiResponse.text();
      return new Response(`Gemini request failed: ${errorBody}`, { status: 502 });
    }

    const geminiData = await geminiResponse.json();
    const translatedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
    if (!translatedText) {
      return new Response('Gemini returned no translation', { status: 502 });
    }

    return new Response(JSON.stringify({ translatedText }), {
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
