-- Structured contribute reviews. v1 rows stay valid: new columns default, and
-- existing review_photos are copied as kind = 'legacy'.

ALTER TABLE reviews ADD COLUMN schema_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE reviews ADD COLUMN persona TEXT CHECK (persona IN ('wheelchair', 'secondary'));
ALTER TABLE reviews ADD COLUMN final_text TEXT;

ALTER TABLE review_entrances ADD COLUMN pass_index INTEGER NOT NULL DEFAULT 0;
ALTER TABLE review_entrances ADD COLUMN tags TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(tags));
ALTER TABLE review_entrances ADD COLUMN ramp_answer TEXT
  CHECK (ramp_answer IS NULL OR ramp_answer IN ('yes', 'with_push', 'too_steep', 'not_sure'));
ALTER TABLE review_entrances ADD COLUMN handrail_answer TEXT
  CHECK (handrail_answer IS NULL OR handrail_answer IN ('yes', 'with_effort', 'no', 'not_sure'));

CREATE TABLE review_elevators (
  id TEXT PRIMARY KEY NOT NULL,
  review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  pass_index INTEGER NOT NULL,
  wide_entrance TEXT NOT NULL CHECK (wide_entrance IN ('yes', 'no', 'not_sure')),
  space_to_maneuver TEXT CHECK (space_to_maneuver IS NULL OR space_to_maneuver IN ('yes', 'no', 'not_sure')),
  reachable_buttons TEXT CHECK (reachable_buttons IS NULL OR reachable_buttons IN ('yes', 'no', 'not_sure')),
  location_text TEXT,
  UNIQUE (review_id, pass_index)
);
CREATE INDEX review_elevators_review_idx ON review_elevators(review_id, pass_index);

CREATE TABLE review_toilets (
  id TEXT PRIMARY KEY NOT NULL,
  review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  pass_index INTEGER NOT NULL,
  door TEXT NOT NULL CHECK (door IN ('manual', 'sliding', 'automatic')),
  seat TEXT NOT NULL CHECK (seat IN ('yes', 'too_low', 'too_high', 'not_sure')),
  grab_bars TEXT NOT NULL CHECK (grab_bars IN ('yes', 'awkward', 'no', 'not_sure')),
  space TEXT NOT NULL CHECK (space IN ('yes', 'no', 'not_sure')),
  sink TEXT NOT NULL CHECK (sink IN ('yes', 'no', 'not_sure')),
  emergency TEXT NOT NULL CHECK (emergency IN ('yes', 'no', 'not_sure', 'none')),
  location_text TEXT,
  UNIQUE (review_id, pass_index)
);
CREATE INDEX review_toilets_review_idx ON review_toilets(review_id, pass_index);

CREATE TABLE review_areas (
  review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  area TEXT NOT NULL CHECK (area IN ('pathways', 'seating', 'parking')),
  answer TEXT CHECK (answer IS NULL OR answer IN ('yes', 'no', 'not_sure')),
  notices TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(notices)),
  PRIMARY KEY (review_id, area)
);

-- SQLite cannot alter a CHECK. Rebuild review_photos with the v2 columns.
PRAGMA defer_foreign_keys = ON;

CREATE TABLE review_photos_v2 (
  id TEXT PRIMARY KEY NOT NULL,
  review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  object_key TEXT NOT NULL REFERENCES media_uploads(object_key) ON DELETE RESTRICT,
  facility TEXT NOT NULL CHECK (facility IN (
    'lobby', 'basement', 'elevator', 'toilet', 'exit_side', 'other',
    'pathways', 'seating', 'parking', 'general'
  )),
  caption TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  section TEXT NOT NULL DEFAULT 'legacy' CHECK (section IN (
    'entrance', 'elevator', 'toilet', 'pathways', 'seating', 'parking', 'general', 'legacy'
  )),
  pass_index INTEGER,
  entrance_location TEXT CHECK (entrance_location IS NULL OR entrance_location IN ('lobby', 'basement')),
  kind TEXT NOT NULL DEFAULT 'legacy' CHECK (kind IN ('section', 'evidence', 'final', 'legacy')),
  question TEXT,
  UNIQUE (review_id, object_key)
);

INSERT INTO review_photos_v2 (
  id, review_id, object_key, facility, caption, sort_order, section, kind
)
SELECT
  id, review_id, object_key, facility, caption, sort_order,
  CASE facility
    WHEN 'lobby' THEN 'entrance'
    WHEN 'basement' THEN 'entrance'
    WHEN 'elevator' THEN 'elevator'
    WHEN 'toilet' THEN 'toilet'
    ELSE 'legacy'
  END,
  'legacy'
FROM review_photos;

DROP TABLE review_photos;
ALTER TABLE review_photos_v2 RENAME TO review_photos;
CREATE INDEX review_photos_review_idx ON review_photos(review_id, section, pass_index, sort_order);
