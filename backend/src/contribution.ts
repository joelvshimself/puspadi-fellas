import { HttpError } from "./http";

/** Photos on the optional "Take or upload a photo" screen of one pass or area. */
export const SECTION_PHOTOS_PER_PASS = 5;
/** "Not sure" evidence photos, summed across every question of one pass. */
export const EVIDENCE_PHOTOS_PER_PASS = 3;
export const FINAL_PHOTOS = 5;
export const MAX_PASSES = 10;
export const MAX_PHOTOS_PER_REVIEW = 60;
const LOCATION_MAX = 200;
const TEXT_MAX = 4_000;
const CAPTION_MAX = 500;

export type Persona = "wheelchair" | "secondary";
export type Grade = "yes" | "no" | "limited";
export type Tri = "yes" | "no" | "not_sure";
export type EntranceLocation = "lobby" | "basement";

const LOBBY_TAGS = [
  "ramp", "handrail", "automatic_doors", "manual_doors", "security_assistance", "wheelchairs_available",
] as const;
const BASEMENT_TAGS = ["elevator", "disabled_parking", "ramp", "handrail", "security_assistance"] as const;
const RAMP = ["yes", "with_push", "too_steep", "not_sure"] as const;
const HANDRAIL = ["yes", "with_effort", "no", "not_sure"] as const;
const TRI = ["yes", "no", "not_sure"] as const;
const DOOR = ["manual", "sliding", "automatic"] as const;
const SEAT = ["yes", "too_low", "too_high", "not_sure"] as const;
const GRAB = ["yes", "awkward", "no", "not_sure"] as const;
const EMERGENCY = ["yes", "no", "not_sure", "none"] as const;
const NOTICES = [
  "loose_surface", "rough_surface", "tight_gap", "narrow_path", "steep_section", "curb_no_ramp", "nothing_notable",
] as const;
const AREA_ANSWER = ["yes", "no", "not_sure"] as const;

export interface PhotoRef {
  objectKey: string;
  caption: string;
}

export interface StoredPhoto extends PhotoRef {
  facility: string;
  section: string;
  passIndex: number | null;
  entranceLocation: EntranceLocation | null;
  kind: "section" | "evidence" | "final";
  question: string | null;
  sortOrder: number;
}

export interface EntrancePoint {
  location: EntranceLocation;
  tags: string[];
  ramp: (typeof RAMP)[number] | null;
  handrail: (typeof HANDRAIL)[number] | null;
  evidence: { ramp: PhotoRef[]; handrail: PhotoRef[] };
}

export interface EntrancePass {
  photos: PhotoRef[];
  points: EntrancePoint[];
}

export interface ElevatorPass {
  photos: PhotoRef[];
  wideEntrance: Tri;
  spaceToManeuver: Tri | null;
  reachableButtons: Tri | null;
  location: string | null;
  evidence: { wideEntrance: PhotoRef[]; spaceToManeuver: PhotoRef[]; reachableButtons: PhotoRef[] };
}

export interface ToiletPass {
  photos: PhotoRef[];
  door: (typeof DOOR)[number];
  seat: (typeof SEAT)[number];
  grabBars: (typeof GRAB)[number];
  space: Tri;
  sink: Tri;
  emergency: (typeof EMERGENCY)[number];
  location: string | null;
  evidence: {
    seat: PhotoRef[];
    grabBars: PhotoRef[];
    space: PhotoRef[];
    sink: PhotoRef[];
    emergency: PhotoRef[];
  };
}

export const SECTION_NAMES = ["entrance", "elevator", "toilet", "pathways", "seating", "parking"] as const;
export type SectionName = (typeof SECTION_NAMES)[number];
export type SectionNotes = Record<SectionName, string | null>;

