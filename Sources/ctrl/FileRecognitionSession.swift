import Foundation
import Speech

final class FileRecognitionSession {
    private var continuation: CheckedContinuation<String, Error>?
    private var task: SFSpeechRecognitionTask?

    func recognize(url: URL, locale: String, onDevice: Bool, timeout: TimeInterval = 30) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            throw AsrError.unavailable
        }
        guard recognizer.isAvailable else {
            throw AsrError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = onDevice
        request.shouldReportPartialResults = true

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            self.continuation = continuation

            self.task = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    self.resume(throwing: error)
                    return
                }
                if let result = result, result.isFinal {
                    self.resume(returning: result.bestTranscription.formattedString)
                }
            }

            Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                self.task?.cancel()
                self.resume(throwing: AsrError.timeout)
            }
        }
    }

    private func resume(returning value: String) {
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
