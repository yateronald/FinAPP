-- Verification is now mandatory, but accounts that predate the rule must not
-- be locked out overnight: they get 14 days to confirm, with a daily reminder.
ALTER TABLE "users"
  ADD COLUMN "verification_deadline"     TIMESTAMP(3),
  ADD COLUMN "verification_reminded_at"  TIMESTAMP(3);

-- Grant the grace window to everyone who exists right now and has not
-- confirmed. New sign-ups leave the column null and must confirm immediately.
UPDATE "users"
SET "verification_deadline" = NOW() + INTERVAL '14 days'
WHERE "email_verified" = false
  AND "deleted_at" IS NULL;

-- Serves the daily reminder sweep.
CREATE INDEX "users_verification_deadline_idx"
  ON "users"("verification_deadline")
  WHERE "verification_deadline" IS NOT NULL;
