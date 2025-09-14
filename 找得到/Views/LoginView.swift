import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""

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
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("密码")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    SecureField("请输入密码", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
            VStack(spacing: 5     ) {
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
    }

    private func login() {
        // 清除之前的错误信息
        authService.errorMessage = nil
        
        // 直接调用简化的登录方法
        Task {
            await authService.signIn(email: email, password: password)
        }
    }
}

