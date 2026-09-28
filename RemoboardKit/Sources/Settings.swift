//
//  Settings.swift
//  RemoboardKit
//
//  App-group backed settings shared between the host app and the keyboard extension.
//  Replaces the legacy Objective-C `KBSetting` singleton.
//

import Foundation

public enum ConnectMode: Int {
    case http = 0
    // BLE (legacy value 2) intentionally dropped in the Swift rewrite.
}

public final class Settings {

    public static let appGroup = "group.everettjf.remoboard"
    public static let shared = Settings()

    private let defaults: UserDefaults

    private enum Key {
        static let words = "rkb.quickWords"
        static let connectMode = "rkb.connectMode"
        static let lastAppVersion = "rkb.lastAppVersion"
        static let requirePIN = "rkb.requirePIN"
        static let port = "rkb.port"
        static let diagnostics = "rkb.diagnostics"
        static let clipboardHistory = "rkb.clipboardHistory"
        static let clipboardHistoryLimit = "rkb.clipboardHistoryLimit"
        static let allowClipboardRead = "rkb.allowClipboardRead"
        static let allowClipboardWrite = "rkb.allowClipboardWrite"
    }

    /// The port the keyboard's server listens on. Defaults to 7777; users can change it from
    /// the app if that port is taken. Clamped to the unprivileged range.
    public static let defaultPort = 7777
    public static let portRange = 1024...65535

    public var port: Int {
        get {
            let p = defaults.integer(forKey: Key.port)   // unset -> 0
            return Settings.portRange.contains(p) ? p : Settings.defaultPort
        }
        set { defaults.set(Settings.portRange.contains(newValue) ? newValue : Settings.defaultPort, forKey: Key.port) }
    }

    private init() {
        defaults = UserDefaults(suiteName: Settings.appGroup) ?? .standard
    }

    // MARK: - Quick words

    public static let defaultWords = [
        "OK", "Thanks!", "On my way", "Got it", "👍",
        "好的", "收到", "稍等",
    ]

    public var quickWords: [String] {
        get { defaults.stringArray(forKey: Key.words) ?? Settings.defaultWords }
        set { defaults.set(newValue, forKey: Key.words) }
    }

    public func addWord(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var words = quickWords
        words.append(trimmed)
        quickWords = words
    }

    public func updateWord(at index: Int, to word: String) {
        var words = quickWords
        guard words.indices.contains(index) else { return }
        words[index] = word
        quickWords = words
    }

    public func removeWord(at index: Int) {
        var words = quickWords
        guard words.indices.contains(index) else { return }
        words.remove(at: index)
        quickWords = words
    }

    public func resetDefaultWords() {
        quickWords = Settings.defaultWords
    }

    // MARK: - PIN pairing

    /// Require a pairing code on new installs. Users can explicitly disable it
    /// for a trusted local network in the host app.
    public var requirePIN: Bool {
        get { defaults.object(forKey: Key.requirePIN) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.requirePIN) }
    }

    // MARK: - Privacy & diagnostics

    public struct DiagnosticEvent: Codable, Identifiable, Sendable {
        public let id: UUID; public let date: Date; public let kind: String; public let detail: String
        public init(kind: String, detail: String) { id = UUID(); date = Date(); self.kind = kind; self.detail = detail }
    }

    public var diagnosticEvents: [DiagnosticEvent] {
        get { defaults.data(forKey: Key.diagnostics).flatMap { try? JSONDecoder().decode([DiagnosticEvent].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(Array(newValue.suffix(100))), forKey: Key.diagnostics) }
    }
    public func recordDiagnostic(kind: String, detail: String) { var events = diagnosticEvents; events.append(.init(kind: kind, detail: detail)); diagnosticEvents = events }
    public func clearDiagnostics() { diagnosticEvents = [] }

    public var clipboardHistoryLimit: Int { get { let value = defaults.integer(forKey: Key.clipboardHistoryLimit); return value == 0 ? 10 : min(max(value, 1), 50) } set { defaults.set(min(max(newValue, 1), 50), forKey: Key.clipboardHistoryLimit) } }
    public var clipboardHistory: [String] { get { defaults.stringArray(forKey: Key.clipboardHistory) ?? [] } set { defaults.set(Array(newValue.prefix(clipboardHistoryLimit)), forKey: Key.clipboardHistory) } }
    public func rememberClipboard(_ text: String) { guard !text.isEmpty else { return }; var items = clipboardHistory.filter { $0 != text }; items.insert(text, at: 0); clipboardHistory = items }
    public func clearClipboardHistory() { clipboardHistory = [] }
    public var allowRemoteClipboardRead: Bool { get { defaults.object(forKey: Key.allowClipboardRead) as? Bool ?? true } set { defaults.set(newValue, forKey: Key.allowClipboardRead) } }
    public var allowRemoteClipboardWrite: Bool { get { defaults.object(forKey: Key.allowClipboardWrite) as? Bool ?? true } set { defaults.set(newValue, forKey: Key.allowClipboardWrite) } }

    // MARK: - Connection mode

    public var connectMode: ConnectMode {
        get { ConnectMode(rawValue: defaults.integer(forKey: Key.connectMode)) ?? .http }
        set { defaults.set(newValue.rawValue, forKey: Key.connectMode) }
    }

    // MARK: - Misc

    public var lastAppVersion: String? {
        get { defaults.string(forKey: Key.lastAppVersion) }
        set { defaults.set(newValue, forKey: Key.lastAppVersion) }
    }
}