export interface NormalizedContribution {
  persona: Persona | null;
  entrancePasses: EntrancePass[];
  elevatorPasses: ElevatorPass[];
  toiletPasses: ToiletPass[];
  pathways: { notices: string[]; photos: PhotoRef[] } | null;
  seating: { answer: (typeof AREA_ANSWER)[number]; photos: PhotoRef[] } | null;
  parking: { answer: (typeof AREA_ANSWER)[number]; photos: PhotoRef[] } | null;
  sectionNotes: SectionNotes;
  finalText: string | null;
  finalPhotos: PhotoRef[];
  photos: StoredPhoto[];
  signals: { entrance: Grade | null; elevator: Grade | null; restroom: Grade | null };
  /** Columns the v1 read model still expects. */
  legacy: {
    notes: string | null;
    elevatorExists: boolean | null;
    elevatorAccessible: boolean | null;
    elevatorBlockers: string[];
    elevatorText: string | null;
    hasDisabledToilet: boolean | null;
    toiletText: string | null;
  };
}

export function parseContributionV2(body: unknown, mediaPrefix: string): NormalizedContribution {
  const root = object(body, "body");
  const persona = optionalEnum(root.persona, ["wheelchair", "secondary"] as const, "persona");
  const seen = new Set<string>();
  const photos: StoredPhoto[] = [];

  const entrance = parseEntrance(root.entrance, mediaPrefix, seen, photos);
  const elevator = parseElevator(root.elevator, mediaPrefix, seen, photos);
  const toilet = parseToilet(root.toilet, mediaPrefix, seen, photos);
  const pathways = parsePathways(root.pathways, mediaPrefix, seen, photos);
  const seating = parseAnswerArea(root.seating, "seating", mediaPrefix, seen, photos);
  const parking = parseAnswerArea(root.parking, "parking", mediaPrefix, seen, photos);
  const final = parseFinal(root.final, mediaPrefix, seen, photos);
  const entrancePasses = entrance.passes;
  const elevatorPasses = elevator.passes;
  const toiletPasses = toilet.passes;
  const sectionNotes: SectionNotes = {
    entrance: entrance.notes,
    elevator: elevator.notes,
    toilet: toilet.notes,
    pathways: pathways?.notes ?? null,
    seating: seating?.notes ?? null,
    parking: parking?.notes ?? null,
  };

  const sections = [
    entrancePasses.length ? entrancePasses : null,
    elevatorPasses.length ? elevatorPasses : null,
    toiletPasses.length ? toiletPasses : null,
    pathways,
    seating,
    parking,
  ].filter(Boolean);
  if (!sections.length) {
    throw new HttpError(400, "At least one completed section is required.", "section_required");
  }
  if (photos.length > MAX_PHOTOS_PER_REVIEW) {
    throw new HttpError(400, `A review can include at most ${MAX_PHOTOS_PER_REVIEW} photos.`, "too_many_photos");
  }

  const signals = {
    entrance: best(entrancePasses.flatMap((pass) => pass.points.map(gradeEntrancePoint))),
    elevator: best(elevatorPasses.map(gradeElevator)),
    restroom: best(toiletPasses.map(gradeToilet)),
  };

  return {
    persona,
    entrancePasses,
    elevatorPasses,
    toiletPasses,
    pathways,
    seating,
    parking,
    sectionNotes,
    finalText: final.text,
    finalPhotos: final.photos,
    photos,
    signals,
    legacy: legacyProjection({
      entrancePasses, elevatorPasses, toiletPasses, pathways, seating, parking, sectionNotes, finalText: final.text, signals,
    }),
  };
}

