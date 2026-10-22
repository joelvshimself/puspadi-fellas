-- Optional free-text note written at the end of each contribute section.

CREATE TABLE review_section_notes (
  review_id TEXT NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  section TEXT NOT NULL CHECK (section IN (
    'entrance', 'elevator', 'toilet', 'pathways', 'seating', 'parking'
  )),
  text TEXT NOT NULL,
  PRIMARY KEY (review_id, section)
);
