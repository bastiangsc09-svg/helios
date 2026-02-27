import SwiftUI

@main
struct HeliosApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) var appDelegate
    @State private var state = UsageState()
    @State private var engine: UsageEngine?

    var body: some Scene {
        WindowGroup("Helios") {
            ContentView(state: state, engine: engine)
                .onAppear {
                    if engine == nil {
                        let e = UsageEngine(state: state)
                        engine = e
                        appDelegate.configure(state: state, engine: e)
                    }
                }
        }
        .defaultSize(width: 700, height: 600)

        Settings {
            SettingsView(state: state, engine: engine)
        }
    }
}
