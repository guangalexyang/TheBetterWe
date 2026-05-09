import Foundation

struct FamilyMembership: Codable {
    let familyId: Int
    let memberId: Int
    let displayName: String
    let roleKeywords: [String]
}

struct FamilyPreview: Decodable {
    let familyId: Int
    let familyName: String
}

struct FamilyInvite: Decodable {
    let familyId: Int
    let familyName: String
    let inviteCode: String
}
