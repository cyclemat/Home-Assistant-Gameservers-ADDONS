# Changelog

## 0.0.2

### Added

- Optional ports for plugins, off by default: Dynmap 8123/tcp, BlueMap 8100/tcp, Plan 8804/tcp, Simple Voice Chat 24454/udp, RCON 25575/tcp and free slots 25580 to 25584 (tcp and udp). Set a host port in the **Network** section to open one.
- `bedrock_chat` (on by default): lets Bedrock players chat by setting `enforce-secure-profile=false`.
- Whitelist, ban list and operator lists (`whitelist_enabled`, `whitelist`, `ops`, `banned_players`). Bedrock players are written with a leading dot, for example `.Steve`.
- Performance options: `performance_profile`, `cpu_priority`, `cpu_cores`, `memory_guard` and `fixed_heap`.
- Free world options: `view_distance`, `simulation_distance`, `max_players` and `entity_broadcast_range`.
- Gameplay settings in `server.properties`: `difficulty`, `gamemode`, `force_gamemode`, `hardcore`, `pvp`, `allow_flight`, `allow_nether`, `spawn_monsters`, `spawn_animals`, `spawn_npcs`, `generate_structures`, `command_blocks`, `spawn_protection`, `motd` and `level_seed`.
- `game_rules` as `name=value` entries. Both the old camelCase and the new snake_case names (Minecraft 1.21.11 and newer) work.
- English and German translations of all options.

### Changed

- Java is always started with the G1 garbage collector.
- The Temurin download is verified against its SHA-256 checksum.
- The base image is pinned to `debian-base:9.5.1` and `util-linux` is added.
- `server.properties` is edited without `sed`, so values containing a slash or an ampersand are written correctly.

## 0.0.1

First release.

- Paper server with Geyser and Floodgate, so Java and Bedrock players can play together.
- The newest stable Paper build is resolved through the PaperMC downloads service and verified by its SHA-256 checksum. A specific version can be pinned.
- The Java version required by the Minecraft version is installed automatically (Temurin).
- Geyser and Floodgate are installed and refreshed on every start. Optional extra plugins via https links.
- A minimal Geyser configuration with Floodgate login and NetherNet transport is written once.
- Ports 25565/tcp, 19132/tcp and 19132/udp.
- The Minecraft EULA must be accepted explicitly (`accept_eula`). Clean shutdown that saves the world.
