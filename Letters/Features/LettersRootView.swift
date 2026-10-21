// Main navigation and sample conversations. This composer changes PreviewStore only; it does not send messages.

import SwiftUI

struct LettersRootView: View {
    @StateObject private var store = PreviewStore()
    @State private var selectedTab = ProcessInfo.processInfo.arguments.contains("--preview-alert-all") ? 3 : 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationListView(selectedTab: $selectedTab).tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }.tag(0)
            FeaturePreviewView(title: "Updates", icon: "circle.dashed", subtitle: "Life, in little moments.",
                features: ["Status updates and audience controls", "Private channels and broadcasts", "Communities and announcements"])
                .tabItem { Label("Updates", systemImage: "circle.dashed") }.tag(1)
            LettersCallsView().tabItem { Label("Calls", systemImage: "phone") }.tag(2)
            AlertAllView().tabItem { Label("Alert All", systemImage: "exclamationmark.triangle") }.tag(3)
            LettersSettingsView().tabItem { Label("You", systemImage: "person.crop.circle") }.tag(4)
        }
        .tint(LettersTheme.accent)
        .environmentObject(store)
    }
}

struct ConversationListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedTab: Int
    @State private var newsCategory = WorldNewsCategory.world
    @State private var runnerPaused = false
    @EnvironmentObject private var store: PreviewStore
    @State private var search = ""
    @State private var filter = "All"
    @State private var showInviteInfo = ProcessInfo.processInfo.arguments.contains("--preview-letterbox")
    @State private var showMarkets = ProcessInfo.processInfo.arguments.contains("--preview-markets") || ProcessInfo.processInfo.arguments.contains("--check-market-quotes")
    private let filters = ["All", "Unread", "Favorites", "Groups"]

    private var visibleConversations: [PreviewConversation] {
        store.conversations.filter {
            !$0.archived && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                || $0.lastMessage.localizedCaseInsensitiveContains(search))
            && (filter != "Unread" || $0.unread > 0)
            && (filter != "Favorites" || $0.favorite)
            && (filter != "Groups" || $0.group)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    WorldPulseView(category: $newsCategory, paused: $runnerPaused)
                    Spacer()
                    Menu {
                        Section("Chats & People") {
                            Menu {
                                Picker("Conversation filter", selection: $filter) {
                                    ForEach(filters, id: \.self) { item in Text(item).tag(item) }
                                }
                            } label: { Label("Filter chats", systemImage: "line.3.horizontal.decrease.circle") }
                            Button { openInvitations() } label: { Label("Letterbox invitations & groups", systemImage: "envelope.open") }
                        }
                        Section("Around the World") {
                            Menu {
                                Picker("News category", selection: $newsCategory) {
                                    ForEach(WorldNewsCategory.allCases) { category in Text(category.rawValue).tag(category) }
                                }
                            } label: { Label("News topics", systemImage: "globe") }
                            Button { runnerPaused.toggle() } label: {
                                Label(runnerPaused ? "Resume news and atom" : "Pause news and atom", systemImage: runnerPaused ? "play.fill" : "pause.fill")
                            }
                        }
                        Section("Explore") {
                            Button { DispatchQueue.main.async { showMarkets = true } } label: {
                                Label("Markets", systemImage: "chart.line.uptrend.xyaxis")
                            }
                        }
                        Section("Connect") {
                            Button { navigate(to: 2) } label: { Label("Voice calls", systemImage: "phone") }
                            Button { navigate(to: 1) } label: { Label("Updates", systemImage: "circle.dashed") }
                        }
                        Section("Safety") {
                            Button { navigate(to: 3) } label: { Label("Alert All", systemImage: "exclamationmark.triangle") }
                        }
                        Section("You") {
                            Button { navigate(to: 4) } label: { Label("Profile & settings", systemImage: "person.crop.circle") }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.circle").font(.title2).frame(width: 44, height: 44)
                    }.accessibilityLabel("Home menu: chats, news, markets, connect, safety and you")

                }.padding(.horizontal, 20).padding(.vertical, 14)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(LettersTheme.secondary)
                    TextField("Find a person or conversation", text: $search)
                        .accessibilityLabel("Search conversations")
                }.padding(14).background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { item in
                            Button { filter = item } label: {
                                Text(item).font(.subheadline.weight(.medium)).padding(.horizontal, 16).padding(.vertical, 11)
                                    .foregroundStyle(filter == item ? LettersTheme.background : LettersTheme.secondary)
                                    .background(filter == item ? LettersTheme.accent : LettersTheme.surface, in: Capsule())
                            }.accessibilityAddTraits(filter == item ? .isSelected : [])
                        }
                    }.padding(.horizontal, 20).padding(.vertical, 18)
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        HStack {
                            Text("YOUR INNER CIRCLE").font(.caption.weight(.medium)).tracking(2)
                            Spacer()
                            Image(systemName: "person.2.badge.key.fill")
                        }.foregroundStyle(LettersTheme.secondary).padding(.vertical, 8)
                        ForEach(visibleConversations) { chat in
                            NavigationLink(value: chat.id) {
                                HStack(spacing: 14) {
                                    PersonAvatar(initials: chat.initials, group: chat.group)
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(chat.name).font(.headline).foregroundStyle(.white)
                                            Spacer()
                                            Text(chat.time).font(.caption).foregroundStyle(LettersTheme.secondary)
                                        }
                                        HStack {
                                            Text(chat.lastMessage).font(.subheadline).foregroundStyle(LettersTheme.secondary).lineLimit(2)
                                            Spacer(minLength: 8)
                                            if chat.unread > 0 {
                                                Text("\(chat.unread)").font(.caption.weight(.semibold))
                                                    .foregroundStyle(LettersTheme.background).padding(7)
                                                    .background(LettersTheme.accent, in: Circle())
                                            }
                                        }
                                    }
                                }.padding(.vertical, 14).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                        if visibleConversations.isEmpty {
                            Text("No conversations here yet.").foregroundStyle(LettersTheme.secondary).padding(30)
                        }
                    }.padding(.horizontal, 20)
                }
                PreviewNotice()
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: filter)
            .background(OrbitBackdrop()).toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { ChatPreviewView(conversationID: $0) }
            // Markets is reached from the Home menu only; the bottom tabs stay unchanged.
            .navigationDestination(isPresented: $showMarkets) { MarketsView() }
            .sheet(isPresented: $showInviteInfo) {
                LetterboxView(screenshotMode: ProcessInfo.processInfo.arguments.contains("--preview-letterbox"))
            }
        }
    }
    // Let the native menu dismiss before changing tabs to avoid competing transitions.
    private func navigate(to tab: Int) {
        // Allow the system menu to begin dismissing before changing destinations.
        DispatchQueue.main.async { selectedTab = tab }
    }
    private func openInvitations() {
        DispatchQueue.main.async { showInviteInfo = true }
    }

}

