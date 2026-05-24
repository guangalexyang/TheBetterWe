import AppIntents

struct DeductPointsIntent: AppIntent {
    static let title: LocalizedStringResource = "Deduct Points"
    static let description = IntentDescription("Deduct points from a child in TheBetterWe")

    @Parameter(title: "Child Name")
    var childName: String

    @Parameter(title: "Points")
    var amount: Int

    @Parameter(title: "Note")
    var note: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. Auth + role check — throws if not logged in or user is a child
        let membership = try await PointsIntentSupport.requireParentMembership()

        // 2. Resolve child — throws if not found or ambiguous
        let child = try await PointsIntentSupport.resolveChild(
            named: childName,
            familyId: membership.familyId
        )

        // 3. Confirmation dialog
        let pts = amount == 1 ? "point" : "points"
        let confirmMsg: String
        if let n = note, !n.isEmpty {
            confirmMsg = "Deduct \(amount) \(pts) from \(child.name) for \"\(n)\"?"
        } else {
            confirmMsg = "Deduct \(amount) \(pts) from \(child.name)?"
        }
        try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: confirmMsg)))

        // 4. Execute with negative delta — throws PointsIntentError.network on failure
        let newBalance = try await PointsIntentSupport.adjustPoints(
            familyId: membership.familyId,
            memberId: child.memberId,
            delta: -amount,
            note: note
        )

        // 5. Success dialog
        let successMsg: String
        if let n = note, !n.isEmpty {
            successMsg = "Deducted \(amount) \(pts) from \(child.name) for \"\(n)\". Balance: \(newBalance) pts."
        } else {
            successMsg = "Deducted \(amount) \(pts) from \(child.name). Balance: \(newBalance) pts."
        }
        return .result(dialog: IntentDialog(stringLiteral: successMsg))
    }
}
