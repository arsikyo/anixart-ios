import SwiftUI

@main
struct AnixartIOSApp: App {
    @StateObject private var session = SessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .task {
                    await session.bootstrap()
                }
                .onOpenURL { url in
                    Task {
                        await session.handleDeepLink(url)
                    }
                }
        }
    }
}
