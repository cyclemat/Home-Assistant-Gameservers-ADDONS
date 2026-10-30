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
WHITELIST_ENABLED="$(opt whitelist_enabled)"; : "${WHITELIST_ENABLED:=false}"
[[ "${WHITELIST_ENABLED}" == "true" ]] || WHITELIST_ENABLED="false"
PERFORMANCE_PROFILE="$(opt performance_profile)"; : "${PERFORMANCE_PROFILE:=custom}"
CPU_PRIORITY="$(opt cpu_priority)";             : "${CPU_PRIORITY:=normal}"
CPU_CORES="$(opt cpu_cores)";                   : "${CPU_CORES:=0}"
MEMORY_GUARD="$(opt memory_guard)";             : "${MEMORY_GUARD:=true}"
FIXED_HEAP="$(opt fixed_heap)";                 : "${FIXED_HEAP:=false}"
[[ "${MEMORY_GUARD}" == "false" ]] || MEMORY_GUARD="true"
[[ "${FIXED_HEAP}" == "true" ]] || FIXED_HEAP="false"
VIEW_DISTANCE="$(opt view_distance)";             : "${VIEW_DISTANCE:=0}"
SIMULATION_DISTANCE="$(opt simulation_distance)"; : "${SIMULATION_DISTANCE:=0}"
MAX_PLAYERS="$(opt max_players)";                 : "${MAX_PLAYERS:=0}"
ENTITY_RANGE="$(opt entity_broadcast_range)";     : "${ENTITY_RANGE:=0}"
SPAWN_PROTECTION="$(opt spawn_protection)";       : "${SPAWN_PROTECTION:=-1}"
DIFFICULTY="$(opt difficulty)";                   : "${DIFFICULTY:=default}"
GAMEMODE="$(opt gamemode)";                       : "${GAMEMODE:=default}"
FORCE_GAMEMODE="$(opt force_gamemode)";           : "${FORCE_GAMEMODE:=default}"
HARDCORE="$(opt hardcore)";                       : "${HARDCORE:=default}"
PVP="$(opt pvp)";                                 : "${PVP:=default}"
ALLOW_FLIGHT="$(opt allow_flight)";               : "${ALLOW_FLIGHT:=default}"
ALLOW_NETHER="$(opt allow_nether)";               : "${ALLOW_NETHER:=default}"
SPAWN_MONSTERS="$(opt spawn_monsters)";           : "${SPAWN_MONSTERS:=default}"
SPAWN_ANIMALS="$(opt spawn_animals)";             : "${SPAWN_ANIMALS:=default}"
SPAWN_NPCS="$(opt spawn_npcs)";                   : "${SPAWN_NPCS:=default}"
GENERATE_STRUCTURES="$(opt generate_structures)"; : "${GENERATE_STRUCTURES:=default}"
COMMAND_BLOCKS="$(opt command_blocks)";           : "${COMMAND_BLOCKS:=default}"
MOTD="$(opt motd)"
LEVEL_SEED="$(opt level_seed)"

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
if ! [[ "${CPU_CORES}" =~ ^[0-9]+$ ]]; then
  log_error "cpu_cores muss eine ganze Zahl sein (aktuell: '${CPU_CORES}')"
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

  local arch adoptium_arch assets link sha256 tmp_tar tmp_dir
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64)  adoptium_arch="x64" ;;
    aarch64|arm64) adoptium_arch="aarch64" ;;
    *)
      log_error "Nicht unterstützte Architektur: ${arch}"
      exit 1
      ;;
  esac

  # Download-Link und SHA-256 kommen aus derselben API-Antwort, so passen sie zusammen
  if ! assets="$(fetch_text "https://api.adoptium.net/v3/assets/latest/${JAVA_MAJOR}/hotspot?architecture=${adoptium_arch}&image_type=jre&os=linux&vendor=eclipse")"; then
    log_error "Adoptium-API nicht erreichbar"
    exit 1
  fi
  link="$(jq -r 'first(.[] | .binary.package.link) // empty' <<<"${assets}" 2>/dev/null || true)"
  sha256="$(jq -r 'first(.[] | .binary.package.checksum) // empty' <<<"${assets}" 2>/dev/null || true)"
  if [[ -z "${link}" || -z "${sha256}" ]]; then
    log_error "Keine Temurin JRE für Java ${JAVA_MAJOR} (${adoptium_arch}) gefunden"
    exit 1
  fi

  tmp_tar="${TMP_BASE}/jre${JAVA_MAJOR}.tar.gz"
  tmp_dir="${JRE_DIR}.tmp"

  rm -rf "${tmp_dir}"
  mkdir -p "${tmp_dir}"
  fetch "${link}" "${tmp_tar}"
  if ! echo "${sha256}  ${tmp_tar}" | sha256sum -c - >/dev/null 2>&1; then
    rm -f "${tmp_tar}"
    rm -rf "${tmp_dir}"
    log_error "Prüfsumme des Java-Archivs stimmt nicht überein, Download verworfen"
    exit 1
  fi
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
# server.properties: Port und Whitelist-Schalter setzen
# -----------------------------------------------------------
# set_property <Schlüssel> <Wert>: setzt oder ergänzt einen Eintrag
set_property() {
  [[ -f ./server.properties ]] || : > ./server.properties
  K="$1" V="$2" awk 'BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"] }
    index($0, k "=") == 1 { print k "=" v; found = 1; next }
    { print }
    END { if (!found) print k "=" v }' ./server.properties > ./server.properties.new
  mv ./server.properties.new ./server.properties
}

