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
