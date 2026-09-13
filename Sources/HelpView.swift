import SwiftUI

enum HelpTopic: String, CaseIterable, Identifiable {
    case quickstart = "quickstart"
    case modes = "modes"
    case crawlerOptions = "crawlerOptions"
    case concurrency = "concurrency"
    case videoDownloads = "videoDownloads"
    case documentDownloads = "documentDownloads"
    case audioDownloads = "audioDownloads"
    case dependencies = "dependencies"
    case faq = "faq"
    
    var id: String { rawValue }
    
    var title: String {
        let isDe = (LocalizationManager.shared.currentLanguage == .de)
        switch self {
        case .quickstart: return isDe ? "Schnellstart & Erste Schritte" : "Quickstart & First Steps"
        case .modes: return isDe ? "Eingabemodi im Detail" : "Input Modes in Detail"
        case .crawlerOptions: return isDe ? "Crawler-Optionen & Suchtiefe" : "Crawler Options & Depth"
        case .concurrency: return isDe ? "Parallelität & Geschwindigkeit" : "Concurrency & Speed"
        case .videoDownloads: return isDe ? "Video-Downloads & yt-dlp" : "Video Downloads & yt-dlp"
        case .documentDownloads: return isDe ? "Dokument-Downloads (PDF & Office)" : "Document Downloads (PDF & Office)"
        case .audioDownloads: return isDe ? "Audio-Downloads & Podcasts (MP3 & ARD Sounds)" : "Audio Downloads & Podcasts (MP3 & Streams)"
        case .dependencies: return isDe ? "System-Werkzeuge" : "System Tools"
        case .faq: return isDe ? "Häufige Fragen & FAQ" : "Frequently Asked Questions (FAQ)"
        }
    }
    
    var icon: String {
        switch self {
        case .quickstart: return "bolt.fill"
        case .modes: return "network"
        case .crawlerOptions: return "slider.horizontal.3"
        case .concurrency: return "gauge.with.dots.needle.50percent"
        case .videoDownloads: return "play.rectangle.fill"
        case .documentDownloads: return "doc.text.fill"
        case .audioDownloads: return "waveform"
        case .dependencies: return "wrench.and.screwdriver.fill"
        case .faq: return "questionmark.circle.fill"
        }
    }
}

