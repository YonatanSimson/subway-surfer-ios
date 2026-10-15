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

Coin trails are laid in a lane each obstacle row leaves clear, so taking the
open lane is rewarded. Coins are worth 10 points each on top of distance.

## Zones

The run passes through SUBWAY → CITY → DESERT → NEON and loops, changing every
450m. Zones change the palette (floor, walls, stripes, fog, sky) and the
obstacle mix, so they differ in what they ask of you and not just how they look.

Two details make the change read well. Segments are re-dressed only when they
recycle, ~130m ahead and past the fog, so the re-colouring is never witnessed.
But the resulting *boundary* does travel into view, so segments take an
interpolated palette across a 90m band rather than flipping — otherwise a crisp
colour seam slides up the floor. Fog and sky are scene-global and can't be done
per segment, so they're eased against distance, with the sky image rebuilt only
when the blend moves a sixteenth.

## Difficulty

Starts easy and tightens: first obstacle 32m in, rows every 1.6s at the start
and 0.55s at the top end, speed 9.5 to 34 m/s.

Spacing is defined in **seconds of reaction time**, not metres, then multiplied
by current speed. Speed more than triples over a run, so a fixed metre gap
would stop being hard and start being impossible — 9m at 34 m/s leaves 0.26s to
react, under human reaction time. The time budget keeps the tightest gap
(0.55s) comfortably above the 0.36s a two-lane change needs.

## Sound

Effects are synthesised, not sourced:

```sh
python3 tools/make_sounds.py   # writes SubwaySurfer/Sounds/*.wav
```

Stdlib only — no numpy. Generating them avoids licence tracking, keeps the set
consistent, and makes a tweak a number in the script rather than a new
download. The audio session is `.ambient`, so the game mixes with the player's
music instead of stopping it.

## App icon

Generated, not hand-drawn:

```sh
python3 tools/make_icon.py            # rewrites the 1024px asset
python3 tools/make_icon.py --preview  # also emits 96px and 60px copies
```

A single 1024x1024 PNG goes into the asset catalog and Xcode derives the
per-device sizes. Judge any change at the preview sizes rather than at full
size — detail that reads well large turns to mush on a home screen.

`ASSETCATALOG_COMPILER_APPICON_NAME` lives in `project.yml`, not the Xcode UI,
for the same reason as `DEVELOPMENT_TEAM`: the project is regenerated.

## Architecture

| File | Responsibility |
|---|---|
| `GameViewController` | Hosts the `SCNView`, owns run state (distance, speed, game over), drives the frame loop, queues swipes |
| `GameScene` | The world: camera, lights, recycled track, obstacle and coin pools, collision sweep |
| `Zone` | A themed stretch of run: palette, obstacle weighting, and the blend between zones |
| `TrackSegment` | One slab of corridor, with its materials to hand so recycling can re-dress it |
| `Coin` | One pooled coin |
| `SoundBank` | Preloaded effects, a few voices each so repeats overlap |
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

- Power-ups, rigged character models, Game Center leaderboards.
- No launch image.