set_property server-port "${CONTAINER_PORT}"
set_property white-list "${WHITELIST_ENABLED}"
set_property enforce-whitelist "${WHITELIST_ENABLED}"

# -----------------------------------------------------------
# Spielerlisten (whitelist, ops, banned_players)
# -----------------------------------------------------------
# Die Listen aus der Add-on-Konfiguration werden bei jedem Start mit dem Server
# abgeglichen, indem passende Konsolenbefehle an den Server geschickt werden (der
# Server löst die UUIDs selbst auf). Verwaltet werden nur Einträge aus der
# Konfiguration: Was im Spiel hinzugefügt wurde, bleibt unangetastet. Entfernt wird
# nur, was zuvor in der Konfiguration stand und dort gelöscht wurde.
PLAYER_STATE=".managed_players.json"
PLAYER_MARKER="${TMP_BASE}/mc_started"
PLAYER_NAME_RE='^[A-Za-z0-9_]{1,16}$'

# list_opt <Schlüssel>: Einträge einer Listen-Option, einer pro Zeile
list_opt() { jq -r --arg k "$1" '.[$k] // [] | .[]' "${OPTIONS_FILE}"; }

# file_names <Datei>: Namen (klein geschrieben) aus whitelist.json, ops.json oder banned-players.json
file_names() {
  if [[ -f "$1" ]]; then
    jq -r '.[].name | ascii_downcase' "$1" 2>/dev/null || true
  fi
}

# player_commands <Schlüssel> <Datei> <Befehl hinzufügen> <Befehl entfernen> <Bedrock hinzufügen> <Bedrock entfernen>
# Gibt die nötigen Konsolenbefehle aus. Die Bedrock-Parameter sind hier immer leer, Namen mit
# Punkt sind bei Java-Spielern ungültig und werden schon vorher verworfen.
player_commands() {
  local key="$1" file="$2" add="$3" remove="$4" b_add="$5" b_remove="$6"
  local name lower
  local -A current=() existing=()
  local -a wanted=() previous=()

  while IFS= read -r name; do
    if [[ -z "${name}" ]]; then
      continue
    elif ! [[ "${name}" =~ ${PLAYER_NAME_RE} ]]; then
      log_warn "Ungültiger Spielername in '${key}' ignoriert: ${name}" >&2
      continue
    fi
    current["${name,,}"]=1
    wanted+=("${name}")
  done < <(list_opt "${key}")

  while IFS= read -r lower; do
    if [[ -n "${lower}" ]]; then existing["${lower}"]=1; fi
  done < <(file_names "${file}")

  while IFS= read -r name; do
    if [[ -n "${name}" ]]; then previous+=("${name,,}"); fi
  done < <(jq -r --arg k "${key}" '.[$k] // [] | .[]' "${PLAYER_STATE}" 2>/dev/null || true)

  for name in "${wanted[@]}"; do
    [[ -z "${existing[${name,,}]:-}" ]] || continue
    emit_player_command "${name}" "${add}" "${b_add}"
  done

  for lower in "${previous[@]}"; do
    [[ "${lower}" =~ ${PLAYER_NAME_RE} ]] || continue
    [[ -z "${current[${lower}]:-}" && -n "${existing[${lower}]:-}" ]] || continue
    emit_player_command "${lower}" "${remove}" "${b_remove}"
  done
}

