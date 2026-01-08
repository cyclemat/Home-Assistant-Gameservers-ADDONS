# 🦖 Palworld Dedicated Server (SteamCMD)

![Home Assistant OS](https://img.shields.io/badge/Home%20Assistant-OS-blue)
![Architecture](https://img.shields.io/badge/Architecture-amd64-blue)
![SteamCMD](https://img.shields.io/badge/SteamCMD-Enabled-orange)
![Status](https://img.shields.io/badge/Status-Beta-orange)

A Home Assistant OS add-on to run a fully host-based **Palworld Dedicated Server**
using **SteamCMD**.

---

## 🚀 Overview

This add-on runs a **Palworld Dedicated Server** directly on **Home Assistant OS**.

All data is stored entirely on the host under `/share`, including:

- SteamCMD
- Palworld server files
- Configuration
- Savegames

No additional server, virtual machine, or external host is required.

---

## ✨ Features

- Official Palworld Dedicated Server (Steam App ID `2394010`)
- Automatic updates via SteamCMD
- Persistent data storage under `/share`
- Runs directly on Home Assistant OS
- Easy installation via the Home Assistant Add-on Store

---

## 📦 Installation

1. Open **Home Assistant**
2. Go to **Settings → Add-ons → Add-on Store**
3. Add the following repository:
https://github.com/cyclemat/HAOS---Game-Servers

yaml
Code kopieren
4. Install **Palworld Dedicated Server**
5. Start the add-on

---

## 📁 Data Location

All server data is stored persistently under:

```text
/share/palworld/
├── server/      ← Palworld server files
├── config/      ← Configuration files
└── savegames/   ← World save data
You can access this directory from Windows via:

php-template
Code kopieren
\\<HOME_ASSISTANT_IP>\share\palworld\
🎮 Server Configuration
Server configuration is done via configuration files.

Main configuration file:

text
Code kopieren
/share/palworld/config/PalWorldSettings.ini
After editing the configuration file, restart the add-on for changes to take effect.

🌐 Network Ports
Port	Protocol	Description
8211	UDP	Game server
27015	UDP	Query port

Make sure these ports are forwarded on your router if you want external players to join.

⚙️ Add-on Options
Option	Description
update_on_start	Automatically update the server on add-on start

❤️ Support & Donations
This project is developed and maintained in my free time.

If you enjoy this add-on and find it useful,
I would really appreciate a small donation to support my work and ongoing development.

👉 Donate via PayPal http://paypal.me/cyclemat

Donations are completely optional – thank you very much!

🧑‍💻 Maintainer
Author: CyCleMat

GitHub: https://github.com/cyclemat

📜 Disclaimer
This add-on is not affiliated with or endorsed by Pocketpair or Palworld developers.
All trademarks and game content belong to their respective owners.
