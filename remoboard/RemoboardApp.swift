//
//  RemoboardApp.swift
//  Remoboard
//

import SwiftUI

@main
struct RemoboardApp: App {
    @StateObject private var handoff = HandoffStore()

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-storeScreenshotQuickWords") {
                NavigationView { QuickWordsView() }
                    .navigationViewStyle(.stack)
            } else {
                home
            }
#else
            home
#endif
        }
    }

    private var home: some View {
            HomeView()
                .environmentObject(handoff)
                .onOpenURL { handoff.handle(url: $0) }
#if DEBUG
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("-storeScreenshotReceived") {
                        handoff.receivedText = "Hi Alex,\n\nThanks for the update. I can review the proposal tonight and send feedback tomorrow.\n\nBest,\nEverett"
                    }
                }
#endif
    }
}
