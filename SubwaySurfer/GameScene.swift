import UIKit
import SceneKit

/// Owns the world: camera, lights, the recycled corridor, the player, and the
/// obstacle pool.
///
/// The player and camera never move along Z. Instead the whole world slides
/// toward the camera and segments that fall behind it are pushed back to the
/// front — the "treadmill". That keeps float precision constant no matter how
/// long the run lasts.
final class GameScene: SCNScene {

    let player = Player()

    private let cameraNode = SCNNode()
    private let trackRoot = SCNNode()
    private let obstacleRoot = SCNNode()
    private let coinRoot = SCNNode()

    private var segments: [TrackSegment] = []
    private var obstacles: [Obstacle] = []
    private var coins: [Coin] = []

    /// World distance at which the next obstacle row appears.
    private var nextSpawnDistance: Float = 0

    /// Zone the player is currently in. Unwrapped and monotonic, so the view
    /// controller can spot a change by comparing against the last value it saw.
    private(set) var zoneIndex = 0
    var zoneName: String { Zone.zone(atIndex: zoneIndex).name }

    /// Blend step the sky image was last rebuilt at. Rebuilding a gradient per
    /// frame would be wasteful, and the eye can't tell 16 steps from smooth.
    private var lastSkyStep = Int.min

    private var cameraZ: Float { GameConfig.cameraPosition.z }

    // MARK: Setup

    override init() {
        super.init()
        buildEnvironment()
        buildCamera()
        buildLights()
        buildTrack()
        rootNode.addChildNode(obstacleRoot)
        rootNode.addChildNode(coinRoot)
        rootNode.addChildNode(player.node)
        reset()
    }

    required init?(coder: NSCoder) {
        fatalError("GameScene is created in code, not from a scene file")
    }

    private func buildEnvironment() {
        // Fog does double duty: it sells depth, and it hides obstacles popping
        // in at the spawn distance. Its colour is also what actually sells a
        // zone change, since the segments themselves re-colour out of sight.
        fogStartDistance = CGFloat(GameConfig.spawnDistance * 0.35)
        fogEndDistance = CGFloat(GameConfig.spawnDistance * 0.95)
        fogDensityExponent = 1.4
        updateEnvironment(distance: 0)
    }

    /// Eases fog and sky between zones. Both are scene-global, so unlike the
    /// track they can't be handled per segment.
    private func updateEnvironment(distance: Float) {
        let (from, to, t) = Zone.blend(atDistance: distance)
        fogColor = UIColor.lerp(from.fog, to.fog, t)

        let step = Zone.index(atDistance: distance) * 32 + Int(t * 16)
        guard step != lastSkyStep else { return }
        lastSkyStep = step
        background.contents = GameScene.skyGradient(
            top: UIColor.lerp(from.skyTop, to.skyTop, t),
            mid: UIColor.lerp(from.skyMid, to.skyMid, t),
            bottom: UIColor.lerp(from.skyBottom, to.skyBottom, t)
        )
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 62
        camera.zNear = 0.1
        camera.zFar = Double(GameConfig.spawnDistance + 30)
        cameraNode.camera = camera
        cameraNode.position = GameConfig.cameraPosition
        cameraNode.eulerAngles = SCNVector3(GameConfig.cameraPitch, 0, 0)
        rootNode.addChildNode(cameraNode)
    }

