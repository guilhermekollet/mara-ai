import Foundation
import os

// The pieces of speech-swift's AudioCommon that the vendored engines use.

enum AudioLog {
    static let modelLoading = Logger(subsystem: "com.guilhermekollet.mara-ai", category: "VoiceModelLoading")
    static let inference = Logger(subsystem: "com.guilhermekollet.mara-ai", category: "VoiceInference")
}

public enum AudioModelError: Error, LocalizedError {
    case modelLoadFailed(modelId: String, reason: String, underlying: Error? = nil)
    case inferenceFailed(operation: String, reason: String)
    case voiceNotFound(voice: String, searchPath: String)

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let modelId, let reason, let underlying):
            var message = "Failed to load model '\(modelId)': \(reason)"
            if let underlying { message += " (\(underlying.localizedDescription))" }
            return message
        case .inferenceFailed(let operation, let reason):
            return "Inference failed during \(operation): \(reason)"
        case .voiceNotFound(let voice, let searchPath):
            return "Voice preset '\(voice)' not found at '\(searchPath)'"
        }
    }
}
