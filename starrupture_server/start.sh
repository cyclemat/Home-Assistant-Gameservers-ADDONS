#!/usr/bin/env bash
set -euo pipefail

################################
# FESTE KONFIG
################################
SERVER_PORT=7777
STEAMAPPID=3809400

################################
# OPTION (AUS HA)
################################
UPDATE_ON_START="${UPDATE_ON_START:-true}"

################################
# PFADE
################################
STEAMCMD="/opt/steamcmd/steamcmd.sh"
SERVER_DIR="/share/starrupture/server"
SAVE_DIR="/share/starrupture/savegame"

################################
# WINE
################################
export WINEPREFIX="/opt/wineprefix"

mkdir -p "$SERVER_DIR" "$SAVE_DIR" "$WINEPREFIX"

echo "=============================================="
echo "[StarRupture Dedicated Server]"
echo "SERVER_PORT     = $SERVER_PORT"
echo "STEAMAPPID      = $STEAMAPPID (windows forced)"
echo "UPDATE_ON_START = $UPDATE_ON_START"
echo "SERVER_DIR      = $SERVER_DIR"
echo "SAVE_DIR        = $SAVE_DIR"
echo "=============================================="

################################
# STEAMCMD UPDATE (PALWORLD FIX)
################################
steam_update_with_retry() {
  local tries=6
  local n=1

  while [ "$n" -le "$tries" ]; do
    echo "[SteamCMD] Update attempt $n/$tries"

    # Palworld-Fix: kaputte Downloads killen
    rm -rf "$SERVER_DIR/steamapps/downloading" \
           "$SERVER_DIR/steamapps/temp" 2>/dev/null || true

    set +e
    "$STEAMCMD" \
      +@ShutdownOnFailedCommand 1 \
      +@NoPromptForPassword 1 \
      +@sSteamCmdForcePlatformType windows \
      +force_install_dir "$SERVER_DIR" \
      +login anonymous \
      +app_update "$STEAMAPPID" validate \
      +quit
    rc=$?
    set -e

    if [ "$rc" -eq 0 ]; then
      echo "[SteamCMD] Update OK"
      return 0
    fi

    echo "[SteamCMD] Failed (rc=$rc) – retry in $((n*5))s"
    sleep $((n*5))
    n=$((n+1))
  done

  echo "[SteamCMD] Update FAILED"
  exit 1
}

if [ "$UPDATE_ON_START" = "true" ]; then
  steam_update_with_retry
else
  echo "[SteamCMD] Skipping update"
fi

################################
# SAVEGAMES NACH /share
################################
mkdir -p "$SERVER_DIR/StarRupture/Saved"
rm -rf "$SERVER_DIR/StarRupture/Saved/SaveGames"
ln -s "$SAVE_DIR" "$SERVER_DIR/StarRupture/Saved/SaveGames"

################################
# EXE AUTO-DETECT
################################
detect_exe() {
  local candidates=(
    "$SERVER_DIR/StarRupture/Binaries/Win64/StarRuptureServerEOS-Win64-Shipping.exe"
    "$SERVER_DIR/StarRupture/Binaries/Win64/StarRuptureServerEOS.exe"
    "$SERVER_DIR/StarRuptureServerEOS.exe"
    "$SERVER_DIR/StarRuptureServerEOS-Win64-Shipping.exe"
  )

  for p in "${candidates[@]}"; do
    if [ -f "$p" ]; then
      echo "$p"
      return 0
    fi
  done

  find "$SERVER_DIR" -maxdepth 6 -type f -iname "StarRuptureServerEOS*.exe" 2>/dev/null | head -n 1
}

EXE="$(detect_exe || true)"

if [ -z "$EXE" ]; then
  echo "[ERROR] StarRupture server EXE not found under $SERVER_DIR"
  echo "[DEBUG] Listing $SERVER_DIR:"
  ls -lah "$SERVER_DIR" | head -n 200 || true
  exit 1
fi

echo "[StarRupture] Using EXE:"
echo "  $EXE"

################################
# SERVER START (WINE)
################################
echo "[StarRupture] STARTING SERVER VIA WINE"
exec xvfb-run --auto-servernum \
  wine "$EXE" -Log -port="$SERVER_PORT"
