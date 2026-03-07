import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var modelManager: ModelManager
    @Environment(\.dismiss) var dismiss
    @AppStorage("thinkingEnabled") private var thinkingEnabled = false
    @State private var braveAPIKey: String = WebSearchService.loadAPIKey() ?? ""

    var body: some View {
        NavigationStack {
            List {
                activeModelSection
                chatSection
                modelLibrarySection
                webSearchSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var activeModelSection: some View {
        Section("Active Model") {
            if let id = modelManager.activeModelId,
               let model = AvailableModels.all.first(where: { $0.id == id }) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(model.displayName)
                            .font(.headline)
                        Text(model.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Text("No model loaded")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chatSection: some View {
        Section {
            Toggle("Thinking Mode", isOn: $thinkingEnabled)
        } header: {
            Text("Chat")
        } footer: {
            Text("When on, the model reasons step-by-step before answering. Uses more tokens but improves quality on complex questions.")
        }
    }

    private var modelLibrarySection: some View {
        Section("Model Library") {
            ForEach(AvailableModels.all) { model in
                ModelRow(model: model)
            }
        }
    }

    private var webSearchSection: some View {
        Section {
            SecureField("Brave Search API Key", text: $braveAPIKey)
                .font(.system(size: 14, design: .monospaced))
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: braveAPIKey) {
                    WebSearchService.saveAPIKey(braveAPIKey)
                }
        } header: {
            Text("Web Search")
        } footer: {
            Text("Free tier: 2,000 searches/month. Get a key at brave.com/search/api. Stored in Keychain.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Built by", value: "@carolinacherry")
            Link("GitHub", destination: URL(string: "https://github.com/carolinacherry/4B")!)
        }
    }
}

struct ModelRow: View {
    let model: ModelConfig
    @EnvironmentObject var modelManager: ModelManager
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)

                        if modelManager.isActive(model) {
                            Text("Active")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text("\(String(format: "%.1f", model.sizeGB)) GB  ·  \(model.description)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if modelManager.downloadingModelId == model.id {
                    ProgressView(value: modelManager.downloadProgress)
                        .frame(width: 60)
                } else if modelManager.isDownloaded(model) {
                    if !modelManager.isActive(model) {
                        Button("Switch") {
                            Task {
                                try? await modelManager.activateModel(model)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    Button("Download") {
                        Task {
                            error = nil
                            do {
                                try await modelManager.downloadModel(model)
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .swipeActions(edge: .trailing) {
            if modelManager.isDownloaded(model) && !modelManager.isActive(model) {
                Button(role: .destructive) {
                    modelManager.deleteModel(model)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
