-- Loans now run both ways: money borrowed (settled by an expense) and money
-- lent out (settled by an income). Direction rather than a second table —
-- every field and every computation is shared, only the sign differs.
CREATE TYPE "LoanDirection" AS ENUM ('BORROWED', 'LENT');

ALTER TABLE "loans"
  ADD COLUMN "direction" "LoanDirection" NOT NULL DEFAULT 'BORROWED';

ALTER TABLE "income"
  ADD COLUMN "loan_id" TEXT;

-- Deleting a loan keeps the income: it is money that really came in.
ALTER TABLE "income"
  ADD CONSTRAINT "income_loan_id_fkey" FOREIGN KEY ("loan_id")
  REFERENCES "loans"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "income_loan_id_idx" ON "income"("loan_id");
CREATE INDEX "loans_user_id_direction_status_idx" ON "loans"("user_id", "direction", "status");
