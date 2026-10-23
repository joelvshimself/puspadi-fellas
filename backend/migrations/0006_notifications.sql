-- Push notifications (src/push.ts). Phones register their Firebase Cloud
-- Messaging token; Firebase delivers to Android directly and to iOS via APNs.

CREATE TABLE push_devices (
  token TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX push_devices_user_idx ON push_devices(user_id);

-- What each person wants to hear about. All on by default; the phone's own
-- permission still decides whether anything is shown.
ALTER TABLE profiles ADD COLUMN notify_saved_place_reviews INTEGER NOT NULL DEFAULT 1
  CHECK (notify_saved_place_reviews IN (0, 1));
ALTER TABLE profiles ADD COLUMN notify_announcements INTEGER NOT NULL DEFAULT 1
  CHECK (notify_announcements IN (0, 1));
-- Read by the apps only: the reminder is scheduled on the phone.
ALTER TABLE profiles ADD COLUMN notify_review_reminders INTEGER NOT NULL DEFAULT 1
  CHECK (notify_review_reminders IN (0, 1));