function parseEntrance(
  value: unknown,
  mediaPrefix: string,
  seen: Set<string>,
  photos: StoredPhoto[],
): { passes: EntrancePass[]; notes: string | null } {
  if (value == null) return { passes: [], notes: null };
  const root = object(value, "entrance");
  const notes = optionalText(root.notes, "entrance.notes", TEXT_MAX);
  const passes = array(root.passes, "entrance.passes");
  if (!passes.length || passes.length > MAX_PASSES) {
    throw new HttpError(400, `entrance.passes must contain 1 to ${MAX_PASSES} passes.`, "invalid_section");
  }
  const parsed = passes.map((raw, passIndex) => {
    const pass = object(raw, `entrance.passes[${passIndex}]`);
    const sectionPhotos = takePhotos(pass.photos, `entrance.passes[${passIndex}].photos`, SECTION_PHOTOS_PER_PASS, mediaPrefix, seen);
    pushPhotos(photos, sectionPhotos, {
      facility: "other",
      section: "entrance",
      passIndex,
      entranceLocation: null,
      kind: "section",
      question: null,
    });
    const pointsRaw = array(pass.points, `entrance.passes[${passIndex}].points`);
    if (!pointsRaw.length || pointsRaw.length > 2) {
      throw new HttpError(400, `entrance.passes[${passIndex}] needs one or two locations.`, "invalid_section");
    }
    const locations = new Set<string>();
    let evidenceLeft = EVIDENCE_PHOTOS_PER_PASS;
    const points = pointsRaw.map((pointRaw, pointIndex) => {
      const field = `entrance.passes[${passIndex}].points[${pointIndex}]`;
      const point = object(pointRaw, field);
      const location = requiredEnum(point.location, ["lobby", "basement"] as const, `${field}.location`);
      if (locations.has(location)) throw new HttpError(400, `${field} repeats ${location}.`, "invalid_section");
      locations.add(location);
      const allowed = location === "lobby" ? LOBBY_TAGS : BASEMENT_TAGS;
      const tags = stringList(point.tags, `${field}.tags`, allowed);
      if (!tags.length) throw new HttpError(400, `${field}.tags needs at least one tag.`, "invalid_section");
      const ramp = tags.includes("ramp")
        ? requiredEnum(point.ramp, RAMP, `${field}.ramp`)
        : absent(point.ramp, `${field}.ramp`);
      const handrail = tags.includes("handrail")
        ? requiredEnum(point.handrail, HANDRAIL, `${field}.handrail`)
        : absent(point.handrail, `${field}.handrail`);
      const evidence = parseEvidence(point.evidence, `${field}.evidence`, { ramp, handrail }, ["ramp", "handrail"], mediaPrefix, seen, () => evidenceLeft, (used) => {
        evidenceLeft -= used;
      });
      const rampPhotos = evidence.ramp ?? [];
      const handrailPhotos = evidence.handrail ?? [];
      for (const [question, group] of [["ramp", rampPhotos], ["handrail", handrailPhotos]] as const) {
        pushPhotos(photos, group, {
          facility: location,
          section: "entrance",
          passIndex,
          entranceLocation: location,
          kind: "evidence",
          question,
        });
      }
      return { location, tags, ramp, handrail, evidence: { ramp: rampPhotos, handrail: handrailPhotos } };
    });
    // Legacy galleries still key photos by lobby/basement. The first point carries the pass photos there.
    for (const photo of photos) {
      if (photo.section === "entrance" && photo.passIndex === passIndex && photo.kind === "section") {
        photo.facility = points[0]!.location;
      }
    }
    return { photos: sectionPhotos, points };
  });
  return { passes: parsed, notes };
}

