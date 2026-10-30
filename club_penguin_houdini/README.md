# Club Penguin Houdini – HAOS Add-on (Experimentell)

Ein lokales Home-Assistant-OS-Add-on für **Houdini** mit PostgreSQL und Redis **im selben Container**. Es startet einen Loginserver und eine Welt. **Es ist kein vollständiges Wand-Paket und enthält weder Dash noch den Web-/Flash-Client oder Spieldateien.**

## Installation
1. ZIP entpacken.
2. Den Ordner `club_penguin_houdini` nach `/addons/club_penguin_houdini` auf deinem HAOS kopieren (z. B. per SSH/Samba).
3. In **Einstellungen → Add-ons → Add-on-Store** das Menü öffnen und **Neu laden** wählen.
4. Unter **Lokale Add-ons** das Add-on auswählen und installieren. Der Build benötigt Netzwerkzugriff auf GitHub/PyPI.
5. Starten und **Protokoll** prüfen.

## Ports
- TCP **6112**: Loginserver
- TCP **9875**: Spielwelt `blizzard`
- PostgreSQL und Redis sind nur auf `127.0.0.1` **im Container** erreichbar.

## Persistenz
PostgreSQL- und Redis-Daten liegen unter `/data` im Add-on. Die Daten werden nicht bei jedem Neustart gelöscht. Vor einer Neuinstallation ein HAOS-Backup erstellen.

## Einschränkungen
- **Ungetestete Beta**: Dateien und YAML wurden statisch geprüft, aber kein echter Docker-Build oder HAOS-Laufzeittest war hier möglich.
- Client, Asset-Hosting, Dash, Snowflake und Account-Registrierungsseite sind nicht enthalten.
- Der Standard-Port 6112 ist nicht verschlüsselt; nicht ungeprüft ins Internet freigeben.
- Upstream-Quellcode wird beim Build von `solero/houdini` geladen. Für reproduzierbare Releases den Git-Commit festschreiben.
- Das Legacy-Projekt kann durch veraltete Python-Paketabhängigkeiten oder Datenbank-Schema-Annahmen einen Build- oder Laufzeitfehler verursachen.

## Originale
https://github.com/solero/houdini
https://github.com/solero/wand
