import Foundation
import Supabase

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String? = nil
    @Published var user: User? // Supabase user object

    private let client: SupabaseClient

    init(supabaseClient: SupabaseClient) {
        self.client = supabaseClient
        // Attempt to restore session on initialization
        Task {
            await fetchCurrentUserSession()
        }
        Task {
            await observeAuthStateChanges()
        }
    }

    private func observeAuthStateChanges() async {
        for await state in client.auth.authStateChanges {
            Task { @MainActor in
                switch state.event { // Changed to state.event
                case .signedIn:
                    self.isAuthenticated = true
                    // Fetch user info when signed in
                    Task { await self.fetchCurrentUser() }
                case .signedOut, .userDeleted, .tokenRefreshed:
                    self.isAuthenticated = false
                    self.user = nil
                case .initialSession: // Handle initial session check
                    if state.session != nil {
                        self.isAuthenticated = true
                        Task { await self.fetchCurrentUser() }
                    } else {
                        self.isAuthenticated = false
                        self.user = nil
                    }
                case .passwordRecovery:
                    // Handle password recovery event
                    print("Password recovery event triggered")
                case .userUpdated:
                    // Handle user updated event
                    Task { await self.fetchCurrentUser() }
                case .mfaChallengeVerified:
                    // Handle MFA challenge verified event
                    print("MFA challenge verified")
                @unknown default:
                    print("Unknown AuthChangeEvent: \(state.event)")
                    self.isAuthenticated = false
                    self.user = nil
                }
            }
        }
    }
    
    private func fetchCurrentUserSession() async {
        do {
            let session = try await client.auth.session
            DispatchQueue.main.async {
                self.isAuthenticated = session != nil
                if session != nil {
                    Task { await self.fetchCurrentUser() }
                }
            }
        } catch {
            DispatchQueue.main.async {
                print("Error fetching current user session: \(error.localizedDescription)")
                self.isAuthenticated = false
                self.user = nil
            }
        }
    }

    private func fetchCurrentUser() async {
        do {
            let user = try await client.auth.user()
            DispatchQueue.main.async {
                self.user = user
            }
        } catch {
            DispatchQueue.main.async {
                print("Error fetching current user: \(error.localizedDescription)")
                self.user = nil
            }
        }
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            DispatchQueue.main.async {
                self.isAuthenticated = true
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isAuthenticated = false
            }
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        print("开始登录请求: \(email)")
        
        do {
            print("调用 Supabase auth.signIn...")
            let response = try await client.auth.signIn(email: email, password: password)
            print("Supabase 登录响应: \(response)")
            
            DispatchQueue.main.async {
                self.isAuthenticated = true
                print("登录成功，设置 isAuthenticated = true")
            }
        } catch {
            print("登录失败，错误详情: \(error)")
            print("错误类型: \(type(of: error))")
            print("错误描述: \(error.localizedDescription)")
            
            // 检查是否是网络相关错误
            if let urlError = error as? URLError {
                print("URLError 代码: \(urlError.code.rawValue)")
                print("URLError 描述: \(urlError.localizedDescription)")
                
                switch urlError.code {
                case .notConnectedToInternet:
                    DispatchQueue.main.async {
                        self.errorMessage = "网络连接失败，请检查网络设置"
                    }
                case .timedOut:
                    DispatchQueue.main.async {
                        self.errorMessage = "连接超时，请稍后重试"
                    }
                case .cannotConnectToHost:
                    DispatchQueue.main.async {
                        self.errorMessage = "无法连接到服务器，请检查网络"
                    }
                case .secureConnectionFailed:
                    DispatchQueue.main.async {
                        self.errorMessage = "SSL连接失败，请检查网络设置或稍后重试"
                    }
                default:
                    DispatchQueue.main.async {
                        self.errorMessage = "网络错误: \(urlError.localizedDescription)"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
            
            DispatchQueue.main.async {
                self.isAuthenticated = false
            }
        }
    }

    func signOut() async {
        errorMessage = nil
        do {
            try await client.auth.signOut()
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.user = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
