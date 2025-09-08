import SwiftUI
import Supabase // Import Supabase

@main
struct FindThingsApp: App {
    @StateObject private var supabaseService = SupabaseService()
    @StateObject private var authService: AuthService
    @State private var itemManager: ItemManager?
    
    init() {
        print("FindThingsApp init started")
        let supabaseService = SupabaseService()
        print("SupabaseService created")
        let authService = AuthService(supabaseClient: supabaseService.client)
        print("AuthService created")
        _supabaseService = StateObject(wrappedValue: supabaseService)
        _authService = StateObject(wrappedValue: authService)
        print("FindThingsApp init completed")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(itemManager ?? ItemManager(authService: authService, supabaseService: supabaseService))
                .environmentObject(supabaseService) // Inject SupabaseService
                .environmentObject(authService)     // Inject AuthService
                .onAppear {
                    if itemManager == nil {
                        print("Creating ItemManager on appear")
                        itemManager = ItemManager(authService: authService, supabaseService: supabaseService)
                    }
                }
        }
    }
}