function parseElevator(
  value: unknown,
  mediaPrefix: string,
  seen: Set<string>,
  photos: StoredPhoto[],
): { passes: ElevatorPass[]; notes: string | null } {
  if (value == null) return { passes: [], notes: null };
  const root = object(value, "elevator");
  const notes = optionalText(root.notes, "elevator.notes", TEXT_MAX);
  const passes = array(root.passes, "elevator.passes");
  if (!passes.length || passes.length > MAX_PASSES) {
    throw new HttpError(400, `elevator.passes must contain 1 to ${MAX_PASSES} passes.`, "invalid_section");
  }
  const parsed = passes.map((raw, passIndex) => {
    const field = `elevator.passes[${passIndex}]`;
    const pass = object(raw, field);
    const sectionPhotos = takePhotos(pass.photos, `${field}.photos`, SECTION_PHOTOS_PER_PASS, mediaPrefix, seen);
    pushPhotos(photos, sectionPhotos, {
      facility: "elevator", section: "elevator", passIndex, entranceLocation: null, kind: "section", question: null,
    });
    const wideEntrance = requiredEnum(pass.wideEntrance, TRI, `${field}.wideEntrance`);
    const skipped = wideEntrance === "no";
    const spaceToManeuver = skipped
      ? absent(pass.spaceToManeuver, `${field}.spaceToManeuver`)
      : requiredEnum(pass.spaceToManeuver, TRI, `${field}.spaceToManeuver`);
    const reachableButtons = skipped
      ? absent(pass.reachableButtons, `${field}.reachableButtons`)
      : requiredEnum(pass.reachableButtons, TRI, `${field}.reachableButtons`);
    const location = optionalText(pass.location, `${field}.location`, LOCATION_MAX);
    let evidenceLeft = EVIDENCE_PHOTOS_PER_PASS;
    const evidence = parseEvidence(
      pass.evidence,
      `${field}.evidence`,
      { wideEntrance, spaceToManeuver, reachableButtons },
      ["wideEntrance", "spaceToManeuver", "reachableButtons"],
      mediaPrefix,
      seen,
      () => evidenceLeft,
      (used) => { evidenceLeft -= used; },
    );
    const grouped = {
      wideEntrance: evidence.wideEntrance ?? [],
      spaceToManeuver: evidence.spaceToManeuver ?? [],
      reachableButtons: evidence.reachableButtons ?? [],
    };
    for (const question of ["wideEntrance", "spaceToManeuver", "reachableButtons"] as const) {
      pushPhotos(photos, grouped[question], {
        facility: "elevator", section: "elevator", passIndex, entranceLocation: null, kind: "evidence", question,
      });
    }
    return { photos: sectionPhotos, wideEntrance, spaceToManeuver, reachableButtons, location, evidence: grouped };
  });
  return { passes: parsed, notes };
}

function parseToilet(
  value: unknown,
  mediaPrefix: string,
  seen: Set<string>,
  photos: StoredPhoto[],
): { passes: ToiletPass[]; notes: string | null } {
  if (value == null) return { passes: [], notes: null };
  const root = object(value, "toilet");
  const notes = optionalText(root.notes, "toilet.notes", TEXT_MAX);
  const passes = array(root.passes, "toilet.passes");
  if (!passes.length || passes.length > MAX_PASSES) {
    throw new HttpError(400, `toilet.passes must contain 1 to ${MAX_PASSES} passes.`, "invalid_section");
  }
  const parsed = passes.map((raw, passIndex) => {
    const field = `toilet.passes[${passIndex}]`;
    const pass = object(raw, field);
    const sectionPhotos = takePhotos(pass.photos, `${field}.photos`, SECTION_PHOTOS_PER_PASS, mediaPrefix, seen);
    pushPhotos(photos, sectionPhotos, {
      facility: "toilet", section: "toilet", passIndex, entranceLocation: null, kind: "section", question: null,
    });
    const door = requiredEnum(pass.door, DOOR, `${field}.door`);
    const seat = requiredEnum(pass.seat, SEAT, `${field}.seat`);
    const grabBars = requiredEnum(pass.grabBars, GRAB, `${field}.grabBars`);
    const space = requiredEnum(pass.space, TRI, `${field}.space`);
    const sink = requiredEnum(pass.sink, TRI, `${field}.sink`);
    const emergency = requiredEnum(pass.emergency, EMERGENCY, `${field}.emergency`);
    const location = optionalText(pass.location, `${field}.location`, LOCATION_MAX);
    let evidenceLeft = EVIDENCE_PHOTOS_PER_PASS;
    const evidence = parseEvidence(
      pass.evidence,
      `${field}.evidence`,
      { seat, grabBars, space, sink, emergency },
      ["seat", "grabBars", "space", "sink", "emergency"],
      mediaPrefix,
      seen,
      () => evidenceLeft,
      (used) => { evidenceLeft -= used; },
    );
    const grouped = {
      seat: evidence.seat ?? [],
      grabBars: evidence.grabBars ?? [],
      space: evidence.space ?? [],
      sink: evidence.sink ?? [],
      emergency: evidence.emergency ?? [],
    };
    for (const question of ["seat", "grabBars", "space", "sink", "emergency"] as const) {
      pushPhotos(photos, grouped[question], {
        facility: "toilet", section: "toilet", passIndex, entranceLocation: null, kind: "evidence", question,
      });
    }
    return { photos: sectionPhotos, door, seat, grabBars, space, sink, emergency, location, evidence: grouped };
  });
  return { passes: parsed, notes };
}

