import SwiftUI

struct AddChildView: View {
    let familyId: Int
    var existingChild: PSChild? = nil
    let onSave: (PSChild) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var name = ""
    @State private var selectedGender: ChildGender? = nil
    @State private var birthday = Date()
    @State private var hasBirthday = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var isEditMode: Bool { existingChild != nil }
    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSubmit: Bool { !trimmed.isEmpty && !isLoading }

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let cr: CGFloat = PointSystemStyle.formConfirmCornerRadius

    private static let fieldBg = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 46/255, green: 32/255, blue: 28/255, alpha: 1)
            : UIColor(red: 245/255, green: 242/255, blue: 254/255, alpha: 1)
    })

    private static let borderColor = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(red: 199/255, green: 196/255, blue: 215/255, alpha: 1)
    })

    private static let labelColor = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 180/255, green: 155/255, blue: 145/255, alpha: 1)
            : UIColor(red: 118/255, green: 117/255, blue: 134/255, alpha: 1)
    })

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    formCard
                    if !isEditMode {
                        rewardProfileTip
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        }
        .background(
            LinearGradient(
                colors: theme.pageBgGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { populateForEdit() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            HStack {
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.body)
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
            }
            Text(isEditMode ? LocalizedStringKey("Child Info") : LocalizedStringKey("Add Child"))
                .font(.headline.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: selectedGender.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Text(selectedGender.avatarEmoji)
                        .font(.system(size: 46))
                )
            Circle()
                .fill(theme.cardSurface)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                )
                .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1))
        }
        .padding(.top, 12)
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 20) {
            nameField
            birthdayField
            genderSection
        }
        .padding(20)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.cardBorder, lineWidth: 1))
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Child Name")
            HStack(spacing: 10) {
                Image(systemName: "person")
                    .font(.system(size: 15))
                    .foregroundStyle(Self.labelColor)
                TextField("Enter name", text: $name)
                    .autocorrectionDisabled()
                    .font(.body)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Self.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: Self.cr))
            .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
        }
    }

    private var birthdayField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Birthday")
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 14))
                    .foregroundStyle(Self.labelColor)
                if hasBirthday {
                    DatePicker("", selection: $birthday, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(Color.accentColor)
                        .fixedSize()
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { hasBirthday = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { hasBirthday = true }
                    } label: {
                        Text("Select birthday")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 14)
            .background(Self.fieldBg)
            .clipShape(RoundedRectangle(cornerRadius: Self.cr))
            .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
        }
    }

    private var genderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Gender")
            HStack(spacing: 12) {
                genderCard(.boy)
                genderCard(.girl)
            }
        }
    }

    private func genderCard(_ gender: ChildGender) -> some View {
        let isSelected = selectedGender == gender
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedGender = isSelected ? nil : gender
            }
        } label: {
            VStack(spacing: 8) {
                Text(gender.avatarEmoji)
                    .font(.system(size: 30))
                Text(gender == .boy ? LocalizedStringKey("Boy") : LocalizedStringKey("Girl"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : Self.labelColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Self.cr)
                        .fill(LinearGradient(
                            colors: gender.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                } else {
                    RoundedRectangle(cornerRadius: Self.cr)
                        .fill(Self.fieldBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: Self.cr)
                                .stroke(Self.borderColor, lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reward profile tip

    private var rewardProfileTip: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedGender.gradientColors[0].opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(selectedGender.gradientColors[0])
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Reward Profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("A new reward profile will be automatically generated for them.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            Button { submitChild() } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isEditMode ? LocalizedStringKey("Save Changes") : LocalizedStringKey("Create Child"))
                            .font(.body.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    if canSubmit {
                        Capsule()
                            .fill(LinearGradient(
                                colors: [
                                    Color(red: 0, green: 148/255, blue: 253/255),
                                    Color(red: 255/255, green: 115/255, blue: 155/255)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    } else {
                        Capsule().fill(Color(.systemGray4))
                    }
                }
                .shadow(
                    color: canSubmit
                        ? Color(red: 0, green: 148/255, blue: 253/255).opacity(0.3)
                        : .clear,
                    radius: 10, y: 4
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
        .padding(.bottom, 32)
        .background(theme.cardSurface)
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Self.labelColor)
            .kerning(0.5)
            .textCase(.uppercase)
    }

    private func populateForEdit() {
        guard let child = existingChild else { return }
        name = child.name
        selectedGender = child.gender
        if let bday = child.birthday, let date = Self.isoFormatter.date(from: bday) {
            birthday = date
            hasBirthday = true
        }
    }

    private func submitChild() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil
        let birthdayStr = hasBirthday ? Self.isoFormatter.string(from: birthday) : nil
        Task {
            do {
                let child: PSChild
                if let existing = existingChild {
                    child = try await PointSystemService.updateChild(
                        familyId: familyId,
                        memberId: existing.memberId,
                        name: trimmed,
                        gender: selectedGender,
                        birthday: birthdayStr
                    )
                } else {
                    child = try await PointSystemService.addChild(
                        familyId: familyId,
                        name: trimmed,
                        gender: selectedGender,
                        birthday: birthdayStr
                    )
                }
                onSave(child)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack { AddChildView(familyId: 1) { _ in } }
        .environment(ThemeManager())
}

#Preview("中文") {
    NavigationStack { AddChildView(familyId: 1) { _ in } }
        .environment(ThemeManager())
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
