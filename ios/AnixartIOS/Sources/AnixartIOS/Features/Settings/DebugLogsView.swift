import SwiftUI
import UIKit

// MARK: - DEBUG_LOGGER_TEMPORARY

private enum LogFilterScope: String, CaseIterable, Identifiable {
    case all = "Все"
    case playerAndParser = "Плеер/Парсер"
    case network = "Сеть"
    case errors = "Ошибки"
    case actions = "Действия"

    var id: String { rawValue }
}

@MainActor
struct DebugLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var logger = DebugLogger.shared

    @State private var filter: LogFilterScope = .all
    @State private var searchText = ""
    @State private var copiedBanner = false
    @State private var exportFileURL: URL?

    private var filteredEntries: [DebugLogEntry] {
        let reversed = logger.entries.reversed()
        return reversed.filter { entry in
            switch filter {
            case .all:
                break
            case .playerAndParser:
                guard entry.category == .player || entry.category == .parser else { return false }
            case .network:
                guard entry.category == .api else { return false }
            case .errors:
                guard entry.level == .error || entry.level == .warning else { return false }
            case .actions:
                guard entry.category == .nav || entry.category == .app || entry.category == .ui else { return false }
            }

            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return entry.message.localizedCaseInsensitiveContains(trimmed)
                    || entry.category.rawValue.localizedCaseInsensitiveContains(trimmed)
            }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Фильтр", selection: $filter) {
                    ForEach(LogFilterScope.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = logger.exportText()
                        copiedBanner = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            copiedBanner = false
                        }
                    } label: {
                        Label(copiedBanner ? "Скопировано!" : "Скопировать всё (\(logger.entries.count))", systemImage: copiedBanner ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if let fileURL = exportFileURL {
                        ShareLink(item: fileURL) {
                            Label("Файл", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    if filteredEntries.isEmpty {
                        ContentUnavailableView("Логов пока нет", systemImage: "doc.text.magnifyingglass")
                    } else {
                        ForEach(filteredEntries) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(logger.formatEntry(entry))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(color(for: entry.level))
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Диагностика (логи)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Поиск в логах")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Очистить", role: .destructive) {
                        logger.clear()
                        exportFileURL = logger.writeExportFile()
                    }
                }
            }
            .onAppear {
                exportFileURL = logger.writeExportFile()
            }
            .onChange(of: logger.entries.count) { _, _ in
                exportFileURL = logger.writeExportFile()
            }
        }
    }

    private func color(for level: DebugLogLevel) -> Color {
        switch level {
        case .error: return .red
        case .warning: return .orange
        case .info: return .primary
        case .debug: return .secondary
        }
    }
}
