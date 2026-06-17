<h1 align="center">VoiceNote</h1>

<p align="center">
  A native iOS voice recording app with real-time transcription — built as the TwinMind iOS take-home assignment.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-black?style=flat-square" />
  &nbsp;
  <img src="https://img.shields.io/badge/language-Swift%206-orange?style=flat-square" />
  &nbsp;
  <img src="https://img.shields.io/badge/concurrency-Actor%20based-blue?style=flat-square" />
  &nbsp;
  <img src="https://img.shields.io/badge/transcription-Gemini%20API-darkgreen?style=flat-square" />
  &nbsp;
  <img src="https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square" />
</p>

---

## The Assignment

VoiceNote is my submission for the TwinMind iOS take-home assignment. The prompt was to build a production-grade voice recording app with real-time transcription on iOS — complete with background audio, offline support, encryption, system integrations, and a comprehensive test suite. The constraint was strict: Swift 6 strict concurrency, no third-party dependencies, and a layered actor-based architecture that could scale to thousands of sessions and tens of thousands of segments.

The challenge was not the feature list itself but building each piece to a standard where every layer is genuinely testable, every failure mode is handled, and nothing cuts corners on the things that matter at scale — concurrency, security, and persistence.

---

## What It Does

VoiceNote records audio continuously in the background, slices it into 30-second segments, encrypts each segment to disk, and sends them to Google Gemini for transcription — all in parallel, all while you are doing something else. When connectivity is unavailable, segments queue locally and drain automatically when the network returns. When the API fails repeatedly, the app switches transparently to Apple Speech Recognition as a fallback. Every session, segment, and transcription is persisted in SwiftData and browseable at any time.

The experience on the surface is simple: tap to record, come back to your transcript. The engineering underneath is the point.

---

## Screenshots

### Session List

<table align="center"><tr>
  <td align="center"><img src="Screenshots/Simulator Screenshot - iPhone 17 Pro - 2026-03-05 at 18.17.09.png" width="220" alt="Session list empty state" /><br/><sub>Empty state — no sessions yet</sub></td>
  <td align="center"><img src="Screenshots/Simulator Screenshot - iPhone 17 Pro - 2026-03-05 at 18.17.17.png" width="220" alt="Sort options menu" /><br/><sub>Sort — Newest, Oldest, Name, Duration</sub></td>
</tr></table>

---

## Features

### Recording

- Continuous audio recording via `AVAudioEngine` with a single input node tap — no `AVAudioRecorder`, no restarts between segments
- Background recording: `UIBackgroundModes: audio` keeps the tap alive when the app is not in the foreground
- Three quality presets — High (48 kHz / 32-bit), Medium (22 kHz / 16-bit), Low (16 kHz / 16-bit) — selectable before each session
- Live audio level metering at up to 10 Hz, computed from `floatChannelData` in the tap buffer and normalized to 0.0–1.0
- Interruption handling: phone calls, Siri, and alarms correctly pause the engine; sessions resume automatically when `shouldResume` is true
- Route change handling: pulling out headphones reconfigures the session and rebuilds the engine graph without dropping the current segment file

### Segmentation and Encryption

- Every 30 seconds, the current `AVAudioFile` is closed, encrypted, and a new one is opened — seamlessly, with no gap in the recording
- Encryption uses AES-256-GCM via CryptoKit's `AES.GCM` API; the plaintext file is deleted immediately after successful encryption
- The encryption key lives in Keychain under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — survives device restarts, never touches disk unprotected

### Transcription

- Up to 3 segments are transcribed concurrently using `withThrowingTaskGroup`
- Exponential backoff on failure: delays of 2, 4, 8, and 16 seconds across up to 5 attempts per segment
- After 5 consecutive global failures across any segments, `TranscriptionPipelineActor` switches from Google Gemini to Apple Speech Recognition automatically; the counter resets on any success
- Offline queue: when `NWPathMonitor` reports the path as unsatisfied, new jobs are persisted as `.pending` in SwiftData; `drainOfflineQueue()` runs on path restoration

### Session Management

