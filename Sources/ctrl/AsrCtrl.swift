import Foundation
import Speech
import AVFoundation

enum AsrError: Error {
    case notAuthorized
    case unavailable
    case noResult
    case audioSetupFailed(String)
}

@MainActor
class AsrCtrl {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    nonisolated static func supportedLocales() -> [String] {
        SFSpeechRecognizer.supportedLocales()
            .map { $0.identifier }
            .sorted()
    }

    func transcribeFile(url: URL, locale: String, onDevice: Bool) async -> [String: Any] {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .authorized else {
            return ["ok": false, "error": authError("Speech Recognition", status: status)]
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            return ["ok": false, "error": "Locale '\(locale)' is not supported"]
        }
        guard recognizer.isAvailable else {
            return ["ok": false, "error": "Speech recognizer is not available"]
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = onDevice

        do {
            let text = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    if let result = result, result.isFinal {
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    }
                }
            }
            return [
                "ok": true,
                "locale": locale,
                "onDevice": onDevice,
                "text": text,
            ]
        } catch {
            return ["ok": false, "error": error.localizedDescription]
        }
    }

    func transcribeMicrophone(locale: String, onDevice: Bool, timeout: TimeInterval) async -> [String: Any] {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        guard speechStatus == .authorized else {
            return ["ok": false, "error": authError("Speech Recognition", status: speechStatus)]
        }

        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        guard micStatus == .authorized else {
            return ["ok": false, "error": authError("Microphone", status: micStatus)]
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) else {
            return ["ok": false, "error": "Locale '\(locale)' is not supported"]
        }
        guard recognizer.isAvailable else {
            return ["ok": false, "error": "Speech recognizer is not available"]
        }

        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            return ["ok": false, "error": "Unable to create recognition request"]
        }
        request.requiresOnDeviceRecognition = onDevice
        request.shouldReportPartialResults = true

        let inputNode = audioEngine!.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        var partialTexts: [String] = []
        var finalText: String?

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    finalText = text
                } else {
                    partialTexts.append(text)
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine?.prepare()
        do {
            try audioEngine?.start()
        } catch {
            return ["ok": false, "error": "Audio engine start failed: \(error.localizedDescription)"]
        }

        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

        stopMicrophone()

        let text = finalText ?? partialTexts.last ?? ""
        return [
            "ok": true,
            "locale": locale,
            "onDevice": onDevice,
            "timeout": timeout,
            "text": text,
        ]
    }

    func stopMicrophone() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        audioEngine = nil
    }

    private func authError(_ name: String, status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "\(name) permission has not been granted. macOS does not reliably prompt CLI tools for \(name); please grant access to your terminal in System Settings > Privacy & Security > \(name)."
        case .denied:
            return "\(name) permission denied. Enable it in System Settings > Privacy & Security > \(name)."
        case .restricted:
            return "\(name) is restricted on this device."
        @unknown default:
            return "\(name) authorization status unknown."
        }
    }

    private func authError(_ name: String, status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "\(name) permission has not been granted. macOS does not reliably prompt CLI tools for \(name); please grant access to your terminal in System Settings > Privacy & Security > \(name)."
        case .denied:
            return "\(name) permission denied. Enable it in System Settings > Privacy & Security > \(name)."
        case .restricted:
            return "\(name) is restricted on this device."
        @unknown default:
            return "\(name) authorization status unknown."
        }
    }
}
