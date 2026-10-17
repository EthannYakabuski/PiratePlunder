# Validation record

## Play Games IDs — October 17, 2026, version 0.2.1

All 28 achievement IDs and four leaderboard IDs supplied by the owner are mapped by local catalog key in `config/play_games.json`, mirrored in their catalog `google_play_id` fields and setup CSVs. All 32 IDs are unique. Seven point-value changes in the Console list bring the achievement worksheet total to **975**. The Android presets now use version **0.2.1 / code 3**. No gameplay, native plugin, authentication preference or save-schema change was required.

`tests/test_progression.gd` passed **272 checks with zero failures**. An independent fixture contains the exact owner-provided IDs. Tests exercise every configuration/catalog mapping, map precedence, catalog fallback and a complete mock dispatch of 17 incremental achievements, 11 standard achievements and four leaderboards. Incremental requests use exact absolute targets; the survival score converts 300.25 seconds to 300250 milliseconds. Existing blank-ID, offline queue, retry/acknowledgement, save migration and Shipyard tests remain passing. Test profiles are isolated and restored; no real Google request is made.

`tools/validate_data.py` also passed **9,585 checks with zero failures**. Existing campaign/runtime/rendering evidence below remains applicable because this update changes public IDs and packaging metadata only. Final APK/AAB sizes, hashes and packaged-ID checks are recorded in [ANDROID_BUILD.md](ANDROID_BUILD.md).

The artwork worksheet generator now preserves configured IDs, per-local-ID Console point edits and their metadata source. A helper-only isolated fixture passed **22 checks**, including all 32 IDs, the 975-point allocation, reordered catalogs, edited points, configuration priority and catalog fallback. No artwork was regenerated and actual store files remained unchanged during this check.

The owner's pasted Console list reports draft entries and does not include their incremental type/step or leaderboard format settings. Credentials, authorized account sign-in, Console settings/publication and live Android submissions have not been verified by these offline checks.

## Gameplay 0.2.0 — October 15, 2026

Verified using Godot 4.5.1 on Windows. This record covers the chart-first launch, manual weapons and Shipyard progression, shared island collision/navigation, and replacement of the entire campaign with finite authored encounters. Google configuration and authenticated service testing are outside this revision.

## Campaign data and geography

`tools/validate_data.py`: **9,585 checks, zero failures**. The campaign contains exactly **50 levels, 142 named encounter groups and 526 authored ships**. Each biome includes ten distinct obstacle graphs, with different approach directions and ship formations. The format identifier is `finite_authored_fleets_v2`, topology revision 3; the outer JSON schema remains version 1.

Checks include exact objective/fleet totals, globally unique ship/encounter IDs, explicit ship kinds and positions, bounds, island/entity/hazard clearance, supplies in reachable water, patrol positions, bosses appearing exactly once in their final encounter, and physical map uniqueness ignoring names/IDs. A 32-unit flood-fill grid inflated by 48 units verifies routes. Negative fixtures deliberately create overlapping ships, wrong counts, duplicate geometry and a sealed basin to prove the validator rejects invalid layouts.

[Map diagrams](campaign_maps/) are generated directly from the data using `tools/preview_campaign.py`. They show the actual start, islands, supplies, hazards and staged formations.

## Runtime campaign and manual weapons

`tests/test_game.gd`: **285 checks, zero failures**.

- **200/200** combinations of 50 missions × four base ships completed using a steering/manual-fire test driver. Damage immunity is enabled for this exhaustive objective/navigation feasibility sweep. Automation capabilities remain locked; no automatic primary firing is granted. Every result verifies authored total = deployed total = sunk total.
- **12/12** opening missions (levels 1–3 × four ships) completed with normal hull damage and no immunity.
- Director tests verify exact finite spawn types/positions, inter-encounter delays, no random campaign ships or procedural land, no distance-based deletion of campaign enemies, no timer-based campaign victory, and no premature victory with a surviving enemy or future encounter.
- Weapon tests verify no unearned firing even with a legacy `auto_fire` setting or directly set assistance flag, independent primary reloads, asymmetric cannon counts, separate per-side grapeshot buttons/reloads, locked secondary controls, and purchased auxiliary/primary automation gates.
- Actual input-release tests verify held cannon/secondary pointers clear when UI consumes a release and when pausing. Resuming cannot leave a phantom held-fire command.
- Collision/navigation stress covers all six enemy kinds crossing a route blocked by an island: they progress around the land, never overlap solid land, and remain within the authored boundaries. Swept movement and projectiles cannot tunnel through an island.

