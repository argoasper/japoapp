import SwiftUI

@main
struct JapoTripApp: App {
    @StateObject private var store = DataStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppAppearance.configure()
        // The default URLCache (~20 MB memory / disk shared with everything
        // else the OS caches) was exhausted by a handful of the app's own
        // 1200px photos. A dedicated, generous cache is what lets photos
        // already seen keep showing once the trip loses connectivity.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024, diskCapacity: 400 * 1024 * 1024)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Color(hex: "#C0392B"))
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                // The "visited" write is debounced (see DataStore); flush it
                // immediately when the app is about to leave the foreground
                // so a check-in never gets lost.
                store.flushPendingSave()
            }
        }
    }
}
