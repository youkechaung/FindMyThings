import SwiftUI
import Supabase // Import Supabase

@main
struct FindThingsApp: App {
    // 使用懒加载的方式初始化服务，避免在init中进行复杂的异步操作
    @StateObject private var supabaseService = SupabaseService()
    @StateObject private var authService: AuthService
    @StateObject private var itemManager: ItemManager
    
    init() {
        print("FindThingsApp init started")
        
        // 初始化输入助手禁用器，解决约束冲突问题
        _ = InputAssistantDisabler.shared
        print("InputAssistantDisabler initialized")
        
        // 创建Supabase服务
        let tempSupabaseService = SupabaseService()
        print("SupabaseService created")
        
        // 创建认证服务
        let tempAuthService = AuthService(supabaseService: tempSupabaseService)
        print("AuthService created")
        
        // 创建物品管理器
        let tempItemManager = ItemManager(authService: tempAuthService, supabaseService: tempSupabaseService)
        print("ItemManager created")
        
        // 初始化StateObject
        _supabaseService = StateObject(wrappedValue: tempSupabaseService)
        _authService = StateObject(wrappedValue: tempAuthService)
        _itemManager = StateObject(wrappedValue: tempItemManager)
        print("FindThingsApp init completed")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(itemManager)
                .environmentObject(supabaseService)
                .environmentObject(authService)
                .onAppear {
                    // 应用启动后预加载图片
                    Task {
                        await itemManager.preloadImages()
                    }
                }
        }
    }
}
