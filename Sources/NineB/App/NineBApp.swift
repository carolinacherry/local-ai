import SwiftUI

@main
struct NineBApp: App {
    @StateObject private var engine: LLMEngine
    @StateObject private var modelManager: ModelManager
    @StateObject private var conversationStore = ConversationStore()
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0

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
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}
