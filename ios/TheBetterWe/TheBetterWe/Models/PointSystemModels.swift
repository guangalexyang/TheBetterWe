import Foundation

enum ChildGender: String, CaseIterable {
    case boy, girl
}

struct PSChild: Identifiable, Equatable {
    let id: Int
    let name: String       // nickname / 小名
    var gender: ChildGender?
    var birthday: Date?
    var balance: Int
}
