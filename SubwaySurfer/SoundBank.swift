import AVFoundation

/// Preloaded sound effects.
///
/// Each effect keeps a small ring of players so repeats can overlap — coins in
/// particular arrive faster than one player can finish. Everything is loaded
/// up front; allocating or decoding mid-run would risk a hitch.
final class SoundBank {

    enum Effect: String, CaseIterable {
        case jump, slide, coin, crash

        /// How many of this effect can sound at once.
        var voices: Int {
            switch self {
            case .coin:  return 4   // trails collect in quick succession
            case .jump:  return 2
            case .slide: return 2
            case .crash: return 1   // only ever one per run
            }
        }
    }

    private var players: [Effect: [AVAudioPlayer]] = [:]
    private var nextVoice: [Effect: Int] = [:]
    /// Playback is kicked off the render thread, which must not block.
    private let queue = DispatchQueue(label: "SoundBank", qos: .userInitiated)

    init() {
        configureSession()
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
                continue
            }
            players[effect] = (0..<effect.voices).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
                return player
            }
            nextVoice[effect] = 0
        }
    }

    /// `.ambient` so the game mixes with whatever the player is listening to
    /// instead of stopping it.
    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func play(_ effect: Effect) {
        queue.async { [weak self] in
            guard let self,
                  let voices = self.players[effect], !voices.isEmpty else { return }
            let index = (self.nextVoice[effect] ?? 0) % voices.count
            self.nextVoice[effect] = index + 1
            let player = voices[index]
            player.currentTime = 0
            player.play()
        }
    }
}
