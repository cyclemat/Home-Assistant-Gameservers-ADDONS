#!/usr/bin/env bash
# Mock-Tests für minecraft_paper_geyser_server/run.sh
# Aufruf: tests/test_paper.sh (siehe tests/README.md)

# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPT="${REPO_DIR}/minecraft_paper_geyser_server/run.sh"

# Sandbox mit Standard-Fixtures (Paper, Geyser, Floodgate)
paper_sandbox() {
  sandbox "$1" "${SCRIPT}"
  paper_fixture_default
  plugin_fixture_geysermc v1
}

t_eula_fehlt() {
  paper_sandbox "EULA fehlt"
  set_options '{"accept_eula": false}'
  run_addon
  assert_rc 1
  assert_out_has "EULA"
  assert_calls "keine Downloads vor der Zustimmung" "." 0
  assert_no_file "paper.jar"

  set_options '{"accept_eula": null}'
  run_addon
  assert_rc 1
}

t_xms_groesser_xmx() {
  paper_sandbox "Xms größer als Xmx"
  set_options '{"xms_mb": 4096, "xmx_mb": 1024}'
  run_addon
  assert_rc 1
  assert_out_has "darf nicht größer als xmx_mb"
  assert_calls "keine Downloads" "." 0
}

t_normalstart() {
  paper_sandbox "Normalstart (latest wählt neueste Version mit STABLE-Build)"
  run_addon
  assert_rc 0
  assert_out_has "Paper 26.3, Build 3 (STABLE)"
  assert_out_lacks "Experimenteller Build"
  assert_out_has "Prüfsumme (SHA-256) ok"
  assert_file_has "paper.jar" "PAPERJAR 26.3 3"
  assert_file_has ".paper_build.txt" "26.3 3"
  assert_calls "Java 25 aus den Paper-Metadaten" "adoptium.net/.*/latest/25/" 1
  assert_file ".jre/25/bin/java"
  assert_java_args "major=25 args=-Xms512M -Xmx1024M -XX:+UseG1GC -jar paper.jar nogui"
  assert_file_has "eula.txt" "eula=true"
  assert_file_has "server.properties" "server-port=25565"
  assert_file "plugins/Geyser-Spigot.jar"
  assert_file "plugins/floodgate-spigot.jar"
  assert_file_has "plugins/Geyser-Spigot.jar" "geyser-v1"
  assert_out_has "Bedrock-Port (TCP+UDP): 19132"
  if grep -q "^HEADER User-Agent: ha-addon-minecraft-paper-geyser/" "${MOCK_CALLS}"; then
    ok "Fill-API wird mit eindeutigem User-Agent abgefragt"
  else
    nok "User-Agent fehlt"
  fi
}

t_rc_und_vorversionen_werden_uebersprungen() {
  paper_sandbox "latest überspringt Versionen mit '-' (rc), auch mit STABLE-Build"
  run_addon
  assert_rc 0
  assert_calls "27.1-rc-1 wird gar nicht abgefragt" "versions/27.1-rc-1" 0
  assert_calls "26.3-rc-3 wird gar nicht abgefragt" "versions/26.3-rc-3" 0
  assert_calls "27.0 (nur BETA) wird geprüft und verworfen" "versions/27.0/builds" 1
  assert_out_lacks "27.1-rc-1"
}

t_allow_experimental() {
  paper_sandbox "allow_experimental nimmt auch Pre-Releases (27.1-rc-1) mit Warnung"
  set_options '{"allow_experimental": true}'
  run_addon
  assert_rc 0
  assert_out_has "Paper 27.1-rc-1, Build 1 (STABLE)"
  assert_out_has "Experimenteller Build oder Vorabversion"
  assert_file_has "paper.jar" "PAPERJAR 27.1-rc-1 1"
}

t_allow_experimental_beta() {
  sandbox "allow_experimental nimmt auch BETA-Builds" "${SCRIPT}"
  plugin_fixture_geysermc v1
  paper_reset
  paper_add "27.0" 25 "BETA"
  paper_add "26.3" 25 "STABLE"
  paper_finish
  set_options '{"allow_experimental": true}'
  run_addon
  assert_rc 0
  assert_out_has "Paper 27.0, Build 1 (BETA)"
  assert_out_has "Experimenteller Build oder Vorabversion"
  assert_file_has "paper.jar" "PAPERJAR 27.0 1"

  # Ohne allow_experimental bleibt es bei 26.3
  set_options '{}'
  run_addon
  assert_out_has "Paper 26.3, Build 1 (STABLE)"
  assert_out_has "Minecraft-Version wechselt von 27.0 auf 26.3"
}

