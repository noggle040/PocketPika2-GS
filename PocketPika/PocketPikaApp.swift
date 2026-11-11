import SwiftUI

@main
struct PocketPikaApp: App {
    @StateObject private var store = PocketPikaStore()

    var body: some Scene {
        WindowGroup {
            PocketPikaView()
                .environmentObject(store)
        }
    }
}

