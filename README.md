# 4B

Run Qwen3.5 entirely on your iPhone. No cloud. No API keys. No subscriptions.

https://github.com/user-attachments/assets/63a70984-d895-4f31-821f-1fafa32a89e7

> *iPhone 17 Pro, airplane mode, zero internet. 26 tok/s.*

## Why

Two years ago, GPT-4o cost $20/month and required a datacenter. Today, the same quality runs on your iPhone for free. Permanently.

> "According to benchmarks Qwen3.5 4B is as good as GPT 4o. GPT 4o came out ~2 years ago (May 2024). Qwen 3.5 4B runs easily on modern mobile devices. So the gap between frontier intelligence in a datacenter and running a model of equal quality on your iPhone could be 2-3 years."
>
> — [Awni Hannun](https://x.com/awnihannun/status/2030024849570288080), co-creator of MLX

## Models

| Model | Size | Speed | Notes |
|-------|------|-------|-------|
| Qwen3.5 4B | 2.9 GB | ~26 tok/s | Default. GPT-4o quality per benchmarks. |
| Qwen3.5 2B | 1.5 GB | ~55 tok/s | Fast. Good for older devices. |
| Qwen3.5 0.8B | 0.6 GB | ~80 tok/s | Fastest. Simple tasks only. |
| Qwen3.5 9B | 5.6 GB | ~20 tok/s | Best quality. Requires 8 GB RAM. |

All models are 4-bit quantized via [MLX](https://github.com/ml-explore/mlx-swift-lm) from [Hugging Face](https://huggingface.co/mlx-community).

## Features

- 100% on-device inference via Apple MLX
- Thinking mode with `enable_thinking` template variable
- Web search via Brave Search API (optional, API key stored in Keychain)
- Conversation persistence across app restarts
- Repetition detection and auto-stop
- Model switcher with download manager
- Haptic feedback on send and generation complete
- Markdown rendering, copy button, tok/s stats

## Requirements

- iPhone 15 Pro or later (8+ GB RAM) for the default 4B model
- iPhone 15 Pro or later for the 9B model (requires 8 GB RAM)
- iOS 17+
- ~3 GB free storage for default model
- WiFi for initial model download only

> Tested on iPhone 17 Pro (12 GB RAM). Older devices may work with smaller models (0.8B, 2B) but are not guaranteed. For the best experience, use an iPhone with 8+ GB RAM.

## Setup

### Prerequisites

1. Install [Xcode 15+](https://developer.apple.com/xcode/)
2. Create a free Apple Developer account at [developer.apple.com](https://developer.apple.com) (free tier works)
3. In Xcode: Settings → Accounts → add your Apple ID

### Build and run

```bash
git clone https://github.com/carolinacherry/local-ai.git
cd local-ai
open 4B.xcodeproj
```

1. Connect your iPhone via USB
2. Select your device in the Xcode toolbar
3. Set your development team: Project → Signing & Capabilities → Team
4. Press Run (Cmd+R)
5. First run: iPhone Settings → General → VPN & Device Management → trust your developer certificate
6. The app downloads the 4B model on first launch

### Web search (optional)

Settings → enter your [Brave Search API key](https://brave.com/search/api/) (free tier: 2,000 searches/month). The app auto-detects queries needing fresh data and prefetches results before generation.

## Architecture

| Component | Implementation |
|-----------|---------------|
| Inference | MLX Swift (`ml-explore/mlx-swift-lm`) |
| Thinking control | `enable_thinking` via `applyChatTemplate(additionalContext:)` |
| Model download | HuggingFace Swift Transformers |
| Web search | Brave Search API with app-driven prefetch |
| API key storage | iOS Keychain |
| Persistence | JSON in Documents directory |
| UI | SwiftUI |
| Backend | None. Zero server components. |

## Performance (iPhone 17 Pro)

| Model | TTFT | tok/s | RAM |
|-------|------|-------|-----|
| Qwen3.5 4B 4-bit | ~0.2s | ~26 | 2.9 GB |
| Qwen3.5 2B 4-bit | ~0.15s | ~55 | 1.5 GB |
| Qwen3.5 0.8B 4-bit | ~0.1s | ~80 | 0.6 GB |
| Qwen3.5 9B 4-bit | ~0.3s | ~20 | 5.6 GB |

Speeds vary by prompt length and device thermal state.

## Credits

- [MLX Swift](https://github.com/ml-explore/mlx-swift-lm) by Apple
- [Incept5/mlxchat](https://github.com/Incept5/mlxchat) by @jtdavies for the `enable_thinking` approach
- [Qwen3.5](https://huggingface.co/mlx-community) by Alibaba

## License

[MIT](LICENSE)

---

Built by [@carolinacherry](https://github.com/carolinacherry)
