import Foundation
import Speech
import AVFoundation

enum AsrError: Error {
    case notAuthorized
    case unavailable
    case noResult
    case timeout
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

    /// Returns a human-readable error if Speech Recognition is not authorized, else `nil`.
    /// Single source of truth for the speech-auth gate so multi-locale paths can fail once.
    nonisolated static func speechAuthorizationError() -> String? {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return nil
        case .notDetermined:
            return "Speech Recognition permission has not been granted. Run `maclisten auth` and grant access to your terminal in System Settings."
        case .denied:
            return "Speech Recognition permission denied. Enable it in System Settings > Privacy & Security > Speech Recognition."
        case .restricted:
            return "Speech Recognition is restricted on this device."
        @unknown default:
            return "Speech Recognition authorization status unknown."
        }
    }

    func transcribeFile(
        url: URL,
        locale: String,
        onDevice: Bool,
        includeSegments: Bool = false,
        timeout: TimeInterval = 30
    ) async -> [String: Any] {
        if let authErr = Self.speechAuthorizationError() {
            return ["ok": false, "locale": locale, "error": authErr]
        }

        do {
            let session = FileRecognitionSession()
            let r = try await session.recognize(
                url: url, locale: locale, onDevice: onDevice, includeSegments: includeSegments, timeout: timeout
            )
            var result: [String: Any] = [
                "ok": true,
                "locale": locale,
                "onDevice": onDevice,
                "confidence": r.confidence,
                "text": r.text,
            ]
            if let segments = r.segments {
                result["segments"] = segments
            }
            return result
        } catch AsrError.unavailable {
            return ["ok": false, "locale": locale, "error": "Speech recognizer is not available for locale '\(locale)'"]
        } catch AsrError.timeout {
            return ["ok": false, "locale": locale, "error": "Transcription timed out"]
        } catch {
            return ["ok": false, "locale": locale, "error": error.localizedDescription]
        }
    }

    /// Run `locales` against the same audio and return the highest-confidence result.
    ///
    /// Per-locale failures are recorded in `candidates` and do not abort the rest. When no
    /// locale produces a result, returns `ok:false` with the full candidate table.
    func transcribeFileBest(
        url: URL,
        locales: [String],
        onDevice: Bool,
        includeSegments: Bool = false,
        timeout: TimeInterval = 30
    ) async -> [String: Any] {
        if let authErr = Self.speechAuthorizationError() {
            return ["ok": false, "error": authErr]
        }

        var candidates: [[String: Any]] = []
        var best: (locale: String, result: FileRecognitionResult)?

        for locale in locales {
            do {
                let session = FileRecognitionSession()
                let r = try await session.recognize(
                    url: url, locale: locale, onDevice: onDevice, includeSegments: includeSegments, timeout: timeout
                )
                candidates.append([
                    "ok": true,
                    "locale": locale,
                    "confidence": r.confidence,
                    "text": r.text,
                ])
                if best == nil || r.confidence > best!.result.confidence {
                    best = (locale, r)
                }
            } catch AsrError.unavailable {
                candidates.append(["ok": false, "locale": locale, "error": "locale '\(locale)' not supported or unavailable"])
            } catch AsrError.timeout {
                candidates.append(["ok": false, "locale": locale, "error": "timed out"])
            } catch {
                candidates.append(["ok": false, "locale": locale, "error": error.localizedDescription])
            }
        }

        guard let best = best else {
            return ["ok": false, "error": "No candidate locale produced a result", "candidates": candidates]
        }

        var result: [String: Any] = [
            "ok": true,
            "locale": best.locale,
            "onDevice": onDevice,
            "confidence": best.result.confidence,
            "text": best.result.text,
            "candidates": candidates,
        ]
        if let segments = best.result.segments {
            result["segments"] = segments
        }
        return result
    }

    func transcribeMicrophone(
        locale: String,
        onDevice: Bool,
        timeout: TimeInterval,
        onPartial: ((String) -> Void)? = nil,
        autoStop: Bool = false,
        autoStopSilence: TimeInterval = 1.5,
        outputURL: URL? = nil
    ) async -> [String: Any] {
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

        var writer: AudioFileWriter?
        if let outputURL = outputURL {
            writer = AudioFileWriter(url: outputURL, inputFormat: recordingFormat)
            if writer == nil {
                return ["ok": false, "error": "Unable to open output audio file at \(outputURL.path)"]
            }
        }

        var partialTexts: [String] = []
        var finalText: String?
        var lastPartialText: String = ""
        var lastPartialTime: Date = Date()
        var shouldStop = false

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                if result.isFinal {
                    finalText = text
                } else {
                    partialTexts.append(text)
                    onPartial?(text)
                    if autoStop {
                        lastPartialText = text
                        lastPartialTime = Date()
                    }
                }
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            writer?.write(buffer)
        }

        audioEngine?.prepare()
        do {
            try audioEngine?.start()
        } catch {
            return ["ok": false, "error": "Audio engine start failed: \(error.localizedDescription)"]
        }

        if autoStop {
            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
                let silence = Date().timeIntervalSince(lastPartialTime)
                if !lastPartialText.isEmpty && silence >= autoStopSilence {
                    shouldStop = true
                    self.stopMicrophone()
                    timer.invalidate()
                }
            }
        }

        let start = Date()
        while !shouldStop && Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        stopMicrophone()
        writer?.close()

        let text = finalText ?? partialTexts.last ?? ""
        let recordedSeconds = Date().timeIntervalSince(start)
        var result: [String: Any] = [
            "ok": true,
            "locale": locale,
            "onDevice": onDevice,
            "timeout": timeout,
            "text": text,
            "recordedSeconds": recordedSeconds,
        ]
        if autoStop {
            result["stoppedEarly"] = shouldStop
        }
        if let outputURL = outputURL {
            result["output"] = outputURL.path
        }
        return result
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

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AsrError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private func authError(_ name: String, status: AVAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "\(name) permission has not been granted. Run `maclisten auth` and grant access to your terminal in System Settings."
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
            return "\(name) permission has not been granted. Run `maclisten auth` and grant access to your terminal in System Settings."
        case .denied:
            return "\(name) permission denied. Enable it in System Settings > Privacy & Security > \(name)."
        case .restricted:
            return "\(name) is restricted on this device."
        @unknown default:
            return "\(name) authorization status unknown."
        }
    }
}
