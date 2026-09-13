# WebMediaDownloader

<p align="center">
  <b>Native macOS Desktop-Anwendung zum schnellen, parallelen Herunterladen von Bildern, Videos, Dokumenten und Audios/Podcasts von Webseiten.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0%2B-blue?style=flat-square&logo=apple" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Language-Swift%205.9%2B-orange?style=flat-square&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/UI-SwiftUI-cyan?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Language-Deutsch%20%7C%20English-green?style=flat-square" alt="Bilingual">
</p>

---

## 🌟 Highlights & Funktionen

- **4 Medien-Kategorien mit flexibler Auswahl**:
  - 🖼️ **Bilder**: JPG, PNG, WebP, GIF, SVG, AVIF, HEIC, TIFF, BMP etc.
  - 🎬 **Videos**: MP4, MKV, WebM, MOV sowie Unterstützung für Streaming-Formate (`m3u8`, `mpd`) und Videoplattformen über `yt-dlp`.
  - 📄 **Dokumente**: Adobe PDF, Microsoft Office (Word, Excel, PowerPoint), OpenDocument (ODT, ODS, ODP) sowie TXT, CSV, RTF und EPUB.
  - 🎵 **Audios & Podcasts**: MP3, M4A, AAC, FLAC, WAV, OGG, OPUS und automatische Extraktion aus Mediatheken & Plattformen (z. B. ARD Audiothek, ARD Sounds, Deutschlandfunk, Apple Podcasts).

- **3 Eingabemodi**:
  1. **Einzel-URL / Website crawlen**: Durchsucht Webseiten bis zu einer Tiefe von **1000 Ebenen**.
  2. **Web-Suche**: Globale Suche via DuckDuckGo (mit automatischem Yahoo-Fallback bei Rate-Limits).
  3. **URL-Liste (Batch)**: Stapelverarbeitung beliebig vieler Links.

- **Echte Concurrency & Speed**:
  - Nutzen Sie Ihre Bandbreite optimal mit parallelen Download-Tasks (`withTaskGroup`).
  - Individuelle Schieberegler für gleichzeitige Downloads von Bildern (1–10), Videos (1–4), Dokumenten (1–10) und Audios (1–10).

- **Dauerhafte Merkliste & Duplikatschutz**:
  - Speichert bereits heruntergeladene URLs und Datei-Hashes (MD5) in einer persistenten Historie.
  - **Integrierte Historien-Verwaltung**: Gezielt nach Datum (z. B. *„Heute“*, *„Letzte 24h“*, *„Letzte 7 Tage“* oder freier Kalendertag) oder vollständig zurücksetzbar – mit Live-Vorschau!

- **Umschaltbar per Button: Deutsch 🇩🇪 & Englisch 🇬🇧**:
  - Live-Umschaltung ohne Neustart direkt in der App-Kopfzeile, Toolbar oder per Tastaturkürzel (`⌘ + ⇧ + L`).
  - Alle Texte, Statusanzeigen, Historien-Dialoge und Hilfekapitel sind vollständig zweisprachig.

- **Umfangreiches Hilfesystem**:
  - Integrierte Anleitung mit 9 Themenbereichen, Schnellsuche und Best Practices direkt in der App (`⌘ + ?`).

- **Automatische Systemprüfung**:
  - Prüft und installiert auf Wunsch benötigte Kommandozeilen-Tools (`yt-dlp`, `ffmpeg` via Homebrew) mit nur einem Klick.

---

## 💻 Systemvoraussetzungen

- macOS 14.0 (Sonoma) oder neuer
- Apple Silicon (M1/M2/M3/M4) oder Intel Mac
- Optional für erweiterte Video- und Audio-Plattformen: `yt-dlp` und `ffmpeg` (kann direkt über die App installiert werden)

---

## 🚀 Installation & Start

### Fertiges Release / Disk-Image (.dmg)
1. Laden Sie die Datei `WebMediaDownloader-Installer.dmg` aus den [Releases](../../releases) herunter.
2. Öffnen Sie das DMG-Image per Doppelklick.
3. Ziehen Sie **WebMediaDownloader** in den Ordner **Applications (Programme)**.
4. Fertig! Die App kann direkt über Spotlight oder das Launchpad gestartet werden.

### Aus Quellcode kompilieren

```bash
# Repository klonen
git clone https://github.com/<USERNAME>/Web-Media-Downloader.git
cd Web-Media-Downloader

# Release kompilieren und starten
swift run -c release
```

Oder das Xcode-Projekt öffnen:
```bash
open WebPicDownload/WebPicDownload.xcodeproj
```

---

## 🛠️ Architektur

- **SwiftUI & AppKit**: Moderne, reaktive Benutzeroberfläche nach Apple Human Interface Guidelines.
- **Swift Concurrency**: `actor DownloadTracker` zur thread-sicheren Zustandsspeicherung und Vermeidung von Race Conditions bei parallelen Downloads.
- **Crawler-Engine**: Rekursiver Web-Crawler mit HTML-Parsing, MIME-Typ-Validierung, Referer-Spoofing und optionalem Chrome-Cookie-Import.

---

## 📄 Lizenz

Dieses Projekt ist für den privaten und professionellen Gebrauch lizenziert.
