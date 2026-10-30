<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/club_penguin_houdini/bannercp.png" alt="Club Penguin Houdini – Home Assistant OS Add-on" width="100%">
</p>

<h1 align="center">🐧 Club Penguin Houdini Server</h1>
<h3 align="center">Home Assistant OS Add-on · Experimentelle Beta</h3>

<p align="center">
  <img src="https://img.shields.io/badge/status-experimental%20beta-orange.svg" alt="Status: Experimentelle Beta">
  <img src="https://img.shields.io/badge/arch-amd64-blue.svg" alt="Architektur: amd64">
  <img src="https://img.shields.io/badge/platform-HAOS-41BDF5.svg" alt="Plattform: Home Assistant OS">
  <img src="https://img.shields.io/badge/server-Houdini-yellow.svg" alt="Server: Houdini">
  <img src="https://img.shields.io/badge/client-not%20included-red.svg" alt="Client nicht enthalten">
</p>

<p align="center">
  <strong>🇩🇪 Deutsch</strong> · <a href="README.md">🇬🇧 English</a>
</p>

---

## 📌 Über das Add-on

Dieses Home-Assistant-Add-on stellt den Open-Source-Server **Houdini** für das klassische Multiplayer-Spiel **Club Penguin** bereit. Ein Loginserver, eine Spielwelt und die benötigten internen Datenbankdienste laufen direkt auf **Home Assistant OS (HAOS)**.

Wie bei den anderen [CycleMat Gameserver-Add-ons](https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS) stehen folgende Ziele im Vordergrund:

- 🏠 Selbst gehostet auf eigener Hardware
- 📦 Verwaltung über Home Assistant
- 💾 Persistente Speicherung der Serverdaten
- 🔧 Grundlage für einen privaten Gameserver

> [!WARNING]
> **Experimentelle Server-Beta:** Ein vollständiger HAOS-Build und ein Gameplay-Test wurden noch nicht erfolgreich nachgewiesen. Das Add-on enthält **keinen spielbaren Client**, keine Flash-/Spieldateien, kein Dash, keine Account-Registrierung und nicht den vollständigen Wand-Stack. **Allein durch die Installation kann man noch nicht Club Penguin spielen.**

---

## ✨ Funktionen

- 🐧 Houdini-Loginserver
- 🌍 Eine konfigurierbare Spielwelt (standardmäßig `blizzard`)
- 🐘 PostgreSQL-Datenbank im Container
- ⚡ Redis im Container
- 🗄️ Persistente Datenablage unter `/data`
- 🌐 Portzuordnung über Home Assistant
- 🖥️ Headless-Betrieb mit Protokollen in Home Assistant

---

## 📦 Enthaltene Dienste

| Komponente | Zweck | Status |
|---|---|---|
| Houdini Login | Anmeldeprotokoll | Enthalten |
| Houdini World | Spielweltserver | Enthalten (`blizzard` als Standard) |
| PostgreSQL | Datenbank | Nur intern |
| Redis | Cache / Nachrichten | Nur intern |
| Dash / Registrierung | Webdienste | Nicht enthalten |
| Spielclient und Assets | Zugang für Spieler | Nicht enthalten |
| Vollständiges Wand | Weitere Dienste | Nicht enthalten |

---

## 📁 Datenstruktur

Das Add-on nutzt das persistente Home-Assistant-Datenvolume (`/data` im Container), **nicht** das `/share`-Verzeichnis mancher anderer CycleMat-Gameserver.

```text
Home Assistant Add-on-Daten (/data)
├── PostgreSQL-Daten
├── Redis-Daten
└── Weitere persistente Laufzeitdateien, soweit konfiguriert
```

> [!IMPORTANT]
> Vor Updates, Neuinstallation oder Entfernung des Add-ons ein Backup der Daten erstellen. Persistente Speicherung ersetzt kein Backup.

---

## 🌐 Netzwerk & Ports

| Port | Protokoll | Funktion |
|---|---|---|
| `6112` | TCP | Houdini-Loginserver |
| `9875` | TCP | Houdini-Spielwelt |

Die externen Ports lassen sich in Home Assistant unter **Netzwerk** anpassen. PostgreSQL und Redis sind nur für die interne Nutzung innerhalb des Containers vorgesehen.

⚠️ **Sicherheit:** Die Gameserver-Ports sind standardmäßig nicht TLS-verschlüsselt. Bitte nicht ungeschützt ins Internet freigeben. Für Tests möglichst LAN oder VPN verwenden.

