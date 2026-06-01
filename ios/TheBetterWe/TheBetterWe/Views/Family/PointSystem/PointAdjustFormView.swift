import SwiftUI

// MARK: - PointAdjustFormView

struct PointAdjustFormView: View {
    let style: ActionStyle
    let familyId: Int
    let memberId: Int
    let onSuccess: (Int) -> Void
    let onLogOut: () -> Void
    var onDismiss: (() -> Void)? = nil   // nil = not in sheet mode

    @State private var points: Int = 2
    @State private var pointsText: String = "2"
    @State private var noteText: String = ""
    @FocusState private var isEditing: Bool
    @State private var isMoreExpanded: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let dismiss = onDismiss {
                sheetHeader(dismiss: dismiss)
            }
            stepperArea
            noteField
                .padding(.horizontal, PointSystemStyle.formHPadding)
                .padding(.top, 14)
            moreSection
                .padding(.horizontal, PointSystemStyle.formHPadding)
            confirmSection
                .padding(.horizontal, PointSystemStyle.formHPadding)
                .padding(.top, 16)
                .padding(.bottom, PointSystemStyle.formVPadding)
        }
        .background(Color(.systemGray6))
    }

    @ViewBuilder
    private func sheetHeader(dismiss: @escaping () -> Void) -> some View {
        HStack {
            Text(style.confirmLabel)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(.systemGray3))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, PointSystemStyle.formHPadding)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: Stepper

    private var stepperArea: some View {
        VStack(spacing: 4) {
            HStack(spacing: 24) {
                stepperButton(symbol: "minus") {
                    guard points > 1 else { return }
                    points -= 1
                    pointsText = "\(points)"
                }
                .opacity(isEditing ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.15), value: isEditing)

                numberField

                stepperButton(symbol: "plus") {
                    points += 1
                    pointsText = "\(points)"
                }
                .opacity(isEditing ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.15), value: isEditing)
            }

            Text("pts")
                .font(.system(size: PointSystemStyle.stepperUnitFontSize, weight: .medium))
                .foregroundStyle(.secondary)

            Text("tap to edit")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(isEditing ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: isEditing)
        }
        .padding(.vertical, PointSystemStyle.formVPadding)
    }

    private var numberField: some View {
        TextField("", text: $pointsText)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: PointSystemStyle.stepperValueFontSize, weight: .heavy))
            .foregroundStyle(isEditing ? style.tint : Color(.label))
            .tint(style.tint)
            .focused($isEditing)
            .frame(minWidth: 60)
            .fixedSize()
            .onChange(of: pointsText) { _, newValue in
                let filtered = newValue.filter(\.isNumber)
                if filtered != newValue { pointsText = filtered }
                if let v = Int(filtered), v >= 1, v <= 9999 {
                    points = v
                }
            }
            .onChange(of: isEditing) { _, editing in
                if !editing {
                    // reset display if text is empty or out of range
                    if Int(pointsText) == nil || (Int(pointsText) ?? 0) < 1 {
                        points = max(1, points)
                        pointsText = "\(points)"
                    }
                }
            }
    }

    private func stepperButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: PointSystemStyle.stepperButtonIconSize, weight: .light))
                .foregroundStyle(style.tint)
                .frame(width: PointSystemStyle.stepperButtonSize,
                       height: PointSystemStyle.stepperButtonSize)
                .background(.white)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(style.tint,
                                    lineWidth: PointSystemStyle.stepperButtonBorderWidth)
                )
                .shadow(color: .black.opacity(0.10), radius: 4, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: Note field

    private var noteField: some View {
        TextField("Note (optional)", text: $noteText, axis: .vertical)
            .font(.body)
            .frame(minHeight: 24)
            .padding(.horizontal, PointSystemStyle.formFieldHPadding)
            .padding(.vertical, PointSystemStyle.formFieldVPadding)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: PointSystemStyle.formFieldCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: PointSystemStyle.formFieldCornerRadius)
                    .stroke(Color(.systemGray4), lineWidth: 1.5)
            )
    }

    // MARK: More section

    private var moreSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isMoreExpanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(isMoreExpanded ? "Less" : "More")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .rotationEffect(.degrees(isMoreExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isMoreExpanded)
                }
                .foregroundStyle(style.tint)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            if isMoreExpanded {
                HStack(spacing: 8) {
                    Text("🚧")
                    Text("Coming soon")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: Confirm section

    private var confirmSection: some View {
        VStack(spacing: 8) {
            Button {
                submitForm()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(style.confirmLabel)
                            .font(.body.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, PointSystemStyle.formConfirmVPadding)
                .background(
                    LinearGradient(
                        colors: [style.tint, style.tint.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: PointSystemStyle.formConfirmCornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting || points < 1)

            if let msg = errorMessage {
                Text(verbatim: msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Submit

    private func submitForm() {
        guard points >= 1, !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true
        isEditing = false
        let delta = style.sign * points
        let note = noteText.isEmpty ? nil : noteText
        Task {
            do {
                let response = try await PointSystemService.addPointEvent(
                    familyId: familyId,
                    memberId: memberId,
                    delta: delta,
                    note: note,
                    date: localDateString()
                )
                isSubmitting = false
                onSuccess(response.newBalance)
            } catch PointSystemError.unauthorized {
                isSubmitting = false
                onLogOut()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