# emit_player_command <Name> <Befehl> <Bedrock-Befehl>
emit_player_command() {
  local name="$1" cmd="$2" b_cmd="$3"
  if [[ "${name}" == .* ]]; then
    if [[ -z "${b_cmd}" ]]; then
      log_warn "Bedrock-Spieler ${name} übersprungen (Bedrock-Unterstützung ist aus)" >&2
    elif [[ "${b_cmd}" == "${cmd}" ]]; then
      echo "${b_cmd} ${name}"
    else
      echo "${b_cmd} ${name#.}"
    fi
  else
    echo "${cmd} ${name}"
  fi
}

# save_player_state: merkt sich den Stand der Konfiguration (für spätere Entfernungen)
save_player_state() {
  jq '{whitelist: (.whitelist // []), ops: (.ops // []), banned_players: (.banned_players // [])}' \
    "${OPTIONS_FILE}" > "${PLAYER_STATE}"
}

# send_player_commands <Befehle>: läuft im Hintergrund. Der Server verarbeitet Befehle erst
# zuverlässig nach dem Start, deshalb wird auf den neuen "Done"-Eintrag in logs/latest.log
# gewartet (neu = nicht älter als die Marker-Datei, die vor dem Java-Start angelegt wird).
# Der Stand wird erst gespeichert, wenn die Befehle gesendet wurden. Stoppt der Server
# vorher, wird beim nächsten Start alles erneut versucht.
send_player_commands() {
  local cmds="$1" i
  for (( i = 0; i < 900; i++ )); do
    kill -0 "${JAVA_PID}" 2>/dev/null || return 0
    if [[ -f logs/latest.log && ! "${PLAYER_MARKER}" -nt logs/latest.log ]] && grep -q 'Done (' logs/latest.log 2>/dev/null; then
      break
    fi
    sleep 1
  done
  sleep "${PLAYER_SYNC_DELAY:-2}"
  kill -0 "${JAVA_PID}" 2>/dev/null || return 0
  printf '%s\n' "${cmds}" >&3
  save_player_state
}

# Gleicht die Listen mit dem Server ab (Befehle über die stdin-Pipe, Dateideskriptor 3)
apply_player_lists() {
  local cmds="" count

  cmds="$(
    player_commands whitelist whitelist.json "whitelist add" "whitelist remove" "" ""
    player_commands ops ops.json "op" "deop" "op" "deop"
    player_commands banned_players banned-players.json "ban" "pardon" "ban" "pardon"
  )"

  if [[ -z "${cmds}" ]]; then
    save_player_state
    return 0
  fi

  count="$(wc -l <<<"${cmds}" | tr -d ' ')"
  log_info "Gleiche Spielerlisten ab (${count} Befehle), sobald der Server bereit ist"
  send_player_commands "${cmds}" &
}

# -----------------------------------------------------------
# Spielregeln (game_rules)
# -----------------------------------------------------------
# Einträge der Form name=wert (true, false oder eine Zahl). Sie werden bei jedem Start per
# "gamerule"-Befehl gesetzt, sobald der Server bereit ist. Spielregeln stehen danach in der
# Welt: Ein gelöschter Eintrag setzt die Regel nicht zurück, dafür den Wert ausdrücklich ändern.
# Ab Minecraft 1.21.11 heißen die Regeln in snake_case (keep_inventory), davor in camelCase
# (keepInventory). Die Schreibweise wird zur Serverversion passend umgewandelt. Regeln, die
# darüber hinaus umbenannt wurden (z. B. doDaylightCycle zu advance_time), muss man mit dem
# neuen Namen angeben.
GAME_VERSION="${MC_ID:-${MC_VERSION}}"

# gamerule_is_snake <Version>: 0 (wahr) für 1.21.11 und neuer sowie die Jahresversionen ab 26.x
gamerule_is_snake() {
  local v="${1%%-*}" a="" b="" c=""
  IFS=. read -r a b c <<<"${v}"
  [[ "${a}" =~ ^[0-9]+$ ]] || return 0
  if (( a > 1 )); then return 0; fi
  [[ "${b}" =~ ^[0-9]+$ ]] || return 0
  if (( b > 21 )); then return 0; fi
  if (( b == 21 )) && [[ "${c:-0}" =~ ^[0-9]+$ ]] && (( ${c:-0} >= 11 )); then return 0; fi
  return 1
}

