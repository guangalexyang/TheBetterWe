import AppIntents

struct RedeemRewardIntent: AppIntent {
    static let title: LocalizedStringResource = "Redeem Reward"
    static let description = IntentDescription("Redeem a reward for a child in TheBetterWe")

    @Parameter(title: "Child Name")
    var childName: String

    @Parameter(title: "Points")
    var amount: Int

    @Parameter(title: "Reward")
    var note: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let membership = try await PointsIntentSupport.requireParentMembership()

        let child = try await PointsIntentSupport.resolveChild(
            named: childName,
            familyId: membership.familyId
        )

        let pts = amount == 1 ? "point" : "points"
        let confirmMsg: String
        if let n = note, !n.isEmpty {
            confirmMsg = "Redeem \(amount) \(pts) from \(child.name) for \"\(n)\"?"
        } else {
            confirmMsg = "Redeem \(amount) \(pts) from \(child.name)?"
        }
        try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: confirmMsg)))

        let newBalance = try await PointsIntentSupport.adjustPoints(
            familyId: membership.familyId,
            memberId: child.memberId,
            delta: -amount,
            note: note,
            date: localDateString(),
            eventType: "redeem"
        )

        let successMsg: String
        if let n = note, !n.isEmpty {
            successMsg = "Redeemed \(amount) \(pts) from \(child.name) for \"\(n)\". Balance: \(newBalance) pts."
        } else {
            successMsg = "Redeemed \(amount) \(pts) from \(child.name). Balance: \(newBalance) pts."
        }
        return .result(dialog: IntentDialog(stringLiteral: successMsg))
    }
}
