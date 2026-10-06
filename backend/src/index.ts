import { createAuth, requireUserId } from "./auth";
import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, readJson } from "./http";
import { handleMediaRead, handleMediaUpload } from "./media";
import { handleNearby, handlePlace, handleSavedPlaces, handleSearch } from "./places";
import { handleProfile } from "./profile";
import { handleAdminSync, syncAllRegions } from "./sync";
import {
  handleMyReviews,
  handlePlaceReviews,
  handleReviewById,
  handleReviewPhotos,
  handleReviewsRoot,
} from "./reviews";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      // Awaited so a rejected handler promise lands in the catch below.
      return await route(request, env);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: "request_failed", message: error.message }, error.status);
      }
      const status = typeof error === "object" && error && "status" in error && typeof error.status === "number"
        ? error.status
        : 500;
      if (status >= 500) console.error(error);
      return json(
        { error: status === 401 ? "unauthorized" : "internal_error", message: error instanceof Error ? error.message : "Request failed." },
        status,
      );
    }
  },

  /** Weekly refresh of the place directory from OpenStreetMap (see wrangler.jsonc "triggers"). */
  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(syncAllRegions(env).then((results) => console.log("Place sync", JSON.stringify(results))));
  },
} satisfies ExportedHandler<Env>;

async function route(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const auth = createAuth(env);

  if (url.pathname.startsWith("/api/auth/")) {
    return auth.handler(request);
  }
  if (url.pathname === "/health") {
    return json({ status: "ok" });
  }
  if (url.pathname === "/v1/auth/email-registered") {
    if (request.method !== "POST") return methodNotAllowed("POST");
    const body = await readJson<{ email?: unknown }>(request);
    const email = typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const user = email ? await env.DB.prepare(`SELECT id FROM "user" WHERE lower(email) = ?`).bind(email).first() : null;
    return json({ registered: Boolean(user) });
  }
  if (url.pathname === "/v1/auth/providers") {
    if (request.method !== "GET") return methodNotAllowed("GET");
    const userId = await requireUserId(auth, request);
    const rows = await env.DB.prepare(
      `SELECT DISTINCT providerId FROM account WHERE userId = ?`,
    ).bind(userId).all<{ providerId: string }>();
    return json({ providers: rows.results.map((row) => row.providerId) });
  }
  if (url.pathname === "/v1/profile" || url.pathname.startsWith("/v1/profile/")) {
    return handleProfile(request, env, auth, url.pathname.slice("/v1/profile".length));
  }
  if (url.pathname === "/v1/saved-places") {
    return handleSavedPlaces(request, env, auth);
  }
  if (url.pathname.startsWith("/v1/saved-places/")) {
    return handleSavedPlaces(request, env, auth, url.pathname.slice("/v1/saved-places/".length));
  }
  if (url.pathname === "/v1/reviews") {
    return handleReviewsRoot(request, env, auth);
  }
  if (url.pathname === "/v1/me/reviews") {
    return handleMyReviews(request, env, auth);
  }
  if (url.pathname.startsWith("/v1/reviews/")) {
    return handleReviewById(request, env, auth, url.pathname.slice("/v1/reviews/".length));
  }

  const upload = url.pathname.match(/^\/v1\/media\/review-photos\/([^/]+)\/([^/]+)\/([^/]+)$/);
  if (upload) {
    return handleMediaUpload(request, env, auth, upload[1]!, upload[2]!, upload[3]!);
  }
  if (url.pathname.startsWith("/v1/media/")) {
    return handleMediaRead(request, env, decodeURIComponent(url.pathname.slice("/v1/media/".length)));
  }

  if (url.pathname === "/v1/admin/sync-places") return handleAdminSync(request, env);
  if (url.pathname === "/v1/places/nearby") return handleNearby(request, env, url);
  if (url.pathname === "/v1/places/search") return handleSearch(request, env, url);
  const place = url.pathname.match(/^\/v1\/places\/([^/]+)(?:\/(accessibility|photos|reviews|review-photos))?$/);
  if (place) {
    if (place[2] === "reviews") return handlePlaceReviews(request, env, place[1]!);
    if (place[2] === "review-photos") return handleReviewPhotos(request, env, place[1]!);
    return handlePlace(request, env, place[1]!, place[2]);
  }
  return json({ error: "not_found", message: "Route not found." }, 404);
}

