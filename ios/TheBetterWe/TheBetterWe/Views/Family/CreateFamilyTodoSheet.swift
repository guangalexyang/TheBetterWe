import SwiftUI

struct CreateFamilyTodoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let store: FamilyTodoStore

    @State private var title: String = ""
    @State private var priority: String = "medium"
    @State private var todoType: String = "family"
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var hasLocation: Bool = false
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var isSaving: Bool = false

    @Binding var detent: PresentationDetent

    private var expanded: Bool { hasDueDate || hasLocation }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

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
            sheetHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    titleField
                    prioritySection
                    typeSection
                    dueDateSection
                    locationSection
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.22), value: hasDueDate)
                .animation(.easeInOut(duration: 0.22), value: hasLocation)
            }
            .scrollBounceBehavior(.basedOnSize)
            sheetFooter
        }
        .frame(maxWidth: .infinity)
        .background(theme.cardSurface)
        .onChange(of: expanded) { _, newVal in
            withAnimation(.easeInOut(duration: 0.22)) {
                detent = newVal ? .height(680) : .height(560)
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)
            HStack {
                Text(NSLocalizedString("family_todo_create_title", comment: ""))
                    .font(.headline.weight(.bold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.systemGray))
                        .frame(width: 28, height: 28)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            Divider()
        }
    }

    // MARK: - Fields

    private var titleField: some View {
        fieldSection(label: "family_todo_field_title") {
            HStack {
                TextField(NSLocalizedString("family_todo_field_title_placeholder", comment: ""), text: $title)
                    .font(.body)
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Self.borderColor)
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("family_todo_field_priority")
            HStack(spacing: 8) {
                ForEach([("low", "family_todo_priority_low"), ("medium", "family_todo_priority_medium"), ("high", "family_todo_priority_high")], id: \.0) { value, key in
                    chipButton(label: NSLocalizedString(key, comment: ""), isSelected: priority == value) {
                        withAnimation(.easeInOut(duration: 0.2)) { priority = value }
                    }
                }
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("family_todo_field_type")
            HStack(spacing: 8) {
                chipButton(label: NSLocalizedString("family_todo_type_family", comment: ""), isSelected: todoType == "family") {
                    withAnimation(.easeInOut(duration: 0.2)) { todoType = "family" }
                }
                chipButton(label: NSLocalizedString("family_todo_type_personal", comment: ""), isSelected: todoType == "personal") {
                    withAnimation(.easeInOut(duration: 0.2)) { todoType = "personal" }
                }
            }
        }
    }

    private var dueDateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $hasDueDate) {
                fieldLabel("family_todo_field_due_date")
            }
            .tint(Color.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if hasDueDate {
                Divider().padding(.horizontal, 16)
                HStack(spacing: 10) {
                    datePickerField($dueDate, components: .date, icon: "calendar")
                    datePickerField($dueDate, components: .hourAndMinute, icon: "clock")
                }
                .padding(14)
            }
        }
        .background(Self.fieldBg)
        .clipShape(RoundedRectangle(cornerRadius: Self.cr))
        .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: $hasLocation) {
                fieldLabel("family_todo_field_location")
            }
            .tint(Color.accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if hasLocation {
                Divider().padding(.horizontal, 16)
                TextField(NSLocalizedString("family_todo_field_location_placeholder", comment: ""), text: $location)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
        }
        .background(Self.fieldBg)
        .clipShape(RoundedRectangle(cornerRadius: Self.cr))
        .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
    }

    private var notesSection: some View {
        fieldSection(label: "family_todo_field_notes") {
            TextEditor(text: $notes)
                .font(.body)
                .frame(minHeight: 80)
                .scrollDisabled(true)
        }
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task { await save() }
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(NSLocalizedString("family_todo_save", comment: ""))
                            .font(.body.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canSave ? Color.accentColor : Color(.systemGray4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Self.cr))
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .padding(20)
        }
        .background(theme.cardSurface)
    }

    // MARK: - Helpers

    private func fieldSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Self.fieldBg)
                .clipShape(RoundedRectangle(cornerRadius: Self.cr))
                .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
        }
    }

    private func fieldLabel(_ key: String) -> some View {
        Text(NSLocalizedString(key, comment: ""))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Self.labelColor)
            .kerning(0.5)
            .textCase(.uppercase)
    }

    private func chipButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? .white : Self.labelColor)
                .background(isSelected ? Color.accentColor : Self.fieldBg)
                .clipShape(RoundedRectangle(cornerRadius: Self.cr))
                .overlay {
                    if !isSelected {
                        RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func datePickerField(_ binding: Binding<Date>, components: DatePickerComponents, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Self.labelColor)
            DatePicker("", selection: binding, displayedComponents: components)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.accentColor)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Self.cr))
        .overlay(RoundedRectangle(cornerRadius: Self.cr).stroke(Self.borderColor, lineWidth: 1))
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        let body = CreateTodoBody(
            todoType:    todoType,
            title:       title.trimmingCharacters(in: .whitespaces),
            description: notes.isEmpty ? nil : notes,
            location:    hasLocation && !location.isEmpty ? location : nil,
            priority:    priority,
            dueAt:       hasDueDate ? Int(dueDate.timeIntervalSince1970) : nil
        )
        await store.create(body: body)
        isSaving = false
        dismiss()
    }
}
