// Local invitation UI: generate/review demo codes and decode QR images on device. Live admission is a separate server boundary.

import SwiftUI
import CoreImage.CIFilterBuiltins
import Security
import Vision
import UniformTypeIdentifiers
import ImageIO
import UIKit

struct LetterboxView: View {
    @EnvironmentObject private var store: PreviewStore
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var groupID = ""
    @State private var groupName = ""
    @State private var code = ""
    @State private var name = ""
    @State private var receiverID = ""
    @State private var reviewed: LetterboxInvitation?
    @State private var shownInvitation: LetterboxInvitation?
    @State private var showScanner = false
    @State private var importQR = false
    @State private var error: String?
    @State private var notice: String?
    @State private var revokeID: UUID?
    @FocusState private var editing: Bool
    var screenshotMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label("Your people, by invitation.", systemImage: "envelope.open.fill")
                        .font(.title2.weight(.medium)).foregroundStyle(LettersTheme.accent)
                    Text("Local preview · these codes work only in this app session. No account is created online and no private messages are sent.")
                        .font(.subheadline).foregroundStyle(LettersTheme.secondary)
                    Picker("Local preview profile", selection: Binding(
                        get: { store.letterbox.activeMemberID },
                        set: { store.switchLetterboxProfile($0); groupID = ""; receiverID = ""; code = ""; notice = nil })) {
                        ForEach(store.letterbox.members) { member in Text(member.name).tag(member.id) }
                    }
                    Text("Profile switching is for this offline demonstration only. Each profile has its own contacts, invitations and sample conversations.")
                        .font(.caption).foregroundStyle(LettersTheme.secondary)
                    Picker("Letterbox action", selection: $mode) {
                        Text("Invite").tag(0)
                        Text("Accept").tag(1)
                    }.pickerStyle(.segmented)
                    if mode == 0 { issuePanel } else { acceptPanel }
                    if let notice {
                        Label(notice, systemImage: "checkmark.circle").font(.subheadline)
                            .foregroundStyle(LettersTheme.accent).accessibilityIdentifier("letterbox-result")
                    }
                    Text("A member invitation adds one contact. Groups need their own invitations. Accepting never reveals everyone’s contacts or unlocks old message history.")
                        .font(.footnote).foregroundStyle(LettersTheme.secondary)
                }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
            }.background(OrbitBackdrop()).navigationTitle("Letterbox")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $showScanner) {
                    LetterboxScanner { payload in
                        showScanner = false
                        do {
                            code = try LetterboxPreview.canonicalCode(payload)
                            notice = "QR read locally. Choose a sample member, then review."
                        } catch { self.error = error.localizedDescription }
                    }
                }
                .sheet(item: $shownInvitation) { invitation in
                    NavigationStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                Text("Invited by \(store.letterbox.members.first(where: { $0.id == invitation.issuerID })?.name ?? "Member")").font(.title2)
                                Text("One-use local preview · expires in 24 hours").foregroundStyle(LettersTheme.secondary)
                                if let image = qrImage(invitation.qrPayload) {
                                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                                        .padding(20).background(.white, in: RoundedRectangle(cornerRadius: 18))
                                        .frame(maxWidth: 260).frame(maxWidth: .infinity)
                                        .accessibilityLabel("Letterbox preview QR. Matching code follows.")
                                }
                                Text(invitation.code).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                Text("This QR and code represent the same invitation. They work only in this app session; they cannot grant online access.")
                                    .font(.subheadline).foregroundStyle(LettersTheme.secondary)
                                ShareLink(item: "Letters LOCAL PREVIEW only. \(invitation.qrPayload)") {
                                    Label("Share matching code", systemImage: "square.and.arrow.up")
                                }.frame(minHeight: 44)
                            }.padding(24)
                        }.background(OrbitBackdrop()).navigationTitle("Letterbox QR")
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { shownInvitation = nil } } }
                    }
                }
                .sheet(item: $reviewed) { invitation in
                    confirmation(invitation)
                }
                .fileImporter(isPresented: $importQR, allowedContentTypes: [.png, .jpeg]) { result in
                    if case .success(let url) = result { readQRImage(url) }
                    else if case .failure(let failure) = result, (failure as NSError).code != NSUserCancelledError {
                        error = "Choose a readable PNG or JPEG QR image."
                    }
                }
                .alert("Letterbox", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK", role: .cancel) { error = nil }
                } message: { Text(error ?? "Try again.") }
                .confirmationDialog("Revoke this preview invitation?", isPresented: Binding(
                    get: { revokeID != nil }, set: { if !$0 { revokeID = nil } }), titleVisibility: .visible) {
                    Button("Revoke invitation", role: .destructive) {
                        if let id = revokeID { store.letterbox.revoke(id) }
                        revokeID = nil
                    }
                    Button("Keep invitation", role: .cancel) { revokeID = nil }
                }
                .onAppear {
                    if screenshotMode && store.letterbox.invitations.isEmpty { generate(); shownInvitation = store.letterbox.invitations.first }
                }
        }
    }

    private var issuePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Invitation access", selection: $groupID) {
                Text("Join Letters + add you as a contact").tag("")
                ForEach(store.conversations.filter { $0.group && store.letterbox.canInvite(to: $0.id) }) { group in
                    Text("Join group: \(group.name)").tag(group.id)
                }
            }.pickerStyle(.menu)
            Text(groupID.isEmpty ? "Invite one new member. No group access is included." : "For an already approved member. This adds access to the selected group only.")
                .font(.subheadline).foregroundStyle(LettersTheme.secondary)
            Button { generate() } label: {
                Label("Create preview invitation", systemImage: "qrcode")
                    .frame(maxWidth: .infinity, minHeight: 46)
            }.buttonStyle(.borderedProminent).tint(LettersTheme.accent).foregroundStyle(LettersTheme.background)
            DisclosureGroup("Create your own sample group") {
                TextField("Group name", text: $groupName).padding(.vertical, 12)
                Button("Create group") {
                    do {
                        groupID = try store.letterbox.createGroup(name: groupName)
                        groupName = ""
                        store.refreshLetterboxConversations()
                        notice = "Group created locally. Create separate invitations for its members."
                    } catch { self.error = error.localizedDescription }
                }.frame(minHeight: 44)
            }
            ForEach(store.letterbox.invitations.filter { $0.issuerID == store.letterbox.activeMemberID }) { invitation in
                invitationCard(invitation)
            }
        }
    }

    private func invitationCard(_ invitation: LetterboxInvitation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Invited by \(store.letterbox.members.first(where: { $0.id == invitation.issuerID })?.name ?? "Member")")
                .font(.caption).foregroundStyle(LettersTheme.secondary)
            Text(invitation.groupID.flatMap { id in store.conversations.first(where: { $0.id == id })?.name } ?? "Letters membership + your contact")
                .font(.headline)
            if invitation.isAvailable(at: Date()) {
                if let image = qrImage(invitation.qrPayload) {
                    Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
                        .padding(16).background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: 220).frame(maxWidth: .infinity)
                        .accessibilityLabel("Preview invitation QR code. The matching code follows.")
                }
                Button("Open invitation QR") { shownInvitation = invitation }.frame(minHeight: 44)
                Text(invitation.code).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).accessibilityLabel("Letterbox preview code: \(invitation.code)")
                Text("One use · expires \(invitation.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(LettersTheme.secondary)
                HStack {
                    ShareLink(item: "Letters LOCAL PREVIEW only. \(invitation.qrPayload)") {
                        Label("Share code", systemImage: "square.and.arrow.up")
                    }.frame(minHeight: 44)
                    Spacer()
                    Button("Try acceptance") { code = invitation.code; mode = 1; notice = nil }
                        .frame(minHeight: 44)
                }.font(.subheadline)
                Button("Revoke invitation", role: .destructive) { revokeID = invitation.id }.frame(minHeight: 44)
            } else {
                Text(invitation.revoked ? "Revoked" : invitation.usedBy != nil ? "Accepted locally · code used" : "Expired")
                    .foregroundStyle(LettersTheme.secondary)
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private var acceptPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Try joining as a sample member").font(.headline)
            Text("Use an invitation created above. Codes from another device need the future live service.")
                .font(.subheadline).foregroundStyle(LettersTheme.secondary)
            TextField("DEMO-LBOX-…", text: $code, axis: .vertical)
                .textInputAutocapitalization(.characters).autocorrectionDisabled().lineLimit(2...4)
                .focused($editing).accessibilityLabel("Letterbox invitation code")
                .padding(14).background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            HStack {
                Button { editing = false; showScanner = true } label: { Label("Scan QR", systemImage: "qrcode.viewfinder") }
                Spacer()
                Button { editing = false; importQR = true } label: { Label("QR image", systemImage: "photo") }
            }.frame(minHeight: 44)
            Picker("Accept as", selection: $receiverID) {
                Text("New sample member").tag("")
                ForEach(store.letterbox.members) { member in
                    Text(member.name).tag(member.id)
                }
            }
            if receiverID.isEmpty {
                TextField("Sample display name", text: $name).textContentType(.nickname)
                    .focused($editing).padding(14)
                    .background(LettersTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            }
            Button { review() } label: {
                Text("Review invitation").frame(maxWidth: .infinity, minHeight: 46)
            }.buttonStyle(.borderedProminent).tint(LettersTheme.accent).foregroundStyle(LettersTheme.background)
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func confirmation(_ invitation: LetterboxInvitation) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label("Check your invitation", systemImage: "envelope.open.fill").font(.title2)
                    Text(invitation.groupID == nil ? "Adds one sample contact. No groups are included." : "Adds the selected existing member to this group only.")
                    Text("This is a local rehearsal. No online account, notifications or encrypted connection will be created.")
                        .foregroundStyle(LettersTheme.secondary)
                    Text("Accepting as: \(receiverID.isEmpty ? name : store.letterbox.members.first(where: { $0.id == receiverID })?.name ?? "Unknown")")
                    Button("Accept locally") {
                        do {
                            let member = try store.acceptLetterbox(invitation.code, name: name, existingID: receiverID.isEmpty ? nil : receiverID)
                            receiverID = member.id
                            code = ""; name = ""; reviewed = nil
                            notice = invitation.groupID == nil ? "\(member.name) is now a sample contact. Open Chats for an empty conversation." : "Sample group membership updated. Switch to that profile to see its empty group conversation."
                        } catch { reviewed = nil; self.error = error.localizedDescription }
                    }.buttonStyle(.borderedProminent).frame(minHeight: 48)
                }.padding(24)
            }.background(OrbitBackdrop()).navigationTitle("Review")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { reviewed = nil } } }
        }.presentationDetents([.medium, .large])
    }

    // Inspect first so the user sees the inviter/group before accepting a demo invitation.
    private func review() {
        editing = false
        do {
            let invitation = try store.letterbox.inspect(code)
            if receiverID.isEmpty {
                guard invitation.groupID == nil else { throw LetterboxError.memberRequired }
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed.count <= 40 else { throw LetterboxError.nameRequired }
            }
            reviewed = invitation
        } catch { self.error = error.localizedDescription }
    }

    private func generate() {
        do {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                error = "Couldn’t generate an invitation. Try again."; return
            }
            let secret = String(bytes.map { LetterboxPreview.alphabet[Int($0 & 31)] })
            try store.letterbox.issue(secret: secret, groupID: groupID.isEmpty ? nil : groupID)
            notice = nil
        } catch { self.error = error.localizedDescription }
    }

    // Encode the same invitation payload shown as text; QR is a carrier, not authorization itself.
    private func qrImage(_ payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }

    // Decode imported images locally with Vision; a scanned string still needs invitation validation.
    private func readQRImage(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size > 0, size <= 5_000_000 else { throw LetterboxError.invalidCode }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 5_000_000, let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0, width <= 4096, height <= 4096 else { throw LetterboxError.invalidCode }
            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]
            try VNImageRequestHandler(data: data, options: [:]).perform([request])
            let values = Set((request.results ?? []).compactMap(\.payloadStringValue))
            guard values.count == 1, let payload = values.first else { throw LetterboxError.invalidCode }
            code = try LetterboxPreview.canonicalCode(payload)
            notice = "QR read locally. Choose a sample member, then review."
        } catch { self.error = "Couldn’t read one valid Letterbox preview QR. Use a clear PNG/JPEG under 5 MB and 4096 × 4096 pixels, or type the code." }
    }
}