function parsePathways(
  value: unknown,
  mediaPrefix: string,
  seen: Set<string>,
  photos: StoredPhoto[],
): { notices: string[]; photos: PhotoRef[]; notes: string | null } | null {
  if (value == null) return null;
  const area = object(value, "pathways");
  const notes = optionalText(area.notes, "pathways.notes", TEXT_MAX);
  const notices = stringList(area.notices, "pathways.notices", NOTICES);
  if (!notices.length) throw new HttpError(400, "pathways.notices needs at least one notice.", "invalid_section");
  if (notices.includes("nothing_notable") && notices.length > 1) {
    throw new HttpError(400, "pathways.notices cannot mix nothing_notable with other notices.", "invalid_section");
  }
  const sectionPhotos = takePhotos(area.photos, "pathways.photos", SECTION_PHOTOS_PER_PASS, mediaPrefix, seen);
  pushPhotos(photos, sectionPhotos, {
    facility: "pathways", section: "pathways", passIndex: 0, entranceLocation: null, kind: "section", question: null,
  });
  return { notices, photos: sectionPhotos, notes };
}

function parseAnswerArea(
  value: unknown,
  name: "seating" | "parking",
  mediaPrefix: string,
  seen: Set<string>,
  photos: StoredPhoto[],
): { answer: (typeof AREA_ANSWER)[number]; photos: PhotoRef[]; notes: string | null } | null {
  if (value == null) return null;
  const area = object(value, name);
  const notes = optionalText(area.notes, `${name}.notes`, TEXT_MAX);
  const answer = requiredEnum(area.answer, AREA_ANSWER, `${name}.answer`);
  const sectionPhotos = takePhotos(area.photos, `${name}.photos`, SECTION_PHOTOS_PER_PASS, mediaPrefix, seen);
  pushPhotos(photos, sectionPhotos, {
    facility: name, section: name, passIndex: 0, entranceLocation: null, kind: "section", question: null,
  });
  return { answer, photos: sectionPhotos, notes };
}

function parseFinal(value: unknown, mediaPrefix: string, seen: Set<string>, photos: StoredPhoto[]): { text: string | null; photos: PhotoRef[] } {
  if (value == null) return { text: null, photos: [] };
  const final = object(value, "final");
  const text = optionalText(final.text, "final.text", TEXT_MAX);
  const finalPhotos = takePhotos(final.photos, "final.photos", FINAL_PHOTOS, mediaPrefix, seen);
  pushPhotos(photos, finalPhotos, {
    facility: "general", section: "general", passIndex: null, entranceLocation: null, kind: "final", question: null,
  });
  return { text, photos: finalPhotos };
}

