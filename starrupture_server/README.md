<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/blob/main/starrupture_server/banner.jpg" alt="Home Assistant Game Servers Add-ons" width="50%">
</p>


# 🌌 StarRupture Dedicated Server (SteamCMD + Wine)

![Home Assistant OS](https://img.shields.io/badge/Home%20Assistant-OS-blue)
![Architecture](https://img.shields.io/badge/Architecture-amd64-blue)
![SteamCMD](https://img.shields.io/badge/SteamCMD-Enabled-orange)
![Wine](https://img.shields.io/badge/Wine-Enabled-purple)
![Status](https://img.shields.io/badge/Status-Stable-success)

A Home Assistant OS add-on to run a fully host-based **StarRupture Dedicated Server**
using **SteamCMD + Wine**.

---

## 🚀 Overview

This add-on runs a **StarRupture Dedicated Server** directly on **Home Assistant OS**.

All data is stored entirely on the host under `/share`, including:

- StarRupture server files
- Savegames
- Server data

No additional server, VM or external host is required.

---

## ✨ Features

- Official StarRupture Dedicated Server (Steam App ID `3809400`)
- Automatic updates via SteamCMD
- Persistent data storage in `/share`
- Runs fully headless using Wine
- Easy installation via Home Assistant Add-on Store

---

## 📦 Installation

1. Open **Home Assistant**
2. Go to **Settings → Add-ons → Add-on Store**
3. Add the following repository:
https://github.com/cyclemat/HAOS---StarRupture-Dedicated-Server


4. Install **StarRupture Dedicated Server**
5. Start the add-on

---

## 📁 Data Location

All server data is stored persistently under:


/share/starrupture/
├── server/    ← Server files (SteamCMD)
└── savegame/  ← Savegames
You can access this directory from Windows via:

\\<HOME_ASSISTANT_IP>\share\starrupture\
🎮 Server Configuration
⚠️ Server configuration is done in-game only.

After starting the add-on:

Launch StarRupture

Open Multiplayer → Server Management

Claim your server as administrator

Configure server name, password, difficulty, etc.

There are currently no configuration files to edit manually.

🌐 Network Ports
Port	Protocol	Description
7777	UDP / TCP	Game server

Make sure the port is forwarded on your router if you want external players to join.

⚙️ Add-on Options
Option	Description
update_on_start	Automatically update the server on add-on start

❤️ Support & Donations
This project is developed and maintained in my free time.

If you enjoy this add-on and find it useful,
I would really appreciate a small donation to support my work and ongoing development.

👉 Donate via PayPal http://paypal.me/cyclemat

Donations are completely optional – thank you!

🧑‍💻 Maintainer
Author: CyCleMat
GitHub: https://github.com/cyclemat

📜 Disclaimer
This add-on is not affiliated with or endorsed by StarRupture or its developers.
All trademarks belong to their respective owners.


This project is developed and maintained in my free time.
If it helps you and you like my work, I would be very happy about a small donation via PayPal to support further development.
Paypal: CyCleMat@googlemail.com
