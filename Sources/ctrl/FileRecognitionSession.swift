import Foundation
import Speech

/// Result of recognizing a single audio file for one locale.
struct FileRecognitionResult {
    let text: String
    /// Average confidence of the best transcription, 0...1.
    let confidence: Double
    /// Per-segment detail when requested; `nil` otherwise.
    let segments: [[String: Any]]?
}

/// Coerce a recognizer confidence `Float` into a JSON-safe `Double`.
/// On-device recognition occasionally reports NaN; JSONSerialization cannot encode NaN.
private func safeConfidence(_ f: Float) -> Double {
    f.isFinite ? Double(f) : 0
}

final class FileRecognitionSession {
    private var continuation: CheckedContinuation<FileRecognitionResult, Error>?
    private var task: SFSpeechRecognitionTask?

    func recognize(
        url: URL,
        locale: String,
        onDevice: Bool,
        includeSegments: Bool = false,
        timeout: TimeInterval = 30
    ) async throws -> FileRecognitionResult {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            throw AsrError.unavailable
        }
        guard recognizer.isAvailable else {
            throw AsrError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = onDevice
        request.shouldReportPartialResults = true

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FileRecognitionResult, Error>) in
            self.continuation = continuation

            self.task = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    self.resume(throwing: error)
                    return
                }
                if let result = result, result.isFinal {
                    let transcription = result.bestTranscription
                    let segs = transcription.segments
                    // Sentence-level confidence = mean of per-segment confidences.
                    // (Speech framework only exposes confidence per segment, not per sentence.)
                    let avg: Double = segs.isEmpty
                        ? 0
                        : segs.map { safeConfidence($0.confidence) }.reduce(0, +) / Double(segs.count)
                    let segments: [[String: Any]]? = includeSegments
                        ? segs.map { seg in
                            [
                                "text": seg.substring as Any,
                                "confidence": safeConfidence(seg.confidence) as Any,
                                "start": seg.timestamp as Any,
                                "duration": seg.duration as Any,
                            ]
                        }
                        : nil
                    self.resume(returning: FileRecognitionResult(
                        text: transcription.formattedString,
                        confidence: avg,
                        segments: segments
                    ))
                }
            }

            Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                self.task?.cancel()
                self.resume(throwing: AsrError.timeout)
            }
        }
    }

    private func resume(returning value: FileRecognitionResult) {
        guard continuation != nil else { return }
        continuation?.resume(returning: value)
        continuation = nil
        task = nil
    }

    private func resume(throwing error: Error) {
        guard continuation != nil else { return }
        continuation?.resume(throwing: error)
        continuation = nil
        task = nil
    }
}
