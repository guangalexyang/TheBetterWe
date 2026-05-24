import Foundation

// MARK: - Error

enum PointsIntentError: LocalizedError {
    case notLoggedIn
    case notParent
    case notInFamily
    case childNotFound
    case childAmbiguous
    case network

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:    return String(localized: "Please log in to TheBetterWe first.")
        case .notParent:      return String(localized: "Only parents can adjust points.")
        case .notInFamily:    return String(localized: "You haven't joined a family yet. Please open TheBetterWe.")
        case .childNotFound:  return String(localized: "Couldn't find that child. Please open TheBetterWe.")
        case .childAmbiguous: return String(localized: "Multiple children match that name. Please open TheBetterWe.")
        case .network:        return String(localized: "Network error. Please try again.")
        }
    }
}

// MARK: - Support

enum PointsIntentSupport {

    /// Verifies the user is logged in and is a parent (not a child role).
    /// Uses memberships[0] — same family selection as the main app.
    static func requireParentMembership() async throws -> FamilyMembership {
        guard AuthService.isAuthenticated else { throw PointsIntentError.notLoggedIn }
        let memberships: [FamilyMembership]
        do {
            memberships = try await FamilyService.fetchMine()
        } catch FamilyError.unauthorized {
            throw PointsIntentError.notLoggedIn
        } catch {
            throw PointsIntentError.network
        }
        guard let membership = memberships.first else { throw PointsIntentError.notInFamily }
        guard !membership.roleKeywords.contains("child") else { throw PointsIntentError.notParent }
        return membership
    }

    /// Finds a unique child by matching `name` case-insensitively against any
    /// whitespace-separated token in each child's stored name.
    /// "Noah" matches "Noah Yang"; "Yang" also matches "Noah Yang".
    static func resolveChild(named name: String, familyId: Int) async throws -> PSChild {
        let children: [PSChild]
        do {
            children = try await PointSystemService.fetchChildren(familyId: familyId)
        } catch {
            throw PointsIntentError.network
        }
        let query = name.lowercased().trimmingCharacters(in: .whitespaces)
        let matches = children.filter { child in
            let childLower = child.name.lowercased()
            return childLower == query ||
                childLower.components(separatedBy: .whitespaces).contains(query)
        }
        switch matches.count {
        case 0:  throw PointsIntentError.childNotFound
        case 1:  return matches[0]
        default: throw PointsIntentError.childAmbiguous
        }
    }

    /// Posts a point event and returns the child's new balance.
    /// Pass a positive delta to add, negative to deduct.
    static func adjustPoints(
        familyId: Int,
        memberId: Int,
        delta: Int,
        note: String?
    ) async throws -> Int {
        do {
            let response = try await PointSystemService.addPointEvent(
                familyId: familyId,
                memberId: memberId,
                delta: delta,
                note: note
            )
            return response.newBalance
        } catch PointSystemError.unauthorized {
            throw PointsIntentError.notLoggedIn
        } catch {
            throw PointsIntentError.network
        }
    }
}
