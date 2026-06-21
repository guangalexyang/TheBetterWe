import SwiftUI

// MARK: - Shared check-off animation constants

enum CheckOffAnimation {
    static let duration: Double = 0.5
    static let delay: Double = 0.8
}

// MARK: - Animated strikethrough text

struct StrikeableText: View {
    let text: String
    let font: Font
    let isStriking: Bool
    var lineLimit: Int? = nil

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(isStriking ? Color.secondary : Color.primary)
            .lineLimit(lineLimit)
            .overlay(alignment: .leading) {
                Rectangle()
                    .frame(height: 1.5)
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .scaleEffect(x: isStriking ? 1.0 : 0.0, anchor: .leading)
            }
    }
}

// MARK: - Animated checkbox box

struct CheckOffBox: View {
    let isChecked: Bool
    let size: CGFloat
    let cornerRadius: CGFloat
    let checkmarkSize: CGFloat

    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isChecked ? theme.primaryAccent : Color.clear)
                .overlay {
                    if !isChecked {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(theme.cardBorder, lineWidth: 1.5)
                    }
                }
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: checkmarkSize, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}
