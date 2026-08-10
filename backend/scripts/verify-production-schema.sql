-- Production schema verification.
--
-- Run on the VPS:
--   psql "$DATABASE_URL" -f scripts/verify-production-schema.sql
--
-- Checks what each migration was supposed to leave behind, rather than trusting
-- the _prisma_migrations table alone. That distinction matters here: this
-- database has been brought forward with `prisma db push` in the past, which
-- applies columns but silently skips partial indexes and every data statement —
-- so a migration can be recorded, or the schema can look right, while the
-- effects that actually matter are missing.
--
-- Read-only. Nothing below writes.

\pset border 2
\pset format aligned

\echo ''
\echo '=== 1. Migrations Prisma believes are applied ==================='
SELECT migration_name,
       to_char(finished_at, 'YYYY-MM-DD HH24:MI') AS finished,
       CASE WHEN rolled_back_at IS NOT NULL THEN 'ROLLED BACK'
            WHEN finished_at IS NULL THEN 'FAILED / PENDING'
            ELSE 'ok' END AS state
FROM _prisma_migrations
ORDER BY started_at;

\echo ''
\echo '=== 2. Columns each migration should have added ================='
WITH expected(migration, tbl, col) AS (VALUES
  ('ai_consent_opt_in',      'user_settings', 'ai_consent_at'),
  ('ai_consent_opt_in',      'user_settings', 'ai_consent_version'),
  ('otp_verification_rules', 'otp_codes',     'is_resend'),
  ('grace_period',           'users',         'verification_deadline'),
  ('grace_period',           'users',         'verification_reminded_at'),
  ('login_lockout',          'users',         'failed_login_attempts'),
  ('login_lockout',          'users',         'locked_until'),
  ('loans_lent',             'loans',         'direction'),
  ('loans_lent',             'income',        'loan_id')
)
SELECT e.migration, e.tbl || '.' || e.col AS column,
       COALESCE(c.data_type, '—') AS type,
       CASE WHEN c.column_name IS NULL THEN 'MISSING' ELSE 'ok' END AS state
FROM expected e
LEFT JOIN information_schema.columns c
  ON c.table_name = e.tbl AND c.column_name = e.col AND c.table_schema = 'public'
ORDER BY state DESC, e.migration;

\echo ''
\echo '=== 3. Tables that should exist ================================='
WITH expected(tbl) AS (VALUES ('pending_signups'), ('loans'), ('otp_codes'),
                              ('overall_budgets'), ('monthly_budgets'))
SELECT e.tbl,
       CASE WHEN t.table_name IS NULL THEN 'MISSING' ELSE 'ok' END AS state
FROM expected e
LEFT JOIN information_schema.tables t
  ON t.table_name = e.tbl AND t.table_schema = 'public'
ORDER BY state DESC, e.tbl;

\echo ''
\echo '=== 4. Indexes — the ones db push skips ========================='
WITH expected(idx) AS (VALUES
  ('users_verification_deadline_idx'),
  ('users_locked_until_idx'),
  ('otp_codes_user_id_purpose_created_at_idx'),
  ('pending_signups_email_key'),
  ('pending_signups_expires_at_idx'),
  ('income_loan_id_idx'),
  ('loans_user_id_direction_status_idx')
)
SELECT e.idx,
       CASE WHEN i.indexname IS NULL THEN 'MISSING' ELSE 'ok' END AS state
FROM expected e
LEFT JOIN pg_indexes i ON i.indexname = e.idx AND i.schemaname = 'public'
ORDER BY state DESC, e.idx;

\echo ''
\echo '=== 5. The LoanDirection enum and its default ==================='
SELECT t.typname AS enum,
       string_agg(l.enumlabel, ', ' ORDER BY l.enumsortorder) AS values
FROM pg_type t
JOIN pg_enum l ON l.enumtypid = t.oid
WHERE t.typname = 'LoanDirection'
GROUP BY t.typname;

SELECT column_name, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'loans' AND column_name = 'direction';

\echo ''
\echo '=== 6. income.loan_id must be ON DELETE SET NULL ================'
-- Anything else and deleting a loan would take real income with it.
SELECT con.conname AS constraint,
       CASE con.confdeltype WHEN 'n' THEN 'SET NULL'
                            WHEN 'c' THEN 'CASCADE (WRONG)'
                            WHEN 'a' THEN 'NO ACTION (WRONG)'
                            WHEN 'r' THEN 'RESTRICT (WRONG)'
                            ELSE con.confdeltype::text END AS on_delete
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'income' AND con.contype = 'f'
  AND pg_get_constraintdef(con.oid) LIKE '%loans%';

\echo ''
\echo '=== 7. Data statements (db push never runs these) ==============='
-- Consent is `ai_consent_at`, never `ai_enabled` on its own. Any row with AI
-- on and no consent timestamp means the migration's UPDATE never ran — which
-- is exactly what `db push` does to a data statement.
SELECT count(*) FILTER (WHERE ai_enabled AND ai_consent_at IS NULL) AS ai_on_without_consent,
       count(*) FILTER (WHERE ai_consent_at IS NOT NULL)            AS consented,
       count(*)                                                     AS total_settings
FROM user_settings;

-- Existing accounts should carry a grace deadline; new ones verify up front.
SELECT count(*)                                              AS users,
       count(*) FILTER (WHERE email_verified)                AS verified,
       count(*) FILTER (WHERE NOT email_verified)            AS unverified,
       count(*) FILTER (WHERE verification_deadline IS NOT NULL) AS with_deadline
FROM users;

\echo ''
\echo '=== 8. Loan data currently in production ========================'
SELECT direction, status, count(*) AS loans
FROM loans WHERE deleted_at IS NULL
GROUP BY direction, status ORDER BY direction, status;

SELECT count(*) FILTER (WHERE loan_id IS NOT NULL) AS income_linked_to_a_loan
FROM income WHERE deleted_at IS NULL;

\echo ''
\echo '=== done. Anything marked MISSING above needs a migration ======='
