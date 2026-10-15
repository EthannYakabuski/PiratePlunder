# PiratePlunder — implementation memory

## Product contract
- Godot 4.5+, portrait Android, whimsical top-down naval arcade game.
- Four distinct ships; shared 50-level campaign path across five biomes; separate ship XP/perks.
- Endless ocean with deterministic regenerated islands, enemies, escalating danger and bosses.
- Large bottom-center wheel: drag toward a heading, ship sails automatically. Bottom left/right buttons manually fire their respective broadsides independently. Automatic primary fire is a purchased rank-20 capstone only. Desktop arrows/WASD and Q/E also work; unlocked grapeshot uses Z/C.
- Launch on Your Next Adventure. Choose campaign/endless/daily first, then choose one ship for that run. The opening duplicate ship chooser has been removed.
- Health, combo score, pickups, damage feedback, music, cannon effects, rewarding progression, stars, tutorial, daily quests/login reward.
- Offline-first saves; optional real Google Play Games plugin integration for sign-in, snapshots, achievements and leaderboards.
- Game ID: 837392218124. OAuth client identifier is public configuration, not a secret. No signing keys, passwords, private keys or service-account credentials belong in this repository.
- Store deliverables: app icon, feature graphic, achievement/leaderboard icons and catalog, copy, actual in-engine portrait phone and tablet captures.

## Assumptions / decisions
- No monetization, ads, energy system, real-money purchases or data-collecting analytics in the MVP. Shipyard purchases use earned in-game gold.
- Ship progression grants modest passive rank bonuses and a per-ship Shipyard tree purchased with earned gold. Extra broadside cannons unlock individually on alternating sides; separate per-side grapeshot buttons and much later auxiliary automation lead to the rank-20 primary automation capstone.
- Campaign missions use finite authored fleets, staged encounters and fixed island/hazard/supply layouts. Campaign never uses endless random spawning. Victory waits until every planned encounter and every surviving enemy is cleared. Endless and Daily Drift retain open-ocean spawning.
- Each ten-level biome ends with a named boss. Failure retains earned XP/loot at a reduced rate; retry is immediate.
- Endless procedural terrain is deterministic by chunk coordinate. Distant endless simulation entities are culled; islands regenerate on demand; bounded pools keep endless mode memory stable. Campaign fleets never use distance culling.
- Google Play Console IDs for individual achievements/boards, package identity and signing certificates are not yet supplied. Public placeholders and setup documentation will be provided, and online calls must remain disabled until configured.
- Packaging name provisionally `com.pirateplunder.game`; change before creating OAuth credentials if this is not the desired permanent package name.
- Desktop tests can verify logic/rendering/performance; physical-device touch, thermal and Google account flows require an Android device and configured backend.

## Ownership during build
- Root: project settings, gameplay, UI, tests, screenshot capture, integration and final verification.
- campaign_design: data catalogs and campaign design document.
- services_progression: persistence, Play Games adapter, plugin, progression tests/setup.
- asset_art: full asset audit, artwork, original audio, store catalog/copy.

## Validation gate
Run Godot import/parser checks, data validation, save and merge tests, automated combat/campaign/endless runs, actual render captures at phone and tablet dimensions, and an entity/performance soak. Record commands/results and remaining publishing work in docs/VALIDATION.md and README.md. Never label untested Android/cloud features as verified.

## Completed checkpoint — October 14, 2026
- Full visual/dimension/license audit of all 11 source packs; curated runtime imports preserve the original assets.
- Playable screen flow, four ships, 50 campaign missions, endless biomes, four boss attack patterns, all pickups, tutorial, daily challenge/rewards, XP/perks, health/score/audio/particles/settings.
- 28 achievement icons/catalog and four leaderboard icons/catalog; app/adaptive icons, feature graphic, copy/worksheets, 15 exact-size real Godot screenshots with provenance.
- Requested Play Games plugin v3.4.0 vendored with optional adapter, real public game ID, empty per-feature Console IDs, offline queues and conflict-safe local merging. Native automatic resolution covers routine snapshot conflicts; residual resolver and commit acknowledgement limitations documented.
- 1,124 content checks; 56 persistence/adapter checks; 81 gameplay checks; 21 UI checks.
- All 200 damage-disabled campaign combinations completed. Normal navigation bots passed all eight hardest sampled combinations; broader blind bots passed 45/52.
- Twenty-minute endless soak passed; strict enemy cap also checked by injecting 40 bosses.
- Desktop rendering improved from approximately 41 FPS to approximately 60 FPS through tiled water and particle batching. Physical Android performance is still unverified.
- Gradle debug APK and debug AAB packaging validated against API36; final artifacts live under ignored builds/. Release signing remains private owner setup.
- README and docs/VALIDATION.md are the current handoff entry points. No publication, account configuration, release-key generation, Git commit, or push was performed.

## Next work when owner resumes
Use the existing project and tests; do not restart or regenerate the source asset library. Install the APK on a real ARM64 phone, collect steering/touch/performance feedback, finish Console setup and IDs, verify cloud round trips, then sign a release AAB privately. See docs/ANDROID_BUILD.md, docs/PLAY_GAMES.md and docs/STORE_LISTING.md. Any monetization or backend addition requires revisiting privacy/store declarations.

## Gameplay revision — October 15, 2026
User confirmed the MVP works and requested A–F: chart-first launch; manual cannons; gradual extra cannons; separate upgradeable secondary fire; enemies respecting islands; fully authored finite campaign maps. These override the original automatic-fire/start-screen assumptions. Google backend work is out of scope for this round. Preserve existing player saves, ranks, gold and campaign stars. Save migration must remove legacy free automation without erasing progress. The campaign rewrite must be verified against exact fleet counts, deferred-wave victory, navigable layouts and island collisions, including enemies.

Completed revision checkpoints: 50 finite maps / 142 named encounters / 526 ships; ten distinct topology graphs per biome with rotated routes; 9,585 data/geometry checks; 165 save/upgrade checks; 285 runtime checks including all 200 manual-control campaign combinations and 12 opening missions with normal damage. All six enemy archetypes route around land. A 20-minute endless soak remains bounded. Held controls clear on pause/release. UI checks cover chart-first flow, one ship choice, purchases and automation gates; long-description wrapping is verified with the real renderer. Capture playback cannot record progression or alter tutorial status. See docs/GAMEPLAY_UPDATE.md, docs/UPGRADES.md and the regenerated docs/campaign_maps diagrams.

Additional revision observations: 16/16 damage-enabled runs of levels 20/30/40/50 with all four ships at assumed ranks 7/9/11/13 passed, using purchased eligible upgrades and no automation or immunity; 140 setup/isolation checks passed. The 200-run full matrix deliberately uses immunity to isolate navigation/completion feasibility. UI passes 28 headless / 29 native-rendered checks. Eighteen actual-size phone/tablet screenshots include the Shipyard. Desktop rendering measured approximately 60 FPS; Android touch and performance still require hardware checks.
