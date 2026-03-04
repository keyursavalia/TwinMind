//
//  AudioRouteInfo.swift
//  TwinMind
//
//  Purpose: Captures audio input/output route information for display and logging.
//  Design decision: Value type that wraps AVAudioSession route details
//  without importing AVFoundation in pure domain models.
//

import Foundation

/// Information about the current audio input and output routes.
///
/// This type encapsulates the active audio devices (microphone, speakers, headphones)
/// for display in the UI and for handling route change events.
public struct AudioRouteInfo: Sendable, Equatable, Codable {

    /// The name of the current input device (e.g., "iPhone Microphone", "AirPods").
    public let inputDeviceName: String

    /// The type of the current input device (e.g., "MicrophoneBuiltIn", "BluetoothHFP").
    public let inputDeviceType: String

    /// The name of the current output device (e.g., "Speaker", "AirPods").
    public let outputDeviceName: String

    /// The type of the current output device (e.g., "Speaker", "BluetoothA2DP").
    public let outputDeviceType: String

    /// Whether the input device is wireless (Bluetooth, AirPlay).
    public let isInputWireless: Bool

    /// Whether the output device is wireless (Bluetooth, AirPlay).
    public let isOutputWireless: Bool

    /// Creates a new audio route info instance.
    ///
    /// - Parameters:
    ///   - inputDeviceName: The name of the input device.
    ///   - inputDeviceType: The type of the input device.
    ///   - outputDeviceName: The name of the output device.
    ///   - outputDeviceType: The type of the output device.
    ///   - isInputWireless: Whether the input is wireless.
    ///   - isOutputWireless: Whether the output is wireless.
    public init(
        inputDeviceName: String,
        inputDeviceType: String,
        outputDeviceName: String,
        outputDeviceType: String,
        isInputWireless: Bool,
        isOutputWireless: Bool
    ) {
        self.inputDeviceName = inputDeviceName
        self.inputDeviceType = inputDeviceType
        self.outputDeviceName = outputDeviceName
        self.outputDeviceType = outputDeviceType
        self.isInputWireless = isInputWireless
        self.isOutputWireless = isOutputWireless
    }
}

// MARK: - Computed Properties

extension AudioRouteInfo {

    /// A user-facing display string for the input device.
    public var inputDisplayString: String {
        if isInputWireless {
            return "\(inputDeviceName) (Wireless)"
        }
        return inputDeviceName
    }

    /// A user-facing display string for the output device.
    public var outputDisplayString: String {
        if isOutputWireless {
            return "\(outputDeviceName) (Wireless)"
        }
        return outputDeviceName
    }

    /// Icon name for the input device (SF Symbols).
    public var inputIconName: String {
        if inputDeviceType.contains("Bluetooth") || isInputWireless {
            return "airpodspro"
        } else if inputDeviceType.contains("USB") {
            return "cable.connector"
        } else if inputDeviceType.contains("Headset") {
            return "headphones"
        } else {
            return "mic.fill"
        }
    }

    /// Icon name for the output device (SF Symbols).
    public var outputIconName: String {
        if outputDeviceType.contains("Bluetooth") || isOutputWireless {
            return "airpodspro"
        } else if outputDeviceType.contains("USB") {
            return "cable.connector"
        } else if outputDeviceType.contains("Headphones") || outputDeviceType.contains("Headset") {
            return "headphones"
        } else if outputDeviceType.contains("Speaker") {
            return "speaker.wave.2.fill"
        } else {
            return "hifispeaker.fill"
        }
    }
}

// MARK: - Default Instance

extension AudioRouteInfo {

    /// Default route using built-in iPhone microphone and speaker.
    public static var `default`: AudioRouteInfo {
        AudioRouteInfo(
            inputDeviceName: "iPhone Microphone",
            inputDeviceType: "MicrophoneBuiltIn",
            outputDeviceName: "Speaker",
            outputDeviceType: "Speaker",
            isInputWireless: false,
            isOutputWireless: false
        )
    }
}
