#!/usr/bin/env bash
# Gemeinsame Hilfsfunktionen für die Mock-Tests der Minecraft-Add-ons.
# Benötigt: bash, jq, tar, sha1sum, sha256sum, timeout (alles Standard unter Linux).
# Die Tests starten die echte run.sh mit Mock-curl und Mock-java im PATH und
# der Variable OPTIONS_FILE. Es gibt keinen Netzwerkzugriff.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034  # wird von den Testdateien genutzt
REPO_DIR="$(cd "${TESTS_DIR}/.." && pwd)"

PASS=0
FAIL=0
FAILED=()
CURRENT_TEST=""
SANDBOXES=()

cleanup_sandboxes() {
  if [[ -z "${KEEP:-}" ]]; then
    for d in "${SANDBOXES[@]:-}"; do
      [[ -n "${d}" ]] && rm -rf "${d}"
    done
  fi
}
trap cleanup_sandboxes EXIT

# -----------------------------------------------------------
# Ausgabe und Assertions
# -----------------------------------------------------------
ok()  { PASS=$((PASS + 1)); echo "  ok    $*"; }
nok() { FAIL=$((FAIL + 1)); echo "  FAIL  $*"; FAILED+=("${CURRENT_TEST}: $*"); }

# assert_eq <Beschreibung> <erwartet> <tatsächlich>
assert_eq() {
  if [[ "$3" == "$2" ]]; then ok "$1"; else nok "$1 (erwartet '$2', erhalten '$3')"; fi
}

assert_rc() { assert_eq "Exit-Code ist $1" "$1" "${RC}"; }

# Ausgabe der run.sh ohne ANSI-Farben: $T/out.log
assert_out_has() {
  if grep -qF -- "$1" "${T}/out.log"; then ok "Log enthält: $1"; else nok "Log enthält nicht: $1"; fi
}
assert_out_lacks() {
  if grep -qF -- "$1" "${T}/out.log"; then nok "Log enthält unerwartet: $1"; else ok "Log enthält nicht: $1"; fi
}

assert_file()    { if [[ -e "${DATA}/$1" ]]; then ok "Datei vorhanden: $1"; else nok "Datei fehlt: $1"; fi; }
assert_no_file() { if [[ -e "${DATA}/$1" ]]; then nok "Datei unerwartet vorhanden: $1"; else ok "Datei nicht vorhanden: $1"; fi; }

# assert_file_lacks <Datei> <fester Text>
assert_file_lacks() {
  if grep -qF -- "$2" "${DATA}/$1" 2>/dev/null; then nok "$1 enthält unerwartet: $2"; else ok "$1 enthält nicht: $2"; fi
}

# assert_file_has <Datei> <fester Text>
assert_file_has() {
  if grep -qF -- "$2" "${DATA}/$1" 2>/dev/null; then ok "$1 enthält: $2"; else nok "$1 enthält nicht: $2"; fi
}

# Anzahl der curl-Aufrufe (GET-Zeilen) des letzten Laufs, die zum ERE passen
calls_matching() { grep -cE "^GET .*($1)" "${MOCK_CALLS}" 2>/dev/null || true; }

# assert_calls <Beschreibung> <ERE> <erwartete Anzahl>
assert_calls() { assert_eq "$1" "$3" "$(calls_matching "$2")"; }

# assert_java_args <fester Text>: der Mock-java wurde mit diesen Argumenten gestartet
assert_java_args() {
  if grep -qF -- "$1" "${MOCK_JAVA_LOG}" 2>/dev/null; then ok "java gestartet mit: $1"; else nok "java nicht gestartet mit: $1 ($(cat "${MOCK_JAVA_LOG}" 2>/dev/null))"; fi
}

