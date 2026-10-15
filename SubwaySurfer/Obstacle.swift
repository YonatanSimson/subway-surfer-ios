import UIKit
import SceneKit

/// What the player has to do about an obstacle. The three kinds exist so that
/// all four swipes matter: jump, slide, or sidestep.
enum ObstacleKind: CaseIterable {
    /// Low barrier — jump it.
    case barrier
    /// Overhead bar with a gap underneath — slide it.
    case overhead
    /// Full-height block — go around it.
    case block

    var size: SCNVector3 {
        switch self {
        case .barrier:  return SCNVector3(GameConfig.laneWidth * 0.9, 0.55, 0.6)
        case .overhead: return SCNVector3(GameConfig.laneWidth * 0.9, 1.20, 0.6)
        case .block:    return SCNVector3(GameConfig.laneWidth * 0.9, 2.00, 0.6)
        }
    }

    /// Height of the box's centre above the floor.
    var centerY: Float {
        switch self {
        case .barrier:  return size.y / 2
        // Clears a sliding player (0.63 high) but not a standing one (1.40).
        case .overhead: return 0.72 + size.y / 2
        case .block:    return size.y / 2
        }
    }

    var color: UIColor {
        switch self {
        case .barrier:  return UIColor(red: 0.95, green: 0.35, blue: 0.30, alpha: 1)
        case .overhead: return UIColor(red: 0.35, green: 0.70, blue: 0.95, alpha: 1)
        case .block:    return UIColor(red: 0.62, green: 0.40, blue: 0.85, alpha: 1)
        }
    }
}

/// One pooled obstacle. Nodes are never thrown away — they are parked
/// (`isActive == false`, hidden) and re-dressed on the next spawn.
final class Obstacle {

    let node = SCNNode()
    private(set) var isActive = false
    private var kind: ObstacleKind = .barrier
    /// Z position at the start of the current frame, for the swept test.
    private var previousZ: Float = 0

    init() {
        node.isHidden = true
        node.castsShadow = true
    }

    func spawn(kind: ObstacleKind, lane: Lane, z: Float) {
        self.kind = kind
        let size = kind.size
        let box = SCNBox(width: CGFloat(size.x),
                         height: CGFloat(size.y),
                         length: CGFloat(size.z),
                         chamferRadius: 0.04)
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = kind.color
        material.roughness.contents = 0.5
        box.materials = [material]

        node.geometry = box
        node.position = SCNVector3(lane.x, kind.centerY, z)
        node.isHidden = false
        previousZ = z
        isActive = true
    }

    func despawn() {
        isActive = false
        node.isHidden = true
        node.geometry = nil
    }

    /// Moves the obstacle toward the camera by `dz`, remembering where it was.
    func advance(by dz: Float) {
        previousZ = node.position.z
        node.position.z += dz
    }

    /// True once the obstacle is fully behind the camera.
    func isBehind(cameraZ: Float) -> Bool {
        node.position.z - kind.size.z / 2 > cameraZ
    }

    /// Swept collision test against the player.
    ///
    /// The player sits at z = 0 and obstacles only ever move in +Z, so the
    /// frame's Z sweep overlapped the player exactly when the interval
    /// [previousZ, currentZ] crosses the player's depth. Testing the interval
    /// rather than the final position means no obstacle can skip past the
    /// player in a single frame, however fast the run gets.
    func hits(player: Player) -> Bool {
        guard isActive else { return false }

        let depth = player.halfDepth + kind.size.z / 2
        let sweptThroughPlayer = previousZ <= depth && node.position.z >= -depth
        guard sweptThroughPlayer else { return false }

        let size = kind.size
        let box = Box(centerX: node.position.x,
                      centerY: node.position.y,
                      halfWidth: size.x / 2,
                      halfHeight: size.y / 2)
        return box.overlapsInXY(player.collisionBox)
    }
}
