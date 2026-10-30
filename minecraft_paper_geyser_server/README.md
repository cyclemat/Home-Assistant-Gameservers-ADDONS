<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/minecraft_paper_geyser_server/banner.png" alt="Minecraft Paper + Geyser Home Assistant Add-on" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Home%20Assistant-00bcd4.svg">
  <img src="https://img.shields.io/badge/Type-Add--on-yellow.svg">
  <img src="https://img.shields.io/badge/AMD64-Tested-yellow.svg">
  <img src="https://img.shields.io/badge/ARM64-Emulation%20tested-yellow.svg">
  <img src="https://img.shields.io/badge/Status-Beta-orange.svg">
</p>

---

# Minecraft Paper + Geyser (Java & Bedrock)

A Home Assistant add-on that runs a **Paper** Minecraft server together with
**Geyser** and **Floodgate**, so **Java Edition and Bedrock Edition players can play on the same server**.
Bedrock players (phone, console, Windows) do not need a Java account.

## Features

- Newest **stable** Paper build, resolved automatically through the official PaperMC downloads service (Fill v3)
- Paper download is verified by its SHA-256 checksum
- The Java version required by the selected Minecraft version is installed automatically (Temurin, checksum verified)
- Geyser and Floodgate are installed and refreshed on every start
- Optional extra plugins via direct `https` links
- EULA must be accepted explicitly (`accept_eula`)
- Clean shutdown: the world is saved when the add-on stops
- All data is stored in `/share/minecraft-paper`

## Ports

Only the ports that are actually needed are published. The host ports can be changed in the add-on network settings.

| Edition | Port | Protocol |
|---|---|---|
| Java | 25565 | TCP |
| Bedrock (Geyser) | 19132 | **TCP and UDP** |

Bedrock clients from version 26.60 on (planned for October 27th, 2026) only connect through
**NetherNet**. Geyser then needs a TCP port for the connection setup (signaling) in addition to the
UDP port for the game, both are 19132 by default. The add-on enables NetherNet for you and publishes
both. A UDP-only forward is not enough anymore.

The add-on does not use host networking and does not open anything else (see "Ports for plugins" for optional extra ports).
If you want to play from outside your home network, forward exactly these ports on your router
(19132 for TCP and UDP, 25565 for TCP). Do not forward other ports.
For an internet-facing server, enable the Minecraft whitelist (`white-list=true` in `server.properties`).

## Ports for plugins

Home Assistant cannot open ports through an add-on option. A port has to be declared in the add-on, and you choose
the host port in the **Network** section of the add-on configuration. This add-on already declares extra ports that are
**off by default**. To open one, enter a host port next to it (for example the same number) and restart the add-on.
Nothing is published until you do that.

| Container port | Meant for |
|---|---|
| 8123/tcp | Dynmap web map |
| 8100/tcp | BlueMap web map |
| 8804/tcp | Plan analytics |
| 24454/udp | Simple Voice Chat |
| 25575/tcp | RCON remote console (only open it with a strong `rcon.password`) |
| 25580 to 25584, tcp and udp | Free slots for any other plugin |

The plugin has to listen on exactly that **container** port, so set it in the plugin's own configuration (Dynmap
already uses 8123, BlueMap 8100, Plan 8804, Simple Voice Chat 24454). For a plugin that needs another port, change the
plugin's port to one of the free slots 25580 to 25584. If you want to reach it from outside your home network, the host
port also has to be forwarded on your router. A plugin with a port that is not in the table needs an entry in the add-on's
`config.yaml`, because ports cannot be added at runtime.

## Connecting

