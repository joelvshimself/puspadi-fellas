-- ==========================================================================
-- Prune duplicate and hand-made test reviews (2026-08-26)
--
-- Two kinds of row are removed, both identified from the live table:
--
-- 1. ONE hand-made test row. apple_maps_id = 'seed-park23', written 22 Aug,
--    recorded 512m from Park23 while every genuine Park23 submission sits at
--    35m. Every other row in the table carries a device UUID; this one does
--    not, which is what marks it as typed rather than submitted. It was
--    sitting on a drifted duplicate id and the alias merge moved it onto
--    Park23, which is why it surfaced looking like somebody else's review.
--
-- 2. NINE repeat submissions. The same device sent the same review several
--    times — 7D429AB8 four times, 61DA7784 three, 692CA87A three, and two
--    further pairs. (place_id, apple_maps_id) is the same contribution; the
--    newest of each group is kept.
--
-- Why the newest and not the oldest: it is what the rest of the system already
-- treats as authoritative. review_to_signals() deletes a place's earlier
-- review signals on every insert, so the grade has always been derived from
-- the most recent submission — keeping an older row would leave the list
-- disagreeing with the badge above it.
--
-- accessibility_signals needs no repair for the same reason: the surviving row
-- is the one whose answers are already in the ledger. review_entrances is ON
-- DELETE CASCADE, so entrance children go with their parent.
-- ==========================================================================

do $$
declare
  test_rows integer;
  dupe_rows integer;
  remaining integer;
begin
  -- 1. The hand-made row. Matched on the exact value rather than "anything
  --    that does not look like a UUID", so this cannot quietly widen later
  --    into deleting real contributions from a client that formats its id
  --    differently.
  delete from public.reviews where apple_maps_id = 'seed-park23';
  get diagnostics test_rows = row_count;

  -- 2. Repeat submissions of the same contribution.
  delete from public.reviews r
  using public.reviews keep
  where r.id <> keep.id
    and r.place_id = keep.place_id
    and r.apple_maps_id is not null
    and r.apple_maps_id = keep.apple_maps_id
    and (r.created_at, r.id) < (keep.created_at, keep.id);
  get diagnostics dupe_rows = row_count;

  select count(*) into remaining from public.reviews;

  raise notice 'pruned % hand-made test row(s) and % repeat submission(s); % review(s) remain',
    test_rows, dupe_rows, remaining;
end $$;
