import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject var store: ConversationStore
    @Binding var activeConversationId: UUID?
    @Binding var showList: Bool

    var body: some View {
        NavigationStack {
            Group {
                if store.conversations.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Text("No conversations yet")
                            .font(.system(size: 15))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(store.conversations) { conversation in
                            Button {
                                activeConversationId = conversation.id
                                showList = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)

                                    HStack(spacing: 6) {
                                        Text("\(conversation.messages.count) messages")
                                        Text("·")
                                        Text(conversation.updatedAt, style: .relative)
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.delete(store.conversations[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { showList = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        activeConversationId = nil
                        showList = false
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15))
                    }
                }
            }
        }
    }
}
