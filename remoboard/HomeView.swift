//
//  HomeView.swift
//  Remoboard
//
//  Home / onboarding. A brand hero, a visual setup card with one primary action,
//  quick-action tiles for the main features, and a footer — the pattern used by
//  well-designed keyboard utility apps.
//

import SwiftUI
import UIKit
import RemoboardKit

struct HomeView: View {
    @EnvironmentObject private var handoff: HandoffStore
    @State private var requirePIN = Settings.shared.requirePIN
    @State private var portText = String(Settings.shared.port)

    private let feedbackURL = URL(string: "https://github.com/everettjf/Remoboard/issues/new")!
    private let siteURL = URL(string: "https://xnu.app/remoboard")!
    private let scriptWidgetURL = URL(string: "https://xnu.app/scriptwidget/?utm_source=remoboard&utm_medium=in_app&utm_campaign=cross_promo&utm_content=home_featured_card")!

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    setupCard
                    quickActions
                    securityCard
                    NavigationLink { ConnectionDiagnosticsView() } label: { Label("Connection Diagnostics & Clipboard Privacy", systemImage: "stethoscope").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(18).background(card) }.buttonStyle(.plain)
                    portCard
                    scriptWidgetCard
                    moreAppsCard
                    footer
                }
                .padding(20)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: Binding(
            get: { handoff.receivedText != nil },
            set: { if !$0 { handoff.receivedText = nil } }
        )) {
            if let text = handoff.receivedText {
                ReceivedView(text: text) { handoff.receivedText = nil }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 14) {
            Text("Remoboard")
                .font(.largeTitle.bold())
            Text(NSLocalizedString("home.tagline", comment: ""))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: Setup card

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("home.howto.title", comment: ""))
                .font(.headline)

            VStack(spacing: 14) {
                StepRow(number: 1, text: NSLocalizedString("home.howto.step1", comment: ""))
                StepRow(number: 2, text: NSLocalizedString("home.howto.step2", comment: ""))
                StepRow(number: 3, text: NSLocalizedString("home.howto.step3", comment: ""))
                StepRow(number: 4, text: NSLocalizedString("home.howto.step4", comment: ""))
            }

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(NSLocalizedString("home.opensettings", comment: ""), systemImage: "gear")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(NSLocalizedString("home.fullaccess.note", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(card)
    }

    // MARK: Quick actions

    private var quickActions: some View {
        HStack(spacing: 14) {
            NavigationLink {
                QuickWordsView()
            } label: {
                ActionTile(icon: "text.badge.star",
                           title: NSLocalizedString("home.quickwords", comment: ""),
                           subtitle: NSLocalizedString("home.quickwords.sub", comment: ""))
            }
            .buttonStyle(.plain)

            NavigationLink {
                TestInputView()
            } label: {
                ActionTile(icon: "keyboard",
                           title: NSLocalizedString("home.testinput", comment: ""),
                           subtitle: NSLocalizedString("home.testinput.sub", comment: ""))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Security

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $requirePIN) {
                Text(NSLocalizedString("home.pin.title", comment: ""))
                    .font(.headline)
            }
            .onChange(of: requirePIN) { newValue in
                Settings.shared.requirePIN = newValue
            }
            Text(NSLocalizedString("home.pin.note", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(card)
    }

    // MARK: Port

    private var portCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("home.port.title", comment: ""))
                .font(.headline)
            HStack {
                TextField(String(Settings.defaultPort), text: $portText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                    .onChange(of: portText) { v in
                        let digits = String(v.filter(\.isNumber).prefix(5))
                        if digits != v { portText = digits }
                    }
                Spacer()
                Button(NSLocalizedString("home.port.apply", comment: "")) { applyPort() }
                    .buttonStyle(.bordered)
                    .disabled(Int(portText) == Settings.shared.port)
            }
            Text(NSLocalizedString("home.port.note", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(card)
    }

    private func applyPort() {
        let p = Int(portText) ?? Settings.defaultPort
        let clamped = min(max(p, Settings.portRange.lowerBound), Settings.portRange.upperBound)
        Settings.shared.port = clamped
        portText = String(clamped)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: More apps

    private var scriptWidgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "curlybraces.square.fill")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(NSLocalizedString("home.scriptwidget.eyebrow", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .textCase(.uppercase)
                    Text("ScriptWidget")
                        .font(.title3.bold())
                    Text(NSLocalizedString("home.scriptwidget.description", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Link(destination: scriptWidgetURL) {
                Label(NSLocalizedString("home.scriptwidget.cta", comment: ""), systemImage: "arrow.up.right")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityHint(NSLocalizedString("home.scriptwidget.hint", comment: ""))
        }
        .padding(18)
        .background(card)
    }

    private var moreAppsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("home.moreapps", comment: ""), systemImage: "square.grid.2x2")
                .font(.headline)

            AppStoreLink(name: "BSSID SCAN", systemImage: "wifi", url: "https://apps.apple.com/us/app/bssid-scan/id1442586100")
            Divider()
            AppStoreLink(name: "Dayvella", systemImage: "calendar", url: "https://apps.apple.com/app/id6753280745")
        }
        .padding(18)
        .background(card)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 10) {
            Link(destination: feedbackURL) {
                Label(NSLocalizedString("home.feedback", comment: ""), systemImage: "bubble.left")
                    .font(.subheadline)
            }
            Link("xnu.app", destination: siteURL)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}

private struct StepRow: View {
    let number: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

private struct AppStoreLink: View {
    let name: String
    let systemImage: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Label(name, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(HandoffStore())
}