t_release_vor_rc_bei_experimental() {
  sandbox "allow_experimental: Release steht vor seinem Release-Candidate" "${SCRIPT}"
  plugin_fixture_geysermc v1
  paper_reset
  paper_add "26.3-rc-3" 25 "ALPHA"
  paper_add "26.3" 25 "STABLE"
  paper_add "26.3-rc-2" 25 "ALPHA"
  paper_finish
  set_options '{"allow_experimental": true}'
  run_addon
  assert_rc 0
  assert_out_has "Paper 26.3, Build 1 (STABLE)"
}

t_gepinnte_version_mit_eigener_java_version() {
  paper_sandbox "Gepinnte Version 1.21.11 nutzt ihre eigene Java-Version (21)"
  set_options '{"mc_version": "1.21.11"}'
  run_addon
  assert_rc 0
  assert_out_has "Paper 1.21.11, Build 2 (STABLE)"
  assert_calls "Java 21 wird geladen" "adoptium.net/.*/latest/21/" 1
  assert_calls "Java 25 wird nicht geladen" "adoptium.net/.*/latest/25/" 0
  assert_java_args "major=21 args="
  assert_calls "Projektübersicht wird bei gepinnter Version nicht gebraucht" "v3/projects/paper$" 0
}

t_gepinnte_version_ohne_stable_build() {
  paper_sandbox "Gepinnte Version ohne STABLE-Build bricht ab"
  set_options '{"mc_version": "27.0"}'
  run_addon
  assert_rc 1
  assert_out_has "gibt es keinen passenden Paper-Build"
  assert_no_file "paper.jar"
}

t_java_major_option() {
  paper_sandbox "java_major überschreibt die Paper-Metadaten"
  set_options '{"java_major": 21}'
  run_addon
  assert_rc 0
  assert_calls "Java 21 wird geladen" "adoptium.net/.*/latest/21/" 1
  assert_calls "Java 25 wird nicht geladen" "adoptium.net/.*/latest/25/" 0
}

t_java_pruefsumme_falsch() {
  paper_sandbox "Falsche Java-Prüfsumme: Abbruch, keine Installation"
  jre_break_checksum 25
  run_addon
  assert_rc 1
  assert_out_has "Prüfsumme des Java-Archivs stimmt nicht überein"
  assert_no_file ".jre/25"
  assert_no_file ".jre/25.tmp"
  assert_no_file "paper.jar"
  if [[ -s "${MOCK_JAVA_LOG}" ]]; then nok "java wurde unerwartet gestartet"; else ok "java wurde nicht gestartet"; fi
}

t_adoptium_api_nicht_erreichbar() {
  paper_sandbox "Adoptium-API nicht erreichbar bricht ab"
  echo "api.adoptium.net/*" > "${MOCK_FAIL}"
  run_addon
  assert_rc 1
  assert_out_has "Adoptium-API nicht erreichbar"
  assert_no_file "paper.jar"
}

t_java_metadaten_fehlen() {
  paper_sandbox "Fehlende Java-Metadaten: Fallback auf Java 25 mit Warnung"
  rm -f "${MOCK_WWW}/fill.papermc.io/v3/projects/paper/versions/26.3/index"
  run_addon
  assert_rc 0
  assert_out_has "Benötigte Java-Version nicht ermittelbar, nutze Java 25"
  assert_calls "Java 25 wird geladen" "adoptium.net/.*/latest/25/" 1
}

t_sigterm() {
  paper_sandbox "SIGTERM führt zu stop und Exit 0"
  scenario_sigterm
}

t_neustart_ohne_redownload() {
  paper_sandbox "Neustart ohne Re-Downloads"
  set_options '{"update_plugins": false}'
  run_addon
  assert_rc 0
  assert_calls "erster Lauf lädt Java (API und Archiv)" "adoptium" 2
  assert_calls "erster Lauf lädt Paper" "fill-data" 1
  assert_calls "erster Lauf lädt Geyser und Floodgate" "geysermc" 2
  run_addon
  assert_rc 0
  assert_calls "zweiter Lauf: kein Java-Download" "adoptium" 0
  assert_calls "zweiter Lauf: kein Paper-Download" "fill-data" 0
  assert_calls "zweiter Lauf: keine Plugin-Downloads" "geysermc" 0
  assert_out_lacks "Lade Paper herunter"
}

t_neuer_build_laedt_neu() {
  paper_sandbox "Neuer Paper-Build ersetzt das JAR"
  run_addon
  assert_file_has "paper.jar" "PAPERJAR 26.3 3"
  paper_reset
  paper_add "26.3" 25 "STABLE,STABLE,STABLE,STABLE"
  paper_finish
  run_addon
  assert_rc 0
  assert_file_has "paper.jar" "PAPERJAR 26.3 4"
  assert_calls "Paper wird neu geladen" "fill-data" 1
  assert_calls "Java bleibt erhalten" "adoptium" 0
}

