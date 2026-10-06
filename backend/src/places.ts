import type { Auth } from "./auth";
import { requireUserId } from "./auth";
import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, requiredString } from "./http";

interface SignalCount {
  feature: string;
  value: "yes" | "no" | "limited";
  count: number;
}

function decodePlaceId(value: string): string {
  try {
    return requiredString(decodeURIComponent(value), "Apple Place ID", 500);
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(400, "Apple Place ID is invalid.");
  }
}

export async function handleSavedPlaces(
  request: Request,
  env: Env,
  auth: Auth,
  encodedPlaceId?: string,
): Promise<Response> {
  const userId = await requireUserId(auth, request);
  if (!encodedPlaceId) {
    if (request.method !== "GET") return methodNotAllowed("GET");
    const rows = await env.DB.prepare(
      `SELECT apple_place_id FROM saved_places WHERE user_id = ? ORDER BY created_at DESC`,
    ).bind(userId).all<{ apple_place_id: string }>();
    return json({ place_ids: rows.results.map((row) => row.apple_place_id) });
  }

  const placeId = decodePlaceId(encodedPlaceId);
  if (request.method === "PUT") {
    await env.DB.batch([
      env.DB.prepare(`INSERT OR IGNORE INTO places (apple_place_id) VALUES (?)`).bind(placeId),
      env.DB.prepare(
        `INSERT OR IGNORE INTO saved_places (user_id, apple_place_id) VALUES (?, ?)`,
      ).bind(userId, placeId),
    ]);
    return new Response(null, { status: 204 });
  }
  if (request.method === "DELETE") {
    await env.DB.prepare(`DELETE FROM saved_places WHERE user_id = ? AND apple_place_id = ?`)
      .bind(userId, placeId).run();
    return new Response(null, { status: 204 });
  }
  return methodNotAllowed("PUT", "DELETE");
}

export async function handlePlace(
  request: Request,
  env: Env,
  encodedPlaceId: string,
  resource: string,
): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const placeId = decodePlaceId(encodedPlaceId);
  switch (resource) {
    case "accessibility":
      return accessibility(env, placeId);
    case "photos":
      return placePhotos(env, placeId);
    default:
      throw new HttpError(404, "Place route not found.");
  }
}

export async function accessibility(env: Env, placeId: string): Promise<Response> {
  return json({ status: "ok", place: { place_id: placeId }, grade: await loadGrade(env, placeId) });
}

export async function loadGrade(env: Env, placeId: string) {
  const rows = await env.DB.prepare(
    `SELECT feature, value, COUNT(*) AS count
     FROM accessibility_signals
     WHERE apple_place_id = ?
     GROUP BY feature, value`,
  ).bind(placeId).all<SignalCount>();

  const byFeature = new Map<string, SignalCount[]>();
  for (const row of rows.results) {
    const values = byFeature.get(row.feature) ?? [];
    values.push(row);
    byFeature.set(row.feature, values);
  }
  const severity: Record<SignalCount["value"], number> = { yes: 0, limited: 1, no: 2 };
  return [...byFeature].map(([feature, values]) => {
    const sorted = [...values].sort((a, b) => b.count - a.count || severity[b.value] - severity[a.value]);
    const total = values.reduce((sum, item) => sum + item.count, 0);
    return {
      feature,
      best_value: sorted[0]!.value,
      confidence: sorted[0]!.count / total,
    };
  });
}

async function placePhotos(env: Env, placeId: string): Promise<Response> {
  const rows = await env.DB.prepare(
    `SELECT id, object_key, credit, sort_order
     FROM place_photos WHERE apple_place_id = ? ORDER BY sort_order, created_at`,
  ).bind(placeId).all<{ id: string; object_key: string; credit: string | null; sort_order: number }>();
  return json(rows.results.map((row) => ({
    id: row.id,
    url: `${env.API_BASE_URL}/v1/media/${row.object_key}`,
    source: "community",
    credit: row.credit,
    sort_order: row.sort_order,
  })));
}
