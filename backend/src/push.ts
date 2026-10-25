import type { Auth } from "./auth";
import { requireUserId } from "./auth";
import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, readJson, requiredString } from "./http";

/**
 * Push notifications through Firebase Cloud Messaging (HTTP v1). Firebase
 * delivers to Android itself and to iOS through APNs with the key uploaded to
 * the Firebase project, so the Worker only ever talks to Google. (APNs needs
 * HTTP/2, which a Worker's fetch doesn't speak.)
 *
 * Needs the secret FCM_SERVICE_ACCOUNT: the Firebase service account JSON.
 * Without it nothing is sent and the rest of the API works as before.
 */

/** Phones subscribe to this topic themselves when announcements are on. */
export const ANNOUNCEMENTS_TOPIC = "announcements";

/** Most devices one review fans out to. Each is one request; Workers Paid allows 1,000 per invocation. */
const MAX_DEVICES_PER_REVIEW = 400;
const CONCURRENCY = 20;

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface PushMessage {
  title: string;
  body: string;
  /** Opens this place when tapped. */
  placeId?: string;
  kind: "saved_place_review" | "announcement";
  /** Later messages with the same key replace earlier ones on the phone. */
  collapseKey?: string;
}

// ---- Devices ----

/** PUT /v1/devices (register or move a token to this user), DELETE /v1/devices/:token. */
export async function handleDevices(request: Request, env: Env, auth: Auth, token?: string): Promise<Response> {
  const userId = await requireUserId(auth, request);
  if (token === undefined) {
    if (request.method !== "PUT") return methodNotAllowed("PUT");
    const body = await readJson<{ token?: unknown; platform?: unknown }>(request);
    const deviceToken = requiredString(body.token, "token", 4096);
    if (body.platform !== "ios" && body.platform !== "android") throw new HttpError(400, "platform must be ios or android.");
    // A phone keeps its token across sign-outs, so the token belongs to whoever signed in last.
    await env.DB.prepare(
      `INSERT INTO push_devices (token, user_id, platform) VALUES (?, ?, ?)
       ON CONFLICT(token) DO UPDATE SET user_id = excluded.user_id, platform = excluded.platform,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
    ).bind(deviceToken, userId, body.platform).run();
    return json({ status: "ok" });
  }
  if (request.method !== "DELETE") return methodNotAllowed("DELETE");
  await env.DB.prepare(`DELETE FROM push_devices WHERE token = ? AND user_id = ?`)
    .bind(decodeURIComponent(token), userId).run();
  return json({ status: "ok" });
}

// ---- What gets sent ----

/** After a new review: tell everyone who saved the place (except its author). Runs after the response. */
export async function notifySavedPlaceReview(env: Env, reviewId: string): Promise<void> {
  if (!env.FCM_SERVICE_ACCOUNT) return;
  const review = await env.DB.prepare(
    `SELECT r.user_id, r.place_id, p.name FROM reviews r JOIN places p ON p.id = r.place_id WHERE r.id = ?`,
  ).bind(reviewId).first<{ user_id: string; place_id: string; name: string }>();
  if (!review) return;
  const devices = await env.DB.prepare(
    `SELECT d.token FROM saved_places s
     JOIN profiles pr ON pr.user_id = s.user_id AND pr.notify_saved_place_reviews = 1
     JOIN push_devices d ON d.user_id = s.user_id
     WHERE s.place_id = ? AND s.user_id != ?
     LIMIT ?`,
  ).bind(review.place_id, review.user_id, MAX_DEVICES_PER_REVIEW).all<{ token: string }>();
  await sendToTokens(env, devices.results.map((row) => row.token), {
    kind: "saved_place_review",
    title: review.name,
    body: "Someone just shared how accessible it is. See what they found.",
    placeId: review.place_id,
    collapseKey: `place-${review.place_id}`,
  });
}

/** POST /v1/admin/announcements {title, body, placeId?}: one message to every phone with announcements on. */
export async function handleAnnouncement(request: Request, env: Env): Promise<Response> {
  if (request.method !== "POST") return methodNotAllowed("POST");
  const token = request.headers.get("authorization")?.replace(/^Bearer /, "");
  if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) throw new HttpError(401, "Admin token required.");
  if (!env.FCM_SERVICE_ACCOUNT) throw new HttpError(503, "Push isn't configured: set FCM_SERVICE_ACCOUNT.");
  const body = await readJson<{ title?: unknown; body?: unknown; placeId?: unknown }>(request);
  const message: PushMessage = {
    kind: "announcement",
    title: requiredString(body.title, "title", 100),
    body: requiredString(body.body, "body", 500),
    placeId: typeof body.placeId === "string" && body.placeId ? body.placeId : undefined,
  };
  const account = serviceAccount(env);
  const result = await send(account, { topic: ANNOUNCEMENTS_TOPIC, ...fcmMessage(message) });
  if (!result.ok) throw new HttpError(502, `Firebase refused the announcement: ${result.error}`);
  return json({ status: "ok" });
}

// ---- Firebase Cloud Messaging ----

function serviceAccount(env: Env): ServiceAccount {
  const account = JSON.parse(env.FCM_SERVICE_ACCOUNT!) as ServiceAccount;
  if (!account.project_id || !account.client_email || !account.private_key) {
    throw new Error("FCM_SERVICE_ACCOUNT is missing project_id, client_email or private_key.");
  }
  return account;
}

function fcmMessage(message: PushMessage) {
  const data: Record<string, string> = { kind: message.kind };
  if (message.placeId) data.place_id = message.placeId;
  return {
    notification: { title: message.title, body: message.body },
    data,
    android: {
      ...(message.collapseKey ? { collapse_key: message.collapseKey } : {}),
      notification: { channel_id: message.kind === "announcement" ? "announcements" : "reviews" },
    },
    apns: {
      headers: message.collapseKey ? { "apns-collapse-id": message.collapseKey } : {},
      payload: { aps: { sound: "default" } },
    },
  };
}

async function sendToTokens(env: Env, tokens: string[], message: PushMessage): Promise<void> {
  if (tokens.length === 0) return;
  const account = serviceAccount(env);
  const payload = fcmMessage(message);
  const dead: string[] = [];
  for (let start = 0; start < tokens.length; start += CONCURRENCY) {
    await Promise.all(tokens.slice(start, start + CONCURRENCY).map(async (token) => {
      const result = await send(account, { token, ...payload });
      if (result.unregistered) dead.push(token);
      else if (!result.ok) console.error("Push failed", result.error);
    }));
  }
  // Uninstalled apps and expired tokens: stop sending to them.
  for (let start = 0; start < dead.length; start += 50) {
    await env.DB.batch(dead.slice(start, start + 50).map((token) =>
      env.DB.prepare(`DELETE FROM push_devices WHERE token = ?`).bind(token)));
  }
}

async function send(account: ServiceAccount, message: object): Promise<{ ok: boolean; unregistered?: boolean; error?: string }> {
  const response = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${await accessToken(account)}`, "content-type": "application/json" },
    body: JSON.stringify({ message }),
  });
  if (response.ok) return { ok: true };
  const text = await response.text();
  const unregistered = response.status === 404 || text.includes("UNREGISTERED") ||
    (response.status === 400 && text.includes("registration token"));
  return { ok: false, unregistered, error: `${response.status} ${text.slice(0, 300)}` };
}

let cachedToken: { value: string; expiresAt: number } | null = null;

/** OAuth access token for the service account, signed here with Web Crypto (RS256). Reused until it's nearly expired. */
async function accessToken(account: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) return cachedToken.value;
  const now = Math.floor(Date.now() / 1000);
  const encode = (value: object) => base64Url(new TextEncoder().encode(JSON.stringify(value)));
  const unsigned = `${encode({ alg: "RS256", typ: "JWT" })}.${encode({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;
  const pem = account.private_key.replace(/-----(BEGIN|END) PRIVATE KEY-----|\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (char) => char.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${unsigned}.${base64Url(new Uint8Array(signature))}`,
  });
  if (!response.ok) throw new Error(`Google token exchange failed: ${response.status} ${await response.text()}`);
  const body = await response.json<{ access_token: string; expires_in: number }>();
  cachedToken = { value: body.access_token, expiresAt: Date.now() + body.expires_in * 1000 };
  return body.access_token;
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
