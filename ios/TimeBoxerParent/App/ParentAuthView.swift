import SwiftUI

struct ParentAuthView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign in"
        case createAccount = "Create account"

        var id: Self { self }
    }

    @EnvironmentObject private var authentication: AuthenticationModel
    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 8 && !authentication.isSubmitting
    }

    var body: some View {
        ZStack {
            TimeBoxerColors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    TimeBoxerBrand()
                        .padding(.top, 44)

                    VStack(spacing: 10) {
                        Text("Parent control, wherever you are")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                        Text("Sign in to manage your child’s Mac, approve requests and receive alerts.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 18) {
                        Picker("Account action", selection: $mode) {
                            ForEach(Mode.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .timeBoxerField()

                        SecureField("Password (8 characters minimum)", text: $password)
                            .textContentType(mode == .signIn ? .password : .newPassword)
                            .timeBoxerField()

                        if let message = authentication.message {
                            Text(message)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task {
                                if mode == .signIn {
                                    await authentication.signIn(email: email, password: password)
                                } else {
                                    await authentication.signUp(email: email, password: password)
                                }
                            }
                        } label: {
                            HStack {
                                if authentication.isSubmitting {
                                    ProgressView().tint(.black)
                                }
                                Text(mode.rawValue)
                                    .fontWeight(.black)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.black)
                        .background(TimeBoxerColors.green, in: RoundedRectangle(cornerRadius: 16))
                        .disabled(!canSubmit)
                        .opacity(canSubmit ? 1 : 0.45)
                    }
                    .padding(22)
                    .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.black.opacity(0.08))
                    }

                    Text("The app stores family data in the independent TimeBoxer cloud project. Your password is handled by Supabase Auth and is never stored by the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
            }
        }
    }
}

private extension View {
    func timeBoxerField() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
    }
}
