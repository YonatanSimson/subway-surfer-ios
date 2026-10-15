import UIKit

/// Score readout pinned to the top of the screen during a run.
final class HUDView: UIView {

    private let scoreLabel = UILabel()
    private let bestLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false

        scoreLabel.font = .monospacedDigitSystemFont(ofSize: 44, weight: .heavy)
        scoreLabel.textColor = .white
        scoreLabel.textAlignment = .center
        scoreLabel.layer.shadowColor = UIColor.black.cgColor
        scoreLabel.layer.shadowOpacity = 0.5
        scoreLabel.layer.shadowRadius = 4
        scoreLabel.layer.shadowOffset = CGSize(width: 0, height: 2)

        bestLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        bestLabel.textColor = UIColor(white: 1, alpha: 0.7)
        bestLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [scoreLabel, bestLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("HUDView is created in code")
    }

    func update(score: Int, best: Int) {
        scoreLabel.text = "\(score)"
        bestLabel.text = best > 0 ? "BEST \(best)" : " "
    }
}
