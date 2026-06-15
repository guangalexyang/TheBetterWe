import SwiftUI

private enum AuthTab: CaseIterable { case login, signup }

// MARK: - AuthView

struct AuthView: View {
    var onSuccess: () -> Void = {}

    @Namespace private var tabNS
    @State private var selectedTab: AuthTab = .login
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                    .padding(.top, 64)
                    .padding(.bottom, 36)

                cardSection
                    .padding(.horizontal, 20)

                Text("继续即表示你同意佳家的**服务条款**与**隐私政策**")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .padding(.bottom, 48)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            LinearGradient(colors: theme.pageBgGradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }

    // MARK: Hero

    private var heroSection: some View {
        ZStack {
            // Decorative blobs
            Circle()
                .fill(theme.primaryAccent.opacity(0.18))
                .frame(width: 140, height: 140)
                .blur(radius: 40)
                .offset(x: 80, y: -30)
            Circle()
                .fill(Color(red: 232/255, green: 93/255, blue: 122/255).opacity(0.14))
                .frame(width: 100, height: 100)
                .blur(radius: 28)
                .offset(x: -70, y: 10)

            VStack(spacing: 14) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.2), radius: 16, y: 6)

                VStack(spacing: 6) {
                    Text("佳家")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("让每一天，都成为美好的家庭故事")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Card

    private var cardSection: some View {
        VStack(spacing: 0) {
            tabHeader

            Group {
                if selectedTab == .login {
                    LoginTabContent(onSuccess: onSuccess)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity
                        ))
                } else {
                    SignUpTabContent(onSuccess: onSuccess)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: selectedTab)
        }
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(theme.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 24, y: 8)
    }

    private var tabHeader: some View {
        HStack(spacing: 0) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 0) {
                        Text(tab == .login ? "登录" : "注册")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(selectedTab == tab ? theme.primaryAccent : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)

                        ZStack {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(theme.primaryAccent)
                                    .frame(width: 32, height: 2)
                                    .matchedGeometryEffect(id: "tab-indicator", in: tabNS)
                            }
                        }
                        .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.cardBorder)
                .frame(height: 1)
        }
    }
}

// MARK: - Login Tab

private struct LoginTabContent: View {
    var onSuccess: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: LoginField?
    @Environment(\.appTheme) private var theme

    private var canLogIn: Bool { !username.isEmpty && !password.isEmpty }

