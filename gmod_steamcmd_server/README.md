<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/gmod_steamcmd_server/banner.png" alt="Garry's Mod Server Home Assistant Add-on" width="100%">
</p>

<p align="center">
  <a href="https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS/tree/main/gmod_steamcmd_server">
    <img src="https://img.shields.io/badge/Home%20Assistant-Add--on-41BDF5?logo=home-assistant&logoColor=white" alt="Home Assistant Add-on">
  </a>
  <img src="https://img.shields.io/badge/arch-amd64%20%7C%20aarch64-informational" alt="Arch">
  <img src="https://img.shields.io/badge/SteamCMD-AppID%204020-success" alt="SteamCMD AppID 4020">
  <img src="https://img.shields.io/badge/status-beta-orange" alt="Status">
</p>

# 🎮 Garry's Mod Dedicated Server
## Home Assistant Add-on

This add-on installs and runs a **Garry's Mod Dedicated Server** inside Home Assistant using **SteamCMD**.

All server data is stored persistently under `/share`, so updates won't wipe your config, addons or workshop content.

---

## ✅ Features

- SteamCMD install & update (optional validate)
- Persistent server files in `/share/gmod`
- Optional `server.cfg` auto-generation (toggle)
- Manual config supported (toggle off)
- Auto restart on crash (+ configurable delay)
- Workshop collection support
- Configurable ports & start parameters
- Logs available in Home Assistant add-on log

---

## 📁 Persistent paths

```
/share/gmod/server/
└── garrysmod/
    ├── addons/
    ├── cfg/
    ├── data/
    ├── logs/
    └── workshop/
```

Main config:
```
/share/gmod/server/garrysmod/cfg/server.cfg
```

---

## ⚙️ server.cfg handling

Toggle:
- `generate_server_cfg_on_start`

| Value | Behavior |
|------|----------|
| `true`  | `server.cfg` is re-generated on every start |
| `false` | `server.cfg` is never touched (manual edits stay) |

---

## 🔁 Crash auto-restart

Options:
- `auto_restart_on_crash`
- `restart_delay_seconds`

If enabled, the add-on restarts the server after a crash automatically.

---

## 🌐 Default ports

| Port | Purpose |
|------|---------|
| UDP 27015 | Game / Query |
| UDP 27005 | Client |
| TCP 27016 | RCON |

---

## 📦 Workshop support

Options:
- `workshop_collection_id`
- `workshop_authkey`

---

## 🚀 Install

1. Copy this add-on into:
   ```
   /addons/local/gmod_steamcmd_server
   ```
2. Home Assistant → Add-ons → Add-on Store → Reload
3. Install & start

First start will download server files (may take a while).

---

## ❤️ Support

If you like this add-on and want to support development:

PayPal: https://paypal.me/cyclemat

---

<p align="center">
  <img src="YOUR_CM_LOGO_RAW_URL" alt="CycleMat" width="220">
</p>
