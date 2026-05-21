import SwiftUI

struct AddChildSheet: View {
    let onAdd: (PSChild) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Child's name", text: $name)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("New Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(PSChild(id: Int.random(in: 1000...9999), name: trimmed, balance: 0))
                        dismiss()
                    }
                    .disabled(trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    AddChildSheet { _ in }
}