# -----------------------------------------------------------
# Sandbox pro Test
# -----------------------------------------------------------
# sandbox <Testname> <Pfad der run.sh>
sandbox() {
  CURRENT_TEST="$1"
  ADDON_SCRIPT="$2"
  echo "== $1"

  T="$(mktemp -d)"
  SANDBOXES+=("${T}")
  mkdir -p "${T}/bin" "${T}/tmp" "${T}/data" "${T}/www"
  cp "${TESTS_DIR}/mocks/curl" "${T}/bin/curl"
  chmod +x "${T}/bin/curl"

  export MOCK_WWW="${T}/www"
  export MOCK_CALLS="${T}/calls.log"
  export MOCK_FAIL="${T}/fail.txt"
  export MOCK_READY="${T}/ready"
  export MOCK_STDIN_LOG="${T}/java_stdin.log"
  export MOCK_JAVA_LOG="${T}/java_invocations.log"
  export MOCK_JAVA_MODE="exit"
  export MOCK_JAVA_EXIT_CODE="0"
  export PLAYER_SYNC_DELAY="0.2"
  # Feste Test-Umgebung für den RAM-Schutz: 16 GB RAM und kein Container-Limit
  printf "MemTotal:       16777216 kB
MemAvailable:   12582912 kB
" > "${T}/meminfo"
  export MEMINFO_FILE="${T}/meminfo"
  export CGROUP_MEM_FILE="${T}/no-cgroup-limit"
  : > "${MOCK_CALLS}"
  : > "${MOCK_FAIL}"
  : > "${MOCK_JAVA_LOG}"
  : > "${MOCK_STDIN_LOG}"

  DATA="${T}/data/server"
  RC=""
  set_options '{}'
  build_jre_archives
}

# set_options <JSON>: Standardwerte plus die angegebenen Überschreibungen (null löscht einen Wert)
set_options() {
  jq -n --arg dd "${DATA}" --argjson o "$1" \
    '{data_dir: $dd, accept_eula: true, xms_mb: 512, xmx_mb: 1024, mc_version: "latest"} * $o' \
    > "${T}/options.json"
}

# Gefälschte Temurin-Archive für mehrere Java-Versionen und beide Architekturen
build_jre_archives() {
  local major arch src dir
  for major in 8 17 21 25; do
    src="${T}/jre-src/jdk-${major}-jre"
    mkdir -p "${src}/bin"
    cp "${TESTS_DIR}/mocks/java" "${src}/bin/java"
    chmod +x "${src}/bin/java"
    echo "${major}" > "${src}/.mock_major"
    for arch in x64 aarch64; do
      # Archiv auf einem GitHub-ähnlichen Host, Link und Prüfsumme in der Assets-API
      dir="${MOCK_WWW}/github.com/adoptium/mock-binaries"
      mkdir -p "${dir}" "${MOCK_WWW}/api.adoptium.net/v3/assets/latest/${major}"
      tar -czf "${dir}/jre-${major}-${arch}.tar.gz" -C "${T}/jre-src" "jdk-${major}-jre"
      jq -n --arg link "https://github.com/adoptium/mock-binaries/jre-${major}-${arch}.tar.gz" \
        --arg sha "$(sha256sum "${dir}/jre-${major}-${arch}.tar.gz" | cut -d' ' -f1)" \
        '[{binary: {package: {link: $link, checksum: $sha}}}]' \
        > "${MOCK_WWW}/api.adoptium.net/v3/assets/latest/${major}/hotspot.${arch}"
    done
    # Die Mock-API ignoriert die Query, deshalb wird die Datei zur Laufzeit-Architektur gewählt
    case "$(uname -m)" in
      aarch64|arm64) cp "${MOCK_WWW}/api.adoptium.net/v3/assets/latest/${major}/hotspot.aarch64" "${MOCK_WWW}/api.adoptium.net/v3/assets/latest/${major}/hotspot" ;;
      *)             cp "${MOCK_WWW}/api.adoptium.net/v3/assets/latest/${major}/hotspot.x64" "${MOCK_WWW}/api.adoptium.net/v3/assets/latest/${major}/hotspot" ;;
    esac
  done
}

