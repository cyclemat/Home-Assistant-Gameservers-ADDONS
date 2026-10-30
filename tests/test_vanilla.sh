#!/usr/bin/env bash
# Mock-Tests für minecraft_vanilla_server/run.sh
# Aufruf: tests/test_vanilla.sh (siehe tests/README.md)

# shellcheck source=tests/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRIPT="${REPO_DIR}/minecraft_vanilla_server/run.sh"

# Standard-Fixture: 26.3 (Java 25) ist latest, dazu ältere Versionen mit anderen Java-Anforderungen
vanilla_fixture() {
  mojang_reset
  mojang_add "26.3" 25
  mojang_add "1.21.1" 21
  mojang_add "1.20.4" 17
  mojang_add "1.12.2" none
  mojang_finish
}

t_eula_fehlt() {
  sandbox "EULA fehlt" "${SCRIPT}"
  vanilla_fixture
  set_options '{"accept_eula": false}'
  run_addon
  assert_rc 1
  assert_out_has "EULA"
  assert_calls "keine Downloads vor der Zustimmung" "." 0
  assert_no_file "server.jar"

  set_options '{"accept_eula": null}'
  run_addon
  assert_rc 1
  assert_out_has "accept_eula"
}

t_xms_groesser_xmx() {
  sandbox "Xms größer als Xmx" "${SCRIPT}"
  vanilla_fixture
  set_options '{"xms_mb": 4096, "xmx_mb": 1024}'
  run_addon
  assert_rc 1
  assert_out_has "darf nicht größer als xmx_mb"
  assert_calls "keine Downloads" "." 0
}

t_normalstart() {
  sandbox "Normalstart (latest, Java 25)" "${SCRIPT}"
  vanilla_fixture
  run_addon
  assert_rc 0
  assert_calls "Java 25 wird geladen (Issue 4: nicht mehr fest Java 21)" "adoptium.net/.*/latest/25/" 1
  assert_calls "Java 21 wird nicht geladen" "adoptium.net/.*/latest/21/" 0
  assert_file ".jre/25/bin/java"
  assert_out_has "Nutze neueste Minecraft-Version: 26.3"
  assert_out_has "Prüfsumme (SHA-1) ok"
  assert_file "server.jar"
  assert_file_has "server.jar" "SERVERJAR 26.3"
  assert_file_has "eula.txt" "eula=true"
  assert_file_has "server.properties" "server-port=25565"
  assert_java_args "major=25 args=-Xms512M -Xmx1024M -XX:+UseG1GC -jar server.jar nogui"
  assert_out_has "Java Version: openjdk version \"25.0.1\""
  assert_no_file "server.jar.tmp"
}

t_java_aus_mojang_metadaten() {
  local ver java
  for pair in "1.21.1:21" "1.20.4:17" "1.12.2:8"; do
    ver="${pair%%:*}"
    java="${pair##*:}"
    sandbox "Java-Ermittlung ${ver} -> Java ${java}" "${SCRIPT}"
    vanilla_fixture
    set_options "{\"mc_version\": \"${ver}\"}"
    run_addon
    assert_rc 0
    assert_calls "Java ${java} wird geladen" "adoptium.net/.*/latest/${java}/" 1
    assert_java_args "major=${java} "
    assert_file_has "server.jar" "SERVERJAR ${ver}"
  done
}

t_java_major_option() {
  sandbox "java_major überschreibt die Mojang-Angabe" "${SCRIPT}"
  vanilla_fixture
  set_options '{"java_major": 21}'
  run_addon
  assert_rc 0
  assert_calls "Java 21 wird geladen" "adoptium.net/.*/latest/21/" 1
  assert_calls "Java 25 wird nicht geladen" "adoptium.net/.*/latest/25/" 0
}

t_java_pruefsumme_falsch() {
  sandbox "Falsche Java-Prüfsumme: Abbruch, keine Installation" "${SCRIPT}"
  vanilla_fixture
  jre_break_checksum 25
  run_addon
  assert_rc 1
  assert_out_has "Prüfsumme des Java-Archivs stimmt nicht überein"
  assert_no_file ".jre/25"
  assert_no_file ".jre/25.tmp"
  assert_no_file "server.jar"
  assert_java_args_none
}

t_adoptium_api_nicht_erreichbar() {
  sandbox "Adoptium-API nicht erreichbar bricht ab" "${SCRIPT}"
  vanilla_fixture
  echo "api.adoptium.net/*" > "${MOCK_FAIL}"
  run_addon
  assert_rc 1
  assert_out_has "Adoptium-API nicht erreichbar"
  assert_no_file "server.jar"
}

t_alte_java_wird_aufgeraeumt() {
  sandbox "Alte Java-Version wird entfernt (Update von 0.0.2)" "${SCRIPT}"
  vanilla_fixture
  mkdir -p "${DATA}/.jre/21/bin"
  printf '#!/bin/sh\nexit 0\n' > "${DATA}/.jre/21/bin/java"
  chmod +x "${DATA}/.jre/21/bin/java"
  run_addon
  assert_rc 0
  assert_file ".jre/25/bin/java"
  assert_no_file ".jre/21"
}

