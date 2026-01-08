#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
log() { echo "[$(date +'%H:%M:%S')] $*"; }

jget() {
  local key="$1"
  local def="${2:-}"
  if [ -f "${OPTIONS_FILE}" ]; then
    local val
    val="$(jq -r --arg k "$key" '.[$k] // empty' "${OPTIONS_FILE}" 2>/dev/null || true)"
    if [ -n "${val}" ] && [ "${val}" != "null" ]; then
      echo "${val}"
      return
    fi
  fi
  echo "${def}"
}

APP_ID="$(jget app_id 896660)"
UPDATE_ON_BOOT="$(jget update_on_boot true)"
VALIDATE="$(jget validate false)"

SERVER_NAME="$(jget server_name "Valheim HAOS")"
WORLD_NAME="$(jget world_name "Dedicated")"
PASSWORD="$(jget password "changeme")"
PUBLIC="$(jget public true)"
PORT="$(jget port 2456)"
EXTRA_ARGS="$(jget extra_args "")"

STEAMCMD="/opt/steamcmd/steamcmd.sh"

BASE_DIR="/share/valheim"
SERVER_DIR="${BASE_DIR}/server"
DATA_DIR="${BASE_DIR}/data"

# Persistente "Home"/Unity/Steam Pfade
HOME_DIR="${BASE_DIR}/home"
XDG_CONFIG_HOME="${HOME_DIR}/.config"
XDG_DATA_HOME="${HOME_DIR}/.local/share"
XDG_CACHE_HOME="${HOME_DIR}/.cache"

mkdir -p "${SERVER_DIR}" "${DATA_DIR}" \
         "${HOME_DIR}" "${XDG_CONFIG_HOME}" "${XDG_DATA_HOME}" "${XDG_CACHE_HOME}"

export HOME="${HOME_DIR}"
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Passwort-Check (Valheim braucht >= 5 Zeichen)
if [ "${#PASSWORD}" -lt 5 ]; then
  log "ERROR: Valheim password must be at least 5 characters long!"
  exit 1
fi

# Public Flag
if [ "${PUBLIC}" = "true" ] || [ "${PUBLIC}" = "1" ]; then
  PUBLIC_FLAG="1"
else
  PUBLIC_FLAG="0"
fi

update_server() {
  log "INFO: Updating Valheim via SteamCMD (AppID ${APP_ID})..."

  local validate_arg=""
  if [ "${VALIDATE}" = "true" ] || [ "${VALIDATE}" = "1" ]; then
    validate_arg="validate"
  fi

  "${STEAMCMD}" \
    +force_install_dir "${SERVER_DIR}" \
    +login anonymous \
    +app_update "${APP_ID}" ${validate_arg} \
    +quit
}

if [ "${UPDATE_ON_BOOT}" = "true" ] || [ "${UPDATE_ON_BOOT}" = "1" ]; then
  update_server
else
  log "INFO: update_on_boot=false -> skipping update."
fi

VALHEIM_BIN="${SERVER_DIR}/valheim_server.x86_64"
if [ ! -x "${VALHEIM_BIN}" ]; then
  log "ERROR: Valheim server binary not found at: ${VALHEIM_BIN}"
  log "HINT: Set update_on_boot=true to download server files."
  ls -lah "${SERVER_DIR}" || true
  exit 1
fi

# ---- Steam Init Fix (entscheidend) ----
# Valheim/Steamworks sucht hier:
#   ~/.steam/sdk64/steamclient.so
# Wir verlinken sie aus SteamCMD:
STEAMCLIENT_SRC="/opt/steamcmd/linux64/steamclient.so"
STEAM_SDK64_DIR="${HOME}/.steam/sdk64"
mkdir -p "${STEAM_SDK64_DIR}"

if [ -f "${STEAMCLIENT_SRC}" ]; then
  ln -sf "${STEAMCLIENT_SRC}" "${STEAM_SDK64_DIR}/steamclient.so"
else
  log "WARN: steamclient.so not found at ${STEAMCLIENT_SRC}"
  log "WARN: Steam may fail to initialize."
fi

# Wichtig: Valheim Start-Skripte setzen i.d.R. diese Werte:
export LD_LIBRARY_PATH="${SERVER_DIR}/linux64:${LD_LIBRARY_PATH:-}"
export SteamAppId="892970"
export SteamGameId="892970"
# --------------------------------------

if [ "${PORT}" != "2456" ]; then
  log "WARN: port=${PORT} set. Recommended internal port is 2456; change external mapping in HA instead."
fi

log "INFO: Starting Valheim Dedicated Server"
log "INFO: Server files: ${SERVER_DIR}"
log "INFO: Save data:    ${DATA_DIR}"
log "INFO: HOME:         ${HOME_DIR}"
log "INFO: Steam SDK64:  ${STEAM_SDK64_DIR}"
log "INFO: Internal port: ${PORT} (also requires UDP $((PORT+1)) and $((PORT+2)))"

cd "${SERVER_DIR}"

exec "${VALHEIM_BIN}" \
  -name "${SERVER_NAME}" \
  -port "${PORT}" \
  -world "${WORLD_NAME}" \
  -password "${PASSWORD}" \
  -public "${PUBLIC_FLAG}" \
  -savedir "${DATA_DIR}" \
  -batchmode -nographics \
  ${EXTRA_ARGS}
