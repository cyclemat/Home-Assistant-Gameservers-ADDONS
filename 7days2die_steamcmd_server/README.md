<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/7days2die_steamcmd_server/banner.jpg"
       alt="7 Days to Die Dedicated Server for Home Assistant"
       width="80%">
</p>

<h1 align="center">7 Days to Die Dedicated Server (SteamCMD)</h1>

<p align="center">
  Run a fully automated <strong>7 Days to Die</strong> dedicated server directly inside <strong>Home Assistant OS</strong>.
  <br>
  Download, update, validate and run the server using <strong>SteamCMD</strong> – fully integrated as a Home Assistant Add-on.
</p>

---

## 🧟 About this Add-on

This Home Assistant Add-on allows you to host a **7 Days to Die Dedicated Server** directly on **HAOS** without the need for an external machine or VM.

The server is:
- installed via **SteamCMD**
- stored persistently in `/share/7days2die_dedicated`
- automatically updated on start (optional validation)
- fully configurable via Home Assistant UI
- logs integrated into the HA add-on log output

The add-on is designed to be **simple, stable and maintenance-free**.

---

## ✨ Features

- ✅ Automatic download & updates via SteamCMD  
- ✅ Optional Steam file validation  
- ✅ Persistent server files in `/share`  
- ✅ Configurable server settings via Home Assistant  
- ✅ Telnet, WebDashboard & EAC support  
- ✅ Server log (`server.log`) streamed into Home Assistant logs  
- ✅ Clean shutdown & automatic world saving  
- ✅ No external Docker or Linux knowledge required  

---

## 📦 Installation

1. Add my repository to Home Assistant:
https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS

2. Install **7 Days to Die Dedicated Server (SteamCMD)**

3. Start the add-on – the server will automatically download and install.

---

## 📁 Server Directory

All server files are stored in:

/share/7days2die_dedicated

This includes:
- game binaries
- `serverconfig.xml`
- savegames
- logs (`server.log`)
- mods

👉 You can freely edit files inside this directory.

---

## ⚙️ Configuration Options

These options are configurable via the Home Assistant add-on UI:

| Option | Description |
|------|------------|
| `ServerName` | Public server name |
| `ServerDescription` | Server description |
| `ServerPassword` | Optional password |
| `ServerMaxPlayerCount` | Maximum players |
| `GameName` | World / savegame name |
| `GameDifficulty` | Game difficulty |
| `TelnetEnabled` | Enable Telnet console |
| `WebDashboardEnabled` | Enable Web dashboard |
| `EACEnabled` | Enable Easy Anti-Cheat |
| `validate_on_boot` | Validate Steam files on startup |
| `stream_log` | Stream `server.log` into HA logs |

---

## 🌐 Network Ports

Ports are **fixed internally** and mapped via Home Assistant:

| Service | Port |
|------|------|
| Game Port | `26900/udp` |
| Steam Query | `26901/udp` |
| Steam Master | `26902/udp` |
| Telnet | `8081/tcp` |
| Web Dashboard | `8080/tcp` |

👉 Adjust external ports via **port mapping**, not inside the server.

---

## 🧾 Logs

- Main server log:
/share/7days2die_dedicated/server.log

- When `stream_log: true` is enabled, the server log is **mirrored into the Home Assistant add-on log output**.

---

## 💾 Savegames

- Savegames are created and managed automatically
- World data is stored under:
/root/.local/share/7DaysToDie/Saves
- The server performs **automatic saves**
- Clean shutdown ensures world integrity

No manual save configuration is required.

---

## 🛠️ Mods

Mods can be installed by placing them into:

/share/7days2die_dedicated/Mods

Restart the add-on after adding or removing mods.

---

## ❤️ Support & Donations

This add-on is developed and maintained in my free time.

If you like my work and want to support further development,  
I would really appreciate a small donation ❤️

👉 **PayPal:**  
**https://paypal.me/cyclemat**

---

## 📜 License

This project is provided as-is without warranty.  
7 Days to Die is a trademark of **The Fun Pimps**.

---
<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/assets/logo.png" width="200">
</p>

<p align="center">
  <strong>Have fun surviving the apocalypse! 🧟🔥</strong>
</p>
