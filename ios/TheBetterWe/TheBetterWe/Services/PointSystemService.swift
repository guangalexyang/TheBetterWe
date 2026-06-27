import Foundation
import OSLog

func localDateString() -> String { localDateString(from: Date()) }

func localDateString(from date: Date) -> String {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd"
    return fmt.string(from: date)
}

private let pointSystemLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TheBetterWe", category: "PointSystemService")

enum PointSystemError: LocalizedError {
    case network
    case unauthorized
    case unparseable
    case childNotFound
    case childAmbiguous

    var errorDescription: String? {
        switch self {
        case .network:        return String(localized: "Network error. Please try again.")
        case .unauthorized:   return String(localized: "Session expired. Please log in again.")
        case .unparseable:    return String(localized: "Couldn't understand that command.")
        case .childNotFound:  return String(localized: "Couldn't find that child.")
        case .childAmbiguous: return String(localized: "Multiple children match that name.")
        }
    }
}

struct ParsedVoiceCommand {
    let memberId: Int
    let memberName: String
    let delta: Int       // signed: positive = add, negative = deduct
    let note: String?
    let date: String?    // YYYY-MM-DD or nil
}

enum PointSystemService {
    private static let baseURL = AuthService.baseURL

    static func fetchChildren(familyId: Int) async throws -> [PSChild] {
        let data = try await get(path: "/families/\(familyId)/point-system/children")
        guard let children = try? JSONDecoder().decode([PSChild].self, from: data) else {
            throw PointSystemError.network
        }
        return children
    }

    static func addChild(
        familyId: Int,
        name: String,
        gender: ChildGender?,
        birthday: String?
    ) async throws -> PSChild {
        struct Body: Encodable {
            let name: String
            let gender: String?
            let birthday: String?
        }
        let data = try await post(
            path: "/families/\(familyId)/point-system/children",
            body: Body(name: name, gender: gender?.rawValue, birthday: birthday),
            expectedStatus: 201
        )
        guard let child = try? JSONDecoder().decode(PSChild.self, from: data) else {
            throw PointSystemError.network
        }
        return child
    }

    static func addPointEvent(
        familyId: Int,
        memberId: Int,
        delta: Int,
        note: String?,
        date: String? = nil,
        eventType: String = "add"
    ) async throws -> PointEventResponse {
        struct Body: Encodable {
            let memberId: Int
            let delta: Int
            let note: String?
            let date: String?
            let eventType: String
        }
        let data = try await post(
            path: "/families/\(familyId)/point-system/events",
            body: Body(memberId: memberId, delta: delta, note: note, date: date, eventType: eventType),
            expectedStatus: 201
        )
        guard let response = try? JSONDecoder().decode(PointEventResponse.self, from: data) else {
            throw PointSystemError.network
        }
        return response
    }

    static func fetchActivities(familyId: Int, memberId: Int, limit: Int = 20, offset: Int = 0) async throws -> [PSActivity] {
        let data = try await get(path: "/families/\(familyId)/point-system/members/\(memberId)/events?limit=\(limit)&offset=\(offset)")
        do {
            return try JSONDecoder().decode([PSActivity].self, from: data)
        } catch {
            throw PointSystemError.network
        }
    }

    static func deleteActivity(familyId: Int, eventId: Int) async throws {
        try await delete(path: "/families/\(familyId)/point-system/events/\(eventId)")
    }

    static func fetchGoals(familyId: Int, memberId: Int) async throws -> [PSGoal] {
        let data = try await get(path: "/families/\(familyId)/point-system/members/\(memberId)/goals?localDate=\(localDateString())")
        guard let goals = try? JSONDecoder().decode([PSGoal].self, from: data) else {
            throw PointSystemError.network
        }
        return goals
    }

    static func createGoal(
        familyId: Int,
        memberId: Int,
        name: String,
        targetPoints: Int,
        lifespan: GoalLifespan,
        startDate: String?,
        endDate: String?
    ) async throws -> PSGoal {
        struct Body: Encodable {
            let memberId: Int
            let name: String
            let targetPoints: Int
            let lifespan: String
            let startDate: String?
            let endDate: String?
            let localDate: String
        }
        let data = try await post(
            path: "/families/\(familyId)/point-system/goals",
            body: Body(
                memberId: memberId,
                name: name,
                targetPoints: targetPoints,
                lifespan: lifespan.rawValue,
                startDate: startDate,
                endDate: endDate,
                localDate: localDateString()
            ),
            expectedStatus: 201
        )
        guard let goal = try? JSONDecoder().decode(PSGoal.self, from: data) else {
            throw PointSystemError.network
        }
        return goal
    }

