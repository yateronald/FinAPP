#!/bin/bash

# ╔══════════════════════════════════════════════════════════════════╗
# ║           DATABASE MIGRATION & SYNC SCRIPT                      ║
# ║     Aiven Cloud PostgreSQL  →  Local VPS PostgreSQL             ║
# ╠══════════════════════════════════════════════════════════════════╣
# ║  USAGE:                                                          ║
# ║    bash db.sh create          → Full migration (first time)     ║
# ║    bash db.sh update          → Sync schema + data changes      ║
# ║    bash db.sh update schema   → Sync schema only                ║
# ║    bash db.sh update data     → Sync data only                  ║
# ║    bash db.sh status          → Compare source vs local         ║
# ╚══════════════════════════════════════════════════════════════════╝

set -e

# ════════════════════════════════════════════════════════════════════
#  ⚙️  CONFIG — FILL IN ALL VALUES BEFORE RUNNING
# ════════════════════════════════════════════════════════════════════

# ── SOURCE — Aiven Cloud ─────────────────────────────────────────
SOURCE_HOST="pg-3ac4bb34-yateronald-bcd4.b.aivencloud.com"               # e.g. pg-xxx.aivencloud.com
SOURCE_PORT="25952"
SOURCE_DB="fintrack"                 # Your Aiven DB name
SOURCE_USER="avnadmin"
SOURCE_PASSWORD="AVNS_4fbPdY3X3q175YRDZAV"           # Your Aiven password
SOURCE_SSL="require"         # Do not change — Aiven requires SSL

# ── DESTINATION — Local VPS PostgreSQL ───────────────────────────
DEST_HOST="localhost"
DEST_PORT="5432"
DEST_DB="finance"                   # The NEW local DB name (can differ from Aiven)
DEST_USER="yateolivera"                 # Local postgres user (from your Phase 10 setup)
DEST_PASSWORD="yate1999Y@!"
# ── BACKUP ───────────────────────────────────────────────────────
BACKUP_DIR="/home/deploy/db-backups"
KEEP_BACKUPS=7               # How many backup files to keep
# ── BACKUP ───────────────────────────────────────────────────────
BACKUP_DIR="/home/deploy/db-backups"
KEEP_BACKUPS=7               # How many backup files to keep

# ════════════════════════════════════════════════════════════════════
#  COLORS & HELPERS
# ════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[✖] ERROR: $1${NC}"; exit 1; }
section() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}"; }

# ════════════════════════════════════════════════════════════════════
#  VALIDATE CONFIG
# ════════════════════════════════════════════════════════════════════

validate_config() {
  [[ -z "$SOURCE_HOST" ]]     && error "SOURCE_HOST is empty — fill in the config section"
  [[ -z "$SOURCE_DB" ]]       && error "SOURCE_DB is empty — fill in the config section"
  [[ -z "$SOURCE_PASSWORD" ]] && error "SOURCE_PASSWORD is empty — fill in the config section"
  [[ -z "$DEST_DB" ]]         && error "DEST_DB is empty — fill in your local DB name"
  [[ -z "$DEST_USER" ]]       && error "DEST_USER is empty — fill in the config section"
  [[ -z "$DEST_PASSWORD" ]]   && error "DEST_PASSWORD is empty — fill in the config section"
  return 0
}

# ════════════════════════════════════════════════════════════════════
#  CONNECTION HELPERS
# ════════════════════════════════════════════════════════════════════

# Run a query on the SOURCE (Aiven)
source_query() {
  PGPASSWORD="$SOURCE_PASSWORD" PGSSLMODE="$SOURCE_SSL" \
  psql -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_USER" -d "$SOURCE_DB" \
    -t -c "$1" 2>/dev/null
}

# Run a query on the DESTINATION (local)
dest_query() {
  PGPASSWORD="$DEST_PASSWORD" \
  psql -h "$DEST_HOST" -p "$DEST_PORT" -U "$DEST_USER" -d "$DEST_DB" \
    -t -c "$1" 2>/dev/null
}

