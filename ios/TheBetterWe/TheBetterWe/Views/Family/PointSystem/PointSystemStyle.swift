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
}