// Sample chat interaction only; do not route real credentials or messages through this view yet.
struct ChatPreviewView: View {
    let conversationID: String
    @EnvironmentObject private var store: PreviewStore
    @State private var draft = ""
    @State private var showFeatureInfo = false
    @State private var showStickers = false
    @State private var callDraft: CallDraft?
    private var chat: PreviewConversation? { store.conversations.first { $0.id == conversationID } }

    var body: some View {
        VStack(spacing: 0) {
            PreviewNotice()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        Text("TODAY").font(.caption).tracking(2).foregroundStyle(LettersTheme.secondary).padding(.top, 20)
                        Label("Sample messages · no network connection", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(LettersTheme.secondary).multilineTextAlignment(.center)
                        ForEach(chat?.messages ?? []) { message in
                            HStack {
                                if message.outgoing { Spacer(minLength: 40) }
                                VStack(alignment: .trailing, spacing: 7) {
                                    if let sticker = message.sticker {
                                        StickerArtwork(sticker: sticker).frame(width: 112, height: 112)
                                    } else {
                                        Text(message.text).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    if message.outgoing { Text("Local preview").font(.caption2).opacity(0.75) }
                                }
                                .padding(16)
                                .foregroundStyle(message.outgoing ? LettersTheme.background : .white)
                                .background(message.outgoing ? LettersTheme.accent : LettersTheme.surface,
                                            in: RoundedRectangle(cornerRadius: 22))
                                if !message.outgoing { Spacer(minLength: 40) }
                            }.id(message.id)
                        }
                    }.padding(.horizontal, 20).padding(.bottom, 20)
                }
                .onChange(of: chat?.messages.count) { _ in
                    if let last = chat?.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button { showFeatureInfo = true } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .accessibilityLabel("Attachment preview information")
                TextField("Try a sample message", text: $draft, axis: .vertical)
                    .lineLimit(1...5).padding(13).background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityLabel("Sample message")
                Button { showStickers = true } label: {
                    Image(systemName: "face.smiling").frame(width: 44, height: 44)
                }.accessibilityLabel("Choose or add stickers")
                Button {
                    store.appendPreview(draft, to: conversationID)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up").font(.headline).frame(width: 44, height: 44)
                        .foregroundStyle(LettersTheme.background).background(LettersTheme.accent, in: Circle())
                }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add sample message locally")
            }.padding(12)
        }
        .background(OrbitBackdrop())
        .navigationTitle(chat?.name ?? "Conversation").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let contact = chat, !contact.group {
                    Button { callDraft = CallDraft(contact: contact, kind: .voice) } label: {
                        Image(systemName: "phone")
                    }.accessibilityLabel("Preview voice call with \(contact.name)")
                }
            }
        }
        .onAppear { store.markRead(conversationID) }
        .fullScreenCover(item: $callDraft) { CallPreparationView(draft: $0) }
        .sheet(isPresented: $showStickers) {
            StickerPickerView { sticker in
                store.appendSticker(sticker, to: conversationID)
                showStickers = false
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showFeatureInfo) {
            PreviewExplanation(title: "Part of the Letters roadmap", icon: "sparkles",
                detail: "Encrypted voice calls and attachments are required for Letters. These controls show the intended experience; they do not place calls, capture media, or send files yet.")
        }
    }
}

