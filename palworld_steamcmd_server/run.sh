#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"

# SteamCMD bleibt im Container (ausführbar!)
STEAMCMD="/opt/steamcmd/steamcmd.sh"

# Alles Persistente auf den Host (/share)
BASE="/share/palworld"
SERVER_DIR="${BASE}/server"
CONFIG_DIR="${BASE}/config"
STEAM_HOME="${BASE}/steam_home"
INI_FILE="${CONFIG_DIR}/PalWorldSettings.ini"
GAME_CFG_DIR="${SERVER_DIR}/Pal/Saved/Config/LinuxServer"

GAME_PORT=8211
QUERY_PORT=27015

echo "▶ Palworld Add-on startet (SteamCMD exec aus /opt, Daten nach /share)…"

if [[ ! -f "${OPTIONS_FILE}" ]]; then
  echo "❌ options.json nicht gefunden: ${OPTIONS_FILE}"
  exit 1
fi

APP_ID="$(jq -r '.app_id // empty' "${OPTIONS_FILE}")"
STEAM_USER="$(jq -r '.steam_user // "anonymous"' "${OPTIONS_FILE}")"
STEAM_PASS="$(jq -r '.steam_pass // ""' "${OPTIONS_FILE}")"
UPDATE_ON_BOOT="$(jq -r '.update_on_boot // true' "${OPTIONS_FILE}")"

if [[ -z "${APP_ID}" || "${APP_ID}" == "null" ]]; then
  echo "❌ app_id fehlt"
  exit 1
fi

mkdir -p "${BASE}" "${SERVER_DIR}" "${CONFIG_DIR}" "${STEAM_HOME}" "${GAME_CFG_DIR}"
chown -R steam:steam "${BASE}" || true
chown -R steam:steam /opt/steamcmd || true
chmod +x "${STEAMCMD}" || true

steam_update() {
  local login_args=(+login "${STEAM_USER}")
  if [[ "${STEAM_USER}" != "anonymous" && -n "${STEAM_PASS}" ]]; then
    login_args=(+login "${STEAM_USER}" "${STEAM_PASS}")
  fi

  gosu steam:steam env HOME="${STEAM_HOME}" "${STEAMCMD}" \
    +force_install_dir "${SERVER_DIR}" \
    "${login_args[@]}" \
    +app_update "${APP_ID}" validate \
    +quit
}

if [[ "${UPDATE_ON_BOOT}" == "true" ]]; then
  echo "▶ SteamCMD: Install/Update Palworld nach ${SERVER_DIR}"
  steam_update
else
  echo "ℹ️ update_on_boot=false – überspringe Update"
fi

# Default Config nur einmal erzeugen
if [[ ! -f "${INI_FILE}" ]]; then
  echo "▶ Erzeuge Default PalWorldSettings.ini unter /share"
  cat > "${INI_FILE}" <<'EOF'
[/Script/Pal.PalGameWorldSettings]
OptionSettings=(
  ServerName="Palworld Server",
  ServerDescription="",
  ServerPassword="",
  AdminPassword="",
  ServerPlayerMaxNum=32,
  DayTimeSpeedRate=1.0,
  NightTimeSpeedRate=1.0,
  ExpRate=1.0,
  PalSpawnNumRate=1.0,
  DeathPenalty="All",
  bEnableFastTravel=True,
  bEnableInvaderEnemy=True,
  bIsUseBackupSaveData=True,
  LogFormatType="Text"
)
EOF
  chown steam:steam "${INI_FILE}" || true
fi

# Config ins Spiel spiegeln
mkdir -p "${GAME_CFG_DIR}"
cp -f "${INI_FILE}" "${GAME_CFG_DIR}/PalWorldSettings.ini"
chown -R steam:steam "${SERVER_DIR}/Pal/Saved/Config" || true

# steamclient.so fix (falls vorhanden)
if [[ -f "${SERVER_DIR}/linux64/steamclient.so" ]]; then
  mkdir -p "${SERVER_DIR}/Pal/Binaries/Linux"
  cp -f "${SERVER_DIR}/linux64/steamclient.so" \
        "${SERVER_DIR}/Pal/Binaries/Linux/steamclient.so" || true
fi

SERVER_SH="${SERVER_DIR}/PalServer.sh"
SERVER_BIN="${SERVER_DIR}/Pal/Binaries/Linux/PalServer-Linux-Shipping"

echo "▶ Starte Palworld Server…"
if [[ -x "${SERVER_SH}" ]]; then
  exec gosu steam:steam env HOME="${STEAM_HOME}" "${SERVER_SH}" \
    -port="${GAME_PORT}" \
    -queryport="${QUERY_PORT}" \
    -useperfthreads \
    -NoAsyncLoadingThread \
    -UseMultithreadForDS
elif [[ -x "${SERVER_BIN}" ]]; then
  exec gosu steam:steam env HOME="${STEAM_HOME}" "${SERVER_BIN}" \
    -port="${GAME_PORT}" \
    -queryport="${QUERY_PORT}" \
    -useperfthreads \
    -NoAsyncLoadingThread \
    -UseMultithreadForDS
else
  echo "❌ Palworld Server Binary nicht gefunden in ${SERVER_DIR}"
  exit 1
fi