to_snake() { sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' <<<"$1" | tr '[:upper:]' '[:lower:]'; }
to_camel() { awk -F_ '{ out = $1; for (i = 2; i <= NF; i++) out = out toupper(substr($i, 1, 1)) substr($i, 2); print out }' <<<"$1"; }

# game_rule_commands: gibt die gamerule-Befehle aus
game_rule_commands() {
  local entry name value snake=0
  if gamerule_is_snake "${GAME_VERSION}"; then snake=1; fi
  while IFS= read -r entry; do
    if [[ -z "${entry}" ]]; then
      continue
    elif ! [[ "${entry}" =~ ^([A-Za-z0-9_:]{1,64})=(true|false|-?[0-9]{1,9})$ ]]; then
      log_warn "Ungültige Spielregel ignoriert (erwartet name=wert): ${entry}" >&2
      continue
    fi
    name="${BASH_REMATCH[1]#minecraft:}"
    value="${BASH_REMATCH[2]}"
    if (( snake == 1 )); then name="$(to_snake "${name}")"; else name="$(to_camel "${name}")"; fi
    echo "gamerule ${name} ${value}"
  done < <(list_opt game_rules)
}

# Schickt die Spielregeln an den Server (wie die Spielerlisten, nach dem Start)
apply_game_rules() {
  local cmds count
  cmds="$(game_rule_commands)"
  if [[ -z "${cmds}" ]]; then return 0; fi
  count="$(wc -l <<<"${cmds}" | tr -d ' ')"
  log_info "Setze ${count} Spielregeln, sobald der Server bereit ist"
  send_player_commands "${cmds}" &
}

# -----------------------------------------------------------
# Leistungsprofil (view-distance, simulation-distance, max-players)
# -----------------------------------------------------------
# Die simulation-distance ist der größte Hebel für die CPU-Last, die view-distance
# für RAM und Netzwerk. "custom" lässt server.properties unangetastet.
case "${PERFORMANCE_PROFILE}" in
  low)      PROFILE_VALUES="6 4 10" ;;
  balanced) PROFILE_VALUES="8 6 20" ;;
  high)     PROFILE_VALUES="12 8 40" ;;
  custom)   PROFILE_VALUES="" ;;
  *)
    log_warn "Unbekanntes Leistungsprofil '${PERFORMANCE_PROFILE}', nutze custom"
    PROFILE_VALUES=""
    ;;
esac
if [[ -n "${PROFILE_VALUES}" ]]; then
  read -r PROFILE_VIEW PROFILE_SIM PROFILE_MAX <<<"${PROFILE_VALUES}"
  set_property view-distance "${PROFILE_VIEW}"
  set_property simulation-distance "${PROFILE_SIM}"
  set_property max-players "${PROFILE_MAX}"
  log_info "Leistungsprofil ${PERFORMANCE_PROFILE}: view-distance=${PROFILE_VIEW}, simulation-distance=${PROFILE_SIM}, max-players=${PROFILE_MAX}"
fi

# -----------------------------------------------------------
# Spielwelt und Spielerlebnis (server.properties)
# -----------------------------------------------------------
# Jede Option ändert nur ihren Eintrag in server.properties und nur, wenn sie gesetzt ist
# ("default" bzw. 0 / -1 lässt den Eintrag unangetastet). Ausdrücklich gesetzte Weiten und
# die Spielerzahl überschreiben das Leistungsprofil.

# set_number <Schlüssel> <Option> <Wert> <Min> <Max> <Wert für "unverändert">
set_number() {
  local key="$1" label="$2" val="$3" min="$4" max="$5" skip="$6"
  if [[ -z "${val}" || "${val}" == "${skip}" ]]; then return 0; fi
  if ! [[ "${val}" =~ ^-?[0-9]+$ ]] || (( val < min || val > max )); then
    log_warn "Ungültiger Wert für ${label}: '${val}' (erlaubt ${min} bis ${max}), ignoriert"
    return 0
  fi
  set_property "${key}" "${val}"
  log_info "${label}=${val}"
}

# set_choice <Schlüssel> <Option> <Wert> <erlaubte Werte, durch Leerzeichen getrennt>
set_choice() {
  local key="$1" label="$2" val="$3" allowed="$4"
  if [[ -z "${val}" || "${val}" == "default" ]]; then return 0; fi
  if [[ " ${allowed} " != *" ${val} "* ]]; then
    log_warn "Ungültiger Wert für ${label}: '${val}' (erlaubt: ${allowed}), ignoriert"
    return 0
  fi
  set_property "${key}" "${val}"
  log_info "${label}=${val}"
}

