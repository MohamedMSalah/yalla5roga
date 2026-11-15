-- Unknown source prices must stay unknown. Existing values and rows are preserved.
ALTER TABLE places ALTER COLUMN price_level DROP NOT NULL;
ALTER TABLE places ALTER COLUMN price_level DROP DEFAULT;
-- Absence may advance at most once per distinct source release, including city runs.
ALTER TABLE place_source_records ADD COLUMN last_absence_release VARCHAR(128);