t_pruefsumme_falsch() {
  sandbox "Falsche Prüfsumme: Abbruch, keine JAR" "${SCRIPT}"
  plugin_fixture_geysermc v1
  paper_reset
  paper_add "26.3" 25 "STABLE" badsha
  paper_finish
  run_addon
  assert_rc 1
  assert_out_has "Prüfsumme des Paper-JAR stimmt nicht überein"
  assert_no_file "paper.jar"
  assert_no_file "paper.jar.tmp"
  assert_no_file ".paper_build.txt"
  assert_calls "Plugins werden nach dem Abbruch nicht mehr geladen" "geysermc" 0
  if [[ -s "${MOCK_JAVA_LOG}" ]]; then nok "java wurde unerwartet gestartet"; else ok "java wurde nicht gestartet"; fi
}

t_fill_api_nicht_erreichbar() {
  paper_sandbox "Fill-API nicht erreichbar bricht ab"
  echo "fill.papermc.io/*" > "${MOCK_FAIL}"
  run_addon
  assert_rc 1
  assert_out_has "Paper-API (fill.papermc.io) nicht erreichbar"
}

t_plugin_download_scheitert() {
  paper_sandbox "Plugin-Download scheitert: Start trotzdem, vorhandene Jar bleibt"
  # Erster Lauf installiert Geyser v1
  run_addon
  assert_file_has "plugins/Geyser-Spigot.jar" "geyser-v1"
  # Zweiter Lauf: neue Version vorhanden, der Server dazu aber nicht erreichbar
  plugin_fixture_geysermc v2
  echo "download.geysermc.org/*" > "${MOCK_FAIL}"
  run_addon
  assert_rc 0
  assert_out_has "Geyser (Bedrock-Brücke): Download fehlgeschlagen, nutze die vorhandene Version"
  assert_file_has "plugins/Geyser-Spigot.jar" "geyser-v1"
  assert_no_file "plugins/Geyser-Spigot.jar.tmp"
  assert_java_args "-jar paper.jar nogui"

  # Ohne vorhandene Jar: Warnung, der Server startet trotzdem
  rm -f "${DATA}/plugins/floodgate-spigot.jar"
  run_addon
  assert_rc 0
  assert_out_has "Floodgate (Bedrock-Login ohne Java-Account): Download fehlgeschlagen, das Plugin ist NICHT installiert"
  assert_no_file "plugins/floodgate-spigot.jar"
  assert_java_args "-jar paper.jar nogui"
}

t_plugin_download_liefert_keine_jar() {
  paper_sandbox "Plugin-Download liefert keine JAR (HTML-Fehlerseite): verworfen"
  run_addon
  printf '<html>Rate limit</html>' > "${MOCK_WWW}/${GEYSER_PATH}"
  run_addon
  assert_rc 0
  assert_file_has "plugins/Geyser-Spigot.jar" "geyser-v1"
  assert_out_has "nutze die vorhandene Version"
}

t_update_plugins_false() {
  paper_sandbox "update_plugins=false behält vorhandene Plugins"
  set_options '{"update_plugins": false}'
  run_addon
  assert_file_has "plugins/Geyser-Spigot.jar" "geyser-v1"
  plugin_fixture_geysermc v2
  run_addon
  assert_rc 0
  assert_file_has "plugins/Geyser-Spigot.jar" "geyser-v1"
  assert_calls "keine Geyser/Floodgate-Downloads" "geysermc" 0
  assert_out_has "Updates deaktiviert (update_plugins=false)"

  # Fehlendes Plugin wird auch bei update_plugins=false installiert
  rm -f "${DATA}/plugins/floodgate-spigot.jar"
  run_addon
  assert_file_has "plugins/floodgate-spigot.jar" "floodgate-v2"
  assert_calls "nur das fehlende Plugin wird geladen" "geysermc" 1
}

t_update_plugins_true() {
  paper_sandbox "update_plugins=true aktualisiert Geyser und Floodgate"
  run_addon
  plugin_fixture_geysermc v2
  run_addon
  assert_file_has "plugins/Geyser-Spigot.jar" "geyser-v2"
  assert_file_has "plugins/floodgate-spigot.jar" "floodgate-v2"
}

t_bedrock_support_false() {
  paper_sandbox "bedrock_support=false installiert weder Geyser noch Floodgate"
  set_options '{"bedrock_support": false}'
  run_addon
  assert_rc 0
  assert_calls "keine Geyser/Floodgate-Downloads" "geysermc" 0
  assert_no_file "plugins/Geyser-Spigot.jar"
  assert_no_file "plugins/floodgate-spigot.jar"
  assert_out_lacks "Bedrock-Port"
  assert_java_args "-jar paper.jar nogui"
}

