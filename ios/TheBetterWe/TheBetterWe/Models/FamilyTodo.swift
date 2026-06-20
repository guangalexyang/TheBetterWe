import Foundation

struct FamilyTodo: Codable, Identifiable {
    let id: Int
    let familyId: Int
    let createdByMemberId: Int
    let todoType: String
    let title: String
    let description: String?
    let location: String?
    let priority: String
    let dueAt: Int?
    let completedAt: Int?
    let completedByMemberId: Int?
    let completedByDisplayName: String?
    let createdAt: Int
    let updatedAt: Int
}

struct FamilyTodoListResponse: Codable {
    let active: [FamilyTodo]
    let completed: [FamilyTodo]
}

struct CreateTodoBody: Encodable {
    let todoType: String
    let title: String
    let description: String?
    let location: String?
    let priority: String
    let dueAt: Int?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(todoType,    forKey: .todoType)
        try c.encode(title,       forKey: .title)
        try c.encode(priority,    forKey: .priority)
        if let description { try c.encode(description, forKey: .description) }
        if let location    { try c.encode(location,    forKey: .location) }
        if let dueAt       { try c.encode(dueAt,       forKey: .dueAt) }
    }

    enum CodingKeys: String, CodingKey {
        case todoType, title, description, location, priority, dueAt
    }
}

struct PatchTodoBody: Encodable {
    var title: String? = nil
    var description: String? = nil
    var location: String? = nil
    var priority: String? = nil
    var dueAt: Int?? = nil
    var completed: Bool? = nil

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let title       { try c.encode(title,       forKey: .title) }
        if let description { try c.encode(description, forKey: .description) }
        if let location    { try c.encode(location,    forKey: .location) }
        if let priority    { try c.encode(priority,    forKey: .priority) }
        if let dueAt       { try c.encode(dueAt,       forKey: .dueAt) }
        if let completed   { try c.encode(completed,   forKey: .completed) }
    }

    enum CodingKeys: String, CodingKey {
        case title, description, location, priority, dueAt, completed
    }
}