# Setzt in der Mock-Adoptium-API eine falsche Prüfsumme für die angegebene Java-Version
jre_break_checksum() {
  local f="${MOCK_WWW}/api.adoptium.net/v3/assets/latest/$1/hotspot"
  jq '.[0].binary.package.checksum = "0000000000000000000000000000000000000000000000000000000000000000"' "${f}" > "${f}.new"
  mv "${f}.new" "${f}"
}

# -----------------------------------------------------------
# Läufe
# -----------------------------------------------------------
run_env() {
  PATH="${T}/bin:${PATH}" OPTIONS_FILE="${T}/options.json" TMPDIR="${T}/tmp" "$@"
}

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g' "${T}/out.raw" > "${T}/out.log"; }

# Startet die run.sh und wartet auf das Ende. Setzt RC.
run_addon() {
  : > "${MOCK_CALLS}"
  : > "${MOCK_JAVA_LOG}"
  rm -f "${MOCK_READY}"
  run_env timeout 60 bash "${ADDON_SCRIPT}" > "${T}/out.raw" 2>&1
  RC=$?
  strip_ansi
}

# Startet die run.sh im Hintergrund (für Signal-Tests) und wartet, bis der Mock-Server läuft.
start_addon_bg() {
  : > "${MOCK_CALLS}"
  : > "${MOCK_JAVA_LOG}"
  : > "${MOCK_STDIN_LOG}"
  rm -f "${MOCK_READY}"
  # Direkter Hintergrundstart (kein Funktionsaufruf), damit ADDON_PID die run.sh selbst ist
  PATH="${T}/bin:${PATH}" OPTIONS_FILE="${T}/options.json" TMPDIR="${T}/tmp" \
    bash "${ADDON_SCRIPT}" > "${T}/out.raw" 2>&1 &
  ADDON_PID=$!
  local i
  for i in $(seq 1 200); do
    [[ -e "${MOCK_READY}" ]] && return 0
    sleep 0.1
  done
  nok "Mock-Server wurde nicht gestartet"
  kill -9 "${ADDON_PID}" 2>/dev/null || true
  return 1
}

# Wartet bis zu 20 s auf das Ende des Hintergrundlaufs. Setzt RC (124 bei Zeitüberschreitung).
wait_addon_bg() {
  local i
  for i in $(seq 1 200); do
    if ! kill -0 "${ADDON_PID}" 2>/dev/null; then
      wait "${ADDON_PID}"
      RC=$?
      strip_ansi
      return 0
    fi
    sleep 0.1
  done
  kill -9 "${ADDON_PID}" 2>/dev/null || true
  RC=124
  strip_ansi
}

# Gemeinsames Signal-Szenario: SIGTERM -> "stop" an den Server -> Exit 0
scenario_sigterm() {
  export MOCK_JAVA_MODE="wait"
  if start_addon_bg; then
    kill -TERM "${ADDON_PID}"
    wait_addon_bg
    assert_rc 0
    assert_file_stdin_has_stop
    assert_out_has "Stop-Signal empfangen"
    assert_out_has "Server gestoppt"
    assert_file_has "logs/latest.log" "Saving worlds"
  fi
  export MOCK_JAVA_MODE="exit"
}

# Startet den Mock-Server (wait-Modus), wartet bis mindestens <N> Zeilen auf seinem stdin
# angekommen sind (die Spielerlisten-Befehle), schickt dann SIGTERM und wartet auf das Ende.
run_lists_scenario() {
  local expected="$1" i
  export MOCK_JAVA_MODE="wait"
  if start_addon_bg; then
    for i in $(seq 1 100); do
      [[ -f "${DATA}/.managed_players.json" ]] && (( $(wc -l < "${MOCK_STDIN_LOG}") >= expected )) && break
      sleep 0.1
    done
    kill -TERM "${ADDON_PID}"
    wait_addon_bg
  fi
  export MOCK_JAVA_MODE="exit"
}

