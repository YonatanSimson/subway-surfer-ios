import UIKit
import SceneKit

/// One slab of corridor: floor, two walls, and the lane divider stripes.
///
/// Holds its own materials so that recycling can re-dress the segment for a
/// new zone by assigning colours — no node-graph search and no allocation in
/// the frame loop.
final class TrackSegment {

    let node = SCNNode()

    /// Alternating segments are shaded slightly differently, which is what
    /// makes forward motion legible on an otherwise flat floor.
    private let isShaded: Bool

    private let floorMaterial = SCNMaterial()
    private let wallMaterials: [SCNMaterial]
    private let stripeMaterials: [SCNMaterial]

    init(shaded: Bool) {
        isShaded = shaded
        let length = CGFloat(GameConfig.segmentLength)

        floorMaterial.lightingModel = .physicallyBased
        floorMaterial.roughness.contents = 0.85
        let floorGeometry = SCNBox(width: CGFloat(GameConfig.corridorWidth),
                                   height: 0.4, length: length, chamferRadius: 0)
        floorGeometry.materials = [floorMaterial]
        let floor = SCNNode(geometry: floorGeometry)
        floor.position = SCNVector3(0, -0.2, 0)   // top face sits at y = 0
        node.addChildNode(floor)

        var walls: [SCNMaterial] = []
        for side in [-1, 1] {
            let material = SCNMaterial()
            material.lightingModel = .physicallyBased
            material.roughness.contents = 0.7
            let geometry = SCNBox(width: 0.3, height: CGFloat(GameConfig.wallHeight),
                                  length: length, chamferRadius: 0)
            geometry.materials = [material]
            let wall = SCNNode(geometry: geometry)
            wall.position = SCNVector3(Float(side) * GameConfig.corridorWidth / 2,
                                       GameConfig.wallHeight / 2, 0)
            node.addChildNode(wall)
            walls.append(material)
        }
        wallMaterials = walls

        // Stripes between the lanes. These are the main sense of speed.
        var stripes: [SCNMaterial] = []
        for side in [-1, 1] {
            let material = SCNMaterial()
            material.lightingModel = .constant
            let geometry = SCNBox(width: 0.06, height: 0.02,
                                  length: length * 0.9, chamferRadius: 0)
            geometry.materials = [material]
            let stripe = SCNNode(geometry: geometry)
            stripe.position = SCNVector3(Float(side) * GameConfig.laneWidth / 2, 0.01, 0)
            node.addChildNode(stripe)
            stripes.append(material)
        }
        stripeMaterials = stripes
    }

    /// Re-colours the segment for a point `t` of the way from `from` to `to`.
    ///
    /// Segments take an interpolated palette rather than one zone or the
    /// other, because a hard flip puts a crisp colour seam across the floor
    /// that is plainly visible once it travels into view. Spreading the change
    /// over the transition band turns one hard edge into several faint ones.
    func apply(from: Zone, to: Zone, t: Float) {
        floorMaterial.diffuse.contents = UIColor.lerp(
            isShaded ? from.floorDark : from.floorLight,
            isShaded ? to.floorDark : to.floorLight, t)
        let wall = UIColor.lerp(from.wall, to.wall, t)
        for material in wallMaterials {
            material.diffuse.contents = wall
        }
        let stripe = UIColor.lerp(from.stripe, to.stripe, t).withAlphaComponent(0.5)
        for material in stripeMaterials {
            material.diffuse.contents = stripe
        }
    }

    /// Settles the segment fully into one zone.
    func apply(_ zone: Zone) {
        apply(from: zone, to: zone, t: 1)
    }
}
