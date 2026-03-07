import Foundation

struct ModelConfig: Identifiable, Hashable {
    let id: String
    let displayName: String
    let huggingFaceRepo: String
    let sizeGB: Double
    let description: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ModelConfig, rhs: ModelConfig) -> Bool {
        lhs.id == rhs.id
    }
}

enum AvailableModels {
    static let all: [ModelConfig] = [
        ModelConfig(
            id: "4B",
            displayName: "Qwen3.5 4B",
            huggingFaceRepo: "mlx-community/Qwen3.5-4B-MLX-4bit",
            sizeGB: 2.9,
            description: "Default. Good balance of quality and speed."
        ),
        ModelConfig(
            id: "2B",
            displayName: "Qwen3.5 2B",
            huggingFaceRepo: "mlx-community/Qwen3.5-2B-MLX-4bit",
            sizeGB: 1.5,
            description: "Fast. Lower memory. Good for older devices."
        ),
        ModelConfig(
            id: "0.8B",
            displayName: "Qwen3.5 0.8B",
            huggingFaceRepo: "mlx-community/Qwen3.5-0.8B-MLX-4bit",
            sizeGB: 0.6,
            description: "Fastest. Simple tasks only."
        ),
        ModelConfig(
            id: "9B",
            displayName: "Qwen3.5 9B",
            huggingFaceRepo: "mlx-community/Qwen3.5-9B-MLX-4bit",
            sizeGB: 5.6,
            description: "Best quality. Requires iPhone with 8GB RAM."
        ),
    ]

    static let defaultModel = all[0]
}
