import SwiftUI

struct AddChildView: View {
    let onAdd: (PSChild) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedGender: ChildGender? = nil
    @State private var birthday: Date = Date()
    @State private var hasBirthday = false
    @State private var showDatePicker = false
    @State private var name = ""

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private var birthdayText: String {
        hasBirthday
            ? birthday.formatted(date: .long, time: .omitted)
            : String(localized: "Select birthday")
    }

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
                Button {
                    onAdd(PSChild(
                        id: Int.random(in: 1000...9999),
                        name: trimmed,
                        gender: selectedGender,
                        birthday: hasBirthday ? birthday : nil,
                        balance: 0
                    ))
                    dismiss()
                } label: {
                    Text("Add Child")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AuthStyle.buttonVPadding)
                        .background(trimmed.isEmpty ? Color.primary.opacity(0.3) : Color.primary)
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
                }
                .disabled(trimmed.isEmpty)
                .padding(.horizontal, AuthStyle.screenHPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .background(Color(.systemBackground))
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct GenderCircle: View {
    let gender: ChildGender
    let selected: Bool
    let onTap: () -> Void

    private var emoji: String {
        gender == .boy ? "👦" : "👧"
    }

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
                    Text(emoji)
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
    NavigationStack { AddChildView { _ in } }
}

#Preview("中文") {
    NavigationStack { AddChildView { _ in } }
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
