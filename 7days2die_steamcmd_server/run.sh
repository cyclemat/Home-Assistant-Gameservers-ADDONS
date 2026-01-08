#!/usr/bin/with-contenv sh
set -eu

# ==========================================================
# 7 Days to Die Dedicated Server (HAOS)
# Add-on: 7days2die_steamcmd_server
# ==========================================================

APP_ID="294420"

SERVER_DIR="/share/7days2die_dedicated"
SAVE_DIR="${SERVER_DIR}/Saves"
CONFIG_FILE="${SERVER_DIR}/serverconfig.xml"
LOG_FILE="${SERVER_DIR}/server.log"

STEAMCMD_DIR="/steamcmd"
STEAMCMD="${STEAMCMD_DIR}/steamcmd.sh"

OPTIONS="/data/options.json"

# ----------------------------------------------------------
# helpers
# ----------------------------------------------------------
is_true() {
  case "$1" in
    true|True|TRUE|1|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_steamcmd() {
  if [ -x "${STEAMCMD}" ]; then
    return 0
  fi

  echo ">>> SteamCMD not found – installing"
  mkdir -p "${STEAMCMD_DIR}"

  curl -fsSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
    | tar -xz -C "${STEAMCMD_DIR}"

  chmod +x "${STEAMCMD}" 2>/dev/null || true

  if [ ! -x "${STEAMCMD}" ]; then
    echo "ERROR: SteamCMD install failed"
    exit 1
  fi
}

ensure_steamclient() {
  echo ">>> Ensuring steamclient.so"

  mkdir -p /root/.steam/sdk64

  # typische Fundstellen
  if [ -f "${SERVER_DIR}/steamclient.so" ]; then
    ln -sf "${SERVER_DIR}/steamclient.so" /root/.steam/sdk64/steamclient.so
  elif [ -f "${SERVER_DIR}/linux64/steamclient.so" ]; then
    ln -sf "${SERVER_DIR}/linux64/steamclient.so" /root/.steam/sdk64/steamclient.so
  elif [ -f "${STEAMCMD_DIR}/linux64/steamclient.so" ]; then
    ln -sf "${STEAMCMD_DIR}/linux64/steamclient.so" /root/.steam/sdk64/steamclient.so
  fi

  if [ ! -f /root/.steam/sdk64/steamclient.so ]; then
    echo "ERROR: steamclient.so still missing"
    echo ">>> Debug search:"
    find "${SERVER_DIR}" "${STEAMCMD_DIR}" -name steamclient.so -ls 2>/dev/null || true
    exit 1
  fi

  # Loader-Hilfe
  export LD_LIBRARY_PATH="/root/.steam/sdk64:${SERVER_DIR}:${SERVER_DIR}/linux64:${STEAMCMD_DIR}/linux64:${LD_LIBRARY_PATH:-}"

  ls -lah /root/.steam/sdk64/steamclient.so || true
}

# ----------------------------------------------------------
# banner
# ----------------------------------------------------------
echo "======================================="
echo " 7 Days to Die Dedicated Server (HAOS)"
echo " Add-on: 7days2die_steamcmd_server"
echo " Server Dir: ${SERVER_DIR}"
echo "======================================="

# ----------------------------------------------------------
# prepare dirs
# ----------------------------------------------------------
mkdir -p "${SERVER_DIR}" "${SAVE_DIR}"
touch "${LOG_FILE}"

# ----------------------------------------------------------
# read HA options
# ----------------------------------------------------------
UPDATE_ON_BOOT="$(jq -r '.update_on_boot // true' "$OPTIONS")"
VALIDATE="$(jq -r '.validate // false' "$OPTIONS")"
STREAM_LOG="$(jq -r '.stream_log // true' "$OPTIONS")"

SERVER_NAME="$(jq -r '.server_name // "My Game Host"' "$OPTIONS")"
SERVER_DESC="$(jq -r '.server_description // "A 7 Days to Die server"' "$OPTIONS")"
SERVER_PASS="$(jq -r '.server_password // ""' "$OPTIONS")"
MAX_PLAYERS="$(jq -r '.max_players // 8' "$OPTIONS")"
GAME_NAME="$(jq -r '.game_name // "MyGame"' "$OPTIONS")"
GAME_DIFF="$(jq -r '.game_difficulty // 1' "$OPTIONS")"

TELNET_ENABLED="$(jq -r '.telnet_enabled // true' "$OPTIONS")"
EAC_ENABLED="$(jq -r '.eac_enabled // true' "$OPTIONS")"
WEB_ENABLED="$(jq -r '.web_dashboard_enabled // false' "$OPTIONS")"

# ----------------------------------------------------------
# serverconfig.xml
# ----------------------------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
  echo ">>> Creating default serverconfig.xml"
  cat > "$CONFIG_FILE" <<EOF
<?xml version="1.0"?>
<ServerSettings>
  <property name="ServerName" value="${SERVER_NAME}"/>
  <property name="ServerDescription" value="${SERVER_DESC}"/>
  <property name="ServerPassword" value="${SERVER_PASS}"/>
  <property name="ServerMaxPlayerCount" value="${MAX_PLAYERS}"/>

  <property name="GameName" value="${GAME_NAME}"/>
  <property name="GameDifficulty" value="${GAME_DIFF}"/>

  <property name="ServerPort" value="26900"/>

  <property name="TelnetEnabled" value="${TELNET_ENABLED}"/>
  <property name="TelnetPort" value="8081"/>

  <property name="WebDashboardEnabled" value="${WEB_ENABLED}"/>
  <property name="WebDashboardPort" value="8080"/>

  <property name="EACEnabled" value="${EAC_ENABLED}"/>

  <property name="SaveGameFolder" value="${SAVE_DIR}"/>
</ServerSettings>
EOF
else
  echo ">>> Using existing serverconfig.xml"
fi

# ----------------------------------------------------------
# SteamCMD update
# ----------------------------------------------------------
if is_true "$UPDATE_ON_BOOT"; then
  ensure_steamcmd

  echo ">>> Updating server via SteamCMD"
  if is_true "$VALIDATE"; then
    "${STEAMCMD}" +force_install_dir "${SERVER_DIR}" +login anonymous +app_update "${APP_ID}" validate +quit
  else
    "${STEAMCMD}" +force_install_dir "${SERVER_DIR}" +login anonymous +app_update "${APP_ID}" +quit
  fi
else
  echo ">>> update_on_boot disabled"
fi

# ----------------------------------------------------------
# Steamworks fix
# ----------------------------------------------------------
ensure_steamclient

# ----------------------------------------------------------
# start server
# ----------------------------------------------------------
echo ">>> Starting 7 Days to Die Server"
cd "${SERVER_DIR}"

./7DaysToDieServer.x86_64 \
  -logfile "${LOG_FILE}" \
  -batchmode -nographics \
  -configfile=serverconfig.xml &
SERVER_PID="$!"

if is_true "$STREAM_LOG"; then
  echo ">>> Streaming server.log into HA log"
  tail -n 50 -F "${LOG_FILE}" &
  TAIL_PID="$!"
fi

wait "${SERVER_PID}"

if [ "${TAIL_PID:-}" ]; then
  kill "${TAIL_PID}" 2>/dev/null || true
fi