function parseEvidence(
  value: unknown,
  field: string,
  answers: Record<string, string | null>,
  allowed: string[],
  mediaPrefix: string,
  seen: Set<string>,
  remaining: () => number,
  consume: (used: number) => void,
): Record<string, PhotoRef[]> {
  if (value == null) return {};
  const evidence = object(value, field);
  const out: Record<string, PhotoRef[]> = {};
  for (const key of Object.keys(evidence)) {
    if (!allowed.includes(key)) throw new HttpError(400, `${field}.${key} is not a photo question.`, "invalid_section");
    const group = takePhotos(evidence[key], `${field}.${key}`, EVIDENCE_PHOTOS_PER_PASS, mediaPrefix, seen);
    if (group.length && answers[key] !== "not_sure") {
      throw new HttpError(400, `${field}.${key} is only allowed when that answer is not_sure.`, "evidence_requires_not_sure");
    }
    if (group.length > remaining()) {
      throw new HttpError(
        400,
        `${field} can include at most ${EVIDENCE_PHOTOS_PER_PASS} evidence photos for this pass.`,
        "too_many_photos",
      );
    }
    consume(group.length);
    out[key] = group;
  }
  return out;
}

function gradeEntrancePoint(point: EntrancePoint): Grade | null {
  const answers = [point.ramp, point.handrail].filter((value) => value != null && value !== "not_sure");
  if (!answers.length) return null;
  if (point.ramp === "too_steep" || point.handrail === "no") return "no";
  if (answers.some((value) => value === "with_push" || value === "with_effort")) return "limited";
  if (answers.every((value) => value === "yes")) return "yes";
  return null;
}

function gradeElevator(pass: ElevatorPass): Grade | null {
  if (pass.wideEntrance === "no") return "no";
  if (pass.spaceToManeuver === "no" || pass.reachableButtons === "no") return "limited";
  if (pass.wideEntrance === "yes" && pass.spaceToManeuver === "yes" && pass.reachableButtons === "yes") return "yes";
  return null;
}

function gradeToilet(pass: ToiletPass): Grade | null {
  if (pass.space === "no") return "no";
  if (pass.seat === "yes" && pass.grabBars === "yes" && pass.space === "yes" && pass.sink === "yes") return "yes";
  return "limited";
}

/** One accessible pass is enough for the place. */
function best(values: Array<Grade | null>): Grade | null {
  const present = values.filter((value): value is Grade => value != null);
  if (!present.length) return null;
  if (present.includes("yes")) return "yes";
  if (present.includes("limited")) return "limited";
  return "no";
}

function legacyProjection(input: {
  entrancePasses: EntrancePass[];
  elevatorPasses: ElevatorPass[];
  toiletPasses: ToiletPass[];
  pathways: { notices: string[]; notes: string | null } | null;
  seating: { answer: string; notes: string | null } | null;
  parking: { answer: string; notes: string | null } | null;
  sectionNotes: SectionNotes;
  finalText: string | null;
  signals: NormalizedContribution["signals"];
}): NormalizedContribution["legacy"] {
  const elevatorSignal = input.signals.elevator;
  const failedFit = input.elevatorPasses.some((pass) => pass.wideEntrance === "no" || pass.spaceToManeuver === "no");
  const notes = [
    input.finalText,
    noteBlock("Entrance", input.sectionNotes.entrance),
    noteBlock("Elevator", input.sectionNotes.elevator),
    noteBlock("Toilet", input.sectionNotes.toilet),
    areaSummary(input.pathways, input.seating, input.parking),
  ].filter(Boolean).join("\n\n") || null;
  return {
    notes,
    elevatorExists: input.elevatorPasses.length ? true : null,
    elevatorAccessible: elevatorSignal === "yes" ? true : elevatorSignal == null ? null : false,
    elevatorBlockers: elevatorSignal != null && elevatorSignal !== "yes" && failedFit ? ["too_small"] : [],
    elevatorText: joinText(
      input.elevatorPasses.length ? input.elevatorPasses.map(elevatorLine).join("\n\n") : null,
      input.sectionNotes.elevator,
    ),
    hasDisabledToilet: input.toiletPasses.length ? true : null,
    toiletText: joinText(
      input.toiletPasses.length ? input.toiletPasses.map(toiletLine).join("\n\n") : null,
      input.sectionNotes.toilet,
    ),
  };
}

