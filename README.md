<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/assets/banner.png" alt="Home Assistant Game Servers Add-ons" width="80%">
</p>

<h1 align="center">🎮 Home Assistant Game Servers Add-ons</h1>
<h3 align="center">Run your own game servers at home – simple, private & fully automated</h3>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Home%20Assistant-blue.svg" alt="Platform: Home Assistant">
  <img src="https://img.shields.io/badge/Architecture-amd64-blue.svg" alt="Architecture: amd64">
  <img src="https://img.shields.io/badge/Category-ADD--ON-yellow">
  <img src="https://img.shields.io/badge/Type-Dedicated%20Server-red">
  <img src="https://img.shields.io/badge/Status-Active%20Development-green.svg">
</p>

---

## 🚀 About This Repository

This repository provides **Home Assistant add-ons for running dedicated game servers** directly on **Home Assistant OS (HAOS)**.

The goal is simple:

> **Enable everyone to host private game servers at home – without complicated setups, cloud providers, or external infrastructure.**

All add-ons are designed to be:
- 🔹 Easy to install
- 🔹 Fully automated
- 🔹 Persistent (data stored in `/share`)
- 🔹 Safe to update & rebuild
- 🔹 Suitable for 24/7 home servers

---

## 🎯 Why Home Assistant?

Home Assistant already runs on many home servers and mini PCs.  
Why not use that power to also host **game servers**?

Benefits:
- 🏠 Everything runs **locally at home**
- 🔐 Full control over your data
- ♻️ Restart-safe & update-friendly
- ⚡ Integrated into your existing HA ecosystem

---

## 📦 Available Game Server Add-ons

Each game server is provided as its own Home Assistant add-on with:
- SteamCMD integration (Steam based servers) or automatic Java and server downloads (Minecraft)
- Persistent data storage
- Automatic updates (optional)
- Clean startup & shutdown handling

| Add-on | Folder | Notes |
|---|---|---|
| 🛡️ Valheim Dedicated Server | [`valheim_steamcmd_server`](valheim_steamcmd_server) | SteamCMD |
| 🧟 Palworld Dedicated Server | [`palworld_steamcmd_server`](palworld_steamcmd_server) | SteamCMD |
| 🚀 StarRupture Dedicated Server | [`starrupture_server`](starrupture_server) | SteamCMD + Wine |
| 🌾 7 Days to Die Dedicated Server | [`7days2die_steamcmd_server`](7days2die_steamcmd_server) | SteamCMD |
| 🔫 Counter-Strike: Source Dedicated Server | [`css_steamcmd_server`](css_steamcmd_server) | SteamCMD |
| 🔧 Garry's Mod Dedicated Server | [`gmod_steamcmd_server`](gmod_steamcmd_server) | SteamCMD |
| ⛏️ Minecraft Vanilla Dedicated Server | [`minecraft_vanilla_server`](minecraft_vanilla_server) | Official Mojang server, the Java version follows the Minecraft version |
| 🧱 Minecraft Paper + Geyser (Java & Bedrock) | [`minecraft_paper_geyser_server`](minecraft_paper_geyser_server) | Paper with Geyser and Floodgate, Java and Bedrock players on one server |
| 📦 FTB Minecraft Server | [`ftb_minecraft_server`](ftb_minecraft_server) | Modpacks via the FTB installer |

*(more coming)*

> The Minecraft Vanilla and Paper + Geyser add-ons require you to accept the [Minecraft EULA](https://aka.ms/MinecraftEULA)
> in the add-on configuration (`accept_eula`) before the server starts.

---

## 🧩 One-Click Installation (Home Assistant)

You can add this repository directly to your **Home Assistant Add-on Store**:

### 👉 Add Repository
https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS


In Home Assistant:
1. Go to **Settings → Add-ons → Add-on Store**
2. Click **⋮ → Repositories**
3. Paste the URL above
4. Install your desired game server add-on

---

## ⚠️ Disclaimer

This project is a **community-driven, private hobby project**.

- I am **not affiliated with any game developer or publisher**
- All game names, trademarks, and copyrights belong to their respective owners
- These add-ons only provide **dedicated server wrappers**
- You must own the respective games and follow their license terms

---

## ❤️ Support & Donations

All add-ons are **free to use**.

If you enjoy this project and want to support further development, you are welcome to leave a small donation — **completely optional**:

👉 **Donate via PayPal:** http://paypal.me/cyclemat

No pressure, no ads, no paywalls.  
Just open-source and passion ❤️

---

## 🛠️ Feedback & Contributions

- Issues and suggestions are welcome
- Feel free to open pull requests
- New game server ideas are always appreciated

---

<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/assets/logo.png" width="200">
</p>

<p align="center">
  <strong>Host your worlds. Your server. Your rules.</strong>
</p>