t_plugin_urls() {
  paper_sandbox "plugin_urls: https wird geladen, http und andere Schemata werden ignoriert"
  plugin_serve "plugins.example.com/foo-1.0.jar" "foo"
  plugin_serve "plugins.example.com/download" "unnamed"
  plugin_serve "evil.example.com/bad.jar" "bad"
  set_options '{"plugin_urls": [
    "http://evil.example.com/bad.jar",
    "https://plugins.example.com/foo-1.0.jar?token=abc",
    "ftp://evil.example.com/bad.jar",
    "https://plugins.example.com/download",
    "https://plugins.example.com/../../etc/passwd.jar"
  ]}'
  run_addon
  assert_rc 0
  assert_calls "http-URL wird nie abgerufen" "http://evil" 0
  assert_calls "ftp-URL wird nie abgerufen" "ftp://" 0
  assert_out_has "Plugin-URL ignoriert (nur https erlaubt): http://evil.example.com/bad.jar"
  assert_out_has "Plugin-URL ignoriert (nur https erlaubt): ftp://evil.example.com/bad.jar"
  assert_file "plugins/foo-1.0.jar"
  assert_file_has "plugins/foo-1.0.jar" "foo"
  assert_file "plugins/extra-plugin-4.jar"
  assert_no_file "plugins/bad.jar"
  assert_no_file "plugins/passwd.jar"
}

t_geyser_config_wird_einmalig_angelegt() {
  paper_sandbox "Geyser-Config: Floodgate-Login und NetherNet, nie überschrieben"
  run_addon
  assert_rc 0
  assert_file_has "plugins/Geyser-Spigot/config.yml" "auth-type: floodgate"
  assert_file_has "plugins/Geyser-Spigot/config.yml" "transport: nethernet"
  assert_out_has "Geyser-Konfiguration angelegt"

  # Eigene Änderungen des Benutzers bleiben bei jedem weiteren Start erhalten
  printf 'bedrock:\n  transport: both\n' > "${DATA}/plugins/Geyser-Spigot/config.yml"
  run_addon
  assert_rc 0
  assert_file_has "plugins/Geyser-Spigot/config.yml" "transport: both"
  assert_out_lacks "Geyser-Konfiguration angelegt"
}

t_geyser_config_ohne_floodgate() {
  sandbox "Geyser-Config wird ohne Floodgate nicht angelegt" "${SCRIPT}"
  paper_fixture_default
  plugin_serve "${GEYSER_PATH}" "geyser-v1"
  echo "${FLOODGATE_PATH}" > "${MOCK_FAIL}"
  run_addon
  assert_rc 0
  assert_file "plugins/Geyser-Spigot.jar"
  assert_no_file "plugins/Geyser-Spigot/config.yml"
  assert_out_has "Floodgate fehlt, Geyser-Konfiguration wird nicht vorbereitet"
}

t_geyser_config_bei_bedrock_support_false() {
  paper_sandbox "bedrock_support=false legt keine Geyser-Config an"
  set_options '{"bedrock_support": false}'
  run_addon
  assert_rc 0
  assert_no_file "plugins/Geyser-Spigot/config.yml"
}

t_spielerlisten_befehle() {
  paper_sandbox "Spielerlisten: Befehle an den Server und Whitelist-Schalter"
  set_options '{"whitelist_enabled": true, "whitelist": ["Alice", "Bob"], "ops": ["Alice"], "banned_players": ["Griefer"]}'
  run_lists_scenario 4
  assert_rc 0
  assert_cmd "whitelist add Alice"
  assert_cmd "whitelist add Bob"
  assert_cmd "op Alice"
  assert_cmd "ban Griefer"
  assert_cmd "stop"
  assert_out_has "Gleiche Spielerlisten ab (4 Befehle)"
  assert_file_has "server.properties" "white-list=true"
  assert_file_has "server.properties" "enforce-whitelist=true"
  assert_file_has "server.properties" "server-port=25565"
  assert_file ".managed_players.json"
}

t_spielerlisten_abgleich() {
  paper_sandbox "Spielerlisten: nur Neues hinzufügen, nur Entferntes entfernen"
  mkdir -p "${DATA}"
  # Alice ist schon auf dem Server, Carol stand zuvor in der Konfiguration, Dave wurde im Spiel hinzugefügt
  printf '[{"uuid":"1","name":"alice"},{"uuid":"2","name":"Carol"},{"uuid":"3","name":"Dave"}]' > "${DATA}/whitelist.json"
  printf '[{"uuid":"4","name":"Oldop","level":4}]' > "${DATA}/ops.json"
  printf '{"whitelist":["Alice","Carol"],"ops":["Oldop"],"banned_players":[]}' > "${DATA}/.managed_players.json"
  set_options '{"whitelist": ["Alice", "Bob"], "ops": [], "banned_players": ["Griefer"]}'
  run_lists_scenario 4
  assert_rc 0
  assert_no_cmd "whitelist add Alice"
  assert_cmd "whitelist add Bob"
  assert_cmd "whitelist remove carol"
  assert_no_cmd "whitelist remove dave"
  assert_cmd "deop oldop"
  assert_cmd "ban Griefer"
  assert_file_has "server.properties" "white-list=false"
  assert_file_has ".managed_players.json" "Bob"

  # Zweiter Lauf mit unveränderter Konfiguration und aktualisierten Dateien: nichts zu tun
  printf '[{"uuid":"1","name":"Alice"},{"uuid":"5","name":"Bob"},{"uuid":"3","name":"Dave"}]' > "${DATA}/whitelist.json"
  printf '[]' > "${DATA}/ops.json"
  printf '[{"uuid":"6","name":"Griefer"}]' > "${DATA}/banned-players.json"
  run_lists_scenario 1
  assert_rc 0
  assert_out_lacks "Gleiche Spielerlisten ab"
}

