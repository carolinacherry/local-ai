import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: LLMEngine
    @EnvironmentObject var modelManager: ModelManager

    @State private var activeConversationId: UUID?

    var body: some View {
        Group {
            if !modelManager.hasAnyModel {
                OnboardingView()
            } else {
                ChatView(activeConversationId: $activeConversationId)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .preferredColorScheme(.light)
    }
}