- **Java:** server address, default port 25565
- **Bedrock:** Servers, Add Server, server address, port 19132. Servers in a Home Assistant add-on are not
  announced on the LAN, so the server has to be added manually. When you join by IP address, Bedrock shows
  a one-time "trust on first use" prompt. Confirm it. It disappears if you serve the signaling over HTTPS,
  see the [Geyser documentation](https://geysermc.org/wiki/geyser/).

## Bedrock chat

Bedrock does not support Java's chat signing. If the server requires it (`enforce-secure-profile=true`, the default),
Bedrock players can read the chat but cannot write. With `bedrock_chat` on (the default) and Bedrock support enabled, the
add-on sets `enforce-secure-profile=false` on every start. With `bedrock_chat` off it sets `true` again. The option has no
effect without Bedrock support. The trade-off: with the signing requirement off, Java players can join without a signed
chat key too.

## Geyser configuration

On the first start the add-on creates a minimal `plugins/Geyser-Spigot/config.yml` with two settings:

- `java.auth-type: floodgate`, so Bedrock players can join without a Java account
- `bedrock.transport: nethernet`, see above

Geyser fills in all other options with its defaults. The file is never overwritten afterwards, so you can edit it
freely (for example `transport: both` with a separate `webrtc-port` while some players still use an older Bedrock
version). If Floodgate could not be downloaded, the file is not created and Geyser uses its own defaults.

## Configuration

| Option | Description |
|---|---|
| `accept_eula` | Must be `true` to start. By enabling it you agree to the [Minecraft EULA](https://aka.ms/MinecraftEULA) |
| `mc_version` | `latest` (newest version that has a stable Paper build) or a specific version, e.g. `1.21.11` |
| `allow_experimental` | Also accept beta/alpha Paper builds and pre-releases. PaperMC gives no support for them |
| `bedrock_support` | Install Geyser and Floodgate |
| `bedrock_chat` | On by default. Lets Bedrock players chat by setting `enforce-secure-profile=false`. Turn it off to set it to `true` again |
| `update_plugins` | Refresh Geyser and Floodgate on every start. If `false`, existing jars are kept |
| `plugin_urls` | Additional plugins as direct `https://...jar` links. Other schemes are ignored |
| `java_major` | Optional. Forces a Java version. By default it is read from Paper's version metadata |
| `xms_mb` / `xmx_mb` | Minimum / maximum RAM in MB (`xms_mb` must not exceed `xmx_mb`) |
| `whitelist_enabled` | Only whitelisted players can join |
| `whitelist` | Player names on the whitelist (Bedrock players with a leading dot) |
| `ops` | Player names with operator rights |
| `banned_players` | Player names on the ban list |
| `performance_profile` | `custom`, `low`, `balanced` or `high` (view and simulation distance, max players) |
| `cpu_priority` | `normal`, `low` or `lowest` |
| `cpu_cores` | Number of CPU cores, `0` = all |
| `memory_guard` | Limit `xmx_mb` so RAM stays free for the system |
| `fixed_heap` | `xms_mb` = `xmx_mb`, claim the memory at startup |
| `view_distance`, `simulation_distance`, `max_players`, `entity_broadcast_range` | Free world performance settings, 0 = unchanged |
| `difficulty`, `gamemode`, `pvp`, `allow_flight`, ... | Gameplay settings, `default` = unchanged (see below) |
| `motd`, `level_seed`, `spawn_protection` | Server message, seed for a new world, spawn protection radius |
| `game_rules` | Game rules as `name=value` |

## Whitelist, ban list and operators

The three lists can be edited in the add-on configuration (**Whitelist**, **Banned players**, **Operators**).
Add one player name per entry. The whitelist is only enforced while **Enable the whitelist** is on.

On every start the add-on compares the lists with the server and sends the matching console commands
(`whitelist add`, `ban`, `op` and their counterparts) once the server is ready. The server looks up the UUIDs itself,
so Java names must belong to real Minecraft accounts.

- Only entries from the configuration are managed. Players you add in game stay.
- An entry that you delete from the configuration is removed from the server on the next start.
- Changes in the configuration take effect on the next start of the add-on.
- **Bedrock players** start with a dot, for example `.Steve` (Floodgate prefix, no spaces, use `_` instead).
  On the whitelist this uses Floodgate's `fwhitelist`. It looks the gamertag up in Geyser's cache, which does not know
  every player. If it does not find a player, enter the XUID instead of the gamertag (`.2535400000000000`).
  Operators and bans for Bedrock players only work after the player has joined once, because the server
  has to know the player first.

## Performance and resource limits

Home Assistant cannot set CPU or memory limits per add-on, so the add-on applies them itself:

| Option | What it does |
|---|---|
| `performance_profile` | `custom` leaves `server.properties` alone. `low` (view distance 6, simulation distance 4, 10 players), `balanced` (8, 6, 20) and `high` (12, 8, 40) set `view-distance`, `simulation-distance` and `max-players` on every start. The simulation distance has the biggest effect on CPU load. |
| `cpu_priority` | `normal`, `low` (nice 10) or `lowest` (nice 19). With a lower priority the server gives way to Home Assistant when the CPU is busy. |
| `cpu_cores` | Number of CPU cores the server may use, `0` means all. The server runs on the last cores, so the first ones stay free for the system and Home Assistant. Java adjusts its GC and JIT threads to the core count. |
| `memory_guard` | Limits `xmx_mb` automatically so that at least a quarter of the system RAM (and at least 1536 MB) stays free. A container memory limit is taken into account. Without it Linux ends the add-on first when memory runs out. |
| `fixed_heap` | Sets `xms_mb` equal to `xmx_mb` and claims the memory at startup. This avoids heap resizing while running, as Paper recommends. Starting takes a little longer. |

The add-on always starts Java with the G1 garbage collector. Without it Java silently falls back to the slow
SerialGC on machines with fewer than 2 CPUs or less than 1.75 GB RAM.

## World and gameplay settings

These options change the matching entries in `server.properties` on every start. They only touch an entry when you
set it: `default` (or `0` / `-1` for numbers and an empty text) leaves the current value alone, so your own edits
in `server.properties` stay.

| Option | Values | Notes |
|---|---|---|
| `view_distance`, `simulation_distance` | 0, or 2 to 32 | Override the performance profile when set |
| `max_players` | 0, or 1 and up | Overrides the performance profile when set |
| `entity_broadcast_range` | 0, or 10 to 500 (%) | Lower values save CPU and bandwidth |
| `difficulty` | `default`, `peaceful`, `easy`, `normal`, `hard` | |
| `gamemode`, `force_gamemode` | `survival`, `creative`, `adventure`, `spectator` / `true`, `false` | The game mode applies to players who join for the first time, with `force_gamemode` to everyone |
| `hardcore` | `true`, `false` | Only for a newly created world |
| `pvp`, `allow_flight`, `allow_nether`, `command_blocks` | `true`, `false` | |
| `spawn_monsters`, `spawn_animals`, `spawn_npcs` | `true`, `false` | |
| `generate_structures` | `true`, `false` | Only for newly generated chunks |
| `spawn_protection` | -1, or 0 to 1000 (blocks) | |
| `motd` | text | Shown in the server list, no line breaks or backslashes |
| `level_seed` | text | Only used when a new world is created |
| `game_rules` | list of `name=value` | See below |

**Game rules.** Add one entry per rule, for example `keep_inventory=true` or `random_tick_speed=3`. The rules are set on
every start once the server is ready. Since Minecraft 1.21.11 the rules are written in snake_case (`keep_inventory`),
before that in camelCase (`keepInventory`). Either spelling works: the add-on converts it to the one your server version
uses. Rules that were renamed beyond the spelling (for example `doDaylightCycle`, now `advance_time`) need the new name.
Game rules are stored in the world, so deleting an entry does not reset the rule. Set it to the value you want instead.

## Notes

- With `mc_version: latest` the server moves to the newest stable version on a restart.
  Back up your world first, downgrades can corrupt worlds. PaperMC itself advises against
  auto-updaters in production, so pin a version for a server you care about.
- Geyser can need a few days to support a brand-new Minecraft or Bedrock version. If Bedrock players
  cannot join after an update, pin `mc_version` to the previous version.
- Setting `bedrock_support` to `false` does not remove Geyser and Floodgate. Delete their jars from
  `/share/minecraft-paper/plugins` if you no longer want them.
- Server logs are written to `/share/minecraft-paper/logs/latest.log`.

## Architecture & Status

- **amd64**: tested on Home Assistant OS: start with Java 25, a Java player and a Bedrock player (connect and chat),
  and a clean shutdown that saves the world
- **arm64**: built and started under emulation (Java 25 for aarch64, Paper, Geyser, clean shutdown), but not yet run
  on real hardware such as a Raspberry Pi

Feedback and test reports are very welcome.
