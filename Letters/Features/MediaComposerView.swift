// Local media preparation: preview/import/recording work, but the portfolio chat has no authenticated send transport.
import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import AVKit
import ImageIO
import LettersMessaging

struct LocalMedia: Identifiable {
    let id = UUID()
    let draft: EncryptedAttachmentDraft
    var label: String {
        switch draft.kind { case .voiceNote: return "Voice note"; case .image: return "Photo"; case .gif: return "GIF"; case .video: return "Video"; case .file: return "File" }
    }
    var icon: String {
        switch draft.kind { case .voiceNote: return "waveform"; case .image: return "photo"; case .gif: return "sparkles.tv"; case .video: return "video"; case .file: return "doc" }
    }
    // Harmless fixtures are used only by explicit portfolio launch flags, not errors or live sends.
    static func fixture(_ kind: AttachmentType) -> LocalMedia {
        let type: String, name: String, bytes: Data
        switch kind {
        case .gif:
            type = "image/gif"; name = "orbit.gif"
            let output=NSMutableData()
            let destination=CGImageDestinationCreateWithData(output,UTType.gif.identifier as CFString,12,nil)!
            CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for step in 0..<12 {
                let image=UIGraphicsImageRenderer(size:CGSize(width:240,height:160)).image { context in
                    UIColor.systemIndigo.setFill(); context.fill(CGRect(x:0,y:0,width:240,height:160))
                    UIColor.cyan.setFill(); context.cgContext.fillEllipse(in:CGRect(x:90,y:50,width:60,height:60))
                    let angle=Double(step)*Double.pi/6
                    UIColor.white.setFill(); context.cgContext.fillEllipse(in:CGRect(x:112+cos(angle)*85,y:72+sin(angle)*60,width:16,height:16))
                }
                CGImageDestinationAddImage(destination,image.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
            }
            CGImageDestinationFinalize(destination); bytes=output as Data
        case .image:
            type = "image/png"; name = "earth.png"
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 260))
            bytes = renderer.pngData { context in
                UIColor(red: 0.04, green: 0.07, blue: 0.16, alpha: 1).setFill(); context.fill(CGRect(x: 0, y: 0, width: 400, height: 260))
                UIColor.cyan.setFill(); context.cgContext.fillEllipse(in: CGRect(x: 120, y: 50, width: 160, height: 160))
                UIColor.systemIndigo.setFill(); context.cgContext.fillEllipse(in: CGRect(x: 155, y: 75, width: 65, height: 100))
            }
        case .voiceNote:
            type = "audio/wav"; name = "sample-voice.wav"
            // One second of synthetic silence, not a person's recording.
            var wav = Data("RIFF".utf8)
            func append32(_ value: UInt32) { var v=value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
            func append16(_ value: UInt16) { var v=value.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
            append32(16036); wav.append(Data("WAVEfmt ".utf8)); append32(16); append16(1); append16(1); append32(8000); append32(16000); append16(2); append16(16); wav.append(Data("data".utf8)); append32(16000); wav.append(Data(count: 16000)); bytes=wav
        case .video: type="video/mp4"; name="mission-video.mp4"; bytes=Data("Portfolio video placeholder; choose a real local video to play.".utf8)
        case .file: type="text/plain"; name="mission-notes.txt"; bytes=Data("Letters portfolio sample. No personal information.".utf8)
        }
        return LocalMedia(draft: try! EncryptedAttachmentDraft(kind: kind, bytes: bytes, filename: name, mimeType: type, duration: kind == .voiceNote ? 1 : nil))
    }
}

// Generate a real, silent H.264 test clip on-device; no stock footage, people or downloaded assets.
extension LocalMedia {
    @MainActor static func syntheticVideo() async throws -> LocalMedia {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("letters-synthetic-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.protectionKey:FileProtectionType.complete,.posixPermissions:0o700])
        defer { try? FileManager.default.removeItem(at:folder) }
        let url=folder.appendingPathComponent("orbit.mp4")
        let writer=try AVAssetWriter(outputURL:url,fileType:.mp4)
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:320,AVVideoHeightKey:240])
        input.expectsMediaDataInRealTime=false
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:320,kCVPixelBufferHeightKey as String:240])
        writer.add(input); guard writer.startWriting() else { throw AttachmentError.invalidMetadata }
        writer.startSession(atSourceTime:.zero)
        for frame in 0..<12 {
            var waits=0
            while !input.isReadyForMoreMediaData, waits < 200 { try await Task.sleep(nanoseconds:10_000_000); waits += 1 }
            guard input.isReadyForMoreMediaData else { writer.cancelWriting(); throw AttachmentError.invalidMetadata }
            var buffer:CVPixelBuffer?
            guard CVPixelBufferCreate(kCFAllocatorDefault,320,240,kCVPixelFormatType_32ARGB,[kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true] as CFDictionary,&buffer) == kCVReturnSuccess, let buffer else { throw AttachmentError.invalidMetadata }
            CVPixelBufferLockBaseAddress(buffer,[])
            if let base=CVPixelBufferGetBaseAddress(buffer), let context=CGContext(data:base,width:320,height:240,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(buffer),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue) {
                context.setFillColor(UIColor.systemIndigo.cgColor); context.fill(CGRect(x:0,y:0,width:320,height:240))
                context.setFillColor(UIColor.cyan.cgColor); context.fillEllipse(in:CGRect(x:110,y:70,width:100,height:100))
                let angle=Double(frame)*Double.pi/6
                context.setFillColor(UIColor.white.cgColor); context.fillEllipse(in:CGRect(x:150+cos(angle)*120,y:110+sin(angle)*90,width:20,height:20))
            }
            CVPixelBufferUnlockBaseAddress(buffer,[])
            guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(frame),timescale:6)) else { throw AttachmentError.invalidMetadata }
        }
        input.markAsFinished(); await writer.finishWriting()
        guard writer.status == .completed else { throw AttachmentError.invalidMetadata }
        return LocalMedia(draft:try EncryptedAttachmentDraft(kind:.video,bytes:Data(contentsOf:url),filename:"synthetic-orbit.mp4",mimeType:"video/mp4",duration:2))
    }
}