t_spielerlisten_ungueltige_namen() {
  paper_sandbox "Spielerlisten: ungültige Namen werden nie an den Server geschickt"
  set_options '{"whitelist": ["bad name", "x;stop", "Valid_1", "a.b", "waytoolongplayername1"], "ops": ["op evil"]}'
  run_lists_scenario 1
  assert_rc 0
  assert_cmd "whitelist add Valid_1"
  assert_no_cmd "whitelist add bad name"
  assert_no_cmd "whitelist add x;stop"
  assert_no_cmd "whitelist add a.b"
  assert_no_cmd "op op evil"
  assert_out_has "Ungültiger Spielername in 'whitelist' ignoriert: bad name"
  assert_out_has "Ungültiger Spielername in 'ops' ignoriert: op evil"
}

t_spielerlisten_bedrock() {
  paper_sandbox "Spielerlisten: Bedrock-Namen (Punkt) nutzen fwhitelist"
  set_options '{"whitelist": [".Steve", "Alice"], "ops": [".Steve"], "banned_players": [".Troll"]}'
  run_lists_scenario 5
  assert_rc 0
  assert_cmd "fwhitelist add Steve"
  assert_cmd "whitelist add Alice"
  assert_cmd "op .Steve"
  assert_cmd "ban .Troll"
  assert_no_cmd "whitelist add .Steve"
}

t_spielerlisten_bedrock_aus() {
  paper_sandbox "Spielerlisten: Bedrock-Namen ohne Bedrock-Unterstützung werden übersprungen"
  set_options '{"bedrock_support": false, "whitelist": [".Steve", "Alice"]}'
  run_lists_scenario 1
  assert_rc 0
  assert_cmd "whitelist add Alice"
  assert_no_cmd "fwhitelist add Steve"
  assert_out_has "Bedrock-Spieler .Steve übersprungen"
}

t_spielerlisten_leer() {
  paper_sandbox "Spielerlisten: leere Listen erzeugen keine Befehle"
  run_lists_scenario 0
  assert_rc 0
  assert_out_lacks "Gleiche Spielerlisten ab"
  assert_no_cmd "whitelist add"
  assert_file_has "server.properties" "white-list=false"
}

t_cpu_prioritaet() {
  paper_sandbox "Leistung: cpu_priority setzt die nice-Stufe"
  run_addon
  assert_java_args "nice=0 "
  set_options '{"cpu_priority": "low"}'
  run_addon
  assert_rc 0
  assert_java_args "nice=10 "
  set_options '{"cpu_priority": "lowest"}'
  run_addon
  assert_java_args "nice=19 "
  set_options '{"cpu_priority": "bogus"}'
  run_addon
  assert_rc 0
  assert_out_has "Unbekannte CPU-Priorität 'bogus', nutze normal"
  assert_java_args "nice=0 "
}

t_cpu_kerne() {
  paper_sandbox "Leistung: cpu_cores beschränkt Kerne und Java-Threads"
  if (( $(nproc) < 2 )); then
    ok "übersprungen: weniger als 2 Kerne verfügbar"
    return
  fi
  set_options '{"cpu_cores": 1}'
  run_addon
  assert_rc 0
  assert_java_args "-XX:ActiveProcessorCount=1 "
  assert_java_args "cpus=1"

  set_options '{"cpu_cores": 999}'
  run_addon
  assert_rc 0
  assert_out_has "keine Einschränkung nötig"
  if grep -q "ActiveProcessorCount" "${MOCK_JAVA_LOG}"; then nok "ActiveProcessorCount unerwartet gesetzt"; else ok "ActiveProcessorCount nicht gesetzt"; fi

  set_options '{"cpu_cores": "abc"}'
  run_addon
  assert_rc 1
  assert_out_has "cpu_cores muss eine ganze Zahl sein"
}

