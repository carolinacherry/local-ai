import SwiftUI

struct DownloadProgressView: View {
    let progress: Double
    let totalGB: Double

    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)

            HStack {
                Text("\(String(format: "%.1f", progress * totalGB)) / \(String(format: "%.1f", totalGB)) GB")
                Spacer()
                Text("\(Int(progress * 100))%")
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }
}
