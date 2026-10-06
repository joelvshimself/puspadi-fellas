import type { Auth } from "./auth";
import { requireUserId } from "./auth";
import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, readJson, requiredString, uuid } from "./http";
import { loadGrade } from "./places";
import { ensureProfile } from "./profile";

type AccessibilityValue = "yes" | "no" | "limited";
type Facility = "lobby" | "basement" | "elevator" | "toilet" | "exit_side" | "other";

interface Note {
  text?: unknown;
  photoUrls?: unknown;
  photoCaptions?: unknown;
}

interface Entrance {
  location?: unknown;
  hasDropoffRamp?: unknown;
  hasRails?: unknown;
  doorType?: unknown;
  isWideEnough?: unknown;
  review?: Note | null;
}

interface ReviewPayload {
  submissionId?: unknown;
  appleMapsId?: unknown;
  entrances?: Entrance[] | null;
  elevator?: {
    exists?: unknown;
    wheelchairAccessible?: unknown;
    blockers?: unknown;
    review?: Note | null;
  } | null;
  toilet?: { hasDisabledToilet?: unknown; review?: Note | null } | null;
}

interface NormalizedNote {
  text: string | null;
  photos: Array<{ objectKey: string; caption: string }>;
}

interface NormalizedEntrance {
  location: Facility;
  hasDropoffRamp: boolean | null;
  hasRails: boolean | null;
  doorType: "manual" | "automatic" | null;
  isWideEnough: boolean | null;
  review: NormalizedNote | null;
}

interface ReviewRow {
  id: string;
  user_id: string;
  apple_place_id: string;
  notes: string | null;
  elevator_exists: number | null;
  elevator_wheelchair_accessible: number | null;
  elevator_blockers: string;
  elevator_review_text: string | null;
  has_disabled_toilet: number | null;
  toilet_review_text: string | null;
  created_at: string;
  display_name: string | null;
  pseudonym: string | null;
  avatar_key: string | null;
  mobility_aids: string | null;
}

interface EntranceRow {
  review_id: string;
  location: Facility;
  has_dropoff_ramp: number | null;
  has_rails: number | null;
  door_type: string | null;
  is_wide_enough: number | null;
  review_text: string | null;
  sort_order: number;
}

interface PhotoRow {
  id: string;
  review_id: string;
  object_key: string;
  facility: Facility;
  caption: string;
  sort_order: number;
}

function bool(value: unknown): boolean | null {
  return typeof value === "boolean" ? value : null;
}

function mediaKey(env: Env, value: unknown): string | null {
  if (typeof value !== "string") return null;
  const prefix = `${env.API_BASE_URL}/v1/media/`;
  if (!value.startsWith(prefix)) return null;
  try {
    return decodeURIComponent(value.slice(prefix.length));
  } catch {
    return null;
  }
}

function normalizeNote(env: Env, value: Note | null | undefined): NormalizedNote | null {
  if (!value || typeof value !== "object") return null;
  const text = typeof value.text === "string" && value.text.trim() ? value.text.trim().slice(0, 4_000) : null;
  const urls = Array.isArray(value.photoUrls) ? value.photoUrls : [];
  const captions = Array.isArray(value.photoCaptions) ? value.photoCaptions : [];
  const photos = urls.slice(0, 5).flatMap((url, index) => {
    const objectKey = mediaKey(env, url);
    if (!objectKey) return [];
    const caption = typeof captions[index] === "string" ? captions[index].trim().slice(0, 500) : "";
    return [{ objectKey, caption }];
  });
  return text || photos.length ? { text, photos } : null;
}

function normalizeEntrances(env: Env, value: Entrance[] | null | undefined): NormalizedEntrance[] {
  if (!Array.isArray(value)) return [];
  const facilities = new Set<Facility>(["lobby", "basement", "exit_side", "other"]);
  return value.slice(0, 4).flatMap((item) => {
    if (!item || typeof item !== "object" || typeof item.location !== "string") return [];
    if (!facilities.has(item.location as Facility)) return [];
    const doorType = item.doorType === "manual" || item.doorType === "automatic" ? item.doorType : null;
    return [{
      location: item.location as Facility,
      hasDropoffRamp: bool(item.hasDropoffRamp),
      hasRails: bool(item.hasRails),
      doorType,
      isWideEnough: bool(item.isWideEnough),
      review: normalizeNote(env, item.review),
    }];
  });
}