@MainActor final class VoiceNoteRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var recording = false
    @Published private(set) var readyToReview = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var error: String?
    private var recorder: AVAudioRecorder?
    private var file: URL?
    private var timer: Timer?
    private var generation = UUID()

    func start() async {
        cancel()
        let attempt = generation
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard generation == attempt else { return }
        guard granted else { error="Microphone access is off. You can enable it in Settings."; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("letters-voice-" + UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete, .posixPermissions: 0o700])
            var privateFolder=folder; var values=URLResourceValues(); values.isExcludedFromBackup=true; try privateFolder.setResourceValues(values)
            let url=folder.appendingPathComponent("voice.m4a"); file=url
            let recording = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 24000, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            recording.delegate=self; recorder=recording
            guard recording.record(forDuration: 300) else { throw AttachmentError.invalidMetadata }
            self.recording=true; elapsed=0
            timer=Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.elapsed=self?.recorder?.currentTime ?? 0 }
            }
        } catch { cancel(); self.error="Unable to start recording. Please try again." }
    }
    func finish() throws -> LocalMedia {
        guard let recorder, let file, elapsed > 0.1 else { throw AttachmentError.invalidMetadata }
        let duration=max(elapsed,recorder.currentTime)
        recorder.stop(); timer?.invalidate(); timer=nil; recording=false
        defer { cancel() }
        let bytes=try Data(contentsOf: file)
        return LocalMedia(draft: try EncryptedAttachmentDraft(kind: .voiceNote, bytes: bytes, filename: "voice-note.m4a", mimeType: "audio/mp4", duration: duration))
    }
    func cancel() {
        generation=UUID(); timer?.invalidate(); timer=nil; recorder?.stop(); recorder=nil; recording=false; readyToReview=false; elapsed=0
        if let file { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }; file=nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // Keep a finished recording available for explicit review; no auto-send at the time limit.
        recording=false; readyToReview=flag; timer?.invalidate(); timer=nil
        if !flag { cancel(); error="Recording was interrupted. Please record again." }
    }
}

