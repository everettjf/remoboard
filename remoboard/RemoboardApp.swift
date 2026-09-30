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
                        handoff.receivedText = Self.storeScreenshotMessage
                    }
                }
#endif
    }

#if DEBUG
    private static var storeScreenshotMessage: String {
        let language = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if language.hasPrefix("zh") {
            return "Alex，你好：\n\n谢谢更新。我今晚可以看一下方案，明天把反馈发给你。\n\n祝好，\nEverett"
        } else if language.hasPrefix("ja") {
            return "Alex さん\n\nご連絡ありがとうございます。今夜、提案を確認し、明日フィードバックをお送りします。\n\nEverett"
        } else if language.hasPrefix("pt") {
            return "Olá, Alex,\n\nObrigado pela atualização. Vou revisar a proposta hoje à noite e enviar meus comentários amanhã.\n\nEverett"
        } else if language.hasPrefix("ru") {
            return "Привет, Алекс!\n\nСпасибо за новости. Сегодня вечером изучу предложение и завтра пришлю отзыв.\n\nЭверетт"
        } else if language.hasPrefix("de") {
            return "Hallo Alex,\n\nvielen Dank für das Update. Ich sehe mir den Vorschlag heute Abend an und schicke dir morgen mein Feedback.\n\nEverett"
        } else if language.hasPrefix("vi") {
            return "Chào Alex,\n\nCảm ơn bạn đã cập nhật. Tối nay tôi sẽ xem đề xuất và gửi phản hồi vào ngày mai.\n\nEverett"
        } else if language.hasPrefix("fr") {
            return "Bonjour Alex,\n\nMerci pour cette mise à jour. Je vais lire la proposition ce soir et vous envoyer mes commentaires demain.\n\nEverett"
        }
        return "Hi Alex,\n\nThanks for the update. I can review the proposal tonight and send feedback tomorrow.\n\nBest,\nEverett"
    }
#endif
}
