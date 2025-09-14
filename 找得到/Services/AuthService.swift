import Foundation
import CryptoKit

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentUser: AppUser? = nil

    private let supabaseService: SupabaseService

    init(supabaseService: SupabaseService) {
        self.supabaseService = supabaseService
        // 检查本地存储的登录状态
        checkStoredLoginState()
        print("AuthService 初始化完成 (应用内认证)")
    }

    // 应用内用户注册方法
    func signUp(username: String, email: String, password: String) async {
        errorMessage = nil
        
        // 验证输入
        guard !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = "请填写所有必填字段"
            return
        }
        
        guard isValidEmail(email) else {
            errorMessage = "请输入有效的邮箱地址"
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "密码长度至少6位"
            return
        }
        
        do {
            // 检查邮箱是否已存在
            let existingUser = try await supabaseService.getUserByEmail(email: email)
            if existingUser != nil {
                errorMessage = "该邮箱已被注册"
                return
            }
            
            // 创建新用户
            let newUser = AppUser(username: username, email: email, password: password)
            
            // 保存到数据库
            try await supabaseService.createUser(user: newUser)
            
            // 注册成功后自动登录
            self.currentUser = newUser
            self.isAuthenticated = true
            saveLoginState(user: newUser)
            
            print("注册成功并自动登录")
        } catch {
            self.errorMessage = "注册失败: \(error.localizedDescription)"
            self.isAuthenticated = false
            print("注册失败: \(error.localizedDescription)")
        }
    }

    // 应用内用户登录方法
    func signIn(email: String, password: String) async {
        errorMessage = nil
        print("开始登录请求: \(email)")
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "请填写邮箱和密码"
            return
        }
        
        do {
            // 从数据库获取用户信息
            guard let user = try await supabaseService.getUserByEmail(email: email) else {
                errorMessage = "用户不存在"
                return
            }
            
            // 验证密码
            let inputPassword = password
            guard user.password == inputPassword else {
                errorMessage = "密码错误"
                return
            }
            
            // 登录成功
            self.currentUser = user
            self.isAuthenticated = true
            saveLoginState(user: user)
            
            print("登录成功")
        } catch {
            print("登录失败，错误详情: \(error)")
            self.errorMessage = "登录失败: \(error.localizedDescription)"
            self.isAuthenticated = false
        }
    }

    // 登出方法
    func signOut() async {
        errorMessage = nil
        
        // 清除本地存储的登录状态
        clearLoginState()
        
        self.isAuthenticated = false
        self.currentUser = nil
        
        print("登出成功")
    }
    
    // MARK: - 私有方法
    
    // 密码哈希
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // 邮箱格式验证
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // 保存登录状态到本地
    private func saveLoginState(user: AppUser) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "currentUser")
            UserDefaults.standard.set(true, forKey: "isAuthenticated")
        }
    }
    
    // 检查本地存储的登录状态
    private func checkStoredLoginState() {
        if UserDefaults.standard.bool(forKey: "isAuthenticated"),
           let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(AppUser.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
            print("从本地存储恢复登录状态")
        }
    }
    
    // 清除本地登录状态
    private func clearLoginState() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "isAuthenticated")
    }
}
