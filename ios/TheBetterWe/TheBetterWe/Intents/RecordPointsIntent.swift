import AppIntents
import OSLog

private let recordPointsLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TheBetterWe", category: "RecordPointsIntent")

struct RecordPointsIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Record Points"
    static let description = IntentDescription(
        "Add or deduct points with a single spoken sentence"
    )

    @Parameter(
        title: "Points Command",
        requestValueDialog: IntentDialog(
            "What points would you like to record? For example: Add 5 points to Noah for doing homework."
        )
    )
    var command: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        recordPointsLogger.info("command received: '\(command)'")

        do {
            // 1. Auth + parent check
            let membership = try await PointsIntentSupport.requireParentMembership()

            // 2. Parse utterance via server → Gemini
            let parsed = try await PointsIntentSupport.parseVoiceCommand(
                utterance: command,
                familyId: membership.familyId
            )
            recordPointsLogger.info("parsed — member: '\(parsed.memberName)', delta: \(parsed.delta), note: '\(parsed.note ?? "nil")'")

            // 3. Build confirmation dialog
            let absPoints = abs(parsed.delta)
            let pts = absPoints == 1 ? "point" : "points"
            let verb = parsed.delta > 0 ? "Add" : "Deduct"
            let prep = parsed.delta > 0 ? "to" : "from"
            let dateStr = parsed.date.map { RecordPointsIntent.formatDate($0) }

            let confirmMsg: String
            switch (parsed.note, dateStr) {
            case let (note?, date?):
                confirmMsg = "\(verb) \(absPoints) \(pts) \(prep) \(parsed.memberName) for \"\(note)\" on \(date)?"
            case let (note?, nil):
                confirmMsg = "\(verb) \(absPoints) \(pts) \(prep) \(parsed.memberName) for \"\(note)\"?"
            case let (nil, date?):
                confirmMsg = "\(verb) \(absPoints) \(pts) \(prep) \(parsed.memberName) on \(date)?"
            case (nil, nil):
                confirmMsg = "\(verb) \(absPoints) \(pts) \(prep) \(parsed.memberName)?"
            }

            try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: confirmMsg)))

            // 4. Execute
            let newBalance = try await PointsIntentSupport.adjustPoints(
                familyId: membership.familyId,
                memberId: parsed.memberId,
                delta: parsed.delta,
                note: parsed.note,
                date: parsed.date
            )

            // 5. Success dialog
            let pastVerb = parsed.delta > 0 ? "Added" : "Deducted"
            let successMsg: String
            switch (parsed.note, dateStr) {
            case let (note?, date?):
                successMsg = "\(pastVerb) \(absPoints) \(pts) \(prep) \(parsed.memberName) for \"\(note)\" on \(date). Balance: \(newBalance) pts."
            case let (note?, nil):
                successMsg = "\(pastVerb) \(absPoints) \(pts) \(prep) \(parsed.memberName) for \"\(note)\". Balance: \(newBalance) pts."
            case let (nil, date?):
                successMsg = "\(pastVerb) \(absPoints) \(pts) \(prep) \(parsed.memberName) on \(date). Balance: \(newBalance) pts."
            case (nil, nil):
                successMsg = "\(pastVerb) \(absPoints) \(pts) \(prep) \(parsed.memberName). Balance: \(newBalance) pts."
            }
            recordPointsLogger.info("success — new balance: \(newBalance)")
            return .result(dialog: IntentDialog(stringLiteral: successMsg))

        } catch let e as PointsIntentError {
            recordPointsLogger.warning("error '\(String(describing: e))' — command was: '\(command)'")
            // Open app for errors the user needs to resolve manually
            switch e {
            case .childNotFound, .childAmbiguous, .notLoggedIn, .notInFamily:
                try? await requestToContinueInForeground()
            case .notParent, .network:
                break
            case .unparseable:
                // Surface what was heard so the user can diagnose ASR vs parse issues
                return .result(dialog: IntentDialog(stringLiteral: "Heard: \"\(command)\". Couldn't parse — try: \"Add 5 points to Noah for doing homework\"."))
            }
            return .result(dialog: IntentDialog(stringLiteral: e.errorDescription ?? "请打开我们家。"))
        } catch {
            recordPointsLogger.error("unexpected error: \(error)")
            return .result(dialog: "An unexpected error occurred. Please try again.")
        }
    }

    // Formats "2026-05-24" → "May 24"
    private static func formatDate(_ iso: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: iso) else { return iso }
        let display = DateFormatter()
        display.dateFormat = "MMM d"
        return display.string(from: date)
    }
}
