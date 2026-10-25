import { assertAuthConfigured, createAuth, requireUserId } from "./auth";
import type { Env } from "./env";
import { HttpError, json } from "./http";
import { handleMediaRead, handleMediaUpload } from "./media";
import { handleNearby, handlePlace, handleRegions, handleSavedPlaces, handleSearch } from "./places";
import { handleDeleteAccount } from "./account";
import { handleProfile } from "./profile";
import { handleAnnouncement, handleDevices, notifySavedPlaceReview } from "./push";
import { handleAdminSync, syncDueTiles } from "./sync";
import {
  handleMyReviews,
  handlePlaceReviews,
  handleReviewById,
  handleReviewPhotos,
  handleReviewsRoot,
  handleReviewForEdit,
} from "./reviews";

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    try {
      // Awaited so a rejected handler promise lands in the catch below.
      return await route(request, env, ctx);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: error.code, message: error.message }, error.status);
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

  /** Every 10 minutes: refresh the most overdue tiles of the place directory (src/sync.ts). */
  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(syncDueTiles(env).then((results) => console.log("Place sync", JSON.stringify(results))));
  },
} satisfies ExportedHandler<Env>;

async function route(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const url = new URL(request.url);
  const auth = createAuth(env);

  if (url.pathname.startsWith("/api/auth/")) {
    assertAuthConfigured(auth);
    return auth.handler(request);
  }
  if (url.pathname === "/health") {
    return json({ status: "ok" });
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
    const response = await handleReviewsRoot(request, env, auth);
    // A new review (201, not a replayed submission): tell people who saved the place, after responding.
    if (response.status === 201) {
      const { reviewId } = await response.clone().json<{ reviewId: string }>();
      ctx.waitUntil(notifySavedPlaceReview(env, reviewId).catch((error) => console.error("Push failed", error)));
    }
    return response;
  }
  if (url.pathname === "/v1/devices") {
    return handleDevices(request, env, auth);
  }
  if (url.pathname.startsWith("/v1/devices/")) {
    return handleDevices(request, env, auth, url.pathname.slice("/v1/devices/".length));
  }
  if (url.pathname === "/v1/me") {
    return handleDeleteAccount(request, env, auth);
  }
  if (url.pathname === "/v1/me/reviews") {
    return handleMyReviews(request, env, auth);
  }
  const editReview = url.pathname.match(/^\/v1\/reviews\/([^/]+)\/edit$/);
  if (editReview) {
    return handleReviewForEdit(request, env, auth, editReview[1]!);
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
  if (url.pathname === "/v1/admin/announcements") return handleAnnouncement(request, env);
  if (url.pathname === "/v1/places/nearby") return handleNearby(request, env, url);
  if (url.pathname === "/v1/places/search") return handleSearch(request, env, url);
  if (url.pathname === "/v1/places/regions") return handleRegions(request, env);
  const place = url.pathname.match(/^\/v1\/places\/([^/]+)(?:\/(accessibility|photos|reviews|review-photos))?$/);
  if (place) {
    if (place[2] === "reviews") return handlePlaceReviews(request, env, place[1]!);
    if (place[2] === "review-photos") return handleReviewPhotos(request, env, place[1]!);
    return handlePlace(request, env, place[1]!, place[2]);
  }
  return json({ error: "not_found", message: "Route not found." }, 404);
}

