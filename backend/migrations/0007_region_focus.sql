-- Where "Go to <region>" lands: a busy spot with places, not the middle of
-- the region's box (for Bali that's jungle).
ALTER TABLE sync_regions ADD COLUMN focus_lat REAL;
ALTER TABLE sync_regions ADD COLUMN focus_lng REAL;
UPDATE sync_regions SET focus_lat = -8.72, focus_lng = 115.17 WHERE id = 'bali';       -- Kuta
UPDATE sync_regions SET focus_lat = -33.8688, focus_lng = 151.2093 WHERE id = 'australia'; -- Sydney
UPDATE sync_regions SET focus_lat = 48.8566, focus_lng = 2.3522 WHERE id = 'europe';    -- Paris
