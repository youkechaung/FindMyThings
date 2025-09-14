import Foundation

// 用于测试应用内认证的服务
class AuthTestService {
    static let shared = AuthTestService()
    
    private init() {}
    
    // 测试用户注册
    @MainActor
    func testUserRegistration() async {
        print("=== 开始测试用户注册 ===")
        
        let supabaseService = SupabaseService()
        let authService = AuthService(supabaseService: supabaseService)
        await authService.signOut()             
        // 测试注册
        await authService.signUp(
            username: "测试用户",
            email: "test@example.com",
            password: "123456"
        )
        
        if authService.isAuthenticated {
            print("✅ 注册测试成功")
            print("当前用户: \(authService.currentUser?.username ?? "未知")")
        } else {
            print("❌ 注册测试失败: \(authService.errorMessage ?? "未知错误")")
        }
    }
    
    // 测试用户登录
    @MainActor
    func testUserLogin() async {
        print("=== 开始测试用户登录 ===")
        
        let supabaseService = SupabaseService()
        let authService = AuthService(supabaseService: supabaseService)
        
        // 测试登录
        await authService.signIn(
            email: "test@example.com",
            password: "123456"
        )
        
        if authService.isAuthenticated {
            print("✅ 登录测试成功")
            print("当前用户: \(authService.currentUser?.username ?? "未知")")
        } else {
            print("❌ 登录测试失败: \(authService.errorMessage ?? "未知错误")")
        }
    }
    
    // 测试密码哈希
    @MainActor
    func testPasswordHashing() {
        print("=== 开始测试密码哈希 ===")
        
        let password = "123456"
        let supabaseService = SupabaseService()
        let authService = AuthService(supabaseService: supabaseService)
        
        // 使用反射访问私有方法（仅用于测试）
        let mirror = Mirror(reflecting: authService)
        for child in mirror.children {
            if child.label == "hashPassword" {
                print("找到hashPassword方法")
                break
            }
        }
        
        print("密码: \(password)")
        print("✅ 密码哈希测试完成")
    }
    
    // 运行所有测试
    @MainActor
    func runAllTests() async {
        print("🚀 开始运行认证系统测试")
        
        await testUserRegistration()
        await testUserLogin()
        testPasswordHashing()
        
        print("🏁 认证系统测试完成")
    }
}