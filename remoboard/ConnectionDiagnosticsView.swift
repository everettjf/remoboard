import SwiftUI
import UIKit
import RemoboardKit

struct ConnectionDiagnosticsView: View {
    private func localized(_ key: String) -> String { NSLocalizedString(key, comment: "") }

    @State private var events = Settings.shared.diagnosticEvents
    @State private var history = Settings.shared.clipboardHistory
    @State private var allowRead = Settings.shared.allowRemoteClipboardRead
    @State private var allowWrite = Settings.shared.allowRemoteClipboardWrite
    @State private var pasted = ""
    @State private var showShare = false

    var body: some View {
        List {
            Section(localized("diagnostics.pairing.title")) {
                if let success = events.last(where: { $0.kind == "pairing" && $0.detail.contains("verified") }) {
                    Label(String(format: localized("diagnostics.pairing.verified"), success.date.formatted(date: .abbreviated, time: .standard)), systemImage: "checkmark.shield.fill").foregroundStyle(.green)
                } else { Label(localized("diagnostics.pairing.none"), systemImage: "shield.slash") }
                Text(localized("diagnostics.pairing.explanation")).font(.caption).foregroundStyle(.secondary)
            }
            Section(localized("diagnostics.clipboard.title")) {
                Toggle(localized("diagnostics.clipboard.read"), isOn: $allowRead).onChange(of: allowRead) { Settings.shared.allowRemoteClipboardRead = $0 }
                Toggle(localized("diagnostics.clipboard.write"), isOn: $allowWrite).onChange(of: allowWrite) { Settings.shared.allowRemoteClipboardWrite = $0 }
                if #available(iOS 16.0, *) {
                    PasteButton(payloadType: String.self) { values in pasted = values.first ?? ""; Settings.shared.rememberClipboard(pasted); reload() }.buttonBorderShape(.roundedRectangle)
                }
                if !pasted.isEmpty { Text(pasted).lineLimit(3).privacySensitive() }
                Button(localized("diagnostics.clipboard.clear"), role: .destructive) { Settings.shared.clearClipboardHistory(); reload() }.disabled(history.isEmpty)
                ForEach(Array(history.enumerated()), id: \.offset) { _, item in Text(item).lineLimit(2).privacySensitive() }
            }
            Section(localized("diagnostics.log.title")) {
                ForEach(events.reversed()) { event in VStack(alignment: .leading) { Text(localizedKind(event.kind)).font(.headline); Text(localizedDetail(event.detail)); Text(event.date.formatted()).font(.caption).foregroundStyle(.secondary) } }
                Button(localized("diagnostics.log.clear"), role: .destructive) { Settings.shared.clearDiagnostics(); reload() }.disabled(events.isEmpty)
            }
        }
        .navigationTitle(localized("diagnostics.title"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(events.isEmpty)
                .accessibilityLabel(localized("diagnostics.share"))
            }
        }
        .sheet(isPresented: $showShare) {
            DiagnosticsActivityView(items: [diagnosticText])
        }
        .onAppear(perform: reload)
    }

    private func localizedKind(_ kind: String) -> String {
        switch kind {
        case "pairing": return localized("diagnostics.kind.pairing")
        case "clipboard": return localized("diagnostics.kind.clipboard")
        default: return kind.capitalized
        }
    }

    private func localizedDetail(_ detail: String) -> String {
        if detail == "PIN verified end to end" { return localized("diagnostics.event.verified") }
        if detail.hasPrefix("PIN rejected (attempt "), detail.hasSuffix(")") {
            let number = detail.dropFirst("PIN rejected (attempt ".count).dropLast()
            return String(format: localized("diagnostics.event.rejected"), String(number))
        }
        for (prefix, key) in [
            ("Remote write accepted (", "diagnostics.event.write"),
            ("Remote read accepted (", "diagnostics.event.read")
        ] where detail.hasPrefix(prefix) {
            let count = detail.dropFirst(prefix.count).split(separator: " ").first.map(String.init) ?? "0"
            return String(format: localized(key), count)
        }
        return detail
    }

    private var diagnosticText: String { ([localized("diagnostics.export.header")] + events.map { "\($0.date.formatted(.iso8601)) [\(localizedKind($0.kind))] \(localizedDetail($0.detail))" }).joined(separator: "\n") }
    private func reload() { events = Settings.shared.diagnosticEvents; history = Settings.shared.clipboardHistory }
}

private struct DiagnosticsActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
