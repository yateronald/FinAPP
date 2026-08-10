-- Sign-ups are staged until the e-mail code is validated. Nothing reaches
-- "users" before then, so an abandoned or failed verification leaves no
-- account behind and the address stays free to try again.
CREATE TABLE "pending_signups" (
    "id"                  TEXT NOT NULL,
    "email"               TEXT NOT NULL,
    "password_hash"       TEXT,
    "first_name"          TEXT,
    "last_name"           TEXT,
    "country"             TEXT,
    "language"            "Language" NOT NULL DEFAULT 'EN',
    "currency"            TEXT NOT NULL DEFAULT 'XOF',
    "google_id"           TEXT,
    "avatar_url"          TEXT,
    "code_hash"           TEXT NOT NULL,
    "expires_at"          TIMESTAMP(3) NOT NULL,
    "attempts"            INTEGER NOT NULL DEFAULT 0,
    "resend_count"        INTEGER NOT NULL DEFAULT 0,
    "resend_window_start" TIMESTAMP(3),
    "created_at"          TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pending_signups_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "pending_signups_email_key" ON "pending_signups"("email");
-- Serves the expiry sweep.
CREATE INDEX "pending_signups_expires_at_idx" ON "pending_signups"("expires_at");
