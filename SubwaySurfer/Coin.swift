import UIKit
import SceneKit

/// A collectable coin. Pooled and swept-tested exactly like `Obstacle` — the
/// only difference is what collision means.
final class Coin {

    static let radius: Float = 0.24
    static let thickness: Float = 0.06
    /// Sits at chest height: reachable while running, and still on the way
    /// through a jump arc.
    static let centerY: Float = 1.00

    let node = SCNNode()
    private(set) var isActive = false
    private var previousZ: Float = 0

    init() {
        let geometry = SCNCylinder(radius: CGFloat(Coin.radius),
                                   height: CGFloat(Coin.thickness))
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 1.00, green: 0.84, blue: 0.28, alpha: 1)
        material.metalness.contents = 0.9
        material.roughness.contents = 0.25
        // A little self-illumination so coins stay readable in the dark zones.
        material.emission.contents = UIColor(red: 0.35, green: 0.26, blue: 0.04, alpha: 1)
        geometry.materials = [material]

        let face = SCNNode(geometry: geometry)
        // Lay the cylinder face-on to the camera.
        face.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        node.addChildNode(face)

        // Spin for readability. Rotation is a different property from the
        // position this class writes each frame, so the action can't fight it.
        node.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 1.6)))
        node.isHidden = true
    }

    func spawn(lane: Lane, z: Float) {
        node.position = SCNVector3(lane.x, Coin.centerY, z)
        node.isHidden = false
        previousZ = z
        isActive = true
    }

    func despawn() {
        isActive = false
        node.isHidden = true
    }

    func advance(by dz: Float) {
        previousZ = node.position.z
        node.position.z += dz
    }

    func isBehind(cameraZ: Float) -> Bool {
        node.position.z - Coin.radius > cameraZ
    }

    /// Same swept-Z reasoning as `Obstacle.hits`, with a slightly generous box
    /// so coins feel magnetic rather than finicky.
    func collected(by player: Player) -> Bool {
        guard isActive else { return false }

        let depth = player.halfDepth + Coin.thickness / 2 + 0.25
        guard previousZ <= depth && node.position.z >= -depth else { return false }

        let box = Box(centerX: node.position.x,
                      centerY: Coin.centerY,
                      halfWidth: Coin.radius + 0.18,
                      halfHeight: Coin.radius + 0.18)
        return box.overlapsInXY(player.collisionBox)
    }
}
