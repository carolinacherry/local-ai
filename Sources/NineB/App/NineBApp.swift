import SwiftUI

@main
struct NineBApp: App {
    @StateObject private var engine: LLMEngine
    @StateObject private var modelManager: ModelManager
    @StateObject private var conversationStore = ConversationStore()

    init() {
        let eng = LLMEngine()
        _engine = StateObject(wrappedValue: eng)
        _modelManager = StateObject(wrappedValue: ModelManager(engine: eng))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .environmentObject(modelManager)
                .environmentObject(conversationStore)
        }
    }
}
