import SwiftUI

@main
struct JapoTripApp: App {
    @StateObject private var store = DataStore()

    init() {
        AppAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .tint(Color(hex: "#C0392B"))
        }
    }
}
