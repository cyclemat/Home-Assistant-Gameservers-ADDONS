#!/usr/bin/env bash
set -euo pipefail

RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo "-----------------------------------------------------------"
echo " Minecraft Vanilla Dedicated Server (Home Assistant Add-on)"
echo "-----------------------------------------------------------"

# -----------------------------------------------------------
# Konstanten
# -----------------------------------------------------------
MANIFEST_URL="${MANIFEST_URL:-https://piston-meta.mojang.com/mc/game/version_manifest_v2.json}"
CONTAINER_PORT="25565"
TMP_BASE="${TMPDIR:-/tmp}"

# -----------------------------------------------------------
# Optionen
# -----------------------------------------------------------
OPTIONS_FILE="${OPTIONS_FILE:-/data/options.json}"

# Liefert den Wert einer Option als Text, leer wenn nicht gesetzt (false bleibt "false")
opt() { jq -r --arg k "$1" '.[$k] | if . == null then empty else tostring end' "${OPTIONS_FILE}"; }

DATA_DIR="$(opt data_dir)";         : "${DATA_DIR:=/share/minecraft-vanilla}"
XMS_MB="$(opt xms_mb)";             : "${XMS_MB:=1024}"
XMX_MB="$(opt xmx_mb)";             : "${XMX_MB:=4096}"
MC_VERSION="$(opt mc_version)";     : "${MC_VERSION:=latest}"
ACCEPT_EULA="$(opt accept_eula)"
SERVER_JAR_URL="$(opt server_jar_url)"
JAVA_MAJOR_OPT="$(opt java_major)"

# -----------------------------------------------------------
# EULA: nur mit ausdrücklicher Zustimmung
# -----------------------------------------------------------
if [[ "${ACCEPT_EULA}" != "true" ]]; then
  log_error "Die Minecraft EULA (https://aka.ms/MinecraftEULA) wurde nicht akzeptiert."
  log_error "Aktiviere die Option 'accept_eula' in der Add-on-Konfiguration und starte neu."
  exit 1
fi

# -----------------------------------------------------------
# Eingaben prüfen
# -----------------------------------------------------------
if ! [[ "${XMS_MB}" =~ ^[0-9]+$ && "${XMX_MB}" =~ ^[0-9]+$ ]]; then
  log_error "xms_mb und xmx_mb müssen ganze Zahlen sein (aktuell: '${XMS_MB}' / '${XMX_MB}')"
  exit 1
fi
if (( XMS_MB > XMX_MB )); then
  log_error "xms_mb (${XMS_MB}) darf nicht größer als xmx_mb (${XMX_MB}) sein"
  exit 1
fi
if [[ -n "${JAVA_MAJOR_OPT}" && ! "${JAVA_MAJOR_OPT}" =~ ^[0-9]+$ ]]; then
  log_error "java_major muss eine ganze Zahl sein (aktuell: '${JAVA_MAJOR_OPT}')"
  exit 1
