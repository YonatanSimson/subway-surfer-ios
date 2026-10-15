import SceneKit

/// An axis-aligned box used for collision tests.
///
/// The game moves every node by hand in the render loop, so collisions are
/// resolved with explicit box overlap rather than SceneKit physics bodies. That
/// keeps the one mechanic that can end a run fully deterministic, and lets the
/// Z axis be tested as a swept interval (see `Obstacle.hits`) so a fast
/// obstacle can never tunnel through the player between two frames.
struct Box {
    var centerX: Float
    var centerY: Float
    var halfWidth: Float
    var halfHeight: Float

    func insetBy(_ amount: Float) -> Box {
        Box(centerX: centerX,
            centerY: centerY,
            halfWidth: max(0, halfWidth - amount),
            halfHeight: max(0, halfHeight - amount))
    }

    /// Overlap on the X and Y axes only; Z is handled separately.
    func overlapsInXY(_ other: Box) -> Bool {
        abs(centerX - other.centerX) < halfWidth + other.halfWidth
            && abs(centerY - other.centerY) < halfHeight + other.halfHeight
    }
}
