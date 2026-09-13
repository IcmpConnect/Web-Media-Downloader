import Foundation

public struct DownloadHistoryRecord: Codable, Identifiable, Hashable {
    public var id: String { url }
    public let url: String
    public let hash: String?
    public let timestamp: Date
    
    public init(url: String, hash: String?, timestamp: Date = Date()) {
        self.url = url
        self.hash = hash
        self.timestamp = timestamp
    }
}

public struct DownloadHistoryData: Codable {
    public var records: [DownloadHistoryRecord]
    public var downloadedUrls: [String]
    public var downloadedHashes: [String]
    
    public init(records: [DownloadHistoryRecord] = [], downloadedUrls: [String] = [], downloadedHashes: [String] = []) {
        self.records = records
        self.downloadedUrls = downloadedUrls
        self.downloadedHashes = downloadedHashes
    }
}

public enum DateResetDirection: String, CaseIterable, Identifiable {
    case after = "after"
    case before = "before"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .after:
            return loc("Einträge ab diesem Datum löschen (Neuere entfernen)", "Delete entries on/after this date (remove newer)")
        case .before:
            return loc("Einträge vor diesem Datum löschen (Ältere entfernen)", "Delete entries before this date (remove older)")
        }
    }
}

public struct HistorySummary {
    public let exists: Bool
    public let totalRecords: Int
    public let totalUrls: Int
    public let totalHashes: Int
    public let oldestDate: Date?
    public let newestDate: Date?
    
    public init(exists: Bool, totalRecords: Int, totalUrls: Int, totalHashes: Int, oldestDate: Date?, newestDate: Date?) {
        self.exists = exists
        self.totalRecords = totalRecords
        self.totalUrls = totalUrls
        self.totalHashes = totalHashes
        self.oldestDate = oldestDate
        self.newestDate = newestDate
    }
}

public final class DownloadHistoryManager {
    public static let historyFileName = ".download_history.json"
    
    public static func historyFile(in folder: URL) -> URL {
        return folder.appendingPathComponent(historyFileName)
    }
    
    /// Loads the history from the target folder, with full backward compatibility for legacy JSONs.
    public static func load(from folder: URL) -> DownloadHistoryData {
        let file = historyFile(in: folder)
        guard FileManager.default.fileExists(atPath: file.path),
              let data = try? Data(contentsOf: file) else {
            return DownloadHistoryData()
        }
        
        // Attempt decoding modern format
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let modern = try? decoder.decode(DownloadHistoryData.self, from: data) {
            var result = modern
            // If records were empty but legacy downloadedUrls exists
            if result.records.isEmpty && !result.downloadedUrls.isEmpty {
                let fileDate = (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date) ?? Date()
                result.records = result.downloadedUrls.map { DownloadHistoryRecord(url: $0, hash: nil, timestamp: fileDate) }
            }
            return result
        }
        
        // Attempt decoding legacy dictionary [String: [String]]
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
            let urls = json["downloadedUrls"] ?? []
            let hashes = json["downloadedHashes"] ?? []
            let fileDate = (try? FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date) ?? Date()
            
            let records = urls.map { DownloadHistoryRecord(url: $0, hash: nil, timestamp: fileDate) }
            return DownloadHistoryData(records: records, downloadedUrls: urls, downloadedHashes: hashes)
        }
        
        return DownloadHistoryData()
    }
    
    /// Saves the history to target folder, ensuring both records and legacy arrays are present.
    public static func save(_ historyData: DownloadHistoryData, to folder: URL) {
        let file = historyFile(in: folder)
        var toSave = historyData
        
        // Synchronize legacy arrays from records if needed
        let recordUrls = Set(toSave.records.map { $0.url })
        let recordHashes = Set(toSave.records.compactMap { $0.hash })
        
        toSave.downloadedUrls = Array(Set(toSave.downloadedUrls).union(recordUrls)).sorted()
        toSave.downloadedHashes = Array(Set(toSave.downloadedHashes).union(recordHashes)).sorted()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = try? encoder.encode(toSave) {
            try? data.write(to: file, options: .atomic)
        }
    }
    
    /// Returns summary information about the history in the given folder.
    public static func getSummary(for folder: URL) -> HistorySummary {
        let file = historyFile(in: folder)
        guard FileManager.default.fileExists(atPath: file.path) else {
            return HistorySummary(exists: false, totalRecords: 0, totalUrls: 0, totalHashes: 0, oldestDate: nil, newestDate: nil)
        }
        
        let data = load(from: folder)
        let total = max(data.records.count, data.downloadedUrls.count)
        
        var oldest: Date? = nil
        var newest: Date? = nil
        
        for r in data.records {
            if oldest == nil || r.timestamp < oldest! {
                oldest = r.timestamp
            }
            if newest == nil || r.timestamp > newest! {
                newest = r.timestamp
            }
        }
        
        return HistorySummary(
            exists: true,
            totalRecords: total,
            totalUrls: data.downloadedUrls.count,
            totalHashes: data.downloadedHashes.count,
            oldestDate: oldest,
            newestDate: newest
        )
    }
    
    /// Completely resets (deletes or empties) the history file.
    @discardableResult
    public static func resetAll(in folder: URL) -> Int {
        let file = historyFile(in: folder)
        let current = load(from: folder)
        let count = max(current.records.count, current.downloadedUrls.count)
        
        if FileManager.default.fileExists(atPath: file.path) {
            try? FileManager.default.removeItem(at: file)
        }
        return count
    }
    
    /// Previews how many items will be deleted and remain when filtering by date.
    public static func previewResetByDate(in folder: URL, cutoff: Date, direction: DateResetDirection) -> (deleted: Int, remaining: Int) {
        let current = load(from: folder)
        if current.records.isEmpty {
            return (0, 0)
        }
        
        var deletedCount = 0
        var remainingCount = 0
        
        for r in current.records {
            let shouldDelete: Bool
            switch direction {
            case .after:
                // Delete items downloaded at or after the cutoff
                shouldDelete = (r.timestamp >= cutoff)
            case .before:
                // Delete items downloaded before the cutoff
                shouldDelete = (r.timestamp < cutoff)
            }
            if shouldDelete {
                deletedCount += 1
            } else {
                remainingCount += 1
            }
        }
        
        return (deletedCount, remainingCount)
    }
    
    /// Resets history by date, deleting entries matching the condition and keeping the rest.
    @discardableResult
    public static func resetByDate(in folder: URL, cutoff: Date, direction: DateResetDirection) -> (deleted: Int, remaining: Int) {
        var current = load(from: folder)
        let (deleted, remaining) = previewResetByDate(in: folder, cutoff: cutoff, direction: direction)
        
        if deleted == 0 {
            return (0, remaining)
        }
        
        // Filter records to retain
        current.records = current.records.filter { r in
            switch direction {
            case .after:
                return r.timestamp < cutoff
            case .before:
                return r.timestamp >= cutoff
            }
        }
        
        // Rebuild URLs and Hashes
        current.downloadedUrls = current.records.map { $0.url }.sorted()
        current.downloadedHashes = current.records.compactMap { $0.hash }.sorted()
        
        save(current, to: folder)
        return (deleted, remaining)
    }
}
