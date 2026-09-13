import Foundation
import CryptoKit
import Combine

actor DownloadTracker {
    private var historyData: DownloadHistoryData
    private var downloadedUrls: Set<String>
    private var downloadedHashes: Set<String>
    private var stats: CrawlStats
    private let targetFolder: URL
    private var onStatsUpdate: (@Sendable (CrawlStats) -> Void)?
    
    init(targetFolder: URL, initialHistory: DownloadHistoryData, initialStats: CrawlStats, onStatsUpdate: (@Sendable (CrawlStats) -> Void)?) {
        self.targetFolder = targetFolder
        self.historyData = initialHistory
        self.downloadedUrls = Set(initialHistory.downloadedUrls)
        self.downloadedHashes = Set(initialHistory.downloadedHashes)
        self.stats = initialStats
        self.onStatsUpdate = onStatsUpdate
    }
    
    func isUrlDownloaded(_ urlStr: String) -> Bool {
        return downloadedUrls.contains(urlStr)
    }
    
    func isHashDownloaded(_ hash: String) -> Bool {
        return downloadedHashes.contains(hash)
    }
    
    func recordFound(count: Int) {
        stats.imagesFound += count
        notifyStats()
    }
    
    func recordPageCrawled() {
        stats.pagesCrawled += 1
        notifyStats()
    }
    
    func recordSkipped() {
        stats.imagesSkipped += 1
        notifyStats()
    }
    
    func recordError() {
        stats.errors += 1
        notifyStats()
    }
    
    func recordSuccess(url: String, hash: String?, bytes: Int64) {
        stats.imagesDownloaded += 1
        stats.bytesDownloaded += bytes
        downloadedUrls.insert(url)
        if let h = hash {
            downloadedHashes.insert(h)
        }
        let record = DownloadHistoryRecord(url: url, hash: hash, timestamp: Date())
        historyData.records.append(record)
        historyData.downloadedUrls.append(url)
        if let h = hash {
            historyData.downloadedHashes.append(h)
        }
        notifyStats()
        saveHistory()
    }
    
    func recordVideoSuccess(url: String) {
        stats.imagesDownloaded += 1
        downloadedUrls.insert(url)
        let record = DownloadHistoryRecord(url: url, hash: nil, timestamp: Date())
        historyData.records.append(record)
        historyData.downloadedUrls.append(url)
        notifyStats()
        saveHistory()
    }
    
    func getStats() -> CrawlStats {
        return stats
    }
    
    private func notifyStats() {
        let current = stats
        onStatsUpdate?(current)
    }
    
    private func saveHistory() {
        DownloadHistoryManager.save(historyData, to: targetFolder)
    }
}

class Crawler: ObservableObject {
    let startUrl: String
    let targetFolder: URL
    let minSizeKB: Double
    let maxDepth: Int
    let followExternal: Bool
    let preventDuplicates: Bool
    let structureByPage: Bool
    let downloadImages: Bool
    let downloadVideos: Bool
    let downloadDocuments: Bool
    let downloadAudios: Bool
    let isSearchMode: Bool
    let isListMode: Bool
    let useChromeCookies: Bool
    let searchResultsLimit: Int
    let maxConcurrentImageDownloads: Int
    let maxConcurrentVideoDownloads: Int
    let maxConcurrentDocumentDownloads: Int
    let maxConcurrentAudioDownloads: Int
    
    // Cancellation and Pause state
    private(set) var isCancelled = false
    private(set) var hasFailed = false
    private(set) var isPaused = false
    
    // Stats and callbacks
    private var stats = CrawlStats()
    var onLog: (@Sendable (String, LogEntry.LogType) -> Void)?
    var onStatsUpdate: (@Sendable (CrawlStats) -> Void)?
    
    init(
        startUrl: String,
        targetFolder: URL,
        minSizeKB: Double,
        maxDepth: Int,
        followExternal: Bool,
        preventDuplicates: Bool,
        structureByPage: Bool,
        downloadImages: Bool,
        downloadVideos: Bool,
        downloadDocuments: Bool = false,
        downloadAudios: Bool = false,
        isSearchMode: Bool,
        isListMode: Bool,
        useChromeCookies: Bool,
        searchResultsLimit: Int,
        maxConcurrentImageDownloads: Int = 4,
        maxConcurrentVideoDownloads: Int = 2,
        maxConcurrentDocumentDownloads: Int = 4,
        maxConcurrentAudioDownloads: Int = 4
    ) {
        self.startUrl = startUrl
        self.targetFolder = targetFolder
        self.minSizeKB = minSizeKB
        self.maxDepth = maxDepth
        self.followExternal = followExternal
        self.preventDuplicates = preventDuplicates
        self.structureByPage = structureByPage
        self.downloadImages = downloadImages
        self.downloadVideos = downloadVideos
        self.downloadDocuments = downloadDocuments
        self.downloadAudios = downloadAudios
        self.isSearchMode = isSearchMode
        self.isListMode = isListMode
        self.useChromeCookies = useChromeCookies
        self.searchResultsLimit = searchResultsLimit
        self.maxConcurrentImageDownloads = maxConcurrentImageDownloads
        self.maxConcurrentVideoDownloads = maxConcurrentVideoDownloads
        self.maxConcurrentDocumentDownloads = maxConcurrentDocumentDownloads
        self.maxConcurrentAudioDownloads = maxConcurrentAudioDownloads
    }
    
    func cancel() {
        isCancelled = true
        isPaused = false // Resume if paused to exit cleanly
        log("Crawler-Abbruch angefordert...", type: .warning)
    }
    
    func pause() {
        isPaused = true
        log("Crawler pausiert.", type: .warning)
    }
    
    func resume() {
        isPaused = false
        log("Crawler fortgesetzt.", type: .info)
    }
    
    // --- MAIN ENGINE ---
    