function noteBlock(title: string, text: string | null): string | null {
  return text ? `[${title}]\n${text}` : null;
}

function joinText(first: string | null, second: string | null): string | null {
  const parts = [first, second].filter((part): part is string => part != null && part.length > 0);
  return parts.length ? parts.join("\n\n") : null;
}

/** Answer codes as people read them, for the review text (the codes stay in the structured columns). */
const ANSWER_LABELS: Record<string, string> = {
  yes: "Yes", no: "No", not_sure: "Not sure", none: "None",
  with_push: "With a push", too_steep: "Too steep", with_effort: "With effort",
  too_low: "Too low", too_high: "Too high", awkward: "Positioned awkwardly",
  manual: "Manual", sliding: "Sliding", automatic: "Automatic",
};
const NOTICE_LABELS: Record<string, string> = {
  loose_surface: "Loose gravel or sand", rough_surface: "Rough or uneven surface", tight_gap: "Tight gap",
  narrow_path: "Narrow pathway", steep_section: "Steep section", curb_no_ramp: "Curb or step with no ramp",
  nothing_notable: "Nothing notable",
};
export const answer = (code: string) => ANSWER_LABELS[code] ?? code;

function elevatorLine(pass: ElevatorPass, index: number, all: ElevatorPass[]): string {
  const lines = [
    pass.location ? `Location: ${pass.location}` : null,
    `Entrance Width: ${answer(pass.wideEntrance)}`,
    pass.spaceToManeuver ? `Space to Maneuver: ${answer(pass.spaceToManeuver)}` : null,
    pass.reachableButtons ? `Reachable Buttons: ${answer(pass.reachableButtons)}` : null,
  ].filter((line): line is string => line != null);
  return all.length > 1 ? `[Elevator ${index + 1}]\n${lines.join("\n")}` : lines.join("\n");
}

function toiletLine(pass: ToiletPass, index: number, all: ToiletPass[]): string {
  const lines = [
    pass.location ? `Location: ${pass.location}` : null,
    `Doors: ${answer(pass.door)}`,
    `Toilet Seat: ${answer(pass.seat)}`,
    `Grab Bars: ${answer(pass.grabBars)}`,
    `Space to Maneuver: ${answer(pass.space)}`,
    `Sink: ${answer(pass.sink)}`,
    `Emergency Aid: ${answer(pass.emergency)}`,
  ].filter((line): line is string => line != null);
  return all.length > 1 ? `[Toilet ${index + 1}]\n${lines.join("\n")}` : lines.join("\n");
}

function areaSummary(
  pathways: { notices: string[]; notes: string | null } | null,
  seating: { answer: string; notes: string | null } | null,
  parking: { answer: string; notes: string | null } | null,
): string | null {
  const parts: string[] = [];
  if (pathways) parts.push(joinText(`[Outdoor Pathways]\nNoticed: ${pathways.notices.map((code) => NOTICE_LABELS[code] ?? code).join(", ")}`, pathways.notes)!);
  if (seating) parts.push(joinText(`[Seating]\nWheelchair friendly seating: ${answer(seating.answer)}`, seating.notes)!);
  if (parking) parts.push(joinText(`[Parking]\nAccessible parking: ${answer(parking.answer)}`, parking.notes)!);
  return parts.length ? parts.join("\n\n") : null;
}

function pushPhotos(
  photos: StoredPhoto[],
  group: PhotoRef[],
  meta: Omit<StoredPhoto, "objectKey" | "caption" | "sortOrder">,
) {
  group.forEach((photo) => {
    photos.push({ ...photo, ...meta, sortOrder: photos.length });
  });
}