struct MediaComposerView: View {
    let append: (LocalMedia) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var recorder=VoiceNoteRecorder()
    @State private var importing=false
    @State private var requested=AttachmentType.image
    @State private var selected: LocalMedia?
    @State private var error: String?
    init(append: @escaping (LocalMedia) -> Void) {
        self.append=append
        if let value=ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-media=") }),
           let kind=AttachmentType(rawValue: String(value.dropFirst("--preview-media=".count))) {
            _selected=State(initialValue: LocalMedia.fixture(kind))
        }
    }
    private var allowed: [UTType] {
        switch requested { case .image: return [.png,.jpeg,.heic,.webP]; case .gif: return [.gif]; case .video: return [.mpeg4Movie,.quickTimeMovie]; case .file: return [.data]; case .voiceNote: return [.audio] }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label("LOCAL PREVIEW · NOT SENT", systemImage: "info.circle").font(.caption.bold()).foregroundStyle(LettersTheme.accent)
                    Text("More than words.").font(.largeTitle.bold())
                    Text("Prepare a voice note, GIF, photo, video or file. This portfolio chat keeps attachments only in memory; it does not send them.").foregroundStyle(LettersTheme.secondary)
                    if let selected {
                        LocalMediaPreview(media: selected)
                        Button("Add to local sample chat") { append(selected); dismiss() }.buttonStyle(.borderedProminent)
                        Button("Discard selection", role: .destructive) { self.selected=nil }
                    }
                    Divider()
                    Label("Voice note", systemImage: "waveform").font(.title2)
                    Text("Up to 5 minutes · microphone only while recording. Stop to review before adding.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                    HStack {
                        Button(recorder.recording || recorder.readyToReview ? "Stop & review" : "Record voice note") {
                            if recorder.recording || recorder.readyToReview { do { selected=try recorder.finish() } catch { self.error="Recording is too short or unavailable."; recorder.cancel() } }
                            else { Task { await recorder.start() } }
                        }.buttonStyle(.bordered).disabled(selected != nil)
                        if recorder.recording { Text(String(format: "%.0fs", recorder.elapsed)).monospacedDigit(); Button("Cancel", role: .destructive) { recorder.cancel() } }
                    }
                    ForEach([AttachmentType.image,.gif,.video,.file],id: \.self) { kind in
                        Button { requested=kind; importing=true } label: {
                            Label(kind == .image ? "Choose a photo" : kind == .gif ? "Choose a GIF" : kind == .video ? "Choose a video" : "Choose a file",
                                  systemImage: kind == .image ? "photo" : kind == .gif ? "sparkles.tv" : kind == .video ? "video" : "doc")
                                .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight:44)
                        }.disabled(recorder.recording)
                    }
                    Text("20 MB per attachment. GIFs come from files you choose; chat terms are not sent to an external GIF search service.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                    Text("The separate encrypted transport encrypts media bytes and the message containing its key. Live account/chat integration is still required.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                    if let message=error ?? recorder.error { Text(message).foregroundStyle(.orange).accessibilityAddTraits(.updatesFrequently) }
                }.padding(24)
            }.background(OrbitBackdrop()).navigationTitle("Attachments").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: allowed) { result in
            do {
                let url=try result.get(); let granted=url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
                let values=try url.resourceValues(forKeys: [.fileSizeKey,.contentTypeKey,.isRegularFileKey])
                guard values.isRegularFile == true, let size=values.fileSize, size > 0, size <= EncryptedAttachmentDraft.maximumBytes else { throw AttachmentError.tooLarge }
                let data=try Data(contentsOf: url)
                let mime=values.contentType?.preferredMIMEType ?? "application/octet-stream"
                if requested == .image || requested == .gif { try validateImage(data) }
                selected=LocalMedia(draft: try EncryptedAttachmentDraft(kind: requested, bytes: data, filename: String(url.lastPathComponent.prefix(100)), mimeType: mime))
                error=nil
            } catch { self.error="Choose a supported file up to 20 MB. Photos and GIFs must be valid images." }
        }
        .task {
            if selected?.draft.kind == .video, selected?.draft.filename == "mission-video.mp4" {
                do { selected = try await LocalMedia.syntheticVideo() } catch { self.error="Synthetic video capture unavailable." }
            }
        }
        .onChange(of: scenePhase) { phase in if phase != .active { recorder.cancel() } }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in recorder.cancel() }
        .onDisappear { recorder.cancel() }
    }
    private func validateImage(_ data: Data) throws {
        guard let source=CGImageSourceCreateWithData(data as CFData,nil), CGImageSourceGetCount(source) <= 120,
              let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
              let w=properties[kCGImagePropertyPixelWidth] as? Int, let h=properties[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0, w <= 8192, h <= 8192, w*h <= 16000000 else { throw AttachmentError.invalidMetadata }
    }
}

