import SwiftUI

enum PointSystemStyle {
    static let cardHeight: CGFloat = 130
    static let cardCornerRadius: CGFloat = 18
    static let avatarSize: CGFloat = 88
    static let avatarBorderWidth: CGFloat = 3
    static let cardHPadding: CGFloat = 16
    static let dotSize: CGFloat = 6
    static let activeDotWidth: CGFloat = 18
    static let cardTopPadding: CGFloat = 12
    static let cardBottomPadding: CGFloat = 8

    // Content section
    static let pointsBannerHPadding: CGFloat = 20
    static let pointsBannerVPadding: CGFloat = 16
    static let pointsValueFontSize: CGFloat = 40
    static let pointsUnitFontSize: CGFloat = 18
    static let actionListGap: CGFloat = 8
    static let rowIconSize: CGFloat = 32
    static let rowIconCornerRadius: CGFloat = 8
    static let rowHPadding: CGFloat = 20
    static let rowVPadding: CGFloat = 14

    static let addIconBackground    = Color(red: 0.91, green: 0.97, blue: 0.91)
    static let deductIconBackground = Color(red: 0.99, green: 0.91, blue: 0.91)
    static let recordIconBackground = Color(red: 0.91, green: 0.93, blue: 0.97)

    // Point adjust form
    static let formHPadding: CGFloat = 20
    static let formVPadding: CGFloat = 20
    static let stepperButtonSize: CGFloat = 44
    static let stepperButtonBorderWidth: CGFloat = 1.5
    static let stepperValueFontSize: CGFloat = 52
    static let stepperUnitFontSize: CGFloat = 14
    static let stepperButtonIconSize: CGFloat = 22
    static let formFieldCornerRadius: CGFloat = 10
    static let formFieldHPadding: CGFloat = 12
    static let formFieldVPadding: CGFloat = 10
    static let formConfirmVPadding: CGFloat = 13
    static let formConfirmCornerRadius: CGFloat = 12

    static let addTint    = Color(red: 58/255, green: 123/255, blue: 213/255)
    static let deductTint = Color(red: 217/255, green: 64/255, blue: 64/255)

    // Redesign v1.0.1
    static let memberGridColumns: Int = 4
    static let memberAvatarSize: CGFloat = 64
    static let memberAvatarBorderWidth: CGFloat = 2
    static let childCardCornerRadius: CGFloat = 16
    static let childCardBorderWidth: CGFloat = 1
    static let childCardPadding: CGFloat = 20
    static let childCardAvatarSize: CGFloat = 56
    static let pointsDisplayFontSize: CGFloat = 32
    static let actionButtonHeight: CGFloat = 48
    static let sectionHeaderFontSize: CGFloat = 20
    static let activityIconSize: CGFloat = 40
    static let goalProgressHeight: CGFloat = 16
}

// MARK: - ActionStyle

struct ActionStyle {
    let tint: Color
    let confirmLabel: LocalizedStringKey
    let sign: Int  // +1 for add points, -1 for deduct

    static let add = ActionStyle(
        tint: PointSystemStyle.addTint,
        confirmLabel: "Add Points",
        sign: 1
    )
    static let deduct = ActionStyle(
        tint: PointSystemStyle.deductTint,
        confirmLabel: "Deduct Points",
        sign: -1
    )
}

extension ChildGender {
    var gradientColors: [Color] {
        switch self {
        case .boy:
            return [Color(red: 58/255, green: 123/255, blue: 213/255),
                    Color(red: 91/255, green: 168/255, blue: 245/255)]
        case .girl:
            return [Color(red: 201/255, green: 75/255, blue: 158/255),
                    Color(red: 232/255, green: 124/255, blue: 192/255)]
        }
    }

    var avatarEmoji: String {
        switch self {
        case .boy:  return "👦"
        case .girl: return "👧"
        }
    }
}

extension Optional where Wrapped == ChildGender {
    var gradientColors: [Color] {
        self?.gradientColors ?? [Color(red: 90/255, green: 123/255, blue: 170/255),
                                 Color(red: 127/255, green: 160/255, blue: 200/255)]
    }

    var avatarEmoji: String {
        self?.avatarEmoji ?? "🧒"
    }

    var tintColor: Color {
        switch self {
        case .some(.boy):  return Color(red: 58/255,  green: 123/255, blue: 213/255)
        case .some(.girl): return Color(red: 201/255, green: 75/255,  blue: 158/255)
        case .none:        return Color(red: 90/255,  green: 123/255, blue: 170/255)
        }
    }
}
