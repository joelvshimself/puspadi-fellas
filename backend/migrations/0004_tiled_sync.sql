-- Regions are now synced tile by tile (src/sync.ts): one Overpass query per
-- tile, a few tiles every cron run, so no single query or Worker run has to
-- hold a whole region. A tile that returns too much is split into four.

-- Only active regions are synced. New regions start off: turning one on is
--   wrangler d1 execute rollspot --remote --command "UPDATE sync_regions SET active = 1 WHERE id = 'europe'"
-- (Europe and Australia need the Workers Paid plan: storage, writes and CPU.)
ALTER TABLE sync_regions ADD COLUMN active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0, 1));

CREATE TABLE sync_tiles (
  id TEXT PRIMARY KEY NOT NULL,
  region_id TEXT NOT NULL REFERENCES sync_regions(id) ON DELETE CASCADE,
  south REAL NOT NULL,
  west REAL NOT NULL,
  north REAL NOT NULL,
  east REAL NOT NULL,
  -- NULL means never synced: due now.
  next_sync_at TEXT,
  last_synced_at TEXT,
  last_status TEXT,
  last_count INTEGER
);
CREATE INDEX sync_tiles_due_idx ON sync_tiles(next_sync_at);
CREATE INDEX sync_tiles_region_idx ON sync_tiles(region_id);

-- Mainland Australia and Tasmania.
INSERT INTO sync_regions (id, name, south, west, north, east, active) VALUES ('australia', 'Australia', -44.0, 112.5, -10.0, 154.0, 0);
-- Iceland and the Azores to the Urals' western edge, Cyprus and Crete to the North Cape.
-- A box, so it also takes in the North African coast and parts of the Middle East.
INSERT INTO sync_regions (id, name, south, west, north, east, active) VALUES ('europe', 'Europe', 34.5, -31.5, 71.5, 45.0, 0);
