#!/usr/bin/env bash
set -euo pipefail

# Farben (HA Log kann ANSI meist anzeigen)
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo "-----------------------------------------------------------"
echo " FTB Minecraft Server Add-on (Installer + Java Select)"
echo "-----------------------------------------------------------"

# -----------------------------
# Optionen aus Home Assistant
# -----------------------------
PACK_ID="$(jq -r '.pack_id' /data/options.json)"
VERSION_ID="$(jq -r '.version_id' /data/options.json)"
SERVER_PORT="$(jq -r '.server_port' /data/options.json)"
AUTO_EULA="$(jq -r '.auto_accept_eula' /data/options.json)"
DATA_DIR="$(jq -r '.data_dir' /data/options.json)"
INSTANCE_NAME="$(jq -r '.instance_name' /data/options.json)"
INSTALLER_VERSION="$(jq -r '.installer_version' /data/options.json)"
FORCE_REINSTALL="$(jq -r '.force_reinstall' /data/options.json)"

JAVA_VER="$(jq -r '.java_version' /data/options.json)"
JAVA_FALLBACK="$(jq -r '.java_fallback' /data/options.json)"

XMS_MB="$(jq -r '.xms_mb' /data/options.json)"
XMX_MB="$(jq -r '.xmx_mb' /data/options.json)"

if [[ -z "${PACK_ID}" || "${PACK_ID}" == "0" || "${PACK_ID}" == "null" ]]; then
  log_error "pack_id ist 0/leer. Bitte im Add-on setzen."
  exit 1
fi

if [[ -z "${JAVA_VER}" || "${JAVA_VER}" == "null" ]]; then
  JAVA_VER="21"
fi

if [[ -z "${JAVA_FALLBACK}" || "${JAVA_FALLBACK}" == "null" ]]; then
  JAVA_FALLBACK="true"
fi

if [[ -z "${XMS_MB}" || "${XMS_MB}" == "null" ]]; then
  XMS_MB="1024"
fi
if [[ -z "${XMX_MB}" || "${XMX_MB}" == "null" ]]; then
  XMX_MB="4096"
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)    ARCH_ADOPTIUM="x64"     ; INSTALLER_ASSET="ftb-server-linux-amd64" ;;
  aarch64|arm64)   ARCH_ADOPTIUM="aarch64" ; INSTALLER_ASSET="ftb-server-linux-arm64" ;;
  *)
    log_error "Nicht unterstützte Architektur: $ARCH"
    exit 1
    ;;
esac

log_info "Architektur        : ${ARCH}"
log_info "Java Auswahl       : ${JAVA_VER}"
log_info "Java Fallback      : ${JAVA_FALLBACK}"
log_info "RAM (Xms/Xmx MB)   : ${XMS_MB}/${XMX_MB}"
log_info "Pack ID            : ${PACK_ID}"
log_info "Version ID         : ${VERSION_ID} (0 = latest)"
log_info "Server Port        : ${SERVER_PORT}"

# -----------------------------
# Pfade (persistent im /share)
# -----------------------------
INSTANCE_DIR="${DATA_DIR%/}/${INSTANCE_NAME}"
JRE_BASE="${DATA_DIR%/}/.jre"

INSTALLER_DIR="/tmp/ftb-installer"
INSTALLER_BIN="${INSTALLER_DIR}/${INSTALLER_ASSET}"
INSTALLER_URL="https://github.com/FTBTeam/FTB-Server-Installer/releases/download/${INSTALLER_VERSION}/${INSTALLER_ASSET}"

SERVER_LOG_DIR="${INSTANCE_DIR}/logs"
SERVER_LOG_FILE="${SERVER_LOG_DIR}/ha_console.log"

mkdir -p "${INSTANCE_DIR}" "${JRE_BASE}" "${INSTALLER_DIR}" "${SERVER_LOG_DIR}"
cd "${INSTANCE_DIR}"

