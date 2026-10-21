// App entry point: launches the native portfolio UI with a consistent dark theme.

import SwiftUI

@main
struct LettersApp: App {
    var body: some Scene {
        WindowGroup { LettersRootView().preferredColorScheme(.dark) }
    }
}