t_sigterm() {
  sandbox "SIGTERM führt zu stop und Exit 0" "${SCRIPT}"
  vanilla_fixture
  scenario_sigterm
}

t_neustart_ohne_redownload() {
  sandbox "Neustart ohne Re-Downloads" "${SCRIPT}"
  vanilla_fixture
  run_addon
  assert_rc 0
  assert_calls "erster Lauf lädt Java (API und Archiv)" "adoptium" 2
  assert_calls "erster Lauf lädt das Server-JAR" "piston-data" 1
  run_addon
  assert_rc 0
  assert_calls "zweiter Lauf: kein Java-Download" "adoptium" 0
  assert_calls "zweiter Lauf: kein JAR-Download" "piston-data" 0
  assert_calls "zweiter Lauf: nur die Metadaten" "piston-meta" 2
  assert_out_lacks "Lade Server-JAR herunter"
}

t_neue_version_laedt_neu() {
  sandbox "Neue Mojang-Version ersetzt das JAR" "${SCRIPT}"
  vanilla_fixture
  run_addon
  assert_file_has "server.jar" "SERVERJAR 26.3"
  mojang_reset
  mojang_add "26.4" 25
  mojang_add "26.3" 25
  mojang_finish
  run_addon
  assert_rc 0
  assert_file_has "server.jar" "SERVERJAR 26.4"
  assert_calls "JAR wird neu geladen" "piston-data" 1
  assert_calls "Java bleibt erhalten" "adoptium" 0
}

t_pruefsumme_falsch() {
  sandbox "Falsche Prüfsumme: Abbruch, keine JAR" "${SCRIPT}"
  mojang_reset
  mojang_add "26.3" 25 badsha
  mojang_finish
  run_addon
  assert_rc 1
  assert_out_has "Prüfsumme des Server-JAR stimmt nicht überein"
  assert_no_file "server.jar"
  assert_no_file "server.jar.tmp"
  assert_no_file ".server_jar_url.txt"
  assert_java_args_none
}

assert_java_args_none() {
  if [[ -s "${MOCK_JAVA_LOG}" ]]; then nok "java wurde unerwartet gestartet"; else ok "java wurde nicht gestartet"; fi
}

t_unbekannte_version() {
  sandbox "Unbekannte Version bricht ab" "${SCRIPT}"
  vanilla_fixture
  set_options '{"mc_version": "9.9.9"}'
  run_addon
  assert_rc 1
  assert_out_has "Unbekannte Minecraft-Version"
  assert_no_file "server.jar"
}

t_manifest_nicht_erreichbar() {
  sandbox "Mojang nicht erreichbar bricht ab" "${SCRIPT}"
  vanilla_fixture
  echo "piston-meta.mojang.com/*" > "${MOCK_FAIL}"
  run_addon
  assert_rc 1
  assert_out_has "Mojang-Versionsmanifest nicht erreichbar"
}

t_eigene_jar_url() {
  sandbox "Eigene server_jar_url (ohne Prüfsumme, Java aus mc_version)" "${SCRIPT}"
  vanilla_fixture
  mkdir -p "${MOCK_WWW}/files.example.com"
  printf 'CUSTOMJAR' > "${MOCK_WWW}/files.example.com/custom.jar"
  set_options '{"server_jar_url": "https://files.example.com/custom.jar", "mc_version": "1.21.1"}'
  run_addon
  assert_rc 0
  assert_out_has "benutzerdefinierte Server-JAR URL"
  assert_out_has "Download ist nicht verifiziert"
  assert_file_has "server.jar" "CUSTOMJAR"
  assert_calls "Java 21 passend zu mc_version" "adoptium.net/.*/latest/21/" 1
}

t_eigene_jar_url_nur_https() {
  sandbox "server_jar_url mit http wird abgelehnt" "${SCRIPT}"
  vanilla_fixture
  set_options '{"server_jar_url": "http://files.example.com/custom.jar"}'
  run_addon
  assert_rc 1
  assert_out_has "server_jar_url muss mit https:// beginnen"
  assert_calls "keine Downloads" "." 0
}

vanilla_sandbox() {
  sandbox "$1" "${SCRIPT}"
  vanilla_fixture
}

t_spielerlisten_befehle() {
  vanilla_sandbox "Spielerlisten: Befehle an den Server und Whitelist-Schalter"
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
  vanilla_sandbox "Spielerlisten: nur Neues hinzufügen, nur Entferntes entfernen"
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
  vanilla_sandbox "Spielerlisten: ungültige Namen werden nie an den Server geschickt"
  set_options '{"whitelist": ["bad name", "x;stop", "Valid_1", "a.b", ".Steve", "waytoolongplayername1"], "ops": ["op evil"]}'
  run_lists_scenario 1
  assert_rc 0
  assert_cmd "whitelist add Valid_1"
  assert_no_cmd "whitelist add bad name"
  assert_no_cmd "whitelist add x;stop"
  assert_no_cmd "whitelist add a.b"
  assert_no_cmd "whitelist add .Steve"
  assert_no_cmd "fwhitelist add Steve"
  assert_no_cmd "op op evil"
  assert_out_has "Ungültiger Spielername in 'whitelist' ignoriert: bad name"
  assert_out_has "Ungültiger Spielername in 'ops' ignoriert: op evil"
}



