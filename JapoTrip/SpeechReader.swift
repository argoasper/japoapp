import Foundation
import AVFoundation
import Combine

@MainActor
final class SpeechReader: NSObject, ObservableObject {
    private let synth = AVSpeechSynthesizer()
    /// The utterance we are currently interested in. Callbacks that arrive for
    /// anything else are stale (see `finished(_:)`) and must be ignored.
    private var currentUtterance: AVSpeechUtterance?
    @Published var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
        // `.ambient` (not `.playback`) so the phone's ring/silent switch is
        // respected: reading a description out loud inside a temple should
        // never override a silenced phone.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .spokenAudio, options: [.duckOthers])
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Drop the old utterance FIRST: stopSpeaking(at:.immediate) fires
        // didCancel asynchronously, and without this the late callback would
        // deactivate the audio session and clear `isSpeaking` right after the
        // new utterance had already started.
        currentUtterance = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }

        try? AVAudioSession.sharedInstance().setActive(true, options: [])
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "ca-ES")
            ?? AVSpeechSynthesisVoice(language: "es-ES")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        currentUtterance = utterance
        synth.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        currentUtterance = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
        deactivateSession()
    }

    /// Releases the audio session so other apps (Music, Maps navigation voice)
    /// stop being ducked once we are done reading.
    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    fileprivate func finished(_ utterance: AVSpeechUtterance) {
        guard utterance === currentUtterance else { return }
        currentUtterance = nil
        isSpeaking = false
        deactivateSession()
    }
}

extension SpeechReader: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished(utterance) }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finished(utterance) }
    }
}
