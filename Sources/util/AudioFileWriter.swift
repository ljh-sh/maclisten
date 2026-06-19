import Foundation
import AVFoundation

final class AudioFileWriter {
    private var audioFile: AVAudioFile?
    private var converter: AVAudioConverter?
    private let outputFormat: AVAudioFormat
    private let inputFormat: AVAudioFormat

    init?(url: URL, inputFormat: AVAudioFormat) {
        self.inputFormat = inputFormat

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            return nil
        }
        self.outputFormat = outputFormat

        do {
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: outputFormat.settings,
                commonFormat: outputFormat.commonFormat,
                interleaved: outputFormat.isInterleaved
            )
        } catch {
            return nil
        }

        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        guard let audioFile = audioFile else { return }

        // If formats already match, write directly.
        if buffer.format == outputFormat {
            do {
                try audioFile.write(from: buffer)
            } catch { }
            return
        }

        guard let converter = converter else { return }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputCapacity = UInt32(Double(buffer.frameLength) * ratio) + 16
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            return
        }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            guard !consumed else {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .haveData || status == .endOfStream {
            do {
                try audioFile.write(from: outputBuffer)
            } catch { }
        }
    }

    func close() {
        audioFile = nil
        converter = nil
    }

    var url: URL? {
        audioFile?.url
    }
}