- Sessions grouped by date — Today, Yesterday, and calendar dates for older entries
- Search across session names; sort by newest, oldest, name, or duration
- Per-session detail view with segment-by-segment transcription progress and timestamps
- Swipe to delete — cascade delete removes all segments and transcriptions

### System Integrations

- **Live Activity and Dynamic Island**: real-time recording state, elapsed timer, input device name, transcription progress (`x/y segments`), and audio level bars — updated at most once per second
- **App Intents**: `StartRecordingIntent` and `StopRecordingIntent` for Siri and Shortcuts; both handle edge cases gracefully (already recording, no active session)
- **WidgetKit**: home screen widget showing the most recent session state and a quick-start control

---

## Architecture

The app uses a strict five-layer architecture enforced at the type level by Swift 6's concurrency model. No layer may import or call into a layer above it. Cross-layer communication happens through `async` method calls and `AsyncStream` — never `NotificationCenter` or shared mutable state.

```
SwiftUI Views
    │  (read @Observable ViewModels only)
    ▼
@Observable ViewModels          ← @MainActor, owns all UI state
    │  (call actor methods via await)
    ▼
Domain Actors                   ← AudioEngineActor · TranscriptionPipelineActor · DataManagerActor
    │  (use infrastructure services)
    ▼
Infrastructure Services         ← KeychainService · EncryptionService · NetworkService · AudioFileManager
    │  (wrap system frameworks)
    ▼
System Frameworks               ← AVFoundation · SwiftData · CryptoKit · NWPathMonitor · ActivityKit
```

### The event bus

`AudioEngineActor` emits an `AsyncStream<AudioEngineEvent>`. `TranscriptionPipelineActor` consumes that stream and dispatches `SegmentJob` values into its own processing queue. `DataManagerActor` receives completed transcriptions and persists them. ViewModels observe state changes by awaiting actor methods — they never hold domain state themselves.

```swift
enum AudioEngineEvent: Sendable {
    case stateChanged(RecordingState)
    case segmentReady(SegmentJob)
    case levelUpdate(Float)
    case routeChanged(AudioRouteInfo)
    case error(AppError)
}
```

### Protocol-driven dependency injection

Every actor and service conforms to a protocol. Dependencies are injected through initializers — no singletons, no `@EnvironmentObject`. `AppDependencies` is instantiated exactly once at app launch and passed via `@Environment` with a custom key.

```
AudioEngineProtocol        ← AudioEngineActor / MockAudioEngine
TranscriptionProtocol      ← WhisperAPIService / AppleSpeechService / LocalWhisperService (stub)
DataManagerProtocol        ← DataManagerActor / MockDataManager
NetworkServiceProtocol     ← NetworkService / MockNetworkService
KeychainServiceProtocol    ← KeychainService / MockKeychainService
EncryptionServiceProtocol  ← EncryptionService / MockEncryptionService
```

### Swift 6 concurrency rules

All actors use the `actor` keyword — not classes with serial queues. All `@Observable` ViewModels are `@MainActor` — explicitly annotated, never inferred. `@Sendable` is required on every closure passed to a `Task` or `TaskGroup`. `DispatchQueue` does not appear anywhere in the codebase.

---

## Security

Every sensitive piece of data in VoiceNote is handled with a specific, deliberate mechanism. None of these are defaults — they were each chosen and enforced explicitly.

| Component | Mechanism |
|---|---|
| **Audio files at rest** | AES-256-GCM via CryptoKit `AES.GCM` — applied at the segment boundary, before the file path is emitted on the event stream |
| **Plaintext cleanup** | The unencrypted segment file is deleted immediately after successful encryption; it never lingers |
| **Encryption key** | Generated on first launch, stored in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — accessible in background, never written to disk |
| **API key** | Read from `Info.plist` on first launch, moved to Keychain immediately, never stored anywhere else; re-read from Keychain on each use |
| **Transport** | `NSAppTransportSecurity` in `Info.plist` has `NSAllowsArbitraryLoads: false` — HTTPS enforced at the configuration layer, not just in code |
| **Memory** | Audio tap buffers are zeroed via `memset` on the `UnsafeMutablePointer` from `floatChannelData` after each segment write |
| **Logging** | No API keys, encryption keys, or file paths appear in any log statement in production builds — sensitive paths are guarded by `#if DEBUG` |

