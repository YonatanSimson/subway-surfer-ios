import SceneKit

/// Every tunable number in the game lives here, so balancing is one file.
enum GameConfig {

    // MARK: Track

    /// Distance between lane centres.
    static let laneWidth: Float = 1.6
    /// Length of one recycled floor segment, in metres.
    static let segmentLength: Float = 20
    /// Enough segments to cover `spawnDistance` ahead plus a little behind the camera.
    static let segmentCount = 8
    static let corridorWidth: Float = 5.4
    static let wallHeight: Float = 3.0

    // MARK: Camera

    static let cameraPosition = SCNVector3(0, 3.1, 6.6)
    static let cameraPitch: Float = -0.20

    // MARK: Player

    static let playerRadius: Float = 0.30
    static let playerHeight: Float = 1.40
    /// Sideways travel speed during a lane change, in metres/sec.
    static let laneChangeSpeed: Float = 9.0
    static let jumpVelocity: Float = 7.2
    static let gravity: Float = -22.0
    /// Downward kick when you swipe down while airborne.
    static let fastFallVelocity: Float = -18.0
    static let slideDuration: Float = 0.60
    /// Sliding squashes the player to this fraction of full height.
    static let slideHeightFactor: Float = 0.45
    /// Collision box is shrunk by this much, so near-misses read as misses.
    static let collisionForgiveness: Float = 0.06

    // MARK: Speed and difficulty

    static let startSpeed: Float = 9.0
    static let maxSpeed: Float = 26.0
    static let speedGainPerMetre: Float = 0.012

    // MARK: Obstacles

    /// How far ahead of the camera obstacles appear. Fog hides the pop-in.
    static let spawnDistance: Float = 110
    static let startSpacing: Float = 17
    static let minSpacing: Float = 10.5
    static let spacingLossPerMetre: Float = 0.004
    /// Distance over which the chance of a two-lane row ramps to `maxDoubleChance`.
    static let doubleRowRampDistance: Float = 4000
    static let maxDoubleChance: Float = 0.45

    // MARK: Frame timing

    /// Clamp on per-frame delta time, so a hitch or a pause can't teleport the world.
    static let maxFrameDelta: Float = 1.0 / 20.0
}
