import SwiftUI
import AppKit
import Combine

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp: String
    let message: String
    let type: LogType
    
    enum LogType: Hashable {
        case info, success, warning, error, system, ytdlp
    }
}

struct CrawlStats {
    var pagesCrawled = 0
    var imagesFound = 0
    var imagesDownloaded = 0
    var imagesSkipped = 0
    var bytesDownloaded: Int64 = 0
    var errors = 0
    
    var formattedBytes: String {
        let mb = Double(bytesDownloaded) / (1024.0 * 1024.0)
        return String(format: "%.2f MB", mb)
    }
}

struct ContentView: View {
    @ObservedObject private var langManager = LocalizationManager.shared
    
    // State variables
    @State private var startUrl = ""
    @State private var targetFolder = ""
    @State private var minSizeKB: Double = 50
    @State private var maxDepth = 0
    @State private var followExternal = false
    @State private var preventDuplicates = true
    @State private var structureByPage = true
    @State private var downloadImages = true
    @State private var downloadVideos = false
    @State private var downloadDocuments = false
    @State private var downloadAudios = false
    @State private var isSearchMode = false
    @State private var inputMode = 0 // 0 = Einzel-URL, 1 = Internet-Suche, 2 = URL-Liste
    @State private var urlListText = ""
    @State private var useChromeCookies = false
    @State private var searchResultsLimit = 10
    @State private var isPaused = false
    @State private var restrictToSite = ""
    @State private var maxConcurrentImageDownloads = 4
    @State private var maxConcurrentVideoDownloads = 2
    @State private var maxConcurrentDocumentDownloads = 4
    @State private var maxConcurrentAudioDownloads = 4
    
    // Dependency variables
    @State private var brewInstalled = false
    @State private var ytdlpInstalled = false
    @State private var ffmpegInstalled = false
    @State private var isInstallingDependencies = false
    
    // Process variables
    @State private var isCrawling = false
    @State private var stats = CrawlStats()
    @State private var logs: [LogEntry] = [
        LogEntry(timestamp: currentTimeString(), message: LocalizationManager.shared.currentLanguage == .de ? "Konsole bereit. Bitte geben Sie oben die Parameter ein und klicken Sie auf Start." : "Console ready. Please configure parameters and click Start.", type: .system)
    ]
    @State private var progressWidth: Double = 0.0
    @State private var activeCrawler: Crawler? = nil
    @State private var scrollWorkItem: DispatchWorkItem? = nil
    @State private var showHelpSheet = false
    @State private var showResetHistorySheet = false
    
    // UI Validation Errors
    @State private var urlError: String? = nil
    @State private var folderError: String? = nil
    
