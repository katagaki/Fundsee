import SwiftUI

/// Developer-only harness app: renders the Fundsee widget families at real
/// sizes against the shared app-group store. Not shipped with the app.
@main
struct HarnessApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WidgetPreviewScreen()
                    .navigationTitle("Widget Harness")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
