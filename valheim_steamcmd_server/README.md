<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/valheim_steamcmd_server/banner.png" alt="Valheim Dedicated Server" width="100%">
</p>

<h1 align="center">🛡️ Valheim Dedicated Server</h1>
<h3 align="center">Home Assistant Add-on (SteamCMD)</h3>

<p align="center">
  <img src="https://img.shields.io/badge/status-beta-orange.svg">
  <img src="https://img.shields.io/badge/arch-amd64-blue.svg">
  <img src="https://img.shields.io/badge/haos-supported-green.svg">
  <img src="https://img.shields.io/badge/steamcmd-required-lightgrey.svg">
</p>

---

## 📌 About

This Home Assistant add-on allows you to run a **Valheim Dedicated Server** directly on **Home Assistant OS (HAOS)** using **SteamCMD**.

The add-on is designed with the same philosophy as my other game server add-ons:
- **Simple**
- **Reliable**
- **Persistent**
- **No external dependencies**

All server data is stored safely inside `/share` so updates or rebuilds will never destroy your worlds.

---

## ✨ Features

- 🧰 Valheim Dedicated Server via **SteamCMD**
- 📦 Persistent storage in `/share`
- 🔐 Anonymous Steam login (no Steam account required)
- 🔁 Automatic updates on start (optional)
- 🌐 External port remapping via Home Assistant UI
- 🖥️ Fully headless (`-batchmode -nographics`)
- ♻️ Safe restarts without data loss
- 🧠 Optimized for container environments (HAOS)

---

## 📁 Data Structure

All relevant data is stored persistently:

/share/valheim/
├── server/ # Valheim server files (SteamCMD)
├── data/ # Worlds, saves, characters
└── home/ # Unity / Steam / PlayerPrefs (persistent)

yaml
Code kopieren

---

## 🌐 Network & Ports

Valheim requires **three consecutive UDP ports**.

### Internal container ports
2456/udp
2457/udp
2458/udp

csharp
Code kopieren

### External ports
You may freely remap the ports in the Home Assistant add-on configuration.

Example:
30056 → 2456
30057 → 2457
30058 → 2458

yaml
Code kopieren

⚠️ **Important:**  
Ports must always remain consecutive.

---

## ⚙️ Configuration

| Option | Description |
|------|------------|
| `server_name` | Name of your Valheim server |
| `world_name` | World save name |
| `password` | Server password (min. 5 characters, required by Valheim) |
| `public` | Show server in the public server list |
| `update_on_boot` | Update server files on every start |
| `validate` | Validate Steam files during update |
| `extra_args` | Additional Valheim startup arguments |

---

## 🚀 First Start

1. Install the add-on from your repository
2. Set a **password with at least 5 characters**
3. Start the add-on
4. SteamCMD will automatically download the server files
5. Join the server using your external IP and port

---

## 🔄 Updates

When `update_on_boot` is enabled:
- The server checks for updates on startup
- Automatically downloads the latest version
- Starts the server afterward

No manual updates required.

---

## 🧠 Technical Details

- Uses **SteamCMD** for server management
- Steam initialized via `steamclient.so`
- Unity PlayerPrefs redirected to `/share/valheim/home`
- Designed for **long-running servers**
- Compatible with rebuilds & supervisor restarts

---

## ❤️ Support & Donations

This add-on is developed and maintained in my free time.

If you enjoy using it and want to support my work:

👉 **Donate via PayPal:** http://paypal.me/cyclemat

Thank you very much for your support! 🙏

---

## 🐛 Issues & Feedback

If you encounter any issues:
- Check the add-on logs first
- Include relevant log output when reporting problems
- Suggestions and improvements are always welcome

---

⚔️ **Skål, Viking! Have fun conquering Valheim!**