    func start() async {
        var visitedUrls = Set<String>()
        let historyData = loadDownloadHistory()
        
        let tracker = DownloadTracker(
            targetFolder: targetFolder,
            initialHistory: historyData,
            initialStats: stats,
            onStatsUpdate: onStatsUpdate
        )
        var queue = [(url: URL, depth: Int)]()
        
        var domain = "localhost"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateStr = formatter.string(from: Date())
        
        if isListMode {
            log("Verarbeite URL-Liste...", type: .info)
            let lines = startUrl.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    if let url = URL(string: trimmed) {
                        queue.append((url, 0))
                    } else {
                        log("Ignoriere ungültige URL in Liste: \(trimmed)", type: .warning)
                    }
                }
            }
            domain = "url_liste"
        } else if isSearchMode {
            log("Führe globale Internet-Suche nach Begriffen: '\(startUrl)' durch...", type: .info)
            guard let encodedQuery = startUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                log("Fehler beim Erstellen der Suchanfragen-URL.", type: .error)
                hasFailed = true
                return
            }
            
            var resultUrls = [URL]()
            var searchHtml = ""
            var searchSuccess = false
            
            // Try DuckDuckGo first
            if let searchUrl = URL(string: "https://html.duckduckgo.com/html/?q=\(encodedQuery)") {
                do {
                    log("Lade Suchergebnisse von DuckDuckGo...", type: .info)
                    searchHtml = try await fetchHTML(from: searchUrl)
                    if searchHtml.contains("anomaly-modal") {
                        log("DuckDuckGo fordert ein CAPTCHA. Weiche auf Yahoo-Suche aus...", type: .warning)
                    } else {
                        resultUrls = parseDuckDuckGoResults(html: searchHtml)
                        searchSuccess = true
                    }
                } catch {
                    log("DuckDuckGo-Abfrage fehlgeschlagen (HTTP-Fehler oder blockiert). Weiche auf Yahoo-Suche aus...", type: .warning)
                }
            }
            
            // Fallback to Yahoo Search if DuckDuckGo failed or was blocked
            if !searchSuccess {
                if let yahooUrl = URL(string: "https://search.yahoo.com/search?q=\(encodedQuery)") {
                    do {
                        log("Lade Suchergebnisse von Yahoo Search...", type: .info)
                        searchHtml = try await fetchHTML(from: yahooUrl)
                        resultUrls = parseYahooResults(html: searchHtml)
                        searchSuccess = true
                    } catch {
                        log("Fehler beim Abrufen der Yahoo-Suchergebnisse: \(error.localizedDescription)", type: .error)
                        hasFailed = true
                        return
                    }
                }
            }
            
            // Extract restricted site if present (e.g. site:domain)
            var restrictedHost: String? = nil
            if let range = startUrl.range(of: " site:") {
                restrictedHost = String(startUrl[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
            
            // Filter results to remove search engine domains and apply site restriction
            var filteredUrls = [URL]()
            for url in resultUrls {
                let host = url.host?.lowercased() ?? ""
                
                let isSearchEngine = host.contains("duckduckgo.com") || host.contains("yahoo.com") || host.contains("yahoo.net") || host.contains("yimg.com") || host.contains("yahooapis.com") || host.contains("live.com") || host.contains("bing.com")
                if isSearchEngine { continue }
                
                if let restricted = restrictedHost {
                    let cleanHost = host.replacingOccurrences(of: "www.", with: "")
                    let cleanRestricted = restricted.replacingOccurrences(of: "www.", with: "")
                    if cleanHost != cleanRestricted && !cleanHost.hasSuffix("." + cleanRestricted) {
                        continue
                    }
                }
                
                filteredUrls.append(url)
            }
            
            let uniqueResults = Array(Set(filteredUrls)).prefix(searchResultsLimit)
            if uniqueResults.isEmpty {
                log("Keine Suchergebnisse für '\(startUrl)' gefunden.", type: .warning)
                hasFailed = true
                return
            }
            
            log("\(uniqueResults.count) Suchergebnisse gefunden. Starte Crawling dieser Seiten...", type: .info)
            for resUrl in uniqueResults {
                queue.append((resUrl, 0))
            }
            domain = "suche_" + startUrl.lowercased()
                .replacingOccurrences(of: "[^a-z0-9]", with: "_", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            if domain.count > 30 {
                domain = String(domain.prefix(30))
            }
        } else {
            guard let url = URL(string: startUrl) else {
                log("Ungültige Start-URL: \(startUrl)", type: .error)
                hasFailed = true
                return
            }
            queue.append((url, 0))
            domain = url.host ?? "localhost"
        }
        
        let seriesFolderName = "\(domain.replacingOccurrences(of: "www.", with: ""))_\(dateStr)"
        let jobTargetFolder = targetFolder.appendingPathComponent(seriesFolderName)
        
        log("Ziel-Ordnerpfad für diese Serie: \(jobTargetFolder.path)", type: .info)
        log("Parallelität: max. \(maxConcurrentImageDownloads) Bilder, max. \(maxConcurrentAudioDownloads) Audios, max. \(maxConcurrentDocumentDownloads) Dokumente, max. \(maxConcurrentVideoDownloads) Videos gleichzeitig.", type: .info)
        if isListMode {
            log("Crawler gestartet im URL-Listen-Modus. \(queue.count) URLs geladen, Minimale Größe: \(Int(minSizeKB)) KB, Bilder: \(downloadImages ? "Ja" : "Nein"), Audios: \(downloadAudios ? "Ja" : "Nein"), Dokumente: \(downloadDocuments ? "Ja" : "Nein"), Videos: \(downloadVideos ? "Ja" : "Nein")", type: .info)
        } else if isSearchMode {
            log("Crawler gestartet. Suchbegriff: \(startUrl), Minimale Größe: \(Int(minSizeKB)) KB, Max. Tiefe: \(maxDepth), Bilder: \(downloadImages ? "Ja" : "Nein"), Audios: \(downloadAudios ? "Ja" : "Nein"), Dokumente: \(downloadDocuments ? "Ja" : "Nein"), Videos: \(downloadVideos ? "Ja" : "Nein")", type: .info)
        } else {
            log("Crawler gestartet. Start-URL: \(startUrl), Minimale Größe: \(Int(minSizeKB)) KB, Max. Tiefe: \(maxDepth), Bilder: \(downloadImages ? "Ja" : "Nein"), Audios: \(downloadAudios ? "Ja" : "Nein"), Dokumente: \(downloadDocuments ? "Ja" : "Nein"), Videos: \(downloadVideos ? "Ja" : "Nein")", type: .info)
        }
        
        // Fast-path for URL-List Mode when downloading ONLY videos
        if isListMode && downloadVideos && !downloadImages && !downloadDocuments && !downloadAudios {
            let videoUrls = queue.map { $0.url }
            queue.removeAll()
            
            log("Starte parallele Video-Downloads für \(videoUrls.count) URLs (max. \(maxConcurrentVideoDownloads) gleichzeitig)...", type: .info)
            
            let concurrency = max(1, maxConcurrentVideoDownloads)
            await withTaskGroup(of: Void.self) { group in
                var activeCount = 0
                for url in videoUrls {
                    if self.isCancelled { break }
                    while self.isPaused && !self.isCancelled {
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                    if self.isCancelled { break }
                    
                    if activeCount >= concurrency {
                        await group.next()
                        activeCount -= 1
                    }
                    
                    if self.isCancelled { break }
                    
                    let urlStr = url.absoluteString
                    if visitedUrls.contains(urlStr) { continue }
                    visitedUrls.insert(urlStr)
                    
                    activeCount += 1
                    group.addTask {
                        await self.processVideoItem(
                            url: url,
                            jobTargetFolder: jobTargetFolder,
                            tracker: tracker
                        )
                    }
                }
                await group.waitForAll()
            }
            
            self.stats = await tracker.getStats()
            self.triggerStatsUpdate()
            log("Alle Einträge der URL-Liste wurden verarbeitet.", type: .success)
            return
        }
        
        while !queue.isEmpty && !isCancelled {
            if isPaused {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                continue
            }
            
            // Check if next items in queue are video platforms
            if downloadVideos, let first = queue.first, (self.isVideoPlatform(url: first.url) || self.hasVideoExtension(url: first.url)) {
                var videoBatch = [URL]()
                while !queue.isEmpty, let next = queue.first, (self.isVideoPlatform(url: next.url) || self.hasVideoExtension(url: next.url)) {
                    videoBatch.append(queue.removeFirst().url)
                }
                
                log("Verarbeite \(videoBatch.count) gefundene Video-Links (max. \(maxConcurrentVideoDownloads) gleichzeitig)...", type: .info)
                let concurrency = max(1, maxConcurrentVideoDownloads)
                await withTaskGroup(of: Void.self) { group in
                    var activeCount = 0
                    for vUrl in videoBatch {
                        if self.isCancelled { break }
                        while self.isPaused && !self.isCancelled {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                        }
                        if self.isCancelled { break }
                        
                        if activeCount >= concurrency {
                            await group.next()
                            activeCount -= 1
                        }
                        
                        if self.isCancelled { break }
                        
                        let urlStr = vUrl.absoluteString
                        if visitedUrls.contains(urlStr) { continue }
                        visitedUrls.insert(urlStr)
                        
                        activeCount += 1
                        group.addTask {
                            await self.processVideoItem(
                                url: vUrl,
                                jobTargetFolder: jobTargetFolder,
                                tracker: tracker
                            )
                        }
                    }
                    await group.waitForAll()
                }
                self.stats = await tracker.getStats()
                self.triggerStatsUpdate()
                continue
            }
            
            let current = queue.removeFirst()
            let url = current.url
            let depth = current.depth
            
            if visitedUrls.contains(url.absoluteString) { continue }
            visitedUrls.insert(url.absoluteString)
            
            log("Verarbeite URL: \(url.absoluteString) (Tiefe: \(depth)/\(maxDepth))", type: .info)
            await tracker.recordPageCrawled()
            
            let isAudioPlatform = downloadAudios && self.isAudioPlatform(url: url)
            let isVideoPlatform = downloadVideos && (isListMode || self.isVideoPlatform(url: url))
            if isVideoPlatform || isAudioPlatform {
                await processMediaPlatformItem(url: url, jobTargetFolder: jobTargetFolder, tracker: tracker, isAudioOnly: isAudioPlatform && !downloadVideos)
                self.stats = await tracker.getStats()
                self.triggerStatsUpdate()
                continue
            }
            
            let isDirectAudio = downloadAudios && self.hasAudioExtension(url: url)
            let isDirectDoc = downloadDocuments && self.hasDocumentExtension(url: url)
            let isDirectImg = downloadImages && self.hasImageExtension(url: url)
            let isDirectVid = downloadVideos && self.hasVideoExtension(url: url)
            
            if isDirectAudio || isDirectDoc || isDirectImg || (isDirectVid && !isVideoPlatform) {
                log("Direkte Datei-URL erkannt: \(url.absoluteString)", type: .info)
                await tracker.recordFound(count: 1)
                await downloadFile(url: url, targetFolder: jobTargetFolder, refererUrl: nil, tracker: tracker)
                self.stats = await tracker.getStats()
                self.triggerStatsUpdate()
                continue
            }
            
            do {
                let html = try await fetchHTML(from: url)
                
                let mediaUrls = parseMediaUrls(from: html, baseUrl: url)
                let fileConcurrency = max(1, max(
                    downloadImages ? maxConcurrentImageDownloads : 0,
                    downloadAudios ? maxConcurrentAudioDownloads : 0,
                    downloadDocuments ? maxConcurrentDocumentDownloads : 0
                ))
                log("\(mediaUrls.count) Medien-, Audio- und Dokument-URLs auf dieser Seite gefunden. Starte Downloads (max. \(fileConcurrency) gleichzeitig)...", type: .info)
                await tracker.recordFound(count: mediaUrls.count)
                
                // Determine folder for this page's files
                var pageFolder = jobTargetFolder
                if structureByPage {
                    let subpageName = getSubpageFolderName(pageUrl: url, startUrl: startUrl, html: html, isSearchMode: isSearchMode)
                    pageFolder = jobTargetFolder.appendingPathComponent(subpageName)
                }
                
                // Concurrent download of media and document files
                await withTaskGroup(of: Void.self) { group in
                    var activeCount = 0
                    for mediaUrl in mediaUrls {
                        if self.isCancelled { break }
                        while self.isPaused && !self.isCancelled {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                        }
                        if self.isCancelled { break }
                        
                        if activeCount >= fileConcurrency {
                            await group.next()
                            activeCount -= 1
                        }
                        
                        if self.isCancelled { break }
                        
                        activeCount += 1
                        group.addTask {
                            await self.downloadFile(
                                url: mediaUrl,
                                targetFolder: pageFolder,
                                refererUrl: url.absoluteString,
                                tracker: tracker
                            )
                        }
                    }
                    await group.waitForAll()
                }
                
                // Follow links if depth < maxDepth
                if depth < maxDepth {
                    let links = parseLinks(from: html, baseUrl: url)
                    for link in links {
                        let isHttp = link.scheme == "http" || link.scheme == "https"
                        let isSameHost: Bool
                        if isSearchMode {
                            isSameHost = self.isSameHost(link.host, url.host)
                        } else {
                            if let startUrlObj = URL(string: startUrl) {
                                isSameHost = self.isSameHost(link.host, startUrlObj.host)
                            } else {
                                isSameHost = self.isSameHost(link.host, url.host)
                            }
                        }
                        
                        if isHttp && (followExternal || isSameHost) {
                            let linkStr = link.absoluteString
                            if !visitedUrls.contains(linkStr) && !queue.contains(where: { $0.url.absoluteString == linkStr }) {
                                queue.append((link, depth + 1))
                            }
                        }
                    }
                }
                
            } catch {
                log("Fehler bei URL \(url.absoluteString): \(error.localizedDescription)", type: .error)
                await tracker.recordError()
            }
            
            self.stats = await tracker.getStats()
            self.triggerStatsUpdate()
        }
        
        self.stats = await tracker.getStats()
        self.triggerStatsUpdate()
    }
    
    // --- HELPER NETWORKING & PARSING ---
    
    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Crawler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ungültige HTTP-Antwort"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "Crawler", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP-Fehler \(httpResponse.statusCode)"])
        }
        
        if let html = String(data: data, encoding: .utf8) {
            return html
        } else if let html = String(data: data, encoding: .isoLatin1) {
            return html
        } else {
            throw NSError(domain: "Crawler", code: 2, userInfo: [NSLocalizedDescriptionKey: "Konnte HTML-Codierung nicht entschlüsseln"])
        }
    }
    
    private func extractMatches(in html: String, regex: String) -> [String] {
        guard let r = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else { return [] }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = r.matches(in: html, options: [], range: nsRange)
        return matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            let r = match.range(at: 1)
            guard let range = Range(r, in: html) else { return nil }
            return String(html[range])
        }
    }
    
    private func parseMediaUrls(from html: String, baseUrl: URL) -> [URL] {
        var urls = Set<String>()
        
        // 1. <img> tags
        if downloadImages {
            let imgMatches = extractMatches(in: html, regex: "<img[^>]+src=[\"']([^\"']+)[\"']")
            urls.formUnion(imgMatches)
            
            // 2. srcset inside <img> or <source>
            let srcsetMatches = extractMatches(in: html, regex: "srcset=[\"']([^\"']+)[\"']")
            for srcset in srcsetMatches {
                let parts = srcset.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                for part in parts {
                    if let first = part.components(separatedBy: " ").first, !first.isEmpty {
                        urls.insert(first)
                    }
                }
            }
            
            // 4. CSS inline style background-image
            let bgMatches = extractMatches(in: html, regex: "url\\(['\"]?([^'\")\\s]+)['\"]?\\)")
            urls.formUnion(bgMatches)
        }
        
        // 3. <source src="..."> for videos
        if downloadVideos {
            let sourceSrc = extractMatches(in: html, regex: "<source[^>]+src=[\"']([^\"']+)[\"']")
            urls.formUnion(sourceSrc)
            
            let videoSrc = extractMatches(in: html, regex: "<video[^>]+src=[\"']([^\"']+)[\"']")
            urls.formUnion(videoSrc)
            
            // 3b. <iframe> tags for embedded video platforms
            let iframeSrc = extractMatches(in: html, regex: "<iframe[^>]+src=[\"']([^\"']+)[\"']")
            for src in iframeSrc {
                let lower = src.lowercased()
                if lower.contains("youtube.com") || lower.contains("youtu.be") || lower.contains("vimeo.com") || lower.contains("dailymotion.com") {
                    urls.insert(src)
                }
            }
            
            // 3c. Extract hidden streaming manifests (.m3u8, .mpd) or direct video files from JS/raw text
            let manifestRegex = "(https?://[^\"'\\s<>]+?\\.(?:m3u8|mpd|mp4|webm|mov|avi|mkv|flv|wmv|m4v|3gp)(?:/[^\"'\\s<>]*)?(?:\\?[^\"'\\s<>]*)?)"
            if let r = try? NSRegularExpression(pattern: manifestRegex, options: [.caseInsensitive]) {
                let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
                let matches = r.matches(in: html, options: [], range: nsRange)
                for match in matches {
                    if let range = Range(match.range, in: html) {
                        let matchedStr = String(html[range])
                        urls.insert(matchedStr)
                    }
                }
            }
        }
        
        // 3d. <audio> tags and <source> inside <audio>
        if downloadAudios {
            let audioSrc = extractMatches(in: html, regex: "<audio[^>]+src=[\"']([^\"']+)[\"']")
            urls.formUnion(audioSrc)
            
            // Podcast and RSS enclosures: <enclosure url="..." type="audio/..." />
            let enclosureSrc = extractMatches(in: html, regex: "<enclosure[^>]+url=[\"']([^\"']+)[\"']")
            urls.formUnion(enclosureSrc)
            
            // Direct audio regex scanning (.mp3, .m4a, .aac, .flac, .wav, .ogg, .opus, etc.)
            let audioFileRegex = "(https?://[^\"'\\s<>]+?\\.(?:mp3|m4a|aac|wav|flac|ogg|oga|opus|wma|aiff|alac)(?:/[^\"'\\s<>]*)?(?:\\?[^\"'\\s<>]*)?)"
            if let r = try? NSRegularExpression(pattern: audioFileRegex, options: [.caseInsensitive]) {
                let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
                let matches = r.matches(in: html, options: [], range: nsRange)
                for match in matches {
                    if let range = Range(match.range, in: html) {
                        let matchedStr = String(html[range])
                        urls.insert(matchedStr)
                    }
                }
            }
        }
        
        // 4b. <embed> and <object> tags for documents (e.g. PDFs)
        if downloadDocuments {
            let embedSrc = extractMatches(in: html, regex: "<embed[^>]+src=[\"']([^\"']+)[\"']")
            for src in embedSrc {
                if let u = URL(string: src, relativeTo: baseUrl), self.hasDocumentExtension(url: u) {
                    urls.insert(src)
                }
            }
            let objectData = extractMatches(in: html, regex: "<object[^>]+data=[\"']([^\"']+)[\"']")
            for data in objectData {
                if let u = URL(string: data, relativeTo: baseUrl), self.hasDocumentExtension(url: u) {
                    urls.insert(data)
                }
            }
        }
        
        // 5. <a> tags with media, audio & document extensions
        let aHrefs = extractMatches(in: html, regex: "<a[^>]+href=[\"']([^\"']+)[\"']")
        for href in aHrefs {
            let isImg = downloadImages && href.range(of: "\\.(jpg|jpeg|png|gif|webp|avif|svg)(\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil
            let isVid = downloadVideos && href.range(of: "\\.(mp4|webm|ogg|ogv|mov|avi|mkv|flv|wmv|m4v|3gp)(\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil
            let isDoc = downloadDocuments && href.range(of: "\\.(pdf|docx?|docm?|dotx?|xlsx?|xlsm?|xltx?|xlsb|pptx?|pptm?|ppsx?|potx?|odt|ods|odp|odg|rtf|txt|csv|epub|mobi)(\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil
            let isAud = downloadAudios && href.range(of: "\\.(mp3|m4a|aac|wav|flac|ogg|oga|opus|wma|aiff|alac|weba)(\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil
            if isImg || isVid || isDoc || isAud {
                urls.insert(href)
            }
        }
        
        // Resolve relative URLs
        var resolvedUrls = [URL]()
        for urlStr in urls {
            if urlStr.hasPrefix("data:") { continue }
            if let resolved = URL(string: urlStr, relativeTo: baseUrl) {
                resolvedUrls.append(resolved.absoluteURL)
            }
        }
        
        return resolvedUrls
    }
    
    private func parseLinks(from html: String, baseUrl: URL) -> [URL] {
        var hrefs = extractMatches(in: html, regex: "<a[^>]+href=[\"']([^\"']+)[\"']")
        if downloadVideos {
            let iframeSrcs = extractMatches(in: html, regex: "<iframe[^>]+src=[\"']([^\"']+)[\"']")
            hrefs.append(contentsOf: iframeSrcs)
        }
        var urls = Set<URL>()
        for href in hrefs {
            if href.hasPrefix("#") || href.hasPrefix("javascript:") || href.hasPrefix("mailto:") || href.hasPrefix("tel:") { continue }
            if let resolved = URL(string: href, relativeTo: baseUrl) {
                var components = URLComponents(url: resolved.absoluteURL, resolvingAgainstBaseURL: false)
                components?.fragment = nil
                if let cleanUrl = components?.url {
                    // Do not follow links that are direct media or document downloads
                    if self.hasImageExtension(url: cleanUrl) || self.hasDocumentExtension(url: cleanUrl) || self.hasAudioExtension(url: cleanUrl) || (self.hasVideoExtension(url: cleanUrl) && !self.isVideoPlatform(url: cleanUrl)) {
                        continue
                    }
                    urls.insert(cleanUrl)
                }
            }
        }
        return Array(urls)
    }
    
    private func getSubpageFolderName(pageUrl: URL, startUrl: String, html: String, isSearchMode: Bool) -> String {
        let isHome: Bool
        if isSearchMode {
            isHome = false
        } else {
            if let startUrlObj = URL(string: startUrl) {
                isHome = pageUrl.absoluteString == startUrlObj.absoluteString || pageUrl.path == "/" || pageUrl.path.isEmpty
            } else {
                isHome = pageUrl.path == "/" || pageUrl.path.isEmpty
            }
        }
        
        if isHome {
            if let titleMatch = extractMatches(in: html, regex: "<title>([^<]+)</title>").first {
                let clean = titleMatch.replacingOccurrences(of: "[^a-zA-Z0-9_\\- ]", with: "_", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
                return clean.isEmpty ? "home" : String(clean.prefix(50))
            }
            return "home"
        }
        
        var relativePath = pageUrl.path
        if !isSearchMode, let startUrlObj = URL(string: startUrl), !self.isSameHost(pageUrl.host, startUrlObj.host) {
            relativePath = (pageUrl.host ?? "external") + relativePath
        } else if isSearchMode {
            relativePath = (pageUrl.host ?? "external") + relativePath
        }
        
        let clean = relativePath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .replacingOccurrences(of: "[^a-zA-Z0-9_\\-/]", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "/", with: "_")
        
        return clean.isEmpty ? "subpage" : String(clean.prefix(50))
    }
    
    private func parseDuckDuckGoResults(html: String) -> [URL] {
        var foundUrls = [URL]()
        let hrefs = extractMatches(in: html, regex: "<a[^>]+href=[\"']([^\"']+)[\"']")
        
        for href in hrefs {
            let cleanHref = href.replacingOccurrences(of: "&amp;", with: "&")
            if cleanHref.contains("uddg=") {
                if let components = URLComponents(string: cleanHref),
                   let uddgItem = components.queryItems?.first(where: { $0.name == "uddg" }),
                   let decodedVal = uddgItem.value,
                   let targetUrl = URL(string: decodedVal) {
                    foundUrls.append(targetUrl)
                }
            } else if !cleanHref.contains("duckduckgo.com") && (cleanHref.hasPrefix("http://") || cleanHref.hasPrefix("https://")) {
                if let targetUrl = URL(string: cleanHref) {
                    foundUrls.append(targetUrl)
                }
            }
        }
        return foundUrls
    }
    
    private func parseYahooResults(html: String) -> [URL] {
        var foundUrls = [URL]()
        let hrefs = extractMatches(in: html, regex: "<a[^>]+href=[\"']([^\"']+)[\"']")
        
        for href in hrefs {
            let cleanHref = href.replacingOccurrences(of: "&amp;", with: "&")
            if cleanHref.contains("/RU=") {
                if let ruRange = cleanHref.range(of: "/RU="), let rkRange = cleanHref.range(of: "/RK=") {
                    let startIdx = ruRange.upperBound
                    let endIdx = rkRange.lowerBound
                    let encodedUrl = String(cleanHref[startIdx..<endIdx])
                    if let decodedVal = encodedUrl.removingPercentEncoding,
                       let targetUrl = URL(string: decodedVal) {
                        foundUrls.append(targetUrl)
                    }
                } else if let ruRange = cleanHref.range(of: "/RU=") {
                    let startIdx = ruRange.upperBound
                    let encodedUrl = String(cleanHref[startIdx...])
                    let cleanEncoded = encodedUrl.components(separatedBy: "/").first ?? encodedUrl
                    if let decodedVal = cleanEncoded.removingPercentEncoding,
                       let targetUrl = URL(string: decodedVal) {
                        foundUrls.append(targetUrl)
                    }
                }
            } else if !cleanHref.contains("yahoo.com") && !cleanHref.contains("yimg.com") && (cleanHref.hasPrefix("http://") || cleanHref.hasPrefix("https://")) {
                if let targetUrl = URL(string: cleanHref) {
                    foundUrls.append(targetUrl)
                }
            }
        }
        return foundUrls
    }
    
    private func processMediaPlatformItem(url: URL, jobTargetFolder: URL, tracker: DownloadTracker, isAudioOnly: Bool = false) async {
        let urlStr = url.absoluteString
        let itemLabel = isAudioOnly ? "Audio" : "Video"
        if await tracker.isUrlDownloaded(urlStr) {
            log("Übersprungen: \(itemLabel) bereits im Verlauf - URL: \(urlStr)", type: .info)
            await tracker.recordSkipped()
            return
        }
        
        log("Übergebe an yt-dlp (\(itemLabel)): \(urlStr)", type: .info)
        
        var pageFolder = jobTargetFolder
        if structureByPage {
            let subpageName = getSubpageFolderName(pageUrl: url, startUrl: startUrl, html: "", isSearchMode: isSearchMode)
            pageFolder = jobTargetFolder.appendingPathComponent(subpageName)
        }
        
        let success = await downloadWithYtdlp(url: url, targetFolder: pageFolder, isAudioOnly: isAudioOnly)
        if success {
            log("\(itemLabel) erfolgreich verarbeitet: \(url.lastPathComponent)", type: .success)
            await tracker.recordVideoSuccess(url: urlStr)
        } else {
            log("yt-dlp Download fehlgeschlagen oder abgebrochen: \(url.lastPathComponent)", type: .warning)
            await tracker.recordError()
        }
    }
    
    private func processVideoItem(url: URL, jobTargetFolder: URL, tracker: DownloadTracker) async {
        await processMediaPlatformItem(url: url, jobTargetFolder: jobTargetFolder, tracker: tracker, isAudioOnly: false)
    }
    
    private func downloadFile(url: URL, targetFolder: URL, refererUrl: String?, tracker: DownloadTracker) async {
        let urlStr = url.absoluteString
        if await tracker.isUrlDownloaded(urlStr) {
            log("Übersprungen: Bereits heruntergeladen (Verlauf) - URL: \(urlStr)", type: .info)
            await tracker.recordSkipped()
            return
        }
        
        let isVideoPlatform = downloadVideos && (self.isVideoPlatform(url: url) || self.hasVideoExtension(url: url))
        if isVideoPlatform {
            let success = await downloadWithYtdlp(url: url, targetFolder: targetFolder, refererUrl: refererUrl)
            if success {
                await tracker.recordVideoSuccess(url: urlStr)
                return
            }
        }
        
        do {
            // Try HEAD request first for headers
            var headRequest = URLRequest(url: url)
            headRequest.httpMethod = "HEAD"
            headRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            if let ref = refererUrl {
                headRequest.setValue(ref, forHTTPHeaderField: "Referer")
            }
            
            var contentLength: Int64? = nil
            var mimeType: String? = nil
            
            if let (_, response) = try? await URLSession.shared.data(for: headRequest),
               let httpResponse = response as? HTTPURLResponse {
                if let lenHeader = httpResponse.value(forHTTPHeaderField: "Content-Length"), let len = Int64(lenHeader) {
                    contentLength = len
                }
                mimeType = httpResponse.mimeType
            }
            
            let minSizeBytes = Int64(minSizeKB * 1024)
            
            // Size filter check
            if let len = contentLength, len < minSizeBytes {
                log("Übersprungen: Datei ist zu klein (\(len / 1024) KB) - URL: \(urlStr)", type: .info)
                await tracker.recordSkipped()
                return
            }
            
            // MIME check
            if let mime = mimeType {
                let isImg = downloadImages && (mime.hasPrefix("image/") || (mime.contains("octet-stream") && self.hasImageExtension(url: url)))
                let isVid = downloadVideos && (mime.hasPrefix("video/") || (mime.contains("octet-stream") && self.hasVideoExtension(url: url)))
                let isDoc = downloadDocuments && self.isDocumentMime(mime, url: url)
                let isAud = downloadAudios && self.isAudioMime(mime, url: url)
                if !isImg && !isVid && !isDoc && !isAud {
                    log("Übersprungen: Ungültiger MIME-Typ (\(mime)) - URL: \(urlStr)", type: .info)
                    return
                }
            }
            
            // GET request
            var getRequest = URLRequest(url: url)
            getRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            if let ref = refererUrl {
                getRequest.setValue(ref, forHTTPHeaderField: "Referer")
            }
            
            let (data, response) = try await URLSession.shared.data(for: getRequest)
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            guard httpResponse.statusCode == 200 else {
                log("Fehler beim Laden von \(urlStr): HTTP \(httpResponse.statusCode)", type: .error)
                await tracker.recordError()
                return
            }
            
            let actualSize = Int64(data.count)
            if actualSize < minSizeBytes {
                log("Übersprungen: Datei ist zu klein (\(actualSize / 1024) KB) - URL: \(urlStr)", type: .info)
                await tracker.recordSkipped()
                return
            }
            
            let finalMime = httpResponse.mimeType ?? ""
            let isImg = downloadImages && (finalMime.hasPrefix("image/") || (finalMime.contains("octet-stream") && self.hasImageExtension(url: url)))
            let isVid = downloadVideos && (finalMime.hasPrefix("video/") || (finalMime.contains("octet-stream") && self.hasVideoExtension(url: url)))
            let isDoc = downloadDocuments && self.isDocumentMime(finalMime, url: url)
            let isAud = downloadAudios && self.isAudioMime(finalMime, url: url)
            if !finalMime.isEmpty && !isImg && !isVid && !isDoc && !isAud {
                log("Übersprungen: Ungültiger MIME-Typ (\(finalMime)) - URL: \(urlStr)", type: .info)
                return
            }
            
            // Duplicate content checking (MD5)
            var hashString: String? = nil
            if preventDuplicates {
                let hash = Insecure.MD5.hash(data: data)
                let computedHash = hash.map { String(format: "%02hhx", $0) }.joined()
                
                if await tracker.isHashDownloaded(computedHash) {
                    log("Übersprungen: Dateiinhalt ist ein Duplikat (MD5: \(computedHash)) - URL: \(urlStr)", type: .info)
                    await tracker.recordSkipped()
                    return
                }
                hashString = computedHash
            }
            
            let label = isVid ? "Video" : (isAud ? "Audio" : (isDoc ? "Dokument" : "Bild"))
            let ext = getExtension(fromMime: finalMime, url: url, isVideo: isVid, isDocument: isDoc, isAudio: isAud)
            var baseName = getFilename(from: url)
            if !baseName.lowercased().hasSuffix(ext) {
                baseName += ext
            }
            baseName = sanitizeFilename(baseName)
            
            // Lazy directory creation
            try FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true, attributes: nil)
            
            var fileUrl = targetFolder.appendingPathComponent(baseName)
            let nameOnly = (baseName as NSString).deletingPathExtension
            var counter = 1
            
            while FileManager.default.fileExists(atPath: fileUrl.path) {
                fileUrl = targetFolder.appendingPathComponent("\(nameOnly)_\(counter)\(ext)")
                counter += 1
            }
            
            try data.write(to: fileUrl)
            
            log("Gespeichert: \(label) - \(fileUrl.lastPathComponent) (\(actualSize / 1024) KB)", type: .success)
            await tracker.recordSuccess(url: urlStr, hash: hashString, bytes: actualSize)
            
        } catch {
            log("Fehler beim Herunterladen von \(urlStr): \(error.localizedDescription)", type: .error)
            await tracker.recordError()
        }
    }
    
    private func getExtension(fromMime mime: String, url: URL, isVideo: Bool, isDocument: Bool, isAudio: Bool = false) -> String {
        let cleanMime = mime.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let map: [String: String] = [
            "image/jpeg": ".jpg",
            "image/jpg": ".jpg",
            "image/png": ".png",
            "image/gif": ".gif",
            "image/webp": ".webp",
            "image/svg+xml": ".svg",
            "image/avif": ".avif",
            "image/x-icon": ".ico",
            "video/mp4": ".mp4",
            "video/webm": ".webm",
            "video/ogg": ".ogg",
            "video/quicktime": ".mov",
            "video/x-matroska": ".mkv",
            "video/x-ms-wmv": ".wmv",
            "video/x-flv": ".flv",
            "audio/mpeg": ".mp3",
            "audio/mp3": ".mp3",
            "audio/mp4": ".m4a",
            "audio/x-m4a": ".m4a",
            "audio/aac": ".aac",
            "audio/wav": ".wav",
            "audio/x-wav": ".wav",
            "audio/flac": ".flac",
            "audio/x-flac": ".flac",
            "audio/ogg": ".ogg",
            "audio/vorbis": ".ogg",
            "audio/opus": ".opus",
            "audio/webm": ".weba",
            "audio/x-ms-wma": ".wma",
            "audio/aiff": ".aiff",
            "audio/x-aiff": ".aiff",
            "application/pdf": ".pdf",
            "application/x-pdf": ".pdf",
            "application/msword": ".doc",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document": ".docx",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.template": ".dotx",
            "application/vnd.ms-excel": ".xls",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": ".xlsx",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.template": ".xltx",
            "application/vnd.ms-powerpoint": ".ppt",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation": ".pptx",
            "application/vnd.openxmlformats-officedocument.presentationml.slideshow": ".ppsx",
            "application/vnd.oasis.opendocument.text": ".odt",
            "application/vnd.oasis.opendocument.spreadsheet": ".ods",
            "application/vnd.oasis.opendocument.presentation": ".odp",
            "application/vnd.oasis.opendocument.graphics": ".odg",
            "application/rtf": ".rtf",
            "text/rtf": ".rtf",
            "text/plain": ".txt",
            "text/csv": ".csv",
            "application/epub+zip": ".epub"
        ]
        if let mapped = map[cleanMime] { return mapped }
        
        let urlExt = url.pathExtension.lowercased()
        if !urlExt.isEmpty {
            return "." + urlExt
        }
        
        if isVideo { return ".mp4" }
        if isAudio { return ".mp3" }
        if isDocument { return ".pdf" }
        return ".jpg"
    }
    
    private func getFilename(from url: URL) -> String {
        let lastComp = url.lastPathComponent
        if !lastComp.isEmpty && lastComp != "/" {
            return lastComp.removingPercentEncoding ?? lastComp
        }
        return "download"
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        var sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "_")
        while sanitized.hasPrefix(".") || sanitized.hasPrefix(" ") {
            sanitized.removeFirst()
        }
        return sanitized.isEmpty ? "file" : sanitized
    }
    
    // --- HELPER LOGS ---
    
    private func log(_ message: String, type: LogEntry.LogType) {
        onLog?(message, type)
    }
    
    private func triggerStatsUpdate() {
        onStatsUpdate?(stats)
    }
    
    private func loadDownloadHistory() -> DownloadHistoryData {
        let history = DownloadHistoryManager.load(from: targetFolder)
        log("Download-Historie geladen: \(history.downloadedUrls.count) URLs, \(history.downloadedHashes.count) Dateiinhalte bekannt.", type: .info)
        return history
    }
    
    private func isSameHost(_ host1: String?, _ host2: String?) -> Bool {
        guard let h1 = host1?.lowercased(), let h2 = host2?.lowercased() else { return false }
        let clean1 = h1.hasPrefix("www.") ? String(h1.dropFirst(4)) : h1
        let clean2 = h2.hasPrefix("www.") ? String(h2.dropFirst(4)) : h2
        return clean1 == clean2
    }
    
    private func hasVideoExtension(url: URL) -> Bool {
        return url.absoluteString.range(of: "\\.(mp4|webm|m3u8|mpd|mov|avi|mkv|flv|wmv|m4v|3gp)(?:/|\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func hasImageExtension(url: URL) -> Bool {
        return url.absoluteString.range(of: "\\.(jpg|jpeg|png|gif|webp|avif|svg)(?:/|\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func hasDocumentExtension(url: URL) -> Bool {
        return url.absoluteString.range(of: "\\.(pdf|docx?|docm?|dotx?|xlsx?|xlsm?|xltx?|xlsb|pptx?|pptm?|ppsx?|potx?|odt|ods|odp|odg|rtf|txt|csv|epub|mobi)(?:/|\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func isDocumentMime(_ mime: String, url: URL) -> Bool {
        let clean = mime.lowercased()
        if clean.contains("pdf") ||
           clean.contains("msword") ||
           clean.contains("officedocument") ||
           clean.contains("wordprocessingml") ||
           clean.contains("spreadsheetml") ||
           clean.contains("presentationml") ||
           clean.contains("opendocument") ||
           clean.contains("excel") ||
           clean.contains("powerpoint") ||
           clean.contains("rtf") ||
           clean.contains("epub") ||
           clean.contains("mobipocket") ||
           clean.contains("text/csv") ||
           (clean.contains("text/plain") && hasDocumentExtension(url: url)) ||
           (clean.contains("octet-stream") && hasDocumentExtension(url: url)) {
            return true
        }
        return false
    }
    
    private func hasAudioExtension(url: URL) -> Bool {
        return url.absoluteString.range(of: "\\.(mp3|m4a|aac|wav|flac|ogg|oga|opus|wma|aiff|alac|weba)(?:/|\\?|$)", options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func isAudioMime(_ mime: String, url: URL) -> Bool {
        let clean = mime.lowercased()
        if clean.hasPrefix("audio/") ||
           clean.contains("audio/mpeg") ||
           clean.contains("audio/mp3") ||
           clean.contains("audio/mp4") ||
           clean.contains("audio/x-m4a") ||
           clean.contains("audio/aac") ||
           clean.contains("audio/wav") ||
           clean.contains("audio/flac") ||
           clean.contains("audio/ogg") ||
           clean.contains("audio/opus") ||
           (clean.contains("octet-stream") && hasAudioExtension(url: url)) {
            return true
        }
        return false
    }
    
    private func isAudioPlatform(url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let domains = [
            "ardsounds.de", "ardaudiothek.de", "soundcloud.com", "audiomack.com",
            "bandcamp.com", "mixcloud.com", "podcasts.apple.com", "podcast.de", "deezer.com"
        ]
        return domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
    
    private func isVideoPlatform(url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        let urlStr = url.absoluteString.lowercased()
        
        let domains = [
            "youtube.com", "youtu.be", "vimeo.com", "dailymotion.com", "twitch.tv", "tiktok.com", "x.com", "twitter.com",
            "facebook.com", "instagram.com", "reddit.com", "linkedin.com", "tumblr.com", "pinterest.com", "telegram.org",
            "bilibili.com", "bitchute.com", "rumble.com", "rutube.ru", "odysee.com", "streamable.com", "wistia.com",
            "soundcloud.com", "audiomack.com", "bandcamp.com", "mixcloud.com", "9gag.com", "imgur.com", "newgrounds.com",
            "ardsounds.de", "ardaudiothek.de", "podcast.de", "podcasts.apple.com",
            "3sat.de", "ardmediathek.de", "arte.tv", "br.de", "ndr.de", "mdr.de", "wdr.de", "phoenix.de", "tagesschau.de",
            "zdf.de", "servus.com", "kika.de", "rtl.de", "rtl.lu", "n-tv.de", "orf.at", "playsuisse.ch", "srf.ch", 
            "rts.ch", "rsi.ch", "rtve.es", "raiplay.it", "1tv.ru", "bbc.co.uk", "bbc.com", "itv.com", "cbsnews.com",
            "cnn.com", "foxnews.com", "nbcnews.com", "abcnews.go.com", "reuters.com", "bloomberg.com", "sbs.com.au", "abc.net.au",
            "heavyfetish.com"
        ]
        
        let matchesHost = domains.contains { host == $0 || host.hasSuffix("." + $0) }
        if !matchesHost { return false }
        
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return urlStr.contains("/watch") || urlStr.contains("youtu.be/") || urlStr.contains("/embed/") || urlStr.contains("/v/") || urlStr.contains("/shorts/") || urlStr.contains("/playlist") || urlStr.contains("/@") || urlStr.contains("/channel/") || urlStr.contains("/c/") || urlStr.contains("/user/") || urlStr.contains("/videos") || urlStr.contains("/streams") || urlStr.contains("/podcasts")
        }
        if host.contains("vimeo.com") {
            if urlStr.contains("/video/") { return true }
            let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !trimmedPath.isEmpty && trimmedPath.allSatisfy({ $0.isNumber }) {
                return true
            }
            return urlStr.contains("/album/") || urlStr.contains("/showcase/") || urlStr.contains("/channels/") || urlStr.contains("/groups/") || path.components(separatedBy: "/").count == 2
        }
        if host.contains("dailymotion.com") || host.contains("dai.ly") {
            return urlStr.contains("/video/") || host.contains("dai.ly")
        }
        if host.contains("tiktok.com") {
            return urlStr.contains("/video/") || urlStr.contains("/v/")
        }
        if host.contains("twitch.tv") {
            return urlStr.contains("/videos/") || urlStr.contains("/clip/")
        }
        if host.contains("x.com") || host.contains("twitter.com") {
            return urlStr.contains("/status/")
        }
        if host.contains("facebook.com") {
            return urlStr.contains("/videos/") || urlStr.contains("/watch/") || urlStr.contains("/reel/")
        }
        if host.contains("instagram.com") {
            return urlStr.contains("/p/") || urlStr.contains("/reel/") || urlStr.contains("/tv/")
        }
        if host.contains("heavyfetish.com") {
            return urlStr.contains("/videos/")
        }
        
        return true
    }
    
    private func findYtdlpPath() -> String? {
        let commonPaths = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp",
            "/bin/yt-dlp"
        ]
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["yt-dlp"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        
        if task.terminationStatus == 0,
           let data = try? pipe.fileHandleForReading.readToEnd(),
           let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }
        
        return nil
    }
    
    private func downloadWithYtdlp(url: URL, targetFolder: URL, refererUrl: String? = nil, isAudioOnly: Bool = false) async -> Bool {
        guard let ytdlpPath = findYtdlpPath() else {
            log("yt-dlp wurde nicht gefunden. Bitte installieren Sie es mit 'brew install yt-dlp' für Plattform-Downloads.", type: .warning)
            return false
        }
        
        try? FileManager.default.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        
        // 1. Try with Chrome cookies if enabled
        if useChromeCookies {
            log("Versuche Download mit Chrome-Cookies...", type: .info)
            let success = await runYtdlpProcess(ytdlpPath: ytdlpPath, url: url, targetFolder: targetFolder, refererUrl: refererUrl, useCookies: true, isAudioOnly: isAudioOnly)
            if success {
                return true
            }
            log("Download mit Chrome-Cookies fehlgeschlagen. Versuche es ohne Cookies...", type: .warning)
        }
        
        // 2. Try/Retry without cookies
        return await runYtdlpProcess(ytdlpPath: ytdlpPath, url: url, targetFolder: targetFolder, refererUrl: refererUrl, useCookies: false, isAudioOnly: isAudioOnly)
    }
    
    private func runYtdlpProcess(ytdlpPath: String, url: URL, targetFolder: URL, refererUrl: String?, useCookies: Bool, isAudioOnly: Bool = false) async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: ytdlpPath)
        
        var args = [
            "--no-playlist",
            "-P", targetFolder.path
        ]
        if isAudioOnly {
            args.append(contentsOf: ["-x", "--audio-format", "mp3"])
        }
        if useCookies {
            args.append(contentsOf: ["--cookies-from-browser", "chrome"])
        }
        if let ref = refererUrl {
            args.append(contentsOf: ["--referer", ref])
        }
        args.append(url.absoluteString)
        task.arguments = args
        
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + currentPath
        task.environment = env
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        let fileHandle = pipe.fileHandleForReading
        
        do {
            try task.run()
            
            while task.isRunning {
                if isCancelled {
                    task.terminate()
                    log("yt-dlp Prozess abgebrochen.", type: .warning)
                    return false
                }
                
                if let data = try? fileHandle.read(upToCount: 512), !data.isEmpty,
                   let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: .newlines)
                    for line in lines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            if trimmed.contains("ERROR:") {
                                log("[yt-dlp-Fehler] \(trimmed)", type: .error)
                            } else if trimmed.contains("WARNING:") {
                                log("[yt-dlp-Warnung] \(trimmed)", type: .warning)
                            } else {
                                log("[yt-dlp] \(trimmed)", type: .ytdlp)
                            }
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
                        if trimmed.contains("ERROR:") {
                            log("[yt-dlp-Fehler] \(trimmed)", type: .error)
                        } else if trimmed.contains("WARNING:") {
                            log("[yt-dlp-Warnung] \(trimmed)", type: .warning)
                        } else {
                            log("[yt-dlp] \(trimmed)", type: .ytdlp)
                        }
                    }
                }
            }
            
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                log("Video erfolgreich über yt-dlp heruntergeladen.", type: .success)
                stats.imagesDownloaded += 1
                triggerStatsUpdate()
                return true
            } else {
                log("yt-dlp beendete mit Fehlercode \(task.terminationStatus).", type: .error)
                return false
            }
        } catch {
            log("Fehler beim Ausführen von yt-dlp: \(error.localizedDescription)", type: .error)
            return false
        }
    }
}