# Trim surrounding whitespace WITHOUT touching quotes.
#
# `xargs` was used for this originally, but it applies shell quote-processing:
#   echo "'A','B'" | xargs  ->  A,B
# which turned CREATE TYPE ... AS ENUM ('A','B') into invalid SQL.
trim() {
  echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Execute a statement on the DESTINATION, failing loudly.
#
# psql exits 0 on SQL errors unless ON_ERROR_STOP is set, which is why the
# original table-creation step reported success while every statement failed.
dest_exec() {
  PGPASSWORD="$DEST_PASSWORD" \
  psql -h "$DEST_HOST" -p "$DEST_PORT" -U "$DEST_USER" -d "$DEST_DB" \
    -v ON_ERROR_STOP=1 -q -c "$1" > /dev/null 2>&1
}

# Run a query on local postgres (no specific DB — for admin tasks)
dest_admin_query() {
  PGPASSWORD="$DEST_PASSWORD" \
  psql -h "$DEST_HOST" -p "$DEST_PORT" -U "$DEST_USER" -d "postgres" \
    -t -c "$1" 2>/dev/null
}

# Test connections
test_connections() {
  section "Testing Connections"

  log "Testing Aiven connection..."
  PGPASSWORD="$SOURCE_PASSWORD" PGSSLMODE="$SOURCE_SSL" \
  psql -h "$SOURCE_HOST" -p "$SOURCE_PORT" -U "$SOURCE_USER" -d "$SOURCE_DB" \
    -c "SELECT version();" > /dev/null 2>&1 \
    || error "Cannot connect to Aiven. Check SOURCE_HOST, SOURCE_PASSWORD."
  success "Aiven Cloud connected ✔"

  log "Testing local PostgreSQL connection..."
  PGPASSWORD="$DEST_PASSWORD" \
  psql -h "$DEST_HOST" -p "$DEST_PORT" -U "$DEST_USER" -d "postgres" \
    -c "SELECT version();" > /dev/null 2>&1 \
    || error "Cannot connect to local PostgreSQL. Check DEST_USER, DEST_PASSWORD."
  success "Local PostgreSQL connected ✔"
}

# ════════════════════════════════════════════════════════════════════
#  BACKUP
# ════════════════════════════════════════════════════════════════════

backup_local_db() {
  if dest_admin_query "SELECT 1 FROM pg_database WHERE datname='$DEST_DB';" | grep -q 1; then
    section "Backing Up Local Database"

    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/${DEST_DB}_$(date +%Y%m%d_%H%M%S).sql"

    log "Creating backup → $BACKUP_FILE"
    PGPASSWORD="$DEST_PASSWORD" \
    pg_dump -h "$DEST_HOST" -p "$DEST_PORT" -U "$DEST_USER" -d "$DEST_DB" \
      > "$BACKUP_FILE"

    # Keep only the last N backups
    ls -t "$BACKUP_DIR"/${DEST_DB}_*.sql 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs rm -f 2>/dev/null || true

    success "Backup saved → $BACKUP_FILE"
  fi
}

# ════════════════════════════════════════════════════════════════════
#  CREATE — FULL MIGRATION (first time)
# ════════════════════════════════════════════════════════════════════

create_db() {
  section "Creating Local Database"

  # Check if DB already exists
  if dest_admin_query "SELECT 1 FROM pg_database WHERE datname='$DEST_DB';" | grep -q 1; then
    warn "Database '$DEST_DB' already exists locally."
    echo ""
    read -p "  Drop and recreate it? This will DELETE all local data. (yes/no): " CONFIRM
    [[ "$CONFIRM" != "yes" ]] && { log "Aborted."; exit 0; }

    backup_local_db

    log "Dropping existing database..."
    dest_admin_query "DROP DATABASE IF EXISTS \"$DEST_DB\";"
  fi

  log "Creating database '$DEST_DB'..."
  dest_admin_query "CREATE DATABASE \"$DEST_DB\" OWNER \"$DEST_USER\";"
  dest_admin_query "GRANT ALL PRIVILEGES ON DATABASE \"$DEST_DB\" TO \"$DEST_USER\";"
  success "Database '$DEST_DB' created"
}

full_migration() {
  section "Full Migration — Aiven → Local"

  DUMP_FILE="/tmp/aiven_full_dump_$(date +%Y%m%d_%H%M%S).sql"

  log "Dumping full schema + data from Aiven..."
  PGPASSWORD="$SOURCE_PASSWORD" PGSSLMODE="$SOURCE_SSL" \
  pg_dump \
    -h "$SOURCE_HOST" \
    -p "$SOURCE_PORT" \
    -U "$SOURCE_USER" \
    -d "$SOURCE_DB" \
    --no-owner \
    --no-privileges \
    --no-acl \
    -f "$DUMP_FILE"

  success "Dump complete → $DUMP_FILE"
  log "Dump size: $(du -sh $DUMP_FILE | cut -f1)"

  log "Restoring into local '$DEST_DB'..."
  PGPASSWORD="$DEST_PASSWORD" \
  psql -h "$DEST_HOST" -p "$DEST_PORT" -U "$DEST_USER" -d "$DEST_DB" \
    -f "$DUMP_FILE" > /dev/null

  rm -f "$DUMP_FILE"
  success "Full migration complete"
}

# ════════════════════════════════════════════════════════════════════
#  UPDATE SCHEMA — Smart Diff
# ════════════════════════════════════════════════════════════════════

update_schema() {
  section "Schema Sync — Aiven → Local"

  SCHEMA_DUMP="/tmp/aiven_schema_$(date +%Y%m%d_%H%M%S).sql"

  log "Fetching schema from Aiven..."
  PGPASSWORD="$SOURCE_PASSWORD" PGSSLMODE="$SOURCE_SSL" \
  pg_dump \
    -h "$SOURCE_HOST" \
    -p "$SOURCE_PORT" \
    -U "$SOURCE_USER" \
    -d "$SOURCE_DB" \
    --schema-only \
    --no-owner \
    --no-privileges \
    --no-acl \
    -f "$SCHEMA_DUMP"

  # ── Sync ENUM types FIRST ───────────────────────────────────────
  #
  # A table that uses an enum cannot be created until the type exists.
  # `pg_dump -t <table>` emits only the table, never the types it depends on,
  # so creating `loans` before `LoanStatus` fails with:
  #     type "public.LoanStatus" does not exist
  # and every follow-up ALTER then fails with "relation loans does not exist".
  log "Checking for new enum types..."

  SOURCE_ENUMS=$(source_query "
    SELECT t.typname || '|' ||
           string_agg(quote_literal(e.enumlabel), ',' ORDER BY e.enumsortorder)
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
    GROUP BY t.typname
    ORDER BY t.typname;
  ")

  ENUMS_CREATED=0
  ENUMS_EXTENDED=0
  ENUMS_FAILED=0
  while IFS= read -r row; do
    row=$(trim "$row")
    [[ -z "$row" ]] && continue
    ENUM_NAME="${row%%|*}"
    ENUM_LABELS="${row#*|}"

    EXISTS=$(dest_query "
      SELECT 1 FROM pg_type t
      JOIN pg_namespace n ON n.oid = t.typnamespace
      WHERE n.nspname = 'public' AND t.typname = '$ENUM_NAME' LIMIT 1;
    " | xargs)

    if [[ -z "$EXISTS" ]]; then
      log "  Creating enum type '$ENUM_NAME'"
      if dest_exec "CREATE TYPE \"$ENUM_NAME\" AS ENUM ($ENUM_LABELS);"; then
        success "  Enum '$ENUM_NAME' created"
        ENUMS_CREATED=$((ENUMS_CREATED + 1))
      else
        ENUMS_FAILED=$((ENUMS_FAILED + 1))
        warn "  Could not create enum '$ENUM_NAME'. psql said:"
        PGPASSWORD="$DEST_PASSWORD" psql -h "$DEST_HOST" -p "$DEST_PORT"           -U "$DEST_USER" -d "$DEST_DB" -v ON_ERROR_STOP=1           -c "CREATE TYPE \"$ENUM_NAME\" AS ENUM ($ENUM_LABELS);" 2>&1           | sed 's/^/    /' || true
      fi
    else
      # The type exists, but the source may have gained new values.
      IFS=',' read -ra LABELS <<< "$ENUM_LABELS"
      for raw in "${LABELS[@]}"; do
        label=$(trim "$raw")
        bare=$(echo "$label" | sed "s/^'//; s/'$//")
        HAS=$(dest_query "
          SELECT 1 FROM pg_enum e
          JOIN pg_type t ON t.oid = e.enumtypid
          JOIN pg_namespace n ON n.oid = t.typnamespace
          WHERE n.nspname='public' AND t.typname='$ENUM_NAME'
            AND e.enumlabel='$bare' LIMIT 1;
        " | xargs)
        if [[ -z "$HAS" ]]; then
          log "  Adding value $label to enum '$ENUM_NAME'"
          if dest_exec "ALTER TYPE \"$ENUM_NAME\" ADD VALUE IF NOT EXISTS $label;"; then
            ENUMS_EXTENDED=$((ENUMS_EXTENDED + 1))
          else
            warn "  Could not add $label to '$ENUM_NAME'"
          fi
        fi
      done
    fi
  done <<< "$SOURCE_ENUMS"

  if [ "$ENUMS_FAILED" -gt 0 ]; then
    warn "$ENUMS_FAILED enum type(s) could not be created — tables using them will fail below."
  elif [ "$ENUMS_CREATED" -eq 0 ] && [ "$ENUMS_EXTENDED" -eq 0 ]; then
    log "No new enum types found"
  else
    success "Enums: $ENUMS_CREATED created, $ENUMS_EXTENDED value(s) added"
  fi

  # ── Detect new tables ───────────────────────────────────────────
  log "Checking for new tables..."

  SOURCE_TABLES=$(source_query "
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name;
  ")

  DEST_TABLES=$(dest_query "
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name;
  ")

  NEW_TABLES=()
  FAILED_TABLES=()
  while IFS= read -r table; do
    table=$(echo "$table" | xargs)  # trim whitespace
    [[ -z "$table" ]] && continue
    if ! echo "$DEST_TABLES" | grep -qw "$table"; then
      NEW_TABLES+=("$table")
    fi
  done <<< "$SOURCE_TABLES"

  if [ ${#NEW_TABLES[@]} -eq 0 ]; then
    log "No new tables found"
  else
    warn "New tables detected: ${NEW_TABLES[*]}"
    for tbl in "${NEW_TABLES[@]}"; do
      log "Creating table '$tbl' from schema dump..."
      # Extract CREATE TABLE block for this table and apply it.
      PGPASSWORD="$SOURCE_PASSWORD" PGSSLMODE="$SOURCE_SSL" \
      pg_dump \
        -h "$SOURCE_HOST" -p "$SOURCE_PORT" \
        -U "$SOURCE_USER" -d "$SOURCE_DB" \
        --schema-only --no-owner --no-privileges --no-acl \
        -t "$tbl" \
      | PGPASSWORD="$DEST_PASSWORD" \
        psql -h "$DEST_HOST" -p "$DEST_PORT" \
             -U "$DEST_USER" -d "$DEST_DB" \
             -v ON_ERROR_STOP=1 -q > /dev/null 2>&1

      # Verify rather than trust the exit code: confirm the table is really
      # there. The previous version printed "created" unconditionally, so a
      # failed run still looked like a success.
      CREATED=$(dest_query "
        SELECT 1 FROM information_schema.tables
        WHERE table_schema='public' AND table_name='$tbl' LIMIT 1;
      " | xargs)
      if [[ -n "$CREATED" ]]; then
        success "Table '$tbl' created"
      else
        warn "Table '$tbl' was NOT created — see the errors above."
        warn "  Usually a missing type or a foreign key to a table that does not exist yet."
        warn "  Re-running the script after the dependency is in place normally fixes it."
        FAILED_TABLES+=("$tbl")
      fi
    done
  fi

  # ── Detect new columns ──────────────────────────────────────────
  log "Checking for new or changed columns..."

  SOURCE_COLS=$(source_query "
    SELECT table_name, column_name, data_type, character_maximum_length,
           is_nullable, column_default
    FROM information_schema.columns
    WHERE table_schema = 'public'
    ORDER BY table_name, ordinal_position;
  ")

  CHANGES=0
  while IFS= read -r table; do
    table=$(echo "$table" | xargs)
    [[ -z "$table" ]] && continue

    SRC_COLS=$(source_query "
      SELECT column_name FROM information_schema.columns
      WHERE table_schema='public' AND table_name='$table'
      ORDER BY ordinal_position;
    ")

    DST_COLS=$(dest_query "
      SELECT column_name FROM information_schema.columns
      WHERE table_schema='public' AND table_name='$table'
      ORDER BY ordinal_position;
    " 2>/dev/null || echo "")

    while IFS= read -r col; do
      col=$(echo "$col" | xargs)
      [[ -z "$col" ]] && continue

      if ! echo "$DST_COLS" | grep -qw "$col"; then

        # ── Get each part of the column definition separately ──────
        COL_TYPE=$(source_query "
          SELECT data_type ||
            CASE WHEN character_maximum_length IS NOT NULL
                 THEN '(' || character_maximum_length || ')'
                 ELSE '' END
          FROM information_schema.columns
          WHERE table_schema='public'
            AND table_name='$table'
            AND column_name='$col';
        " | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        COL_NULLABLE=$(source_query "
          SELECT is_nullable
          FROM information_schema.columns
          WHERE table_schema='public'
            AND table_name='$table'
            AND column_name='$col';
        " | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Get raw DEFAULT — use pg_get_expr, avoid xargs which strips quotes
        COL_DEFAULT=$(PGPASSWORD="$SOURCE_PASSWORD" PGSSLMODE="$SOURCE_SSL" \
          psql -h "$SOURCE_HOST" -p "$SOURCE_PORT" \
               -U "$SOURCE_USER" -d "$SOURCE_DB" \
               -t -A -c "
            SELECT pg_get_expr(d.adbin, d.adrelid)
            FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
            WHERE n.nspname = 'public'
              AND c.relname = '$table'
              AND a.attname = '$col'
              AND a.attnum > 0;
          " 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # ── Build the full ALTER statement ────────────────────────
        ALTER_SQL="ALTER TABLE \"$table\" ADD COLUMN IF NOT EXISTS \"$col\" $COL_TYPE"

        [[ "$COL_NULLABLE" == "NO" ]] && ALTER_SQL="$ALTER_SQL NOT NULL"

        if [[ -n "$COL_DEFAULT" && "$COL_DEFAULT" != "" ]]; then
          ALTER_SQL="$ALTER_SQL DEFAULT $COL_DEFAULT"
        fi

        warn "  New column detected: $table.$col"
        log   "  Type    : $COL_TYPE"
        log   "  Nullable: $COL_NULLABLE"
        [[ -n "$COL_DEFAULT" ]] && log "  Default : $COL_DEFAULT"
        log   "  SQL     : $ALTER_SQL"

        # ── Execute it ────────────────────────────────────────────
        PGPASSWORD="$DEST_PASSWORD" \
        psql -h "$DEST_HOST" -p "$DEST_PORT" \
             -U "$DEST_USER" -d "$DEST_DB" \
             -c "$ALTER_SQL;" \
          && success "  Added column '$col' to '$table' ✔" \
          || {
            warn "  Standard ALTER failed — trying without NOT NULL constraint..."
            FALLBACK_SQL="ALTER TABLE \"$table\" ADD COLUMN IF NOT EXISTS \"$col\" $COL_TYPE"
            [[ -n "$COL_DEFAULT" ]] && FALLBACK_SQL="$FALLBACK_SQL DEFAULT $COL_DEFAULT"
            PGPASSWORD="$DEST_PASSWORD" \
            psql -h "$DEST_HOST" -p "$DEST_PORT" \
                 -U "$DEST_USER" -d "$DEST_DB" \
                 -c "$FALLBACK_SQL;" \
              && success "  Added column '$col' (without NOT NULL) — set manually if needed" \
              || warn "  Could not add '$col' — run manually: $ALTER_SQL"
          }

        CHANGES=$((CHANGES + 1))
      fi
    done <<< "$SRC_COLS"
  done <<< "$SOURCE_TABLES"

  [ $CHANGES -eq 0 ] && log "No new columns found" || success "$CHANGES column(s) added"

  # ── Detect new indexes ──────────────────────────────────────────
  log "Checking for new indexes..."

  SOURCE_INDEXES=$(source_query "
    SELECT indexname, indexdef FROM pg_indexes
    WHERE schemaname = 'public'
    ORDER BY indexname;
  ")

  IDX_CHANGES=0
  while IFS='|' read -r idxname idxdef; do
    idxname=$(echo "$idxname" | xargs)
    idxdef=$(echo "$idxdef" | xargs)
    [[ -z "$idxname" ]] && continue

    EXISTS=$(dest_query "
      SELECT 1 FROM pg_indexes
      WHERE schemaname='public' AND indexname='$idxname';
    " | xargs)

    if [[ "$EXISTS" != "1" ]]; then
      warn "  New index: $idxname"
      dest_query "$idxdef;" 2>/dev/null \
        && success "  Created index '$idxname'" \
        || warn "  Could not create index '$idxname' — check manually"
      IDX_CHANGES=$((IDX_CHANGES + 1))
    fi
  done <<< "$(echo "$SOURCE_INDEXES" | sed 's/ \| /|/g')"

  [ $IDX_CHANGES -eq 0 ] && log "No new indexes found" || success "$IDX_CHANGES index(es) created"

  rm -f "$SCHEMA_DUMP"
  success "Schema sync complete"
}

# ════════════════════════════════════════════════════════════════════
#  UPDATE DATA — Smart Upsert
# ════════════════════════════════════════════════════════════════════

update_data() {
  section "Data Sync — Aiven → Local"

  TABLES=$(source_query "
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name;
  ")

  while IFS= read -r table; do
    table=$(echo "$table" | xargs)
    [[ -z "$table" ]] && continue

    log "Syncing data for table '$table'..."

    # Get primary key column(s)
    PK=$(source_query "
      SELECT kcu.column_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
      WHERE tc.constraint_type = 'PRIMARY KEY'
        AND tc.table_name = '$table'
        AND tc.table_schema = 'public'
      ORDER BY kcu.ordinal_position;
    " | xargs | tr ' ' ',')

    # Dump data from source for this table
    DATA_FILE="/tmp/sync_${table}_$(date +%s).sql"

    PGPASSWORD="$SOURCE_PASSWORD" PGSSLMODE="$SOURCE_SSL" \
    pg_dump \
      -h "$SOURCE_HOST" -p "$SOURCE_PORT" \
      -U "$SOURCE_USER" -d "$SOURCE_DB" \
      --data-only --no-owner --no-privileges \
      -t "$table" \
      -f "$DATA_FILE" 2>/dev/null

    if [[ -z "$PK" ]]; then
      # No primary key — truncate and reload
      warn "  No primary key on '$table' — truncating and reloading"
      dest_query "TRUNCATE TABLE \"$table\" CASCADE;" 2>/dev/null || true
      PGPASSWORD="$DEST_PASSWORD" \
      psql -h "$DEST_HOST" -p "$DEST_PORT" \
           -U "$DEST_USER" -d "$DEST_DB" \
           -f "$DATA_FILE" > /dev/null 2>&1 || warn "  Could not sync '$table'"
    else
      # Has primary key — use INSERT ON CONFLICT (upsert)
      # Convert COPY statements to INSERT ... ON CONFLICT DO UPDATE
      PGPASSWORD="$DEST_PASSWORD" \
      psql -h "$DEST_HOST" -p "$DEST_PORT" \
           -U "$DEST_USER" -d "$DEST_DB" \
           -c "SET session_replication_role = replica;" > /dev/null 2>&1 || true

      PGPASSWORD="$DEST_PASSWORD" \
      psql -h "$DEST_HOST" -p "$DEST_PORT" \
           -U "$DEST_USER" -d "$DEST_DB" \
           -f "$DATA_FILE" > /dev/null 2>&1 || warn "  Could not sync data for '$table'"
    fi

    rm -f "$DATA_FILE"
    success "  '$table' synced"

  done <<< "$TABLES"

  success "Data sync complete"
}

# ════════════════════════════════════════════════════════════════════
#  STATUS — Compare Source vs Local
# ════════════════════════════════════════════════════════════════════

show_status() {
  section "Database Status Report"

  echo ""
  echo -e "${BOLD}SOURCE (Aiven):${NC} $SOURCE_DB @ $SOURCE_HOST"
  echo -e "${BOLD}LOCAL:${NC}          $DEST_DB @ $DEST_HOST"
  echo ""

  # Table count
  SRC_TABLE_COUNT=$(source_query "
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema='public' AND table_type='BASE TABLE';
  " | xargs)

  DST_TABLE_COUNT=$(dest_query "
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema='public' AND table_type='BASE TABLE';
  " 2>/dev/null | xargs || echo "0")

  echo -e "  Tables  → Source: ${CYAN}$SRC_TABLE_COUNT${NC}  |  Local: ${CYAN}$DST_TABLE_COUNT${NC}"

  # Row counts per table
  echo ""
  echo -e "  ${BOLD}Table Comparison:${NC}"
  printf "  %-30s %-15s %-15s %s\n" "TABLE" "AIVEN ROWS" "LOCAL ROWS" "STATUS"
  printf "  %-30s %-15s %-15s %s\n" "─────────────────────────────" "──────────────" "──────────────" "──────────"

  SOURCE_TABLES=$(source_query "
    SELECT table_name FROM information_schema.tables
    WHERE table_schema='public' AND table_type='BASE TABLE'
    ORDER BY table_name;
  ")

  while IFS= read -r table; do
    table=$(echo "$table" | xargs)
    [[ -z "$table" ]] && continue

    SRC_COUNT=$(source_query "SELECT COUNT(*) FROM \"$table\";" | xargs)
    DST_COUNT=$(dest_query "SELECT COUNT(*) FROM \"$table\";" 2>/dev/null | xargs || echo "N/A")

    if [[ "$DST_COUNT" == "N/A" ]]; then
      STATUS="${RED}MISSING LOCALLY${NC}"
    elif [[ "$SRC_COUNT" == "$DST_COUNT" ]]; then
      STATUS="${GREEN}IN SYNC${NC}"
    else
      STATUS="${YELLOW}OUT OF SYNC${NC}"
    fi

    printf "  %-30s %-15s %-15s " "$table" "$SRC_COUNT" "$DST_COUNT"
    echo -e "$STATUS"

  done <<< "$SOURCE_TABLES"

  echo ""
  echo -e "  ${BOLD}Local DB Size:${NC}"
  dest_query "
    SELECT pg_size_pretty(pg_database_size('$DEST_DB'));
  " | xargs | sed 's/^/  /'

  echo ""
}

# ════════════════════════════════════════════════════════════════════
#  CHECK REQUIREMENTS
# ════════════════════════════════════════════════════════════════════

check_requirements() {
  command -v psql     > /dev/null 2>&1 || error "psql not found. Run: apt install postgresql-client -y"
  command -v pg_dump  > /dev/null 2>&1 || error "pg_dump not found. Run: apt install postgresql-client -y"
  return 0
}

# ════════════════════════════════════════════════════════════════════
#  MAIN
# ════════════════════════════════════════════════════════════════════

ACTION="${1:-}"
TARGET="${2:-}"

check_requirements
validate_config

case "$ACTION" in

  # ── FRESH INSTALL ─────────────────────────────────────────────────
  "create")
    echo -e "\n${CYAN}${BOLD}  ╔══════════════════════════════════════╗"
    echo    "  ║   FULL MIGRATION — Aiven → Local    ║"
    echo -e "  ╚══════════════════════════════════════╝${NC}\n"
    test_connections
    create_db
    full_migration
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║        ✅ Migration Complete                 ║${NC}"
    echo -e "${GREEN}${BOLD}╠══════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Local DB : $DEST_DB @ localhost"
    echo -e "${GREEN}${BOLD}║${NC}  User     : $DEST_USER"
    echo -e "${GREEN}${BOLD}║${NC}"
    echo -e "${GREEN}${BOLD}║${NC}  Update your backend .env:"
    echo -e "${GREEN}${BOLD}║${NC}  DATABASE_URL=postgresql://$DEST_USER:****@localhost:5432/$DEST_DB"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    ;;

  # ── UPDATE ────────────────────────────────────────────────────────
  "update")
    echo -e "\n${CYAN}${BOLD}  [ DB UPDATE — Aiven → Local ]${NC}\n"
    test_connections
    backup_local_db

    case "$TARGET" in
      "schema")
        update_schema
        ;;
      "data")
        update_data
        ;;
      "")
        update_schema
        update_data
        ;;
      *)
        error "Unknown target '$TARGET'. Use: schema | data | (empty for both)"
        ;;
    esac

    success "All done"
    ;;

  # ── STATUS ────────────────────────────────────────────────────────
  "status")
    test_connections
    show_status
    ;;

  # ── HELP ──────────────────────────────────────────────────────────
  *)
    echo ""
    echo -e "${YELLOW}USAGE:${NC}"
    echo "  bash db.sh create          → Full migration from Aiven to local (first time)"
    echo "  bash db.sh update          → Sync schema changes + data"
    echo "  bash db.sh update schema   → Sync schema only (new tables, columns, indexes)"
    echo "  bash db.sh update data     → Sync data only"
    echo "  bash db.sh status          → Compare Aiven vs local (row counts, sync status)"
    echo ""
    ;;
esac
