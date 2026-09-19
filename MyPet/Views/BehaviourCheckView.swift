import PhotosUI
import SwiftUI

/// The Check tab: point the camera at your pet or record a few seconds of
/// sound, and MyPet says what everyday state is most likely ("high possibility
/// Biscuit is hungry"). Behaviour only, never a diagnosis.
///
/// Added after Supervisor Meeting 2 (18 Sep 2026), where Dr Yam described this
/// feature as a tab of its own and asked for photo or sound before video.
struct BehaviourCheckView: View {

    @Environment(MyPetStore.self) private var store

    @StateObject private var camera = CameraController()
    @StateObject private var recorder = SoundRecorder()

    @State private var mode: BehaviourCheckModel.Mode = .photo
    @State private var selectedPetID: UUID?
    @State private var phase: Phase = .ready
    @State private var elapsed: Double = 0
    @State private var results: [BehaviourCheckModel.Likelihood] = []
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var savedToLog = false

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    enum Phase: Equatable { case ready, capturing, analysing, done }

    /// Photo mode holds still for a short countdown so a moving pet can settle.
    private let photoHoldSeconds = 3.0
    private let soundMaxSeconds = 20.0

    private var pet: Pet? {
        if let selectedPetID, let pet = store.pet(id: selectedPetID) { return pet }
        return store.pets.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    petChips
                    Picker("Mode", selection: $mode) {
                        ForEach(BehaviourCheckModel.Mode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.symbolName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(phase == .capturing || phase == .analysing)

                    captureArea
                    controlBar

                    if phase == .done, let pet { resultCard(for: pet) }

                    footnote
                }
                .padding(16)
            }
            .background(Theme.pageGradient.ignoresSafeArea())
            .navigationTitle("Behaviour check")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if mode == .photo { camera.start() } }
            .onDisappear {
                camera.stop()
                recorder.stop()
            }
            .onChange(of: mode) { _, newMode in
                reset()
                if newMode == .photo { camera.start() } else { camera.stop() }
            }
            .onChange(of: pickedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pickedImage = image
                        finishCapture()
                    }
                }
            }
            .onReceive(tick) { _ in advance() }
        }
    }

    // MARK: Pet chips

    private var petChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.pets) { candidate in
                    let isSelected = candidate.id == pet?.id
                    Button {
                        selectedPetID = candidate.id
                        reset()
                    } label: {
                        HStack(spacing: 6) {
                            PetAvatar(pet: candidate, size: 26)
                            Text(candidate.name).font(.subheadline.weight(.medium))
                        }
                        .padding(.leading, 4)
                        .padding(.trailing, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(isSelected ? candidate.accent.opacity(0.22) : Theme.card))
                        .overlay(Capsule().strokeBorder(isSelected ? candidate.accent : Theme.cardBorder, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Capture area

    private var captureArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [Color.black.opacity(0.85), Theme.brandTeal.opacity(0.9)],
                                     startPoint: .top, endPoint: .bottom))

            if mode == .photo {
                photoContent
            } else {
                soundContent
            }

            ViewfinderCorners()
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .padding(22)

            VStack {
                HStack {
                    Label(mode == .photo ? "Fit \(pet?.name ?? "your pet") in the frame" : "Record \(pet?.name ?? "your pet")'s sounds",
                          systemImage: mode.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.35), in: Capsule())
                    Spacer()
                    if phase == .capturing {
                        Circle().fill(.red).frame(width: 10, height: 10)
                            .opacity(Int(elapsed * 2) % 2 == 0 ? 1 : 0.3)
                    }
                }
                Spacer()
                if phase == .analysing {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Analysing on your phone…").font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.4), in: Capsule())
                }
            }
            .padding(34)
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    @ViewBuilder
    private var photoContent: some View {
        if let pickedImage {
            Image(uiImage: pickedImage).resizable().scaledToFill()
        } else if camera.status == .running {
            CameraPreview(session: camera.session)
        } else {
            VStack(spacing: 10) {
                Image(systemName: camera.status == .denied ? "video.slash.fill" : "camera.viewfinder")
                    .font(.system(size: 54))
                Text(camera.status == .denied
                     ? "Camera access is off. Allow it in Settings, or choose a photo."
                     : "No camera here (the Simulator has none). Tap the shutter to try the flow, or choose a photo.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label("Choose a photo", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.white.opacity(0.2), in: Capsule())
                }
            }
            .foregroundStyle(.white)
        }
    }

    private var soundContent: some View {
        VStack(spacing: 18) {
            Image(systemName: phase == .capturing ? "mic.fill" : "mic")
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .scaleEffect(phase == .capturing ? 1.1 : 1)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: phase == .capturing)
            HStack(alignment: .center, spacing: 4) {
                ForEach(Array(recorder.levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(.white.opacity(0.9))
                        .frame(width: 4, height: max(4, level * 90))
                }
            }
            .frame(height: 90)
            .animation(.linear(duration: 0.08), value: recorder.levels)
        }
    }

    // MARK: Control bar (the timer at the bottom)

    private var controlBar: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timerText)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(timerCaption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: primaryAction) {
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Theme.brand, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .fill(phase == .capturing ? AnyShapeStyle(Color.red) : AnyShapeStyle(Theme.heroGradient))
                        .padding(10)
                    Image(systemName: buttonSymbol)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 78, height: 78)
            }
            .buttonStyle(.plain)
            .disabled(phase == .analysing || pet == nil || (phase == .capturing && !canStop))
            .accessibilityLabel(buttonAccessibilityLabel)

            Text(bottomHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .petCard()
    }

    private var target: Double {
        mode == .photo ? photoHoldSeconds : Double(BehaviourCheckModel.minimumSoundSeconds)
    }

    private var progress: CGFloat {
        switch phase {
        case .ready: 0
        case .capturing: CGFloat(min(elapsed / target, 1))
        case .analysing, .done: 1
        }
    }

    private var canStop: Bool { mode == .sound && elapsed >= target }

    private var timerText: String {
        let seconds = Int(elapsed)
        let shown = String(format: "00:%02d", seconds)
        return "\(shown) / \(String(format: "00:%02d", Int(target)))"
    }

    private var timerCaption: String {
        switch (mode, phase) {
        case (.photo, .capturing): "Hold steady…"
        case (.sound, .capturing): canStop ? "Enough recorded, tap to stop" : "Keep recording"
        case (_, .analysing): "Analysing"
        case (_, .done): "Done"
        case (.photo, _): "\(Int(photoHoldSeconds))-second hold"
        case (.sound, _): "At least \(BehaviourCheckModel.minimumSoundSeconds) seconds"
        }
    }

    private var buttonSymbol: String {
        switch phase {
        case .ready: mode == .photo ? "camera.fill" : "mic.fill"
        case .capturing: mode == .sound ? "stop.fill" : "hourglass"
        case .analysing: "ellipsis"
        case .done: "arrow.counterclockwise"
        }
    }

    private var buttonAccessibilityLabel: String {
        switch phase {
        case .ready: mode == .photo ? "Take photo" : "Start recording"
        case .capturing: "Stop"
        case .analysing: "Analysing"
        case .done: "Check again"
        }
    }

    private var bottomHint: String {
        mode == .photo ? "Only when you tap.\nNo 24/7 camera." : "Barks, meows,\nwhining…"
    }

    // MARK: Flow

    private func primaryAction() {
        switch phase {
        case .ready:
            elapsed = 0
            savedToLog = false
            withAnimation { phase = .capturing }
            if mode == .sound { Task { await recorder.start() } }
        case .capturing:
            if canStop { finishCapture() }
        case .analysing:
            break
        case .done:
            reset()
        }
    }

    private func advance() {
        guard phase == .capturing else { return }
        elapsed += 0.1
        if mode == .photo && elapsed >= photoHoldSeconds { finishCapture() }
        if mode == .sound && elapsed >= soundMaxSeconds { finishCapture() }
    }

    private func finishCapture() {
        guard let pet else { return }
        recorder.stop()
        withAnimation { phase = .analysing }
        let recent = store.logs(for: pet.id).first
        let seed = UInt64(Date.now.timeIntervalSince1970 * 1000) & 0xFFFF_FFFF
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            results = BehaviourCheckModel.analyse(mode: mode, pet: pet, recentLog: recent, seed: seed)
            withAnimation(.spring) { phase = .done }
        }
    }

    private func reset() {
        recorder.stop()
        elapsed = 0
        results = []
        pickedImage = nil
        pickedItem = nil
        savedToLog = false
        phase = .ready
    }

    // MARK: Result

    private func resultCard(for pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(results.first?.state.emoji ?? "🐾").font(.largeTitle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(BehaviourCheckModel.headline(for: results, petName: pet.name))
                        .font(.headline)
                    Text("From a \(mode == .photo ? "photo" : "sound clip") just now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(results.prefix(4)) { item in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("\(item.state.emoji) \(item.state.displayName)").font(.subheadline)
                        Spacer()
                        Text("\(Int((item.probability * 100).rounded()))%")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.12))
                            Capsule().fill(pet.accent)
                                .frame(width: geometry.size.width * item.probability)
                        }
                    }
                    .frame(height: 8)
                }
            }

            Label("A behaviour indication, not a diagnosis. If you're worried about your pet's health, talk to your vet.",
                  systemImage: "info.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                saveToLog(pet: pet)
            } label: {
                Label(savedToLog ? "Added to today's log" : "Add to today's log",
                      systemImage: savedToLog ? "checkmark" : "square.and.pencil")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(pet.accent)
            .disabled(savedToLog)
        }
        .petCard(accent: pet.accent)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func saveToLog(pet: Pet) {
        guard let top = results.first else { return }
        var log = store.draftLog(for: pet, on: .now)
        let line = "Behaviour check (\(mode.rawValue.lowercased())): \(top.state.displayName.lowercased()), \(Int((top.probability * 100).rounded()))%"
        log.notes = log.notes.isEmpty ? line : log.notes + "\n" + line
        store.record(log: log)
        withAnimation { savedToLog = true }
    }

    private var footnote: some View {
        Label("Prototype: the checks run on your phone with a placeholder model. In FYP2 this becomes a trained image and sound classifier. No AI account, no cost, and nothing is uploaded.",
              systemImage: "cpu")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ViewfinderCorners

struct ViewfinderCorners: Shape {
    var length: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = length
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l)); path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return path
    }
}
