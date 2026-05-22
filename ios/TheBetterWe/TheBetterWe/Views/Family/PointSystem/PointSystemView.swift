import SwiftUI

// MARK: - ChildCard

private struct ChildCard: View {
    let child: PSChild

    private static let birthdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func ageString() -> String? {
        guard let birthday = child.birthday else { return nil }
        guard let date = Self.birthdayFormatter.date(from: birthday) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: date, to: .now).year ?? 0
        return String(format: String(localized: "%d years old"), years)
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: PointSystemStyle.avatarSize, height: PointSystemStyle.avatarSize)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.85),
                                        lineWidth: PointSystemStyle.avatarBorderWidth)
                    )
                Text(child.gender.avatarEmoji)
                    .font(.system(size: 42))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: child.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if let age = ageString() {
                    Text(verbatim: age)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.80))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: PointSystemStyle.cardHeight)
        .background(
            LinearGradient(
                colors: child.gender.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: PointSystemStyle.cardCornerRadius))
    }
}

// MARK: - PageDots

private struct PageDots: View {
    let count: Int
    let selected: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == selected ? activeColor : Color(.systemGray3))
                    .frame(width: i == selected ? PointSystemStyle.activeDotWidth : PointSystemStyle.dotSize,
                           height: PointSystemStyle.dotSize)
                    .animation(.easeInOut(duration: 0.2), value: selected)
            }
        }
    }
}

// MARK: - Previews

#Preview("ChildCard — boy") {
    ChildCard(child: PSChild(memberId: 1, name: "桅", gender: .boy,
                             birthday: "2022-03-15", balance: 0))
        .padding()
}

#Preview("ChildCard — girl") {
    ChildCard(child: PSChild(memberId: 2, name: "朵", gender: .girl,
                             birthday: "2020-07-04", balance: 0))
        .padding()
}

#Preview("ChildCard — unknown, no birthday") {
    ChildCard(child: PSChild(memberId: 3, name: "小明", gender: nil,
                             birthday: nil, balance: 0))
        .padding()
}

#Preview("PageDots — 3 kids, page 1 active") {
    PageDots(count: 3, selected: 1,
             activeColor: Color(red: 58/255, green: 123/255, blue: 213/255))
        .padding()
}
