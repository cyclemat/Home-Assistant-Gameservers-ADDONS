<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/gmod_steamcmd_server/banner.png" alt="Garry's Mod Server Home Assistant Add-on" width="100%">
</p>

# 🎮 Garry's Mod Dedicated Server *Beta Please give feedBack
## Home Assistant Add-on

This add-on installs and runs a **Garry's Mod Dedicated Server** directly inside Home Assistant using SteamCMD.

The server can be fully managed via the add-on configuration and stores all data persistently in the Home Assistant `/share` directory.

---

## ✅ Features

- Automatic installation via SteamCMD
- Optional automatic updates on start
- Persistent server data
- Automatic or manual server.cfg handling
- Automatic restart on server crash
- Workshop collection support
- Configurable server parameters
- Home Assistant compatible logging

---

## 📁 Server Data

All server data remains intact across updates:

```
/share/gmod/server/
└── garrysmod/
    ├── addons
    ├── cfg
    ├── data
    ├── logs
    └── workshop
```

Server configuration file location:

```
/share/gmod/server/garrysmod/cfg/server.cfg
```

---

## ⚙️ Automatic server.cfg generation

Add-on option:

```
generate_server_cfg_on_start
```

| Value | Behavior |
|------|-----------|
| true | server.cfg is regenerated on every start |
| false | server.cfg remains unchanged and can be edited manually |

---

## 🔁 Automatic restart on crash

The server automatically restarts if it crashes.

Configurable via:

```
auto_restart_on_crash
restart_delay_seconds
```

---

## 🌐 Default Ports

| Port | Purpose |
|------|---------|
| UDP 27015 | Game / Query |
| UDP 27005 | Client |
| TCP 27016 | RCON |

Ports can be customized if needed.

---

## 📦 Workshop Support

Available options:

- `workshop_collection_id`
- `workshop_authkey`

These allow automatic addon downloads from the Steam Workshop.

---

## 🚀 Installation

1. Install the add-on in Home Assistant
2. Adjust configuration
3. Start the server

On first start, SteamCMD downloads the complete server files, which may take some time.

---

## 🛠️ Notes

- First startup may take several minutes.
- Large workshop collections increase startup time.
- Server data remains persistent between updates.

---

## 📦 Part of the Game Server Add-on Collection

This add-on is part of the Home Assistant game server add-on series.

Planned future improvements:
- Player count sensor
- Server status sensor
- Restart button in Home Assistant
- Backup functionality

---

Enjoy your Garry's Mod server! 🎉