function deriveEntrance(entrances: NormalizedEntrance[]): AccessibilityValue | null {
  const values = entrances.flatMap((entrance): AccessibilityValue[] => {
    if (entrance.hasDropoffRamp === null && entrance.isWideEnough === null) return [];
    if (entrance.hasDropoffRamp === true && entrance.isWideEnough === true) return ["yes"];
    if (entrance.hasDropoffRamp === false || entrance.isWideEnough === false) return ["no"];
    return ["limited"];
  });
  if (!values.length) return null;
  if (values.every((value) => value === "yes")) return "yes";
  if (values.every((value) => value === "no")) return "no";
  return "limited";
}

function collectNotes(
  entrances: NormalizedEntrance[],
  elevator: NormalizedNote | null,
  toilet: NormalizedNote | null,
): string | null {
  const parts = entrances.flatMap((entrance) => entrance.review?.text ? [entrance.review.text] : []);
  if (elevator?.text) parts.push(elevator.text);
  if (toilet?.text) parts.push(toilet.text);
  return parts.length ? parts.join("\n") : null;
}

export async function handleReviewsRoot(request: Request, env: Env, auth: Auth): Promise<Response> {
  if (request.method !== "POST") return methodNotAllowed("POST");
  const userId = await requireUserId(auth, request);
  const body = await readJson<ReviewPayload>(request);
  const submissionId = requiredString(body.submissionId, "submissionId", 100);
  const placeId = requiredString(body.appleMapsId, "appleMapsId", 500);

  const previous = await env.DB.prepare(
    `SELECT id FROM reviews WHERE user_id = ? AND submission_id = ?`,
  ).bind(userId, submissionId).first<{ id: string }>();
  if (previous) {
    return json({ status: "ok", reviewId: previous.id, placeId, grade: await loadGrade(env, placeId) });
  }

  await ensureProfile(env, userId);
  const entrances = normalizeEntrances(env, body.entrances);
  const elevatorExists = bool(body.elevator?.exists);
  const elevatorAccessible = elevatorExists === true ? bool(body.elevator?.wheelchairAccessible) : null;
  const elevatorBlockers = elevatorAccessible === false && Array.isArray(body.elevator?.blockers)
    ? body.elevator.blockers.filter((value) => value === "no_ramp" || value === "too_small")
    : [];
  const elevatorNote = normalizeNote(env, body.elevator?.review);
  const toiletAccessible = bool(body.toilet?.hasDisabledToilet);
  const toiletNote = normalizeNote(env, body.toilet?.review);
  const reviewId = uuid();

  const statements: D1PreparedStatement[] = [
    env.DB.prepare(`INSERT OR IGNORE INTO places (apple_place_id) VALUES (?)`).bind(placeId),
    env.DB.prepare(
      `INSERT INTO reviews (
        id, submission_id, user_id, apple_place_id, notes,
        elevator_exists, elevator_wheelchair_accessible, elevator_blockers,
        elevator_review_text, has_disabled_toilet, toilet_review_text
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      reviewId,
      submissionId,
      userId,
      placeId,
      collectNotes(entrances, elevatorNote, toiletNote),
      elevatorExists === null ? null : Number(elevatorExists),
      elevatorAccessible === null ? null : Number(elevatorAccessible),
      JSON.stringify(elevatorBlockers),
      elevatorNote?.text ?? null,
      toiletAccessible === null ? null : Number(toiletAccessible),
      toiletNote?.text ?? null,
    ),
  ];

  entrances.forEach((entrance, index) => {
    statements.push(env.DB.prepare(
      `INSERT INTO review_entrances (
        id, review_id, location, has_dropoff_ramp, has_rails, door_type,
        is_wide_enough, review_text, sort_order
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      uuid(), reviewId, entrance.location,
      entrance.hasDropoffRamp === null ? null : Number(entrance.hasDropoffRamp),
      entrance.hasRails === null ? null : Number(entrance.hasRails),
      entrance.doorType,
      entrance.isWideEnough === null ? null : Number(entrance.isWideEnough),
      entrance.review?.text ?? null,
      index,
    ));
    addPhotos(statements, env, reviewId, entrance.location, entrance.review?.photos ?? []);
  });
  addPhotos(statements, env, reviewId, "elevator", elevatorNote?.photos ?? []);
  addPhotos(statements, env, reviewId, "toilet", toiletNote?.photos ?? []);

  const signals: Array<[string, AccessibilityValue | null]> = [
    ["entrance", deriveEntrance(entrances)],
    ["elevator", elevatorExists === false ? "no" : elevatorAccessible === true ? "yes" : elevatorAccessible === false ? "no" : null],
    ["restroom", toiletAccessible === null ? null : toiletAccessible ? "yes" : "no"],
  ];
  for (const [feature, value] of signals) {
    if (!value) continue;
    statements.push(env.DB.prepare(
      `INSERT INTO accessibility_signals (apple_place_id, user_id, feature, value, review_id)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(apple_place_id, user_id, feature) DO UPDATE SET
         value = excluded.value,
         review_id = excluded.review_id,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
    ).bind(placeId, userId, feature, value, reviewId));
  }

  await env.DB.batch(statements);
  return json({ status: "ok", reviewId, placeId, grade: await loadGrade(env, placeId) }, 201);
}

function addPhotos(
  statements: D1PreparedStatement[],
  env: Env,
  reviewId: string,
  facility: Facility,
  photos: NormalizedNote["photos"],
) {
  photos.forEach((photo, index) => {
    statements.push(env.DB.prepare(
      `INSERT OR IGNORE INTO review_photos (id, review_id, object_key, facility, caption, sort_order)
       VALUES (?, ?, ?, ?, ?, ?)`,
    ).bind(uuid(), reviewId, photo.objectKey, facility, photo.caption, index));
  });
}

async function reviewRows(env: Env, where: string, value: string): Promise<ReviewRow[]> {
  const result = await env.DB.prepare(
    `SELECT r.*, p.display_name, p.pseudonym, p.avatar_key, p.mobility_aids
     FROM reviews r
     LEFT JOIN profiles p ON p.user_id = r.user_id
     WHERE ${where} = ?
     ORDER BY r.created_at DESC
     LIMIT 100`,
  ).bind(value).all<ReviewRow>();
  return result.results;
}

async function relatedRows(env: Env, reviewIds: string[]) {
  if (!reviewIds.length) return { entrances: [] as EntranceRow[], photos: [] as PhotoRow[] };
  const placeholders = reviewIds.map(() => "?").join(",");
  const [entrances, photos] = await env.DB.batch<EntranceRow | PhotoRow>([
    env.DB.prepare(
      `SELECT * FROM review_entrances WHERE review_id IN (${placeholders}) ORDER BY sort_order`,
    ).bind(...reviewIds),
    env.DB.prepare(
      `SELECT * FROM review_photos WHERE review_id IN (${placeholders}) ORDER BY sort_order`,
    ).bind(...reviewIds),
  ]);
  return {
    entrances: (entrances?.results ?? []) as EntranceRow[],
    photos: (photos?.results ?? []) as PhotoRow[],
  };
}

function role(mobilityJson: string | null): string | null {
  const aids = mobilityJson ? JSON.parse(mobilityJson) as string[] : [];
  if (!aids.length) return null;
  return aids.includes("Wheelchair") ? "Wheelchair User" : "Community Contributor";
}

function reviewOutput(env: Env, row: ReviewRow, entrances: EntranceRow[], photos: PhotoRow[]) {
  const facilityPhotos = (facility: Facility) => photos.filter((photo) => photo.facility === facility);
  const url = (key: string) => `${env.API_BASE_URL}/v1/media/${key}`;
  return {
    id: row.id,
    created_at: row.created_at,
    notes: row.notes,
    elevator_exists: row.elevator_exists === null ? null : row.elevator_exists === 1,
    elevator_wheelchair_accessible: row.elevator_wheelchair_accessible === null ? null : row.elevator_wheelchair_accessible === 1,
    elevator_blockers: JSON.parse(row.elevator_blockers) as string[],
    elevator_review_text: row.elevator_review_text,
    elevator_photo_urls: facilityPhotos("elevator").map((photo) => url(photo.object_key)),
    elevator_photo_captions: facilityPhotos("elevator").map((photo) => photo.caption),
    has_disabled_toilet: row.has_disabled_toilet === null ? null : row.has_disabled_toilet === 1,
    toilet_review_text: row.toilet_review_text,
    toilet_photo_urls: facilityPhotos("toilet").map((photo) => url(photo.object_key)),
    toilet_photo_captions: facilityPhotos("toilet").map((photo) => photo.caption),
    review_entrances: entrances.map((entrance) => {
      const entrancePhotos = facilityPhotos(entrance.location);
      return {
        location: entrance.location,
        has_dropoff_ramp: entrance.has_dropoff_ramp === null ? null : entrance.has_dropoff_ramp === 1,
        has_rails: entrance.has_rails === null ? null : entrance.has_rails === 1,
        door_type: entrance.door_type,
        is_wide_enough: entrance.is_wide_enough === null ? null : entrance.is_wide_enough === 1,
        review_text: entrance.review_text,
        photo_urls: entrancePhotos.map((photo) => url(photo.object_key)),
        photo_captions: entrancePhotos.map((photo) => photo.caption),
      };
    }),
    reviewer_name: row.display_name?.trim() || row.pseudonym,
    reviewer_role: role(row.mobility_aids),
    reviewer_avatar_url: row.avatar_key ? url(row.avatar_key) : null,
    reviewer_is_pseudonym: !row.display_name?.trim(),
  };
}

export async function handlePlaceReviews(request: Request, env: Env, encodedPlaceId: string): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const placeId = decodeURIComponent(encodedPlaceId);
  const rows = await reviewRows(env, "r.apple_place_id", placeId);
  const related = await relatedRows(env, rows.map((row) => row.id));
  return json({
    status: "ok",
    reviews: rows.map((row) => reviewOutput(
      env,
      row,
      related.entrances.filter((entrance) => entrance.review_id === row.id),
      related.photos.filter((photo) => photo.review_id === row.id),
    )),
  });
}

export async function handleReviewPhotos(request: Request, env: Env, encodedPlaceId: string): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const placeId = decodeURIComponent(encodedPlaceId);
  const rows = await reviewRows(env, "r.apple_place_id", placeId);
  const related = await relatedRows(env, rows.map((row) => row.id));
  const label: Record<Facility, string> = {
    lobby: "Lobby", basement: "Basement", elevator: "Elevator", toilet: "Toilet", exit_side: "Exit side", other: "Other",
  };
  return json({
    status: "ok",
    placeId,
    photos: related.photos.map((photo) => ({
      url: `${env.API_BASE_URL}/v1/media/${photo.object_key}`,
      facility: photo.facility,
      label: label[photo.facility],
      caption: photo.caption,
    })),
  });
}

export async function handleMyReviews(request: Request, env: Env, auth: Auth): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const userId = await requireUserId(auth, request);
  await ensureProfile(env, userId);
  const rows = await reviewRows(env, "r.user_id", userId);
  const related = await relatedRows(env, rows.map((row) => row.id));
  const profile = rows[0] ?? await env.DB.prepare(
    `SELECT user_id, display_name, pseudonym, avatar_key, mobility_aids FROM profiles WHERE user_id = ?`,
  ).bind(userId).first<ReviewRow>();

  const reviews = rows.map((row) => {
    const entrances = related.entrances.filter((entry) => entry.review_id === row.id);
    const photos = related.photos.filter((entry) => entry.review_id === row.id);
    const features = new Set<string>();
    for (const entrance of entrances) {
      if (entrance.has_dropoff_ramp === 1) features.add("Ramp");
      if (entrance.has_rails === 1) features.add("Handrail");
      if (entrance.door_type === "automatic") features.add("Automatic Doors");
      if (entrance.door_type === "manual") features.add("Manual Doors");
    }
    if (row.elevator_exists === 1) features.add("Elevator");
    if (row.has_disabled_toilet === 1) features.add("Toilet");
    const photoUrls = photos.map((photo) => `${env.API_BASE_URL}/v1/media/${photo.object_key}`);
    return {
      id: row.id,
      placeId: row.apple_place_id,
      placeName: "Place",
      createdAt: row.created_at,
      reviewText: row.notes?.trim() || "No review notes written.",
      providedFeatures: [...features],
      photoUrls,
      photoCaptions: photos.map((photo) => photo.caption),
    };
  });
  return json({
    status: "ok",
    userName: profile?.display_name?.trim() || "You",
    userRole: role(profile?.mobility_aids ?? null),
    profileImageUrl: profile?.avatar_key ? `${env.API_BASE_URL}/v1/media/${profile.avatar_key}` : null,
    reviews,
  });
}

export async function handleReviewById(
  request: Request,
  env: Env,
  auth: Auth,
  reviewId: string,
): Promise<Response> {
  if (request.method !== "DELETE") return methodNotAllowed("DELETE");
  const userId = await requireUserId(auth, request);
  const review = await env.DB.prepare(
    `SELECT id FROM reviews WHERE id = ? AND user_id = ?`,
  ).bind(reviewId, userId).first<{ id: string }>();
  if (!review) throw new HttpError(404, "Review not found.");
  const media = await env.DB.prepare(
    `SELECT object_key FROM review_photos WHERE review_id = ?`,
  ).bind(reviewId).all<{ object_key: string }>();
  const deletes: D1PreparedStatement[] = [
    env.DB.prepare(`DELETE FROM accessibility_signals WHERE review_id = ?`).bind(reviewId),
    env.DB.prepare(`DELETE FROM reviews WHERE id = ? AND user_id = ?`).bind(reviewId, userId),
  ];
  for (const item of media.results) {
    deletes.push(env.DB.prepare(`DELETE FROM media_uploads WHERE object_key = ?`).bind(item.object_key));
  }
  await env.DB.batch(deletes);
  await Promise.all(media.results.map((item) => env.MEDIA.delete(item.object_key)));
  return new Response(null, { status: 204 });
}