struct LocalMediaPreview: View {
    @Environment(\.scenePhase) private var scenePhase
    let media: LocalMedia
    @State private var audio: AVAudioPlayer?
    @State private var video: AVPlayer?
    @State private var temp: URL?
    @State private var error: String?
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Label(media.label,systemImage:media.icon).font(.title2.bold())
            if media.draft.kind == .image, let image=UIImage(data:media.draft.bytes) {
                Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:220).clipShape(RoundedRectangle(cornerRadius:18))
            } else if media.draft.kind == .gif {
                GIFPreview(bytes:media.draft.bytes).frame(height:170)
            } else if media.draft.kind == .voiceNote {
                HStack { Image(systemName:"waveform").font(.largeTitle); Text(String(format:"%.1f seconds",media.draft.duration ?? 0)); Button("Play / pause") { playAudio() } }
            } else if media.draft.kind == .video {
                if let video { VideoPlayer(player:video).frame(height:200) }
                else { Label("Video ready for local review",systemImage:"play.rectangle").frame(height:120) }
                Button("Open video preview") { playVideo() }
                if media.draft.filename == "mission-video.mp4" { Text("Portfolio placeholder. Select a real video to test playback.").font(.caption) }
            } else { Label("Document ready for local review",systemImage:"doc.text").frame(height:90) }
            Text(media.draft.filename).font(.headline)
            Text(ByteCountFormatter.string(fromByteCount:Int64(media.draft.bytes.count),countStyle:.file)).font(.caption)
            Text("Not uploaded · no delivery receipt").font(.caption).foregroundStyle(LettersTheme.secondary)
            if let error { Text(error).foregroundStyle(.orange) }
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(LettersTheme.surface,in:RoundedRectangle(cornerRadius:24))
            .task(id: media.id) { if media.draft.filename == "synthetic-orbit.mp4" { playVideo() } }
            .onChange(of: scenePhase) { phase in if phase != .active { audio?.pause(); video?.pause() } }
            .onDisappear { audio?.stop(); video?.pause(); if let temp { try? FileManager.default.removeItem(at:temp.deletingLastPathComponent()) } }
    }
    private func playAudio() {
        do {
            if let audio { if audio.isPlaying { audio.pause() } else { audio.play() }; return }
            let player=try AVAudioPlayer(data:media.draft.bytes); audio=player; player.play()
        } catch { self.error="This audio could not be played." }
    }
    private func playVideo() {
        guard temp == nil else { video?.play(); return }
        do {
            let folder=FileManager.default.temporaryDirectory.appendingPathComponent("letters-video-"+UUID().uuidString)
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.protectionKey:FileProtectionType.complete,.posixPermissions:0o700])
            let url=folder.appendingPathComponent("preview."+(media.draft.mimeType == "video/quicktime" ? "mov" : "mp4"))
            try media.draft.bytes.write(to:url,options:.completeFileProtection); temp=url
            let player=AVPlayer(url:url); video=player; player.play()
        } catch { self.error="This video could not be opened." }
    }
}

// Decode a bounded frame set locally; never load remote HTML/scripts to display a GIF.
struct GIFPreview: UIViewRepresentable {
    let bytes: Data
    func makeUIView(context:Context) -> UIImageView { let view=UIImageView(); view.contentMode = .scaleAspectFit; return view }
    func updateUIView(_ view:UIImageView,context:Context) {
        guard let source=CGImageSourceCreateWithData(bytes as CFData,nil) else { return }
        var images:[UIImage]=[]; var pixels=0; var duration=0.0
        for index in 0..<min(CGImageSourceGetCount(source),120) {
            guard let info=CGImageSourceCopyPropertiesAtIndex(source,index,nil) as? [CFString:Any],
                  let w=info[kCGImagePropertyPixelWidth] as? Int, let h=info[kCGImagePropertyPixelHeight] as? Int,
                  w > 0, h > 0, w <= 8192, h <= 8192, pixels+w*h <= 16000000,
                  let image=CGImageSourceCreateImageAtIndex(source,index,nil) else { break }
            pixels += w*h; images.append(UIImage(cgImage:image))
            let gif=info[kCGImagePropertyGIFDictionary] as? [CFString:Any]
            duration += max(0.02,gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1)
        }
        view.image=images.first
        if !UIAccessibility.isReduceMotionEnabled { view.animationImages=images; view.animationDuration=duration; view.startAnimating() }
        else { view.stopAnimating(); view.animationImages=nil }
        view.accessibilityLabel="Locally imported GIF"
    }
}