    var body: some View {
        VStack(spacing: 14) {
            // Username
            AuthFieldShell(theme: theme, isFocused: focusedField == .username) {
                Image(systemName: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                authDivider
                TextField("用户名", text: $username)
                    .focused($focusedField, equals: .username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            // Password
            AuthFieldShell(theme: theme, isFocused: focusedField == .password) {
                Button { isPasswordVisible.toggle() } label: {
                    Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                authDivider
                Group {
                    if isPasswordVisible {
                        TextField("密码", text: $password)
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("密码", text: $password)
                            .focused($focusedField, equals: .password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.password)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            authButton(
                label: "登录",
                isLoading: isLoading,
                enabled: canLogIn
            ) {
                submitLogin()
            }
        }
        .padding(20)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
    }

    private func submitLogin() {
        guard canLogIn, !isLoading else { return }
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await AuthService.logIn(username: username, password: password)
                onSuccess()
            } catch let error as AuthError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = AuthError.network.errorDescription
            }
            isLoading = false
        }
    }
}

private enum LoginField: Hashable { case username, password }

// MARK: - Sign Up Tab

private struct SignUpTabContent: View {
    var onSuccess: () -> Void

    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmVisible = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: SignUpField?
    @Environment(\.appTheme) private var theme

    private var hasLength: Bool    { PasswordValidator.hasLength(password) }
    private var hasLetter: Bool    { PasswordValidator.hasLetter(password) }
    private var hasNumber: Bool    { PasswordValidator.hasNumber(password) }
    private var isPasswordValid: Bool { PasswordValidator.isValid(password) }
    private var passwordsMatch: Bool  { !confirmPassword.isEmpty && password == confirmPassword }
    private var canSignUp: Bool { !username.isEmpty && isPasswordValid && passwordsMatch }

    var body: some View {
        VStack(spacing: 14) {
            // Username
            AuthFieldShell(theme: theme, isFocused: focusedField == .username) {
                Image(systemName: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                authDivider
                TextField("用户名", text: $username)
                    .focused($focusedField, equals: .username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: username) { _, _ in errorMessage = nil }
            }

            // Password
            AuthFieldShell(theme: theme, isFocused: focusedField == .password) {
                Button { isPasswordVisible.toggle() } label: {
                    Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                authDivider
                Group {
                    if isPasswordVisible {
                        TextField("密码", text: $password)
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("密码", text: $password)
                            .focused($focusedField, equals: .password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
            }

            // Password validation indicators
            if !password.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    validationRow("至少 6 位字符", passed: hasLength)
                    validationRow("包含字母", passed: hasLetter)
                    validationRow("包含数字", passed: hasNumber)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .offset(y: -4)))
            }

            // Confirm password
            AuthFieldShell(theme: theme, isFocused: focusedField == .confirm) {
                Button { isConfirmVisible.toggle() } label: {
                    Image(systemName: isConfirmVisible ? "eye" : "eye.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                authDivider
                Group {
                    if isConfirmVisible {
                        TextField("确认密码", text: $confirmPassword)
                            .focused($focusedField, equals: .confirm)
                    } else {
                        SecureField("确认密码", text: $confirmPassword)
                            .focused($focusedField, equals: .confirm)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.oneTimeCode)
            }

            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("两次密码不一致")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            authButton(
                label: "注册",
                isLoading: isLoading,
                enabled: canSignUp
            ) {
                submitSignUp()
            }
        }
        .padding(20)
        .animation(.easeInOut(duration: 0.18), value: password.isEmpty)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
    }

    @ViewBuilder
    private func validationRow(_ text: LocalizedStringKey, passed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: passed ? "checkmark" : "xmark")
                .font(.caption.bold())
                .foregroundStyle(passed ? .green : Color(.systemGray3))
            Text(text)
                .font(.caption)
                .foregroundStyle(passed ? .primary : Color(.systemGray3))
        }
    }

    private func submitSignUp() {
        guard canSignUp, !isLoading else { return }
        errorMessage = nil
        isLoading = true
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
    }
}

private enum SignUpField: Hashable { case username, password, confirm }

// MARK: - Shared field helpers

private struct AuthFieldShell<Content: View>: View {
    let theme: AppTheme
    let isFocused: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(theme.pageBg, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    isFocused ? theme.primaryAccent : theme.cardBorder,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

private var authDivider: some View {
    Rectangle()
        .fill(Color(.systemGray4))
        .frame(width: 1, height: 22)
}

@ViewBuilder
private func authButton(
    label: LocalizedStringKey,
    isLoading: Bool,
    enabled: Bool,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Group {
            if isLoading {
                ProgressView().tint(.white)
            } else {
                Text(label)
                    .font(.body.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 240/255, green: 112/255, blue: 74/255),
                    Color(red: 232/255, green: 93/255, blue: 122/255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(enabled ? 1 : 0.4)
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color(red: 240/255, green: 112/255, blue: 74/255).opacity(enabled ? 0.35 : 0),
            radius: 12, y: 4
        )
    }
    .buttonStyle(.plain)
    .disabled(!enabled || isLoading)
    .padding(.top, 4)
}

// MARK: - Previews

#Preview("Light") {
    AuthView()
        .environment(ThemeManager())
        .environment(\.appTheme, AppTheme.light)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    AuthView()
        .environment(ThemeManager())
        .environment(\.appTheme, AppTheme.dark)
        .preferredColorScheme(.dark)
}