struct HelpView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var langManager = LocalizationManager.shared
    @State private var selectedTopic: HelpTopic? = .quickstart
    @State private var searchText = ""
    
    var filteredTopics: [HelpTopic] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return HelpTopic.allCases
        }
        let query = searchText.lowercased()
        return HelpTopic.allCases.filter {
            $0.title.lowercased().contains(query) || topicKeywords($0).lowercased().contains(query)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "book.pages.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(loc("WebMediaDownloader – Anleitung & Hilfesystem", "WebMediaDownloader – Help & User Guide"))
                    .font(.headline)
                Spacer()
                
                // Language Switch Button in HelpView
                Button(action: { langManager.toggleLanguage() }) {
                    HStack(spacing: 4) {
                        Text(langManager.currentLanguage == .de ? "🇬🇧 English" : "🇩🇪 Deutsch")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(loc("Auf Englisch umschalten", "Switch to German"))
                
                Button(loc("Fertig", "Done")) {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Main Two-Column Navigation View
            NavigationSplitView {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField(loc("Hilfe durchsuchen...", "Search help..."), text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    
                    List(filteredTopics, selection: $selectedTopic) { topic in
                        NavigationLink(value: topic) {
                            Label(topic.title, systemImage: topic.icon)
                                .padding(.vertical, 3)
                        }
                    }
                    .listStyle(.sidebar)
                }
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
            } detail: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let topic = selectedTopic {
                            topicContent(for: topic)
                        } else {
                            Text(loc("Bitte wählen Sie links ein Hilfethema aus.", "Please select a help topic from the left."))
                                .foregroundColor(.secondary)
                                .padding(30)
                        }
                    }
                    .padding(25)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .frame(minWidth: 800, idealWidth: 880, minHeight: 540, idealHeight: 620)
    }
    
    // MARK: - Topic Keywords for Search
    private func topicKeywords(_ topic: HelpTopic) -> String {
        switch topic {
        case .quickstart:
            return "erste schritte zielordner start anleitung grundlagen übersicht console log quickstart steps guide destination folder start"
        case .modes:
            return "einzel-url internet-suche url-liste duckduckgo yahoo site batch massenverarbeitung single web search list batch"
        case .crawlerOptions:
            return "suchtiefe minimale dateigröße filter externe links unterseiten duplikate hash md5 history depth file size subpages duplicates"
        case .concurrency:
            return "parallelität downloads gleichzeitig geschwindigkeit performance taskgroup rate limit 429 concurrency speed parallel"
        case .videoDownloads:
            return "yt-dlp videos ffmpeg stream m3u8 manifest cookies chrome watch player streaming hls dash"
        case .documentDownloads:
            return "dokumente pdf word excel powerpoint office docx xlsx pptx odt ods odp rtf txt csv epub berichte documents spreadsheets slides"
        case .audioDownloads:
            return "audio podcast hörbuch musik song ardsounds ardaudiothek dradio mp3 m4a aac flac wav ogg opus soundcloud download radio music"
        case .dependencies:
            return "system homebrew brew yt-dlp ffmpeg installation terminal werkzeuge tools components"
        case .faq:
            return "fragen fehler mime typ php abbruch probleme lösungen faq questions errors troubleshooting"
        }
    }
    
    // MARK: - Topic Content Views
    @ViewBuilder
    private func topicContent(for topic: HelpTopic) -> some View {
        switch topic {
        case .quickstart:
            quickstartView
        case .modes:
            modesView
        case .crawlerOptions:
            crawlerOptionsView
        case .concurrency:
            concurrencyView
        case .videoDownloads:
            videoDownloadsView
        case .documentDownloads:
            documentDownloadsView
        case .audioDownloads:
            audioDownloadsView
        case .dependencies:
            dependenciesView
        case .faq:
            faqView
        }
    }
    
    // MARK: - 1. Schnellstart / Quickstart
    private var quickstartView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "Schnellstart & Erste Schritte" : "Quickstart & First Steps", icon: "bolt.fill")
            
            Text(isDe ?
                 "Willkommen bei **WebMediaDownloader**! Mit dieser nativen macOS-Anwendung können Sie Bilder, Videos, Dokumente und Audios von Webseiten, Suchmaschinen oder Link-Listen vollautomatisch herunterladen." :
                 "Welcome to **WebMediaDownloader**! With this native macOS application, you can automatically download images, videos, documents, and audio from websites, search engines, or link lists.")
                .font(.body)
            
            card(title: isDe ? "In 3 Schritten zum Download:" : "Download in 3 Simple Steps:", icon: "list.number") {
                VStack(alignment: .leading, spacing: 10) {
                    stepRow(
                        number: "1",
                        title: isDe ? "Zielordner auswählen" : "Select Destination Folder",
                        description: isDe ?
                            "Klicken Sie links unter 'Zielordner (Lokal)' auf 'Suchen...' und wählen Sie den Mac-Ordner, in dem die Dateien gespeichert werden sollen." :
                            "Click 'Browse...' under 'Destination Folder (Local)' on the left and choose the Mac directory where files should be saved."
                    )
                    stepRow(
                        number: "2",
                        title: isDe ? "Modus & Webadresse festlegen" : "Choose Mode & Web Address",
                        description: isDe ?
                            "Wählen Sie den gewünschten Eingabemodus (Einzel-URL, Internet-Suche oder URL-Liste) und geben Sie die Zieladresse oder Suchbegriffe ein." :
                            "Select your desired input mode (Single URL, Web Search, or URL List) and enter the target URL or search keywords."
                    )
                    stepRow(
                        number: "3",
                        title: isDe ? "Starten" : "Start Download",
                        description: isDe ?
                            "Wählen Sie 'Bilder herunterladen', 'Videos herunterladen', 'Dokumente herunterladen' und/oder 'Audios herunterladen' und klicken Sie auf den Button 'Starten'." :
                            "Enable 'Download Images', 'Download Videos', 'Download Documents', and/or 'Download Audio' and click 'Start'."
                    )
                }
            }
            
            infoBox(
                title: isDe ? "Echtzeit-Dashboard & Konsole" : "Real-time Dashboard & Console",
                text: isDe ?
                    "Während des Downloads zeigt Ihnen das Dashboard oben rechts die Anzahl der durchsuchten Seiten, gefundenen und geladenen Medien sowie die übertragene Datenmenge live an. Im Protokoll-Fenster darunter können Sie jeden Schritt in Echtzeit mitverfolgen." :
                    "During the download, the top-right dashboard displays pages crawled, media files found and downloaded, and data transfer volume in real time. The console log below tracks every step live.",
                type: .info
            )
            
            infoBox(
                title: isDe ? "Downloads pausieren oder abbrechen" : "Pause or Cancel Downloads",
                text: isDe ?
                    "Sie können laufende Downloads jederzeit mit dem Button 'Pausieren' vorübergehend anhalten und später fortsetzen, oder mit 'Abbrechen' sofort und sauber beenden." :
                    "You can temporarily halt ongoing downloads at any time with 'Pause' and resume later, or cleanly terminate them immediately with 'Cancel'.",
                type: .tip
            )
        }
    }
    
    // MARK: - 2. Eingabemodi / Input Modes
    private var modesView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "Eingabemodi im Detail" : "Input Modes in Detail", icon: "network")
            
            Text(isDe ?
                 "Die App bietet drei flexible Eingabemodi, die Sie über den Umschalter oben links auswählen können:" :
                 "The app provides three flexible input modes, selectable via the segmented control on the top left:")
                .font(.body)
            
            card(title: isDe ? "1. Einzel-URL" : "1. Single URL", icon: "link") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isDe ? "Geben Sie eine einzelne Webadresse ein (z. B. `https://example.com/galerie`)." : "Enter a single website URL (e.g. `https://example.com/gallery`).")
                    Text(isDe ? "• **Verhalten:** Der Crawler analysiert diese Seite und lädt alle darauf gefundenen Bilder bzw. Medien." : "• **Behavior:** The crawler parses this page and downloads all discovered images and media.")
                    Text(isDe ? "• **Tipp:** Wenn Sie der Seite tiefer folgen möchten (z. B. Folgeseiten oder Detailansichten), stellen Sie die **Suchtiefe** auf mindestens 1 oder 2 ein." : "• **Tip:** To follow links deeper (e.g. pagination or detail pages), increase **Search Depth** to at least 1 or 2.")
                }
            }
            
            card(title: isDe ? "2. Internet-Suche" : "2. Web Search", icon: "magnifyingglass") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isDe ? "Geben Sie freie Suchbegriffe ein (z. B. `Oldtimer Cabrio rot`)." : "Enter arbitrary search terms (e.g. `vintage red roadster`).")
                    Text(isDe ? "• **Verhalten:** Die App fragt datenschutzfreundliche Suchmaschinen (DuckDuckGo mit automatischem Yahoo-Fallback) ab und durchsucht die gefundenen Ergebnisseiten automatisch." : "• **Behavior:** The app queries privacy-focused search engines (DuckDuckGo with automatic Yahoo fallback) and crawls the resulting web pages automatically.")
                    Text(isDe ? "• **Maximale Anzahl Seiten:** Begrenzen Sie die Trefferanzahl (5, 10, 20, 30 oder 50 Seiten)." : "• **Max Results:** Limit the number of result pages to crawl (5, 10, 20, 30, or 50 pages).")
                    Text(isDe ? "• **Website-Einschränkung (`site:`):** Sie können die Suche auf eine bestimmte Domain beschränken (z. B. `wikipedia.org` oder `youtube.com`). Die App sucht dann ausschließlich auf dieser Website." : "• **Site Restriction (`site:`):** Restrict searches to a specific domain (e.g. `wikipedia.org` or `youtube.com`).")
                }
            }
            
            card(title: isDe ? "3. URL-Liste (Batch-Download)" : "3. URL List (Batch Download)", icon: "text.alignleft") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isDe ? "Geben Sie beliebig viele URLs in das Textfeld ein (eine URL pro Zeile)." : "Paste multiple URLs into the text editor (one URL per line).")
                    Text(isDe ? "• **Verhalten:** Die App arbeitet jede Zeile der Liste nacheinander oder parallel ab." : "• **Behavior:** The app processes every line of the list sequentially or in parallel.")
                    Text(isDe ? "• **Besonders stark für Medien:** Wenn 'Videos herunterladen' oder 'Audios herunterladen' aktiv ist, wird jede Zeile direkt als Medienquelle übergeben. Ideal für Serien von Videolinks oder Podcasts!" : "• **Ideal for batch media:** When 'Download Videos' or 'Download Audio' is active, each URL is processed directly as a media stream. Perfect for video series or podcast playlists!")
                }
            }
        }
    }
    
    // MARK: - 3. Crawler-Optionen / Crawler Options
    private var crawlerOptionsView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "Crawler-Optionen & Suchtiefe" : "Crawler Options & Depth", icon: "slider.horizontal.3")
            
            card(title: isDe ? "Suchtiefe (Links folgen)" : "Search Depth (Following Links)", icon: "arrow.down.right.and.arrow.up.left") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isDe ? "Die Suchtiefe steuert, wie vielen Ebenen von Verlinkungen der Crawler folgt (0 bis 1000):" : "Search depth controls how many link tiers the crawler traverses (0 to 1000):")
                    HStack(alignment: .top, spacing: 10) {
                        Text(isDe ? "• **0 (Nur Startseite):**" : "• **0 (Start page only):**").fontWeight(.semibold)
                        Text(isDe ? "Es werden nur Medien geladen, die direkt auf der Startseite eingebettet sind. Es wird keinen Links gefolgt." : "Only media directly embedded on the initial page are downloaded. No links are followed.")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text(isDe ? "• **1 Ebene tief:**" : "• **1 Level deep:**").fontWeight(.semibold)
                        Text(isDe ? "Die Startseite wird durchsucht, und alle Links auf der Startseite werden ebenfalls als Unterseiten aufgerufen." : "The start page is crawled, and all links found on it are visited as subpages.")
                    }
                    HStack(alignment: .top, spacing: 10) {
                        Text(isDe ? "• **2+ Ebenen tief (bis 1000):**" : "• **2+ Levels deep (up to 1000):**").fontWeight(.semibold)
                        Text(isDe ? "Folgt weiteren Verlinkungen rekursiv bis zur gewählten Tiefe." : "Recursively follows subsequent links up to the configured depth.")
                    }
                    
                    infoBox(
                        title: isDe ? "Wichtig für Video-Portale & Suchseiten:" : "Important for Video Platforms & Portals:",
                        text: isDe ?
                            "Auf Portalen sind Videos meist nicht direkt auf der Übersichtsseite eingebettet, sondern auf eigenen Unterseiten ('Watch-Pages'). Wählen Sie bei solchen Seiten immer mindestens **Suchtiefe 1**, damit der Crawler den Links zu den eigentlichen Videoseiten folgen kann!" :
                            "On video portals, media streams are rarely embedded directly on listing pages, but on dedicated subpages ('watch pages'). Always use at least **Search Depth 1** so the crawler can follow links to the actual player pages!",
                        type: .warning
                    )
                }
            }
            
            card(title: isDe ? "Filter & Ordnungsoptionen" : "Filters & Storage Options", icon: "folder") {
                VStack(alignment: .leading, spacing: 10) {
                    optionRow(
                        title: isDe ? "Minimale Dateigröße (KB)" : "Minimum File Size (KB)",
                        desc: isDe ? "Filtert kleine Vorschaubilder, Icons, Buttons und Tracking-Pixel heraus (Standard: 50 KB)." : "Filters out tiny thumbnails, icons, buttons, and tracking pixels (Default: 50 KB)."
                    )
                    optionRow(
                        title: isDe ? "Externe Links verfolgen" : "Follow External Links",
                        desc: isDe ? "Bleibt standardmäßig deaktiviert, damit der Crawler nicht ins freie Web abdriftet, sondern auf dem Start-Host bleibt." : "Disabled by default so the crawler stays on the start host instead of wandering off to the open web."
                    )
                    optionRow(
                        title: isDe ? "Doppelte Dateien verhindern" : "Prevent Duplicate Files",
                        desc: isDe ? "Berechnet den MD5-Inhalts-Hash jeder Datei und speichert eine `.download_history.json` im Zielordner. Gleiche Dateien werden sofort übersprungen – auch über Programm-Neustarts hinweg! Über 'Merkliste verwalten & zurücksetzen...' können Sie diese Liste jederzeit vollständig oder nach Datum leeren." : "Computes the MD5 content hash for each file and stores `.download_history.json` in the destination folder. Duplicates are skipped instantly across app sessions. You can manage or reset this history at any time via 'Manage & Reset Download History...'."
                    )
                    optionRow(
                        title: isDe ? "Nach Unterseiten strukturieren" : "Organize by Subpages",
                        desc: isDe ? "Legt für jede durchsuchte Unterseite automatisch einen eigenen, passend benannten Unterordner an." : "Automatically creates dedicated, sanitized subfolders for each crawled subpage."
                    )
                }
            }
        }
    }
    
    // MARK: - 4. Parallelität / Concurrency
    private var concurrencyView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "Parallelität & Geschwindigkeit" : "Concurrency & Speed", icon: "gauge.with.dots.needle.50percent")
            
            Text(isDe ?
                 "WebMediaDownloader unterstützt **echte, parallele Downloads** über Swifts Concurrency-Engine (`withTaskGroup`). Dadurch wird Ihre Bandbreite optimal ausgenutzt." :
                 "WebMediaDownloader supports **true parallel downloads** using Swift's Concurrency Engine (`withTaskGroup`), maximizing network throughput.")
                .font(.body)
            
            card(title: isDe ? "Gleichzeitige Bild-Downloads (1 bis 10)" : "Concurrent Image Downloads (1 to 10)", icon: "photo.stack") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isDe ? "• **Standardwert:** 4 gleichzeitige Bilder." : "• **Default:** 4 concurrent images.")
                    Text(isDe ? "• **Empfehlung:** Bei schnellen Leitungen können Sie diesen Wert auf 6 bis 8 erhöhen. Webseiten mit 50–100 Bildern werden dadurch in Sekunden geladen." : "• **Recommendation:** On fast broadband, increase this to 6–8. Galleries with 50–100 images will finish in seconds.")
                    Text(isDe ? "• **Hinweis:** Manche empfindliche Server können bei mehr als 8 Verbindungen temporäre Fehler (HTTP 429 Too Many Requests) senden. Im Zweifel reichen 4–5 völlig aus." : "• **Note:** Sensitive web servers may return rate-limit errors (HTTP 429) if concurrency is set too high. 4–5 is typically optimal.")
                }
            }
            
            card(title: isDe ? "Gleichzeitige Video-Downloads (1 bis 4)" : "Concurrent Video Downloads (1 to 4)", icon: "film.stack") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isDe ? "• **Standardwert:** 2 gleichzeitige Videos." : "• **Default:** 2 concurrent videos.")
                    Text(isDe ? "• **Warum moderat wählen?** Jeder `yt-dlp`-Prozess lädt Stream-Fragmente und verwendet `ffmpeg` zum Zusammenführen (Muxing) von Ton und Bild. Das beansprucht spürbar Prozessorleistung (CPU)." : "• **Why moderate?** Each `yt-dlp` process streams video segments and uses `ffmpeg` for muxing video and audio tracks, which utilizes noticeable CPU resources.")
                    Text(isDe ? "• **Empfehlung:** 2–3 gleichzeitige Video-Downloads bieten die perfekte Balance zwischen Geschwindigkeit und flüssiger System-Performance." : "• **Recommendation:** 2–3 concurrent video streams provide the sweet spot of speed and smooth Mac responsiveness.")
                }
            }
            
            card(title: isDe ? "Gleichzeitige Dokument-Downloads (1 bis 10)" : "Concurrent Document Downloads (1 to 10)", icon: "doc.stack") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isDe ? "• **Standardwert:** 4 gleichzeitige Dokumente." : "• **Default:** 4 concurrent documents.")
                    Text(isDe ? "• **Empfehlung:** Ideal für das schnelle Herunterladen großer Sammlungen von PDF- oder Office-Dateien." : "• **Recommendation:** Perfect for swiftly gathering large collections of PDFs and Office files.")
                }
            }
            
            card(title: isDe ? "Gleichzeitige Audio-Downloads (1 bis 10)" : "Concurrent Audio Downloads (1 to 10)", icon: "waveform") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isDe ? "• **Standardwert:** 4 gleichzeitige Audios." : "• **Default:** 4 concurrent audio streams.")
                    Text(isDe ? "• **Empfehlung:** Perfekt für das zügige Herunterladen ganzer Hörspiel- oder Podcast-Reihen (z. B. von ARD Sounds / Deutschlandfunk)." : "• **Recommendation:** Excellent for rapidly downloading entire podcast series or audiobooks (e.g. ARD Sounds, DLF).")
                }
            }
            
            infoBox(
                title: isDe ? "100 % Thread-Sicherheit" : "100% Thread Safety",
                text: isDe ?
                    "Alle Zähler, Download-Historieneinträge und Dateischreibvorgänge werden durch einen Swift-Actor (`DownloadTracker`) synchronisiert. Es treten selbst bei maximaler Parallelität keinerlei Datenkollisionen auf." :
                    "All stats, history records, and file operations are coordinated via a Swift actor (`DownloadTracker`), guaranteeing complete thread safety without race conditions.",
                type: .info
            )
        }
    }
    
    // MARK: - 5. Video-Downloads & yt-dlp
    private var videoDownloadsView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "Video-Downloads & yt-dlp" : "Video Downloads & yt-dlp", icon: "play.rectangle.fill")
            
            Text(isDe ?
                 "Die App integriert das weltweit führende Open-Source-Videowerkzeug **yt-dlp** zusammen mit **ffmpeg**." :
                 "The application integrates the world-renowned open-source video extractor **yt-dlp** alongside **ffmpeg**.")
                .font(.body)
            
            card(title: isDe ? "Wie Video-Downloads funktionieren" : "How Video Downloads Work", icon: "gearshape.2") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isDe ? "1. **Bekannte Video-Plattformen:** URLs bekannter Portale (z. B. YouTube, Vimeo, Twitch, Reddit, Mediatheken etc.) werden sofort erkannt und direkt an `yt-dlp` übergeben." : "1. **Recognized Video Portals:** URLs of known video platforms (e.g. YouTube, Vimeo, Twitch, Reddit, broadcast libraries) are passed directly to `yt-dlp` for maximum stream quality.")
                    Text(isDe ? "2. **Streaming-Manifeste (HLS / DASH):** Bei Webseiten durchsucht die App den Quellcode nach versteckten `.m3u8`- und `.mpd`-Streaming-Manifesten sowie direkten `.mp4`-Dateien." : "2. **Streaming Manifests (HLS / DASH):** The crawler analyzes HTML source for embedded `.m3u8` and `.mpd` playlists as well as direct `.mp4` video files.")
                    Text(isDe ? "3. **Eingebettete Player (Iframes):** Der Crawler folgt automatisch eingebetteten `<iframe>`-Playern und durchsucht diese nach Medien." : "3. **Embedded Players (Iframes):** The crawler inspects embedded `<iframe>` players automatically.")
                    Text(isDe ? "4. **Zusammenführen von Audio & Video:** `ffmpeg` sorgt dafür, dass getrennte Video- und Tonspuren automatisch zu einer perfekten MP4-Datei zusammengefügt werden." : "4. **Audio & Video Muxing:** `ffmpeg` merges separate video and audio streams into playable MP4 files automatically.")
                }
            }
            
            card(title: isDe ? "Option: Chrome-Cookies importieren" : "Option: Import Chrome Cookies", icon: "lock.shield") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isDe ? "Manche Videos (z. B. Altersbeschränkungen oder Login-Bereiche) erfordern eine Anmeldung." : "Some media (e.g. age-restricted content or member portals) require an active user session.")
                    Text(isDe ? "• Wenn Sie **'Chrome-Cookies importieren'** aktivieren, nutzt `yt-dlp` Ihre bestehenden Logins aus Google Chrome." : "• When **'Import Chrome Cookies'** is enabled, `yt-dlp` borrows your logged-in cookies from Google Chrome.")
                    Text(isDe ? "• **Auto-Fallback:** Sollte Chrome nicht verfügbar sein, schlägt der Download nicht fehl, sondern wiederholt den Versuch vollautomatisch ohne Cookies." : "• **Auto-Fallback:** If Chrome is not available or has no active session, the app automatically retries without cookies.")
                }
            }
        }
    }
    
    // MARK: - 6. Dokument-Downloads / Document Downloads
    private var documentDownloadsView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "Dokument-Downloads (PDF & Office)" : "Document Downloads (PDF & Office)", icon: "doc.text.fill")
            
            Text(isDe ?
                 "Mit der Option **'Dokumente herunterladen'** durchsucht WebMediaDownloader Webseiten und Suchmaschinen nach Dokumenten aller gängigen Formate und lädt diese vollautomatisch herunter." :
                 "With **'Download Documents'** enabled, WebMediaDownloader scans web pages and search queries for documents across all common formats and downloads them automatically.")
                .font(.body)
            
            card(title: isDe ? "Unterstützte Dokumentformate" : "Supported Document Formats", icon: "doc.on.doc") {
                VStack(alignment: .leading, spacing: 8) {
                    optionRow(
                        title: "Adobe PDF (.pdf)",
                        desc: isDe ? "Eingebettete PDFs, Formulare, Geschäftsberichte und Verlinkungen werden automatisch erkannt." : "Embedded PDF viewers, reports, whitepapers, and direct links."
                    )
                    optionRow(
                        title: "Microsoft Word (.docx, .doc)",
                        desc: isDe ? "Dokumente, Vorlagen und Word-Dateien." : "Word documents, templates, and archives."
                    )
                    optionRow(
                        title: "Microsoft Excel (.xlsx, .xls, .csv)",
                        desc: isDe ? "Tabellenblätter, Arbeitsmappen und CSV-Datensätze." : "Worksheets, spreadsheets, and CSV datasets."
                    )
                    optionRow(
                        title: "Microsoft PowerPoint (.pptx, .ppt)",
                        desc: isDe ? "Präsentationen, Folien und Vorlagen." : "Slide decks, presentations, and templates."
                    )
                    optionRow(
                        title: "OpenDocument / LibreOffice (.odt, .ods, .odp)",
                        desc: isDe ? "Freie Office-Formate für Text, Tabellen und Präsentationen." : "Open formats for text, spreadsheets, and presentations."
                    )
                    optionRow(
                        title: "Text & E-Books (.rtf, .txt, .epub)",
                        desc: isDe ? "Rich Text Dokumente, reine Textdateien und E-Books." : "Rich text documents, plain text, and electronic books."
                    )
                }
            }
            
            card(title: isDe ? "Tipps für die Dokumentensuche" : "Tips for Document Discovery", icon: "lightbulb") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isDe ? "1. **Gezielte Dateitypen in der Web-Suche:** Geben Sie im Modus 'Internet-Suche' z. B. `filetype:pdf` oder `filetype:docx` zusammen mit Ihrem Suchbegriff ein (z. B. `Quartalsbericht 2024 filetype:pdf`)." : "1. **Targeted Filetypes in Web Search:** In 'Web Search' mode, append `filetype:pdf` or `filetype:docx` to your keywords (e.g. `annual report 2024 filetype:pdf`).")
                    Text(isDe ? "2. **Eingebettete Dokumente:** Auch über `<embed>`- oder `<object>`-Tags eingebundene PDF-Betrachter werden zuverlässig erkannt." : "2. **Embedded Viewers:** The crawler reliably detects `<embed>` and `<object>` viewer plugins.")
                    Text(isDe ? "3. **Direkte Datei-Listen:** Im Modus 'URL-Liste' können Sie direkte Links zu PDF- oder Office-Dateien einfügen – diese werden ohne Umwege direkt gespeichert." : "3. **Direct File URLs:** Paste direct PDF or Office links into 'URL List' mode for immediate downloading.")
                }
            }
        }
    }
    
    // MARK: - 7. Audio-Downloads / Audio Downloads
    private var audioDownloadsView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "Audio-Downloads & Podcasts (MP3 & ARD Sounds)" : "Audio Downloads & Podcasts (MP3 & Streams)", icon: "waveform")
            
            Text(isDe ?
                 "Mit WebMediaDownloader können Sie Audiotitel, Musik, Podcasts, Hörbücher und Radiosendungen sowohl von bekannten Audio-Plattformen als auch direkt von Webseiten herunterladen." :
                 "With WebMediaDownloader you can download audio tracks, music, podcasts, audiobooks, and radio broadcasts from major platforms or directly from website links.")
                .font(.body)
            
            card(title: isDe ? "Unterstützte Audioformate & Plattformen" : "Supported Audio Formats & Platforms", icon: "music.note.list") {
                VStack(alignment: .leading, spacing: 10) {
                    optionRow(
                        title: "MP3 Audio (.mp3)",
                        desc: isDe ? "Universelles Audioformat – wird direkt oder via Extraktor in erstklassiger MP3-Qualität gespeichert." : "Universal audio standard – saved in pristine MP3 quality directly or via extractors."
                    )
                    optionRow(
                        title: "AAC / Apple Audio (.m4a, .aac)",
                        desc: isDe ? "Häufig für Podcasts und Apple Podcasts / iTunes verwendet." : "Commonly used for podcast feeds and iTunes/Apple Podcasts."
                    )
                    optionRow(
                        title: "Verlustfreie Formate (.flac, .wav, .aiff)",
                        desc: isDe ? "Studio- und Hi-Res-Audioqualität ohne Qualitätsverlust." : "Studio and high-resolution lossless audio streams."
                    )
                    optionRow(
                        title: "Moderne Web-Audioformate (.ogg, .opus, .weba)",
                        desc: isDe ? "Moderne, komprimierte Audiostreams im Netz." : "Modern efficient web audio streams."
                    )
                    optionRow(
                        title: isDe ? "Audio-Plattformen & Mediatheken" : "Audio Platforms & Broadcasters",
                        desc: isDe ? "Unterstützt z. B. ardsounds.de, ardaudiothek.de, Deutschlandfunk (dradio.de), SoundCloud, Apple Podcasts u. v. m." : "Supports platforms like ardsounds.de, ardaudiothek.de, dradio.de, SoundCloud, podcasts, and more."
                    )
                }
            }
            
            card(title: isDe ? "Wie Audio-Downloads funktionieren" : "How Audio Downloads Work", icon: "gearshape.2") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isDe ? "1. **Direkte Audio-Dateien:** Verlinkungen zu `.mp3`- oder `.m4a`-Dateien (wie z. B. Podcast-Episoden von `dradio.de`) werden direkt und blitzschnell über URLSession heruntergeladen." : "1. **Direct Audio Files:** Links to `.mp3` or `.m4a` files (such as podcast episodes from `dradio.de`) download directly and swiftly via URLSession.")
                    Text(isDe ? "2. **Audio-Tags & Podcast-Feeds:** Die App durchsucht HTML-Seiten automatisch nach `<audio>`- und `<source>`-Tags sowie RSS/Podcast-`<enclosure>`-Tags." : "2. **HTML Audio Tags & Enclosures:** Pages are automatically parsed for `<audio>`, `<source>`, and RSS podcast `<enclosure>` tags.")
                    Text(isDe ? "3. **Audio-Plattformen via yt-dlp & ffmpeg:** Bei Plattformen wie `ardsounds.de` oder `ardaudiothek.de` übernimmt `yt-dlp` das Extrahieren des Audiostreams und wandelt ihn mit `ffmpeg` automatisch in saubere MP3-Dateien (`-x --audio-format mp3`) um." : "3. **Platform Extraction:** On platforms like `ardsounds.de` or `ardaudiothek.de`, `yt-dlp` extracts the audio stream and converts it into pure MP3 using `ffmpeg` (`-x --audio-format mp3`).")
                }
            }
        }
    }
    
    // MARK: - 8. System-Werkzeuge / System Tools
    private var dependenciesView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "System-Werkzeuge" : "System Tools", icon: "wrench.and.screwdriver.fill")
            
            Text(isDe ?
                 "Für maximale Leistungsfähigkeit greift WebMediaDownloader auf bewährte macOS-Werkzeuge zurück:" :
                 "For maximum capability and speed, WebMediaDownloader utilizes trusted macOS command-line tools:")
                .font(.body)
            
            card(title: isDe ? "Die drei Komponenten" : "The Three Core Components", icon: "cpu") {
                VStack(alignment: .leading, spacing: 10) {
                    toolRow(
                        name: "Homebrew",
                        status: isDe ? "Paketmanager für macOS" : "Package Manager for macOS",
                        desc: isDe ? "Wird benötigt, um Werkzeuge wie yt-dlp und ffmpeg sauber und aktuell auf Ihrem Mac bereitzustellen." : "Used to safely manage and update command line utilities like yt-dlp and ffmpeg on your Mac."
                    )
                    toolRow(
                        name: "yt-dlp",
                        status: isDe ? "Video- & Audio-Downloader" : "Video & Audio Extractor",
                        desc: isDe ? "Lädt Medien von über 1.000 Plattformen in höchster Qualität herunter." : "Downloads video and audio streams from over 1,000 supported platforms."
                    )
                    toolRow(
                        name: "ffmpeg",
                        status: isDe ? "Video- & Audio-Konverter" : "Media Processing Engine",
                        desc: isDe ? "Führt Video- und Audiospuren zusammen und konvertiert Streams zu sauberen MP4- bzw. MP3-Dateien." : "Muxes video and audio streams and converts formats seamlessly into MP4 or MP3."
                    )
                }
            }
            
            infoBox(
                title: isDe ? "Ein-Klick-Installation aus der App" : "One-Click In-App Installation",
                text: isDe ?
                    "Im Bereich 'System-Werkzeuge' in der linken Steuerleiste sehen Sie grüne Häkchen, wenn die Tools vorhanden sind. Falls etwas fehlt, erscheint ein Button 'Fehlende Tools installieren'. Ein Klick genügt, und die App installiert alles automatisch im Hintergrund über Homebrew!" :
                    "The 'System Tools' panel on the left displays green checkmarks when all dependencies are ready. If anything is missing, an 'Install Missing Tools' button appears to install everything automatically via Homebrew!",
                type: .tip
            )
        }
    }
    
    // MARK: - 9. FAQ & Fehlerbehebung / FAQ & Troubleshooting
    private var faqView: some View {
        let isDe = (langManager.currentLanguage == .de)
        return VStack(alignment: .leading, spacing: 16) {
            header(title: isDe ? "Häufige Fragen & Fehlerbehebung" : "Frequently Asked Questions (FAQ)", icon: "questionmark.circle.fill")
            
            faqItem(
                question: isDe ? "Warum werden auf einer Videoseite keine Videos gefunden?" : "Why are no videos found on a video portal page?",
                answer: isDe ?
                    "Stellen Sie sicher, dass 'Videos herunterladen' aktiv ist und die Suchtiefe auf mindestens 1 eingestellt ist. Viele Webseiten zeigen auf der Übersichtsseite nur Vorschaubilder, während die Videos auf den Unterseiten liegen." :
                    "Ensure 'Download Videos' is checked and Search Depth is set to at least 1. Most video portals display only thumbnails on their catalog pages; the actual players reside on linked watch pages."
            )
            
            faqItem(
                question: isDe ? "Was bedeutet 'Übersprungen: Ungültiger MIME-Typ'?" : "What does 'Skipped: Invalid MIME type' mean?",
                answer: isDe ?
                    "Der Server liefert an dieser URL kein Bild oder Video, sondern ein HTML-Dokument, Skript oder Tracking-Pixel. Die App filtert diese Dateien automatisch aus, um Ihren Speicherplatz zu schonen." :
                    "The web server delivered HTML text, a script, or an advertisement pixel rather than actual media. The crawler discards these files to conserve disk space."
            )
            
            faqItem(
                question: isDe ? "Warum lädt yt-dlp eine Datei nicht mit der Meldung 'unusual extension (php)'?" : "Why does yt-dlp refuse a link with 'unusual extension (php)'?",
                answer: isDe ?
                    "Manche Server leiten direkte Dateiaufrufe auf Validierungsskripte (z. B. remote_control.php) um. Geben Sie in einem solchen Fall nicht den direkten Serverpfad ein, sondern die normale Webadresse der Videoseite (/videos/...). Die App übergibt diese an den passenden yt-dlp-Extraktor." :
                    "Some web hosts redirect raw video requests to PHP validation scripts. In this case, provide the page's standard URL (e.g. `/videos/...`) rather than the raw `.mp4` link so yt-dlp uses its specialized extractor."
            )
            
            faqItem(
                question: isDe ? "Wo werden heruntergeladene Dateien abgelegt?" : "Where are downloaded files saved?",
                answer: isDe ?
                    "Im von Ihnen gewählten Zielordner. Wenn 'Nach Unterseiten strukturieren' aktiv ist, erstellt die App pro Unterseite einen eigenen Unterordner. Im Zielordner liegt auch eine unsichtbare Datei `.download_history.json`, die bereits geladene Dateien für zukünftige Durchläufe merkt." :
                    "In the directory you selected under 'Destination Folder'. If 'Organize by Subpages' is checked, subfolders are created per page. The directory also contains a hidden `.download_history.json` file remembering already downloaded files."
            )
            
            faqItem(
                question: isDe ? "Wie kann ich die Merkliste bereits geladener Dateien zurücksetzen?" : "How do I reset or clear the download history?",
                answer: isDe ?
                    "Klicken Sie in der linken Leiste unter 'Doppelte Dateien verhindern' auf den blauen Link 'Merkliste verwalten & zurücksetzen...'. Im Dialogfenster können Sie wählen, ob Sie alle Einträge löschen möchten oder gezielt nach Datum (z. B. nur heutige Downloads, die letzten 7 Tage oder ein Wunschdatum)." :
                    "Click 'Manage & Reset Download History...' in the crawler options card on the left. In the sheet, choose between completely clearing the history or pruning by date (e.g. today's downloads, last 7 days, or a custom calendar date)."
            )
            
            faqItem(
                question: isDe ? "Welche Tastaturkurzbefehle gibt es?" : "Which keyboard shortcuts are supported?",
                answer: isDe ?
                    "• Cmd + ? : Dieses Hilfesystem öffnen\n• Cmd + Shift + L : Sprache umschalten (Deutsch / Englisch)\n• Cmd + Option + 1 : Deutsch aktivieren\n• Cmd + Option + 2 : Englisch aktivieren\n• Esc : Hilfefenster schließen" :
                    "• Cmd + ? : Open this help guide\n• Cmd + Shift + L : Toggle language (German / English)\n• Cmd + Option + 1 : Switch to German\n• Cmd + Option + 2 : Switch to English\n• Esc : Close help sheet"
            )
        }
    }
    
    // MARK: - UI Helper Components
    
    private func header(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(.bottom, 5)
    }
    
    private func card<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            Divider()
            content()
                .font(.subheadline)
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func stepRow(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func optionRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func toolRow(name: String, status: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text("– \(status)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.accentColor)
                Text(question)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Text(answer)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 24)
        }
        .padding(.vertical, 4)
    }
    
    private func infoBox(title: String, text: String, type: InfoType) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: type.icon)
                .font(.headline)
                .foregroundColor(type.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(type.color.opacity(0.08))
        .cornerRadius(8)
    }
    
    enum InfoType {
        case info, tip, warning
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .tip: return "lightbulb.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .tip: return .green
            case .warning: return .orange
            }
        }
    }
}
