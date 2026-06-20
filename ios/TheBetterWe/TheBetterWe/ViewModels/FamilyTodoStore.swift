import Foundation
import Observation

@Observable
final class FamilyTodoStore {
    var active:    [FamilyTodo] = []
    var completed: [FamilyTodo] = []
    var isLoading: Bool = false
    var loadError: String? = nil

    private(set) var familyId: Int = 0

    func load(familyId: Int, filter: String = "all") async {
        self.familyId = familyId
        isLoading = true
        loadError = nil
        do {
            let resp = try await FamilyTodoService.fetchTodos(familyId: familyId, filter: filter)
            active    = resp.active
            completed = resp.completed
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    func create(body: CreateTodoBody) async {
        do {
            let todo = try await FamilyTodoService.createTodo(familyId: familyId, body: body)
            active.insert(todo, at: 0)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func complete(todoId: Int) async {
        do {
            let updated = try await FamilyTodoService.patchTodo(
                familyId: familyId,
                todoId: todoId,
                body: PatchTodoBody(completed: true)
            )
            active.removeAll { $0.id == todoId }
            completed.insert(updated, at: 0)
            if completed.count > 20 { completed = Array(completed.prefix(20)) }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func reactivate(todoId: Int) async {
        do {
            let updated = try await FamilyTodoService.patchTodo(
                familyId: familyId,
                todoId: todoId,
                body: PatchTodoBody(completed: false)
            )
            completed.removeAll { $0.id == todoId }
            active.insert(updated, at: 0)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func delete(todoId: Int) async {
        do {
            try await FamilyTodoService.deleteTodo(familyId: familyId, todoId: todoId)
            active.removeAll    { $0.id == todoId }
            completed.removeAll { $0.id == todoId }
        } catch {
            loadError = error.localizedDescription
        }
    }
}