---

## ⚙️ Konfiguration

Die derzeitige `config.yaml` enthält:

| Option | Standardwert | Beschreibung |
|---|---|---|
| `world_name` | `blizzard` | Name der Spielwelt |
| `world_id` | `3100` | Numerische Welt-ID (1–9999) |
| `log_level` | `INFO` | `DEBUG`, `INFO`, `WARNING` oder `ERROR` |

Account-Registrierung, Client-Download und Webhosting sind aktuell **nicht** enthalten und deshalb nicht konfigurierbar.

---

## 🚀 Installation & erster Start

### Installation aus dem CycleMat-Repository

1. In Home Assistant **Einstellungen → Add-ons → Add-on-Store** öffnen.
2. Unter **⋮ → Repositories** folgende Adresse eintragen:

   `https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS`

3. **Club Penguin Houdini (Experimental)** auswählen und installieren.
4. Unter **Konfiguration** und **Netzwerk** die Einstellungen kontrollieren.
5. Add-on starten und die **Protokolle** prüfen.

Beim ersten Build wird Internetzugang benötigt, um Quellcode und Abhängigkeiten zu laden. Wegen älterer Abhängigkeiten können Build- oder Startfehler auftreten.

### Lokale Installation

Den Ordner `club_penguin_houdini` nach `/addons/club_penguin_houdini` kopieren, den Add-on-Store neu laden und das Add-on unter **Lokale Add-ons** installieren.

---

## 🧠 Technische Details

- Basiert auf [solero/houdini](https://github.com/solero/houdini)
- [solero/wand](https://github.com/solero/wand) ist das übergeordnete Docker-Projekt, aber **nicht** vollständig enthalten
- PostgreSQL und Redis laufen gemeinsam mit Houdini in einem Add-on-Container
- Aktuell unterstützte Architektur: `amd64`
- Beim Docker-Build werden Upstream-Abhängigkeiten geladen
- Kein Docker-Compose oder Host-Docker-Socket erforderlich

---

## 🔄 Updates & Entwicklungsstand

Dies ist eine **Entwicklungsversion**, kein durchgehend getesteter stabiler Release. Ein Neu-Build kann wegen veränderter Upstream-Abhängigkeiten fehlschlagen. Vor Updates daher ein Home-Assistant-Backup erstellen.

### Geplant

- ✅ Erste HAOS-Add-on-Struktur
- ⬜ Nachgewiesener HAOS-Build und erfolgreicher Start
- ⬜ Festgelegte Abhängigkeiten und Health-Checks
- ⬜ Account-Erstellung und Verwaltung
- ⬜ Anleitung für einen kompatiblen Client und Spieldateien
- ⬜ Optionales Dash-/Web-Frontend
- ⬜ Unterstützung mehrerer Spielwelten

---

## ⚠️ Haftungshinweis

Dies ist ein inoffizielles Community-Hobbyprojekt und steht in keiner Verbindung zu Disney, Club Penguin oder den Entwicklern von Houdini beziehungsweise Wand. Spielnamen und Inhalte sind Eigentum der jeweiligen Rechteinhaber. **Das Add-on verbreitet keine proprietären Clients oder Spieldateien.** Verwende nur Software und Assets, für die du die nötigen Nutzungsrechte hast.

---

## ❤️ Unterstützung & Spenden

Dieses Add-on wird in meiner Freizeit entwickelt und gepflegt. Alle CycleMat-Gameserver-Add-ons sind kostenlos.

Wenn dir das Projekt gefällt und du die Weiterentwicklung unterstützen möchtest:

👉 **PayPal-Spende:** http://paypal.me/cyclemat

Vielen Dank für deine Unterstützung! ❤️

---

## 🐛 Fehler & Feedback

Fehlerberichte, Logs und Verbesserungsvorschläge:

👉 [GitHub Issues](https://github.com/cyclemat/Home-Assistant-Gameservers-ADDONS/issues)

Bitte möglichst HAOS-Version, Add-on-Version und die relevanten Startprotokolle angeben (ohne Passwörter oder andere Geheimnisse).

---

<p align="center">
  <img src="https://raw.githubusercontent.com/cyclemat/Home-Assistant-Gameservers-ADDONS/main/assets/logo.png" alt="CycleMat" width="200">
</p>

<p align="center"><strong>Host your worlds. Your server. Your rules. 🐧</strong></p>
