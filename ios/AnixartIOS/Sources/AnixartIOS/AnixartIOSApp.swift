import SwiftUI

@main
struct AnixartIOSApp: App {
    @StateObject private var session = SessionStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .task {
                    DebugLogger.log(.app, "App launched (authenticated=\(session.isAuthenticated))")
                    await session.bootstrap()
                }
                .onOpenURL { url in
                    DebugLogger.log(.app, "Deep link received: \(url.absoluteString)")
                    Task {
                        await session.handleDeepLink(url)
                    }
                }
        }
    }
}
