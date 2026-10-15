import UIKit

/// Score readout pinned to the top of the screen during a run.
final class HUDView: UIView {

    private let scoreLabel = UILabel()
    private let bestLabel = UILabel()
    private let zoneLabel = UILabel()
    private let coinLabel = UILabel()

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

        zoneLabel.font = .systemFont(ofSize: 20, weight: .heavy)
        zoneLabel.textColor = .white
        zoneLabel.textAlignment = .center
        zoneLabel.alpha = 0
        zoneLabel.layer.shadowColor = UIColor.black.cgColor
        zoneLabel.layer.shadowOpacity = 0.6
        zoneLabel.layer.shadowRadius = 4
        zoneLabel.layer.shadowOffset = CGSize(width: 0, height: 2)

        coinLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        coinLabel.textColor = UIColor(red: 1.00, green: 0.84, blue: 0.28, alpha: 1)
        coinLabel.textAlignment = .center
        coinLabel.layer.shadowColor = UIColor.black.cgColor
        coinLabel.layer.shadowOpacity = 0.5
        coinLabel.layer.shadowRadius = 3
        coinLabel.layer.shadowOffset = CGSize(width: 0, height: 1)

        let stack = UIStackView(arrangedSubviews: [scoreLabel, bestLabel, coinLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        zoneLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(zoneLabel)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            zoneLabel.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 18),
            zoneLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("HUDView is created in code")
    }

    func update(score: Int, best: Int, coins: Int) {
        scoreLabel.text = "\(score)"
        bestLabel.text = best > 0 ? "BEST \(best)" : " "
        coinLabel.text = coins > 0 ? "◉ \(coins)" : " "
    }

    /// Flashes the zone name, so entering a new one reads as progress rather
    /// than as the scenery randomly changing.
    func announceZone(_ name: String) {
        zoneLabel.text = name
        zoneLabel.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.4, animations: { self.zoneLabel.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.6, delay: 1.4) { self.zoneLabel.alpha = 0 }
        }
    }
}
