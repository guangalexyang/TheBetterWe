import Foundation

enum FamilyTodoService {
    private static let baseURL = AuthService.baseURL

    static func fetchTodos(familyId: Int, filter: String = "all") async throws -> FamilyTodoListResponse {
        let path = "/families/\(familyId)/todos?filter=\(filter)"
        let url = URL(string: baseURL.absoluteString + path)!
        guard let token = AuthService.accessToken else { throw URLError(.userAuthenticationRequired) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(FamilyTodoListResponse.self, from: data)
    }

    static func createTodo(familyId: Int, body: CreateTodoBody) async throws -> FamilyTodo {
        let url = URL(string: baseURL.absoluteString + "/families/\(familyId)/todos")!
        guard let token = AuthService.accessToken else { throw URLError(.userAuthenticationRequired) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(FamilyTodo.self, from: data)
    }

    static func patchTodo(familyId: Int, todoId: Int, body: PatchTodoBody) async throws -> FamilyTodo {
        let url = URL(string: baseURL.absoluteString + "/families/\(familyId)/todos/\(todoId)")!
        guard let token = AuthService.accessToken else { throw URLError(.userAuthenticationRequired) }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(FamilyTodo.self, from: data)
    }

    static func deleteTodo(familyId: Int, todoId: Int) async throws {
        let url = URL(string: baseURL.absoluteString + "/families/\(familyId)/todos/\(todoId)")!
        guard let token = AuthService.accessToken else { throw URLError(.userAuthenticationRequired) }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 204 else {
            throw URLError(.badServerResponse)
        }
    }
}
