ALTER TABLE "outing_arrivals"
  DROP CONSTRAINT "outing_arrivals_verification_check",
  ADD CONSTRAINT "outing_arrivals_verification_check" CHECK (
    (verification_method IN ('legacy', 'organizer')
      AND verification_distance IS NULL AND location_accuracy IS NULL)
    OR (verification_method IN ('gps', 'automatic_gps', 'manual_gps')
      AND verification_distance IS NOT NULL AND verification_distance >= 0
      AND verification_distance < 'Infinity'::double precision
      AND location_accuracy IS NOT NULL AND location_accuracy > 0
      AND location_accuracy < 'Infinity'::double precision)
  );
