/**
 * Gemini proxy Worker — translation AND the in-app AI Assistant.
 *
 * Gemini's API key can't live in the Flutter app (same reasoning as
 * imagekit-auth-worker.js for ImageKit's private key), so this small, free
 * Cloudflare Worker holds it as a Worker secret and proxies the actual
 * Gemini call. Two request shapes hit the same endpoint, same secret, same
 * deployment — no second Worker or API key was needed for the AI Assistant:
 *   - { text, targetLanguage }  -> { translatedText }   (message translation)
 *   - { messages: [...] }       -> { reply }             (AI Assistant chat)
 *
 * This Worker never stores anything between requests (aside from the
 * in-memory Google-certs/OAuth caches used by the *other* Workers — this
 * file has none of its own state).
 *
 * Deploy (Cloudflare dashboard, no local tooling needed):
 *   1. workers.cloudflare.com -> sign up free (no card required), or reuse
 *      the account already used for the other Workers.
 *   2. Get a free Gemini API key at aistudio.google.com/apikey (Google
 *      account, no card required for the free tier).
 *   3. Workers & Pages -> Create -> Create Worker -> name it exactly
 *      "lumina-gemini-translate" (this must match
 *      lib/core/config/translation_config.dart's geminiTranslateEndpoint,
 *      which the AI Assistant also reuses as-is — or update that constant
 *      to whatever URL Cloudflare assigns).
 *   4. Edit code -> paste this whole file, replacing the default template
 *      -> Deploy.
 *   5. Worker -> Settings -> Variables and Secrets -> Add -> name it
 *      GEMINI_API_KEY, paste your Gemini API key, type "Secret" -> Save.
 *
 * If this Worker already exists (from setting up translation earlier), you
 * only need to re-paste this updated file and Deploy again — the secret and
 * URL stay exactly the same.
 */

const LANGUAGE_NAMES = {
  en: 'English',
  ar: 'Arabic',
  fr: 'French',
};

const GEMINI_MODEL_ENDPOINT =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent';

// Basic hygiene so a malformed or abusive request can't run up an unbounded
// Gemini bill through this endpoint (same open-access posture as the rest
// of this app's Workers — no auth check — just sane upper bounds).
const MAX_ASSISTANT_MESSAGES = 20;
const MAX_MESSAGE_LENGTH = 4000;

// Grounds every Lumina-specific answer in what the app actually does today
// (see AI_ASSISTANT.md in the Flutter repo for how this stays in sync) —
// the assistant is told to say so rather than invent an answer for
// anything not covered here.
const LUMINA_APP_GUIDE = `
Lumina Chat feature reference. For any question about using the Lumina Chat app, answer ONLY using the facts below. If something isn't covered here, say you're not sure rather than guessing or inventing functionality.

NAVIGATION
- Home screen: the conversation list. Tap your avatar (top-left) to open Settings. Tap the search icon (top-right) to find people and start a direct chat. Tap the "new group" icon (person with a plus, top-right, next to search) to start a group.
- The Lumina Assistant (this chat) opens from a floating button in the bottom-right corner of the home screen.

ACCOUNT & SETTINGS (Home -> tap your avatar top-left -> Settings)
- Sign out: Settings -> "Sign Out" (also available as "Logout" on the Profile screen).
- Change theme: Settings -> Theme -> choose Light, Dark, or System.
- Change language: Settings -> Language -> choose English, Arabic, or French. This sets your preferred language for message auto-translation, not the app's display language.
- Edit display name: Settings -> Profile -> "Edit profile" card.
- Edit username: Settings -> Profile -> tap your "@username" (pencil icon) -> enter a new one -> Save.
- Change profile photo: Settings -> Profile -> tap the camera icon on your avatar -> Take photo / Choose from gallery / Remove photo.
- Delete account: Settings -> Profile -> "Delete account" (requires your password; permanent).

CHATS
- Start a direct chat: Home -> search icon -> find a person by name or @username -> tap them.
- Send a text message: open a chat, type in the message box, tap send.
- Send an image: open a chat -> tap the image icon (left of the message box) -> Take photo or Choose from gallery.
- Send a voice message: open a chat -> tap the microphone icon to start recording -> tap the send icon to send it, or the trash icon to cancel.
- Reply to a message: swipe the message, or long-press it and choose "Reply".
- React to a message: long-press a message and tap an emoji, or tap an existing reaction pill under a message to add/remove your own.
- Edit a message: long-press a message you sent (text messages only) -> Edit.
- Delete a message: long-press it -> Delete -> "Delete for me" (anyone) or, if you sent it, "Delete for everyone".
- Forward a message: long-press it -> Forward -> pick a conversation.
- Translate a message: tap "Translate" under an incoming message written in a different language than your preferred language (set in Settings -> Language).
- Clear a chat (your view only, the other person is unaffected): inside a chat, tap the (kebab) menu -> "Clear chat". From the home screen you can also long-press a conversation -> "Delete chat" — same effect, just triggered from the list.

GROUPS
- Create a group: Home -> tap the new-group icon (top-right) -> enter a name, optionally add a photo, select members -> Create.
- Add members: open the group -> tap the group name/avatar in the header (or the menu -> "Group info") -> "Add members" -> select people -> Add. Any current member can add people.
- Remove a member: Group info screen -> tap the red remove icon next to a member's name. Only the group's creator/admin can do this.
- Leave a group: Group info screen -> "Leave group". Anyone, including the creator, can leave; the group continues for the remaining members.
- Incoming group messages show the sender's name above the bubble.

NOTIFICATIONS
- Lumina sends a push notification for new messages when the app isn't open.
`.trim();

