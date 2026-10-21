import SwiftUI

struct AlertAllView: View {
    @EnvironmentObject private var store: PreviewStore
    @State private var note = ""
    @State private var showConfirmation = false
    @State private var showEndConfirmation = false
    @State private var showFailure = false
    @FocusState private var editingNote: Bool
    private let signal = Color(red: 1, green: 0.64, blue: 0.44)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().stroke(signal.opacity(0.20), lineWidth: 1).frame(width: 76, height: 76)
                            Circle().fill(signal.opacity(0.12)).frame(width: 60, height: 60)
                            Image(systemName: "exclamationmark.triangle.fill").font(.title).foregroundStyle(signal)
                        }.accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("One signal. Your people.").font(.title2.weight(.semibold))
                            Text("For moments that matter.").foregroundStyle(LettersTheme.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Local rehearsal only", systemImage: "info.circle").font(.headline)
                        Text("This preview cannot notify anyone. In the finished app, Alert All will ask every approved Letters member to check on you.")
                            .font(.subheadline).foregroundStyle(LettersTheme.secondary)
                    }.alertCard()

                    if let rehearsal = store.alertAll.latest {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(rehearsal.endedAt == nil ? "Rehearsal active" : "Rehearsal ended",
                                  systemImage: rehearsal.endedAt == nil ? "waveform.path" : "checkmark.circle")
                                .font(.headline).foregroundStyle(signal)
                            Text(rehearsal.note)
                            Text("Created \(rehearsal.createdAt.formatted(date: .omitted, time: .shortened)) · on this device")
                                .font(.caption).foregroundStyle(LettersTheme.secondary)
                            Text("Nobody notified · no recipient acknowledgements")
                                .font(.subheadline).foregroundStyle(LettersTheme.secondary)
                            if rehearsal.endedAt == nil {
                                Button("End local rehearsal") { showEndConfirmation = true }
                                    .buttonStyle(.bordered).frame(minHeight: 44)
                            }
                        }.alertCard()
                    }

                    if !store.alertAll.hasActiveRehearsal {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("All approved Letters members", systemImage: "person.3.fill").font(.headline)
                            Text("Intended audience · family and invited friends. Membership will be checked by the service before a real alert can be sent.")
                                .font(.subheadline).foregroundStyle(LettersTheme.secondary)
                            Text("A short note (optional)").font(.subheadline.weight(.medium))
                            TextField("I need help. Please check on me.", text: $note, axis: .vertical)
                                .lineLimit(3...6).padding(14)
                                .background(LettersTheme.background, in: RoundedRectangle(cornerRadius: 14))
                                .focused($editingNote).accessibilityLabel("Optional alert note")
                            Text("\(note.trimmingCharacters(in: .whitespacesAndNewlines).count)/280 characters")
                                .font(.caption).foregroundStyle(noteIsValid ? LettersTheme.secondary : signal)
                            Button {
                                editingNote = false
                                showConfirmation = true
                            } label: {
                                Label("Review Alert All rehearsal", systemImage: "exclamationmark.triangle")
                                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                            }.buttonStyle(.borderedProminent).tint(signal)
                                .foregroundStyle(LettersTheme.background).disabled(!noteIsValid)
                            Text("You’ll confirm before creating a local rehearsal.")
                                .font(.caption).foregroundStyle(LettersTheme.secondary)
                        }.alertCard()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("For a real emergency", systemImage: "phone.arrow.up.right").font(.headline)
                        Text("Contact local emergency services directly if you need urgent help. Letters does not contact emergency services, share your location, or guarantee a response.")
                            .font(.subheadline).foregroundStyle(LettersTheme.secondary)
                    }
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.background(OrbitBackdrop()).navigationTitle("Alert All")
                .confirmationDialog("Create a local rehearsal?", isPresented: $showConfirmation, titleVisibility: .visible) {
                    Button("Create local rehearsal") {
                        if store.alertAll.createRehearsal(note: note) { note = "" } else { showFailure = true }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The finished feature will notify all approved Letters members. This rehearsal stays on this device and sends no notifications.")
                }
                .confirmationDialog("End this local rehearsal?", isPresented: $showEndConfirmation, titleVisibility: .visible) {
                    Button("End rehearsal") { store.alertAll.endRehearsal() }
                    Button("Keep rehearsal", role: .cancel) {}
                } message: { Text("Nobody will receive an all-clear notification in this preview.") }
                .alert("Rehearsal not created", isPresented: $showFailure) {
                    Button("OK", role: .cancel) {}
                } message: { Text("An active rehearsal already exists, or the note is too long. Nobody was notified.") }
        }
    }

    private var noteIsValid: Bool {
        note.trimmingCharacters(in: .whitespacesAndNewlines).count <= AlertAllPreviewState.maximumNoteLength
    }
}

private extension View {
    func alertCard() -> some View {
        padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}
