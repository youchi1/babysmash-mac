import AppKit

/// Plays the bundled WAV effects using NSSound. Sounds are cached on first use.
final class Sounds {
    private var cache: [String: NSData] = [:]

    private static let laughter = [
        "giggle.wav", "babylaugh.wav", "babygigl2.wav",
        "ccgiggle.wav", "laughingmice.wav", "scooby2.wav",
    ]

    static func randomLaugh() -> String { laughter[Int.random(in: 0..<laughter.count)] }

    /// Plays a bundled sound by file name (e.g. "giggle.wav").
    func play(_ name: String) {
        guard let data = data(for: name) else { return }
        // A fresh NSSound per playback allows overlapping effects.
        if let sound = NSSound(data: data as Data) {
            sound.play()
        }
    }

    // One reusable NSSound per "channel". A new sound on a channel is ignored
    // while that channel is still playing (SND_NOSTOP behaviour), so rapid
    // streams of events (mouse-draw, scroll wheel) never overlap into noise.
    private var channels: [String: NSSound] = [:]

    /// Plays `name` on `channel` only if that channel isn't already playing.
    /// A fresh instance is used each time so it reliably replays, and it always
    /// plays to completion (never force-stopped).
    func playNonOverlapping(_ name: String, channel: String) {
        if channels[channel]?.isPlaying == true { return }
        guard let data = data(for: name), let sound = NSSound(data: data as Data) else { return }
        channels[channel] = sound
        sound.play()
    }

    private func data(for name: String) -> NSData? {
        if let cached = cache[name] { return cached }
        guard let url = resourceURL(for: name),
              let data = NSData(contentsOf: url) else { return nil }
        cache[name] = data
        return data
    }

    private func resourceURL(for name: String) -> URL? {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        // Sounds live in Resources/Sounds inside the .app bundle.
        if let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "Sounds") {
            return url
        }
        return Bundle.main.url(forResource: base, withExtension: ext)
    }
}
