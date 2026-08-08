/// The client triggers push notifications itself right after a message
/// send succeeds — no polling, no persistent server, no Cloud Functions
/// (which would need the paid Blaze plan). This small, free Cloudflare
/// Worker (see /cloudflare-worker/push-notify-worker.js) verifies the
/// caller's Firebase ID token, then relays the send to FCM using a service
/// account it holds as a secret — same shape as [geminiTranslateEndpoint]
/// and [imageKitAuthEndpoint].
///
/// This URL assumes the Worker is named exactly `lumina-push-notify` under
/// the same Cloudflare account as the other Workers — update this constant
/// if Cloudflare assigns a different one once the Worker is deployed.
const pushNotifyEndpoint =
    'https://lumina-push-notify.mhmd2004shkeir.workers.dev';
