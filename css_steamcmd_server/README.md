<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/css_steamcmd_server/banner.png" alt="Counter-Strike: Source Dedicated Server Add-on" width="100%">
</p>

<h1 align="center">Counter-Strike: Source Dedicated Server (SteamCMD)</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Home%20Assistant-Add--on-blue.svg">
  <img src="https://img.shields.io/badge/Architecture-amd64-blue.svg">
  <img src="https://img.shields.io/badge/SteamCMD-supported-brightgreen.svg">
  <img src="https://img.shields.io/badge/Game-Counter--Strike%3A%20Source-orange.svg">
</p>

---
This Home Assistant Add-on allows you to run a **Counter-Strike: Source Dedicated Server** directly on **Home Assistant OS** using **SteamCMD**.

It is designed to be:
- reliable
- self-contained
- configurable via the Home Assistant UI
- compatible with LAN and Internet servers (GSLT)

---

## ✨ Features

- SteamCMD-based installation and updates
- Fixed AppID (`232330`) and fixed server path
- Optional Steam update verification skip
- Optional debug mode (`-debug`)
- Automatic secure **RCON password generation** (if set to `CHANGE_ME`)
- Persistent RCON password storage
- Optional SourceTV support
- Auto-generated `server.cfg` and `autoexec.cfg`
- Full log output directly in the Home Assistant Add-on log
- Robust Steam runtime handling (CXXABI safe)
- Runs fully inside Home Assistant OS (no external server required)

---

## 📂 Server Files Location

All server files are stored in:

/share/css_server

You can freely edit configs, add maps, or install plugins there.

---

## 🔧 Installation

1. Open **Home Assistant**
2. Go to **Settings → Add-ons → Add-on Store**
3. Add this repository if not already added:
https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS

4. Install **Counter-Strike: Source Dedicated Server (SteamCMD)**
5. Configure the add-on
6. Start the server

---

## ⚙️ Configuration Options

| Option | Description |
|------|------------|
| `update_on_boot` | Update server via SteamCMD on start |
| `skip_steam_verify` | Skip SteamCMD file verification |
| `enable_debug` | Start server with `-debug` flag |
| `hostname` | Server hostname |
| `maxplayers` | Maximum player count |
| `map` | Start map name |
| `tickrate` | Server tickrate |
| `sv_lan` | LAN mode (1 = LAN only, 0 = Internet) |
| `gslt` | Steam Game Server Login Token |
| `rcon_password` | RCON password (`CHANGE_ME` = auto-generate) |
| `sv_password` | Server join password (optional) |
| `enable_sourcetv` | Enable SourceTV |
| `sourcetv_name` | SourceTV display name |

---

## 📺 SourceTV

If enabled, SourceTV will run on:

UDP 27020

You can connect using:
tv_connect <server_ip>

---

## 🔐 RCON Password Handling

If `rcon_password` is set to `CHANGE_ME`:

- A secure random password is generated automatically
- Stored persistently in:
/data/rcon_password.txt

- Reused on every restart

⚠️ The password is **not logged** for security reasons.

---

## 🧪 Debugging

Enable debug mode to generate additional diagnostics:

enable_debug: true
This enables the -debug flag and creates a debug.log in the server directory.

❤️ Support & Donations
This add-on is developed and maintained in my free time.

If you enjoy using it and want to support further development,
I would really appreciate a small donation via PayPal:

👉 https://www.paypal.me/cyclemat

Thank you for your support! 🙏

📄 License
This project is provided as-is, without warranty.
Counter-Strike: Source is a trademark of Valve Corporation.
