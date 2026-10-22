import type { Auth } from "./auth";
import { requireUserId } from "./auth";
import { assertPhotoOwnership, parseContributionV2, SECTION_NAMES, type NormalizedContribution, type Persona, type SectionName } from "./contribution";
import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, readJson, requiredString, uuid } from "./http";
import { findPlaceId, loadGrade, requirePlaceId } from "./places";
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
  version?: unknown;
  persona?: unknown;
  entrance?: unknown;
  pathways?: unknown;
  seating?: unknown;
  parking?: unknown;
  final?: unknown;
  submissionId?: unknown;
  /** Rollspot place ID, or osm:<type>/<id>. */
  placeId?: unknown;
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
  place_id: string;
  notes: string | null;
  elevator_exists: number | null;
  elevator_wheelchair_accessible: number | null;
  elevator_blockers: string;
  elevator_review_text: string | null;
  has_disabled_toilet: number | null;
  toilet_review_text: string | null;
  schema_version: number;
  persona: string | null;
  final_text: string | null;
  created_at: string;
  display_name: string | null;
  pseudonym: string | null;
  avatar_key: string | null;
  mobility_aids: string | null;
  place_name: string | null;
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
  pass_index: number;
  tags: string;
  ramp_answer: string | null;
  handrail_answer: string | null;
}

interface ElevatorPassRow {
  review_id: string;
  pass_index: number;
  wide_entrance: string;
  space_to_maneuver: string | null;
  reachable_buttons: string | null;
  location_text: string | null;
}

interface ToiletPassRow {
  review_id: string;
  pass_index: number;
  door: string;
  seat: string;
  grab_bars: string;
  space: string;
  sink: string;
  emergency: string;
  location_text: string | null;
}

interface AreaRow {
  review_id: string;
  area: string;
  answer: string | null;
  notices: string;
}

interface SectionNoteRow {
  review_id: string;
  section: SectionName;
  text: string;
}

interface PhotoRow {
  id: string;
  review_id: string;
  object_key: string;
  facility: Facility;
  caption: string;
  sort_order: number;
  section: string;
  pass_index: number | null;
  entrance_location: string | null;
  kind: string;
  question: string | null;
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

  const previous = await env.DB.prepare(
    `SELECT id, place_id FROM reviews WHERE user_id = ? AND submission_id = ?`,
  ).bind(userId, submissionId).first<{ id: string; place_id: string }>();
  if (previous) {
    return json({
      status: "ok",
      reviewId: previous.id,
      placeId: previous.place_id,
      grade: await loadGrade(env, previous.place_id),
    });
  }
  const placeId = await requirePlaceId(env, requiredString(body.placeId, "placeId", 200));

  await ensureProfile(env, userId);
  if (body.version === 2) return insertContribution(env, userId, placeId, submissionId, body);

  const entrances = normalizeEntrances(env, body.entrances);
  const elevatorExists = bool(body.elevator?.exists);
  const elevatorAccessible = elevatorExists === true ? bool(body.elevator?.wheelchairAccessible) : null;
  const elevatorBlockers = elevatorAccessible === false && Array.isArray(body.elevator?.blockers)
    ? body.elevator.blockers.filter((value) => value === "no_ramp" || value === "too_small")
    : [];
  const elevatorNote = normalizeNote(env, body.elevator?.review);
  const toiletAccessible = bool(body.toilet?.hasDisabledToilet);
  const toiletNote = normalizeNote(env, body.toilet?.review);
  // An empty review would still use up the submissionId, so a corrected retry
  // could never land. Reject it instead (e.g. a v2 body sent without `version`).
  if (!entrances.length && elevatorExists === null && toiletAccessible === null && !elevatorNote && !toiletNote) {
    throw new HttpError(400, "The review has no answers.");
  }
  const reviewId = uuid();

