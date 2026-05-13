import SwiftUI

struct ModuleFeature {
    let icon: String
    let text: LocalizedStringKey
}

enum AppModule: String, CaseIterable, Hashable {
    case familyTodo
    case pointSystem
    case familyNotes
    case orderFromMe

    var isMandatory: Bool {
        switch self {
        case .familyTodo, .pointSystem, .familyNotes: return true
        case .orderFromMe: return false
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .familyTodo:  return "Family TODO"
        case .pointSystem: return "Point System"
        case .familyNotes: return "Family Notes"
        case .orderFromMe: return "OrderFromMe"
        }
    }

    var description: LocalizedStringKey {
        switch self {
        case .familyTodo:  return "Shared family task list"
        case .pointSystem: return "Award and track points for kids"
        case .familyNotes: return "Share notes and announcements"
        case .orderFromMe: return "The must-have assistant for your family chef"
        }
    }

    var icon: String {
        switch self {
        case .familyTodo:  return "checklist"
        case .pointSystem: return "star.fill"
        case .familyNotes: return "note.text"
        case .orderFromMe: return "fork.knife"
        }
    }

    var features: [ModuleFeature] {
        switch self {
        case .orderFromMe:
            return [
                ModuleFeature(icon: "book.closed.fill",  text: "Document and view recipes, AI integrated"),
                ModuleFeature(icon: "envelope.fill",     text: "Create and share your own menu to manage party invitations"),
                ModuleFeature(icon: "cart.fill",         text: "Convert party orders into a grocery shopping plan"),
            ]
        default:
            return []
        }
    }
}
