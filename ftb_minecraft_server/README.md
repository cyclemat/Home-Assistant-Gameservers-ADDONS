p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/ftb_minecraft_server/banner.png" alt="FTB Minecraft Server Home Assistant Add-on" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Home%20Assistant-00bcd4.svg">
  <img src="https://img.shields.io/badge/Type-Add--on-yellow.svg">
  <img src="https://img.shields.io/badge/AMD64-Tested-yellow.svg">
  <img src="https://img.shields.io/badge/ARM64-Untested-red.svg">
  <img src="https://img.shields.io/badge/Status-Beta-orange.svg">
</p>

---

<h1>FTB Minecraft Dedicated Server (Installer)</h1>

This Home Assistant Add-on allows you to run **Feed The Beast (FTB) Minecraft Modpack Servers**
directly on **Home Assistant OS** using the **official FTB Server Installer**.

It is designed to be:

- reliable
- fully headless (no GUI required)
- configurable via the Home Assistant UI
- flexible with **multiple Java versions**

---

## ✨ Features

- Headless installation via **FTB Server Installer**
- Supports **any FTB Modpack** via Pack ID / Version ID
- **Selectable Java version** (8 / 17 / 21)
- Optional **automatic Java fallback** on version mismatch
- Configurable **RAM settings** (`Xms` / `Xmx`)
- Automatic **EULA acceptance**
- Persistent server data in `/share`
- Live Minecraft server output in Home Assistant logs
- Additional persistent server log file
- Clean separation between installer and runtime
- Runs fully inside **Home Assistant OS**
- No external server or launcher required

---

## 📂 Server Files Location

All server files are stored persistently in:

/share/ftb/<instance_name>/

makefile
Code kopieren

Example:
/share/ftb/ftb_one_test/

markdown
Code kopieren

You can freely edit:
- `server.properties`
- `ops.json`
- `whitelist.json`
- mods, configs, worlds, scripts

Java runtimes are cached in:
/share/ftb/.jre/

---

## 🔧 Installation

1. Open **Home Assistant**
2. Go to **Settings → Add-ons → Add-on Store**
3. Add this repository if not already added:

https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS

4. Install **FTB Minecraft Server**
5. Configure the add-on
6. Start the server

---

## ⚙️ Configuration Options

| Option | Description |
|-----|------------|
| `pack_id` | FTB Modpack ID |
| `version_id` | Modpack version ID (`0` = latest) |
| `instance_name` | Folder name under `/share/ftb` |
| `java_version` | Java version (`8`, `17`, `21`) |
| `java_fallback` | Automatically try other Java versions on failure |
| `xms_mb` | Minimum RAM (MB) |
| `xmx_mb` | Maximum RAM (MB) |
| `server_port` | Minecraft server port |
| `auto_accept_eula` | Automatically accept Mojang EULA |
| `force_reinstall` | Force reinstall on next start |

---

## ☕ Java Version Notes

| Minecraft / Modpack Type | Recommended Java |
|-------------------------|------------------|
| Very old packs (1.4–1.6) | Java 8 |
| Most modern packs (1.18–1.20) | Java 17 |
| Latest packs (1.20.5 / 1.21+) | Java 21 |

If **Java fallback** is enabled, the add-on will automatically try
other Java versions when common incompatibility errors are detected.

---

## 📜 Logs

- **Live output** is shown directly in the Home Assistant Add-on log
- Full persistent log is written to:

/share/ftb/<instance_name>/logs/ha_console.log


This makes debugging crashes or startup issues much easier.

---

## 🧪 Status

⚠️ **Status: Beta**

- Core functionality is working
- Actively developed and improved
- ARM64 is supported but **not yet fully tested**

Feedback, logs and suggestions are very welcome.

---

## ❤️ Support & Donations

This add-on is developed and maintained in my free time.

If you enjoy using it and want to support further development,
I would really appreciate a small donation via PayPal:

👉 **https://www.paypal.me/cyclemat**

Thank you for your support! 🙏

---

## 📄 License

This project is provided **as-is**, without warranty.

Minecraft is a trademark of Mojang Studios.  
Feed The Beast (FTB) is a trademark of Feed The Beast Ltd.


<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/assets/logo.png" width="200">
</p>


<hr>

<p align="center" style="margin-top: 16px;">
  <em style="font-size: 1.05em;">
    “Every block placed is a step into your own story.”
  </em>
  <br>
  <span style="opacity: 0.8; font-size: 0.95em;">
    — inspired by Minecraft
  </span>
</p>







