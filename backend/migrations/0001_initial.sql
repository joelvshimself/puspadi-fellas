-- Better Auth owns these four tables. Application code never reads password
-- hashes or provider tokens directly.
CREATE TABLE "user" (
  "id" TEXT PRIMARY KEY NOT NULL,
  "name" TEXT NOT NULL,
  "email" TEXT NOT NULL UNIQUE,
  "emailVerified" INTEGER NOT NULL DEFAULT 0,
  "image" TEXT,
  "createdAt" INTEGER NOT NULL,
  "updatedAt" INTEGER NOT NULL
);

CREATE TABLE "session" (
  "id" TEXT PRIMARY KEY NOT NULL,
  "expiresAt" INTEGER NOT NULL,
  "token" TEXT NOT NULL UNIQUE,
  "createdAt" INTEGER NOT NULL,
  "updatedAt" INTEGER NOT NULL,
  "ipAddress" TEXT,
  "userAgent" TEXT,
  "userId" TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE
);
CREATE INDEX "session_userId_idx" ON "session"("userId");

CREATE TABLE "account" (
  "id" TEXT PRIMARY KEY NOT NULL,
  "accountId" TEXT NOT NULL,
  "providerId" TEXT NOT NULL,
  "userId" TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  "accessToken" TEXT,
  "refreshToken" TEXT,
  "idToken" TEXT,
  "accessTokenExpiresAt" INTEGER,
  "refreshTokenExpiresAt" INTEGER,
  "scope" TEXT,
  "password" TEXT,
  "createdAt" INTEGER NOT NULL,
  "updatedAt" INTEGER NOT NULL
);
CREATE INDEX "account_userId_idx" ON "account"("userId");
CREATE UNIQUE INDEX "account_provider_identity_idx" ON "account"("providerId", "accountId");

CREATE TABLE "verification" (
  "id" TEXT PRIMARY KEY NOT NULL,
  "identifier" TEXT NOT NULL,
  "value" TEXT NOT NULL,
  "expiresAt" INTEGER NOT NULL,
  "createdAt" INTEGER NOT NULL,
  "updatedAt" INTEGER NOT NULL
);
CREATE INDEX "verification_identifier_idx" ON "verification"("identifier");

-- Rollspot stores an Apple Place ID, not an Apple Maps place-data snapshot.
-- Current names, addresses and coordinates are resolved with MapKit on-device.
CREATE TABLE places (
  apple_place_id TEXT PRIMARY KEY NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE profiles (
  user_id TEXT PRIMARY KEY NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  display_name TEXT,
  avatar_key TEXT,
  mobility_aids TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(mobility_aids)),
  pseudonym TEXT NOT NULL UNIQUE,
  show_real_name INTEGER NOT NULL DEFAULT 0 CHECK (show_real_name IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE saved_places (
  user_id TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  apple_place_id TEXT NOT NULL REFERENCES places(apple_place_id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  PRIMARY KEY (user_id, apple_place_id)
);
CREATE INDEX saved_places_user_idx ON saved_places(user_id, created_at DESC);

CREATE TABLE reviews (
  id TEXT PRIMARY KEY NOT NULL,
  submission_id TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  apple_place_id TEXT NOT NULL REFERENCES places(apple_place_id) ON DELETE CASCADE,
  notes TEXT,
  elevator_exists INTEGER CHECK (elevator_exists IN (0, 1)),
  elevator_wheelchair_accessible INTEGER CHECK (elevator_wheelchair_accessible IN (0, 1)),
  elevator_blockers TEXT NOT NULL DEFAULT '[]' CHECK (json_valid(elevator_blockers)),
  elevator_review_text TEXT,
  has_disabled_toilet INTEGER CHECK (has_disabled_toilet IN (0, 1)),
  toilet_review_text TEXT,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  UNIQUE (user_id, submission_id)
);
CREATE INDEX reviews_place_created_idx ON reviews(apple_place_id, created_at DESC);
CREATE INDEX reviews_user_created_idx ON reviews(user_id, created_at DESC);

CREATE TABLE review_entrances (
  id TEXT PRIMARY KEY NOT NULL,
  review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  location TEXT NOT NULL CHECK (location IN ('lobby', 'basement', 'exit_side', 'other')),
  has_dropoff_ramp INTEGER CHECK (has_dropoff_ramp IN (0, 1)),
  has_rails INTEGER CHECK (has_rails IN (0, 1)),
  door_type TEXT CHECK (door_type IN ('manual', 'automatic')),
  is_wide_enough INTEGER CHECK (is_wide_enough IN (0, 1)),
  review_text TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX review_entrances_review_idx ON review_entrances(review_id, sort_order);

CREATE TABLE media_uploads (
  object_key TEXT PRIMARY KEY NOT NULL,
  owner_user_id TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  content_type TEXT NOT NULL,
  byte_size INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE review_photos (
  id TEXT PRIMARY KEY NOT NULL,
  review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  object_key TEXT NOT NULL REFERENCES media_uploads(object_key) ON DELETE RESTRICT,
  facility TEXT NOT NULL CHECK (facility IN ('lobby', 'basement', 'elevator', 'toilet', 'exit_side', 'other')),
  caption TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  UNIQUE (review_id, object_key)
);
CREATE INDEX review_photos_review_idx ON review_photos(review_id, facility, sort_order);

-- One current verdict per contributor and facility. A repeat review updates
-- that contributor's verdict instead of letting repeated taps stack weight.
CREATE TABLE accessibility_signals (
  apple_place_id TEXT NOT NULL REFERENCES places(apple_place_id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  feature TEXT NOT NULL CHECK (feature IN ('entrance', 'elevator', 'restroom')),
  value TEXT NOT NULL CHECK (value IN ('yes', 'no', 'limited')),
  review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  PRIMARY KEY (apple_place_id, user_id, feature)
);
CREATE INDEX accessibility_signals_place_idx ON accessibility_signals(apple_place_id, feature);

CREATE TABLE place_photos (
  id TEXT PRIMARY KEY NOT NULL,
  apple_place_id TEXT NOT NULL REFERENCES places(apple_place_id) ON DELETE CASCADE,
  object_key TEXT NOT NULL REFERENCES media_uploads(object_key) ON DELETE RESTRICT,
  credit TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX place_photos_place_idx ON place_photos(apple_place_id, sort_order);
