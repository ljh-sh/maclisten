import Foundation
import Speech
import AVFoundation

private var gWatchCancelled: Int32 = 0
private var gWatchStopReason: String?

final class WatchCtrl {
    private var audioEngine: AVAudioEngine?
    private var currentRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func watch(
        locale: String,
        onDevice: Bool,
        keyword: String?,
        onPartial: ((String) -> Void)?,
        onSegment: ((String) -> Void)?,
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

        gWatchCancelled = 0
        gWatchStopReason = nil

        signal(SIGINT) { _ in
            gWatchStopReason = "Ctrl-C"
            gWatchCancelled = 1
        }
        signal(SIGTERM) { _ in
            gWatchStopReason = "SIGTERM"
            gWatchCancelled = 1
        }

        // Intercept Ctrl-D (EOF on stdin) only when stdin is an interactive TTY.
        if isatty(STDIN_FILENO) != 0 {
            FileHandle.standardInput.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    gWatchStopReason = "Ctrl-D"
                    gWatchCancelled = 1
                    FileHandle.standardInput.readabilityHandler = nil
                }
            }
        }

        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        var writer: AudioFileWriter?
        if let outputURL = outputURL {
            writer = AudioFileWriter(url: outputURL, inputFormat: recordingFormat)
            if writer == nil {
                return ["ok": false, "error": "Unable to open output audio file at \(outputURL.path)"]
            }
        }

        let start = Date()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.currentRequest?.append(buffer)
            writer?.write(buffer)
        }

        audioEngine?.prepare()
        do {
            try audioEngine?.start()
        } catch {
            return ["ok": false, "error": "Audio engine start failed: \(error.localizedDescription)"]
        }

        var segments: [String] = []

        while gWatchCancelled == 0 {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = onDevice
            request.shouldReportPartialResults = true
            currentRequest = request

            let segment = await recognizeSegment(recognizer: recognizer, request: request, onPartial: onPartial)

            if let segment = segment, !segment.isEmpty {
                let shouldEmit: Bool
                if let kw = keyword?.lowercased() {
                    shouldEmit = segment.lowercased().contains(kw)
                } else {
                    shouldEmit = true
                }
                if shouldEmit {
                    segments.append(segment)
                    onSegment?(segment)
                }
            }

            recognitionTask?.cancel()
            recognitionTask = nil
            currentRequest = nil

            if segment == nil {
                break
            }
        }

        let recordedSeconds = Date().timeIntervalSince(start)
        stop()
        writer?.close()
        FileHandle.standardInput.readabilityHandler = nil

        // Emit a log line explaining why watch stopped.
        if let reason = gWatchStopReason {
            printJson(["ok": true, "event": "stopped", "reason": reason])
            fflush(stdout)
        }

        var result: [String: Any] = [
            "ok": true,
            "locale": locale,
            "onDevice": onDevice,
            "keyword": keyword ?? NSNull(),
            "segments": segments,
            "count": segments.count,
            "recordedSeconds": recordedSeconds,
            "stopReason": gWatchStopReason ?? NSNull(),
        ]
        if let outputURL = outputURL {
            result["output"] = outputURL.path
        }
        return result
    }

    private func recognizeSegment(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onPartial: ((String) -> Void)?
    ) async -> String? {
        final class Box {
            var continuation: CheckedContinuation<String?, Never>?
            var resumed = false
            func resume(_ value: String?) {
                guard !resumed else { return }
                resumed = true
                continuation?.resume(returning: value)
            }
        }
        let box = Box()

        return await withCheckedContinuation { continuation in
            box.continuation = continuation

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        box.resume(text)
                    } else {
                        onPartial?(text)
                    }
                } else if let error = error {
                    box.resume(nil)
                }
            }

            // Restart recognition every 60 seconds to avoid framework time limits.
            Task {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                box.resume(nil)
            }
        }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        currentRequest?.endAudio()
        recognitionTask?.cancel()
        currentRequest = nil
        recognitionTask = nil
        audioEngine = nil
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
