import SwiftUI

@main
struct FindThingsApp: App {
    @StateObject private var itemManager = ItemManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(itemManager)
        }
    }
}
