import Foundation
import Supabase

@MainActor
final class AuthenticationModel: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userID: UUID)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var isSubmitting = false
    @Published var message: String?

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseEnvironment.client) {
        self.client = client
    }

    func restoreSession() async {
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if
            let testEmail = environment["TIMEBOXER_TEST_EMAIL"],
            let testPassword = environment["TIMEBOXER_TEST_PASSWORD"],
            !testEmail.isEmpty,
            !testPassword.isEmpty
        {
            do {
                let session = try await client.auth.signIn(email: testEmail, password: testPassword)
                await SupabaseEnvironment.sessionStore.set(
                    accessToken: session.accessToken,
                    userID: session.user.id
                )
                state = .signedIn(userID: session.user.id)
                message = nil
                return
            } catch {
                message = "Test family login failed: \(error.localizedDescription)"
            }
        }
#endif
        do {
            let session = try await client.auth.session
            await SupabaseEnvironment.sessionStore.set(
                accessToken: session.accessToken,
                userID: session.user.id
            )
            state = .signedIn(userID: session.user.id)
        } catch {
            state = .signedOut
        }
    }

    func signIn(email: String, password: String) async {
        await submit {
            let session = try await self.client.auth.signIn(email: email, password: password)
            await SupabaseEnvironment.sessionStore.set(
                accessToken: session.accessToken,
                userID: session.user.id
            )
            self.state = .signedIn(userID: session.user.id)
            self.message = nil
        }
    }

    func signUp(email: String, password: String) async {
        await submit {
            let response = try await self.client.auth.signUp(email: email, password: password)
            if let session = response.session {
                await SupabaseEnvironment.sessionStore.set(
                    accessToken: session.accessToken,
                    userID: session.user.id
                )
                self.state = .signedIn(userID: session.user.id)
                self.message = nil
            } else {
                self.state = .signedOut
                self.message = "Check your email to confirm the account, then sign in."
            }
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            message = "The cloud session could not be closed cleanly."
        }
        await SupabaseEnvironment.sessionStore.clear()
        state = .signedOut
    }

    private func submit(_ operation: @escaping () async throws -> Void) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await operation()
        } catch {
            message = error.localizedDescription
        }
    }
}
