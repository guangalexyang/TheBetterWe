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
        let url = URL(string: baseURL.absoluteString + "/families/\(id)")!
        _ = try await send(url: url, method: "DELETE", expectedStatus: 204)
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
        let url = URL(string: baseURL.absoluteString + path)!
        return try await send(url: url, expectedStatus: 200)
    }

    private static func post<B: Encodable>(path: String, body: B, expectedStatus: Int) async throws -> Data {
        let url = URL(string: baseURL.absoluteString + path)!
        let bodyData = try? JSONEncoder().encode(body)
        return try await send(url: url, method: "POST", body: bodyData, expectedStatus: expectedStatus)
    }

    @discardableResult
    private static func send(url: URL, method: String = "GET", body: Data? = nil, expectedStatus: Int) async throws -> Data {
        let (data, status): (Data, Int)
        do {
            (data, status) = try await AuthService.authorizedData(for: url, method: method, body: body)
        } catch AuthError.sessionExpired {
            throw FamilyError.unauthorized
        } catch {
            throw FamilyError.network
        }
        if status == 401 { throw FamilyError.unauthorized }
        if status == 404 { throw FamilyError.notFound }
        if status == 409 { throw FamilyError.alreadyMember }
        guard status == expectedStatus else { throw FamilyError.network }
        return data
    }
}