t_ram_schutz() {
  paper_sandbox "Leistung: RAM-Schutz begrenzt xmx_mb"
  # 4 GB RAM: mindestens 1536 MB bleiben frei, also höchstens 2560 MB Heap
  printf 'MemTotal:        4194304 kB\n' > "${T}/meminfo"
  set_options '{"xms_mb": 1024, "xmx_mb": 4096}'
  run_addon
  assert_rc 0
  assert_out_has "xmx_mb (4096) ist zu hoch für 4096 MB RAM, begrenze auf 2560 MB"
  assert_java_args "-Xms1024M -Xmx2560M "

  set_options '{"xms_mb": 3000, "xmx_mb": 4000}'
  run_addon
  assert_java_args "-Xms2560M -Xmx2560M "

  # Passt der Wert, bleibt alles unverändert
  set_options '{"xms_mb": 512, "xmx_mb": 2000}'
  run_addon
  assert_out_lacks "ist zu hoch"
  assert_java_args "-Xms512M -Xmx2000M "

  # Mit großem RAM bleibt ein Viertel frei (16 GB: 12288 MB Heap)
  printf 'MemTotal:       16777216 kB\n' > "${T}/meminfo"
  set_options '{"xms_mb": 1024, "xmx_mb": 20000}'
  run_addon
  assert_java_args "-Xmx12288M "

  # Ausgeschaltet greift nichts
  set_options '{"xms_mb": 1024, "xmx_mb": 20000, "memory_guard": false}'
  run_addon
  assert_out_lacks "ist zu hoch"
  assert_java_args "-Xmx20000M "
}

t_ram_schutz_container_limit() {
  paper_sandbox "Leistung: RAM-Schutz beachtet ein Container-Limit"
  printf '%s\n' 2147483648 > "${T}/cgroup-limit"
  export CGROUP_MEM_FILE="${T}/cgroup-limit"
  set_options '{"xms_mb": 256, "xmx_mb": 1024}'
  run_addon
  assert_rc 0
  assert_out_has "ist zu hoch für 2048 MB RAM, begrenze auf 512 MB"
  assert_java_args "-Xms256M -Xmx512M "
  export CGROUP_MEM_FILE="${T}/no-cgroup-limit"
}

t_ram_schutz_ohne_meminfo() {
  paper_sandbox "Leistung: RAM-Schutz ohne lesbaren RAM-Wert überspringt sich"
  export MEMINFO_FILE="${T}/gibt-es-nicht"
  run_addon
  assert_rc 0
  assert_out_has "Gesamt-RAM nicht ermittelbar, RAM-Schutz übersprungen"
  assert_java_args "-Xmx1024M "
  export MEMINFO_FILE="${T}/meminfo"
}

t_fester_heap() {
  paper_sandbox "Leistung: fixed_heap setzt Xms gleich Xmx und belegt den Heap vorab"
  set_options '{"xms_mb": 256, "xmx_mb": 1024, "fixed_heap": true}'
  run_addon
  assert_rc 0
  assert_java_args "-Xms1024M -Xmx1024M "
  assert_java_args "-XX:+AlwaysPreTouch"
}

t_leistungsprofil() {
  paper_sandbox "Leistung: performance_profile setzt Sicht- und Simulationsweite"
  run_addon
  assert_rc 0
  if grep -qE "^(view|simulation)-distance=" "${DATA}/server.properties"; then nok "custom ändert die Weiten"; else ok "custom lässt server.properties unangetastet"; fi

  set_options '{"performance_profile": "low"}'
  run_addon
  assert_file_has "server.properties" "view-distance=6"
  assert_file_has "server.properties" "simulation-distance=4"
  assert_file_has "server.properties" "max-players=10"
  assert_out_has "Leistungsprofil low: view-distance=6, simulation-distance=4, max-players=10"

  set_options '{"performance_profile": "balanced"}'
  run_addon
  assert_file_has "server.properties" "view-distance=8"
  assert_file_has "server.properties" "simulation-distance=6"
  assert_file_has "server.properties" "max-players=20"

  set_options '{"performance_profile": "high"}'
  run_addon
  assert_file_has "server.properties" "view-distance=12"
  assert_file_has "server.properties" "simulation-distance=8"
  assert_file_has "server.properties" "max-players=40"

  # Zurück auf custom: der zuletzt gesetzte Wert bleibt stehen und wird nicht mehr verändert
  printf 'view-distance=14\nserver-port=25565\n' > "${DATA}/server.properties"
  set_options '{"performance_profile": "custom"}'
  run_addon
  assert_file_has "server.properties" "view-distance=14"

  set_options '{"performance_profile": "turbo"}'
  run_addon
  assert_rc 0
  assert_out_has "Unbekanntes Leistungsprofil 'turbo', nutze custom"
  assert_file_has "server.properties" "view-distance=14"
}

t_spielwelt_ueberschreibt_profil() {
  paper_sandbox "Spielwelt: eigene Werte überschreiben das Leistungsprofil"
  set_options '{"performance_profile": "balanced", "view_distance": 12, "max_players": 5, "entity_broadcast_range": 50}'
  run_addon
  assert_rc 0
  assert_file_has "server.properties" "view-distance=12"
  assert_file_has "server.properties" "simulation-distance=6"
  assert_file_has "server.properties" "max-players=5"
  assert_file_has "server.properties" "entity-broadcast-range-percentage=50"

  # Ungültige Werte werden ignoriert, das Profil bleibt
  set_options '{"performance_profile": "low", "view_distance": 1, "simulation_distance": 99}'
  run_addon
  assert_file_has "server.properties" "view-distance=6"
  assert_file_has "server.properties" "simulation-distance=4"
  assert_out_has "Ungültiger Wert für view_distance: '1'"
  assert_out_has "Ungültiger Wert für simulation_distance: '99'"
}