fi
if ! [[ "${MC_VERSION}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  log_error "Ungültige Minecraft-Version: '${MC_VERSION}'"
  exit 1
fi
if [[ -n "${SERVER_JAR_URL}" && "${SERVER_JAR_URL}" != https://* ]]; then
  log_error "server_jar_url muss mit https:// beginnen"
  exit 1
fi

mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

# -----------------------------------------------------------
# Download-Helfer (nur https, auch bei Weiterleitungen)
# -----------------------------------------------------------
# fetch <URL> <Ziel>   lädt eine Datei, bei Fehlern Exit-Code != 0
fetch() {
  curl -fsSL --retry 3 --retry-delay 2 --proto '=https' --proto-redir '=https' "$1" -o "$2"
}

# fetch_text <URL>   liefert den Antworttext
fetch_text() {
  curl -fsSL --retry 3 --retry-delay 2 --proto '=https' --proto-redir '=https' "$1"
}

# -----------------------------------------------------------
# Version, Server-JAR und Java-Version auflösen (Mojang piston-meta)
# -----------------------------------------------------------
MC_ID=""
META_JAR_URL=""
META_JAR_SHA1=""
META_JAVA_MAJOR=""

# Setzt MC_ID und META_*; Fehler werden vom Aufrufer behandelt.
resolve_vanilla() {
  local manifest id version_url vjson

  if ! manifest="$(fetch_text "${MANIFEST_URL}")"; then
    log_error "Mojang-Versionsmanifest nicht erreichbar"
    return 1
  fi

  if [[ "${MC_VERSION}" == "latest" ]]; then
    id="$(jq -r '.latest.release // empty' <<<"${manifest}")"
  else
    id="${MC_VERSION}"
  fi
  version_url="$(jq -r --arg id "${id}" 'first(.versions[] | select(.id == $id) | .url) // empty' <<<"${manifest}")"
  if [[ -z "${id}" || -z "${version_url}" ]]; then
    log_error "Unbekannte Minecraft-Version: '${id:-${MC_VERSION}}'"
    return 1
  fi

  if ! vjson="$(fetch_text "${version_url}")"; then
    log_error "Versionsdaten für ${id} nicht ladbar"
    return 1
  fi

  MC_ID="${id}"
  META_JAR_URL="$(jq -r '.downloads.server.url // empty' <<<"${vjson}")"
  META_JAR_SHA1="$(jq -r '.downloads.server.sha1 // empty' <<<"${vjson}")"
  # Versionen vor 1.17 haben kein javaVersion-Feld und laufen mit Java 8
  META_JAVA_MAJOR="$(jq -r '.javaVersion.majorVersion // 8' <<<"${vjson}")"
  return 0
}

JAR_URL=""
JAR_SHA1=""
JAVA_MAJOR="${JAVA_MAJOR_OPT}"

if [[ -n "${SERVER_JAR_URL}" ]]; then
  JAR_URL="${SERVER_JAR_URL}"
  log_info "Nutze benutzerdefinierte Server-JAR URL"
  if [[ -z "${JAVA_MAJOR}" ]]; then
    # Java-Version best effort aus den Mojang-Daten zu mc_version ableiten
    if resolve_vanilla 2>/dev/null; then
      JAVA_MAJOR="${META_JAVA_MAJOR}"
    fi
  fi
else
  if ! resolve_vanilla; then
    exit 1
  fi
  if [[ -z "${META_JAR_URL}" ]]; then
    log_error "Für Minecraft ${MC_ID} gibt es kein Server-JAR"
    exit 1
  fi
  JAR_URL="${META_JAR_URL}"
  JAR_SHA1="${META_JAR_SHA1}"
  if [[ "${MC_VERSION}" == "latest" ]]; then
    log_info "Nutze neueste Minecraft-Version: ${MC_ID}"
  else
    log_info "Nutze Minecraft-Version ${MC_ID}"
  fi
  if [[ -z "${JAVA_MAJOR}" ]]; then
    JAVA_MAJOR="${META_JAVA_MAJOR}"
  fi
fi

if [[ -z "${JAVA_MAJOR}" || ! "${JAVA_MAJOR}" =~ ^[0-9]+$ ]]; then
  JAVA_MAJOR="25"
  log_warn "Benötigte Java-Version nicht ermittelbar, nutze Java ${JAVA_MAJOR} (setze 'java_major' zum Überschreiben)"
fi

# -----------------------------------------------------------
# Java automatisch installieren (Temurin, passend zur Version)
# -----------------------------------------------------------
JRE_ROOT="${DATA_DIR}/.jre"
JRE_DIR="${JRE_ROOT}/${JAVA_MAJOR}"
JAVA_HOME="${JRE_DIR}"
JAVA_BIN="${JAVA_HOME}/bin/java"

install_java() {
  if [[ -x "${JAVA_BIN}" ]]; then
    return 0
  fi

  log_info "Java ${JAVA_MAJOR} nicht gefunden, installiere Temurin JRE"

  local arch adoptium_arch url tmp_tar tmp_dir
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64)  adoptium_arch="x64" ;;
    aarch64|arm64) adoptium_arch="aarch64" ;;
    *)
      log_error "Nicht unterstützte Architektur: ${arch}"
      exit 1
      ;;
  esac

  url="https://api.adoptium.net/v3/binary/latest/${JAVA_MAJOR}/ga/linux/${adoptium_arch}/jre/hotspot/normal/eclipse?project=jdk"
  tmp_tar="${TMP_BASE}/jre${JAVA_MAJOR}.tar.gz"
  tmp_dir="${JRE_DIR}.tmp"

  rm -rf "${tmp_dir}"
  mkdir -p "${tmp_dir}"
  fetch "${url}" "${tmp_tar}"
  tar -xzf "${tmp_tar}" -C "${tmp_dir}" --strip-components=1
  rm -f "${tmp_tar}"

  [[ -x "${tmp_dir}/bin/java" ]] || { log_error "Java Installation fehlgeschlagen"; exit 1; }

  rm -rf "${JRE_DIR}"
  mv "${tmp_dir}" "${JRE_DIR}"

  # Ältere Java-Versionen aufräumen
  find "${JRE_ROOT}" -mindepth 1 -maxdepth 1 ! -name "${JAVA_MAJOR}" -exec rm -rf {} + 2>/dev/null || true
}

install_java
export JAVA_HOME
export PATH="${JAVA_HOME}/bin:${PATH}"
log_info "Java Version: $(java -version 2>&1 | head -n1)"

# -----------------------------------------------------------
# Server-JAR herunterladen (mit SHA-1-Prüfung, wenn Mojang sie liefert)
# -----------------------------------------------------------
SERVER_JAR="server.jar"
URL_MARKER=".server_jar_url.txt"

if [[ ! -f "${SERVER_JAR}" || ! -f "${URL_MARKER}" || "$(cat "${URL_MARKER}")" != "${JAR_URL}" ]]; then
  log_info "Lade Server-JAR herunter"
  fetch "${JAR_URL}" "${SERVER_JAR}.tmp"

  if [[ -n "${JAR_SHA1}" ]]; then
    if ! echo "${JAR_SHA1}  ${SERVER_JAR}.tmp" | sha1sum -c - >/dev/null 2>&1; then
      rm -f "${SERVER_JAR}.tmp"
      log_error "Prüfsumme des Server-JAR stimmt nicht überein, Download verworfen"
      exit 1
    fi
    log_info "Prüfsumme (SHA-1) ok"
  else
    log_warn "Keine Prüfsumme verfügbar, Download ist nicht verifiziert"
  fi

  mv "${SERVER_JAR}.tmp" "${SERVER_JAR}"
  echo "${JAR_URL}" > "${URL_MARKER}"
fi

# -----------------------------------------------------------
# EULA (Zustimmung wurde oben geprüft)
# -----------------------------------------------------------
cat > ./eula.txt <<'EOF'
#By changing the setting below to TRUE you are indicating your agreement to the Minecraft EULA (https://aka.ms/MinecraftEULA).
eula=true
EOF
log_info "EULA gemäß Konfiguration akzeptiert"

# -----------------------------------------------------------
# server.properties: Port fest setzen
# -----------------------------------------------------------
if [[ -f "./server.properties" ]]; then
  if grep -q '^server-port=' ./server.properties; then
    sed -i "s/^server-port=.*/server-port=${CONTAINER_PORT}/" ./server.properties
  else
    echo "server-port=${CONTAINER_PORT}" >> ./server.properties
  fi
else
  echo "server-port=${CONTAINER_PORT}" > ./server.properties
fi

# -----------------------------------------------------------
# Start (mit sauberem Shutdown bei SIGTERM)
# -----------------------------------------------------------
log_info "Starte Minecraft Vanilla Server"
log_info "Port (Container)  : ${CONTAINER_PORT}"
log_info "RAM               : Xms=${XMS_MB}M / Xmx=${XMX_MB}M"
log_info "Datenverzeichnis  : ${DATA_DIR}"
log_info "Server-Log        : ${DATA_DIR}/logs/latest.log"
echo "-----------------------------------------------------------"

# Eigene stdin-Pipe, damit wir dem Server "stop" schicken können
STDIN_FIFO="${TMP_BASE}/mc_stdin"
rm -f "${STDIN_FIFO}"
mkfifo "${STDIN_FIFO}"
exec 3<>"${STDIN_FIFO}"

STOPPING=0
JAVA_PID=""

# Wird über trap aufgerufen (shellcheck erkennt das nicht). Die Trap steht vor dem
# Java-Start, damit ein frühes SIGTERM nicht verloren geht.
# shellcheck disable=SC2329
graceful_stop() {
  STOPPING=1
  log_info "Stop-Signal empfangen, beende Server sauber (Welt wird gespeichert)"
  echo "stop" >&3 || true
  wait "${JAVA_PID}" 2>/dev/null || true
}
trap graceful_stop TERM INT

java -Xms"${XMS_MB}M" -Xmx"${XMX_MB}M" -jar "${SERVER_JAR}" nogui <&3 &
JAVA_PID=$!

set +e
wait "${JAVA_PID}"
RC=$?
set -e

if (( STOPPING == 1 )); then
  log_info "Server gestoppt"
  exit 0
fi

log_warn "Server wurde beendet (Exit-Code ${RC})"
exit "${RC}"
