#!/usr/bin/env bash
set -euo pipefail

RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo "-----------------------------------------------------------"
echo " Minecraft Fabric Dedicated Server (Home Assistant Add-on)"
echo "-----------------------------------------------------------"

# -----------------------------------------------------------
# Optionen
# -----------------------------------------------------------
DATA_DIR="$(jq -r '.data_dir' /data/options.json)"
XMS_MB="$(jq -r '.xms_mb' /data/options.json)"
XMX_MB="$(jq -r '.xmx_mb' /data/options.json)"
MC_VERSION="$(jq -r '.mc_version' /data/options.json)"
FABRIC_LOADER_VERSION="$(jq -r '.fabric_loader_version' /data/options.json)"
FABRIC_INSTALLER_VERSION="$(jq -r '.fabric_installer_version' /data/options.json)"

[[ "${DATA_DIR}" == "null" || -z "${DATA_DIR}" ]] && DATA_DIR="/share/minecraft-fabric"
[[ "${MC_VERSION}" == "null" || -z "${MC_VERSION}" ]] && MC_VERSION="latest"
[[ "${FABRIC_LOADER_VERSION}" == "null" || -z "${FABRIC_LOADER_VERSION}" ]] && FABRIC_LOADER_VERSION="latest"
[[ "${FABRIC_INSTALLER_VERSION}" == "null" || -z "${FABRIC_INSTALLER_VERSION}" ]] && FABRIC_INSTALLER_VERSION="latest"

CONTAINER_PORT="25565"

mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

LOG_DIR="${DATA_DIR}/logs"
LOG_FILE="${LOG_DIR}/ha_console.log"
mkdir -p "${LOG_DIR}"

# -----------------------------------------------------------
# Java 21 automatisch installieren (Temurin)
# -----------------------------------------------------------
JRE_DIR="${DATA_DIR}/.jre/21"
JAVA_HOME="${JRE_DIR}"
JAVA_BIN="${JAVA_HOME}/bin/java"

install_java() {
  if [[ -x "${JAVA_BIN}" ]]; then
    return 0
  fi

  log_info "Java 21 nicht gefunden – installiere Temurin JRE"

  local arch adoptium_arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64)  adoptium_arch="x64" ;;
    aarch64|arm64) adoptium_arch="aarch64" ;;
    *)
      log_error "Nicht unterstützte Architektur: ${arch}"
      exit 1
      ;;
  esac

  mkdir -p "${JRE_DIR}"
  TMP="/tmp/jre21.tar.gz"
  URL="https://api.adoptium.net/v3/binary/latest/21/ga/linux/${adoptium_arch}/jre/hotspot/normal/eclipse?project=jdk"

  curl -fL --retry 3 --retry-delay 2 "${URL}" -o "${TMP}"
  rm -rf "${JRE_DIR:?}/"*
  tar -xzf "${TMP}" -C "${JRE_DIR}" --strip-components=1
  rm -f "${TMP}"

  [[ -x "${JAVA_BIN}" ]] || { log_error "Java Installation fehlgeschlagen"; exit 1; }
}

install_java
export JAVA_HOME
export PATH="${JAVA_HOME}/bin:${PATH}"
log_info "Java Version: $(java -version 2>&1 | head -n1)"

# -----------------------------------------------------------
# Fabric installieren
# -----------------------------------------------------------
FABRIC_SERVER_JAR="fabric-server-launch.jar"
FABRIC_MARKER=".fabric_install_marker.txt"
FABRIC_INSTALLER_JAR="${DATA_DIR}/fabric-installer.jar"

get_latest_release_version() {
  local manifest
  manifest="$(curl -fsSL https://piston-meta.mojang.com/mc/game/version_manifest_v2.json)"
  echo "$manifest" | jq -r '.latest.release'
}

resolve_mc_version() {
  if [[ "${MC_VERSION}" == "latest" ]]; then
    echo "$(get_latest_release_version)"
  else
    echo "${MC_VERSION}"
  fi
}

get_latest_installer_version() {
  local installers
  installers="$(curl -fsSL https://meta.fabricmc.net/v2/versions/installer)"
  echo "$installers" | jq -r '.[0].version'
}

get_latest_loader_version() {
  local mc_ver="$1"
  local loaders
  loaders="$(curl -fsSL "https://meta.fabricmc.net/v2/versions/loader/${mc_ver}")"
  echo "$loaders" | jq -r '.[0].loader.version'
}

