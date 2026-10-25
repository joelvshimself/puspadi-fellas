import type { Auth } from "./auth";
import { requireUserId } from "./auth";
import type { Env } from "./env";
import { methodNotAllowed } from "./http";

/**
 * DELETE /v1/me: permanently deletes the signed-in account, its reviews, saved places,
 * profile and every photo it uploaded. Required by the App Store for apps with sign-up.
 *
 * Photo rows reference media_uploads with ON DELETE RESTRICT, so they are removed
 * before the uploads; deleting the user then cascades sessions, accounts, profile
 * and saved places. The profile photo isn't a media upload, so it is removed by its own key.
 */
export async function handleDeleteAccount(request: Request, env: Env, auth: Auth): Promise<Response> {
  if (request.method !== "DELETE") return methodNotAllowed("DELETE");
  const userId = await requireUserId(auth, request);
  const media = await env.DB.prepare(`SELECT object_key FROM media_uploads WHERE owner_user_id = ?`)
    .bind(userId).all<{ object_key: string }>();
  const mine = `SELECT id FROM reviews WHERE user_id = ?`;
  const owned = `SELECT object_key FROM media_uploads WHERE owner_user_id = ?`;
  await env.DB.batch([
    env.DB.prepare(`DELETE FROM review_photos WHERE review_id IN (${mine}) OR object_key IN (${owned})`).bind(userId, userId),
    env.DB.prepare(`DELETE FROM place_photos WHERE object_key IN (${owned})`).bind(userId),
    env.DB.prepare(`DELETE FROM accessibility_signals WHERE user_id = ?`).bind(userId),
    env.DB.prepare(`DELETE FROM reviews WHERE user_id = ?`).bind(userId),
    env.DB.prepare(`DELETE FROM media_uploads WHERE owner_user_id = ?`).bind(userId),
    env.DB.prepare(`DELETE FROM "user" WHERE id = ?`).bind(userId),
  ]);
  // R2 deletes take up to 1000 keys per call.
  const keys = [...media.results.map((row) => row.object_key), `avatars/${userId}/avatar.jpg`];
  for (let start = 0; start < keys.length; start += 1000) {
    await env.MEDIA.delete(keys.slice(start, start + 1000));
  }
  return new Response(null, { status: 204 });
}
