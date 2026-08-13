// supabase/functions/submit-accessibility-review/index.ts
//
// Owner 3 — Community & Route Data. Accepts the iPhone accessibility
// contribution payload (entrances / elevator / toilet), writes flattened
// columns on reviews + review_entrances rows, derives grade signals, and
// returns the live accessibility_grade(). See docs/specs.md §4.5.
//
// TODO: re-enable auth before production — JWT is intentionally skipped
// for device testing; inserts use user_id = null via service_role.
//
// Request body:
// {
//   appleMapsId: string,
//   lat: number,
//   lng: number,
//   entrances?: EntranceReport[],
//   elevator?: ElevatorReport | null,
//   toilet?: ToiletReport | null
// }
//
// Response: { status: "ok", reviewId, placeId, grade }

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

type AccessibilityValue = "yes" | "no" | "limited" | "unknown";

interface Review {
  text?: string | null;
  photoUrls?: string[] | null;
}

interface EntranceReport {
  location: "lobby" | "basement" | "exit_side" | "other";
  hasDropoffRamp?: boolean | null;
  hasRails?: boolean | null;
  doorType?: "manual" | "automatic" | null;
  isWideEnough?: boolean | null;
  review?: Review | null;
}

interface ElevatorReport {
  exists?: boolean | null;
  wheelchairAccessible?: boolean | null;
  blockers?: Array<"no_ramp" | "too_small"> | null;
  review?: Review | null;
}

interface ToiletReport {
  hasDisabledToilet?: boolean | null;
  review?: Review | null;
}

interface RequestBody {
  appleMapsId?: unknown;
  lat?: unknown;
  lng?: unknown;
  entrances?: EntranceReport[] | null;
  elevator?: ElevatorReport | null;
  toilet?: ToiletReport | null;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // TODO: re-enable auth before production — verify Authorization JWT and
  // set user_id from auth.getUser(); for now anon inserts with user_id null.
  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const { appleMapsId, lat, lng } = body;
  if (typeof appleMapsId !== "string" || appleMapsId.length === 0) {
    return json({ error: "appleMapsId is required" }, 400);
  }
  if (typeof lat !== "number" || typeof lng !== "number") {
    return json({ error: "lat and lng are required numbers" }, 400);
  }

  const entrances = normalizeEntrances(body.entrances);
  const elevator = normalizeElevator(body.elevator);
  const toilet = normalizeToilet(body.toilet);

  const placeId = canonicalPlaceId(lat, lng);
  const entranceAccessible = deriveEntrance(entrances);
  const restroomAccessible = deriveToilet(toilet);
  const elevatorAccessible = deriveElevator(elevator);

  const { data: review, error: insertError } = await supabase
    .from("reviews")
    .insert({
      user_id: null, // TODO: re-enable auth — set from JWT
      place_id: placeId,
      apple_maps_id: appleMapsId,
      lat,
      lng,
      elevator_exists: elevator?.exists ?? null,
      elevator_wheelchair_accessible: elevator?.wheelchairAccessible ?? null,
      elevator_blockers: elevator?.blockers ?? [],
      elevator_review_text: elevator?.review?.text ?? null,
      elevator_photo_urls: elevator?.review?.photoUrls ?? [],
      has_disabled_toilet: toilet?.hasDisabledToilet ?? null,
      toilet_review_text: toilet?.review?.text ?? null,
      toilet_photo_urls: toilet?.review?.photoUrls ?? [],
      entrance_accessible: entranceAccessible,
      restroom_accessible: restroomAccessible,
      elevator_accessible: elevatorAccessible,
      notes: collectNotes(entrances, elevator, toilet),
    })
    .select("id")
    .single();

  if (insertError || !review) {
    console.error("review insert failed:", insertError);
    return json({ error: "failed to save review", detail: insertError?.message }, 500);
  }

  if (entrances.length > 0) {
    const entranceRows = entrances.map((e, i) => ({
      review_id: review.id,
      location: e.location,
      has_dropoff_ramp: e.hasDropoffRamp,
      has_rails: e.hasRails,
      door_type: e.doorType,
      is_wide_enough: e.isWideEnough,
      review_text: e.review?.text ?? null,
      photo_urls: e.review?.photoUrls ?? [],
      sort_order: i,
    }));

    const { error: entrancesError } = await supabase
      .from("review_entrances")
      .insert(entranceRows);

    if (entrancesError) {
      console.error("review_entrances insert failed:", entrancesError);
      await supabase.from("reviews").delete().eq("id", review.id);
      return json({
        error: "failed to save entrance details",
        detail: entrancesError.message,
      }, 500);
    }
  }

  const { data: grade } = await supabase.rpc("accessibility_grade", {
    target_place_id: placeId,
  });

  return json({
    status: "ok",
    reviewId: review.id,
    placeId,
    grade: grade ?? [],
  });
});

