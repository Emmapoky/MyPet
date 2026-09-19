import SwiftUI

/// One-line logging: type or dictate a sentence, check what MyPet understood,
/// confirm. Lingsha's Shortcut idea, rebuilt inside the app (see
/// `QuickCaptureParser` for why it no longer needs an external AI).
struct QuickCaptureView: View {

    @Environment(MyPetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var selectedPetID: UUID?
    @State private var savedMessage: String?
    @FocusState private var isFocused: Bool

    init(initialText: String = "") {
        _text = State(initialValue: initialText)
    }

    private var parser: QuickCaptureParser { QuickCaptureParser(pets: store.pets) }
    private var result: QuickCaptureParser.Result { parser.parse(text) }

    private var targetPet: Pet? {
        if let id = result.petID ?? selectedPetID { return store.pet(id: id) }
        return nil
    }

    private let examples = [
        "Biscuit ate half his dinner, a bit sleepy",
        "Mochi finished her food and pooped normally",
        "Didn't eat breakfast, hiding under the bed",
        "Weighed 4.2 kg, very playful today"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    header
                    inputCard
                    understoodCard
                    if result.petID == nil && store.pets.count > 1 { petPicker }
                    examplesCard
                }
                .padding(16)
            }
            .background(Theme.pageGradient.ignoresSafeArea())
            .navigationTitle("Quick capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(targetPet == nil || text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { isFocused = text.isEmpty }
            .overlay(alignment: .bottom) {
                if let savedMessage {
                    Label(savedMessage, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Theme.positive, in: Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.bubble.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Theme.brandLavender, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("Just say what happened")
                    .font(.headline)
                Text("MyPet turns one sentence into today's log. You check it, then save. It runs on your phone, so there's no AI account and no cost.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("e.g. Biscuit ate half his dinner, a bit sleepy", text: $text, axis: .vertical)
                .lineLimit(2...5)
                .focused($isFocused)
                .font(.body)
            Label("Tap the 🎙️ on the keyboard to speak instead of typing.", systemImage: "mic.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .petCard(accent: Theme.brandLavender)
    }

    @ViewBuilder
    private var understoodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What MyPet understood")
                .font(.subheadline.weight(.semibold))

            if result.understood.isEmpty {
                Text(text.isEmpty ? "Start typing and the details appear here." : "Nothing recognised yet. Try words like 'ate half', 'sleepy', 'pooped normally'.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowChips(items: result.understood)
            }

            if let pet = targetPet {
                Text("Will update \(pet.name)'s log for today. Anything not mentioned keeps its usual value.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .petCard(accent: Theme.brandTeal)
    }

    private var petPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Which pet?").font(.subheadline.weight(.semibold))
            HStack {
                ForEach(store.pets) { pet in
                    Button {
                        selectedPetID = pet.id
                    } label: {
                        Label(pet.name, systemImage: pet.symbolName)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(selectedPetID == pet.id ? pet.accent.opacity(0.25) : Color.secondary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .petCard()
    }

    private var examplesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Try one").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(examples, id: \.self) { example in
                Button {
                    text = example
                } label: {
                    Text("“\(example)”")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            Label("Also works from Siri and the Shortcuts app: “Log my pet in MyPet”.", systemImage: "square.2.layers.3d")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // MARK: Save

    private func save() {
        guard let pet = targetPet else { return }
        let draft = store.draftLog(for: pet, on: .now)
        store.record(log: QuickCaptureParser.apply(result, text: text, to: draft))
        withAnimation { savedMessage = "Saved to \(pet.name)'s log" }
        Task {
            try? await Task.sleep(for: .seconds(1.1))
            dismiss()
        }
    }
}

// MARK: - FlowChips

/// Wrapping row of small rounded labels.
struct FlowChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.brandTeal.opacity(0.15), in: Capsule())
            }
        }
    }
}

/// Minimal wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
