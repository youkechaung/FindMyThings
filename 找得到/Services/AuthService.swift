import Foundation
import Supabase

class AuthService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String? = nil
    @Published var user: User? // Supabase user object

    private let client: SupabaseClient

    init(supabaseClient: SupabaseClient) {
        self.client = supabaseClient
        // Attempt to restore session on initialization
        Task {
            await observeAuthStateChanges()
            await fetchCurrentUserSession()
        }
    }

    private func observeAuthStateChanges() async {
        for await state in client.auth.authStateChanges {
            DispatchQueue.main.async {
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
        do {
            _ = try await client.auth.signIn(email: email, password: password)
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
