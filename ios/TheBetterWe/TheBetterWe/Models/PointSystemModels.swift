import Foundation

enum ChildGender: String, CaseIterable, Codable {
    case boy, girl
}

struct PSChild: Identifiable, Equatable, Codable {
    let memberId: Int
    let name: String
    let gender: ChildGender?
    let birthday: String?   // "YYYY-MM-DD" from server
    var balance: Int

    var id: Int { memberId }
}

struct PointEventResponse: Decodable {
    let eventId: Int
    let memberId: Int
    let delta: Int
    let note: String?
    let newBalance: Int
}

struct PSActivity: Identifiable, Decodable {
    let eventId: Int
    let memberId: Int
    let delta: Int
    let note: String?
    let eventDate: String   // "YYYY-MM-DD"
    let createdAt: String   // ISO 8601

    var id: Int { eventId }

    // Returns "+25" or "-200"
    var deltaText: String {
        delta >= 0 ? "+\(delta)" : "\(delta)"
    }

    var isPositive: Bool { delta > 0 }
}

struct PSGoal: Identifiable, Decodable {
    let goalId: Int
    let memberId: Int
    let name: String
    let targetPoints: Int

    var id: Int { goalId }
}
