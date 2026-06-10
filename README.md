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
