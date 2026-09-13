import Foundation
import SwiftUI
import Combine

public enum AppLanguage: String, CaseIterable, Identifiable {
    case de = "de"
    case en = "en"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "English"
        }
    }
    
    public var flag: String {
        switch self {
        case .de: return "🇩🇪"
        case .en: return "🇬🇧"
        }
    }
    
    public var buttonTitle: String {
        switch self {
        case .de: return "🇬🇧 English"
        case .en: return "🇩🇪 Deutsch"
        }
    }
    
    public var next: AppLanguage {
        switch self {
        case .de: return .en
        case .en: return .de
        }
    }
}

public class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    @AppStorage("app_language") private var storedLanguage: String = "de"
    @Published public var currentLanguage: AppLanguage = .de
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? "de"
        self.currentLanguage = AppLanguage(rawValue: saved) ?? .de
    }
    
    public func toggleLanguage() {
        let nextLang = currentLanguage.next
        setLanguage(nextLang)
    }
    
    public func setLanguage(_ lang: AppLanguage) {
        currentLanguage = lang
        storedLanguage = lang.rawValue
        UserDefaults.standard.set(lang.rawValue, forKey: "app_language")
    }
    
    // Convenience helper
    public func s(_ deText: String, _ enText: String) -> String {
        return currentLanguage == .de ? deText : enText
    }
}

// Global quick access function
public func loc(_ deText: String, _ enText: String) -> String {
    return LocalizationManager.shared.s(deText, enText)
}
