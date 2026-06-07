import SwiftUI

struct AddChildView: View {
    let familyId: Int
    var existingChild: PSChild? = nil
    let onSave: (PSChild) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedGender: ChildGender? = nil
    @State private var birthday: Date = Date()
    @State private var hasBirthday = false
    @State private var showDatePicker = false
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var isEditMode: Bool { existingChild != nil }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private var birthdayText: String {
        hasBirthday
            ? birthday.formatted(date: .long, time: .omitted)
            : String(localized: "Select birthday")
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            ZStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                Text("Child Info")
                    .font(.title.bold())
            }
            .padding(.horizontal, AuthStyle.screenHPadding)
            .frame(height: AuthStyle.topRowHeight)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Gender circles
                    HStack(spacing: 40) {
                        GenderCircle(gender: .boy, selected: selectedGender == .boy) {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedGender = .boy }
                        }
                        GenderCircle(gender: .girl, selected: selectedGender == .girl) {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedGender = .girl }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 36)
                    .padding(.bottom, 44)

                    // Birthday
                    Text("Birthday")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDatePicker.toggle()
                            if showDatePicker { hasBirthday = true }
                        }
                    } label: {
                        HStack {
                            Text(birthdayText)
                                .foregroundStyle(hasBirthday ? .primary : .secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(showDatePicker ? 90 : 0))
                        }
                        .padding(.horizontal, FamilyStyle.fieldHPadding)
                        .padding(.vertical, FamilyStyle.fieldVPadding)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: FamilyStyle.fieldCornerRadius))
                    }
                    .buttonStyle(.plain)

                    if showDatePicker {
                        DatePicker("", selection: $birthday, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.top, 4)
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showDatePicker = false }
                            } label: {
                                Text("Confirm")
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.primary)
                                    .foregroundStyle(Color(UIColor.systemBackground))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Nickname
                    Text("Nickname")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, AuthStyle.sectionSpacing)
                        .padding(.bottom, 8)

                    TextField("Enter nickname", text: $name)
                        .autocorrectionDisabled()
                        .padding(.horizontal, FamilyStyle.fieldHPadding)
                        .padding(.vertical, FamilyStyle.fieldVPadding)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: FamilyStyle.fieldCornerRadius))
                }
                .animation(.easeInOut(duration: 0.2), value: showDatePicker)
                .padding(.horizontal, AuthStyle.screenHPadding)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AuthStyle.screenHPadding)
                    }

                    Button {
                        submitChild()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(Color(UIColor.systemBackground))
                            } else {
                                Text(isEditMode ? "Save Changes" : "Add Child")
                                    .font(.body.bold())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuthStyle.buttonVPadding)
                        .background(trimmed.isEmpty || isLoading ? Color.primary.opacity(0.3) : Color.primary)
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
                    }
                    .disabled(trimmed.isEmpty || isLoading)
                    .padding(.horizontal, AuthStyle.screenHPadding)
                }
                .padding(.top, 16)
                .padding(.bottom, 32)
                .background(Color(.systemBackground))
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            guard let child = existingChild else { return }
            name = child.name
            selectedGender = child.gender
            if let bday = child.birthday,
               let date = Self.isoFormatter.date(from: bday) {
                birthday = date
                hasBirthday = true
            }
        }
    }

    private func submitChild() {
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

private struct GenderCircle: View {
    let gender: ChildGender
    let selected: Bool
    let onTap: () -> Void

    private var label: LocalizedStringKey {
        gender == .boy ? "Boy" : "Girl"
    }

    private var ringColor: Color {
        gender == .boy ? .blue : .pink
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(selected ? ringColor : Color.clear, lineWidth: 3)
                        )
                    Text(gender.avatarEmoji)
                        .font(.system(size: 52))
                }
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { AddChildView(familyId: 1) { _ in } }
}

#Preview("中文") {
    NavigationStack { AddChildView(familyId: 1) { _ in } }
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
