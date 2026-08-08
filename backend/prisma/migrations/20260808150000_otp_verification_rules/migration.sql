-- Email verification is now mandatory for every account, including Google
-- sign-ups, with a 3-minute code, 3 attempts, and 3 resends per hour.

-- The hourly resend quota counts only codes the user explicitly asked for,
-- so the automatic code sent at sign-up does not consume the allowance.
ALTER TABLE "otp_codes"
  ADD COLUMN "is_resend" BOOLEAN NOT NULL DEFAULT false;

-- Serves the rolling-window count in the resend throttle.
CREATE INDEX "otp_codes_user_id_purpose_created_at_idx"
  ON "otp_codes"("user_id", "purpose", "created_at");
