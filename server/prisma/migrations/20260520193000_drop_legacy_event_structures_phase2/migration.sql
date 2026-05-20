DROP INDEX IF EXISTS "event_timetable_slots_start_time_idx";
DROP INDEX IF EXISTS "event_timetable_slots_dj_id_idx";
DROP INDEX IF EXISTS "event_timetable_slots_lineup_artist_id_idx";
DROP INDEX IF EXISTS "event_timetable_slots_event_id_idx";
DROP INDEX IF EXISTS "event_lineup_artists_dj_id_idx";
DROP INDEX IF EXISTS "event_lineup_artists_event_id_idx";
DROP INDEX IF EXISTS "event_lineup_slots_event_id_festival_day_index_idx";
DROP INDEX IF EXISTS "event_lineup_slots_start_time_idx";
DROP INDEX IF EXISTS "event_lineup_slots_dj_id_idx";
DROP INDEX IF EXISTS "event_lineup_slots_event_id_idx";

ALTER TABLE IF EXISTS "event_timetable_slots" DROP CONSTRAINT IF EXISTS "event_timetable_slots_lineup_artist_id_fkey";
ALTER TABLE IF EXISTS "event_timetable_slots" DROP CONSTRAINT IF EXISTS "event_timetable_slots_dj_id_fkey";
ALTER TABLE IF EXISTS "event_timetable_slots" DROP CONSTRAINT IF EXISTS "event_timetable_slots_event_id_fkey";
ALTER TABLE IF EXISTS "event_lineup_artists" DROP CONSTRAINT IF EXISTS "event_lineup_artists_dj_id_fkey";
ALTER TABLE IF EXISTS "event_lineup_artists" DROP CONSTRAINT IF EXISTS "event_lineup_artists_event_id_fkey";
ALTER TABLE IF EXISTS "event_lineup_slots" DROP CONSTRAINT IF EXISTS "event_lineup_slots_dj_id_fkey";
ALTER TABLE IF EXISTS "event_lineup_slots" DROP CONSTRAINT IF EXISTS "event_lineup_slots_event_id_fkey";

DROP TABLE IF EXISTS "event_timetable_slots";
DROP TABLE IF EXISTS "event_lineup_artists";
DROP TABLE IF EXISTS "event_lineup_slots";

ALTER TABLE "events" DROP COLUMN IF EXISTS "stage_order";