    private func buildLights() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        ambient.light?.color = UIColor(red: 0.75, green: 0.80, blue: 1.0, alpha: 1)
        rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.light?.shadowSampleCount = 8
        sun.light?.shadowRadius = 3
        sun.light?.shadowColor = UIColor(white: 0, alpha: 0.45)
        // Shadows only need to cover the stretch of track you can actually see.
        sun.light?.orthographicScale = 14
        sun.light?.zFar = 120
        sun.eulerAngles = SCNVector3(-1.05, 0.5, 0)
        sun.position = SCNVector3(6, 18, -14)
        rootNode.addChildNode(sun)
    }

    private func buildTrack() {
        rootNode.addChildNode(trackRoot)
        for index in 0..<GameConfig.segmentCount {
            let segment = TrackSegment(shaded: index % 2 == 0)
            trackRoot.addChildNode(segment.node)
            segments.append(segment)
        }
    }

    // MARK: Run lifecycle

    func reset() {
        player.reset()

        // Lay the segments out from just behind the camera to past the spawn point.
        for (index, segment) in segments.enumerated() {
            segment.node.position = SCNVector3(0, 0, 20 - Float(index) * GameConfig.segmentLength)
            segment.apply(Zone.zone(atIndex: 0))
        }
        for obstacle in obstacles {
            obstacle.despawn()
        }
        for coin in coins {
            coin.despawn()
        }
        nextSpawnDistance = GameConfig.firstSpawnDistance
        zoneIndex = 0
        lastSkyStep = Int.min
        updateEnvironment(distance: 0)
    }

    // MARK: Per-frame update

    /// What one frame of the world did to the player.
    struct FrameResult {
        var hit = false
        var coinsCollected = 0
    }

    /// Advances the world by one frame.
    func advance(dt: Float, speed: Float, distance: Float) -> FrameResult {
        let dz = speed * dt
        player.update(dt: dt)
        recycleSegments(dz: dz, distance: distance)

        var result = FrameResult()
        result.hit = advanceObstacles(dz: dz)
        result.coinsCollected = advanceCoins(dz: dz)

        spawnIfNeeded(distance: distance, speed: speed)
        updateEnvironment(distance: distance)
        zoneIndex = Zone.index(atDistance: distance)
        return result
    }

    private func advanceCoins(dz: Float) -> Int {
        var collected = 0
        for coin in coins where coin.isActive {
            coin.advance(by: dz)
            if coin.collected(by: player) {
                collected += 1
                coin.despawn()
            } else if coin.isBehind(cameraZ: cameraZ) {
                coin.despawn()
            }
        }
        return collected
    }

    private func recycleSegments(dz: Float, distance: Float) {
        let trackLength = Float(GameConfig.segmentCount) * GameConfig.segmentLength
        for segment in segments {
            segment.node.position.z += dz
            guard segment.node.position.z - GameConfig.segmentLength / 2 > cameraZ else { continue }

            segment.node.position.z -= trackLength
            // A recycled segment is re-dressed for the zone it will be met in,
            // not the one the player is standing in. It lands ~130m ahead,
            // past the fog, so the re-colouring itself is never witnessed —
            // but the resulting boundary does travel into view, which is why
            // the palette is blended across the band rather than flipped.
            let meetDistance = distance - segment.node.position.z
            let (from, to, t) = Zone.blend(atDistance: meetDistance)
            segment.apply(from: from, to: to, t: t)
        }
    }

    private func advanceObstacles(dz: Float) -> Bool {
        var hit = false
        for obstacle in obstacles where obstacle.isActive {
            obstacle.advance(by: dz)
            // Keep testing even after a hit, so the loop stays branch-free and
            // every obstacle still gets recycled this frame.
            if obstacle.hits(player: player) { hit = true }
            if obstacle.isBehind(cameraZ: cameraZ) { obstacle.despawn() }
        }
        return hit
    }

    private func spawnIfNeeded(distance: Float, speed: Float) {
        guard distance >= nextSpawnDistance else { return }

        spawnRow(distance: distance)

        // Spacing is a reaction-time budget converted to metres at the current
        // speed, so the run gets harder without becoming unreactable.
        let gap = max(GameConfig.minGapSeconds,
                      GameConfig.startGapSeconds - distance * GameConfig.gapLossPerMetre)
        nextSpawnDistance = distance + max(GameConfig.minSpacingMetres, gap * speed)
    }

    /// Blocks one or two lanes, never all three.
    private func spawnRow(distance: Float) {
        let lanes = Lane.allCases.shuffled()
        let intoDoubles = max(0, distance - GameConfig.doubleRowStartDistance)
        let doubleChance = min(GameConfig.maxDoubleChance,
                               intoDoubles / GameConfig.doubleRowRampDistance)
        let count = Float.random(in: 0..<1) < doubleChance ? 2 : 1

        // The zone picks the obstacle mix, so zones differ in what they ask of
        // you rather than only in how they look.
        let zone = Zone.zone(atDistance: distance)
        for lane in lanes.prefix(count) {
            let obstacle = dequeueObstacle()
            obstacle.spawn(kind: zone.randomObstacleKind(),
                           lane: lane,
                           z: -GameConfig.spawnDistance)
        }

        // Reward taking the open lane: the trail goes in a lane this row
        // leaves clear, just past the obstacles.
        guard let freeLane = lanes.dropFirst(count).first,
              Float.random(in: 0..<1) < GameConfig.coinTrailChance else { return }
        spawnCoinTrail(lane: freeLane)
    }

    private func spawnCoinTrail(lane: Lane) {
        let start = -GameConfig.spawnDistance + GameConfig.coinTrailOffset
        for index in 0..<GameConfig.coinTrailLength {
            let coin = dequeueCoin()
            coin.spawn(lane: lane, z: start + Float(index) * GameConfig.coinSpacing)
        }
    }

    private func dequeueCoin() -> Coin {
        if let free = coins.first(where: { !$0.isActive }) {
            return free
        }
        let coin = Coin()
        coins.append(coin)
        coinRoot.addChildNode(coin.node)
        return coin
    }

    /// Reuses a parked obstacle, growing the pool only when none is free.
    private func dequeueObstacle() -> Obstacle {
        if let free = obstacles.first(where: { !$0.isActive }) {
            return free
        }
        let obstacle = Obstacle()
        obstacles.append(obstacle)
        obstacleRoot.addChildNode(obstacle.node)
        return obstacle
    }

    // MARK: Background

    /// A vertical gradient used as the sky, rebuilt when the zone blend moves.
    private static func skyGradient(top: UIColor, mid: UIColor, bottom: UIColor) -> UIImage {
        let size = CGSize(width: 8, height: 256)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [top.cgColor, mid.cgColor, bottom.cgColor]
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors as CFArray,
                                            locations: [0, 0.55, 1]) else { return }
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }
}
