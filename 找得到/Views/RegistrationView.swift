import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 30) {
            // 标题
            VStack(spacing: 10) {
                Text("注册新账号")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                Text("创建您的账户")
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("确认密码")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    SecureField("请再次输入密码", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            .padding(.horizontal, 30)
            
            // 注册按钮
            Button(action: register) {
                HStack {
                    Text("注册")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .disabled(email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
            .opacity(email.isEmpty || password.isEmpty || confirmPassword.isEmpty ? 0.6 : 1.0)
            
            // 错误信息
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            Spacer()
            
            // 返回登录链接
            VStack(spacing: 10) {
                Text("已有账号？")
                    .font(.callout)
                    .foregroundColor(.secondary)
                
                Button("返回登录") {
                    // 这里可以添加返回登录的逻辑
                }
                .font(.callout)
                .foregroundColor(.blue)
            }
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("注册失败"), 
                message: Text(alertMessage), 
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func register() {
        authService.errorMessage = nil // Clear previous error messages
        guard password == confirmPassword else {
            alertMessage = "密码和确认密码不匹配。"
            showingAlert = true
            return
        }

        Task {
            await authService.signUp(email: email, password: password)
            if !authService.isAuthenticated && authService.errorMessage != nil {
                alertMessage = authService.errorMessage ?? "注册失败。请检查您的邮箱和密码。"
                showingAlert = true
            }
        }
    }
}
