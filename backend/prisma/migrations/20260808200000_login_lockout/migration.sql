-- Brute-force protection: five consecutive wrong passwords lock sign-in for
-- five hours. A password reset clears the lock, so a legitimate owner is
-- never stranded by someone else guessing at their address.
ALTER TABLE "users"
  ADD COLUMN "failed_login_attempts" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "locked_until"          TIMESTAMP(3);

-- Lets the admin dashboard list currently-locked accounts cheaply.
CREATE INDEX "users_locked_until_idx"
  ON "users"("locked_until")
  WHERE "locked_until" IS NOT NULL;