# set_text <Schlüssel> <Option> <Wert>: Text ohne Zeilenumbrüche und Backslash
set_text() {
  local key="$1" label="$2" val="$3"
  if [[ -z "${val}" ]]; then return 0; fi
  if [[ "${val}" == *$'\n'* || "${val}" == *$'\r'* || "${val}" == *\\* ]]; then
    log_warn "Ungültiger Wert für ${label}: Zeilenumbrüche und Backslash sind nicht erlaubt, ignoriert"
    return 0
  fi
  set_property "${key}" "${val}"
  log_info "${label} gesetzt"
}

set_number view-distance "view_distance" "${VIEW_DISTANCE}" 2 32 0
set_number simulation-distance "simulation_distance" "${SIMULATION_DISTANCE}" 2 32 0
set_number max-players "max_players" "${MAX_PLAYERS}" 1 10000 0
set_number entity-broadcast-range-percentage "entity_broadcast_range" "${ENTITY_RANGE}" 10 500 0
set_number spawn-protection "spawn_protection" "${SPAWN_PROTECTION}" 0 1000 -1

set_choice difficulty "difficulty" "${DIFFICULTY}" "peaceful easy normal hard"
set_choice gamemode "gamemode" "${GAMEMODE}" "survival creative adventure spectator"
set_choice force-gamemode "force_gamemode" "${FORCE_GAMEMODE}" "true false"
set_choice hardcore "hardcore" "${HARDCORE}" "true false"
set_choice pvp "pvp" "${PVP}" "true false"
set_choice allow-flight "allow_flight" "${ALLOW_FLIGHT}" "true false"
set_choice allow-nether "allow_nether" "${ALLOW_NETHER}" "true false"
set_choice spawn-monsters "spawn_monsters" "${SPAWN_MONSTERS}" "true false"
set_choice spawn-animals "spawn_animals" "${SPAWN_ANIMALS}" "true false"
set_choice spawn-npcs "spawn_npcs" "${SPAWN_NPCS}" "true false"
set_choice generate-structures "generate_structures" "${GENERATE_STRUCTURES}" "true false"
set_choice enable-command-block "command_blocks" "${COMMAND_BLOCKS}" "true false"

set_text motd "motd" "${MOTD}"
set_text level-seed "level_seed" "${LEVEL_SEED}"

# -----------------------------------------------------------
# Ressourcen: RAM-Schutz, CPU-Priorität und CPU-Kerne
# -----------------------------------------------------------
# JVM_FLAGS: Java-Argumente, LAUNCH: Programme vor java (nice, taskset)
# G1 wird immer ausdrücklich gewählt: Bei weniger als 2 CPUs oder weniger als
# 1,75 GB RAM nimmt Java sonst stillschweigend den langsamen SerialGC.
JVM_FLAGS=(-XX:+UseG1GC)
LAUNCH=()

MEMINFO_FILE="${MEMINFO_FILE:-/proc/meminfo}"
CGROUP_MEM_FILES=("${CGROUP_MEM_FILE:-/sys/fs/cgroup/memory.max}" "/sys/fs/cgroup/memory/memory.limit_in_bytes")

# total_memory_mb: Gesamt-RAM in MB, bei einem Container-Limit der kleinere Wert
total_memory_mb() {
  local kb mb limit f
  kb="$(awk '/^MemTotal:/ {print $2}' "${MEMINFO_FILE}" 2>/dev/null || true)"
  [[ "${kb}" =~ ^[0-9]+$ ]] || return 1
  mb=$(( kb / 1024 ))
  for f in "${CGROUP_MEM_FILES[@]}"; do
    limit="$(cat "${f}" 2>/dev/null || true)"
    if [[ "${limit}" =~ ^[0-9]+$ ]] && (( limit / 1048576 < mb )); then
      mb=$(( limit / 1048576 ))
    fi
  done
  echo "${mb}"
}

