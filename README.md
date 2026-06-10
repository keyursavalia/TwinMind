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
