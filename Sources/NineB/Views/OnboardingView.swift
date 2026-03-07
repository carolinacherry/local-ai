import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var modelManager: ModelManager
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("4B")
                    .font(.system(size: 64, weight: .bold, design: .rounded))

                Text("Local AI on your iPhone.")
                    .font(.title3)
                Text("Powered by Qwen3.5 via MLX.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("\(AvailableModels.defaultModel.displayName)  ·  4-bit  ·  \(String(format: "%.1f", AvailableModels.defaultModel.sizeGB)) GB")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if modelManager.isDownloading {
                DownloadProgressView(
                    progress: modelManager.downloadProgress,
                    totalGB: AvailableModels.defaultModel.sizeGB
                )
                .padding(.horizontal, 40)
            } else {
                Button {
                    Task {
                        error = nil
                        do {
                            try await modelManager.downloadAndActivate(AvailableModels.defaultModel)
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Download Model")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 40)
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 4) {
                Text("Requires WiFi. One-time download.")
                Text("Runs fully offline after.")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)

            Spacer()
        }
    }
}