# RAM-Schutz: Java braucht über den Heap hinaus noch Speicher, und Home Assistant und
# andere Add-ons brauchen ihren Teil. Es bleibt mindestens ein Viertel, aber nicht
# weniger als 1536 MB frei. Sonst beendet Linux bei Speichermangel zuerst das Add-on.
if [[ "${MEMORY_GUARD}" == "true" ]]; then
  if TOTAL_MB="$(total_memory_mb)"; then
    RESERVE_MB=$(( TOTAL_MB / 4 ))
    if (( RESERVE_MB < 1536 )); then RESERVE_MB=1536; fi
    MAX_HEAP_MB=$(( TOTAL_MB - RESERVE_MB ))
    if (( MAX_HEAP_MB < 512 )); then MAX_HEAP_MB=512; fi
    if (( XMX_MB > MAX_HEAP_MB )); then
      log_warn "xmx_mb (${XMX_MB}) ist zu hoch für ${TOTAL_MB} MB RAM, begrenze auf ${MAX_HEAP_MB} MB (${RESERVE_MB} MB bleiben für System und Home Assistant frei)"
      XMX_MB="${MAX_HEAP_MB}"
    fi
    if (( XMS_MB > XMX_MB )); then XMS_MB="${XMX_MB}"; fi
  else
    log_warn "Gesamt-RAM nicht ermittelbar, RAM-Schutz übersprungen"
  fi
fi

# Fester Heap: Xms = Xmx und den Speicher gleich beim Start belegen. Das verhindert
# Heap-Größenänderungen im Betrieb (Paper empfiehlt es), der Start dauert etwas länger.
if [[ "${FIXED_HEAP}" == "true" ]]; then
  XMS_MB="${XMX_MB}"
  JVM_FLAGS+=(-XX:+AlwaysPreTouch)
fi

# CPU-Priorität: Der Server weicht Home Assistant aus, wenn die CPU knapp ist
case "${CPU_PRIORITY}" in
  normal) ;;
  low)    LAUNCH+=(nice -n 10) ;;
  lowest) LAUNCH+=(nice -n 19) ;;
  *)      log_warn "Unbekannte CPU-Priorität '${CPU_PRIORITY}', nutze normal" ;;
esac

# expand_cpu_list <Liste>: "0-3,6" wird zu einer Kernnummer pro Zeile
expand_cpu_list() {
  local part
  local -a parts=()
  IFS=',' read -r -a parts <<<"$1"
  for part in "${parts[@]}"; do
    if [[ "${part}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      seq "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    elif [[ "${part}" =~ ^[0-9]+$ ]]; then
      echo "${part}"
    fi
  done
}

# CPU-Kerne: Der Server läuft nur auf den letzten N erlaubten Kernen. Kern 0 und die
# vorderen Kerne bleiben für das System und Home Assistant frei. Java passt seine
# Threads (GC, JIT) an die Kernzahl an.
if (( CPU_CORES > 0 )); then
  if ! command -v taskset >/dev/null 2>&1; then
    log_warn "taskset nicht gefunden, cpu_cores wird ignoriert"
  else
    ALLOWED_LIST="$(taskset -cp $$ 2>/dev/null | sed 's/.*: //')"
    mapfile -t ALLOWED_CPUS < <(expand_cpu_list "${ALLOWED_LIST}")
    if (( ${#ALLOWED_CPUS[@]} == 0 )); then
      log_warn "Erlaubte CPU-Kerne nicht ermittelbar, cpu_cores wird ignoriert"
    elif (( CPU_CORES >= ${#ALLOWED_CPUS[@]} )); then
      log_info "cpu_cores=${CPU_CORES}, verfügbar sind ${#ALLOWED_CPUS[@]} Kerne: keine Einschränkung nötig"
    else
      PINNED="$(printf '%s\n' "${ALLOWED_CPUS[@]: -CPU_CORES}" | paste -sd, -)"
      LAUNCH+=(taskset -c "${PINNED}")
      JVM_FLAGS+=("-XX:ActiveProcessorCount=${CPU_CORES}")
    fi
  fi
fi

# -----------------------------------------------------------
# Start (mit sauberem Shutdown bei SIGTERM)
# -----------------------------------------------------------
log_info "Starte Minecraft Vanilla Server"
log_info "Port (Container)  : ${CONTAINER_PORT}"
log_info "RAM               : Xms=${XMS_MB}M / Xmx=${XMX_MB}M"
log_info "CPU               : Priorität=${CPU_PRIORITY}, cpu_cores=${CPU_CORES} (0 = alle)"
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

touch "${PLAYER_MARKER}"
"${LAUNCH[@]}" java -Xms"${XMS_MB}M" -Xmx"${XMX_MB}M" "${JVM_FLAGS[@]}" -jar "${SERVER_JAR}" nogui <&3 &
JAVA_PID=$!

apply_player_lists || log_warn "Spielerlisten konnten nicht abgeglichen werden"
apply_game_rules || log_warn "Spielregeln konnten nicht gesetzt werden"

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