# assert_cmd <Zeile>: der Server hat diesen Befehl auf stdin erhalten
assert_cmd() {
  if grep -qxF -- "$1" "${MOCK_STDIN_LOG}"; then ok "Befehl an den Server: $1"; else nok "Befehl fehlt: $1 (erhalten: $(tr "\n" "|" < "${MOCK_STDIN_LOG}"))"; fi
}
assert_no_cmd() {
  if grep -qxF -- "$1" "${MOCK_STDIN_LOG}"; then nok "Unerwarteter Befehl an den Server: $1"; else ok "Kein Befehl: $1"; fi
}

assert_file_stdin_has_stop() {
  if grep -qx "stop" "${MOCK_STDIN_LOG}"; then ok "Server erhielt 'stop' auf stdin"; else nok "Server erhielt kein 'stop' auf stdin"; fi
}

# -----------------------------------------------------------
# Fixtures: Mojang (Vanilla)
# -----------------------------------------------------------
MOJANG_IDS=()

mojang_reset() {
  MOJANG_IDS=()
  rm -rf "${MOCK_WWW}/piston-meta.mojang.com" "${MOCK_WWW}/piston-data.mojang.com"
}

# mojang_add <id> <Java-Major|none> [badsha]: die zuerst hinzugefügte Version ist "latest"
mojang_add() {
  local id="$1" java="$2" bad="${3:-}" content real_sha shown_sha dir
  content="SERVERJAR ${id}"
  real_sha="$(printf '%s' "${content}" | sha1sum | cut -d' ' -f1)"
  shown_sha="${real_sha}"
  [[ -n "${bad}" ]] && shown_sha="0000000000000000000000000000000000000000"
  dir="${MOCK_WWW}/piston-data.mojang.com/v1/objects/${real_sha}"
  mkdir -p "${dir}" "${MOCK_WWW}/piston-meta.mojang.com/v1/packages"
  printf '%s' "${content}" > "${dir}/server.jar"
  jq -n --arg id "${id}" --arg sha "${shown_sha}" --arg java "${java}" \
    --arg url "https://piston-data.mojang.com/v1/objects/${real_sha}/server.jar" \
    '{id: $id, downloads: {server: {sha1: $sha, size: 1, url: $url}}}
     + (if $java == "none" then {} else {javaVersion: {component: "mock", majorVersion: ($java | tonumber)}} end)' \
    > "${MOCK_WWW}/piston-meta.mojang.com/v1/packages/${id}.json"
  MOJANG_IDS+=("${id}")
}

mojang_finish() {
  mkdir -p "${MOCK_WWW}/piston-meta.mojang.com/mc/game"
  printf '%s\n' "${MOJANG_IDS[@]}" | jq -R . | jq -s \
    '{latest: {release: .[0], snapshot: "99.9-snapshot-1"},
      versions: ([{id: "99.9-snapshot-1", type: "snapshot", url: "https://piston-meta.mojang.com/v1/packages/99.9-snapshot-1.json"}]
        + map({id: ., type: "release", url: ("https://piston-meta.mojang.com/v1/packages/" + . + ".json")}))}' \
    > "${MOCK_WWW}/piston-meta.mojang.com/mc/game/version_manifest_v2.json"
}

# -----------------------------------------------------------
# Fixtures: Paper (Fill v3)
# -----------------------------------------------------------
PAPER_VERSIONS=()

paper_reset() {
  PAPER_VERSIONS=()
  rm -rf "${MOCK_WWW}/fill.papermc.io" "${MOCK_WWW}/fill-data.papermc.io"
}

