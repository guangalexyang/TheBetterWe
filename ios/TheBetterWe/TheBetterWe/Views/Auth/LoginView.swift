import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void = {}

    @State private var username = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var navigateToSignUp = false
    @State private var isLoading = false

    private var canLogIn: Bool { !username.isEmpty && PasswordValidator.isValid(password) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: AuthStyle.topRowHeight)

                Text("Login")
                    .font(.title.bold())
                    .padding(.bottom, AuthStyle.sectionSpacing)

                HStack(spacing: 12) {
                    Image(systemName: "person")
                        .foregroundStyle(.secondary)
                        .frame(width: AuthStyle.fieldIconWidth)
                    Divider().frame(height: AuthStyle.fieldDividerHeight)
                    TextField("Enter your username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, AuthStyle.fieldHPadding)
                .padding(.vertical, AuthStyle.fieldVPadding)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))
                .padding(.bottom, AuthStyle.fieldSpacing)

                HStack(spacing: 12) {
                    Button { isPasswordVisible.toggle() } label: {
                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                            .foregroundStyle(.secondary)
                            .frame(width: AuthStyle.fieldIconWidth)
                    }
                    Divider().frame(height: AuthStyle.fieldDividerHeight)
                    Group {
                        if isPasswordVisible {
                            TextField("Enter your password", text: $password)
                        } else {
                            SecureField("Enter your password", text: $password)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                .padding(.horizontal, AuthStyle.fieldHPadding)
                .padding(.vertical, AuthStyle.fieldVPadding)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: AuthStyle.fieldCornerRadius))
                .padding(.bottom, AuthStyle.sectionSpacing)

                Button {
                    isLoading = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        // TODO: call auth service
                        isLoading = false
                        onSuccess()
                    }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Log In").font(.body.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AuthStyle.buttonVPadding)
                    .background(canLogIn ? Color.red : Color.red.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
                }
                .disabled(!canLogIn || isLoading)
                .padding(.bottom, 20)

                HStack {
                    Spacer()
                    Button { navigateToSignUp = true } label: {
                        Text("Don't have an account? **Sign Up**")
                            .foregroundStyle(Color.authPink)
                    }
                    Spacer()
                }

                Spacer()
            }
            .padding(.horizontal, AuthStyle.screenHPadding)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToSignUp) {
                SignUpView()
            }
        }
    }
}

#Preview("English") {
    LoginView()
}

#Preview("中文") {
    LoginView()
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
