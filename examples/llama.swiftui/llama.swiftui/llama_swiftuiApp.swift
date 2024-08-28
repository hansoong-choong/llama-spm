import SwiftUI

@main
struct llama_swiftuiApp: App {
    @StateObject var llamaState = LlamaState()
    var body: some Scene {
        WindowGroup {
            MobileContentView()
                .environmentObject(llamaState)
        }
    }
}
