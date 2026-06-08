import Foundation
import SwiftUI

enum ChildGender: String, CaseIterable, Codable {
    case boy, girl
}

struct PSChild: Identifiable, Equatable, Hashable, Codable {
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
    let eventDate: String   // "YYYY-MM-DD" or ISO 8601 from server
    let createdAt: Int      // Unix epoch

    var id: Int { eventId }

    var deltaText: String { delta >= 0 ? "+\(delta)" : "\(delta)" }
    var isPositive: Bool { delta > 0 }

    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(createdAt))
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return String(localized: "Today") }
        if cal.isDateInYesterday(date) { return String(localized: "Yesterday") }
        let display = DateFormatter()
        display.locale = Locale.current
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: Date())
        display.setLocalizedDateFormatFromTemplate(sameYear ? "MMMd" : "MMMdyyyy")
        return display.string(from: date)
    }
}

enum GoalLifespan: String, CaseIterable, Hashable {
    case daily   = "daily"
    case weekly  = "weekly"
    case monthly = "monthly"
    case oneTime = "one_time"

    var label: LocalizedStringKey {
        switch self {
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .oneTime: return "One-time"
        }
    }

    var icon: String {
        switch self {
        case .daily:   return "sun.horizon"
        case .weekly:  return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .oneTime: return "calendar.badge.checkmark"
        }
    }
}

struct PSGoal: Identifiable, Decodable {
    let goalId: Int
    let memberId: Int
    let name: String
    let targetPoints: Int
    let lifespan: String
    let startDate: String?   // "YYYY-MM-DD", only for one_time goals
    let endDate: String?     // "YYYY-MM-DD", only for one_time goals
    let periodProgress: Int

    var id: Int { goalId }
    var goalLifespan: GoalLifespan? { GoalLifespan(rawValue: lifespan) }
}

struct VoiceTranscriptResult: Decodable {
    let confidence: String
    let memberId: Int?
    let memberName: String?
    let delta: Int?
    let note: String?
    let date: String?
    let _debug: String?

    var isHighConfidence: Bool { confidence == "high" }

    var deltaDisplay: String {
        guard let d = delta else { return "" }
        return d > 0 ? "+\(d)" : "\(d)"
    }
}