# -----------------------------
# Java Runtime on-demand holen
# -----------------------------
download_java() {
  local ver="$1"
  local dest="${JRE_BASE}/${ver}"
  local tmp="/tmp/jre_${ver}.tar.gz"

  mkdir -p "${dest}"

  if [[ -x "${dest}/bin/java" ]]; then
    return 0
  fi

  log_info "Java ${ver} fehlt -> lade Temurin JRE (${ARCH_ADOPTIUM})..."

  # Adoptium API (latest GA JRE für major version)
  local url
  url="https://api.adoptium.net/v3/binary/latest/${ver}/ga/linux/${ARCH_ADOPTIUM}/jre/hotspot/normal/eclipse?project=jdk"

  curl -fL --retry 3 --retry-delay 2 "${url}" -o "${tmp}"

  # tar enthält Top-Ordner -> strip 1 Ebene
  rm -rf "${dest:?}/"*
  tar -xzf "${tmp}" -C "${dest}" --strip-components=1
  rm -f "${tmp}"

  if [[ ! -x "${dest}/bin/java" ]]; then
    log_error "Java ${ver} Download/Entpacken fehlgeschlagen."
    exit 1
  fi

  log_info "Java ${ver} bereit: $("${dest}/bin/java" -version 2>&1 | head -n1)"
}

activate_java() {
  local ver="$1"
  local java_home="${JRE_BASE}/${ver}"

  download_java "${ver}"

  export JAVA_HOME="${java_home}"
  export PATH="${JAVA_HOME}/bin:${PATH}"

  log_info "JAVA_HOME          : ${JAVA_HOME}"
  log_info "java -version      : $(java -version 2>&1 | head -n1)"
}

# -----------------------------
# Installer holen (arch-spezifisch)
# -----------------------------
if [[ ! -x "${INSTALLER_BIN}" ]]; then
  log_info "Lade FTB Installer : ${INSTALLER_VERSION}"
  log_info "Installer Asset    : ${INSTALLER_ASSET}"
  curl -fsSL "${INSTALLER_URL}" -o "${INSTALLER_BIN}"
  chmod +x "${INSTALLER_BIN}"
fi

# -----------------------------
# Install nötig?
# -----------------------------
NEED_INSTALL=false
if [[ "${FORCE_REINSTALL}" == "true" ]]; then
  NEED_INSTALL=true
elif [[ ! -f "./run.sh" && ! -f "./start.sh" && ! -f "./startserver.sh" ]]; then
  NEED_INSTALL=true
fi

# -----------------------------
# Headless Installation (mit gewählter Java)
# -----------------------------
activate_java "${JAVA_VER}"

if [[ "${NEED_INSTALL}" == "true" ]]; then
  log_info "Starte headless FTB Installation..."
  log_info "Ziel              : ${INSTANCE_DIR}"

  if [[ "${VERSION_ID}" != "0" && "${VERSION_ID}" != "null" ]]; then
    "${INSTALLER_BIN}" \
      -auto -force \
      -dir "${INSTANCE_DIR}" \
      -no-java \
      -pack "${PACK_ID}" \
      -version "${VERSION_ID}"
  else
    "${INSTALLER_BIN}" \
      -auto -force \
      -dir "${INSTANCE_DIR}" \
      -no-java \
      -pack "${PACK_ID}"
  fi

  log_info "Installation abgeschlossen."
fi

# -----------------------------
# EULA sicherstellen (robust)
# -----------------------------
if [[ "${AUTO_EULA}" == "true" ]]; then
  if [[ ! -f "./eula.txt" ]]; then
    log_warn "eula.txt fehlt -> lege Datei an (eula=true)"
    cat > ./eula.txt <<'EOF'
#By changing the setting below to TRUE you are indicating your agreement to the Minecraft EULA (https://aka.ms/MinecraftEULA).
eula=true
EOF
  else
    if grep -q '^eula=' "./eula.txt"; then
      sed -i 's/^eula=.*/eula=true/' "./eula.txt" || true
    else
      echo "eula=true" >> "./eula.txt"
    fi
  fi

  log_info "EULA Status: $(grep '^eula=' ./eula.txt || true)"