const ASSISTANT_SYSTEM_INSTRUCTION = `You are Lumina Assistant, a helpful AI built into the Lumina Chat messaging app.

You handle two kinds of questions:
1. General questions (anything not about Lumina Chat itself) — answer normally and helpfully, like any capable AI assistant.
2. Questions about how to use Lumina Chat — answer using ONLY the feature reference below. Give concise, step-by-step instructions. If something isn't covered by the reference, say plainly that you're not sure rather than inventing functionality.

Be conversational, keep answers reasonably concise, and use the earlier turns of the conversation for context on follow-up questions.

Formatting: reply in plain text only. The app displays your reply as-is in a plain chat bubble with no Markdown or LaTeX rendering, so never use **bold**, headers, backticks, LaTeX/$...$ math notation, or other markup — write everything as normal prose. Use plain numbered steps ("1.", "2.") or a hyphen "-" for lists when that helps.

${LUMINA_APP_GUIDE}`;

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

    if (Array.isArray(body.messages)) {
      return handleAssistant(body, env);
    }
    return handleTranslate(body, env);
  },
};

async function handleTranslate(body, env) {
  const text = typeof body.text === 'string' ? body.text.trim() : '';
  const targetLanguage = LANGUAGE_NAMES[body.targetLanguage];
  if (!text || !targetLanguage) {
    return new Response('Missing or invalid "text"/"targetLanguage"', { status: 400 });
  }

  const prompt =
    `Translate the following message to ${targetLanguage}. ` +
    'Output only the translated text, with no quotes, labels, or extra commentary:\n\n' +
    text;

  const geminiResponse = await fetch(GEMINI_MODEL_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': env.GEMINI_API_KEY,
    },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
    }),
  });

  if (!geminiResponse.ok) {
    const errorBody = await geminiResponse.text();
    return new Response(`Gemini request failed: ${errorBody}`, { status: 502 });
  }

  const geminiData = await geminiResponse.json();
  const translatedText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
  if (!translatedText) {
    return new Response('Gemini returned no translation', { status: 502 });
  }

  return jsonResponse({ translatedText });
}

async function handleAssistant(body, env) {
  const messages = body.messages
    .filter((m) => m && typeof m.text === 'string' && (m.role === 'user' || m.role === 'assistant'))
    .map((m) => ({ role: m.role, text: m.text.trim() }))
    .filter((m) => m.text.length > 0 && m.text.length <= MAX_MESSAGE_LENGTH)
    .slice(-MAX_ASSISTANT_MESSAGES);

  if (messages.length === 0) {
    return new Response('Missing or invalid "messages"', { status: 400 });
  }

  const geminiResponse = await fetch(GEMINI_MODEL_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': env.GEMINI_API_KEY,
    },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: ASSISTANT_SYSTEM_INSTRUCTION }] },
      contents: messages.map((m) => ({
        role: m.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: m.text }],
      })),
    }),
  });

  if (!geminiResponse.ok) {
    const errorBody = await geminiResponse.text();
    return new Response(`Gemini request failed: ${errorBody}`, { status: 502 });
  }

  const geminiData = await geminiResponse.json();
  const reply = geminiData.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
  if (!reply) {
    return new Response('Gemini returned no reply', { status: 502 });
  }

  return jsonResponse({ reply });
}

function jsonResponse(data) {
  return new Response(JSON.stringify(data), {
    headers: {
      'Content-Type': 'application/json',
      // Harmless for a native Flutter client (CORS is browser-enforced,
      // not applicable to mobile HTTP calls) — kept permissive here only
      // so a future web build or browser-based testing isn't blocked.
      'Access-Control-Allow-Origin': '*',
    },
  });
}
