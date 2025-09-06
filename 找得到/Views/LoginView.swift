import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("登录")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                TextField("邮箱", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal)

                SecureField("密码", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button(action: login) {
                    Text("登录")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                // Option to navigate to registration
                NavigationLink(destination: RegistrationView()) {
                    Text("没有账号？注册一个")
                        .font(.callout)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical)
            .navigationTitle("登录")
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("登录失败"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
            }
        }
    }

    private func login() {
        authService.errorMessage = nil // Clear previous error messages
        Task {
            await authService.signIn(email: email, password: password)
            if !authService.isAuthenticated && authService.errorMessage != nil {
                alertMessage = authService.errorMessage ?? "登录失败。请检查您的邮箱和密码。"
                showingAlert = true
            }
        }
    }
}
