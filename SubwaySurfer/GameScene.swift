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

    private var segments: [SCNNode] = []
    private var obstacles: [Obstacle] = []

    /// World distance at which the next obstacle row appears.
    private var nextSpawnDistance: Float = 0

    private var cameraZ: Float { GameConfig.cameraPosition.z }

    // MARK: Setup

    override init() {
        super.init()
        buildEnvironment()
        buildCamera()
        buildLights()
        buildTrack()
        rootNode.addChildNode(obstacleRoot)
        rootNode.addChildNode(player.node)
        reset()
    }

    required init?(coder: NSCoder) {
        fatalError("GameScene is created in code, not from a scene file")
    }

    private func buildEnvironment() {
        background.contents = GameScene.skyGradient()

        // Fog does double duty: it sells depth, and it hides obstacles popping
        // in at the spawn distance.
        fogColor = UIColor(red: 0.10, green: 0.13, blue: 0.22, alpha: 1)
        fogStartDistance = CGFloat(GameConfig.spawnDistance * 0.35)
        fogEndDistance = CGFloat(GameConfig.spawnDistance * 0.95)
        fogDensityExponent = 1.4
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
            let segment = makeSegment(shade: index % 2 == 0)
            trackRoot.addChildNode(segment)
            segments.append(segment)
        }
    }

    /// One slab of corridor: floor, two walls, and the lane divider stripes.
    private func makeSegment(shade: Bool) -> SCNNode {
        let segment = SCNNode()
        let length = CGFloat(GameConfig.segmentLength)

        let floorGeometry = SCNBox(width: CGFloat(GameConfig.corridorWidth),
                                   height: 0.4,
                                   length: length,
                                   chamferRadius: 0)
        let floorMaterial = SCNMaterial()
        floorMaterial.lightingModel = .physicallyBased
        floorMaterial.diffuse.contents = shade
            ? UIColor(red: 0.20, green: 0.22, blue: 0.30, alpha: 1)
            : UIColor(red: 0.24, green: 0.26, blue: 0.35, alpha: 1)
        floorMaterial.roughness.contents = 0.85
        floorGeometry.materials = [floorMaterial]

        let floor = SCNNode(geometry: floorGeometry)
        floor.position = SCNVector3(0, -0.2, 0)   // top face sits at y = 0
        segment.addChildNode(floor)

        for side in [-1, 1] {
            let wallGeometry = SCNBox(width: 0.3,
                                      height: CGFloat(GameConfig.wallHeight),
                                      length: length,
                                      chamferRadius: 0)
            let wallMaterial = SCNMaterial()
            wallMaterial.lightingModel = .physicallyBased
            wallMaterial.diffuse.contents = UIColor(red: 0.13, green: 0.15, blue: 0.23, alpha: 1)
            wallMaterial.roughness.contents = 0.7
            wallGeometry.materials = [wallMaterial]

            let wall = SCNNode(geometry: wallGeometry)
            wall.position = SCNVector3(Float(side) * GameConfig.corridorWidth / 2,
                                       GameConfig.wallHeight / 2,
                                       0)
            segment.addChildNode(wall)
        }

        // Stripes between the lanes. These are the main sense of speed.
        for side in [-1, 1] {
            let stripeGeometry = SCNBox(width: 0.06, height: 0.02, length: length * 0.9,
                                        chamferRadius: 0)
            let stripeMaterial = SCNMaterial()
            stripeMaterial.lightingModel = .constant
            stripeMaterial.diffuse.contents = UIColor(white: 0.85, alpha: 0.5)
            stripeGeometry.materials = [stripeMaterial]

            let stripe = SCNNode(geometry: stripeGeometry)
            stripe.position = SCNVector3(Float(side) * GameConfig.laneWidth / 2, 0.01, 0)
            segment.addChildNode(stripe)
        }

        return segment
    }

    // MARK: Run lifecycle

    func reset() {
        player.reset()

        // Lay the segments out from just behind the camera to past the spawn point.
        for (index, segment) in segments.enumerated() {
            segment.position = SCNVector3(0, 0, 20 - Float(index) * GameConfig.segmentLength)
        }
        for obstacle in obstacles {
            obstacle.despawn()
        }
        nextSpawnDistance = GameConfig.startSpacing * 2
    }

    // MARK: Per-frame update

    /// Advances the world by one frame. Returns `true` if the player was hit.
    func advance(dt: Float, speed: Float, distance: Float) -> Bool {
        let dz = speed * dt
        player.update(dt: dt)
        recycleSegments(dz: dz)
        let hit = advanceObstacles(dz: dz)
        spawnIfNeeded(distance: distance)
        return hit
    }

    private func recycleSegments(dz: Float) {
        let trackLength = Float(GameConfig.segmentCount) * GameConfig.segmentLength
        for segment in segments {
            segment.position.z += dz
            if segment.position.z - GameConfig.segmentLength / 2 > cameraZ {
                segment.position.z -= trackLength
            }
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

    private func spawnIfNeeded(distance: Float) {
        guard distance >= nextSpawnDistance else { return }

        spawnRow(distance: distance)

        let spacing = max(GameConfig.minSpacing,
                          GameConfig.startSpacing - distance * GameConfig.spacingLossPerMetre)
        nextSpawnDistance = distance + spacing
    }

    /// Blocks one or two lanes, never all three.
    private func spawnRow(distance: Float) {
        let lanes = Lane.allCases.shuffled()
        let doubleChance = min(GameConfig.maxDoubleChance,
                              distance / GameConfig.doubleRowRampDistance)
        let count = Float.random(in: 0..<1) < doubleChance ? 2 : 1

        for lane in lanes.prefix(count) {
            let obstacle = dequeueObstacle()
            obstacle.spawn(kind: ObstacleKind.allCases.randomElement()!,
                           lane: lane,
                           z: -GameConfig.spawnDistance)
        }
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

    /// A vertical gradient, drawn once and used as the sky.
    private static func skyGradient() -> UIImage {
        let size = CGSize(width: 8, height: 256)
        return UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                UIColor(red: 0.06, green: 0.08, blue: 0.16, alpha: 1).cgColor,
                UIColor(red: 0.16, green: 0.22, blue: 0.38, alpha: 1).cgColor,
                UIColor(red: 0.42, green: 0.36, blue: 0.52, alpha: 1).cgColor,
            ]
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
