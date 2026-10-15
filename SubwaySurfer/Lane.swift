import Foundation

/// The three fixed tracks the player can occupy. The raw value doubles as the
/// lane offset, so `x` is just a multiply.
enum Lane: Int, CaseIterable {
    case left = -1
    case center = 0
    case right = 1

    var x: Float { Float(rawValue) * GameConfig.laneWidth }

    /// Clamped neighbour lookup: swiping left in the left lane is a no-op.
    func shifted(by delta: Int) -> Lane {
        Lane(rawValue: min(1, max(-1, rawValue + delta))) ?? self
    }
}
