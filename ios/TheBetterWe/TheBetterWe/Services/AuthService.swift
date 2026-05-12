import Foundation

enum AuthError: LocalizedError {
    case invalidCredentials
    case usernameTaken
    case network

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return String(localized: "Invalid username or password.")
        case .usernameTaken:      return String(localized: "Username already taken.")
        case .network:            return String(localized: "Network error. Please try again.")
        }
    }
}

enum AuthService {
    static let baseURL = URL(string: "http://localhost:3000")!

    private static let accessTokenKey  = "accessToken"
    private static let refreshTokenKey = "refreshToken"
    private static let displayNameKey  = "displayName"

    static var isAuthenticated: Bool {
        KeychainService.load(forKey: accessTokenKey) != nil
    }

    static var accessToken: String? {
        KeychainService.load(forKey: accessTokenKey)
    }

    static var displayName: String? {
        let name = KeychainService.load(forKey: displayNameKey)
        return (name?.isEmpty == false) ? name : nil
    }

    static func signUp(username: String, password: String) async throws {
        let response = try await post(
            path: "/auth/signup",
            body: ["username": username, "password": password],
            expectedStatus: 201
        )
        storeResponse(response)
    }

    static func logIn(username: String, password: String) async throws {
        let response = try await post(
            path: "/auth/login",
            body: ["username": username, "password": password],
            expectedStatus: 200
        )
        storeResponse(response)
    }

    static func updateDisplayName(_ name: String) async throws {
        guard let token = KeychainService.load(forKey: accessTokenKey) else {
            throw AuthError.network
        }
        var request = URLRequest(url: baseURL.appending(path: "/auth/display-name"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(["displayName": name])

        let (_, response): (Data, URLResponse)
        do {
            (_, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw AuthError.network }

        KeychainService.save(name, forKey: displayNameKey)
    }

    static func logOut() async {
        if let refresh = KeychainService.load(forKey: refreshTokenKey) {
            try? await post(
                path: "/auth/logout",
                body: ["refreshToken": refresh],
                expectedStatus: 204
            )
        }
        KeychainService.delete(forKey: accessTokenKey)
        KeychainService.delete(forKey: refreshTokenKey)
        KeychainService.delete(forKey: displayNameKey)
    }

    // MARK: - Helpers

    private struct AuthResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let displayName: String
    }

    @discardableResult
    private static func post(
        path: String,
        body: [String: String],
        expectedStatus: Int
    ) async throws -> AuthResponse {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if status == 409 { throw AuthError.usernameTaken }
        if status == 401 { throw AuthError.invalidCredentials }
        if status != expectedStatus { throw AuthError.network }

        if expectedStatus == 204 {
            return AuthResponse(accessToken: "", refreshToken: "", displayName: "")
        }

        guard let decoded = try? JSONDecoder().decode(AuthResponse.self, from: data) else {
            throw AuthError.network
        }
        return decoded
    }

    private static func storeResponse(_ response: AuthResponse) {
        KeychainService.save(response.accessToken, forKey: accessTokenKey)
        KeychainService.save(response.refreshToken, forKey: refreshTokenKey)
        KeychainService.save(response.displayName, forKey: displayNameKey)
    }
}