---

## Tech Stack

| | |
|---|---|
| **Language** | Swift 6 — strict concurrency enabled, `@Sendable` enforced throughout |
| **UI framework** | SwiftUI — `@Observable` ViewModels, no `ObservableObject` |
| **Persistence** | SwiftData — `RecordingSession`, `AudioSegment`, `TranscriptionResult` |
| **Audio** | AVFoundation — `AVAudioEngine` input node tap, `AVAudioSession` lifecycle management |
| **Encryption** | CryptoKit — `AES.GCM` for segment files, `SymmetricKey` stored in Keychain |
| **Keychain** | Security framework — direct `SecItem` API wrapped in `KeychainService` |
| **Networking** | URLSession — multipart `form-data` for Gemini and Whisper-compatible endpoints |
| **Connectivity** | Network framework — `NWPathMonitor` for offline detection and queue drain |
| **Transcription (primary)** | Google Gemini API — `gemini-2.0-flash` via `generateContent` |
| **Transcription (fallback)** | Apple Speech framework — `SFSpeechRecognizer` used after 5 consecutive API failures |
| **System integrations** | ActivityKit, AppIntents, WidgetKit |
| **Logging** | `os.Logger` — per-subsystem and per-category, subsystem `com.voicenote.app` |
| **Deployment target** | iOS 17.0+ |
| **Third-party dependencies** | None |

---

## Project Structure

```
TwinMind/
├── App/
│   ├── VoiceNoteApp.swift              # @main, environment injection, dependency wiring
│   ├── AppDependencies.swift           # Single dependency container — not a singleton
│   └── Configuration/
│       └── ConfigurationManager.swift  # API key bootstrap from Info.plist → Keychain
│
├── Domain/
│   ├── Models/                         # Pure Swift value types and enums — no imports
│   │   ├── RecordingState.swift
│   │   ├── TranscriptionState.swift
│   │   ├── SessionState.swift
│   │   ├── RecordingQuality.swift      # High / Medium / Low presets with segment duration
│   │   ├── SegmentJob.swift
│   │   └── AppError.swift              # Typed error enum across all domains
│   │
│   ├── Audio/
│   │   ├── AudioEngineProtocol.swift
│   │   ├── AudioEngineActor.swift      # AVAudioEngine lifecycle, tap, segmentation
│   │   ├── AudioSessionConfigurator.swift
│   │   ├── AudioSegmentWriter.swift    # Rolling 30s file writer with encryption handoff
│   │   └── AudioLevelMeter.swift
│   │
│   ├── Transcription/
│   │   ├── TranscriptionServiceProtocol.swift
│   │   ├── TranscriptionPipelineActor.swift  # Queue, retry, fallback, offline drain
│   │   ├── GeminiTranscriptionService.swift  # Multipart form-data to Gemini
│   │   ├── AppleSpeechService.swift          # SFSpeechRecognizer fallback
│   │   └── LocalWhisperService.swift         # Protocol stub — not bundled in MVP
│   │
│   └── Data/
│       ├── DataManagerProtocol.swift
│       ├── DataManagerActor.swift      # All SwiftData operations, pagination, batch insert
│       ├── Models/
│       │   ├── RecordingSession.swift
│       │   ├── AudioSegment.swift
│       │   └── TranscriptionResult.swift
│       └── Queries/
│           └── SessionQueries.swift    # Reusable #Predicate and SortDescriptor definitions
│
├── Infrastructure/
│   ├── Keychain/
│   │   ├── KeychainServiceProtocol.swift
│   │   └── KeychainService.swift
│   ├── Encryption/
│   │   ├── EncryptionServiceProtocol.swift
│   │   └── EncryptionService.swift     # AES-256-GCM encrypt / decrypt with buffer zeroing
│   ├── Network/
│   │   ├── NetworkServiceProtocol.swift
│   │   └── NetworkService.swift        # URLSession wrapper with typed errors
│   └── Storage/
│       └── AudioFileManager.swift
│
├── Features/
│   ├── Recording/
│   │   ├── RecordingViewModel.swift
│   │   ├── RecordingView.swift
│   │   ├── RecordingControlsView.swift
│   │   └── AudioLevelMeterView.swift   # 13-bar animated waveform
│   ├── SessionList/
│   │   ├── SessionListViewModel.swift
│   │   ├── SessionListView.swift
│   │   └── SessionRowView.swift
│   ├── SessionDetail/
│   │   ├── SessionDetailViewModel.swift
│   │   ├── SessionDetailView.swift
│   │   └── TranscriptionSegmentRowView.swift
│   └── Permissions/
│       ├── PermissionViewModel.swift
│       └── PermissionView.swift
│
├── SystemIntegrations/
│   ├── LiveActivity/
│   │   ├── RecordingActivityAttributes.swift  # Shared via App Group
│   │   └── LiveActivityManager.swift          # Rate-limited to 1 update/second
│   ├── AppIntents/
│   │   ├── StartRecordingIntent.swift
│   │   ├── StopRecordingIntent.swift
│   │   └── VoiceNoteShortcuts.swift           # AppShortcutsProvider, 2+ phrases per intent
│   └── Widget/
│       └── (VoiceNoteWidget target)
│
├── Shared/
│   ├── UI/
│   │   ├── ErrorBannerView.swift
│   │   ├── OfflineStatusBannerView.swift
│   │   └── EmptyStateView.swift
│   ├── Extensions/
│   │   ├── Date+Formatting.swift
│   │   └── Double+Duration.swift
│   └── Logging/
│       └── AppLogger.swift             # os.Logger wrappers — one per subsystem category
│
└── Resources/
    ├── Assets.xcassets
    ├── Info.plist
    └── VoiceNote.entitlements

RecordingActivityExtension/             # Live Activity widget extension target
VoiceNoteWidget/                        # WidgetKit extension target
VoiceNoteTests/                         # XCTest unit, integration, and performance tests
VoiceNoteUITests/                       # XCTest UI tests for critical recording flows
```

