# Changelog

## 0.0.4

### Added

- Whitelist, ban list and operator lists in the add-on configuration (`whitelist_enabled`, `whitelist`, `ops`, `banned_players`). They are synchronized with the server on every start.
- Performance options: `performance_profile`, `cpu_priority`, `cpu_cores`, `memory_guard` and `fixed_heap`.
- Free world options: `view_distance`, `simulation_distance`, `max_players` and `entity_broadcast_range`.
- Gameplay settings in `server.properties`: `difficulty`, `gamemode`, `force_gamemode`, `hardcore`, `pvp`, `allow_flight`, `allow_nether`, `spawn_monsters`, `spawn_animals`, `spawn_npcs`, `generate_structures`, `command_blocks`, `spawn_protection`, `motd` and `level_seed`.
- `game_rules` as `name=value` entries. Both the old camelCase and the new snake_case names (Minecraft 1.21.11 and newer) work.
- English and German translations of all options.

### Changed

- Java is always started with the G1 garbage collector.
- The Temurin download is verified against its SHA-256 checksum.
- The base image is pinned to `debian-base:9.5.1`. The unused `xz-utils` package is removed and `util-linux` is added.
- `server.properties` is edited without `sed`, so values containing a slash or an ampersand are written correctly.

## 0.0.3

### Fixed

- Java runtime mismatch on newer Minecraft versions (issue #4). The Java version is now read from Mojang's metadata (Java 8 for versions before 1.17) and installed automatically. The new option `java_major` forces a version.

### Changed

- **Breaking:** The Minecraft EULA is no longer accepted automatically. Enable the new option `accept_eula` once after updating, otherwise the add-on stops with a message in the log.
- The server JAR is verified against the SHA-1 from Mojang.
- The server receives `stop` on SIGTERM, so the world is saved when the add-on stops (`timeout` is 60 seconds).
- The RAM values, `mc_version` and `server_jar_url` (https only) are validated.
- `logs/ha_console.log` is gone. The server writes `logs/latest.log` itself.