    static func deleteGoal(familyId: Int, goalId: Int) async throws {
        try await delete(path: "/families/\(familyId)/point-system/goals/\(goalId)")
    }

    static func updateChild(
        familyId: Int,
        memberId: Int,
        name: String,
        gender: ChildGender?,
        birthday: String?
    ) async throws -> PSChild {
        struct Body: Encodable {
            let name: String
            let gender: String?
            let birthday: String?
        }
        let data = try await put(
            path: "/families/\(familyId)/point-system/members/\(memberId)",
            body: Body(name: name, gender: gender?.rawValue, birthday: birthday)
        )
        guard let child = try? JSONDecoder().decode(PSChild.self, from: data) else {
            throw PointSystemError.network
        }
        return child
    }

    static func deleteChild(familyId: Int, memberId: Int) async throws {
        try await delete(path: "/families/\(familyId)/point-system/members/\(memberId)")
    }

    static func parseTranscript(familyId: Int, transcript: String) async throws -> VoiceTranscriptResult {
        struct Body: Encodable {
            let transcript: String
            let familyId: Int
        }
        let data = try await post(
            path: "/voice/parse",
            body: Body(transcript: transcript, familyId: familyId),
            expectedStatus: 200
        )
        guard let result = try? JSONDecoder().decode(VoiceTranscriptResult.self, from: data) else {
            throw PointSystemError.network
        }
        return result
    }

    static func parseVoiceCommand(familyId: Int, utterance: String) async throws -> ParsedVoiceCommand {
        struct Body: Encodable {
            let utterance: String
        }
        struct Response: Decodable {
            let memberId: Int
            let memberName: String
            let delta: Int
            let note: String?
            let date: String?
        }

        let reqURL = try url(for: "/families/\(familyId)/point-system/parse-voice-command")
        let bodyData = try? JSONEncoder().encode(Body(utterance: utterance))
        let (data, status): (Data, Int)
        do {
            (data, status) = try await AuthService.authorizedData(for: reqURL, method: "POST", body: bodyData)
        } catch AuthError.sessionExpired {
            throw PointSystemError.unauthorized
        } catch {
            throw PointSystemError.network
        }
        switch status {
        case 200:
            guard let parsed = try? JSONDecoder().decode(Response.self, from: data) else {
                throw PointSystemError.network
            }
            return ParsedVoiceCommand(
                memberId: parsed.memberId,
                memberName: parsed.memberName,
                delta: parsed.delta,
                note: parsed.note,
                date: parsed.date
            )
        case 400, 500:
            throw PointSystemError.unparseable
        case 401:
            throw PointSystemError.unauthorized
        case 404:
            if let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let extracted = body["childName"] as? String {
                pointSystemLogger.warning("child_not_found — Doubao extracted name: '\(extracted)'")
            }
            throw PointSystemError.childNotFound
        case 409:
            throw PointSystemError.childAmbiguous
        default:
            throw PointSystemError.network
        }
    }

    // MARK: - Helpers

    private static func url(for path: String) throws -> URL {
        guard let url = URL(string: baseURL.absoluteString + path) else { throw PointSystemError.network }
        return url
    }

    private static func get(path: String) async throws -> Data {
        return try await send(url: try url(for: path), expectedStatus: 200)
    }

    private static func post<B: Encodable>(path: String, body: B, expectedStatus: Int) async throws -> Data {
        let bodyData = try? JSONEncoder().encode(body)
        return try await send(url: try url(for: path), method: "POST", body: bodyData, expectedStatus: expectedStatus)
    }

    private static func put<B: Encodable>(path: String, body: B) async throws -> Data {
        let bodyData = try? JSONEncoder().encode(body)
        return try await send(url: try url(for: path), method: "PUT", body: bodyData, expectedStatus: 200)
    }

    private static func delete(path: String) async throws {
        _ = try await send(url: try url(for: path), method: "DELETE", expectedStatus: 204)
    }

    @discardableResult
    private static func send(url: URL, method: String = "GET", body: Data? = nil, expectedStatus: Int) async throws -> Data {
        let (data, status): (Data, Int)
        do {
            (data, status) = try await AuthService.authorizedData(for: url, method: method, body: body)
        } catch AuthError.sessionExpired {
            throw PointSystemError.unauthorized
        } catch {
            throw PointSystemError.network
        }
        if status == 401 { throw PointSystemError.unauthorized }
        guard status == expectedStatus else { throw PointSystemError.network }
        return data
    }
}
