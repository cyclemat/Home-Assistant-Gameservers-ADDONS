#!/usr/bin/env bash
set -Eeuo pipefail

DATA=/data
PG_BIN="$(find /usr/lib/postgresql -maxdepth 2 -type f -name initdb | sort -V | tail -n1 | xargs dirname)"
PGDATA="$DATA/postgres"
REDISDIR="$DATA/redis"
PASSFILE="$DATA/db_password"
mkdir -p "$PGDATA" "$REDISDIR"
chmod 700 "$PGDATA"

# A private database password persists with the add-on data.
if [[ ! -f "$PASSFILE" ]]; then
  umask 077
  python - <<'PYGEN' > "$PASSFILE"
import secrets
print(secrets.token_urlsafe(32))
PYGEN
fi
DBPASS="$(cat "$PASSFILE")"

if [[ ! -f "$PGDATA/PG_VERSION" ]]; then
  echo '[club-penguin] Initialisiere persistente PostgreSQL-Datenbank'
  chown -R postgres:postgres "$PGDATA"
  runuser -u postgres -- "$PG_BIN/initdb" -D "$PGDATA" -A trust --no-instructions >/dev/null
  cat >> "$PGDATA/postgresql.conf" <<'PGCONF'
listen_addresses = '127.0.0.1'
port = 5432
unix_socket_directories = '/tmp'
PGCONF
  cat > "$PGDATA/pg_hba.conf" <<'HBA'
local all postgres trust
local all all scram-sha-256
host all all 127.0.0.1/32 scram-sha-256
host all all ::1/128 reject
HBA
fi
chown -R postgres:postgres "$PGDATA"
touch "$DATA/postgres.log"
chown postgres:postgres "$DATA/postgres.log"
"$PG_BIN/pg_ctl" --version
runuser -u postgres -- "$PG_BIN/pg_ctl" -D "$PGDATA" -l "$DATA/postgres.log" -w start
cleanup() {
  echo '[club-penguin] Stoppe Dienste'
  for pid in "${WORLD_PID:-}" "${LOGIN_PID:-}" "${REDIS_PID:-}"; do
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; fi
  done
  wait || true
  runuser -u postgres -- "$PG_BIN/pg_ctl" -D "$PGDATA" -m fast -w stop || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT

# Use localhost only for internal Redis and database services.
redis-server --bind 127.0.0.1 --port 6379 --dir "$REDISDIR" --save 60 1 --appendonly yes &
REDIS_PID=$!

runuser -u postgres -- psql -h /tmp -d postgres -v ON_ERROR_STOP=1 \
  -v "dbpass=$DBPASS" -c "ALTER USER postgres PASSWORD :'dbpass'" 2>/dev/null || \
  runuser -u postgres -- psql -h /tmp -d postgres -v ON_ERROR_STOP=1 \
  -c "ALTER USER postgres PASSWORD '$(printf '%s' "$DBPASS" | sed "s/'/''/g")'"

if [[ ! -f "$DATA/sql_imported" ]]; then
  echo '[club-penguin] Importiere Houdini-Datenbankschema'
  PGPASSWORD="$DBPASS" psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 \
    -f /opt/houdini/houdini.sql
  touch "$DATA/sql_imported"
fi

NAME="$(python -c 'import json; print(json.load(open("/data/options.json")).get("world_name", "blizzard"))')"
WORLD_ID="$(python -c 'import json; print(int(json.load(open("/data/options.json")).get("world_id",3100)))')"
LOG_LEVEL="$(python -c 'import json; print(json.load(open("/data/options.json")).get("log_level","INFO"))')"
cd /opt/houdini
COMMON=(--redis-address 127.0.0.1 --database-address 127.0.0.1 --database-user postgres --database-name postgres --database-password "$DBPASS")
echo '[club-penguin] Starte Loginserver auf TCP 6112'
python bootstrap.py login --port 6112 "${COMMON[@]}" &
LOGIN_PID=$!

# The world process needs the login server; fail rather than leave a half-started add-on.
python - <<'PYWAIT'
import socket,time,sys
for _ in range(90):
    try:
        with socket.create_connection(('127.0.0.1',6112),timeout=1): break
    except OSError: time.sleep(1)
else:
    print('[club-penguin] Loginserver nicht erreichbar', file=sys.stderr)
    sys.exit(1)
PYWAIT

echo "[club-penguin] Starte Welt $NAME (ID $WORLD_ID) auf TCP 9875"
python bootstrap.py world -id "$WORLD_ID" --name "$NAME" --port 9875 --lang en "${COMMON[@]}" &
WORLD_PID=$!

while kill -0 "$WORLD_PID" 2>/dev/null && kill -0 "$LOGIN_PID" 2>/dev/null && kill -0 "$REDIS_PID" 2>/dev/null; do
  sleep 3
done
echo '[club-penguin] Ein Dienst wurde unerwartet beendet' >&2
exit 1
