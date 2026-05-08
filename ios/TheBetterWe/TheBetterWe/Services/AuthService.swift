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
    // Replace with real server URL for production.
    private static let baseURL = URL(string: "http://localhost:3000")!

    private static let accessTokenKey  = "accessToken"
    private static let refreshTokenKey = "refreshToken"

    static var isAuthenticated: Bool {
        KeychainService.load(forKey: accessTokenKey) != nil
    }

    static func signUp(username: String, password: String) async throws {
        let tokens = try await post(
            path: "/auth/signup",
            body: ["username": username, "password": password],
            expectedStatus: 201
        )
        storeTokens(tokens)
    }

    static func logIn(username: String, password: String) async throws {
        let tokens = try await post(
            path: "/auth/login",
            body: ["username": username, "password": password],
            expectedStatus: 200
        )
        storeTokens(tokens)
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
    }

    // MARK: - Helpers

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String
    }

    @discardableResult
    private static func post(
        path: String,
        body: [String: String],
        expectedStatus: Int
    ) async throws -> TokenResponse {
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
            return TokenResponse(accessToken: "", refreshToken: "")
        }

        guard let tokens = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw AuthError.network
        }
        return tokens
    }

    private static func storeTokens(_ tokens: TokenResponse) {
        KeychainService.save(tokens.accessToken, forKey: accessTokenKey)
        KeychainService.save(tokens.refreshToken, forKey: refreshTokenKey)
    }
}
