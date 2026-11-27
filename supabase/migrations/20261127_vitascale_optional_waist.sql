-- Child Screening no longer collects waist circumference.
-- Keep past results and allow new screenings to record no waist measurement.
ALTER TABLE IF EXISTS vitascale.screening_results
  ALTER COLUMN waist_cm DROP NOT NULL;