t_spielerlebnis() {
  paper_sandbox "Spielerlebnis: Schwierigkeit, Spielmodus und Schalter in server.properties"
  mkdir -p "${DATA}"
  printf 'difficulty=easy\npvp=true\nallow-nether=true\nlevel-name=meine welt\n' > "${DATA}/server.properties"
  set_options '{"difficulty": "hard", "gamemode": "creative", "force_gamemode": "true", "hardcore": "true", "allow_flight": "true", "command_blocks": "true", "spawn_protection": 0, "spawn_monsters": "false", "generate_structures": "false", "spawn_animals": "false", "spawn_npcs": "false"}'
  run_addon
  assert_rc 0
  assert_file_has "server.properties" "difficulty=hard"
  assert_file_has "server.properties" "gamemode=creative"
  assert_file_has "server.properties" "force-gamemode=true"
  assert_file_has "server.properties" "hardcore=true"
  assert_file_has "server.properties" "allow-flight=true"
  assert_file_has "server.properties" "enable-command-block=true"
  assert_file_has "server.properties" "spawn-protection=0"
  assert_file_has "server.properties" "spawn-monsters=false"
  assert_file_has "server.properties" "generate-structures=false"
  assert_file_has "server.properties" "spawn-animals=false"
  assert_file_has "server.properties" "spawn-npcs=false"
  # Nicht gesetzte Optionen ("default") lassen vorhandene Einträge unangetastet
  assert_file_has "server.properties" "pvp=true"
  assert_file_has "server.properties" "allow-nether=true"
  assert_file_has "server.properties" "level-name=meine welt"
  assert_file_lacks "server.properties" "difficulty=easy"
  # Genau ein Eintrag pro Schlüssel
  assert_eq "difficulty steht genau einmal in der Datei" "1" "$(grep -c '^difficulty=' "${DATA}/server.properties")"

  set_options '{"pvp": "false", "allow_nether": "false"}'
  run_addon
  assert_file_has "server.properties" "pvp=false"
  assert_file_has "server.properties" "allow-nether=false"
  assert_file_has "server.properties" "difficulty=hard"
}

t_spielerlebnis_ungueltig() {
  paper_sandbox "Spielerlebnis: ungültige Werte werden ignoriert"
  mkdir -p "${DATA}"
  printf 'difficulty=easy\nspawn-protection=16\n' > "${DATA}/server.properties"
  set_options '{"difficulty": "impossible", "gamemode": "god", "pvp": "maybe", "spawn_protection": 5000}'
  run_addon
  assert_rc 0
  assert_file_has "server.properties" "difficulty=easy"
  assert_file_has "server.properties" "spawn-protection=16"
  assert_out_has "Ungültiger Wert für difficulty: 'impossible'"
  assert_out_has "Ungültiger Wert für gamemode: 'god'"
  assert_out_has "Ungültiger Wert für pvp: 'maybe'"
  assert_out_has "Ungültiger Wert für spawn_protection: '5000'"
}

t_motd_und_seed() {
  paper_sandbox "Spielerlebnis: MOTD mit Sonderzeichen und Seed"
  set_options '{"motd": "Willkommen / bei A&B | Server", "level_seed": "-4172144997902289642"}'
  run_addon
  assert_rc 0
  assert_file_has "server.properties" "motd=Willkommen / bei A&B | Server"
  assert_file_has "server.properties" "level-seed=-4172144997902289642"

  set_options '{"motd": "mit \\u00a7 Backslash"}'
  run_addon
  assert_file_has "server.properties" "motd=Willkommen / bei A&B | Server"
  assert_out_has "Ungültiger Wert für motd"
}

t_spielregeln_neue_schreibweise() {
  paper_sandbox "Spielregeln: neue Namen (snake_case) und Umrechnung"
  set_options '{"game_rules": ["keepInventory=true", "random_tick_speed=3", "minecraft:doMobLoot=false", "bad rule", "x=maybe", "advance_time=false"]}'
  run_lists_scenario 4
  assert_rc 0
  assert_cmd "gamerule keep_inventory true"
  assert_cmd "gamerule random_tick_speed 3"
  assert_cmd "gamerule do_mob_loot false"
  assert_cmd "gamerule advance_time false"
  assert_no_cmd "gamerule keepInventory true"
  assert_out_has "Ungültige Spielregel ignoriert (erwartet name=wert): bad rule"
  assert_out_has "Ungültige Spielregel ignoriert (erwartet name=wert): x=maybe"
  assert_out_has "Setze 4 Spielregeln"
}

