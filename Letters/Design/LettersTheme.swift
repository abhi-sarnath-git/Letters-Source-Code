// Shared colours and reusable artwork. The envelope is branding; a lock icon is not encryption evidence.

import SwiftUI

enum LettersTheme {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.085)
    static let surface = Color(red: 0.065, green: 0.080, blue: 0.155)
    static let accent = Color(red: 0.50, green: 0.90, blue: 1)
    static let violet = Color(red: 0.74, green: 0.67, blue: 1)
    static let secondary = Color(red: 0.69, green: 0.73, blue: 0.80)
}

struct Lettermark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15).fill(LettersTheme.surface)
            Image(systemName: "envelope.fill")
                .font(.system(size: 32)).foregroundStyle(Color(red: 0.87, green: 0.80, blue: 0.66))
            ZStack {
                Circle().fill(Color(red: 0.48, green: 0.12, blue: 0.22))
                Text("S").font(.system(size: 10, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.90, blue: 0.75))
            }.frame(width: 16, height: 16).offset(y: 1)
        }
        .frame(width: 48, height: 48).accessibilityHidden(true)
    }
}

/// Static decorative stars; no looping motion or interference with readable content.
struct OrbitBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LettersTheme.background
                RadialGradient(colors: [LettersTheme.violet.opacity(0.12), .clear],
                    center: .topTrailing, startRadius: 0, endRadius: 360)
                ForEach(0..<24, id: \.self) { index in
                    Circle().fill(LettersTheme.accent.opacity(index % 3 == 0 ? 0.25 : 0.10))
                        .frame(width: index % 3 == 0 ? 2 : 1, height: index % 3 == 0 ? 2 : 1)
                        .position(x: geometry.size.width * CGFloat((index * 37 + 11) % 100) / 100,
                                  y: geometry.size.height * CGFloat((index * 53 + 7) % 100) / 100)
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct PersonAvatar: View {
    let initials: String
    var group = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill((group ? LettersTheme.violet : LettersTheme.accent).opacity(0.13))
            if group {
                Image(systemName: "person.2.fill").foregroundStyle(LettersTheme.violet)
            } else {
                Text(initials).font(.headline).foregroundStyle(LettersTheme.accent)
            }
        }
        .frame(width: 56, height: 56).accessibilityHidden(true)
    }
}

struct PreviewNotice: View {
    var body: some View {
        Label("Portfolio preview · sample conversations", systemImage: "sparkles")
            .font(.caption).foregroundStyle(LettersTheme.secondary)
            .padding(.vertical, 10).frame(maxWidth: .infinity)
            .background(LettersTheme.surface)
    }
}
