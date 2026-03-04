import SwiftUI

@main
struct HeliosApp_iOS: App {
    @State private var state = UsageState()
    @State private var engine: UsageEngine?

    var body: some Scene {
        WindowGroup {
            ContentView_iOS(state: state, engine: engine)
                .onAppear {
                    if engine == nil {
                        engine = UsageEngine(state: state)
                    }
                }
                .preferredColorScheme(.dark)
        }
    }
}
