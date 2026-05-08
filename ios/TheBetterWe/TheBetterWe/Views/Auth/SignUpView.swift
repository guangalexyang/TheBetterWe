import SwiftUI

struct SignUpView: View {
    var onSuccess: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var hasLetter: Bool { PasswordValidator.hasLetter(password) }
    private var hasNumber: Bool { PasswordValidator.hasNumber(password) }
    private var hasLength: Bool { PasswordValidator.hasLength(password) }
    private var isPasswordValid: Bool { PasswordValidator.isValid(password) }
    private var passwordsMatch: Bool { !confirmPassword.isEmpty && password == confirmPassword }
    private var canSignUp: Bool { !username.isEmpty && isPasswordValid && passwordsMatch }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
            }
            .frame(height: AuthStyle.topRowHeight)

            Text("Sign Up")
                .font(.title.bold())
                .padding(.bottom, AuthStyle.sectionSpacing)

            // Username
            HStack(spacing: 12) {
                Image(systemName: "person")
                    .foregroundStyle(.secondary)
                    .frame(width: AuthStyle.fieldIconWidth)
                Divider().frame(height: AuthStyle.fieldDividerHeight)
                TextField("Choose a username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: username) { errorMessage = nil }
            }
            .padding(.horizontal, AuthStyle.fieldHPadding)
            .padding(.vertical, AuthStyle.fieldVPadding)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))
            .padding(.bottom, AuthStyle.fieldSpacing)

            // Password
            HStack(spacing: 12) {
                Button { isPasswordVisible.toggle() } label: {
                    Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                        .foregroundStyle(.secondary)
                        .frame(width: AuthStyle.fieldIconWidth)
                }
                Divider().frame(height: AuthStyle.fieldDividerHeight)
                Group {
                    if isPasswordVisible {
                        TextField("Create a password", text: $password)
                    } else {
                        SecureField("Create a password", text: $password)
                    }
                }
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .padding(.horizontal, AuthStyle.fieldHPadding)
            .padding(.vertical, AuthStyle.fieldVPadding)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))
            .padding(.bottom, 10)

            // Validation hints
            VStack(alignment: .leading, spacing: 4) {
                validationRow(text: "At least 6 characters", passed: hasLength)
                validationRow(text: "Contains a letter", passed: hasLetter)
                validationRow(text: "Contains a number", passed: hasNumber)
            }
            .padding(.bottom, AuthStyle.fieldSpacing)

            // Confirm password
            HStack(spacing: 12) {
                Button { isConfirmVisible.toggle() } label: {
                    Image(systemName: isConfirmVisible ? "eye" : "eye.slash")
                        .foregroundStyle(.secondary)
                        .frame(width: AuthStyle.fieldIconWidth)
                }
                Divider().frame(height: AuthStyle.fieldDividerHeight)
                Group {
                    if isConfirmVisible {
                        TextField("Confirm your password", text: $confirmPassword)
                    } else {
                        SecureField("Confirm your password", text: $confirmPassword)
                    }
                }
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .padding(.horizontal, AuthStyle.fieldHPadding)
            .padding(.vertical, AuthStyle.fieldVPadding)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))

            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwords do not match")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 6)
            }

            Spacer().frame(height: AuthStyle.sectionSpacing)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.bottom, 8)
            }

            // Sign Up button
            Button {
                isLoading = true
                errorMessage = nil
                Task {
                    do {
                        try await AuthService.signUp(username: username, password: password)
                        onSuccess()
                    } catch let error as AuthError {
                        errorMessage = error.errorDescription
                    } catch {
                        errorMessage = AuthError.network.errorDescription
                    }
                    isLoading = false
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Sign Up").font(.body.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AuthStyle.buttonVPadding)
                .background(canSignUp ? Color.red : Color.red.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
            }
            .disabled(!canSignUp || isLoading)

            Spacer()
        }
        .padding(.horizontal, AuthStyle.screenHPadding)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func validationRow(text: LocalizedStringKey, passed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: passed ? "checkmark" : "xmark")
                .font(.caption.bold())
                .foregroundStyle(passed ? .green : Color(.systemGray3))
            Text(text)
                .font(.caption)
                .foregroundStyle(passed ? .primary : Color(.systemGray3))
        }
    }
}

#Preview("English") {
    NavigationStack { SignUpView() }
}

#Preview("中文") {
    NavigationStack { SignUpView() }
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
