// Public-news cache, foreground refresh and orbital animation. News networking never receives chat credentials.

import SwiftUI

@MainActor final class WorldPulseStore: ObservableObject {
    struct Snapshot { let headlines: [WorldHeadline]; let fetchedAt: Date }
    @Published private(set) var cache: [WorldNewsCategory: Snapshot] = [:]
    @Published private(set) var failures: Set<WorldNewsCategory> = []
    @Published private(set) var loading = false
    private var lastAttempts: [WorldNewsCategory: Date] = [:]

    // Limit requests per topic while retaining old headlines for an honest cached/offline state.
    func refresh(_ category: WorldNewsCategory) async {
        if let last = lastAttempts[category], Date().timeIntervalSince(last) < WorldNewsFeed.refreshInterval { return }
        lastAttempts[category] = Date()
        loading = true
        defer { loading = false }
        do {
            let items = try await WorldNewsFeed.fetch(category)
            try Task.checkCancellation()
            cache[category] = Snapshot(headlines: items, fetchedAt: Date())
            failures.remove(category)
        } catch is CancellationError { lastAttempts[category] = nil }
        catch {
            if Task.isCancelled { lastAttempts[category] = nil }
            else { failures.insert(category) }
        }
    }
}

struct WorldPulseView: View {
    @StateObject private var pulse = WorldPulseStore()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Binding var category: WorldNewsCategory
    @Binding var paused: Bool
    @State private var visible = false
    @State private var index = 0
    @State private var showHeadline = false
    @State private var reading: WorldHeadline?
    @State private var readingCategory = WorldNewsCategory.world
    private var fixture: Bool { ProcessInfo.processInfo.arguments.contains("--preview-world-pulse") }
    private var items: [WorldHeadline] {
        if fixture { return [.init(title: "Sample headline — explore stories from around the world", url: WorldNewsCategory.world.sourceURL, publishedAt: nil)] }
        return pulse.cache[category]?.headlines ?? []
    }
    private var selected: WorldHeadline? { items.isEmpty ? nil : items[index % items.count] }
    private var active: Bool { visible && scenePhase == .active }
    private var taskKey: String { "\(category.rawValue)-\(active)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Live Around The World").font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text(category.rawValue).font(.subheadline.weight(.medium))
                        .foregroundStyle(LettersTheme.accent)
                    Text("Choose topics in the Home menu").font(.caption2).foregroundStyle(LettersTheme.secondary)
                }
                Spacer(minLength: 0)
                OrbitalEarth(active: active && !paused).frame(width: 66, height: 66)
            }
            HStack(alignment: .center, spacing: 10) {
                Button {
                    reading = selected
                    readingCategory = category
                    showHeadline = true
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(fixture ? LettersTheme.violet : selected == nil ? LettersTheme.secondary : LettersTheme.accent)
                            .frame(width: 5, height: 5).accessibilityHidden(true)
                        Text(selected?.title ?? (pulse.loading ? "Fetching latest headlines…" : "Headlines unavailable. Will retry while Home is open."))
                            .font(.subheadline).multilineTextAlignment(.leading).lineLimit(2)
                            .id(selected?.id ?? category.rawValue)
                            .transition(.opacity)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.foregroundStyle(.white)
                }.buttonStyle(.plain).disabled(selected == nil)
                    .accessibilityHint("Opens the complete headline and source link")
                Button { paused.toggle() } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill").font(.caption)
                        .frame(width: 44, height: 44)
                }.accessibilityLabel(paused ? "Resume headline runner and atom" : "Pause headline runner and atom")
            }
            HStack(alignment: .firstTextBaseline) {
                Link("The Guardian ↗", destination: category.sourceURL)
                Spacer()
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    Text(status(at: timeline.date)).multilineTextAlignment(.trailing)
                }
            }.font(.caption2).foregroundStyle(LettersTheme.secondary)
        }
        .animation(reduceMotion || paused ? nil : .easeInOut(duration: 0.22), value: selected?.id)
        .padding(16).background(LettersTheme.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 22))
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onChange(of: category) { _ in index = 0 }
        .task(id: taskKey) {
            guard active, !fixture else { return }
            while !Task.isCancelled {
                await pulse.refresh(category)
                do { try await Task.sleep(nanoseconds: 300_000_000_000) } catch { return }
            }
        }
        .task(id: "\(active)-\(paused)-\(reduceMotion)-\(category.rawValue)-\(showHeadline)") {
            guard active, !paused, !reduceMotion, !showHeadline else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 9_000_000_000) } catch { return }
                if items.count > 1 { index = (index + 1) % items.count }
            }
        }
        .sheet(isPresented: $showHeadline) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(readingCategory.rawValue).font(.caption).foregroundStyle(LettersTheme.accent)
                        if let selected = reading {
                            Text(selected.title).font(.title2.weight(.medium))
                            if let published = selected.publishedAt {
                                Text("Published \(published.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                            }
                            Link("Read at The Guardian", destination: selected.url).frame(minHeight: 44)
                        }
                        Text("Headlines refresh every five minutes while Home is visible. This is a news feed, not real-time market prices. Opening a story visits the publisher’s website.")
                            .font(.footnote).foregroundStyle(LettersTheme.secondary)
                        Button(paused ? "Resume automatic headlines" : "Pause automatic headlines") { paused.toggle() }
                    }.padding(24)
                }.background(OrbitBackdrop()).navigationTitle("Around the world")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showHeadline = false } } }
            }
        }
    }

    private func status(at date: Date) -> String {
        if fixture { return "Sample · portfolio capture" }
        guard let snapshot = pulse.cache[category] else { return pulse.loading ? "Connecting" : "Offline / unavailable" }
        let stale = pulse.failures.contains(category) || date.timeIntervalSince(snapshot.fetchedAt) > 600
        return "\(stale ? "Cached" : "Updated") \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)) · 5 min refresh"
    }
}

// Timeline animation belongs to the visible UI; callers disable it for pause and Reduce Motion.
struct OrbitalEarth: View {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30, paused: !active || reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { canvas, size in
                    let center = CGPoint(x: size.width/2, y: size.height/2)
                    for orbit in 0..<3 {
                        let rotation = Double(orbit) * .pi/3 - .pi/6
                        let a = size.width * 0.46, b = size.height * 0.22
                        func point(_ theta: Double) -> CGPoint {
                            let x = a * cos(theta), y = b * sin(theta)
                            return CGPoint(x: center.x + x*cos(rotation)-y*sin(rotation), y: center.y+x*sin(rotation)+y*cos(rotation))
                        }
                        var path = Path()
                        for step in 0...90 {
                            let p = point(Double(step) / 90 * 2 * .pi)
                            if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
                        }
                        canvas.stroke(path, with: .color(LettersTheme.accent.opacity(0.4)), lineWidth: 0.8)
                        let electron = point(time * (0.8 + Double(orbit)*0.15) + Double(orbit)*2)
                        canvas.fill(Path(ellipseIn: CGRect(x: electron.x-2.5, y: electron.y-2.5, width: 5, height: 5)),
                                    with: .color(orbit == 1 ? LettersTheme.violet : LettersTheme.accent))
                    }
                }
                Circle().fill(RadialGradient(colors: [LettersTheme.accent.opacity(0.3), LettersTheme.background], center: .topLeading, startRadius: 0, endRadius: 28))
                    .frame(width: 28, height: 28)
                Image(systemName: "globe.europe.africa.fill").font(.system(size: 25))
                    .foregroundStyle(LettersTheme.accent)
            }
        }.accessibilityHidden(true)
    }
}
