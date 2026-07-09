import SwiftUI

struct FamilySwitcherView: View {
    let memberships: [FamilyMembership]
    let currentFamilyId: Int
    var onSwitch: (FamilyMembership) -> Void = { _ in }
    var onFamiliesUpdated: ([FamilyMembership]) -> Void = { _ in }

    @State private var navigateToAdd = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    private let headerGradient = LinearGradient(
        colors: [
            Color(red: 240/255, green: 112/255, blue: 74/255),
            Color(red: 232/255, green: 93/255, blue: 122/255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Membership rows
                    VStack(spacing: 0) {
                        ForEach(memberships, id: \.familyId) { membership in
                            membershipRow(membership)

                            if membership.familyId != memberships.last?.familyId {
                                Divider()
                                    .padding(.leading, 76)
                            }
                        }
                    }
                    .background(theme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(theme.cardBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, FamilyStyle.screenHPadding)
                    .padding(.top, 20)

                    // Add row
                    Button {
                        navigateToAdd = true
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(theme.cardSurface)
                                    .overlay(Circle().stroke(theme.cardBorder, lineWidth: 1.5))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Text("加入或创建家庭")
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .padding(.horizontal, FamilyStyle.screenHPadding)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .background(theme.pageBg.ignoresSafeArea())
            .navigationTitle("切换家庭")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color(.systemGray5), in: Circle())
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToAdd) {
                AddFamilyView(onComplete: { newList in
                    onFamiliesUpdated(newList)
                    dismiss()
                })
            }
        }
    }

    @ViewBuilder
    private func membershipRow(_ membership: FamilyMembership) -> some View {
        let isCurrent = membership.familyId == currentFamilyId
        Button {
            guard !isCurrent else { return }
            onSwitch(membership)
            dismiss()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(headerGradient)
                        .frame(width: 48, height: 48)
                    Text(String(membership.familyName.prefix(1)))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: membership.familyName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(verbatim: membership.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.primaryAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FamilySwitcherView(
        memberships: [
            FamilyMembership(familyId: 1, familyName: "AY 的家", memberId: 1, displayName: "爸爸", roleKeywords: []),
            FamilyMembership(familyId: 2, familyName: "外婆家", memberId: 3, displayName: "女儿", roleKeywords: [])
        ],
        currentFamilyId: 1
    )
    .environment(ThemeManager())
    .environment(\.appTheme, .light)
}
