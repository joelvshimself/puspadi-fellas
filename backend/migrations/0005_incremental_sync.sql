-- When a tile last loaded successfully. Later syncs of that tile ask Overpass
-- only for places edited since then (src/sync.ts), instead of the whole tile.
ALTER TABLE sync_tiles ADD COLUMN loaded_at TEXT;
UPDATE sync_tiles SET loaded_at = last_synced_at WHERE last_status = 'ok';
