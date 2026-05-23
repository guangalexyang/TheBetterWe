import Foundation

enum PointSystemError: LocalizedError {
    case network
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .network:      return String(localized: "Network error. Please try again.")
        case .unauthorized: return String(localized: "Session expired. Please log in again.")
        }
    }
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
        note: String?
    ) async throws -> PointEventResponse {
        struct Body: Encodable {
            let memberId: Int
            let delta: Int
            let note: String?
        }
        let data = try await post(
            path: "/families/\(familyId)/point-system/events",
            body: Body(memberId: memberId, delta: delta, note: note),
            expectedStatus: 201
        )
        guard let response = try? JSONDecoder().decode(PointEventResponse.self, from: data) else {
            throw PointSystemError.network
        }
        return response
    }

    // MARK: - Helpers

    private static func get(path: String) async throws -> Data {
        guard let token = AuthService.accessToken else { throw PointSystemError.unauthorized }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(request, expectedStatus: 200)
    }

    private static func post<B: Encodable>(path: String, body: B, expectedStatus: Int) async throws -> Data {
        guard let token = AuthService.accessToken else { throw PointSystemError.unauthorized }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(body)
        return try await send(request, expectedStatus: expectedStatus)
    }

    private static func send(_ request: URLRequest, expectedStatus: Int) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw PointSystemError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw PointSystemError.unauthorized }
        guard status == expectedStatus else { throw PointSystemError.network }
        return data
    }
}
