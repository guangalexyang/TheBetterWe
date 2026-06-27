import Foundation

enum FamilyTodoService {
    private static let baseURL = AuthService.baseURL

    static func fetchTodos(familyId: Int, filter: String = "all") async throws -> FamilyTodoListResponse {
        let (data, _) = try await send(path: "/families/\(familyId)/todos?filter=\(filter)", expectedStatus: 200)
        return try JSONDecoder().decode(FamilyTodoListResponse.self, from: data)
    }

    static func createTodo(familyId: Int, body: CreateTodoBody) async throws -> FamilyTodo {
        let bodyData = try JSONEncoder().encode(body)
        let (data, _) = try await send(path: "/families/\(familyId)/todos", method: "POST", body: bodyData, expectedStatus: 201)
        return try JSONDecoder().decode(FamilyTodo.self, from: data)
    }

    static func patchTodo(familyId: Int, todoId: Int, body: PatchTodoBody) async throws -> FamilyTodo {
        let bodyData = try JSONEncoder().encode(body)
        let (data, _) = try await send(path: "/families/\(familyId)/todos/\(todoId)", method: "PATCH", body: bodyData, expectedStatus: 200)
        return try JSONDecoder().decode(FamilyTodo.self, from: data)
    }

    static func deleteTodo(familyId: Int, todoId: Int) async throws {
        _ = try await send(path: "/families/\(familyId)/todos/\(todoId)", method: "DELETE", expectedStatus: 204)
    }

    // MARK: - Helper

    @discardableResult
    private static func send(path: String, method: String = "GET", body: Data? = nil, expectedStatus: Int) async throws -> (Data, Int) {
        let url = URL(string: baseURL.absoluteString + path)!
        let (data, status): (Data, Int)
        do {
            (data, status) = try await AuthService.authorizedData(for: url, method: method, body: body)
        } catch AuthError.sessionExpired {
            throw URLError(.userAuthenticationRequired)
        } catch {
            throw URLError(.badServerResponse)
        }
        guard status == expectedStatus else { throw URLError(.badServerResponse) }
        return (data, status)
    }
}
