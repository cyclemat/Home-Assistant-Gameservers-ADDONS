<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/club_penguin_houdini/bannercp.png" alt="Club Penguin Houdini – Home Assistant OS Add-on" width="100%">
</p>

<h1 align="center">🐧 Club Penguin Houdini Server</h1>
<h3 align="center">Home Assistant OS Add-on · Experimental Beta</h3>

<p align="center">
  <img src="https://img.shields.io/badge/status-experimental%20beta-orange.svg" alt="Status: Experimental Beta">
  <img src="https://img.shields.io/badge/arch-amd64-blue.svg" alt="Architecture: amd64">
  <img src="https://img.shields.io/badge/platform-HAOS-41BDF5.svg" alt="Platform: Home Assistant OS">
  <img src="https://img.shields.io/badge/server-Houdini-yellow.svg" alt="Server: Houdini">
  <img src="https://img.shields.io/badge/client-not%20included-red.svg" alt="Client not included">
</p>

<p align="center">
  <a href="README.de.md">🇩🇪 Deutsch</a> · <strong>🇬🇧 English</strong>
</p>

---

## 📌 About

This Home Assistant add-on packages the open-source **Houdini** server for the classic **Club Penguin** multiplayer game. Run a login server, one game world and their local database services directly on **Home Assistant OS (HAOS)**.

The goal matches the other [CycleMat Game Server Add-ons](https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS):

- 🏠 Self-hosted on your own hardware
- 📦 Managed from the Home Assistant add-on interface
- 💾 Persistent service data
- 🔧 A starting point for a complete private server setup

> [!WARNING]
> **Experimental server-only beta:** This add-on has not been validated by a complete HAOS build and gameplay test. It does **not** include a playable game client, Flash/game assets, Dash, account registration, or the complete Wand stack. Installing it alone is **not sufficient to play Club Penguin**.

---

## ✨ Features

- 🐧 Houdini login server
- 🌍 One configurable world (`blizzard` by default)
- 🐘 PostgreSQL database inside the container
- ⚡ Redis inside the container
- 🗄️ Persistent add-on data storage under `/data`
- 🌐 Home Assistant port mapping for the login and world servers
- 🖥️ Headless operation and logs in Home Assistant

---

## 📦 Included Services

| Component | Purpose | Availability |
|---|---|---|
| Houdini Login | Account login protocol | Included |
| Houdini World | Game-world server | Included (`blizzard` default) |
| PostgreSQL | Database | Internal only |
| Redis | Cache / messaging | Internal only |
| Dash and registration | Web services | Not included |
| Game client and assets | Player access | Not included |
| Full Wand deployment | Additional services | Not included |

---

## 📁 Data Structure

The add-on uses Home Assistant's persistent add-on data volume (mounted as `/data` inside the container), **not** the `/share` directory used by some other CycleMat game servers.

```text
Home Assistant add-on data (/data)
├── PostgreSQL data
├── Redis data
└── Other persistent runtime files, where configured
```

> [!IMPORTANT]
> Back up the add-on data before upgrading, removing or rebuilding the add-on. Persistent storage does not replace a backup.

---

## 🌐 Network & Ports

| Port | Protocol | Purpose |
|---|---|---|
| `6112` | TCP | Houdini login server |
| `9875` | TCP | Houdini game world |

Ports can be mapped to alternative host ports in the Home Assistant add-on's **Network** tab. PostgreSQL and Redis are intended to be reachable only inside the container.

⚠️ **Security:** These game ports are not protected by TLS by default. Do not publicly forward them without evaluating the security risks. Prefer a trusted local network or VPN for testing.

---

## ⚙️ Configuration

The current `config.yaml` provides:

| Option | Default | Description |
|---|---|---|
| `world_name` | `blizzard` | Name of the game world |
| `world_id` | `3100` | Numerical world identifier (1–9999) |
| `log_level` | `INFO` | `DEBUG`, `INFO`, `WARNING` or `ERROR` |

These are the current settings. Account registration, client download and web hosting are **not** configurable because those services are not included.

---

## 🚀 Installation & First Start

### Install from the CycleMat repository

1. Open **Settings → Add-ons → Add-on Store** in Home Assistant.
2. Select **⋮ → Repositories** and add:

   `https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS`

3. Find **Club Penguin Houdini (Experimental)** and select **Install**.
4. Review the **Configuration** and **Network** tabs.
5. Start the add-on and inspect its **Logs**.

The initial build requires internet access to retrieve upstream sources and dependencies. Because this is a legacy server stack, build or start-up errors are possible.

### Local installation alternative

Copy the `club_penguin_houdini` directory into `/addons/club_penguin_houdini`, reload the Add-on Store, then install it from **Local add-ons**.

---

## 🧠 Technical Details

- Based on [solero/houdini](https://github.com/solero/houdini)
- [solero/wand](https://github.com/solero/wand) is the upstream Docker-oriented ecosystem, **not** fully bundled in this add-on
- PostgreSQL and Redis are run together with Houdini inside one add-on container
- Current add-on architecture: `amd64`
- Docker build fetches upstream project dependencies
- Dedicated Docker Compose or host Docker socket access is not required

---

## 🔄 Updates & Project Status

This is a **development build**, not an automatically verified stable release. Do not assume that rebuilding or installing the newest dependencies will work without adjustments. Take a Home Assistant backup before updates.

### Planned improvements

- ✅ Initial HAOS add-on structure
- ⬜ Verified HAOS build and startup
- ⬜ More reliable dependency pinning and health checks
- ⬜ Account creation and management
- ⬜ Compatible client and asset setup instructions
- ⬜ Optional Dash/web frontend integration
- ⬜ Multi-world support

---

## ⚠️ Disclaimer

This is an unofficial community hobby project. It is not affiliated with or endorsed by Disney, Club Penguin, the Houdini maintainers or the Wand maintainers. Game names and assets belong to their respective rights holders. **No proprietary game client or assets are distributed with this add-on.** Use only software and game assets you are legally permitted to use.

---

## ❤️ Support & Donations

This add-on is developed and maintained in my free time. All CycleMat game-server add-ons are free to use.

If you enjoy the project and would like to support development:

👉 **Donate via PayPal:** http://paypal.me/cyclemat

Thank you for your support! ❤️

---

## 🐛 Issues & Feedback

Report bugs, logs and suggestions here:

👉 [GitHub Issues](https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS/issues)

When reporting a problem, include the HAOS version, add-on version and relevant start-up logs (without passwords or other secrets).

---

<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/assets/logo.png" alt="CycleMat" width="200">
</p>

<p align="center"><strong>Host your worlds. Your server. Your rules. 🐧</strong></p>
