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

struct ModuleSelectionView: View {
    var familyName: String
    var role: FamilyRole
    var customRole: String = ""
    var onComplete: ([FamilyMembership]) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var enabledOptionals:  Set<AppModule> = []
    @State private var expandedOptionals: Set<AppModule> = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var mandatoryModules: [AppModule] { AppModule.allCases.filter { $0.isMandatory } }
    private var optionalModules:  [AppModule] { AppModule.allCases.filter { !$0.isMandatory } }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.bold())
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                }
                Text("Customize Your Space")
                    .font(.title.bold())
            }
            .padding(.horizontal, AuthStyle.screenHPadding)
            .frame(height: AuthStyle.topRowHeight)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Always included")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 32)
                        .padding(.bottom, 12)

                    VStack(spacing: 10) {
                        ForEach(mandatoryModules, id: \.self) { mandatoryCard($0) }
                    }

                    Text("Optional")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, AuthStyle.sectionSpacing)
                        .padding(.bottom, 12)

                    VStack(spacing: 10) {
                        ForEach(optionalModules, id: \.self) { optionalCard($0) }
                    }
                }
                .padding(.horizontal, AuthStyle.screenHPadding)
                .padding(.bottom, 24)
            }

            Button {
                isLoading = true
                let memberDisplayName = role == .other
                    ? (customRole.trimmingCharacters(in: .whitespaces).isEmpty ? role.rawLabel : customRole.trimmingCharacters(in: .whitespaces))
                    : role.rawLabel
                let mandatoryIds = AppModule.allCases.filter { $0.isMandatory }.map { $0.rawValue }
                let optionalIds  = enabledOptionals.map { $0.rawValue }
                // TODO: kid role — parent can view/edit kids' points; kid can only view. Handle role branching before this call.
                Task {
                    do {
                        let membership = try await FamilyService.createFamily(
                            name: familyName,
                            displayName: memberDisplayName,
                            modules: mandatoryIds + optionalIds
                        )
                        onComplete([membership])
                    } catch {
                        errorMessage = error.localizedDescription
                        isLoading = false
                    }
                }
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(Color(UIColor.systemBackground))
                    } else {
                        Text("Done").font(.body.bold())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AuthStyle.buttonVPadding)
                .background(Color.primary)
                .foregroundStyle(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: AuthStyle.buttonCornerRadius))
            }
            .disabled(isLoading)
            .padding(.horizontal, AuthStyle.screenHPadding)
            .padding(.top, 16)
            .padding(.bottom, 48)
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func mandatoryCard(_ module: AppModule) -> some View {
        HStack(spacing: 14) {
            Image(systemName: module.icon)
                .font(.system(size: 20))
                .foregroundStyle(Color.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(module.title)
                    .font(.subheadline.weight(.semibold))
                Text(module.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: FamilyStyle.fieldCornerRadius))
    }

    @ViewBuilder
    private func optionalCard(_ module: AppModule) -> some View {
        let isEnabled  = enabledOptionals.contains(module)
        let isExpanded = expandedOptionals.contains(module)

        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: module.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(module.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                    Text(module.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 14) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded { expandedOptionals.remove(module) }
                            else { expandedOptionals.insert(module) }
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 20, height: 20)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isEnabled { enabledOptionals.remove(module) }
                            else { enabledOptionals.insert(module) }
                        }
                    } label: {
                        Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isEnabled ? Color.primary : Color(.systemGray3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if isExpanded && !module.features.isEmpty {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(module.features.indices, id: \.self) { i in
                        let feature = module.features[i]
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: feature.icon)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.secondary)
                                .frame(width: 16)
                                .padding(.top, 2)
                            Text(feature.text)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: FamilyStyle.fieldCornerRadius))
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

#Preview {
    NavigationStack {
        ModuleSelectionView(familyName: "The Yangs", role: .dad)
    }
}

#Preview("中文") {
    NavigationStack {
        ModuleSelectionView(familyName: "杨家", role: .mom)
    }
    .environment(\.locale, .init(identifier: "zh-Hans"))
}
