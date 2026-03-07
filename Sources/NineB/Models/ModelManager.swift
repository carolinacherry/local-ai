import Foundation
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
final class ModelManager: ObservableObject {
    @Published var downloadedModels: Set<String> = []
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadingModelId: String?
    @Published var activeModelId: String?

    private static let downloadedKey = "downloadedModelIds"
    private let engine: LLMEngine

    init(engine: LLMEngine) {
        self.engine = engine
        loadPersistedState()
        checkDownloadedModels()
    }

    var hasAnyModel: Bool {
        !downloadedModels.isEmpty
    }

    private func loadPersistedState() {
        if let saved = UserDefaults.standard.stringArray(forKey: Self.downloadedKey) {
            downloadedModels = Set(saved)
        }
    }

    private func persistDownloadedModels() {
        UserDefaults.standard.set(Array(downloadedModels), forKey: Self.downloadedKey)
    }

    func checkDownloadedModels() {
        // Check filesystem as well (catches models from previous sessions)
        for model in AvailableModels.all {
            let config = ModelConfiguration(id: model.huggingFaceRepo)
            if FileManager.default.fileExists(atPath: config.modelDirectory().path) {
                downloadedModels.insert(model.id)
            }
        }
        persistDownloadedModels()
    }

    func downloadModel(_ model: ModelConfig) async throws {
        isDownloading = true
        downloadProgress = 0
        downloadingModelId = model.id

        defer {
            isDownloading = false
            downloadingModelId = nil
        }

        let config = ModelConfiguration(id: model.huggingFaceRepo)

        _ = try await LLMModelFactory.shared.loadContainer(
            configuration: config
        ) { [weak self] progress in
            Task { @MainActor in
                self?.downloadProgress = progress.fractionCompleted
            }
        }

        downloadedModels.insert(model.id)
        persistDownloadedModels()
    }

    func activateModel(_ model: ModelConfig) async throws {
        try await engine.loadModel(model)
        activeModelId = model.id
    }

    func downloadAndActivate(_ model: ModelConfig) async throws {
        try await downloadModel(model)
        try await activateModel(model)
    }

    func deleteModel(_ model: ModelConfig) {
        let config = ModelConfiguration(id: model.huggingFaceRepo)
        let dir = config.modelDirectory()
        try? FileManager.default.removeItem(at: dir)
        downloadedModels.remove(model.id)
        persistDownloadedModels()

        if activeModelId == model.id {
            activeModelId = nil
            engine.cancelGeneration()
        }
    }

    func isDownloaded(_ model: ModelConfig) -> Bool {
        downloadedModels.contains(model.id)
    }

    func isActive(_ model: ModelConfig) -> Bool {
        activeModelId == model.id
    }
}
