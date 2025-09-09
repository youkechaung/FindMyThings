import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // 添加调试状态变量
    @State private var isDebugging = false
    @State private var lastInputType = ""
    @State private var lastInputTime = ""

    var body: some View {
        VStack(spacing: 30) {
            // 标题
            VStack(spacing: 10) {
                Text("找得到")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                Text("智能物品管理")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 50)
            
            // 输入表单
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("邮箱")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("请输入邮箱地址", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                        .onChange(of: email, perform: { newValue in
                            lastInputType = "邮箱"
                            lastInputTime = String(describing: Date())
                            if isDebugging {
                                print("邮箱输入: \(newValue)")
                            }
                        })
                        .border(Color.blue, width: 1) // 为了清晰可见
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("密码")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    SecureField("请输入密码", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: password, perform: { newValue in
                            lastInputType = "密码"
                            lastInputTime = String(describing: Date())
                            if isDebugging {
                                print("密码输入: 长度为 \(newValue.count) 的字符串")
                            }
                        })
                        .border(Color.blue, width: 1) // 为了清晰可见
                }
            }
            .padding(.horizontal, 30)
            
            // 登录按钮
            Button(action: login) {
                HStack {
                    Text("登录")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .disabled(email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1.0)
            
            // 错误信息
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            Spacer()
            
            // 注册链接
            VStack(spacing: 10) {
                Text("还没有账号？")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                NavigationLink(destination: RegistrationView()) {
                    Text("立即注册")
                        .font(.callout)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("登录失败"), 
                message: Text(alertMessage), 
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func login() {
        authService.errorMessage = nil // Clear previous error messages
        print("开始登录: \(email)")
        print("密码长度: \(password.count)")
        
        Task {
            do {
                await authService.signIn(email: email, password: password)
                print("登录完成，认证状态: \(authService.isAuthenticated)")
                
                if !authService.isAuthenticated && authService.errorMessage != nil {
                    alertMessage = authService.errorMessage ?? "登录失败。请检查您的邮箱和密码。"
                    showingAlert = true
                }
            } catch {
                print("登录过程中出现错误: \(error)")
                alertMessage = "登录过程中出现错误: \(error.localizedDescription)"
                showingAlert = true
            }
        }
    }
}

