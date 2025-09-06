import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("注册新账号")
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

                SecureField("确认密码", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button(action: register) {
                    Text("注册")
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
            }
            .padding(.vertical)
            .navigationTitle("注册")
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("注册失败"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
            }
        }
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
