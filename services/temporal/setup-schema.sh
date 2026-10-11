#!/bin/sh
# Railway pre-deploy command for the Temporal service.
# Creates the persistence and visibility databases if needed and applies all
# pending schema versions. Safe to run on every deploy: setup-schema skips when
# a newer version exists and update-schema only applies missing versions, which
# is also how Temporal upgrades are performed (schema first, then server).
set -eu

: "${POSTGRES_SEEDS:?POSTGRES_SEEDS must be set}"
: "${POSTGRES_USER:?POSTGRES_USER must be set}"
: "${POSTGRES_PWD:?POSTGRES_PWD must be set}"

PLUGIN="${DB:-postgres12}"
PG_PORT="${DB_PORT:-5432}"
MAIN_DB="${DBNAME:-temporal}"
VIS_DB="${VISIBILITY_DBNAME:-temporal_visibility}"
SCHEMA_ROOT=/etc/temporal/schema/postgresql/v12
export SQL_PASSWORD="${POSTGRES_PWD}"

echo "[temporal-setup] waiting for PostgreSQL at ${POSTGRES_SEEDS}:${PG_PORT}"
i=0
until nc -z -w 5 "${POSTGRES_SEEDS}" "${PG_PORT}"; do
  i=$((i + 1))
  if [ "${i}" -ge 60 ]; then
    echo "[temporal-setup] FATAL: PostgreSQL not reachable after 5 minutes" >&2
    exit 1
  fi
  sleep 5
done

sqltool() {
  temporal-sql-tool --plugin "${PLUGIN}" --ep "${POSTGRES_SEEDS}" -p "${PG_PORT}" -u "${POSTGRES_USER}" "$@"
}

setup_db() {
  db="$1"
  schema_dir="$2"
  if sqltool --db "${db}" create --defaultdb postgres >/dev/null 2>&1; then
    echo "[temporal-setup] created database ${db}"
  else
    echo "[temporal-setup] database ${db} already exists (or create failed; the next step will tell)"
  fi
  sqltool --db "${db}" setup-schema -v 0.0
  sqltool --db "${db}" update-schema -d "${SCHEMA_ROOT}/${schema_dir}/versioned"
  echo "[temporal-setup] ${db} schema is current"
}

setup_db "${MAIN_DB}" temporal
setup_db "${VIS_DB}" visibility
echo "[temporal-setup] done"
