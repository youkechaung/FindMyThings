import SwiftUI

@main
struct FindThingsApp: App {
    @StateObject private var itemManager = ItemManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(itemManager)
                .onAppear {
                    // 为现有物品分配编号
                    itemManager.assignItemNumbers()
                }
        }
    }
}