fi

# -----------------------------
# Port setzen
# -----------------------------
if [[ -f "./server.properties" ]]; then
  if grep -q '^server-port=' "./server.properties"; then
    sed -i "s/^server-port=.*/server-port=${SERVER_PORT}/" "./server.properties"
  else
    echo "server-port=${SERVER_PORT}" >> "./server.properties"
  fi
fi

# -----------------------------
# Start-Script finden
# -----------------------------
START_SCRIPT=""
for f in "./run.sh" "./start.sh" "./startserver.sh"; do
  if [[ -f "$f" ]]; then
    START_SCRIPT="$f"
    break
  fi
done

if [[ -z "${START_SCRIPT}" ]]; then
  log_error "Kein Startscript gefunden (run.sh / start.sh / startserver.sh)"
  log_warn  "Prüfe ob der Installer erfolgreich war: ${INSTANCE_DIR}"
  exit 1
fi

chmod +x "${START_SCRIPT}"

# -----------------------------
# Java-Fehler-Patterns
# -----------------------------
is_java_too_new() {
  grep -qE "URLClassLoader|ClassCastException.*URLClassLoader|IllegalAccessError|NoSuchMethodError" "$1"
}
is_java_too_old() {
  grep -qE "Unsupported class file major version|has been compiled by a more recent version of the Java Runtime|compiled by a more recent version" "$1"
}
is_jvm_fail() {
  grep -qE "Could not create the Java Virtual Machine|A fatal exception has occurred" "$1"
}

# -----------------------------
# Server starten (live log) + optional Java fallback
# -----------------------------
run_server_once() {
  local ver="$1"

  log_info "Starte Server mit Java ${ver} via: ${START_SCRIPT}"

  # RAM nur für den Server setzen (nicht für Installer)
  # Hinweis: JAVA_TOOL_OPTIONS wird von der JVM automatisch gelesen.
  export JAVA_TOOL_OPTIONS="-Xms${XMS_MB}M -Xmx${XMX_MB}M"

  # Java aktivieren (setzt JAVA_HOME/PATH)
  activate_java "${ver}"

  # Logdatei (append), aber mit Header
  {
    echo ""
    echo "==================== $(date -Iseconds) ===================="
    echo "Java: ${ver} | Xms/Xmx: ${XMS_MB}/${XMX_MB} MB"
    echo "==========================================================="
  } >> "${SERVER_LOG_FILE}"

  # Live nach HA + parallel in Datei
  set +e
  bash "${START_SCRIPT}" 2>&1 | tee -a "${SERVER_LOG_FILE}"
  local exit_code=${PIPESTATUS[0]}
  set -e

  return "${exit_code}"
}

# Fallback-Reihenfolge je nach Fehlerart
# (Wir versuchen nie unendlich: max 3 Versuche, jede Version nur einmal.)
pick_fallback_order() {
  local current="$1"
  local reason="$2" # too_new | too_old | jvm_fail | other

  # Default Reihenfolgen
  if [[ "$reason" == "too_new" ]]; then
    # Java zu neu -> runtergehen
    if [[ "$current" == "21" ]]; then echo "17 8"; return; fi
    if [[ "$current" == "17" ]]; then echo "8"; return; fi
    echo ""; return
  fi

  if [[ "$reason" == "too_old" ]]; then
    # Java zu alt -> hochgehen
    if [[ "$current" == "8" ]]; then echo "17 21"; return; fi
    if [[ "$current" == "17" ]]; then echo "21"; return; fi
    echo ""; return
  fi

  # Bei JVM Fail: erst 17, dann 21, dann 8 (oft RAM/Args, aber das ist die „sinnvolle“ Reihenfolge)
  if [[ "$current" == "8" ]]; then echo "17 21"; return; fi
  if [[ "$current" == "17" ]]; then echo "21 8"; return; fi
  if [[ "$current" == "21" ]]; then echo "17 8"; return; fi
  echo ""
}

