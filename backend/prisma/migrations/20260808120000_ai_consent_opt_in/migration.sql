-- AI processing is opt-in. Existing accounts did not accept the dedicated
-- disclosure, so they are disabled and must explicitly enable it again.
ALTER TABLE "user_settings"
  ALTER COLUMN "ai_enabled" SET DEFAULT false,
  ADD COLUMN "ai_consent_at" TIMESTAMP(3),
  ADD COLUMN "ai_consent_version" TEXT;

UPDATE "user_settings"
SET "ai_enabled" = false,
    "ai_consent_at" = NULL,
    "ai_consent_version" = NULL;