  const statements: D1PreparedStatement[] = [
    env.DB.prepare(
      `INSERT INTO reviews (
        id, submission_id, user_id, place_id, notes,
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
      `INSERT INTO accessibility_signals (place_id, user_id, feature, value, review_id)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(place_id, user_id, feature) DO UPDATE SET
         value = excluded.value,
         review_id = excluded.review_id,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
    ).bind(placeId, userId, feature, value, reviewId));
  }

  await env.DB.batch(statements);
  return json({ status: "ok", reviewId, placeId, grade: await loadGrade(env, placeId) }, 201);
}

async function insertContribution(
  env: Env,
  userId: string,
  placeId: string,
  submissionId: string,
  body: ReviewPayload,
): Promise<Response> {
  const contribution = parseContributionV2(body, `${env.API_BASE_URL}/v1/media/`);
  await assertOwnedPhotos(env, contribution, userId, submissionId);
  const persona = contribution.persona ?? await personaFor(env, userId);
  const reviewId = uuid();
  const legacy = contribution.legacy;
  const statements: D1PreparedStatement[] = [
    env.DB.prepare(
      `INSERT INTO reviews (
        id, submission_id, user_id, place_id, notes, schema_version, persona, final_text,
        elevator_exists, elevator_wheelchair_accessible, elevator_blockers,
        elevator_review_text, has_disabled_toilet, toilet_review_text
      ) VALUES (?, ?, ?, ?, ?, 2, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      reviewId, submissionId, userId, placeId, legacy.notes, persona, contribution.finalText,
      legacy.elevatorExists === null ? null : Number(legacy.elevatorExists),
      legacy.elevatorAccessible === null ? null : Number(legacy.elevatorAccessible),
      JSON.stringify(legacy.elevatorBlockers),
      legacy.elevatorText,
      legacy.hasDisabledToilet === null ? null : Number(legacy.hasDisabledToilet),
      legacy.toiletText,
    ),
    ...contributionRows(env, reviewId, placeId, userId, contribution),
  ];
  await env.DB.batch(statements);
  return json({ status: "ok", reviewId, placeId, grade: await loadGrade(env, placeId) }, 201);
}

/** Every child row of a v2 review: passes, areas, notes, photos and the place's accessibility signals. */
function contributionRows(
  env: Env,
  reviewId: string,
  placeId: string,
  userId: string,
  contribution: NormalizedContribution,
): D1PreparedStatement[] {
  const statements: D1PreparedStatement[] = [];
  contribution.entrancePasses.forEach((pass, passIndex) => {
    pass.points.forEach((point, pointIndex) => {
      const doorType = point.tags.includes("automatic_doors")
        ? "automatic"
        : point.tags.includes("manual_doors") ? "manual" : null;
      statements.push(env.DB.prepare(
        `INSERT INTO review_entrances (
          id, review_id, location, has_dropoff_ramp, has_rails, door_type,
          is_wide_enough, review_text, sort_order, pass_index, tags, ramp_answer, handrail_answer
        ) VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?)`,
      ).bind(
        uuid(), reviewId, point.location,
        point.tags.includes("ramp") ? 1 : null,
        point.tags.includes("handrail") ? 1 : null,
        doorType,
        entranceSummary(point),
        passIndex * 2 + pointIndex,
        passIndex,
        JSON.stringify(point.tags),
        point.ramp,
        point.handrail,
      ));
    });
  });

  contribution.elevatorPasses.forEach((pass, passIndex) => {
    statements.push(env.DB.prepare(
      `INSERT INTO review_elevators (
        id, review_id, pass_index, wide_entrance, space_to_maneuver, reachable_buttons, location_text
      ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      uuid(), reviewId, passIndex, pass.wideEntrance, pass.spaceToManeuver, pass.reachableButtons, pass.location,
    ));
  });

  contribution.toiletPasses.forEach((pass, passIndex) => {
    statements.push(env.DB.prepare(
      `INSERT INTO review_toilets (
        id, review_id, pass_index, door, seat, grab_bars, space, sink, emergency, location_text
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      uuid(), reviewId, passIndex, pass.door, pass.seat, pass.grabBars, pass.space, pass.sink, pass.emergency, pass.location,
    ));
  });

  if (contribution.pathways) {
    statements.push(env.DB.prepare(
      `INSERT INTO review_areas (review_id, area, answer, notices) VALUES (?, 'pathways', NULL, ?)`,
    ).bind(reviewId, JSON.stringify(contribution.pathways.notices)));
  }
  for (const area of ["seating", "parking"] as const) {
    const value = contribution[area];
    if (!value) continue;
    statements.push(env.DB.prepare(
      `INSERT INTO review_areas (review_id, area, answer, notices) VALUES (?, ?, ?, '[]')`,
    ).bind(reviewId, area, value.answer));
  }

  for (const section of SECTION_NAMES) {
    const text = contribution.sectionNotes[section];
    if (!text) continue;
    statements.push(env.DB.prepare(
      `INSERT INTO review_section_notes (review_id, section, text) VALUES (?, ?, ?)`,
    ).bind(reviewId, section, text));
  }

  for (const photo of contribution.photos) {
    statements.push(env.DB.prepare(
      `INSERT OR IGNORE INTO review_photos (
        id, review_id, object_key, facility, caption, sort_order, section, pass_index, entrance_location, kind, question
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      uuid(), reviewId, photo.objectKey, photo.facility, photo.caption, photo.sortOrder,
      photo.section, photo.passIndex, photo.entranceLocation, photo.kind, photo.question,
    ));
  }

  for (const [feature, value] of [
    ["entrance", contribution.signals.entrance],
    ["elevator", contribution.signals.elevator],
    ["restroom", contribution.signals.restroom],
  ] as const) {
    if (!value) continue;
    statements.push(env.DB.prepare(
      `INSERT INTO accessibility_signals (place_id, user_id, feature, value, review_id)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(place_id, user_id, feature) DO UPDATE SET
         value = excluded.value, review_id = excluded.review_id,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
    ).bind(placeId, userId, feature, value, reviewId));
  }

  return statements;
}

async function assertOwnedPhotos(env: Env, contribution: NormalizedContribution, userId: string, submissionId: string) {
  const keys = contribution.photos.map((photo) => photo.objectKey);
  if (!keys.length) return;
  const placeholders = keys.map(() => "?").join(",");
  const owned = await env.DB.prepare(
    `SELECT object_key FROM media_uploads WHERE owner_user_id = ? AND object_key IN (${placeholders})`,
  ).bind(userId, ...keys).all<{ object_key: string }>();
  assertPhotoOwnership(keys, userId, submissionId, new Set(owned.results.map((row) => row.object_key)));
}

async function personaFor(env: Env, userId: string): Promise<Persona> {
  const profile = await env.DB.prepare(
    `SELECT mobility_aids FROM profiles WHERE user_id = ?`,
  ).bind(userId).first<{ mobility_aids: string }>();
  const aids = profile?.mobility_aids ? JSON.parse(profile.mobility_aids) as string[] : [];
  return aids.includes("Wheelchair") ? "wheelchair" : "secondary";
}

function entranceSummary(point: NormalizedContribution["entrancePasses"][number]["points"][number]): string | null {
  const lines = [
    point.ramp ? `Ramp: ${point.ramp}` : null,
    point.handrail ? `Handrail: ${point.handrail}` : null,
  ].filter((line): line is string => line != null);
  return lines.length ? lines.join("\n") : null;
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
    `SELECT r.*, p.display_name, p.pseudonym, p.avatar_key, p.mobility_aids, pl.name AS place_name
     FROM reviews r
     LEFT JOIN profiles p ON p.user_id = r.user_id
     LEFT JOIN places pl ON pl.id = r.place_id
     WHERE ${where} = ?
     ORDER BY r.created_at DESC
     LIMIT 100`,
  ).bind(value).all<ReviewRow>();
  return result.results;
}

async function relatedRows(env: Env, reviewIds: string[]) {
  const empty = {
    entrances: [] as EntranceRow[],
    photos: [] as PhotoRow[],
    elevators: [] as ElevatorPassRow[],
    toilets: [] as ToiletPassRow[],
    areas: [] as AreaRow[],
    sectionNotes: [] as SectionNoteRow[],
  };
  if (!reviewIds.length) return empty;
  const placeholders = reviewIds.map(() => "?").join(",");
  const [entrances, photos, elevators, toilets, areas, sectionNotes] = await env.DB.batch<
    EntranceRow | PhotoRow | ElevatorPassRow | ToiletPassRow | AreaRow | SectionNoteRow
  >([
    env.DB.prepare(
      `SELECT * FROM review_entrances WHERE review_id IN (${placeholders}) ORDER BY pass_index, sort_order`,
    ).bind(...reviewIds),
    env.DB.prepare(
      `SELECT * FROM review_photos WHERE review_id IN (${placeholders}) ORDER BY sort_order`,
    ).bind(...reviewIds),
    env.DB.prepare(
      `SELECT * FROM review_elevators WHERE review_id IN (${placeholders}) ORDER BY pass_index`,
    ).bind(...reviewIds),
    env.DB.prepare(
      `SELECT * FROM review_toilets WHERE review_id IN (${placeholders}) ORDER BY pass_index`,
    ).bind(...reviewIds),
    env.DB.prepare(
      `SELECT * FROM review_areas WHERE review_id IN (${placeholders})`,
    ).bind(...reviewIds),
    env.DB.prepare(
      `SELECT * FROM review_section_notes WHERE review_id IN (${placeholders})`,
    ).bind(...reviewIds),
  ]);
  return {
    entrances: (entrances?.results ?? []) as EntranceRow[],
    photos: (photos?.results ?? []) as PhotoRow[],
    elevators: (elevators?.results ?? []) as ElevatorPassRow[],
    toilets: (toilets?.results ?? []) as ToiletPassRow[],
    areas: (areas?.results ?? []) as AreaRow[],
    sectionNotes: (sectionNotes?.results ?? []) as SectionNoteRow[],
  };
}

function role(mobilityJson: string | null): string | null {
  const aids = mobilityJson ? JSON.parse(mobilityJson) as string[] : [];
  if (!aids.length) return null;
  return aids.includes("Wheelchair") ? "Wheelchair User" : "Community Contributor";
}

function photoJson(env: Env, photos: PhotoRow[]) {
  const url = (key: string) => `${env.API_BASE_URL}/v1/media/${key}`;
  return photos.map((photo) => ({
    url: url(photo.object_key),
    caption: photo.caption,
    section: photo.section,
    kind: photo.kind,
    question: photo.question,
    pass_index: photo.pass_index,
    location: photo.entrance_location,
  }));
}

function reviewOutput(
  env: Env,
  row: ReviewRow,
  entrances: EntranceRow[],
  photos: PhotoRow[],
  elevators: ElevatorPassRow[] = [],
  toilets: ToiletPassRow[] = [],
  areas: AreaRow[] = [],
  sectionNotes: SectionNoteRow[] = [],
) {
  const facilityPhotos = (facility: Facility) => photos.filter((photo) => photo.facility === facility);
  const url = (key: string) => `${env.API_BASE_URL}/v1/media/${key}`;
  const passPhotos = (section: string, passIndex: number, kind: string, question?: string, location?: string) =>
    photos.filter((photo) => photo.section === section
      && photo.pass_index === passIndex
      && photo.kind === kind
      && (question == null || photo.question === question)
      && (location == null || photo.entrance_location === location));
  const areaRow = (area: string) => areas.find((item) => item.area === area) ?? null;
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
    schema_version: row.schema_version ?? 1,
    persona: row.persona,
    final_text: row.final_text,
    final_photos: photoJson(env, photos.filter((photo) => photo.kind === "final")),
    entrance_passes: row.schema_version === 2 ? entrancePassesJson(env, entrances, passPhotos) : [],
    elevator_passes: elevators.map((pass) => ({
      wide_entrance: pass.wide_entrance,
      space_to_maneuver: pass.space_to_maneuver,
      reachable_buttons: pass.reachable_buttons,
      location: pass.location_text,
      photos: photoJson(env, passPhotos("elevator", pass.pass_index, "section")),
      evidence: {
        wideEntrance: photoJson(env, passPhotos("elevator", pass.pass_index, "evidence", "wideEntrance")),
        spaceToManeuver: photoJson(env, passPhotos("elevator", pass.pass_index, "evidence", "spaceToManeuver")),
        reachableButtons: photoJson(env, passPhotos("elevator", pass.pass_index, "evidence", "reachableButtons")),
      },
    })),
    toilet_passes: toilets.map((pass) => ({
      door: pass.door,
      seat: pass.seat,
      grab_bars: pass.grab_bars,
      space: pass.space,
      sink: pass.sink,
      emergency: pass.emergency,
      location: pass.location_text,
      photos: photoJson(env, passPhotos("toilet", pass.pass_index, "section")),
      evidence: {
        seat: photoJson(env, passPhotos("toilet", pass.pass_index, "evidence", "seat")),
        grabBars: photoJson(env, passPhotos("toilet", pass.pass_index, "evidence", "grabBars")),
        space: photoJson(env, passPhotos("toilet", pass.pass_index, "evidence", "space")),
        sink: photoJson(env, passPhotos("toilet", pass.pass_index, "evidence", "sink")),
        emergency: photoJson(env, passPhotos("toilet", pass.pass_index, "evidence", "emergency")),
      },
    })),
    areas: {
      pathways: areaJson(env, areaRow("pathways"), photos, "pathways"),
      seating: areaJson(env, areaRow("seating"), photos, "seating"),
      parking: areaJson(env, areaRow("parking"), photos, "parking"),
    },
    section_notes: sectionNotesJson(sectionNotes),
  };
}

function sectionNotesJson(notes: SectionNoteRow[]) {
  const text = (section: SectionName) => notes.find((note) => note.section === section)?.text ?? null;
  return {
    entrance: text("entrance"),
    elevator: text("elevator"),
    toilet: text("toilet"),
    pathways: text("pathways"),
    seating: text("seating"),
    parking: text("parking"),
  };
}

function entrancePassesJson(
  env: Env,
  entrances: EntranceRow[],
  passPhotos: (section: string, passIndex: number, kind: string, question?: string, location?: string) => PhotoRow[],
) {
  const indexes = [...new Set(entrances.map((entrance) => entrance.pass_index ?? 0))].sort((a, b) => a - b);
  return indexes.map((passIndex) => ({
    photos: photoJson(env, passPhotos("entrance", passIndex, "section")),
    points: entrances.filter((entrance) => (entrance.pass_index ?? 0) === passIndex).map((entrance) => ({
      location: entrance.location,
      tags: JSON.parse(entrance.tags || "[]") as string[],
      ramp: entrance.ramp_answer,
      handrail: entrance.handrail_answer,
      evidence: {
        ramp: photoJson(env, passPhotos("entrance", passIndex, "evidence", "ramp", entrance.location)),
        handrail: photoJson(env, passPhotos("entrance", passIndex, "evidence", "handrail", entrance.location)),
      },
    })),
  }));
}

function areaJson(env: Env, row: AreaRow | null, photos: PhotoRow[], section: string) {
  if (!row) return null;
  return {
    answer: row.answer,
    notices: JSON.parse(row.notices || "[]") as string[],
    photos: photoJson(env, photos.filter((photo) => photo.section === section && photo.kind === "section")),
  };
}

export async function handlePlaceReviews(request: Request, env: Env, encodedPlaceKey: string): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const placeId = await findPlaceId(env, encodedPlaceKey);
  if (!placeId) return json({ status: "ok", reviews: [] });
  const rows = await reviewRows(env, "r.place_id", placeId);
  const related = await relatedRows(env, rows.map((row) => row.id));
  return json({
    status: "ok",
    reviews: rows.map((row) => reviewOutput(
      env,
      row,
      related.entrances.filter((entrance) => entrance.review_id === row.id),
      related.photos.filter((photo) => photo.review_id === row.id),
      related.elevators.filter((pass) => pass.review_id === row.id),
      related.toilets.filter((pass) => pass.review_id === row.id),
      related.areas.filter((area) => area.review_id === row.id),
      related.sectionNotes.filter((note) => note.review_id === row.id),
    )),
  });
}

export async function handleReviewPhotos(request: Request, env: Env, encodedPlaceKey: string): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const placeId = await findPlaceId(env, encodedPlaceKey);
  if (!placeId) return json({ status: "ok", placeId: null, photos: [] });
  const rows = await reviewRows(env, "r.place_id", placeId);
  const related = await relatedRows(env, rows.map((row) => row.id));
  const label: Record<string, string> = {
    lobby: "Lobby", basement: "Basement", elevator: "Elevator", toilet: "Toilet", exit_side: "Exit side", other: "Other",
    pathways: "Outdoor Pathways", seating: "Seating", parking: "Accessible Parking", general: "Review",
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
    const areas = related.areas.filter((entry) => entry.review_id === row.id);
    const features = new Set<string>();
    for (const entrance of entrances) {
      const tags = JSON.parse(entrance.tags || "[]") as string[];
      if (entrance.has_dropoff_ramp === 1 || tags.includes("ramp")) features.add("Ramp");
      if (entrance.has_rails === 1 || tags.includes("handrail")) features.add("Handrail");
      if (entrance.door_type === "automatic" || tags.includes("automatic_doors")) features.add("Automatic Doors");
      if (entrance.door_type === "manual" || tags.includes("manual_doors")) features.add("Manual Doors");
      if (tags.includes("security_assistance")) features.add("Security Assistance");
      if (tags.includes("wheelchairs_available")) features.add("Wheelchairs Available");
      if (tags.includes("disabled_parking")) features.add("Disabled Parking");
    }
    if (row.elevator_exists === 1) features.add("Elevator");
    if (row.has_disabled_toilet === 1) features.add("Toilet");
    if (areas.some((area) => area.area === "pathways")) features.add("Outdoor Pathways");
    if (areas.some((area) => area.area === "seating" && area.answer === "yes")) features.add("Seating");
    if (areas.some((area) => area.area === "parking" && area.answer === "yes")) features.add("Accessible Parking");
    const photoUrls = photos.map((photo) => `${env.API_BASE_URL}/v1/media/${photo.object_key}`);
    return {
      id: row.id,
      placeId: row.place_id,
      placeName: row.place_name ?? "Place",
      editable: row.schema_version === 2,
      createdAt: row.created_at,
      reviewText: row.final_text?.trim() || row.notes?.trim() || "No review notes written.",
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
  if (request.method === "GET") {
    const rows = await reviewRows(env, "r.id", reviewId);
    const row = rows[0];
    if (!row) throw new HttpError(404, "Review not found.");
    const related = await relatedRows(env, [reviewId]);
    return json({
      status: "ok",
      placeId: row.place_id,
      review: reviewOutput(
        env,
        row,
        related.entrances.filter((entrance) => entrance.review_id === reviewId),
        related.photos.filter((photo) => photo.review_id === reviewId),
        related.elevators.filter((pass) => pass.review_id === reviewId),
        related.toilets.filter((pass) => pass.review_id === reviewId),
        related.areas.filter((area) => area.review_id === reviewId),
        related.sectionNotes.filter((note) => note.review_id === reviewId),
      ),
    });
  }
  if (request.method === "PUT") return updateContribution(request, env, auth, reviewId);
  if (request.method !== "DELETE") return methodNotAllowed("GET", "PUT", "DELETE");
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

interface OwnedReview {
  id: string;
  place_id: string;
  submission_id: string;
  schema_version: number;
  persona: Persona | null;
  final_text: string | null;
  place_name: string | null;
}

async function ownedReview(env: Env, userId: string, reviewId: string): Promise<OwnedReview> {
  const review = await env.DB.prepare(
    `SELECT r.id, r.place_id, r.submission_id, r.schema_version, r.persona, r.final_text, pl.name AS place_name
     FROM reviews r LEFT JOIN places pl ON pl.id = r.place_id
     WHERE r.id = ? AND r.user_id = ?`,
  ).bind(reviewId, userId).first<OwnedReview>();
  if (!review) throw new HttpError(404, "Review not found.");
  if (review.schema_version !== 2) {
    throw new HttpError(409, "This review was written in an older version of the app and can't be edited.", "not_editable");
  }
  return review;
}

/**
 * GET /v1/reviews/:id/edit: the owner's review as the same v2 body POST /v1/reviews takes, so the app
 * can change answers and PUT it back. Photos keep their media URLs; new ones upload under `submissionId`.
 */
export async function handleReviewForEdit(request: Request, env: Env, auth: Auth, reviewId: string): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const userId = await requireUserId(auth, request);
  const review = await ownedReview(env, userId, reviewId);
  const related = await relatedRows(env, [reviewId]);
  return json({
    status: "ok",
    reviewId,
    placeId: review.place_id,
    placeName: review.place_name ?? "Place",
    submission: submissionBody(env, review, related),
  });
}

function submissionBody(env: Env, review: OwnedReview, related: Awaited<ReturnType<typeof relatedRows>>) {
  const ref = (photo: PhotoRow) => ({ url: `${env.API_BASE_URL}/v1/media/${photo.object_key}`, caption: photo.caption });
  const photos = (section: string, passIndex: number | null, kind: string, question?: string, location?: string) =>
    related.photos
      .filter((photo) => photo.section === section
        && (passIndex == null || photo.pass_index === passIndex)
        && photo.kind === kind
        && (question == null || photo.question === question)
        && (location == null || photo.entrance_location === location))
      .map(ref);
  const evidence = (groups: Record<string, ReturnType<typeof photos>>) =>
    Object.fromEntries(Object.entries(groups).filter(([, group]) => group.length));
  const notes = (section: SectionName) => related.sectionNotes.find((note) => note.section === section)?.text ?? null;
  const area = (name: string) => related.areas.find((row) => row.area === name) ?? null;

  const entranceIndexes = [...new Set(related.entrances.map((row) => row.pass_index))].sort((a, b) => a - b);
  const pathways = area("pathways");
  const seating = area("seating");
  const parking = area("parking");
  const finalPhotos = related.photos.filter((photo) => photo.kind === "final").map(ref);
  return {
    version: 2,
    submissionId: review.submission_id,
    placeId: review.place_id,
    persona: review.persona ?? "wheelchair",
    entrance: entranceIndexes.length ? {
      notes: notes("entrance"),
      passes: entranceIndexes.map((passIndex) => ({
        photos: photos("entrance", passIndex, "section"),
        points: related.entrances.filter((row) => row.pass_index === passIndex).map((row) => ({
          location: row.location,
          tags: JSON.parse(row.tags || "[]") as string[],
          ramp: row.ramp_answer,
          handrail: row.handrail_answer,
          evidence: evidence({
            ramp: photos("entrance", passIndex, "evidence", "ramp", row.location),
            handrail: photos("entrance", passIndex, "evidence", "handrail", row.location),
          }),
        })),
      })),
    } : null,
    elevator: related.elevators.length ? {
      notes: notes("elevator"),
      passes: related.elevators.map((pass) => ({
        photos: photos("elevator", pass.pass_index, "section"),
        wideEntrance: pass.wide_entrance,
        spaceToManeuver: pass.space_to_maneuver,
        reachableButtons: pass.reachable_buttons,
        location: pass.location_text,
        evidence: evidence({
          wideEntrance: photos("elevator", pass.pass_index, "evidence", "wideEntrance"),
          spaceToManeuver: photos("elevator", pass.pass_index, "evidence", "spaceToManeuver"),
          reachableButtons: photos("elevator", pass.pass_index, "evidence", "reachableButtons"),
        }),
      })),
    } : null,
    toilet: related.toilets.length ? {
      notes: notes("toilet"),
      passes: related.toilets.map((pass) => ({
        photos: photos("toilet", pass.pass_index, "section"),
        door: pass.door,
        seat: pass.seat,
        grabBars: pass.grab_bars,
        space: pass.space,
        sink: pass.sink,
        emergency: pass.emergency,
        location: pass.location_text,
        evidence: evidence(Object.fromEntries(
          ["seat", "grabBars", "space", "sink", "emergency"].map((question) => [question, photos("toilet", pass.pass_index, "evidence", question)]),
        )),
      })),
    } : null,
    pathways: pathways ? {
      notes: notes("pathways"),
      notices: JSON.parse(pathways.notices || "[]") as string[],
      photos: photos("pathways", null, "section"),
    } : null,
    seating: seating?.answer ? { notes: notes("seating"), answer: seating.answer, photos: photos("seating", null, "section") } : null,
    parking: parking?.answer ? { notes: notes("parking"), answer: parking.answer, photos: photos("parking", null, "section") } : null,
    final: review.final_text || finalPhotos.length ? { text: review.final_text, photos: finalPhotos } : null,
  };
}

/**
 * PUT /v1/reviews/:id: replaces the owner's answers, notes and photos with a v2 body, keeping the
 * review's id and date. Photos dropped from the body are deleted from storage.
 */
async function updateContribution(request: Request, env: Env, auth: Auth, reviewId: string): Promise<Response> {
  const userId = await requireUserId(auth, request);
  const review = await ownedReview(env, userId, reviewId);
  const body = await readJson<ReviewPayload>(request);
  const contribution = parseContributionV2(body, `${env.API_BASE_URL}/v1/media/`);
  // New photos upload under the review's original submission, so ownership is checked against it.
  await assertOwnedPhotos(env, contribution, userId, review.submission_id);
  const persona = contribution.persona ?? review.persona ?? await personaFor(env, userId);
  const legacy = contribution.legacy;
  const kept = new Set(contribution.photos.map((photo) => photo.objectKey));
  const previous = await env.DB.prepare(
    `SELECT object_key FROM review_photos WHERE review_id = ?`,
  ).bind(reviewId).all<{ object_key: string }>();
  const removed = previous.results.map((row) => row.object_key).filter((key) => !kept.has(key));

  const statements: D1PreparedStatement[] = [
    env.DB.prepare(`DELETE FROM accessibility_signals WHERE review_id = ?`).bind(reviewId),
    env.DB.prepare(`DELETE FROM review_entrances WHERE review_id = ?`).bind(reviewId),
    env.DB.prepare(`DELETE FROM review_elevators WHERE review_id = ?`).bind(reviewId),
    env.DB.prepare(`DELETE FROM review_toilets WHERE review_id = ?`).bind(reviewId),
    env.DB.prepare(`DELETE FROM review_areas WHERE review_id = ?`).bind(reviewId),
    env.DB.prepare(`DELETE FROM review_section_notes WHERE review_id = ?`).bind(reviewId),
    env.DB.prepare(`DELETE FROM review_photos WHERE review_id = ?`).bind(reviewId),
    env.DB.prepare(
      `UPDATE reviews SET
        notes = ?, persona = ?, final_text = ?,
        elevator_exists = ?, elevator_wheelchair_accessible = ?, elevator_blockers = ?,
        elevator_review_text = ?, has_disabled_toilet = ?, toilet_review_text = ?,
        updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
       WHERE id = ? AND user_id = ?`,
    ).bind(
      legacy.notes, persona, contribution.finalText,
      legacy.elevatorExists === null ? null : Number(legacy.elevatorExists),
      legacy.elevatorAccessible === null ? null : Number(legacy.elevatorAccessible),
      JSON.stringify(legacy.elevatorBlockers),
      legacy.elevatorText,
      legacy.hasDisabledToilet === null ? null : Number(legacy.hasDisabledToilet),
      legacy.toiletText,
      reviewId, userId,
    ),
    ...contributionRows(env, reviewId, review.place_id, userId, contribution),
    ...removed.map((key) => env.DB.prepare(`DELETE FROM media_uploads WHERE object_key = ?`).bind(key)),
  ];
  await env.DB.batch(statements);
  await Promise.all(removed.map((key) => env.MEDIA.delete(key)));
  return json({ status: "ok", reviewId, placeId: review.place_id, grade: await loadGrade(env, review.place_id) });
}
