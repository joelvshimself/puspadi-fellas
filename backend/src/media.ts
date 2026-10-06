import type { Auth } from "./auth";
import { requireUserId } from "./auth";
import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, requiredString } from "./http";

const allowedFacilities = new Set(["lobby", "basement", "elevator", "toilet", "exit_side", "other", "uploads"]);

async function digest(value: string): Promise<string> {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function handleMediaUpload(
  request: Request,
  env: Env,
  auth: Auth,
  encodedPlaceId: string,
  facility: string,
  photoId: string,
): Promise<Response> {
  if (request.method !== "PUT") return methodNotAllowed("PUT");
  const userId = await requireUserId(auth, request);
  if (!allowedFacilities.has(facility)) throw new HttpError(400, "Unknown photo facility.");
  const id = requiredString(photoId, "photo ID", 100);
  const placeId = requiredString(decodeURIComponent(encodedPlaceId), "Apple Place ID", 500);
  const type = request.headers.get("content-type")?.split(";")[0] ?? "";
  if (type !== "image/jpeg") throw new HttpError(415, "Review photos must be JPEG images.");
  const bytes = await request.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > 10_000_000) {
    throw new HttpError(413, "A review photo must be between 1 byte and 10 MB.");
  }

  // Stable per photo: retrying an interrupted upload overwrites the same R2
  // object instead of creating an orphaned duplicate.
  const placeDigest = (await digest(placeId)).slice(0, 32);
  const key = `reviews/${userId}/${placeDigest}/${facility}/${id}.jpg`;
  await env.MEDIA.put(key, bytes, { httpMetadata: { contentType: type } });
  await env.DB.prepare(
    `INSERT INTO media_uploads (object_key, owner_user_id, content_type, byte_size)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(object_key) DO UPDATE SET byte_size = excluded.byte_size, content_type = excluded.content_type`,
  ).bind(key, userId, type, bytes.byteLength).run();
  return json({ url: `${env.API_BASE_URL}/v1/media/${key}` });
}

export async function handleMediaRead(request: Request, env: Env, key: string): Promise<Response> {
  if (request.method !== "GET" && request.method !== "HEAD") return methodNotAllowed("GET", "HEAD");
  const object = await env.MEDIA.get(key);
  if (!object) throw new HttpError(404, "Photo not found.");
  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  // Avatar objects can be replaced at the same URL. Let URLSession validate
  // every request so profile changes never get trapped behind a stale cache.
  headers.set("cache-control", "no-cache");
  return new Response(request.method === "HEAD" ? null : object.body, { headers });
}