    var body: some View {
        HSplitView {
            // Left Column: Control Panel
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Text(loc("Einstellungen", "Settings"))
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        
                        // Language Switch Button
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
                        
                        Button(action: { showHelpSheet = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "questionmark.circle")
                                Text(loc("Hilfe", "Help"))
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                        .help(loc("Hilfesystem und Anleitung öffnen (Cmd + ?)", "Open help and guide (Cmd + ?)"))
                    }
                    
                    // Dependency Status Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc("System-Werkzeuge", "System Tools"))
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: brewInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(brewInstalled ? .green : .red)
                                Text("Homebrew")
                            }
                            HStack(spacing: 4) {
                                Image(systemName: ytdlpInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(ytdlpInstalled ? .green : .red)
                                Text("yt-dlp")
                            }
                            HStack(spacing: 4) {
                                Image(systemName: ffmpegInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(ffmpegInstalled ? .green : .red)
                                Text("ffmpeg")
                            }
                        }
                        .font(.caption)
                        
                        if !ytdlpInstalled || !ffmpegInstalled {
                            Button(action: installDependencies) {
                                HStack {
                                    if isInstallingDependencies {
                                        ProgressView()
                                            .controlSize(.small)
                                            .padding(.trailing, 5)
                                        Text(loc("Installiere...", "Installing..."))
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                        Text(loc("Fehlende Tools installieren", "Install Missing Tools"))
                                    }
                                }
                            }
                            .disabled(isInstallingDependencies || !brewInstalled)
                            
                            if !brewInstalled {
                                Text(loc("Homebrew fehlt. Bitte installieren Sie es zuerst von brew.sh", "Homebrew is missing. Please install it first from brew.sh"))
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        // URL / Search query input
                        // Input Mode Picker
                        VStack(alignment: .leading, spacing: 5) {
                            Text(loc("Eingabemodus", "Input Mode"))
                                .fontWeight(.semibold)
                            Picker("", selection: $inputMode) {
                                Text(loc("Einzel-URL", "Single URL")).tag(0)
                                Text(loc("Internet-Suche", "Web Search")).tag(1)
                                Text(loc("URL-Liste", "URL List")).tag(2)
                            }
                            .pickerStyle(.segmented)
                            .disabled(isCrawling)
                        }
                        
                        if inputMode == 0 {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(loc("Start-Webadresse (URL)", "Start URL"))
                                    .fontWeight(.semibold)
                                TextField("https://example.com", text: $startUrl)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(isCrawling)
                                if let urlError = urlError {
                                    Text(urlError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        } else if inputMode == 1 {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(loc("Suchbegriffe (Keywords)", "Search Keywords"))
                                    .fontWeight(.semibold)
                                TextField(loc("z.B. rote Sportwagen, Katzenbabys...", "e.g. sports cars, cute puppies..."), text: $startUrl)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(isCrawling)
                                if let urlError = urlError {
                                    Text(urlError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(loc("Maximale Anzahl Suchergebnisse (Seiten)", "Max Search Results (Pages)"))
                                    .fontWeight(.semibold)
                                Picker("", selection: $searchResultsLimit) {
                                    Text("5").tag(5)
                                    Text("10").tag(10)
                                    Text("20").tag(20)
                                    Text("30").tag(30)
                                    Text("50").tag(50)
                                }
                                .pickerStyle(.segmented)
                                .disabled(isCrawling)
                                
                                Text(loc("Suche einschränken auf Website (optional)", "Restrict search to website (optional)"))
                                    .fontWeight(.semibold)
                                    .padding(.top, 5)
                                TextField(loc("z.B. wikipedia.org oder youtube.com", "e.g. wikipedia.org or youtube.com"), text: $restrictToSite)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(isCrawling)
                            }
                            .padding(.bottom, 5)
                        } else {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(loc("URL-Liste (Eine URL pro Zeile)", "URL List (One URL per line)"))
                                    .fontWeight(.semibold)
                                TextEditor(text: $urlListText)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 100)
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                    )
                                    .disabled(isCrawling)
                                if let urlError = urlError {
                                    Text(urlError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        
                        // Folder Picker
                        VStack(alignment: .leading, spacing: 5) {
                            Text(loc("Zielordner (Lokal)", "Destination Folder (Local)"))
                                .fontWeight(.semibold)
                            HStack {
                                TextField(loc("/Pfad/zum/Zielordner", "/path/to/destination/folder"), text: $targetFolder)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(isCrawling)
                                Button(action: selectFolder) {
                                    Image(systemName: "folder.badge.plus")
                                    Text(loc("Suchen...", "Browse..."))
                                }
                                .disabled(isCrawling)
                            }
                            if let folderError = folderError {
                                Text(folderError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Form Row for Slider/Selections
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(loc("Minimale Dateigröße (KB)", "Minimum File Size (KB)"))
                                    .fontWeight(.semibold)
                                HStack {
                                    Slider(value: $minSizeKB, in: 0...1000, step: 10)
                                        .disabled(isCrawling)
                                    Text("\(Int(minSizeKB)) KB")
                                        .frame(width: 60, alignment: .trailing)
                                }
                                Text(loc("Filtert kleine Grafiken aus.", "Filters out tiny icons and graphics."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(loc("Suchtiefe", "Search Depth"))
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(maxDepth == 0 ? loc("0 (Nur Startseite)", "0 (Start page only)") : (maxDepth == 1 ? loc("1 Ebene", "1 Level") : (langManager.currentLanguage == .de ? "\(maxDepth) Ebenen" : "\(maxDepth) Levels")))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Slider(value: Binding(
                                        get: { Double(maxDepth) },
                                        set: { maxDepth = Int($0) }
                                    ), in: 0...1000, step: 1)
                                    .disabled(isCrawling)
                                    
                                    TextField("", value: Binding(
                                        get: { maxDepth },
                                        set: { maxDepth = min(1000, max(0, $0)) }
                                    ), format: .number)
                                    .frame(width: 46)
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.trailing)
                                    .disabled(isCrawling)
                                    
                                    Stepper("", value: $maxDepth, in: 0...1000)
                                        .labelsHidden()
                                        .disabled(isCrawling)
                                }
                                Text(loc("Wie tief Links gefolgt wird (0–1000).", "How deep links are followed (0–1000)."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        // Card 1: Dateitypen & Downloads
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text(loc("Dateitypen & Downloads", "File Types & Downloads"))
                                    .font(.headline)
                            }
                            
                            Divider()
                            
                            Toggle(loc("Bilder herunterladen", "Download Images"), isOn: $downloadImages)
                                .disabled(isCrawling)
                            Text(loc("Sucht und lädt Bilddateien (jpg, png, webp, etc.) herunter.", "Finds and downloads image files (jpg, png, webp, etc.)."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            
                            if downloadImages {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(loc("Gleichzeitige Bild-Downloads:", "Concurrent Image Downloads:"))
                                            .font(.subheadline)
                                        Slider(value: Binding(
                                            get: { Double(maxConcurrentImageDownloads) },
                                            set: { maxConcurrentImageDownloads = Int($0) }
                                        ), in: 1...10, step: 1)
                                        .frame(maxWidth: 160)
                                        .disabled(isCrawling)
                                        Text("\(maxConcurrentImageDownloads)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 25, alignment: .trailing)
                                    }
                                    Text(loc("Anzahl der parallel geladenen Bilder pro Seite (1–10).", "Number of parallel image downloads per page (1–10)."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                            }
                            
                            Divider()
                            
                            Toggle(loc("Videos herunterladen", "Download Videos"), isOn: $downloadVideos)
                                .disabled(isCrawling)
                            Text(loc("Sucht und lädt Videodateien (mp4, webm, etc.) sowie Plattform-Videos über yt-dlp herunter.", "Finds and downloads video files (mp4, webm, etc.) and platform videos via yt-dlp."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            
                            if downloadVideos {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(loc("Gleichzeitige Video-Downloads:", "Concurrent Video Downloads:"))
                                            .font(.subheadline)
                                        Slider(value: Binding(
                                            get: { Double(maxConcurrentVideoDownloads) },
                                            set: { maxConcurrentVideoDownloads = Int($0) }
                                        ), in: 1...4, step: 1)
                                        .frame(maxWidth: 160)
                                        .disabled(isCrawling)
                                        Text("\(maxConcurrentVideoDownloads)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 25, alignment: .trailing)
                                    }
                                    Text(loc("Anzahl der parallel laufenden yt-dlp Video-Downloads (1–4).", "Number of parallel yt-dlp video downloads (1–4)."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                                
                                Toggle(loc("Chrome-Cookies importieren", "Import Chrome Cookies"), isOn: $useChromeCookies)
                                    .disabled(isCrawling)
                                    .padding(.leading, 20)
                                Text(loc("Erlaubt den Zugriff auf Logins/Sitzungen aus Google Chrome. Wird bei Fehlern automatisch übersprungen.", "Allows access to logins/sessions from Google Chrome. Automatically skipped on errors."))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 40)
                            }
                            
                            Divider()
                            
                            Toggle(loc("Dokumente herunterladen", "Download Documents"), isOn: $downloadDocuments)
                                .disabled(isCrawling)
                            Text(loc("Sucht und lädt Dokumente (PDF, Office Word/Excel/PowerPoint, OpenDocument, RTF, CSV, EPUB, etc.) herunter.", "Finds and downloads documents (PDF, Office Word/Excel/PowerPoint, OpenDocument, RTF, CSV, EPUB, etc.)."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            
                            if downloadDocuments {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(loc("Gleichzeitige Dokument-Downloads:", "Concurrent Document Downloads:"))
                                            .font(.subheadline)
                                        Slider(value: Binding(
                                            get: { Double(maxConcurrentDocumentDownloads) },
                                            set: { maxConcurrentDocumentDownloads = Int($0) }
                                        ), in: 1...10, step: 1)
                                        .frame(maxWidth: 160)
                                        .disabled(isCrawling)
                                        Text("\(maxConcurrentDocumentDownloads)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 25, alignment: .trailing)
                                    }
                                    Text(loc("Anzahl der parallel geladenen Dokumente pro Seite (1–10).", "Number of parallel document downloads per page (1–10)."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                            }
                            
                            Divider()
                            
                            Toggle(loc("Audios herunterladen", "Download Audio"), isOn: $downloadAudios)
                                .disabled(isCrawling)
                            Text(loc("Sucht und lädt Audios (mp3, m4a, wav, flac, ogg, etc.) sowie Audio-Plattformen (ardsounds.de, ardaudiothek.de, podcasts.apple.com, etc.) herunter.", "Finds and downloads audio (mp3, m4a, wav, flac, ogg, etc.) and audio platforms (ardsounds.de, ardaudiothek.de, podcasts.apple.com, etc.)."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            
                            if downloadAudios {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(loc("Gleichzeitige Audio-Downloads:", "Concurrent Audio Downloads:"))
                                            .font(.subheadline)
                                        Slider(value: Binding(
                                            get: { Double(maxConcurrentAudioDownloads) },
                                            set: { maxConcurrentAudioDownloads = Int($0) }
                                        ), in: 1...10, step: 1)
                                        .frame(maxWidth: 160)
                                        .disabled(isCrawling)
                                        Text("\(maxConcurrentAudioDownloads)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .frame(width: 25, alignment: .trailing)
                                    }
                                    Text(loc("Anzahl der parallel geladenen Audios pro Seite (1–10).", "Number of parallel audio downloads per page (1–10)."))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 20)
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        
                        // Card 2: Crawler- & Speicher-Optionen
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.badge.gearshape")
                                    .foregroundColor(.accentColor)
                                Text(loc("Crawler- & Speicher-Optionen", "Crawler & Storage Options"))
                                    .font(.headline)
                            }
                            
                            Divider()
                            
                            Toggle(loc("Externe Links verfolgen", "Follow External Links"), isOn: $followExternal)
                                .disabled(isCrawling)
                            Text(loc("Erlaubt das Crawlen außerhalb des Start-Hosts.", "Allows crawling outside the start host."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            
                            Divider()
                            
                            Toggle(loc("Doppelte Dateien verhindern", "Prevent Duplicate Files"), isOn: $preventDuplicates)
                                .disabled(isCrawling)
                            Text(loc("Vergleicht Dateiinhalte (MD5-Hash), um Duplikate zu überspringen.", "Compares file contents (MD5 hash) to skip duplicates."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            
                            HStack {
                                Button(action: { showResetHistorySheet = true }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "arrow.counterclockwise.circle")
                                        Text(loc("Merkliste verwalten & zurücksetzen...", "Manage & Reset Download History..."))
                                    }
                                    .font(.subheadline)
                                }
                                .buttonStyle(.link)
                                .disabled(isCrawling || targetFolder.isEmpty)
                                .help(targetFolder.isEmpty ? loc("Wählen Sie zuerst einen Zielordner aus", "Please select a destination folder first") : loc("Bereinigt oder löscht die Liste bereits geladener Dateien", "Cleans or resets the history of downloaded files"))
                            }
                            .padding(.leading, 20)
                            .padding(.top, 2)
                            
                            Divider()
                            
                            Toggle(loc("Nach Unterseiten strukturieren", "Organize by Subpages"), isOn: $structureByPage)
                                .disabled(isCrawling)
                            Text(loc("Erstellt eigene Unterordner pro durchsuchter Unterseite.", "Creates dedicated subfolders for each crawled subpage."))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                        .frame(height: 10)
                    
                    // Buttons
                    HStack(spacing: 10) {
                        if !isCrawling {
                            Button(action: startCrawlingJob) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text(loc("Starten", "Start"))
                                }
                                .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                        } else {
                            Button(action: togglePauseJob) {
                                HStack {
                                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                    Text(isPaused ? loc("Fortsetzen", "Resume") : loc("Pausieren", "Pause"))
                                }
                                .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            
                            Button(action: cancelCrawlingJob) {
                                HStack {
                                    Image(systemName: "square.fill")
                                    Text(loc("Abbrechen", "Cancel"))
                                }
                                .frame(maxWidth: .infinity, minHeight: 30)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 320, maxWidth: 420)
            
            // Right Column: Dashboard & Logs
            VStack(alignment: .leading, spacing: 20) {
                Text(loc("Dashboard", "Dashboard"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Stats Grid
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]
                
                LazyVGrid(columns: columns, spacing: 12) {
                    StatBox(title: loc("Seiten durchsucht", "Pages Crawled"), value: "\(stats.pagesCrawled)", icon: "filemenu.and.selection")
                    StatBox(title: loc("Dateien gefunden", "Files Found"), value: "\(stats.imagesFound)", icon: "doc.on.doc")
                    StatBox(title: loc("Heruntergeladen", "Downloaded"), value: "\(stats.imagesDownloaded)", icon: "checkmark.circle", color: .green)
                    StatBox(title: loc("Übersprungen", "Skipped"), value: "\(stats.imagesSkipped)", icon: "line.3.horizontal.decrease.circle", color: .orange)
                    StatBox(title: loc("Datenmenge", "Data Volume"), value: stats.formattedBytes, icon: "externaldrive", color: .blue)
                    StatBox(title: loc("Fehler", "Errors"), value: "\(stats.errors)", icon: "exclamationmark.triangle", color: .red)
                }
                
                // Progress Bar
                if isCrawling {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progressWidth, total: 100)
                            .progressViewStyle(.linear)
                        HStack {
                            Text(loc("Verarbeite... (\(stats.pagesCrawled) Seiten, \(stats.imagesDownloaded) Dateien geladen)", "Processing... (\(stats.pagesCrawled) pages, \(stats.imagesDownloaded) files downloaded)"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.vertical, 5)
                }
                
                // Console Log Header
                HStack {
                    Text(loc("Protokoll", "Log Console"))
                        .font(.headline)
                    Spacer()
                    Button(loc("Leeren", "Clear"), action: clearLogs)
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                }
                
                // Monospace Console
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(logs) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("[\(entry.timestamp)]")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text(entry.message)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(colorForLog(entry.type))
                                }
                                .id(entry.id)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    }
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .border(Color.secondary.opacity(0.2), width: 1)
                    .onChange(of: logs) { oldValue, newValue in
                        if let last = newValue.last {
                            scrollWorkItem?.cancel()
                            let workItem = DispatchWorkItem {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                            scrollWorkItem = workItem
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            .padding(20)
            .frame(minWidth: 400)
        }
        .onAppear {
            checkDependencies()
        }
        .sheet(isPresented: $showHelpSheet) {
            HelpView(isPresented: $showHelpSheet)
        }
        .sheet(isPresented: $showResetHistorySheet) {
            ResetHistorySheet(
                targetFolder: targetFolder,
                isPresented: $showResetHistorySheet,
                onResetPerformed: { msg in
                    addLog(msg, type: .info)
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenHelpRequested"))) { _ in
            showHelpSheet = true
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { langManager.toggleLanguage() }) {
                    Label(langManager.currentLanguage == .de ? "🇬🇧 English" : "🇩🇪 Deutsch", systemImage: "globe")
                }
                .help(loc("Sprache wechseln (Englisch / Deutsch)", "Switch language (English / German)"))
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showHelpSheet = true }) {
                    Label(loc("Hilfe & Anleitung", "Help & Guide"), systemImage: "questionmark.circle")
                }
                .help(loc("Hilfesystem und Anleitung öffnen (Cmd + ?)", "Open help and guide (Cmd + ?)"))
            }
        }
    }
    
    // --- HELPER ACTIONS ---
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            self.targetFolder = panel.url?.path ?? ""
            self.folderError = nil
        }
    }
    
    private func clearLogs() {
        logs = [LogEntry(timestamp: currentTimeString(), message: loc("Konsole geleert.", "Console cleared."), type: .system)]
    }
    
    private func startCrawlingJob() {
        // Client side validation
        urlError = nil
        folderError = nil
        var hasErrors = false
        
        let finalIsSearchMode = (inputMode == 1)
        let finalIsListMode = (inputMode == 2)
        
        if finalIsSearchMode {
            if startUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                urlError = loc("Bitte geben Sie Suchbegriffe ein.", "Please enter search keywords.")
                hasErrors = true
            }
        } else if finalIsListMode {
            if urlListText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                urlError = loc("Bitte geben Sie mindestens eine URL ein.", "Please enter at least one URL.")
                hasErrors = true
            } else {
                let lines = urlListText.components(separatedBy: .newlines)
                var validCount = 0
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" {
                        validCount += 1
                    }
                }
                if validCount == 0 {
                    urlError = loc("Die URL-Liste enthält keine gültigen HTTP/HTTPS-Adressen.", "The URL list does not contain any valid HTTP/HTTPS addresses.")
                    hasErrors = true
                }
            }
        } else {
            if let url = URL(string: startUrl), url.scheme == "http" || url.scheme == "https" {
                // valid
            } else {
                urlError = loc("Bitte geben Sie eine gültige HTTP/HTTPS-Adresse ein.", "Please enter a valid HTTP/HTTPS address.")
                hasErrors = true
            }
        }
        
        if targetFolder.isEmpty {
            folderError = loc("Bitte wählen Sie einen Zielordner aus.", "Please select a destination folder.")
            hasErrors = true
        } else {
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: targetFolder, isDirectory: &isDir) || !isDir.boolValue {
                // If it doesn't exist, we will create it lazily, but let's make sure parent is writable
                let parentPath = (targetFolder as NSString).deletingLastPathComponent
                if !FileManager.default.isWritableFile(atPath: parentPath) {
                    folderError = loc("Ordnerpfad existiert nicht und übergeordneter Ordner ist nicht beschreibbar.", "Folder path does not exist and parent directory is not writable.")
                    hasErrors = true
                }
            } else if !FileManager.default.isWritableFile(atPath: targetFolder) {
                folderError = loc("Keine Schreibrechte im ausgewählten Ordner.", "No write permissions in the selected folder.")
                hasErrors = true
            }
        }
        
        if !downloadImages && !downloadVideos && !downloadDocuments && !downloadAudios {
            urlError = loc("Wählen Sie mindestens einen Dateityp (Bilder, Videos, Dokumente oder Audios) aus.", "Select at least one file type (Images, Videos, Documents, or Audio).")
            hasErrors = true
        }
        
        if hasErrors {
            addLog(loc("Validierungsfehler: Eingaben prüfen.", "Validation error: Check your inputs."), type: .error)
            return
        }
        
        isCrawling = true
        isPaused = false
        stats = CrawlStats()
        logs = []
        progressWidth = 5.0
        
        let finalStartQuery: String
        if finalIsListMode {
            finalStartQuery = urlListText
            let urlCount = urlListText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            addLog(loc("Crawler gestartet für eine Liste von \(urlCount) URLs.", "Crawler started for a list of \(urlCount) URLs."), type: .info)
        } else if finalIsSearchMode && !restrictToSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanSite = extractHost(from: restrictToSite)
            finalStartQuery = "\(startUrl) site:\(cleanSite)"
            addLog(loc("Crawler gestartet in Suche für: '\(startUrl)' eingeschränkt auf Website: \(cleanSite)", "Crawler started search for: '\(startUrl)' restricted to website: \(cleanSite)"), type: .info)
        } else {
            finalStartQuery = startUrl
            if finalIsSearchMode {
                addLog(loc("Crawler gestartet in globaler Suche für: '\(startUrl)'", "Crawler started web search for: '\(startUrl)'"), type: .info)
            } else if let host = URL(string: startUrl)?.host {
                addLog(loc("Crawler gestartet. Starte Verbindung zu \(host)...", "Crawler started. Connecting to \(host)..."), type: .info)
            } else {
                addLog(loc("Crawler gestartet.", "Crawler started."), type: .info)
            }
        }
        
        let crawler = Crawler(
            startUrl: finalStartQuery,
            targetFolder: URL(fileURLWithPath: targetFolder),
            minSizeKB: minSizeKB,
            maxDepth: finalIsListMode ? 0 : maxDepth,
            followExternal: followExternal,
            preventDuplicates: preventDuplicates,
            structureByPage: structureByPage,
            downloadImages: downloadImages,
            downloadVideos: downloadVideos,
            downloadDocuments: downloadDocuments,
            downloadAudios: downloadAudios,
            isSearchMode: finalIsSearchMode,
            isListMode: finalIsListMode,
            useChromeCookies: useChromeCookies,
            searchResultsLimit: searchResultsLimit,
            maxConcurrentImageDownloads: maxConcurrentImageDownloads,
            maxConcurrentVideoDownloads: maxConcurrentVideoDownloads,
            maxConcurrentDocumentDownloads: maxConcurrentDocumentDownloads,
            maxConcurrentAudioDownloads: maxConcurrentAudioDownloads
        )
        
        self.activeCrawler = crawler
        
        // Listen to callbacks from crawler
        crawler.onLog = { msg, type in
            DispatchQueue.main.async {
                self.addLog(msg, type: type)
            }
        }
        
        crawler.onStatsUpdate = { newStats in
            DispatchQueue.main.async {
                self.stats = newStats
                // Animate progress width
                if self.progressWidth < 90 {
                    self.progressWidth += 2
                }
            }
        }
        
        // Run in background task
        Task {
            await crawler.start()
            
            DispatchQueue.main.async {
                self.isCrawling = false
                self.isPaused = false
                self.progressWidth = 100.0
                if crawler.isCancelled {
                    self.addLog(loc("Crawler vom Benutzer abgebrochen.", "Crawler cancelled by user."), type: .warning)
                } else if crawler.hasFailed {
                    self.addLog(loc("Crawler fehlgeschlagen.", "Crawler failed."), type: .error)
                } else {
                    self.addLog(loc("Crawler-Job erfolgreich beendet! \(self.stats.imagesDownloaded) Dateien geladen.", "Crawler job finished successfully! \(self.stats.imagesDownloaded) files downloaded."), type: .success)
                }
                self.activeCrawler = nil
            }
        }
    }
    
    private func togglePauseJob() {
        if let crawler = activeCrawler {
            if isPaused {
                crawler.resume()
                isPaused = false
            } else {
                crawler.pause()
                isPaused = true
            }
        }
    }
    
    private func cancelCrawlingJob() {
        if let crawler = activeCrawler {
            addLog(loc("Abbruch-Signal gesendet...", "Cancellation signal sent..."), type: .info)
            crawler.cancel()
        }
    }
    
    private func addLog(_ message: String, type: LogEntry.LogType) {
        logs.append(LogEntry(timestamp: currentTimeString(), message: message, type: type))
    }
    
    private func colorForLog(_ type: LogEntry.LogType) -> Color {
        switch type {
        case .info: return .primary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .system: return .secondary
        case .ytdlp: return .blue
        }
    }
    
    private func extractHost(from urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        
        var urlToParse = trimmed
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            urlToParse = "https://" + trimmed
        }
        
        if let url = URL(string: urlToParse), let host = url.host {
            return host
        }
        
        return trimmed
    }
    
    private func checkDependencies() {
        let fileManager = FileManager.default
        let paths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        
        self.brewInstalled = paths.contains { fileManager.fileExists(atPath: "\($0)/brew") }
        self.ytdlpInstalled = paths.contains { fileManager.fileExists(atPath: "\($0)/yt-dlp") }
        self.ffmpegInstalled = paths.contains { fileManager.fileExists(atPath: "\($0)/ffmpeg") }
    }
    
    private func getBrewPath() -> String? {
        let fileManager = FileManager.default
        let standardPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return standardPaths.first { fileManager.fileExists(atPath: $0) }
    }
    
    private func installDependencies() {
        guard let brewPath = getBrewPath() else {
            addLog("Homebrew wurde nicht gefunden. Bitte installieren Sie Homebrew von https://brew.sh", type: .warning)
            return
        }
        
        isInstallingDependencies = true
        addLog("Starte automatische Installation von yt-dlp und ffmpeg über Homebrew...", type: .info)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: brewPath)
        task.arguments = ["install", "yt-dlp", "ffmpeg"]
        
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath
        task.environment = env
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        
        Task {
            do {
                try task.run()
                
                while task.isRunning {
                    if let data = try? fileHandle.read(upToCount: 512), !data.isEmpty,
                       let output = String(data: data, encoding: .utf8) {
                        let lines = output.components(separatedBy: .newlines)
                        for line in lines {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                addLog("[Homebrew] \(trimmed)", type: .info)
                            }
                        }
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                
                if let remainingData = try? fileHandle.readToEnd(), !remainingData.isEmpty,
                   let output = String(data: remainingData, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            addLog("[Homebrew] \(trimmed)", type: .info)
                        }
                    }
                }
                
                task.waitUntilExit()
                
                DispatchQueue.main.async {
                    self.isInstallingDependencies = false
                    self.checkDependencies()
                    if self.ytdlpInstalled && self.ffmpegInstalled {
                        self.addLog("Installation erfolgreich abgeschlossen!", type: .success)
                    } else {
                        self.addLog("Installation abgeschlossen. Bitte überprüfen Sie, ob Fehler aufgetreten sind.", type: .warning)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstallingDependencies = false
                    self.addLog("Fehler beim Ausführen von brew: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }
}

// Helper: current time format
func currentTimeString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: Date())
}

// Subview: Stats Box
struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .primary
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color.opacity(0.8))
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .border(Color.secondary.opacity(0.1), width: 1)
    }
}

// MARK: - Reset History Sheet View

struct ResetHistorySheet: View {
    let targetFolder: String
    @Binding var isPresented: Bool
    var onResetPerformed: ((String) -> Void)?
    
    @ObservedObject private var langManager = LocalizationManager.shared
    
    @State private var summary: HistorySummary = HistorySummary(exists: false, totalRecords: 0, totalUrls: 0, totalHashes: 0, oldestDate: nil, newestDate: nil)
    @State private var resetMode: ResetMode = .byDate
    @State private var quickInterval: QuickInterval = .today
    @State private var direction: DateResetDirection = .after
    @State private var customDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var previewDeleted: Int = 0
    @State private var previewRemaining: Int = 0
    @State private var showConfirmDialog: Bool = false
    
    enum ResetMode: String, CaseIterable, Identifiable {
        case byDate
        case all
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .byDate: return loc("Nach Datum / Zeitraum", "Reset by Date / Range")
            case .all: return loc("Vollständig löschen", "Reset Completely")
            }
        }
    }
    
    enum QuickInterval: String, CaseIterable, Identifiable {
        case today
        case last24h
        case last7d
        case last30d
        case custom
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .today: return loc("Heute", "Today")
            case .last24h: return loc("Letzte 24 Std.", "Last 24 Hours")
            case .last7d: return loc("Letzte 7 Tage", "Last 7 Days")
            case .last30d: return loc("Letzte 30 Tage", "Last 30 Days")
            case .custom: return loc("Kalender / Frei", "Custom Date")
            }
        }
    }
    
    private var folderURL: URL {
        URL(fileURLWithPath: targetFolder)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 16) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("Merkliste & Download-Verlauf verwalten", "Manage & Reset Download History"))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(loc("Bereinigen oder löschen Sie gemerkte URLs und Dateiinhalte im Zielordner.", "Clean up or delete remembered URLs and file contents in the destination folder."))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(loc("Schließen", "Close")) {
                    isPresented = false
                }
                .controlSize(.regular)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    // Card 1: Target Folder & Current Status
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "folder.fill")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc("Zielordner:", "Destination Folder:"))
                                    .font(.headline)
                                Text(targetFolder)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 2)
                        
                        if summary.exists && summary.totalRecords > 0 {
                            HStack(spacing: 28) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(loc("Gespeicherte Einträge", "Saved Records"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("\(summary.totalRecords)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.accentColor)
                                }
                                
                                Divider()
                                    .frame(height: 38)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(loc("Ältester Download", "Oldest Download"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatDate(summary.oldestDate))
                                        .font(.body)
                                        .fontWeight(.semibold)
                                }
                                
                                Divider()
                                    .frame(height: 38)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(loc("Neuester Download", "Newest Download"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(formatDate(summary.newestDate))
                                        .font(.body)
                                        .fontWeight(.semibold)
                                }
                                
                                Spacer()
                            }
                        } else {
                            HStack(spacing: 10) {
                                Image(systemName: "info.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.orange)
                                Text(loc("In diesem Zielordner ist aktuell noch keine Merkliste (.download_history.json) vorhanden.", "No download history (.download_history.json) found in this destination folder yet."))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(18)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                    
                    if summary.exists && summary.totalRecords > 0 {
                        // Card 2: Method selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text(loc("Löschmethode auswählen", "Select Reset Method"))
                                .font(.headline)
                            
                            Picker("", selection: $resetMode) {
                                ForEach(ResetMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.regular)
                            .onChange(of: resetMode) { _, _ in updatePreview() }
                            
                            if resetMode == .byDate {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(loc("Zeitraum auswählen:", "Select Timeframe:"))
                                        .font(.headline)
                                    
                                    Picker("", selection: $quickInterval) {
                                        ForEach(QuickInterval.allCases) { interval in
                                            Text(interval.title).tag(interval)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .controlSize(.regular)
                                    .onChange(of: quickInterval) { _, _ in updatePreview() }
                                    
                                    if quickInterval == .custom {
                                        DatePicker(
                                            loc("Stichtag (Datum & Uhrzeit):", "Cutoff (Date & Time):"),
                                            selection: $customDate,
                                            displayedComponents: [.date, .hourAndMinute]
                                        )
                                        .font(.body)
                                        .datePickerStyle(.compact)
                                        .onChange(of: customDate) { _, _ in updatePreview() }
                                        .padding(.vertical, 4)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(loc("Filter-Richtung:", "Filter Direction:"))
                                            .font(.headline)
                                        Picker("", selection: $direction) {
                                            ForEach(DateResetDirection.allCases) { dir in
                                                Text(dir.title)
                                                    .font(.body)
                                                    .tag(dir)
                                            }
                                        }
                                        .pickerStyle(.radioGroup)
                                        .onChange(of: direction) { _, _ in updatePreview() }
                                    }
                                    .padding(.top, 4)
                                }
                            } else {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                    Text(loc("Alle gemerkten Downloads in diesem Ordner werden vollständig gelöscht. Bei nachfolgenden Durchläufen werden alle Dateien wieder heruntergeladen.", "All remembered downloads in this folder will be completely erased. Subsequent crawls will re-download all files."))
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .padding(18)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        
                        // Card 3: Preview Box
                        HStack(spacing: 16) {
                            Image(systemName: previewDeleted > 0 ? "trash.circle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(previewDeleted > 0 ? .orange : .green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc("Vorschau der Bereinigung", "Cleanup Preview"))
                                    .font(.headline)
                                if previewDeleted > 0 {
                                    Text(loc("**\(previewDeleted)** von \(summary.totalRecords) Einträgen werden gelöscht (**\(previewRemaining)** verbleiben in der Merkliste).", "**\(previewDeleted)** of \(summary.totalRecords) entries will be deleted (**\(previewRemaining)** will remain in history)."))
                                        .font(.body)
                                        .foregroundColor(.primary)
                                } else {
                                    Text(loc("Keine Einträge entsprechen dem gewählten Zeitraum (0 zu löschen).", "No entries match the selected timeframe (0 to delete)."))
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
            
            // Bottom Action Bar
            HStack(spacing: 12) {
                Spacer()
                Button(loc("Abbrechen", "Cancel")) {
                    isPresented = false
                }
                .controlSize(.large)
                .padding(.horizontal, 4)
                
                Button(action: { showConfirmDialog = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: resetMode == .all ? "trash.fill" : "arrow.counterclockwise")
                        Text(resetMode == .all ? loc("Vollständig löschen", "Delete Completely") : loc("Ausgewählte Einträge löschen", "Delete Selected Entries"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(resetMode == .all ? .red : .orange)
                .disabled(!summary.exists || summary.totalRecords == 0 || previewDeleted == 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 580, idealHeight: 640)
        .onAppear {
            loadSummary()
        }
        .confirmationDialog(
            loc("Merkliste wirklich zurücksetzen?", "Reset download history?"),
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button(resetMode == .all ? loc("Ja, vollständig löschen", "Yes, delete completely") : loc("Ja, \(previewDeleted) Einträge löschen", "Yes, delete \(previewDeleted) entries"), role: .destructive) {
                performReset()
            }
            Button(loc("Abbrechen", "Cancel"), role: .cancel) {}
        } message: {
            Text(resetMode == .all ?
                 loc("Möchten Sie wirklich alle \(summary.totalRecords) gemerkten Dateien aus der Historie löschen? Diese werden bei künftigen Downloads erneut geladen.", "Do you really want to delete all \(summary.totalRecords) records from the history? They will be re-downloaded in future crawls.") :
                 loc("Möchten Sie wirklich \(previewDeleted) Einträge aus der Merkliste löschen? \(previewRemaining) Einträge bleiben erhalten.", "Do you really want to delete \(previewDeleted) entries from the history? \(previewRemaining) entries will be kept."))
        }
    }
    
    private func loadSummary() {
        summary = DownloadHistoryManager.getSummary(for: folderURL)
        updatePreview()
    }
    
    private func computeCutoffDate() -> Date {
        let now = Date()
        switch quickInterval {
        case .today:
            return Calendar.current.startOfDay(for: now)
        case .last24h:
            return now.addingTimeInterval(-24 * 3600)
        case .last7d:
            return now.addingTimeInterval(-7 * 24 * 3600)
        case .last30d:
            return now.addingTimeInterval(-30 * 24 * 3600)
        case .custom:
            return customDate
        }
    }
    
    private func updatePreview() {
        guard summary.exists, summary.totalRecords > 0 else {
            previewDeleted = 0
            previewRemaining = 0
            return
        }
        if resetMode == .all {
            previewDeleted = summary.totalRecords
            previewRemaining = 0
        } else {
            let cutoff = computeCutoffDate()
            let (del, rem) = DownloadHistoryManager.previewResetByDate(in: folderURL, cutoff: cutoff, direction: direction)
            previewDeleted = del
            previewRemaining = rem
        }
    }
    
    private func performReset() {
        if resetMode == .all {
            let deleted = DownloadHistoryManager.resetAll(in: folderURL)
            onResetPerformed?(loc("Merkliste vollständig zurückgesetzt: Alle \(deleted) Einträge im Zielordner gelöscht.", "Download history completely reset: All \(deleted) records deleted in destination folder."))
        } else {
            let cutoff = computeCutoffDate()
            let (deleted, remaining) = DownloadHistoryManager.resetByDate(in: folderURL, cutoff: cutoff, direction: direction)
            onResetPerformed?(loc("Merkliste nach Datum bereinigt: \(deleted) Einträge gelöscht, \(remaining) Einträge verbleiben.", "Download history reset by date: \(deleted) records deleted, \(remaining) records remain."))
        }
        isPresented = false
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "–" }
        let formatter = DateFormatter()
        formatter.locale = (langManager.currentLanguage == .de ? Locale(identifier: "de_DE") : Locale(identifier: "en_US"))
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

