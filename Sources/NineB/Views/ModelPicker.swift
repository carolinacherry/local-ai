import SwiftUI

struct ModelPicker: View {
    @EnvironmentObject var modelManager: ModelManager
    @Binding var showPicker: Bool

    var body: some View {
        Menu {
            let downloaded = AvailableModels.all.filter { modelManager.isDownloaded($0) }

            ForEach(downloaded) { model in
                Button {
                    Task {
                        try? await modelManager.activateModel(model)
                    }
                } label: {
                    HStack {
                        Text(model.displayName)
                        if modelManager.isActive(model) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if downloaded.count < AvailableModels.all.count {
                Divider()
                Label("More models in Settings", systemImage: "lock")
                    .foregroundStyle(.secondary)
            }
        } label: {
            HStack(spacing: 4) {
                Text(activeModelName)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.primary)
        }
    }

    private var activeModelName: String {
        if let id = modelManager.activeModelId,
           let model = AvailableModels.all.first(where: { $0.id == id }) {
            return model.displayName
        }
        return "No Model"
    }
}
