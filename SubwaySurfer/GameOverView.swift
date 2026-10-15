import UIKit

/// Full-screen overlay shown after a collision.
final class GameOverView: UIView {

    /// Called when the player taps Run Again.
    var onRestart: (() -> Void)?

    private let scoreLabel = UILabel()
    private let bestLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.55)

        let title = UILabel()
        title.text = "GAME OVER"
        title.font = .systemFont(ofSize: 34, weight: .heavy)
        title.textColor = .white
        title.textAlignment = .center

        scoreLabel.font = .monospacedDigitSystemFont(ofSize: 64, weight: .heavy)
        scoreLabel.textColor = .white
        scoreLabel.textAlignment = .center

        bestLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        bestLabel.textColor = UIColor(white: 1, alpha: 0.8)
        bestLabel.textAlignment = .center

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Run Again"
        configuration.baseBackgroundColor = UIColor(red: 1.00, green: 0.82, blue: 0.25, alpha: 1)
        configuration.baseForegroundColor = .black
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 14, leading: 34, bottom: 14, trailing: 34
        )
        let button = UIButton(configuration: configuration)
        button.addTarget(self, action: #selector(restartTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, scoreLabel, bestLabel, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("GameOverView is created in code")
    }

    func configure(score: Int, best: Int, coins: Int, isNewBest: Bool) {
        scoreLabel.text = "\(score)"
        let bestText = isNewBest ? "NEW BEST!" : "BEST \(best)"
        bestLabel.text = coins > 0 ? "\(bestText)   ◉ \(coins)" : bestText
    }

    @objc private func restartTapped() {
        onRestart?()
    }
}
