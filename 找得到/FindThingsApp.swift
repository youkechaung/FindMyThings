import SwiftUI
import Supabase // Import Supabase

@main
struct FindThingsApp: App {
    @StateObject private var supabaseService = SupabaseService()
    @StateObject private var authService: AuthService
    @StateObject private var itemManager: ItemManager
    
    init() {
        let supabaseService = SupabaseService()
        let authService = AuthService(supabaseClient: supabaseService.client)
        _supabaseService = StateObject(wrappedValue: supabaseService)
        _authService = StateObject(wrappedValue: authService)
        _itemManager = StateObject(wrappedValue: ItemManager(authService: authService, supabaseService: supabaseService))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(itemManager)
                .environmentObject(supabaseService) // Inject SupabaseService
                .environmentObject(authService)     // Inject AuthService
                .onAppear {
                    // 为现有物品分配编号
                    itemManager.assignItemNumbers()
                }
        }
    }
}
