-- Flip source priority: OSM/Overpass becomes the required primary source,
-- Google Places becomes optional secondary enrichment (no hard dependency —
-- the app works, with a smaller signal set, if GOOGLE_MAPS_API_KEY is never
-- configured). See docs/specs.md §3/§6 and the Edge Function for the logic.
--
-- place_id is no longer required to be (or resemble) a Google Place ID — the
-- Edge Function now derives it from lat/lng directly (see canonicalPlaceId()),
-- so identity no longer depends on Google being reachable. Google's own ID,
-- when we do have one, is kept only as an optional cross-reference to avoid
-- re-querying Google for a location we've already resolved.

alter table public.place_cache
  add column if not exists google_place_id text;
