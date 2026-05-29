import Foundation

/// Detects whether the most recently typed run of letters forms a real word,
/// using the bundled Words.txt dictionary. Ported from the original WordFinder.
final class WordFinder {
    private let minLength = 2
    private let maxLength = 15
    private var words: Set<String> = []
    private var ready = false

    init() {
        // Load the dictionary off the main thread so startup stays snappy.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.load()
        }
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "Words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        var set = Set<String>()
        text.enumerateLines { line, _ in
            let s = line.trimmingCharacters(in: .whitespaces)
            if !s.contains(";"), !s.contains("/"), !s.contains("\\"),
               s.count >= self.minLength, s.count <= self.maxLength {
                set.insert(s.uppercased())
            }
        }
        self.words = set
        self.ready = true
    }

    /// Given the recent figure history (letters as uppercase Characters,
    /// non-letters as nil), returns the longest real word ending at the most
    /// recent letter, or nil.
    func lastWord(history: [Character?]) -> String? {
        guard ready, history.count >= minLength else { return nil }

        var longest: String?
        var current = ""
        var index = history.count - 1
        let lowest = max(0, index - maxLength)

        while index >= lowest {
            guard let ch = history[index] else { break }
            current = String(ch) + current
            if current.count >= minLength, words.contains(current) {
                longest = current
            }
            index -= 1
        }
        return longest
    }
}
