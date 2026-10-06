import type { Auth } from "./auth";
import { requireUserId } from "./auth";
import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, readJson, requiredString } from "./http";

interface ProfileRow {
  user_id: string;
  display_name: string | null;
  avatar_key: string | null;
  mobility_aids: string;
  pseudonym: string;
  show_real_name: number;
}

interface ProfileUpdate {
  displayName?: unknown;
  mobilityAids?: unknown;
  showRealName?: unknown;
}

export async function ensureProfile(env: Env, userId: string): Promise<void> {
  const pseudonym = `rollspot-${userId.replaceAll("-", "").slice(0, 10)}`;
  await env.DB.prepare(
    `INSERT OR IGNORE INTO profiles (user_id, pseudonym) VALUES (?, ?)`,
  ).bind(userId, pseudonym).run();
}

function publicProfile(env: Env, row: ProfileRow) {
  return {
    id: row.user_id,
    display_name: row.display_name,
    avatar_url: row.avatar_key ? `${env.API_BASE_URL}/v1/media/${row.avatar_key}` : null,
    mobility_aids: JSON.parse(row.mobility_aids) as string[],
    pseudonym: row.pseudonym,
    show_real_name: row.show_real_name === 1,
  };
}

export async function handleProfile(
  request: Request,
  env: Env,
  auth: Auth,
  suffix: string,
): Promise<Response> {
  const userId = await requireUserId(auth, request);
  await ensureProfile(env, userId);

  if (suffix === "/avatar") return handleAvatar(request, env, userId);
  if (suffix !== "") throw new HttpError(404, "Profile route not found.");

  if (request.method === "GET") {
    const row = await env.DB.prepare(`SELECT * FROM profiles WHERE user_id = ?`)
      .bind(userId).first<ProfileRow>();
    if (!row) throw new HttpError(500, "Profile could not be created.");
    return json(publicProfile(env, row));
  }

  if (request.method === "PATCH") {
    const body = await readJson<ProfileUpdate>(request);
    const updates: string[] = [];
    const values: unknown[] = [];

    if (body.displayName !== undefined && body.displayName !== null) {
      updates.push("display_name = ?");
      values.push(requiredString(body.displayName, "displayName", 80));
    }
    if (body.mobilityAids !== undefined && body.mobilityAids !== null) {
      if (!Array.isArray(body.mobilityAids) || !body.mobilityAids.every((item) => typeof item === "string")) {
        throw new HttpError(400, "mobilityAids must be an array of strings.");
      }
      const aids = [...new Set(body.mobilityAids.map((item) => item.trim()).filter(Boolean))].slice(0, 20);
      updates.push("mobility_aids = ?");
      values.push(JSON.stringify(aids));
    }
    if (body.showRealName !== undefined && body.showRealName !== null) {
      if (typeof body.showRealName !== "boolean") throw new HttpError(400, "showRealName must be a boolean.");
      updates.push("show_real_name = ?");
      values.push(body.showRealName ? 1 : 0);
    }
    if (updates.length === 0) throw new HttpError(400, "No profile changes were supplied.");

    updates.push("updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')");
    await env.DB.prepare(`UPDATE profiles SET ${updates.join(", ")} WHERE user_id = ?`)
      .bind(...values, userId).run();
    const row = await env.DB.prepare(`SELECT * FROM profiles WHERE user_id = ?`)
      .bind(userId).first<ProfileRow>();
    return json(publicProfile(env, row!));
  }

  return methodNotAllowed("GET", "PATCH");
}

async function handleAvatar(request: Request, env: Env, userId: string): Promise<Response> {
  if (request.method !== "PUT") return methodNotAllowed("PUT");
  const type = request.headers.get("content-type")?.split(";")[0] ?? "";
  if (type !== "image/jpeg") throw new HttpError(415, "Avatar must be a JPEG image.");
  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > 5_000_000) {
    throw new HttpError(413, "Avatar must be between 1 byte and 5 MB.");
  }

  const key = `avatars/${userId}/avatar.jpg`;
  await env.MEDIA.put(key, bytes, { httpMetadata: { contentType: type } });
  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO media_uploads (object_key, owner_user_id, content_type, byte_size)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(object_key) DO UPDATE SET byte_size = excluded.byte_size, content_type = excluded.content_type`,
    ).bind(key, userId, type, bytes.byteLength),
    env.DB.prepare(
      `UPDATE profiles SET avatar_key = ?, updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE user_id = ?`,
    ).bind(key, userId),
  ]);
  return json({ url: `${env.API_BASE_URL}/v1/media/${key}` });
}
