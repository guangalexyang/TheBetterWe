import SwiftUI

struct FamilyView: View {
    var membership: FamilyMembership
    var onDeleted: () -> Void = {}

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Family") {
                    LabeledContent("Name", value: membership.familyName)
                    LabeledContent("ID", value: "\(membership.familyId)")
                }

                Section("My Info") {
                    LabeledContent("Display Name", value: membership.displayName)
                    LabeledContent("Member ID", value: "\(membership.memberId)")
                }

                Section("Modules") {
                    ForEach(membership.roleKeywords, id: \.self) { keyword in
                        Text(keyword)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Text("Delete Family")
                            Spacer()
                            if isDeleting { ProgressView() }
                        }
                    }
                    .disabled(isDeleting)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete \"\(membership.familyName)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Family", role: .destructive) {
                    isDeleting = true
                    Task {
                        do {
                            try await FamilyService.deleteFamily(id: membership.familyId)
                            onDeleted()
                        } catch {
                            errorMessage = error.localizedDescription
                            isDeleting = false
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

#Preview {
    FamilyView(membership: FamilyMembership(
        familyId: 1,
        familyName: "The Yangs",
        memberId: 1,
        displayName: "Dad",
        roleKeywords: ["familyTodo", "pointSystem", "familyNotes", "orderFromMe"]
    ))
}
