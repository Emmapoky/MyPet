import SwiftUI

struct PetsView: View {

    @Environment(MyPetStore.self) private var store
    var onQuickLog: (Pet) -> Void

    @State private var editingPet: Pet?
    @State private var isAddingPet = false

    var body: some View {
        NavigationStack {
            Group {
                if store.pets.isEmpty {
                    EmptyStateView(
                        symbol: "pawprint.circle",
                        title: "No pets yet",
                        message: "Add a pet to start tracking meals, medication and behaviour.",
                        actionTitle: "Add a pet",
                        action: { isAddingPet = true }
                    )
                } else {
                    List {
                        ForEach(store.pets) { pet in
                            NavigationLink {
                                PetDetailView(petID: pet.id)
                            } label: {
                                PetRow(pet: pet)
                            }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    editingPet = pet
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    onQuickLog(pet)
                                } label: {
                                    Label("Log", systemImage: "square.and.pencil")
                                }
                                .tint(Theme.positive)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Theme.pageGradient.ignoresSafeArea())
                }
            }
            .navigationTitle("Pets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingPet = true
                    } label: {
                        Label("Add pet", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingPet) {
                PetEditView(pet: nil)
            }
            .sheet(item: $editingPet) { pet in
                PetEditView(pet: pet)
            }
        }
    }
}

// MARK: - PetRow

struct PetRow: View {

    @Environment(MyPetStore.self) private var store
    let pet: Pet

    var body: some View {
        HStack(spacing: 12) {
            PetAvatar(pet: pet, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(pet.name).font(.headline)
                    if let severity = store.worstSeverity(for: pet.id) {
                        SeverityBadge(severity: severity, compact: true)
                    }
                }

                Text("\(pet.species.displayName)\(pet.breed.isEmpty ? "" : " · \(pet.breed)") · \(pet.ageDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Label(String(format: "%.2f kg", pet.weightKg), systemImage: "scalemass")
                    Label("\(store.loggingStreak(for: pet.id))/7 logged", systemImage: "calendar")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
