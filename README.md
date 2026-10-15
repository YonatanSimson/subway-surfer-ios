# Subway Runner

A Subway Surfers–style endless runner for iOS. Swift + SceneKit, no third-party
dependencies.

## Build and run

The Xcode project is **generated**, not checked in. After cloning:

```sh
brew install xcodegen      # once
xcodegen generate
open SubwaySurfer.xcodeproj
```

Simulator, from the command line:

```sh
xcodebuild -project SubwaySurfer.xcodeproj -scheme SubwaySurfer \
  -sdk iphonesimulator -destination 'id=<SIMULATOR_UDID>' build
```

### Running on a real iPhone

Device builds need a signing team, which a free Apple ID provides:

1. **Xcode → Settings → Accounts → +** and sign in with your Apple ID.
2. Put the resulting team ID in `project.yml` under `DEVELOPMENT_TEAM`, then
   re-run `xcodegen generate`. Setting it in the Xcode UI instead works, but is
   erased the next time the project is regenerated.
3. On the iPhone: **Settings → Privacy & Security → Developer Mode → on**
   (required since iOS 16; the phone reboots).
4. Select your phone in Xcode's destination menu and press Run. The first
   launch needs **Settings → General → VPN & Device Management → Trust**.

Free-account builds expire after 7 days and need a re-install.

## Controls

| Swipe | Action |
|---|---|
| Left / Right | Change lane |
| Up | Jump |
| Down | Slide (mid-air, it slams you down and slides on landing) |

Obstacles are colour-coded by what they demand: **red** barriers are jumped,
**blue** overhead bars are slid under, **purple** blocks must be gone around.
A row never blocks all three lanes.

## Architecture

| File | Responsibility |
|---|---|
| `GameViewController` | Hosts the `SCNView`, owns run state (distance, speed, game over), drives the frame loop, queues swipes |
| `GameScene` | The world: camera, lights, recycled track, obstacle pool, collision sweep |
| `Player` | The capsule, its lane, and the jump/slide state machine |
| `Obstacle` / `ObstacleKind` | One pooled obstacle and the three things an obstacle can demand |
| `Lane` | The three lane positions |
| `Collision` | Axis-aligned `Box` overlap |
| `GameConfig` | Every tunable number, so balancing is one file |
| `HUDView` / `GameOverView` | UIKit overlays on top of the `SCNView` |

### Three decisions worth knowing

**The world moves, not the player.** The player and camera sit at a fixed Z
while track segments slide toward the camera and wrap around when they fall
behind it. Float precision therefore stays constant no matter how long a run
lasts.

**Collisions are explicit box tests, not SceneKit physics.** Every node is
already moved by hand each frame, so a physics simulation would be a second
source of truth for positions. The box test is deterministic and debuggable,
and because it sweeps the Z interval the obstacle crossed during the frame
rather than testing its final position, an obstacle can never tunnel through
the player at high speed. The player's box is also inset slightly
(`collisionForgiveness`) so near-misses read as misses.

**All motion is integrated manually, not with `SCNAction`.** Lane changes and
jumps both write `node.position`; an in-flight action would fight those writes.
One owner of the transform also keeps the collision box exactly in sync with
what is drawn.

### Threading

`renderer(_:updateAtTime:)` runs on SceneKit's render thread, but gestures fire
on the main thread. Swipes are therefore queued under a lock and drained at the
top of each frame instead of mutating the player directly. Game over hands off
the other way: the render thread sets `isGameOver`, then the main thread stops
the scene before touching UI, so resetting a run can't race the simulation.

## Not done yet

- Sound effects (jump / slide / collision). Collision has haptics only.
- Coins, power-ups, rigged character models, multiple environments, Game Center.
- No app icon or launch image.
