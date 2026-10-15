import UIKit

/// A stretch of the run with its own palette and obstacle mix, so a run at
/// 2000m neither looks nor plays like one at 200m.
///
/// Zones cycle forever; the run stays endless. The boundary between two of
/// them is invisible because segments are re-dressed only when they recycle,
/// which happens ~130m ahead of the player — well beyond the fog's reach.
/// What the player actually sees changing is the fog and sky, which blend
/// across `GameConfig.zoneTransitionLength`.
struct Zone {

    let name: String

    let floorDark: UIColor
    let floorLight: UIColor
    let wall: UIColor
    let stripe: UIColor

    let fog: UIColor
    let skyTop: UIColor
    let skyMid: UIColor
    let skyBottom: UIColor

    /// Relative likelihood of each obstacle kind. Zones differ in what they
    /// ask of you, not just how they look.
    let weights: [ObstacleKind: Float]

    // MARK: The zones

    static let all: [Zone] = [subway, city, desert, neon]

    static let subway = Zone(
        name: "SUBWAY",
        floorDark:  UIColor(red: 0.20, green: 0.22, blue: 0.30, alpha: 1),
        floorLight: UIColor(red: 0.24, green: 0.26, blue: 0.35, alpha: 1),
        wall:       UIColor(red: 0.13, green: 0.15, blue: 0.23, alpha: 1),
        stripe:     UIColor(white: 0.85, alpha: 1),
        fog:        UIColor(red: 0.10, green: 0.13, blue: 0.22, alpha: 1),
        skyTop:     UIColor(red: 0.06, green: 0.08, blue: 0.16, alpha: 1),
        skyMid:     UIColor(red: 0.16, green: 0.22, blue: 0.38, alpha: 1),
        skyBottom:  UIColor(red: 0.42, green: 0.36, blue: 0.52, alpha: 1),
        weights: [.barrier: 1.0, .overhead: 1.0, .block: 1.0]
    )

    static let city = Zone(
        name: "CITY",
        floorDark:  UIColor(red: 0.24, green: 0.21, blue: 0.24, alpha: 1),
        floorLight: UIColor(red: 0.29, green: 0.25, blue: 0.28, alpha: 1),
        wall:       UIColor(red: 0.16, green: 0.13, blue: 0.17, alpha: 1),
        stripe:     UIColor(red: 0.98, green: 0.92, blue: 0.80, alpha: 1),
        fog:        UIColor(red: 0.26, green: 0.16, blue: 0.18, alpha: 1),
        skyTop:     UIColor(red: 0.10, green: 0.07, blue: 0.14, alpha: 1),
        skyMid:     UIColor(red: 0.38, green: 0.16, blue: 0.22, alpha: 1),
        skyBottom:  UIColor(red: 0.88, green: 0.46, blue: 0.26, alpha: 1),
        weights: [.barrier: 1.0, .overhead: 1.0, .block: 1.6]
    )

    static let desert = Zone(
        name: "DESERT",
        floorDark:  UIColor(red: 0.42, green: 0.33, blue: 0.22, alpha: 1),
        floorLight: UIColor(red: 0.47, green: 0.37, blue: 0.25, alpha: 1),
        wall:       UIColor(red: 0.30, green: 0.23, blue: 0.16, alpha: 1),
        stripe:     UIColor(red: 1.00, green: 0.97, blue: 0.88, alpha: 1),
        fog:        UIColor(red: 0.54, green: 0.44, blue: 0.31, alpha: 1),
        skyTop:     UIColor(red: 0.20, green: 0.28, blue: 0.42, alpha: 1),
        skyMid:     UIColor(red: 0.56, green: 0.60, blue: 0.62, alpha: 1),
        skyBottom:  UIColor(red: 0.90, green: 0.80, blue: 0.58, alpha: 1),
        weights: [.barrier: 1.7, .overhead: 0.8, .block: 1.0]
    )

    static let neon = Zone(
        name: "NEON",
        floorDark:  UIColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1),
        floorLight: UIColor(red: 0.13, green: 0.12, blue: 0.21, alpha: 1),
        wall:       UIColor(red: 0.07, green: 0.06, blue: 0.12, alpha: 1),
        stripe:     UIColor(red: 0.40, green: 1.00, blue: 0.95, alpha: 1),
        fog:        UIColor(red: 0.14, green: 0.05, blue: 0.24, alpha: 1),
        skyTop:     UIColor(red: 0.03, green: 0.02, blue: 0.08, alpha: 1),
        skyMid:     UIColor(red: 0.22, green: 0.04, blue: 0.32, alpha: 1),
        skyBottom:  UIColor(red: 0.58, green: 0.10, blue: 0.56, alpha: 1),
        weights: [.barrier: 1.0, .overhead: 1.7, .block: 1.0]
    )

    // MARK: Lookup

    /// Index of the zone covering `distance`. Grows without bound; callers
    /// wrap it. Kept unwrapped so a change of zone is detectable by comparison.
    static func index(atDistance distance: Float) -> Int {
        max(0, Int(distance / GameConfig.zoneLength))
    }

    static func zone(atIndex index: Int) -> Zone {
        all[index % all.count]
    }

    /// The zone covering `distance`.
    static func zone(atDistance distance: Float) -> Zone {
        zone(atIndex: index(atDistance: distance))
    }

    /// The two zones the fog and sky should currently sit between, and how far
    /// the blend has run. `t == 1` means settled in `to` with nothing to blend.
    static func blend(atDistance distance: Float) -> (from: Zone, to: Zone, t: Float) {
        let index = index(atDistance: distance)
        let current = zone(atIndex: index)
        guard index > 0 else { return (current, current, 1) }

        let into = distance - Float(index) * GameConfig.zoneLength
        guard into < GameConfig.zoneTransitionLength else { return (current, current, 1) }

        return (zone(atIndex: index - 1), current, into / GameConfig.zoneTransitionLength)
    }

    /// Picks an obstacle kind according to this zone's weighting.
    func randomObstacleKind() -> ObstacleKind {
        let kinds = ObstacleKind.allCases
        let total = kinds.reduce(Float(0)) { $0 + (weights[$1] ?? 1) }
        var roll = Float.random(in: 0..<total)
        for kind in kinds {
            roll -= weights[kind] ?? 1
            if roll < 0 { return kind }
        }
        return kinds[kinds.count - 1]
    }
}

extension UIColor {
    /// Component-wise blend, for easing the fog and sky between zones.
    static func lerp(_ a: UIColor, _ b: UIColor, _ t: Float) -> UIColor {
        let t = CGFloat(min(1, max(0, t)))
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return UIColor(red: ar + (br - ar) * t,
                       green: ag + (bg - ag) * t,
                       blue: ab + (bb - ab) * t,
                       alpha: aa + (ba - aa) * t)
    }
}