// --- identity ---------------------------------------------------------------

function canonicalPlaceId(lat: number, lng: number): string {
  return `loc_${lat.toFixed(5)}_${lng.toFixed(5)}`;
}

// --- normalize / null rules -------------------------------------------------

function normalizeReview(review: Review | null | undefined): Review | null {
  if (review == null) return null;
  const text = typeof review.text === "string" && review.text.trim().length > 0
    ? review.text.trim()
    : null;
  const photoUrls = Array.isArray(review.photoUrls)
    ? review.photoUrls.filter((u): u is string => typeof u === "string" && u.length > 0)
    : [];
  if (text == null && photoUrls.length === 0) return null;
  return { text, photoUrls };
}

function normalizeEntrances(raw: EntranceReport[] | null | undefined): EntranceReport[] {
  if (!Array.isArray(raw)) return [];
  const allowed = new Set(["lobby", "basement", "exit_side", "other"]);
  return raw
    .filter((e) => e && typeof e.location === "string" && allowed.has(e.location))
    .map((e) => ({
      location: e.location,
      hasDropoffRamp: boolOrNull(e.hasDropoffRamp),
      hasRails: boolOrNull(e.hasRails),
      doorType: e.doorType === "manual" || e.doorType === "automatic" ? e.doorType : null,
      isWideEnough: boolOrNull(e.isWideEnough),
      review: normalizeReview(e.review),
    }));
}

function normalizeElevator(raw: ElevatorReport | null | undefined): ElevatorReport | null {
  if (raw == null || typeof raw !== "object") return null;
  const exists = boolOrNull(raw.exists);
  const wheelchairAccessible = exists === true ? boolOrNull(raw.wheelchairAccessible) : null;
  let blockers: Array<"no_ramp" | "too_small"> = [];
  if (wheelchairAccessible === false && Array.isArray(raw.blockers)) {
    blockers = raw.blockers.filter((b): b is "no_ramp" | "too_small" =>
      b === "no_ramp" || b === "too_small"
    );
  }
  // Strip blockers when accessible or unknown.
  if (wheelchairAccessible !== false) blockers = [];
  return {
    exists,
    wheelchairAccessible: exists === false ? null : wheelchairAccessible,
    blockers,
    review: normalizeReview(raw.review),
  };
}

function normalizeToilet(raw: ToiletReport | null | undefined): ToiletReport | null {
  if (raw == null || typeof raw !== "object") return null;
  return {
    hasDisabledToilet: boolOrNull(raw.hasDisabledToilet),
    review: normalizeReview(raw.review),
  };
}

function boolOrNull(v: unknown): boolean | null {
  return typeof v === "boolean" ? v : null;
}

// --- derive grade signals ---------------------------------------------------

function deriveEntrance(entrances: EntranceReport[]): AccessibilityValue | null {
  if (entrances.length === 0) return null;

  const answered = entrances.filter((e) =>
    e.hasDropoffRamp !== null || e.isWideEnough !== null
  );
  if (answered.length === 0) return null;

  const values = answered.map((e) => {
    if (e.hasDropoffRamp === true && e.isWideEnough === true) return "yes" as const;
    if (e.hasDropoffRamp === false || e.isWideEnough === false) return "no" as const;
    // Only one of the deciding fields answered — treat as limited if the
    // answered one is positive, otherwise no.
    if (e.hasDropoffRamp === true || e.isWideEnough === true) return "limited" as const;
    return "no" as const;
  });

  if (values.every((v) => v === "yes")) return "yes";
  if (values.every((v) => v === "no")) return "no";
  return "limited";
}

function deriveElevator(elevator: ElevatorReport | null): AccessibilityValue | null {
  if (!elevator || elevator.exists === null) return null;
  if (elevator.exists === false) return "no";
  if (elevator.wheelchairAccessible === true) return "yes";
  if (elevator.wheelchairAccessible === false) return "no";
  // exists true but access unanswered — write nothing yet
  return null;
}

function deriveToilet(toilet: ToiletReport | null): AccessibilityValue | null {
  if (!toilet || toilet.hasDisabledToilet === null) return null;
  return toilet.hasDisabledToilet ? "yes" : "no";
}

function collectNotes(
  entrances: EntranceReport[],
  elevator: ElevatorReport | null,
  toilet: ToiletReport | null,
): string | null {
  const parts: string[] = [];
  for (const e of entrances) {
    if (e.review?.text) parts.push(`[entrance:${e.location}] ${e.review.text}`);
  }
  if (elevator?.review?.text) parts.push(`[elevator] ${elevator.review.text}`);
  if (toilet?.review?.text) parts.push(`[toilet] ${toilet.review.text}`);
  return parts.length > 0 ? parts.join("\n") : null;
}

// --- helpers ----------------------------------------------------------------

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
