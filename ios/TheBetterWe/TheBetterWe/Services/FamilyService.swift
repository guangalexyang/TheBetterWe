import Foundation

enum FamilyError: LocalizedError {
    case network
    case unauthorized
    case notFound
    case alreadyMember

    var errorDescription: String? {
        switch self {
        case .network:       return String(localized: "Network error. Please try again.")
        case .unauthorized:  return "Session expired. Please log in again."
        case .notFound:      return "Family not found."
        case .alreadyMember: return "Already a member of this family."
        }
    }
}

enum FamilyService {
    private static let baseURL = AuthService.baseURL

    static func fetchMine() async throws -> [FamilyMembership] {
        let data = try await get(path: "/families/mine")
        guard let memberships = try? JSONDecoder().decode([FamilyMembership].self, from: data) else {
            throw FamilyError.network
        }
        return memberships
    }

    static func deleteFamily(id: Int) async throws {
        guard let token = AuthService.accessToken else { throw FamilyError.unauthorized }
        var request = URLRequest(url: baseURL.appending(path: "/families/\(id)"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await send(request, expectedStatus: 204)
    }

    static func createFamily(name: String, displayName: String, modules: [String]) async throws -> FamilyMembership {
        struct Body: Encodable {
            let familyName: String
            let displayName: String
            let roleKeywords: [String]
        }
        let data = try await post(
            path: "/families",
            body: Body(familyName: name, displayName: displayName, roleKeywords: modules),
            expectedStatus: 201
        )
        guard let membership = try? JSONDecoder().decode(FamilyMembership.self, from: data) else {
            throw FamilyError.network
        }
        return membership
    }

    // MARK: - Helpers

    private static func get(path: String) async throws -> Data {
        guard let token = AuthService.accessToken else { throw FamilyError.unauthorized }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return try await send(request, expectedStatus: 200)
    }

    private static func post<B: Encodable>(path: String, body: B, expectedStatus: Int) async throws -> Data {
        guard let token = AuthService.accessToken else { throw FamilyError.unauthorized }
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
            throw FamilyError.network
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw FamilyError.unauthorized }
        if status == 404 { throw FamilyError.notFound }
        if status == 409 { throw FamilyError.alreadyMember }
        guard status == expectedStatus else { throw FamilyError.network }
        return data
    }
}
