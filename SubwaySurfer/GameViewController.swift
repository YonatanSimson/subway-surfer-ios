import UIKit
import SceneKit

/// Hosts the `SCNView`, owns the run state (distance, speed, game over), and
/// drives the world from the render loop.
final class GameViewController: UIViewController {

    /// A swipe, recorded on the main thread and consumed by the render thread.
    private enum Input {
        case left, right, jump, slide
    }

    private static let bestScoreKey = "bestScore"

    private let sceneView = SCNView()
    private let gameScene = GameScene()
    private let hud = HUDView()
    private var gameOverView: GameOverView?
    private let collisionFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let sounds = SoundBank()

    // Run state. Only touched by the render loop while the scene is playing.
    private var distance: Float = 0
    private var speed = GameConfig.startSpeed
    private var isGameOver = false
    private var lastUpdateTime: TimeInterval?
    private var displayedScore = -1
    private var displayedZoneIndex = -1
    private var coins = 0

    // Gestures fire on the main thread but the simulation runs on the render
    // thread, so swipes are queued here instead of mutating the player directly.
    private let inputLock = NSLock()
    private var pendingInputs: [Input] = []

    // MARK: Lifecycle

    override func loadView() {
        view = sceneView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSceneView()
        configureHUD()
        configureGestures()
        startNewRun()
    }

    override var prefersStatusBarHidden: Bool { true }

    private func configureSceneView() {
        sceneView.scene = gameScene
        sceneView.delegate = self
        sceneView.backgroundColor = .black
        sceneView.antialiasingMode = .multisampling2X
        sceneView.preferredFramesPerSecond = 60
        sceneView.isUserInteractionEnabled = true
        // The world is moved by hand every frame, so the loop has to keep
        // ticking even when no SCNAction is running.
        sceneView.rendersContinuously = true
        sceneView.isPlaying = true
    }

    private func configureHUD() {
        hud.frame = sceneView.bounds
        hud.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.addSubview(hud)
        hud.update(score: 0, best: bestScore, coins: 0)
    }

    private func configureGestures() {
        let directions: [(UISwipeGestureRecognizer.Direction, Selector)] = [
            (.left, #selector(swipedLeft)),
            (.right, #selector(swipedRight)),
            (.up, #selector(swipedUp)),
            (.down, #selector(swipedDown)),
        ]
        for (direction, action) in directions {
            let recognizer = UISwipeGestureRecognizer(target: self, action: action)
            recognizer.direction = direction
            sceneView.addGestureRecognizer(recognizer)
        }
    }

    // MARK: Input

    @objc private func swipedLeft() { enqueue(.left) }
    @objc private func swipedRight() { enqueue(.right) }
    @objc private func swipedUp() { enqueue(.jump) }
    @objc private func swipedDown() { enqueue(.slide) }

    private func enqueue(_ input: Input) {
        guard !isGameOver else { return }
        inputLock.lock()
        pendingInputs.append(input)
        inputLock.unlock()
    }

    private func drainInputs() {
        inputLock.lock()
        let inputs = pendingInputs
        pendingInputs.removeAll(keepingCapacity: true)
        inputLock.unlock()

        for input in inputs {
            switch input {
            case .left:  gameScene.player.move(-1)
            case .right: gameScene.player.move(1)
            case .jump:  if gameScene.player.jump() { sounds.play(.jump) }
            case .slide: if gameScene.player.slide() { sounds.play(.slide) }
            }
        }
    }

    // MARK: Run lifecycle

    private var bestScore: Int {
        UserDefaults.standard.integer(forKey: Self.bestScoreKey)
    }

    private var score: Int { Int(distance) + coins * GameConfig.coinValue }

    /// Called on the main thread with the scene stopped, so resetting the run
    /// state can't race the simulation.
    private func startNewRun() {
        gameOverView?.removeFromSuperview()
        gameOverView = nil

        distance = 0
        speed = GameConfig.startSpeed
        displayedScore = -1
        displayedZoneIndex = -1
        coins = 0
        lastUpdateTime = nil
        isGameOver = false

        inputLock.lock()
        pendingInputs.removeAll()
        inputLock.unlock()

        gameScene.reset()
        hud.update(score: 0, best: bestScore, coins: 0)
        sceneView.isPlaying = true
    }

    private func finishRun() {
        sceneView.isPlaying = false
        collisionFeedback.impactOccurred()

        let finalScore = score
        let previousBest = bestScore
        let isNewBest = finalScore > previousBest
        if isNewBest {
            UserDefaults.standard.set(finalScore, forKey: Self.bestScoreKey)
        }

        let overlay = GameOverView(frame: sceneView.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.configure(score: finalScore,
                          best: max(finalScore, previousBest),
                          coins: coins,
                          isNewBest: isNewBest)
        overlay.onRestart = { [weak self] in self?.startNewRun() }
        overlay.alpha = 0
        sceneView.addSubview(overlay)
        gameOverView = overlay

        UIView.animate(withDuration: 0.25) { overlay.alpha = 1 }
    }

    /// Announces a new zone once, the first frame the run enters it.
    private func publishZone() {
        let index = gameScene.zoneIndex
        guard index != displayedZoneIndex else { return }
        let wasFirst = displayedZoneIndex == -1
        displayedZoneIndex = index
        guard !wasFirst else { return }   // don't announce the starting zone

        let name = gameScene.zoneName
        DispatchQueue.main.async { [weak self] in
            self?.hud.announceZone(name)
        }
    }

    private func publishScore() {
        guard score != displayedScore else { return }
        displayedScore = score
        let current = score
        let currentCoins = coins
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hud.update(score: current, best: self.bestScore, coins: currentCoins)
        }
    }
}

// MARK: - Render loop

extension GameViewController: SCNSceneRendererDelegate {

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard !isGameOver else { return }

        // The first frame has no previous timestamp to measure against.
        guard let last = lastUpdateTime else {
            lastUpdateTime = time
            return
        }
        lastUpdateTime = time

        let dt = min(Float(time - last), GameConfig.maxFrameDelta)
        guard dt > 0 else { return }

        drainInputs()

        speed = min(GameConfig.maxSpeed,
                    GameConfig.startSpeed + distance * GameConfig.speedGainPerMetre)
        distance += speed * dt

        let result = gameScene.advance(dt: dt, speed: speed, distance: distance)

        if result.coinsCollected > 0 {
            coins += result.coinsCollected
            sounds.play(.coin)
        }
        // A slide queued mid-air starts on landing, which is when it should sound.
        if gameScene.player.consumeLandingSlide() { sounds.play(.slide) }

        publishScore()
        publishZone()

        if result.hit {
            isGameOver = true
            sounds.play(.crash)
            DispatchQueue.main.async { [weak self] in self?.finishRun() }
        }
    }
}
