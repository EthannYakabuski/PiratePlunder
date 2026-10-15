# Gameplay verification and balance notes

Verified on October 14, 2026, using Godot 4.5.1 stable on Windows. The checks below exercise the actual arena simulation and authored campaign data. They do not replace touch-device playtesting.

## Automated evidence

| Check | Result |
|---|---|
| Content, resource paths, IDs, objectives, and store dimensions | 1,124 checks passed |
| Campaign feasibility matrix | 200 / 200 wins: all 50 levels with each of the four ships |
| Ordinary damage-enabled baseline bot | 45 / 52 wins across 13 representative levels and four ships |
| Steering-aware damage-enabled bot | 8 / 8 wins on levels 40 and 47 with all four ships |
| Endless Ocean | Completed 20 simulated minutes with bounded active entities |
| Core gameplay assertions | Independent cannon sides, cooldowns, simultaneous touches, steering, pause, swept collisions, shields, repairs, magnet, assisted fire, all objective types, stars, bosses, and deterministic island regeneration passed |

The campaign matrix enables `debug_invulnerable` and otherwise uses base ship statistics, ordinary movement, live enemies, cannon collisions, spawn limits, and actual objectives. It demonstrates that the data and runtime can complete every level before its deadline. It does not prove that a person can win every level or that every ship has equal difficulty.

The baseline bot uses the arena's built-in automated aiming and steering. It ignores obstacle avoidance, incoming charge paths, and tactical repair collection. Damage is enabled and base ships receive no rank bonuses. The sample levels are 1, 3, 4, 5, 10, 19, 20, 29, 30, 39, 40, 47, and 50, covering every objective type and every biome.

The steering-aware bot uses the same steering and fire inputs available to players. It adds a short look-ahead for islands, hazards, nearby enemies, and supplies. It receives no invulnerability, hull refill, damage bonus, teleport, or forced objective progress. It cleared the two difficult sample levels with every ship. This distinguishes navigation difficulty from an impossible objective.

## Completion pace

Observed medians across all 50 invulnerable campaign runs per ship:

| Ship | Median finish | Longest finish |
|---|---:|---:|
| Swiftfin | 42.5s | 120.0s |
| Ironclad | 41.6s | 120.0s |
| Redwake | 41.1s | 120.0s |
| Golden Gull | 41.2s | 120.0s |

Combat and treasure stages generally finish faster than the original 60–120-second authoring target. Survival stages supply the longer sessions, ranging from 50 to 120 seconds. Bosses in the representative base-stat runs typically finish in approximately 12–30 seconds once the bot maintains effective broadsides.

An early treasure magnet can sweep a large initial treasure field and finish a coin stage in roughly 2 seconds. This is an intentional powerup interaction, but its pacing deserves phone playtesting. If it repeatedly makes treasure missions feel trivial, spread initial coins farther apart, reduce the magnet's 750-unit sweep, or raise the later coin targets. Avoid adding a forced minimum session length.

## Skill-sensitive stages

The baseline bot's seven defeats occurred only on:

- Level 40, Baron Blizzard: Swiftfin, Ironclad, and Golden Gull. Redwake won. Charging boss contact and iceberg navigation punish blind circling.
- Level 47, The Sea Bites Back: all four ships. This is a 120-second survival challenge with mixed enemies, whirlpools, and a storm.

The steering-aware bot won all eight ship/stage combinations. Its level 40 wins took 19.9–28.3 seconds with 39–100% hull remaining. All level 47 wins lasted the required 120 seconds with 99–100% hull remaining. Escaping pressure and choosing open water are strong survival strategies.

These findings support a rewarding steering skill curve. They also identify the next manual test focus: make charge and storm danger readable enough for a first-time player, and verify that the central wheel permits the needed turns comfortably with one thumb. Ship ranks earned before later biomes should add additional forgiveness.

## Simulation bounds and performance limits

An active, firing bot completed 20 minutes of Endless Ocean at a 0.05-second simulation step. One verified run observed:

| Entity type | Peak observed | Runtime limit / policy |
|---|---:|---|
| Enemies | 14 | Configured endless cap 14; boss replacement behavior should preserve the cap |
| Cannonballs | 32 | 220 |
| Particles | 163 | 320 |
| Pickups | 70 | 70 |
| Cached island chunks | 39 | Cache prunes distant chunks after approximately 100 entries |

That simulation took approximately 5.17 seconds of wall time for 1,200 seconds of game time, averaging about 0.22ms per simulation step on this desktop. The complete original 200-case campaign matrix, 28 baseline samples, primitive assertions, and endless run took 48.6 seconds. Expanded baseline samples and navigation checks were verified separately.

Headless timing measures CPU simulation without normal rendering, audio output, Android thermals, or real touch input. It is not a mobile frame-rate measurement. Before publishing, profile a physical mid-range Android phone for at least 15–20 minutes, inspect frame time and memory, verify audio latency, and check that backgrounding/resuming preserves the current voyage and save.

The active bot kills enemies and bosses. A non-firing stationary stress case is a useful follow-up when changing spawn rules, because periodic boss spawns must not bypass the configured concurrent-entity cap. Projectile and particle limits remain enforced independently.

## Reproducing the checks

From the project directory, with a Godot 4.5 executable:

```powershell
python tools/validate_data.py
godot --headless --path . --script res://tests/test_game.gd --log-file C:/absolute/project/tests/game-test.log
```

Use an absolute log-file path on Windows. The test script delays loading the arena until autoload registration completes, redirects progression writes to `res://tests/.game-suite-save.json`, resets the test's in-memory progression, and never records these simulated voyages to the player's save. It removes its own temporary save files afterward.

Optional arguments after `--`:

- `--quick`: nine campaign levels per ship, alongside the other checks.
- `--normal-only`: primitive assertions, the 52 damage-enabled baseline samples, and navigation samples.
- `--navigation-only`: primitive assertions plus the eight hard-stage navigation samples.

The default suite now includes all 200 campaign cases, 52 baseline observations, eight asserted navigation cases, and the 20-minute endless simulation. Baseline bot defeats are reported as balance observations; a failure of the control, combat, objective, bounds, campaign feasibility, or navigation assertions exits with a non-zero result.

The environment may print a Windows root-certificate-store warning while running the engine headlessly. Gameplay tests run offline. These checks do not validate Android OAuth, Play Games sign-in, cloud snapshots, or a real Play Console leaderboard submission.

## Content fields and final policies

The runtime consumes authored enemy combat statistics, drops, and score, and named boss health, speed, damage, cooldown, cannon count, and attack pattern. Fan bosses add two spread projectiles to the base cannon count. Level pools, timed waves, objectives, hazards, supply cadence, and palettes provide the 50 distinct stage configurations.

`design_note`, `spawn_pattern`, music moods, per-enemy XP, exact authoring collision radii, and the powerup selection list are descriptive or reference tuning. Runtime policies govern XP, collision sizes, and the four available supplies. Every catalog boss currently uses an eight-second arrival and every treasure unit has value one, matching the implemented behavior.

Campaign clear rewards are paid once per shared level. Collected treasure and battle XP remain available on every voyage. Golden Gull's coin multiplier applies to account rewards after a voyage; the on-screen objective counter counts actual pickups. Daily reward keys use UTC dates consistently across installations.

