-- Multi-currency support.
--
-- `amount` keeps its meaning throughout: the value in the user's base
-- currency. Every existing total, budget, chart and analytics query therefore
-- continues to work with no change at all. The columns added here record what
-- the user actually typed when it was not in the base currency, plus the rate
-- applied, frozen at write time so history cannot be rewritten by later rate
-- movements.
--
-- All four columns are nullable: NULL means "entered in the base currency",
-- which is true of every row that already exists.

ALTER TABLE "expenses"
  ADD COLUMN "original_amount"   DECIMAL(18,6),
  ADD COLUMN "original_currency" TEXT,
  ADD COLUMN "fx_rate"           DECIMAL(20,10),
  ADD COLUMN "fx_rate_at"        TIMESTAMP(3);

ALTER TABLE "income"
  ADD COLUMN "original_amount"   DECIMAL(18,6),
  ADD COLUMN "original_currency" TEXT,
  ADD COLUMN "fx_rate"           DECIMAL(20,10),
  ADD COLUMN "fx_rate_at"        TIMESTAMP(3);

ALTER TABLE "loans"
  ADD COLUMN "original_amount"   DECIMAL(18,6),
  ADD COLUMN "original_currency" TEXT,
  ADD COLUMN "fx_rate"           DECIMAL(20,10),
  ADD COLUMN "fx_rate_at"        TIMESTAMP(3);

-- Rates we have accepted. Reads are always served from here rather than from
-- the upstream provider, so a provider outage degrades accuracy, never
-- availability.
CREATE TABLE "fx_rate_snapshots" (
    "id"           TEXT NOT NULL,
    "base"         TEXT NOT NULL DEFAULT 'USD',
    "rates"        JSONB NOT NULL,
    "published_at" TIMESTAMP(3) NOT NULL,
    "fetched_at"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "source"       TEXT NOT NULL,
    "rate_count"   INTEGER NOT NULL,
    CONSTRAINT "fx_rate_snapshots_pkey" PRIMARY KEY ("id")
);

-- Serves "give me the newest usable snapshot", the only hot read.
CREATE INDEX "fx_rate_snapshots_published_at_idx"
  ON "fx_rate_snapshots"("published_at" DESC);
CREATE INDEX "fx_rate_snapshots_source_published_at_idx"
  ON "fx_rate_snapshots"("source", "published_at" DESC);

-- Changing base currency rewrites every stored amount, so each change is
-- recorded. Without this there is no way to explain why a user's totals moved.
CREATE TABLE "currency_changes" (
    "id"             TEXT NOT NULL,
    "user_id"        TEXT NOT NULL,
    "from_currency"  TEXT NOT NULL,
    "to_currency"    TEXT NOT NULL,
    "rate"           DECIMAL(20,10) NOT NULL,
    "rows_converted" INTEGER NOT NULL,
    "created_at"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "currency_changes_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "currency_changes"
  ADD CONSTRAINT "currency_changes_user_id_fkey" FOREIGN KEY ("user_id")
  REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "currency_changes_user_id_created_at_idx"
  ON "currency_changes"("user_id", "created_at" DESC);