t_spielregeln_alte_schreibweise() {
  paper_sandbox "Spielregeln: alte Namen (camelCase) bis 1.21.10"
  set_options '{"mc_version": "1.21.10", "game_rules": ["keep_inventory=true", "randomTickSpeed=3"]}'
  run_lists_scenario 2
  assert_rc 0
  assert_cmd "gamerule keepInventory true"
  assert_cmd "gamerule randomTickSpeed 3"
  assert_no_cmd "gamerule keep_inventory true"
}

t_spielregeln_keine() {
  paper_sandbox "Spielregeln: ohne Einträge wird nichts gesendet"
  run_lists_scenario 0
  assert_rc 0
  assert_out_lacks "Spielregeln"
}

t_bedrock_chat() {
  paper_sandbox "Bedrock-Chat: enforce-secure-profile=false mit Bedrock-Unterstützung"
  mkdir -p "${DATA}"
  printf 'enforce-secure-profile=true\nlevel-name=world\n' > "${DATA}/server.properties"
  run_addon
  assert_rc 0
  assert_file_has "server.properties" "enforce-secure-profile=false"
  assert_file_has "server.properties" "level-name=world"
  assert_eq "genau ein Eintrag" "1" "$(grep -c '^enforce-secure-profile=' "${DATA}/server.properties")"
  assert_out_has "Bedrock-Chat erlaubt (enforce-secure-profile=false)"

  # Ausgeschaltet wird der Eintrag wieder auf true gesetzt
  set_options '{"bedrock_chat": false}'
  run_addon
  assert_file_has "server.properties" "enforce-secure-profile=true"
  assert_out_has "Bedrock-Chat gesperrt (enforce-secure-profile=true)"

  # Ohne Server-Eintrag wird er angelegt
  rm -f "${DATA}/server.properties"
  set_options '{}'
  run_addon
  assert_file_has "server.properties" "enforce-secure-profile=false"
}

t_bedrock_chat_ohne_bedrock() {
  paper_sandbox "Bedrock-Chat: ohne Bedrock-Unterstützung bleibt der Eintrag unangetastet"
  mkdir -p "${DATA}"
  printf 'enforce-secure-profile=true\n' > "${DATA}/server.properties"
  set_options '{"bedrock_support": false}'
  run_addon
  assert_rc 0
  assert_file_has "server.properties" "enforce-secure-profile=true"
  assert_out_lacks "Bedrock-Chat"
}

t_server_exitcode_wird_durchgereicht() {
  paper_sandbox "Abstürzender Server: Exit-Code wird durchgereicht"
  export MOCK_JAVA_EXIT_CODE=3
  run_addon
  assert_rc 3
  assert_out_has "Server wurde beendet (Exit-Code 3)"
  export MOCK_JAVA_EXIT_CODE=0
}

t_ungueltige_version() {
  paper_sandbox "Ungültige mc_version wird abgelehnt"
  set_options '{"mc_version": "1.21/../../x"}'
  run_addon
  assert_rc 1
  assert_out_has "Ungültige Minecraft-Version"
  assert_calls "keine Downloads" "." 0
}

for t in t_eula_fehlt t_xms_groesser_xmx t_normalstart t_rc_und_vorversionen_werden_uebersprungen \
         t_allow_experimental t_allow_experimental_beta t_release_vor_rc_bei_experimental \
         t_gepinnte_version_mit_eigener_java_version t_gepinnte_version_ohne_stable_build \
         t_java_major_option t_java_pruefsumme_falsch t_adoptium_api_nicht_erreichbar \
         t_java_metadaten_fehlen t_sigterm t_neustart_ohne_redownload \
         t_neuer_build_laedt_neu t_pruefsumme_falsch t_fill_api_nicht_erreichbar \
         t_plugin_download_scheitert t_plugin_download_liefert_keine_jar t_update_plugins_false \
         t_update_plugins_true t_bedrock_support_false t_plugin_urls \
         t_geyser_config_wird_einmalig_angelegt t_geyser_config_ohne_floodgate \
         t_geyser_config_bei_bedrock_support_false \
         t_spielerlisten_befehle t_spielerlisten_abgleich t_spielerlisten_ungueltige_namen \
         t_spielerlisten_bedrock t_spielerlisten_bedrock_aus t_spielerlisten_leer \
         t_server_exitcode_wird_durchgereicht t_ungueltige_version t_cpu_prioritaet t_cpu_kerne t_ram_schutz t_ram_schutz_container_limit t_ram_schutz_ohne_meminfo t_fester_heap t_leistungsprofil t_spielwelt_ueberschreibt_profil t_spielerlebnis t_spielerlebnis_ungueltig t_motd_und_seed t_spielregeln_neue_schreibweise t_spielregeln_alte_schreibweise t_spielregeln_keine t_bedrock_chat t_bedrock_chat_ohne_bedrock; do
  "${t}"
done

summary