## Damage-enabled mid/late-game observations

`tests/test_balance.gd`: **16/16 wins**, with **140 setup/isolation assertions** passing. Each of four ships plays levels 20, 30, 40 and 50 at ranks 7, 9, 11 and 13 respectively, buying only rank-eligible upgrades through the actual purchase API. No immunity, automation or forced mission completion is used. Clear times were 12.85–20.7 seconds with 54.2–100% hull remaining. These are skilled bot observations, not a prediction of human comfort or difficulty. [Detailed hull/time/loadout table](BALANCE.md).

## Persistence, migration and upgrades

`tests/test_progression.gd`: **165 checks, zero failures**. Existing checksum/backup recovery, shared campaign stars, separate XP, daily rewards and service-queue tests remain passing. New tests cover every upgrade rank threshold/prerequisite, single-cannon increments on only one side, per-ship purchases, separate secondary/automation gates, rank-20 Master Gunner, insufficient funds, duplicate purchases, immediate persistence, failed-save rollback and version-2 migration preserving earned progress.

Cloud-data merge tests exercise receipts, repeated and stale merges, duplicate purchases on different devices and concurrent spending settlement. These verify local merge logic without authenticating against Google. No backend settings were changed.

## Screens and rendering

`tests/test_ui.gd`: **28 headless checks / 29 checks with the real renderer**, zero failures. It verifies chart-first launch, a single ship choice after selecting a voyage, loadout stats, locked automation in pause/settings, Shipyard purchases, individual-side increments, gold updates, daily/endless compatibility, logbook/settings, and screenshot playback never recording progress. Native rendering additionally verifies long upgrade descriptions wrap inside their cards.

Reviewed phone/tablet captures of the chart, ship chooser, manual combat, boss, logbook and Shipyard. An isolated rank-11 test profile in `tests/render_arsenal.gd` verifies both grapeshot controls visually without modifying a real save.

The actual GL Compatibility stress benchmark (`tests/test_render.gd`) ran 600 measured frames after warmup at 540×960, capped at 60 FPS, on an NVIDIA GeForce GT 1030:

| Measurement | Result |
| --- | ---: |
| Average frame interval | 16.668 ms (approximately 60 FPS) |
| 95th percentile | 16.776 ms |
| Worst measured frame | 19.411 ms |
| Peak draw calls | 442 |
| Peak static engine memory | 63.20 MiB |
| Peak active simulation entities | 196 |

The engine process monitor's separate 95th-percentile sample was 19.325 ms. This is a Windows rendering measurement, not an Android hardware benchmark.

## Endless and Daily Drift regression checks

The full **20-minute endless simulation** remains active and bounded: observed peaks were 14 enemies, 26 bullets, 195 particles, 68 pickups, 61 island entries and 29 geometry-cache entries. Hard limits are 14 enemies, 220 bullets, 320 particles and 70 pickups. Terrain and navigation caches are pruned. The 90-second Daily Drift challenge also completes independently of finite campaign rules.

## Android artifacts and capture provenance

Export presets use version **0.2.0 / code 2**, preserving package and debug signing identity so an existing installation can be updated. [ANDROID_BUILD.md](ANDROID_BUILD.md) records the final APK/AAB, hashes and packaging checks. The APK is the installable debug build; the unsigned debug AAB is a packaging preview.

There are **18 actual Godot screenshots**, six states for each of phone 1080×1920, 7-inch tablet 1200×1920 and 10-inch tablet 1600×2560. A SubViewport renders at the exact size, avoiding desktop window clamping. Combat/boss images play the authored encounter with a manual-input test driver before freezing a genuine frame; they insert no ships, land or supplies. Screenshot playback bypasses progression writes. The real profile save timestamp was checked during capture and remained unchanged.

`store/screenshots/manifest.json` records dimensions, SHA-256 hashes and provenance. The only conversion removes an opaque alpha channel for store-ready RGB; no resizing, invented UI, score replacement or device-frame composition is performed. These are desktop game renders and do not claim physical phone/tablet testing.

## Remaining practical checks

Install the updated APK on an ARM64 Android device, confirm existing progress and manual control feel, and test simultaneous touches, safe areas, background/resume, sound focus, temperature/battery behavior and sustained frame rate. Human feedback should guide future difficulty and Shipyard-price tuning. The sandbox's Windows certificate-store warning did not prevent offline logic or rendering; no game script/resource errors remain in the passing suites.

Google credentials/IDs, authenticated cloud round trips, private release signing, final Android screenshots and Play Console submission remain the separate owner publishing work described in the setup documents.