MC_VERSION_RESOLVED="$(resolve_mc_version)"

if [[ "${FABRIC_INSTALLER_VERSION}" == "latest" ]]; then
  FABRIC_INSTALLER_VERSION="$(get_latest_installer_version)"
fi

if [[ "${FABRIC_LOADER_VERSION}" == "latest" ]]; then
  FABRIC_LOADER_VERSION="$(get_latest_loader_version "${MC_VERSION_RESOLVED}")"
fi

if [[ -z "${FABRIC_INSTALLER_VERSION}" || "${FABRIC_INSTALLER_VERSION}" == "null" ]]; then
  log_error "Konnte Fabric Installer Version nicht ermitteln"
  exit 1
fi

if [[ -z "${FABRIC_LOADER_VERSION}" || "${FABRIC_LOADER_VERSION}" == "null" ]]; then
  log_error "Konnte Fabric Loader Version nicht ermitteln"
  exit 1
fi

log_info "Minecraft-Version: ${MC_VERSION_RESOLVED}"
log_info "Fabric Loader    : ${FABRIC_LOADER_VERSION}"
log_info "Fabric Installer : ${FABRIC_INSTALLER_VERSION}"

INSTALL_NEEDED="false"
if [[ ! -f "${FABRIC_SERVER_JAR}" || ! -f "${FABRIC_MARKER}" ]]; then
  INSTALL_NEEDED="true"
else
  if [[ "$(cat "${FABRIC_MARKER}")" != "${MC_VERSION_RESOLVED}|${FABRIC_LOADER_VERSION}|${FABRIC_INSTALLER_VERSION}" ]]; then
    INSTALL_NEEDED="true"
  fi
fi

if [[ "${INSTALL_NEEDED}" == "true" ]]; then
  log_info "Installiere/aktualisiere Fabric Server"
  curl -fL --retry 3 --retry-delay 2 \
    "https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER_VERSION}/fabric-installer-${FABRIC_INSTALLER_VERSION}.jar" \
    -o "${FABRIC_INSTALLER_JAR}"

  java -jar "${FABRIC_INSTALLER_JAR}" server \
    -downloadMinecraft \
    -mcversion "${MC_VERSION_RESOLVED}" \
    -loader "${FABRIC_LOADER_VERSION}" \
    -dir "${DATA_DIR}"

  echo "${MC_VERSION_RESOLVED}|${FABRIC_LOADER_VERSION}|${FABRIC_INSTALLER_VERSION}" > "${FABRIC_MARKER}"
fi

[[ -f "${FABRIC_SERVER_JAR}" ]] || { log_error "Fabric Server JAR nicht gefunden"; exit 1; }

# -----------------------------------------------------------
# EULA IMMER akzeptieren
# -----------------------------------------------------------
cat > ./eula.txt <<'EOF'
#By changing the setting below to TRUE you are indicating your agreement to the Minecraft EULA (https://aka.ms/MinecraftEULA).
eula=true
EOF
log_info "EULA automatisch akzeptiert"

# -----------------------------------------------------------
# server.properties – Port fest setzen
# -----------------------------------------------------------
if [[ -f "./server.properties" ]]; then
  sed -i "s/^server-port=.*/server-port=${CONTAINER_PORT}/" ./server.properties || true
else
  echo "server-port=${CONTAINER_PORT}" > ./server.properties
fi

# -----------------------------------------------------------
# Start
# -----------------------------------------------------------
export JAVA_TOOL_OPTIONS="-Xms${XMS_MB}M -Xmx${XMX_MB}M"

log_info "Starte Minecraft Fabric Server"
log_info "Port (Container): ${CONTAINER_PORT}"
log_info "RAM             : Xms=${XMS_MB}M / Xmx=${XMX_MB}M"
log_info "Datenverzeichnis: ${DATA_DIR}"
log_info "Logdatei        : ${LOG_FILE}"
echo "-----------------------------------------------------------"

{
  echo ""
  echo "==================== $(date -Iseconds) ===================="
  echo "Minecraft Fabric  | Port ${CONTAINER_PORT} | Xms/Xmx ${XMS_MB}/${XMX_MB} MB"
  echo "==========================================================="
} >> "${LOG_FILE}"

exec java -jar "${FABRIC_SERVER_JAR}" nogui 2>&1 | tee -a "${LOG_FILE}"
