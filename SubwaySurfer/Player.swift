import UIKit
import SceneKit

/// The runner: one capsule node, a current lane, and a small vertical
/// simulation for jumping and sliding.
///
/// All motion is integrated by hand rather than with `SCNAction`. Lane changes
/// and jumps both write to `node.position`, and an in-flight `SCNAction.move`
/// would fight those manual writes; doing both here keeps one owner of the
/// transform and keeps the collision box exactly in sync with what is drawn.
final class Player {

    enum State {
        case running
        case jumping
        case sliding
    }

    /// Positioned at the centre of the collision box; `bodyNode` hangs off it.
    let node = SCNNode()
    private let bodyNode: SCNNode

    private(set) var lane: Lane = .center
    private(set) var state: State = .running

    private var verticalVelocity: Float = 0
    private var airOffset: Float = 0
    private var slideRemaining: Float = 0
    /// Set when the player swipes down mid-air: the slide begins on landing.
    private var slideQueued = false

    /// Current height, which shrinks while sliding.
    private var height: Float {
        state == .sliding
            ? GameConfig.playerHeight * GameConfig.slideHeightFactor
            : GameConfig.playerHeight
    }

    init() {
        let capsule = SCNCapsule(capRadius: CGFloat(GameConfig.playerRadius),
                                 height: CGFloat(GameConfig.playerHeight))
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = UIColor(red: 1.00, green: 0.82, blue: 0.25, alpha: 1)
        material.roughness.contents = 0.45
        material.metalness.contents = 0.0
        capsule.materials = [material]

        bodyNode = SCNNode(geometry: capsule)
        node.addChildNode(bodyNode)
        node.castsShadow = true
        reset()
    }

    func reset() {
        lane = .center
        state = .running
        verticalVelocity = 0
        airOffset = 0
        slideRemaining = 0
        slideQueued = false
        bodyNode.scale = SCNVector3(1, 1, 1)
        node.position = SCNVector3(lane.x, GameConfig.playerHeight / 2, 0)
        node.eulerAngles = SCNVector3Zero
    }

    // MARK: Input

    func move(_ delta: Int) {
        lane = lane.shifted(by: delta)
    }

    /// Returns true if a jump actually began, so the caller knows whether to
    /// play a sound.
    @discardableResult
    func jump() -> Bool {
        guard state != .jumping else { return false }
        if state == .sliding { endSlide() }
        state = .jumping
        verticalVelocity = GameConfig.jumpVelocity
        return true
    }

    /// Returns true if a slide began now. A slam-down from mid-air reports
    /// false and the sound plays on landing instead.
    @discardableResult
    func slide() -> Bool {
        switch state {
        case .jumping:
            // Slam down and slide the moment we touch the floor.
            verticalVelocity = min(verticalVelocity, GameConfig.fastFallVelocity)
            slideQueued = true
            return false
        case .running:
            beginSlide()
            return true
        case .sliding:
            slideRemaining = GameConfig.slideDuration  // re-swiping extends the slide
            return false
        }
    }

    // MARK: Simulation

    func update(dt: Float) {
        updateHorizontal(dt: dt)
        updateSlide(dt: dt)
        updateVertical(dt: dt)
        node.position.y = height / 2 + airOffset
    }

    private func updateHorizontal(dt: Float) {
        let remaining = lane.x - node.position.x
        let step = GameConfig.laneChangeSpeed * dt
        if abs(remaining) <= step {
            node.position.x = lane.x
        } else {
            node.position.x += remaining < 0 ? -step : step
        }
        // A touch of roll into the turn, purely for feel.
        node.eulerAngles.z = -(lane.x - node.position.x) * 0.12
    }

    private func updateSlide(dt: Float) {
        guard state == .sliding else { return }
        slideRemaining -= dt
        if slideRemaining <= 0 { endSlide() }
    }

    private func updateVertical(dt: Float) {
        guard state == .jumping else { return }
        verticalVelocity += GameConfig.gravity * dt
        airOffset += verticalVelocity * dt
        guard airOffset <= 0 else { return }

        airOffset = 0
        verticalVelocity = 0
        state = .running
        if slideQueued {
            slideQueued = false
            beginSlide()
            startedSlideOnLanding = true
        }
    }

    /// Set for one frame when a queued slide fires on landing, so the view
    /// controller can play the sound it couldn't play at swipe time.
    private(set) var startedSlideOnLanding = false

    func consumeLandingSlide() -> Bool {
        defer { startedSlideOnLanding = false }
        return startedSlideOnLanding
    }

    private func beginSlide() {
        state = .sliding
        slideRemaining = GameConfig.slideDuration
        bodyNode.scale = SCNVector3(1, GameConfig.slideHeightFactor, 1)
    }

    private func endSlide() {
        state = .running
        slideRemaining = 0
        slideQueued = false
        bodyNode.scale = SCNVector3(1, 1, 1)
    }

    // MARK: Collision

    /// Slightly smaller than the drawn capsule, so grazes resolve in the
    /// player's favour.
    var collisionBox: Box {
        Box(centerX: node.position.x,
            centerY: node.position.y,
            halfWidth: GameConfig.playerRadius,
            halfHeight: height / 2)
            .insetBy(GameConfig.collisionForgiveness)
    }

    /// Half-depth along Z, used for the swept collision test.
    var halfDepth: Float { GameConfig.playerRadius }
}