# Start
log_info "Server-Log: live im Protokoll + dauerhaft in ${SERVER_LOG_FILE}"
echo "-----------------------------------------------------------"

# Track tried versions
TRIED=" ${JAVA_VER} "

# 1. Versuch: gewählte Java
set +e
run_server_once "${JAVA_VER}"
EXIT_CODE=$?
set -e

# Wenn Server läuft, endet das Script hier nicht (da der Prozess läuft).
# Wenn wir hier sind, ist der Server beendet/crashed -> Logdatei analysieren.
if [[ -f "${SERVER_LOG_FILE}" ]]; then
  if is_java_too_new "${SERVER_LOG_FILE}"; then
    echo -e "${RED}[JAVA ERROR] Sieht nach INKOMPATIBLER Java-Version aus (Java zu NEU).${NC}"
    echo -e "${YELLOW}[HINWEIS] Manuell: 'java_version' auf 8 stellen.${NC}"
    REASON="too_new"
  elif is_java_too_old "${SERVER_LOG_FILE}"; then
    echo -e "${RED}[JAVA ERROR] Dieses Modpack benötigt eine NEUERE Java-Version (Java zu ALT).${NC}"
    echo -e "${YELLOW}[HINWEIS] Manuell: 'java_version' auf 17 oder 21 stellen.${NC}"
    REASON="too_old"
  elif is_jvm_fail "${SERVER_LOG_FILE}"; then
    echo -e "${RED}[JAVA ERROR] JVM konnte nicht starten.${NC}"
    echo -e "${YELLOW}[HINWEIS] Prüfe RAM (xms_mb/xmx_mb) oder teste andere Java-Version.${NC}"
    REASON="jvm_fail"
  else
    REASON="other"
  fi
else
  REASON="other"
fi

# Optional Java Fallback
if [[ "${JAVA_FALLBACK}" == "true" ]]; then
  FALLBACKS="$(pick_fallback_order "${JAVA_VER}" "${REASON}")"
  if [[ -n "${FALLBACKS}" ]]; then
    log_warn "Java-Fallback aktiv. Grund: ${REASON}. Probiere: ${FALLBACKS}"
    for v in ${FALLBACKS}; do
      if [[ "${TRIED}" == *" ${v} "* ]]; then
        continue
      fi
      TRIED="${TRIED}${v} "

      set +e
      run_server_once "${v}"
      EXIT_CODE=$?
      set -e

      # Wenn der Server läuft, endet das Script nicht -> wir wären nicht hier.
      # Wenn wieder beendet: analysieren und ggf. nächsten Versuch.
      if [[ -f "${SERVER_LOG_FILE}" ]]; then
        if is_java_too_new "${SERVER_LOG_FILE}"; then
          REASON="too_new"
          echo -e "${RED}[JAVA ERROR] (Fallback Java ${v}) Java zu NEU erkannt.${NC}"
          continue
        elif is_java_too_old "${SERVER_LOG_FILE}"; then
          REASON="too_old"
          echo -e "${RED}[JAVA ERROR] (Fallback Java ${v}) Java zu ALT erkannt.${NC}"
          continue
        elif is_jvm_fail "${SERVER_LOG_FILE}"; then
          REASON="jvm_fail"
          echo -e "${RED}[JAVA ERROR] (Fallback Java ${v}) JVM Startfehler.${NC}"
          continue
        else
          # Anderer Crash -> abbrechen, damit User Logs sieht
          log_error "Server beendet (Exit Code ${EXIT_CODE}). Siehe Log: ${SERVER_LOG_FILE}"
          exit "${EXIT_CODE}"
        fi
      fi
    done
  fi
fi

# Wenn wir hier sind, sind alle Versuche gescheitert
log_error "Server konnte nicht gestartet werden."
log_error "Letztes Exit Code: ${EXIT_CODE}"
log_warn  "Siehe ausführliches Log: ${SERVER_LOG_FILE}"
exit "${EXIT_CODE}"