---

## Getting Started

**Requirements:** Xcode 16 and an iOS 17 simulator or device. One API key required.

```bash
git clone https://github.com/keyursavalia/TwinMind.git
cd TwinMind
open TwinMind.xcodeproj
```

In `TwinMind/Info.plist`, add your Google AI API key:

```xml
<key>GEMINI_API_KEY</key>
<string>YOUR_KEY_HERE</string>
```

On first launch the app reads the key from `Info.plist`, stores it in Keychain, and removes it from the plist entry. All subsequent reads come from Keychain only.

Press `Cmd R`. The app initializes SwiftData, generates an encryption key, and shows the session list in its empty state.

For full functionality — background audio, Live Activities, Dynamic Island, and route change handling — a physical device is recommended. The simulator supports the core recording and transcription flow but has known limitations with `AVAudioSession` route changes and `ActivityKit`.

### Running the tests

```bash
xcodebuild test \
  -scheme TwinMind \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Or press `Cmd U` in Xcode. Tests use `MockURLProtocol` for all network calls — no real API is contacted during the test suite.

---

## What's Next

- **Audio playback** — scrubbing and playback of recorded sessions directly in the app, with per-segment seeking
- **Export** — share a full session as `.txt`, `.srt` (timestamped subtitle format), or a zipped `.m4a` + transcript bundle
- **Full-text search** — search across transcription content, not just session names
- **Encryption key rotation** — per-install key is the MVP approach; a rotation strategy with secure re-encryption is the obvious follow-up
- **iCloud sync** — CloudKit-backed sync for sessions across devices, with conflict resolution at the segment level
- **Accessibility pass** — thorough VoiceOver audit across recording, session list, and detail screens

---

## Contributing

Fork the repo, branch from `main`, one fix or feature per PR. Commit format follows Conventional Commits: `type(scope): description`. Bug reports and ideas are welcome as GitHub issues.

---

## License

[MIT](LICENSE) · © 2026 Keyur Savalia