struct FeaturePreviewView: View {
    let title: String
    let icon: String
    let subtitle: String
    let features: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: icon).font(.system(size: 44)).foregroundStyle(LettersTheme.accent).padding(.top, 30)
                    Text(subtitle).font(.largeTitle.weight(.medium))
                    ForEach(features, id: \.self) { feature in
                        Label(feature, systemImage: "circle").foregroundStyle(LettersTheme.secondary)
                    }
                    Text("Planned · not connected in this portfolio preview").font(.footnote).foregroundStyle(LettersTheme.secondary)
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }.background(LettersTheme.background).navigationTitle(title)
        }
    }
}

struct LettersSettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Lettermark()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your space in Letters").font(.headline)
                            Text("Portfolio profile").foregroundStyle(LettersTheme.secondary)
                        }
                    }.padding(.vertical, 10)
                }
                Section("The Letters promise") {
                    Label("Membership by invitation", systemImage: "person.badge.key")
                    Label("End-to-end encryption required", systemImage: "lock.shield")
                    Label("Device verification and recovery", systemImage: "key")
                }
                Section("Messaging development") {
                    NavigationLink { MessagingFoundationView() } label: {
                        Label("Encrypted messaging progress", systemImage: "lock.shield")
                    }
                }
                Section("Current build") {
                    Text("Design preview only. Live accounts, private chats, notifications, calls and alerts are not connected to the preview. The Matrix encryption SDK is linked for separate development tests. Letterbox invitations are local previews.")
                    Text("Use sample content only. This build cannot send private messages.")
                }
                Section("Accessibility") {
                    Text("Native Dynamic Type, VoiceOver labels, standard navigation, and Reduce Motion support for the orbital Home animation.")
                }
            }.scrollContentBackground(.hidden).background(LettersTheme.background).navigationTitle("You")
        }
    }
}

struct PreviewExplanation: View {
    let title: String
    let icon: String
    let detail: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: icon).font(.largeTitle).foregroundStyle(LettersTheme.accent)
                Text(title).font(.largeTitle.weight(.medium))
                Text(detail).foregroundStyle(LettersTheme.secondary)
                Spacer()
            }.padding(28).background(LettersTheme.background)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}
