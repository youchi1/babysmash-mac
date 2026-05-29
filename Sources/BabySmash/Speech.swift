import AVFoundation
import Foundation

/// Wraps AVSpeechSynthesizer, the native macOS text-to-speech engine.
/// Cancels any in-progress utterance before speaking a new one so rapid key
/// presses stay responsive instead of piling up.
final class Speech {
    private let synth = AVSpeechSynthesizer()
    // Slightly slower and a touch higher than default: clearer and friendlier
    // for little ones, and less "robotic" than the raw default voice.
    private let rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.9
    private let pitch: Float = 1.1

    private lazy var voice: AVSpeechSynthesisVoice? = Speech.bestVoice()

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.voice = voice
        synth.speak(utterance)
    }

    /// Picks the most natural-sounding installed voice for the user's language,
    /// preferring Enhanced/Premium quality and the clear "Samantha"/Siri voices,
    /// and avoiding the novelty/robotic legacy voices (Fred, Zarvox, Bells, ...).
    /// If the user installs a higher-quality voice in System Settings, it is
    /// picked up automatically.
    static func bestVoice() -> AVSpeechSynthesisVoice? {
        let preferred = AVSpeechSynthesisVoice.currentLanguageCode() // e.g. "en-US"
        let langPrefix = String(preferred.prefix(2))
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(langPrefix) }
        guard !candidates.isEmpty else {
            return AVSpeechSynthesisVoice(language: preferred)
        }

        func score(_ v: AVSpeechSynthesisVoice) -> Int {
            var s = 0
            if v.language == preferred { s += 100 } else { s += 40 }
            s += v.quality.rawValue * 30 // default=1, enhanced=2, premium=3
            // The old "synthesis.voice" namespace is the novelty/robotic set.
            if v.identifier.hasPrefix("com.apple.speech.synthesis.voice") { s -= 200 }
            if v.identifier.contains("eloquence") { s -= 20 } // also fairly synthetic
            if v.identifier.contains("siri") { s += 25 }      // natural Siri voices
            if v.identifier.contains("voice.compact") { s += 15 } // Samantha & friends
            return s
        }

        let best = candidates.max { score($0) < score($1) }
        if let best { FileHandle.standardError.write(Data("Speech voice: \(best.name) (\(best.identifier))\n".utf8)) }
        return best
    }
}
