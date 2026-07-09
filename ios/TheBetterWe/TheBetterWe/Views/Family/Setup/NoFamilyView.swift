import SwiftUI

struct NoFamilyView: View {
    var displayName: String? = AuthService.displayName
    var onComplete: ([FamilyMembership]) -> Void = { _ in }

    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    if let name = displayName {
                        Text("\(name),")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                    }

                    Text("你还没有加入家庭")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("创建新家庭，或扫描邀请码加入已有家庭。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                AddFamilyView(onComplete: onComplete)
                    .padding(.bottom, 48)
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(
                LinearGradient(
                    colors: theme.pageBgGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }
    }
}

#Preview {
    NoFamilyView(displayName: "Alex")
        .environment(ThemeManager())
        .environment(\.appTheme, .dark)
}

#Preview("Light") {
    NoFamilyView(displayName: "Alex")
        .environment(ThemeManager())
        .environment(\.appTheme, .light)
        .preferredColorScheme(.light)
}

#Preview("中文") {
    NoFamilyView(displayName: "Alex")
        .environment(ThemeManager())
        .environment(\.appTheme, .dark)
        .environment(\.locale, .init(identifier: "zh-Hans"))
}
