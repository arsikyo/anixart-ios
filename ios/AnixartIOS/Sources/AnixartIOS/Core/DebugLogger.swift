import Foundation
import OSLog
import UIKit

// MARK: - DEBUG_LOGGER_TEMPORARY
// Временный модуль расширенного логирования для отладки на устройстве.
// Перед релизной сборкой удалить этот файл, DebugLogsView.swift и вызовы DebugLogger.log(...) по коду.

enum DebugLogLevel: String, CaseIterable, Identifiable, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"

    var id: String { rawValue }
}

enum DebugLogCategory: String, CaseIterable, Identifiable, Sendable {
    case app = "APP"
    case nav = "NAV"
    case api = "API"
    case parser = "PARSER"
    case player = "PLAYER"
    case ui = "UI"

    var id: String { rawValue }
}

struct DebugLogEntry: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: DebugLogLevel
    let category: DebugLogCategory
    let message: String
}

private final class DebugLogBuffer: Sendable {
    private let lock = OSAllocatedUnfairLock<[DebugLogEntry]>(initialState: [])
    private let maxEntries = 1500

    func append(_ entry: DebugLogEntry) {
        lock.withLock { state in
            state.append(entry)
            if state.count > maxEntries {
                state.removeFirst(state.count - maxEntries)
            }
        }
    }

    func snapshot() -> [DebugLogEntry] {
        lock.withLock { $0 }
    }

    func clear() {
        lock.withLock { $0.removeAll() }
    }
}

@MainActor
final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    nonisolated private static let buffer = DebugLogBuffer()
    nonisolated private static let osLogger = Logger(subsystem: "com.anixartios.app", category: "diagnostic")

    @Published private(set) var entries: [DebugLogEntry] = []
    private var isSyncPending = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {
        entries = Self.buffer.snapshot()
    }

    nonisolated static func log(
        _ category: DebugLogCategory,
        _ message: String,
        level: DebugLogLevel = .info
    ) {
        let cleaned = sanitize(message)
        let entry = DebugLogEntry(
            id: UUID(),
            timestamp: Date(),
            level: level,
            category: category,
            message: cleaned
        )
        buffer.append(entry)

        let line = "[\(category.rawValue)][\(level.rawValue)] \(cleaned)"
        switch level {
        case .error:
            osLogger.error("\(line, privacy: .public)")
        case .warning:
            osLogger.warning("\(line, privacy: .public)")
        case .info, .debug:
            osLogger.info("\(line, privacy: .public)")
        }

        Task { @MainActor in
            DebugLogger.shared.scheduleSync()
        }
    }

    func clear() {
        Self.buffer.clear()
        entries = []
        Self.log(.app, "Журнал логов очищен пользователем")
    }

    func formatEntry(_ entry: DebugLogEntry) -> String {
        let ts = Self.timeFormatter.string(from: entry.timestamp)
        return "[\(ts)] [\(entry.category.rawValue)] [\(entry.level.rawValue)] \(entry.message)"
    }

    func exportText(limit: Int? = nil) -> String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

        var headerLines: [String] = [
            "=== AnixartIOS Diagnostic Log ===",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "App: \(appVersion) (\(buildNumber))",
            "Device: \(device.model) | iOS \(device.systemVersion)",
            "API BaseURL: \(APIConfiguration.baseURL.absoluteString)",
            "Kodik API URL: \(APIConfiguration.kodikVideoLinksURL)",
            "Static Domain: \(APIConfiguration.staticDomain)",
            "Authenticated: \(SessionStore.shared.isAuthenticated) | Guest: \(SessionStore.shared.isGuestMode)",
            "Total entries: \(entries.count)",
            "================================="
        ]

        let targetEntries: ArraySlice<DebugLogEntry>
        if let limit, entries.count > limit {
            targetEntries = entries.suffix(limit)
        } else {
            targetEntries = entries[...]
        }

        headerLines.append(contentsOf: targetEntries.map(formatEntry))
        return headerLines.joined(separator: "\n")
    }

    func writeExportFile() -> URL? {
        let text = exportText()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("anixart-debug-log.txt")
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    private func scheduleSync() {
        guard !isSyncPending else { return }
        isSyncPending = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            self.isSyncPending = false
            self.entries = Self.buffer.snapshot()
        }
    }

    nonisolated static func sanitize(_ text: String) -> String {
        var result = text
        if let regex = try? NSRegularExpression(pattern: "(token=)([A-Za-z0-9._-]{4})[A-Za-z0-9._-]+", options: [.caseInsensitive]) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1$2***")
        }
        return result
    }
}
