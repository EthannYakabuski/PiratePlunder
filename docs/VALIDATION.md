# Validation record

Verified October 14, 2026 with Godot 4.5.1 on Windows. The project is playable offline. This document distinguishes tested behavior from publishing work that needs devices/accounts.

## Content and mechanics

`tools/validate_data.py` passed **1,124 checks**: exactly 50 uniquely authored levels, five groups of ten, valid objective/enemy/wave/hazard/ship references, four ships, 28 achievements, four boards, and artwork dimension checks. Every provided bitmap decoded successfully during the full asset audit.

`tests/test_game.gd` passed **81 gameplay checks** and completed **200/200 campaign combinations** (50 levels × four ships) using ordinary steering/fire input with damage disabled for objective feasibility. The suite also checks independent cannon reloads and side targeting, held touch/pointer behavior, automatic fire, projectile impacts, pickups, all objective types, authored boss stats/attacks, storm safe periods, supply behavior, and deterministic terrain.

Damage-enabled baseline bots won **45/52** sampled missions. Steering bots that avoid terrain/hazards subsequently won **8/8** difficult stage40/stage47 combinations without invulnerability. These are useful feasibility and regression checks; human playtesting is still required to judge one-thumb comfort and difficulty. [Detailed balance results](BALANCE.md).

The **20-minute endless simulation** stayed within its configured entity limits: observed peaks were 14 enemies, 33 bullets, 156 particles, 70 pickups, and 42 cached terrain entries. The timed-boss path additionally replaces an existing rival when necessary, so even a non-firing run cannot accumulate enemies past the hard 14 cap. Projectiles cap at 220, particles at 320, pickups at 70; distant enemies/pickups are culled and terrain entries are pruned. The final desktop simulation completed in about 5.50 seconds of wall time, which measures accelerated simulation throughput, not an Android frame rate.

## Persistence and screen flow

`tests/test_progression.gd` passed **56 checks** covering save/reload, checksum and backup recovery, progression across all50 levels, separate ship XP, stars, deterministic daily quests, duplicate reward/run protection, malformed cloud data, merge convergence/idempotence, and mocked online queues/acknowledgements. It also verifies empty Google IDs produce no submissions, incremental totals are absolute, survival scores use milliseconds, and daily wins do not unlock campaign levels.

`tests/test_ui.gd` passed **21 checks**: initial ship cards, shared chart, locked progression, run ship selection, additive rank bonuses, pause, results, recording once, hiding previous arenas, campaign/endless/daily launch, logbook/settings, restored automatic-fire preference, and an adversarial 40-boss spawn verifying the endless cap. Test profiles use repository-local temporary saves and are cleaned up.

Godot import and script parsing completed. The sandbox prevents writing desktop editor settings/shader caches outside the workspace and cannot read the Windows certificate store; those environment messages were distinguished from script/resource errors. Offline scenes and captures render successfully.

## Actual desktop rendering

`tests/test_render.gd` runs a damage-disabled late-endless stress scene with14 rivals and active effects through the real OpenGL Compatibility renderer at540×960. It measures600 frames after warmup, with a60FPS cap, on an NVIDIA GeForce GT1030.

| Measurement | Before optimization | Final measurement |
| --- | ---: | ---: |
| Average frame | 24.10ms (~41.5FPS) | 16.67ms (~60FPS) |
| 95th-percentile frame | 28.97ms | 16.74ms |
| Peak draw calls | 1,128 | 456 |
| Peak static engine memory | 51.41MiB | 51.62MiB |

The ocean now uses a single tiled texture; effects share a particle texture and skip hidden/out-of-view particles. The final stress run peaked at 232 active simulation entities. Worst measured frame was 17.53ms. The engine process monitor's 95th-percentile sample was 17.43ms and is reported separately from measured frame intervals because that monitor uses a different sampling window. Android hardware has not been benchmarked.

## Android artifacts

The Gradle debug APK and debug AAB packaging paths succeeded. Build verification checks package/version, API24 minimum/API36 target, portrait orientation, permissions, Play Games plugin classes and the supplied game ID, bundled campaign data, architecture, signature/zip alignment where applicable, and16KB native segment alignment. [Exact artifact details and signing limitations](ANDROID_BUILD.md).

No Android device was connected. Only an old x86 emulator system image was available while the APK targets ARM64; no matching emulator/physical run is represented as tested. Touch ergonomics, multi-touch, safe areas, audio focus, temperature, battery use, and sustained phone frame rates require hardware testing.

## Store capture provenance

`tools/capture_viewport.gd` renders the real main scene into an exact-size SubViewport. This avoids Windows shrinking portrait windows to fit the desktop. The capture script writes1080×1920 phone,1200×1920 7-inch tablet, and1600×2560 10-inch tablet images, showing ships, chart, combat, boss, and logbook. Screenshot dimensions label intended device classes, not a claim that those physical devices were used.

Combat captures use reproducible in-engine enemy placement and ordinary simulation before freezing a frame. They do not invent score/UI or resize a desktop screenshot. Opaque alpha is removed when converting to store-ready RGB without changing rendered pixels. `store/screenshots/manifest.json` records sizes, hashes, state, and provenance. Recapture the final signed Android build before release.

## Remaining release checks

- Configure actual Play Games achievement/board IDs, package/certificate credentials, test accounts, and owner permissions; test authenticated sign-in/submission and cross-device cloud round trips.
- Address or verify the pinned plugin's residual-conflict resolver and optimistic native commit-acknowledgement limitations described in [PLAY_GAMES.md](PLAY_GAMES.md).
- Sign a release AAB privately, increment version code, run Play pre-launch/native compatibility checks, and validate Android16/large-screen behavior.
- Complete human/device QA, support/privacy/Console declarations, final Android screenshots, and required testing tracks.

These are publishing dependencies, not completed cloud/device tests.