# paper_add <Version> <Java-Minimum> <Channels der Builds, neuester zuerst, Komma getrennt> [badsha]
paper_add() {
  local ver="$1" java="$2" channels="$3" bad="${4:-}"
  local base="${MOCK_WWW}/fill.papermc.io/v3/projects/paper/versions/${ver}"
  local -a chans builds=()
  local count i id content sha shown_sha objdir
  IFS=',' read -r -a chans <<<"${channels}"
  count="${#chans[@]}"
  mkdir -p "${base}"

  jq -n --arg v "${ver}" --argjson j "${java}" \
    '{version: {id: $v, support: {status: "SUPPORTED"}, java: {version: {minimum: $j}}}, builds: []}' > "${base}/index"

  for i in "${!chans[@]}"; do
    id=$((count - i))
    content="PAPERJAR ${ver} ${id}"
    sha="$(printf '%s' "${content}" | sha256sum | cut -d' ' -f1)"
    objdir="${MOCK_WWW}/fill-data.papermc.io/v1/objects/${sha}"
    mkdir -p "${objdir}"
    printf '%s' "${content}" > "${objdir}/paper-${ver}-${id}.jar"
    shown_sha="${sha}"
    if [[ -n "${bad}" && "${i}" == "0" ]]; then
      shown_sha="0000000000000000000000000000000000000000000000000000000000000000"
    fi
    builds+=("$(jq -nc --argjson id "${id}" --arg ch "${chans[$i]}" --arg sha "${shown_sha}" \
      --arg url "https://fill-data.papermc.io/v1/objects/${sha}/paper-${ver}-${id}.jar" --arg name "paper-${ver}-${id}.jar" \
      '{id: $id, time: "2026-01-01T00:00:00Z", channel: $ch, commits: [],
        downloads: {"server:default": {name: $name, checksums: {sha256: $sha}, size: 1, url: $url}}}')")
  done
  printf '%s\n' "${builds[@]}" | jq -s . > "${base}/builds"
  PAPER_VERSIONS+=("${ver}")
}

# Baut die Projektübersicht (Versionen nach Hauptversion gruppiert, wie in der echten API)
paper_finish() {
  mkdir -p "${MOCK_WWW}/fill.papermc.io/v3/projects/paper"
  printf '%s\n' "${PAPER_VERSIONS[@]}" | jq -R . | jq -s \
    '{project: {id: "paper", name: "Paper"},
      versions: (reduce .[] as $v ({}; .[($v | split("-")[0] | split(".")[0:2] | join("."))] += [$v]))}' \
    > "${MOCK_WWW}/fill.papermc.io/v3/projects/paper/index"
}

# Standard-Paper-Fixture:
#   27.0        nur BETA                      (nur mit allow_experimental)
#   27.1-rc-1   STABLE, aber Release-Candidate (wird wegen "-" übersprungen)
#   26.3        neuester STABLE-Build 3, Java 25
#   26.3-rc-3   Release-Candidate
#   1.21.11     STABLE, Java 21
paper_fixture_default() {
  paper_reset
  paper_add "27.0" 25 "BETA"
  paper_add "27.1-rc-1" 25 "STABLE"
  paper_add "26.3" 25 "STABLE,STABLE,BETA"
  paper_add "26.3-rc-3" 25 "ALPHA"
  paper_add "1.21.11" 21 "STABLE,STABLE"
  paper_add "1.21.10" 21 "STABLE"
  paper_finish
}

# -----------------------------------------------------------
# Fixtures: Plugins
# -----------------------------------------------------------
# plugin_serve <Pfad unter www> <Inhaltskennung>: legt eine Datei an, die wie ein JAR (ZIP) beginnt
plugin_serve() {
  mkdir -p "$(dirname "${MOCK_WWW}/$1")"
  printf 'PK\003\004%s' "$2" > "${MOCK_WWW}/$1"
}

GEYSER_PATH="download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
FLOODGATE_PATH="download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"

plugin_fixture_geysermc() {
  plugin_serve "${GEYSER_PATH}" "geyser-$1"
  plugin_serve "${FLOODGATE_PATH}" "floodgate-$1"
}

# -----------------------------------------------------------
# Abschluss
# -----------------------------------------------------------
summary() {
  echo
  echo "Ergebnis: ${PASS} bestanden, ${FAIL} fehlgeschlagen"
  if (( FAIL > 0 )); then
    printf '  - %s\n' "${FAILED[@]}"
    return 1
  fi
}