function takePhotos(value: unknown, field: string, limit: number, mediaPrefix: string, seen: Set<string>): PhotoRef[] {
  if (value == null) return [];
  if (!Array.isArray(value)) throw new HttpError(400, `${field} must be a list of photos.`, "invalid_section");
  if (value.length > limit) {
    throw new HttpError(400, `${field} accepts at most ${limit} photos.`, "too_many_photos");
  }
  return value.map((item, index) => {
    const photo = object(item, `${field}[${index}]`);
    const objectKey = mediaKey(mediaPrefix, photo.url, `${field}[${index}].url`);
    if (seen.has(objectKey)) throw new HttpError(400, `${field}[${index}] repeats a photo already used in this review.`, "duplicate_photo");
    seen.add(objectKey);
    const caption = typeof photo.caption === "string" ? photo.caption.trim().slice(0, CAPTION_MAX) : "";
    return { objectKey, caption };
  });
}

function mediaKey(prefix: string, value: unknown, field: string): string {
  if (typeof value !== "string" || !value.startsWith(prefix)) {
    throw new HttpError(400, `${field} must be a photo uploaded for this review.`, "invalid_photo");
  }
  try {
    const key = decodeURIComponent(value.slice(prefix.length));
    if (!key.startsWith("reviews/")) throw new HttpError(400, `${field} is not a review photo.`, "invalid_photo");
    return key;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(400, `${field} is not a review photo.`, "invalid_photo");
  }
}

/** Confirms every stored photo belongs to this user and this submission. */
export function assertPhotoOwnership(keys: string[], userId: string, submissionId: string, owned: Set<string>) {
  for (const key of keys) {
    if (!key.startsWith(`reviews/${userId}/`) || !key.includes(`/${submissionId}/`)) {
      throw new HttpError(400, "A photo does not belong to this review.", "invalid_photo");
    }
    if (!owned.has(key)) throw new HttpError(400, "A photo has not been uploaded.", "invalid_photo");
  }
}

function object(value: unknown, field: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, `${field} must be an object.`, "invalid_section");
  }
  return value as Record<string, unknown>;
}

function array(value: unknown, field: string): unknown[] {
  if (!Array.isArray(value)) throw new HttpError(400, `${field} must be a list.`, "invalid_section");
  return value;
}

function requiredEnum<T extends string>(value: unknown, allowed: readonly T[], field: string): T {
  if (typeof value !== "string" || !allowed.includes(value as T)) {
    throw new HttpError(400, `${field} must be one of: ${allowed.join(", ")}.`, "invalid_section");
  }
  return value as T;
}

function optionalEnum<T extends string>(value: unknown, allowed: readonly T[], field: string): T | null {
  if (value == null || value === "") return null;
  return requiredEnum(value, allowed, field);
}

function absent(value: unknown, field: string): null {
  if (value == null) return null;
  throw new HttpError(400, `${field} does not apply for this answer.`, "invalid_section");
}

function optionalText(value: unknown, field: string, max: number): string | null {
  if (value == null || value === "") return null;
  if (typeof value !== "string") throw new HttpError(400, `${field} must be text.`, "invalid_section");
  const trimmed = value.trim();
  if (!trimmed) return null;
  if (trimmed.length > max) throw new HttpError(400, `${field} is too long.`, "invalid_section");
  return trimmed;
}

function stringList<T extends string>(value: unknown, field: string, allowed: readonly T[]): T[] {
  if (!Array.isArray(value)) throw new HttpError(400, `${field} must be a list.`, "invalid_section");
  const out: T[] = [];
  for (const item of value) {
    if (typeof item !== "string" || !allowed.includes(item as T) || out.includes(item as T)) {
      throw new HttpError(400, `${field} has an unknown or repeated value.`, "invalid_section");
    }
    out.push(item as T);
  }
  return out;
}
