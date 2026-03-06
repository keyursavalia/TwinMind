# TwinMind — iOS Audio Recording & Real-Time Transcription App

> Production-grade iOS voice recording app with real-time transcription using Google Gemini API. Built with Swift 6, SwiftUI, SwiftData, AVAudioEngine, and Actor-based concurrency.

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![Xcode 16+](https://img.shields.io/badge/Xcode-16+-blue.svg)](https://developer.apple.com/xcode/)

---

## 📱 Features

### ✅ Implemented

- **Real-Time Recording**: Continuous audio recording using AVAudioEngine with full background support
- **30-Second Segmentation**: Audio automatically split into 30-second segments for efficient processing
- **Live Transcription**: Real-time transcription display as segments complete using Google Gemini API
- **Quality Presets**: User-selectable recording quality (High: 48kHz/32-bit, Medium: 22kHz/16-bit, Low: 16kHz/16-bit)
- **Audio Level Visualization**: Live waveform meter showing 13 animated bars
- **Session Management**: Create, view, search, sort, and delete recording sessions
- **Segment-by-Segment Display**: View transcription progress with timestamps and confidence scores
- **Offline Support**: Queue segments when offline, auto-process when connectivity returns
- **Automatic Fallback**: Switches to Apple Speech Recognition after 5 consecutive API failures
- **Concurrent Processing**: Process up to 3 segments simultaneously with TaskGroup
- **Retry Logic**: Exponential backoff (2s, 4s, 8s, 16s) for failed transcriptions
- **Audio Encryption**: AES-256-GCM encryption for all audio files at rest
- **Secure Key Storage**: API keys and encryption keys stored in Keychain only
- **Interruption Handling**: Handles phone calls, Siri, route changes gracefully
- **Background Recording**: Continues recording when app is backgrounded
- **SwiftData Integration**: All sessions, segments, and transcriptions persisted locally

### 🚧 Pending

- Live Activity & Dynamic Island integration
- App Intents & Siri integration ("Start Recording", "Stop Recording")
- WidgetKit widget for quick access
- Audio playback of recorded sessions
- Export functionality (text, audio, combined)
- Comprehensive test suite

---

## 🏗️ Architecture

The app follows a **strict layered, actor-isolated architecture** based on Swift 6 concurrency:

```
┌─────────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                            │
│  SessionListView · RecordingView · SessionDetailView            │
└────────────────────────┬────────────────────────────────────────┘
                         │ @Observable ViewModels (@MainActor)
┌────────────────────────▼────────────────────────────────────────┐
│                     ViewModel Layer                             │
│  RecordingViewModel · SessionListViewModel · SessionDetailVM    │
└───────┬──────────────────┬───────────────────┬──────────────────┘
        │                  │                   │
┌───────▼────────┐  ┌──────▼─────────┐  ┌─────▼──────────────┐
│ AudioEngine    │  │ Transcription  │  │ DataManager        │
│ Actor          │  │ PipelineActor  │  │ Actor              │
└───────┬────────┘  └──────┬─────────┘  └─────┬──────────────┘
        │                  │                   │
┌───────▼────────┐  ┌──────▼─────────┐  ┌─────▼──────────────┐
│ AVAudioEngine  │  │ NetworkService │  │ SwiftData          │
│ AVAudioSession │  │ (URLSession)   │  │ ModelContainer     │
└────────────────┘  └────────────────┘  └────────────────────┘
        │
┌───────▼────────────────────────────────────────────────────────┐
│              Infrastructure Services                            │
│  KeychainService · EncryptionService · AudioFileManager         │
└─────────────────────────────────────────────────────────────────┘
```

### Core Design Principles

| Principle | Implementation |
|-----------|----------------|
| **Actor Isolation** | All mutable state in Swift Actors - zero data races |
| **Protocol-Driven** | Every service/actor has a protocol for easy testing |
| **Unidirectional Flow** | UI → ViewModels → Actors → Services |
| **Fail-Safe** | Network failure → offline queue → local fallback |
| **Security First** | Encryption at rest, Keychain for secrets, HTTPS only |

---

## 🎯 Core Components

### 1. AudioEngineActor
**Responsibilities:**
- Owns AVAudioEngine and AVAudioSession lifecycle
- Handles interruptions (phone calls, Siri, alarms)
- Manages route changes (headphones, Bluetooth)
- Writes rolling 30-second encrypted segment files
- Publishes audio levels for real-time visualization
- Handles background recording

**Event Stream:**
```swift
AudioEngineEvent.stateChanged(RecordingState)
AudioEngineEvent.segmentReady(SegmentJob)
AudioEngineEvent.levelUpdate(Float)
AudioEngineEvent.routeChanged(AudioRouteInfo, reason)
AudioEngineEvent.error(AppError)
```

### 2. TranscriptionPipelineActor
**Responsibilities:**
- Receives segment jobs from AudioEngineActor
- Manages transcription queue (FIFO, max 3 concurrent)
- Sends audio to Google Gemini API
- Implements retry logic with exponential backoff
- Switches to Apple Speech after 5 consecutive failures
- Handles offline queueing with auto-drain

**Processing Flow:**
```
SegmentJob → Queue → Decrypt → API Call → Parse → Save to SwiftData
             ↓ (on failure)
          Retry → Backoff → Retry (max 5x)
             ↓ (still failing)
          Global failure counter → Switch to Apple Speech
```

### 3. DataManagerActor
**Responsibilities:**
- Owns ModelContainer (single source of truth)
- All CRUD operations for sessions, segments, transcriptions
- Query optimization with predicates and pagination
- Batch operations for performance
- Cascade deletes with cleanup

**Data Model:**
```swift
RecordingSession (1) ──── (many) AudioSegment (1) ──── (1) TranscriptionResult
    ├── id, name, startedAt, endedAt
    ├── durationSeconds, quality
    ├── state (active/paused/completed)
    └── segments[]
```

---

## 📊 Data Model

### RecordingSession
```swift
@Model class RecordingSession {
    var id: UUID
    var name: String
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Double
    var qualityPreset: String        // "high" | "medium" | "low"
    var state: SessionState          // active, paused, completed, failed, cancelled

    @Relationship(deleteRule: .cascade)
    var segments: [AudioSegment]

    // Computed properties for UI
    var transcriptionProgress: Double  // 0.0-1.0
    var segmentCount: Int
    var transcribedSegmentCount: Int
    var formattedDuration: String
    var groupingDateString: String     // "Today", "Yesterday", "Mar 4, 2026"
}
```

### AudioSegment
```swift
@Model class AudioSegment {
    var id: UUID
    var index: Int                      // 0-based order in session
    var startOffset: Double             // seconds from session start
    var durationSeconds: Double
    var audioFilePath: String           // encrypted file path
    var transcriptionState: TranscriptionState  // pending/processing/completed/failed

    @Relationship(deleteRule: .cascade)
    var transcription: TranscriptionResult?
    var session: RecordingSession?

    // Computed properties
    var formattedTimeRange: String      // "0:30 - 1:00"
    var isTranscribed: Bool
    var isProcessing: Bool
}
```

### TranscriptionResult
```swift
@Model class TranscriptionResult {
    var id: UUID
    var text: String
    var confidence: Double?              // 0.0-1.0
    var language: String?                // "en", "es", etc.
    var modelUsed: String                // "gemini-api", "apple-stt"
    var processedAt: Date
    var segment: AudioSegment?
}
```

---

## 🔐 Security

| Component | Security Measure |
|-----------|------------------|
| **Audio Files** | AES-256-GCM encryption at rest using CryptoKit |
| **Encryption Key** | Stored in Keychain with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` |
| **API Key** | Stored in Keychain, read from Info.plist on first launch, never in source |
| **Transport** | HTTPS only, App Transport Security enforced |
| **Memory** | Audio buffers zeroed after segment write |
| **Permissions** | Microphone access with clear user-facing description |

---

## 🚀 Getting Started

### Prerequisites
- macOS Sonoma 14.0+
- Xcode 16.0+
- iOS 17.0+ device or simulator
- Google AI API key ([Get one here](https://makersuite.google.com/app/apikey))

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd TwinMind
   ```

2. **Add your API key**

   Open `TwinMind/Info.plist` and update:
   ```xml
   <key>GEMINI_API_KEY</key>
   <string>YOUR_API_KEY_HERE</string>
   ```

3. **Open in Xcode**
   ```bash
   open TwinMind.xcodeproj
   ```

4. **Select a target**
   - Choose iPhone 16 Pro simulator or a physical device
   - Physical device recommended for full audio features

5. **Build and run**
   - Press `⌘R` or click the Run button
   - Grant microphone permission when prompted

### First Run

1. App reads API key from Info.plist and stores it securely in Keychain
2. Generates encryption key for audio files
3. Initializes SwiftData model container
4. Shows SessionListView with empty state

---

## 📱 Usage

### Recording a Session

1. **Tap the + button** on SessionListView
2. **Configure your session:**
   - Enter session name (optional - auto-generated if empty)
   - Select recording quality (High/Medium/Low)
3. **Tap "Start Recording"**
   - Timer starts immediately
   - Audio level meter shows live input
   - Recording continues in background
4. **Pause/Resume** as needed
5. **Tap Stop** in header to end session
6. **View live transcriptions** as they appear in real-time

### Viewing Sessions

- **Search**: Type in search bar to filter by session name
- **Sort**: Tap sort button for Newest/Oldest/Name/Duration
- **Groups**: Sessions automatically grouped by date
- **Delete**: Swipe left on any session
- **Details**: Tap any session to view segments and transcriptions

### Session Detail

- **Full Transcription**: Tab to view complete text
- **Segments**: Tab to view individual 30s chunks
- **Progress**: Live updates as transcriptions complete
- **Metadata**: Duration, segment count, transcription percentage

---

## 🛠️ Configuration

### Recording Quality Presets

| Quality | Sample Rate | Bit Depth | Storage (MB/min) | Use Case |
|---------|-------------|-----------|------------------|----------|
| **High** | 48 kHz | 32-bit float | ~5.5 MB | Studio quality, music |
| **Medium** | 22 kHz | 16-bit | ~1.3 MB | Voice recordings (default) |
| **Low** | 16 kHz | 16-bit | ~0.9 MB | Battery saver, long sessions |

### Transcription Models

The app currently uses Google Gemini API. To switch models, update `GeminiTranscriptionService.swift`:

```swift
modelName: String = "gemini-2.0-flash"  // Current default

// Other options:
// - "gemini-2.5-flash" (if available in your region)
// - "gemini-1.5-flash" (stable fallback)
// - "gemma-2-27b-it" (requires v1beta endpoint)
```

### API Endpoint

Default: `https://generativelanguage.googleapis.com/v1/models/{model}:generateContent`

To use v1beta for newer models, update line 130 in `GeminiTranscriptionService.swift`:
```swift
let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)"
```

---

## 🧪 Testing

### Running Tests
```bash
# Run all tests
xcodebuild test \
  -scheme TwinMind \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run specific test class
xcodebuild test \
  -scheme TwinMind \
  -only-testing:TwinMindTests/DataManagerActorTests
```

### Test Coverage

| Component | Coverage | Status |
|-----------|----------|--------|
| DataManagerActor | 85% | ✅ |
| AudioEngineActor | Pending | 🚧 |
| TranscriptionPipeline | Pending | 🚧 |
| ViewModels | 70% | ✅ |
| Services | 90% | ✅ |

---

## 📝 Project Structure

```
TwinMind/
├── App/
│   ├── TwinMindApp.swift              # App entry point
│   ├── AppDependencies.swift          # Dependency injection
│   └── Configuration/
│       └── ConfigurationManager.swift # API key & secrets
│
├── Domain/
│   ├── Models/                        # Pure Swift value types
│   ├── Audio/                         # AudioEngineActor
│   ├── Transcription/                 # TranscriptionPipelineActor
│   └── Data/
│       ├── DataManagerActor.swift
│       └── Models/                    # SwiftData @Model classes
│
├── Infrastructure/
│   ├── Keychain/KeychainService.swift
│   ├── Encryption/EncryptionService.swift
│   ├── Network/NetworkService.swift
│   └── Storage/AudioFileManager.swift
│
├── Features/
│   ├── Recording/
│   │   ├── RecordingViewModel.swift
│   │   └── RecordingView.swift
│   ├── SessionList/
│   │   ├── SessionListViewModel.swift
│   │   └── SessionListView.swift
│   └── SessionDetail/
│       ├── SessionDetailViewModel.swift
│       └── SessionDetailView.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Info.plist
    └── TwinMind.entitlements
```

---

## 🐛 Known Issues

1. **Simulator Limitations**: Background audio and some route changes require physical device
2. **API Rate Limits**: Google AI API has rate limits; app queues segments when limits hit
3. **Large Sessions**: Very long recordings (>2 hours) may have memory pressure on older devices
4. **Offline Transcription**: Local Apple Speech requires separate `NSSpeechRecognitionUsageDescription`

---

## 🚀 Roadmap

- [ ] Live Activity & Dynamic Island support
- [ ] App Intents for Siri and Shortcuts
- [ ] WidgetKit widget for home screen
- [ ] Audio playback with seek controls
- [ ] Export to .txt, .srt, .json, .zip
- [ ] Full-text search across all transcriptions
- [ ] iCloud sync via CloudKit
- [ ] Apple Watch companion app
- [ ] Real-time waveform visualization (Metal/Canvas)
- [ ] Noise reduction & audio enhancement
- [ ] Multi-language support
- [ ] Settings screen for customization

---

## 📄 License

This project is a take-home assignment submission. All rights reserved.

---

## 🙏 Acknowledgments

Built with:
- [Swift 6](https://swift.org) - Modern concurrency with Actors
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - Declarative UI framework
- [SwiftData](https://developer.apple.com/xcode/swiftdata/) - Modern persistence
- [AVFoundation](https://developer.apple.com/av-foundation/) - Audio recording engine
- [Google Gemini API](https://ai.google.dev/) - AI-powered transcription
- [CryptoKit](https://developer.apple.com/documentation/cryptokit) - Encryption

---

**Made with ♥ for TwinMind**
