// Real local expiry for sample messages. No claim of remote deletion, unread protection or screenshot prevention.
import SwiftUI

struct MessageTimerView:View {
    @Binding var selection:MessageLifetime
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    Label("LOCAL PREVIEW TIMER",systemImage:"info.circle").font(.caption.bold()).foregroundStyle(LettersTheme.accent)
                    Image(systemName:"timer").font(.system(size:44)).foregroundStyle(LettersTheme.accent)
                    Text("Let the moment pass.").font(.largeTitle.bold())
                    Text("Self-destruct timer").font(.title2)
                    Text("New sample messages and attachments disappear locally after the selected time, measured from when you add them. Earlier messages keep their existing timer.").foregroundStyle(LettersTheme.secondary)
                    ForEach(MessageLifetime.allCases) { lifetime in
                        Button { selection=lifetime } label: {
                            HStack { Text(lifetime.rawValue); Spacer(); Image(systemName:selection == lifetime ? "checkmark.circle.fill" : "circle") }
                                .padding(13).background(LettersTheme.surface,in:RoundedRectangle(cornerRadius:14))
                        }.accessibilityLabel(lifetime.rawValue).accessibilityAddTraits(selection == lifetime ? [.isSelected] : [])
                    }
                    Text("Months and years use calendar dates in UTC. ‘never’ keeps future messages until you remove them.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                    Text("This preview does not delete messages on another device or a server. Remote expiry, encrypted attachment cleanup and offline-device enforcement remain release requirements. Recipients can retain copies.").font(.footnote).foregroundStyle(LettersTheme.secondary)
                }.padding(24)
            }.background(OrbitBackdrop()).navigationTitle("Message timer").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
