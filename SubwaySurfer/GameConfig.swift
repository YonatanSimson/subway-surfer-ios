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

    static let startSpeed: Float = 9.5
    static let maxSpeed: Float = 34.0
    /// Reaches `maxSpeed` at roughly 2400m.
    static let speedGainPerMetre: Float = 0.011

    // MARK: Obstacles

    /// How far ahead of the camera obstacles appear. Fog hides the pop-in.
    static let spawnDistance: Float = 110
    /// Clear run-up before the first obstacle. Long enough to get oriented,
    /// short enough that the run doesn't open on an empty corridor.
    static let firstSpawnDistance: Float = 32

    // Obstacle spacing is defined in **seconds of reaction time**, not metres.
    // Speed more than quadruples over a run, so a fixed metre gap would get
    // impossible rather than merely hard: 9m at 34 m/s leaves 0.26s to react,
    // which is below human reaction time. Holding a time budget instead and
    // multiplying by current speed keeps the ramp hard but fair.
    static let startGapSeconds: Float = 1.6
    static let minGapSeconds: Float = 0.55
    /// Reaches `minGapSeconds` at roughly 1700m.
    static let gapLossPerMetre: Float = 0.00062
    /// Absolute floor, so obstacles can never overlap at low speed.
    static let minSpacingMetres: Float = 8

    /// Two-lane rows only begin after this distance, then ramp in.
    static let doubleRowStartDistance: Float = 160
    /// Distance over which the chance of a two-lane row ramps to `maxDoubleChance`.
    static let doubleRowRampDistance: Float = 3000
    static let maxDoubleChance: Float = 0.60

    // MARK: Coins

    /// Chance that an obstacle row also lays a coin trail in a free lane.
    static let coinTrailChance: Float = 0.62
    static let coinTrailLength = 4
    static let coinSpacing: Float = 2.6
    /// How far past the obstacle row the trail begins.
    static let coinTrailOffset: Float = 4.0
    /// Points per coin, on top of the distance score.
    static let coinValue = 10

    // MARK: Zones

    /// How far the run travels before the environment changes. Kept short
    /// enough that the first change arrives while the run is still easy.
    static let zoneLength: Float = 450
    /// Distance over which fog and sky blend into a new zone.
    static let zoneTransitionLength: Float = 90

    // MARK: Frame timing

    /// Clamp on per-frame delta time, so a hitch or a pause can't teleport the world.
    static let maxFrameDelta: Float = 1.0 / 20.0
}
