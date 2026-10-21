// Voice-call preparation for fictional contacts. No microphone capture, ringing or media transport is started here.

import SwiftUI

enum CallKind: String, CaseIterable {
    case voice = "Voice"
    var icon: String { "phone.fill" }
}

struct CallDraft: Identifiable {
    let id = UUID()
    let contact: PreviewConversation
    let kind: CallKind
}

struct LettersCallsView: View {
    @EnvironmentObject private var store: PreviewStore
    @State private var search = ""
    @State private var callDraft: CallDraft?

    private var contacts: [PreviewConversation] {
        store.conversations.filter {
            !$0.group && !$0.archived && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        Image(systemName: "waveform.circle.fill").font(.system(size: 44))
                            .foregroundStyle(LettersTheme.accent).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Across the distance.").font(.title2.weight(.medium))
                            Text("A familiar voice, wherever you are.")
                                .font(.subheadline).foregroundStyle(LettersTheme.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Calling setup required", systemImage: "info.circle")
                            .font(.headline)
                        Text("Explore voice call screens with sample contacts. No call is placed, and your microphone stays off. Alert All replaces video calling in Letters.")
                            .font(.subheadline).foregroundStyle(LettersTheme.secondary)
                    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 22))

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(LettersTheme.secondary)
                        TextField("Find a contact", text: $search).accessibilityLabel("Search sample calling contacts")
                    }.padding(14).background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                    Text("SAMPLE CONTACTS").font(.caption.weight(.medium)).tracking(2)
                        .foregroundStyle(LettersTheme.secondary)
                    ForEach(contacts) { contact in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                PersonAvatar(initials: contact.initials)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.name).font(.headline)
                                    Text("Portfolio contact").font(.caption).foregroundStyle(LettersTheme.secondary)
                                }
                            }
                            HStack(spacing: 12) {
                                ForEach(CallKind.allCases, id: \.self) { kind in
                                    Button { callDraft = CallDraft(contact: contact, kind: kind) } label: {
                                        Label(kind.rawValue, systemImage: kind.icon)
                                            .frame(maxWidth: .infinity, minHeight: 44)
                                    }.buttonStyle(.bordered).tint(LettersTheme.accent)
                                        .accessibilityLabel("Preview \(kind.rawValue.lowercased()) call with \(contact.name)")
                                }
                            }
                        }.padding(.vertical, 6)
                    }
                    if contacts.isEmpty {
                        Text("No matching contacts.").foregroundStyle(LettersTheme.secondary)
                    }
                    Divider()
                    Label("No call history yet", systemImage: "clock")
                        .foregroundStyle(LettersTheme.secondary)
                    Text("Only real call outcomes will appear here once live calling is connected.")
                        .font(.footnote).foregroundStyle(LettersTheme.secondary)
                }.padding(24)
            }.background(OrbitBackdrop()).navigationTitle("Calls")
                .fullScreenCover(item: $callDraft) { CallPreparationView(draft: $0) }
        }
    }
}

/// An explicitly offline preparation screen. No signaling, media capture, or fake ringing.
struct CallPreparationView: View {
    let draft: CallDraft
    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind: CallKind
    @State private var showSetup = false

    init(draft: CallDraft) {
        self.draft = draft
        _selectedKind = State(initialValue: draft.kind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Label("CALL PREVIEW", systemImage: "sparkles")
                        .font(.caption.weight(.medium)).tracking(2)
                        .foregroundStyle(LettersTheme.secondary).padding(.top, 24)
                    ZStack {
                        Circle().stroke(LettersTheme.accent.opacity(0.14), lineWidth: 1)
                        Circle().stroke(LettersTheme.violet.opacity(0.22), lineWidth: 1).padding(16)
                        PersonAvatar(initials: draft.contact.initials)
                    }.frame(width: 148, height: 148).accessibilityHidden(true)
                    VStack(spacing: 10) {
                        Text(draft.contact.name).font(.largeTitle.weight(.medium))
                        Text("Not connected").foregroundStyle(LettersTheme.secondary)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Private contacts only", systemImage: "person.2.badge.key")
                        Label("End-to-end encryption required", systemImage: "lock.shield")
                        Label("Microphone is off", systemImage: "mic.slash")
                    }.font(.subheadline).foregroundStyle(LettersTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                        .background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                    Text("Live calls need signed-in private contacts and a verified encrypted calling service. This preview cannot dial anyone.")
                        .font(.subheadline).foregroundStyle(LettersTheme.secondary).multilineTextAlignment(.center)
                    Button { showSetup = true } label: {
                        Label("What is needed for live calls?", systemImage: selectedKind.icon)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(.borderedProminent).tint(LettersTheme.accent)
                        .foregroundStyle(LettersTheme.background)
                    Button("Back to Letters") { dismiss() }.frame(minHeight: 44)
                }.padding(24).frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
            }.background(OrbitBackdrop())
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
                .sheet(isPresented: $showSetup) {
                    PreviewExplanation(title: "Bring your people closer", icon: selectedKind.icon,
                        detail: "We still need private accounts, server-enforced contact access, the MatrixRTC calling engine, an authorization service and a media relay. Then we'll verify encrypted calls between two independent iPhones, including blocked contacts, reconnects and microphone permissions. A free server experiment is the next step.")
                }
        }
    }
}