t_spielerlisten_leer() {
  vanilla_sandbox "Spielerlisten: leere Listen erzeugen keine Befehle"
  run_lists_scenario 0
  assert_rc 0
  assert_out_lacks "Gleiche Spielerlisten ab"
  assert_no_cmd "whitelist add"
  assert_file_has "server.properties" "white-list=false"
}

t_cpu_prioritaet() {
  vanilla_sandbox "Leistung: cpu_priority setzt die nice-Stufe"
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
  vanilla_sandbox "Leistung: cpu_cores beschränkt Kerne und Java-Threads"
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
  vanilla_sandbox "Leistung: RAM-Schutz begrenzt xmx_mb"
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
  vanilla_sandbox "Leistung: RAM-Schutz beachtet ein Container-Limit"
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
  vanilla_sandbox "Leistung: RAM-Schutz ohne lesbaren RAM-Wert überspringt sich"
  export MEMINFO_FILE="${T}/gibt-es-nicht"
  run_addon
  assert_rc 0
  assert_out_has "Gesamt-RAM nicht ermittelbar, RAM-Schutz übersprungen"
  assert_java_args "-Xmx1024M "
  export MEMINFO_FILE="${T}/meminfo"
}

t_fester_heap() {
  vanilla_sandbox "Leistung: fixed_heap setzt Xms gleich Xmx und belegt den Heap vorab"
  set_options '{"xms_mb": 256, "xmx_mb": 1024, "fixed_heap": true}'
  run_addon
  assert_rc 0
  assert_java_args "-Xms1024M -Xmx1024M "
  assert_java_args "-XX:+AlwaysPreTouch"
}

t_leistungsprofil() {
  vanilla_sandbox "Leistung: performance_profile setzt Sicht- und Simulationsweite"
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
  vanilla_sandbox "Spielwelt: eigene Werte überschreiben das Leistungsprofil"
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
  vanilla_sandbox "Spielerlebnis: Schwierigkeit, Spielmodus und Schalter in server.properties"
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
  vanilla_sandbox "Spielerlebnis: ungültige Werte werden ignoriert"
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
  vanilla_sandbox "Spielerlebnis: MOTD mit Sonderzeichen und Seed"
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
  vanilla_sandbox "Spielregeln: neue Namen (snake_case) und Umrechnung"
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
  vanilla_sandbox "Spielregeln: alte Namen (camelCase) bis 1.21.10"
  set_options '{"mc_version": "1.21.1", "game_rules": ["keep_inventory=true", "randomTickSpeed=3"]}'
  run_lists_scenario 2
  assert_rc 0
  assert_cmd "gamerule keepInventory true"
  assert_cmd "gamerule randomTickSpeed 3"
  assert_no_cmd "gamerule keep_inventory true"
}

t_spielregeln_keine() {
  vanilla_sandbox "Spielregeln: ohne Einträge wird nichts gesendet"
  run_lists_scenario 0
  assert_rc 0
  assert_out_lacks "Spielregeln"
}

t_server_exitcode_wird_durchgereicht() {
  sandbox "Abstürzender Server: Exit-Code wird durchgereicht" "${SCRIPT}"
  vanilla_fixture
  export MOCK_JAVA_EXIT_CODE=3
  run_addon
  assert_rc 3
  assert_out_has "Server wurde beendet (Exit-Code 3)"
  export MOCK_JAVA_EXIT_CODE=0
}

for t in t_eula_fehlt t_xms_groesser_xmx t_normalstart t_java_aus_mojang_metadaten \
         t_java_major_option t_java_pruefsumme_falsch t_adoptium_api_nicht_erreichbar \
         t_alte_java_wird_aufgeraeumt t_sigterm \
         t_neustart_ohne_redownload t_neue_version_laedt_neu t_pruefsumme_falsch \
         t_unbekannte_version t_manifest_nicht_erreichbar t_eigene_jar_url \
         t_eigene_jar_url_nur_https t_server_exitcode_wird_durchgereicht \
         t_spielerlisten_befehle t_spielerlisten_abgleich t_spielerlisten_ungueltige_namen \
         t_spielerlisten_leer t_cpu_prioritaet t_cpu_kerne t_ram_schutz t_ram_schutz_container_limit t_ram_schutz_ohne_meminfo t_fester_heap t_leistungsprofil t_spielwelt_ueberschreibt_profil t_spielerlebnis t_spielerlebnis_ungueltig t_motd_und_seed t_spielregeln_neue_schreibweise t_spielregeln_alte_schreibweise t_spielregeln_keine; do
  "${t}"
done

summary
