# PiratePlunder — implementation memory

## Product contract
- Godot 4.5+, portrait Android, whimsical top-down naval arcade game.
- Four distinct ships; shared 50-level campaign path across five biomes; separate ship XP/perks.
- Endless ocean with deterministic regenerated islands, enemies, escalating danger and bosses.
- Large bottom-center wheel: drag toward a heading, ship sails automatically. Bottom left/right buttons fire their respective broadsides independently. Assisted broadsides enabled by default for one-thumb play; manual option for skill play. Desktop arrows/WASD and Q/E also work.
- Launch directly into ship cards over ocean. A ship tap opens the campaign chart. Select campaign/endless/daily, then tap a ship to launch. No conventional main menu.
- Health, combo score, pickups, damage feedback, music, cannon effects, rewarding progression, stars, tutorial, daily quests/login reward.
- Offline-first saves; optional real Google Play Games plugin integration for sign-in, snapshots, achievements and leaderboards.
- Game ID: 837392218124. OAuth client identifier is public configuration, not a secret. No signing keys, passwords, private keys or service-account credentials belong in this repository.
- Store deliverables: app icon, feature graphic, achievement/leaderboard icons and catalog, copy, actual in-engine portrait phone and tablet captures.

## Assumptions / decisions
- No monetization, ads, energy system, purchases or data-collecting analytics in the MVP.
- Ship progression grants modest automatic perks; no upgrade menu is required.
- Campaign objectives include sink, salvage, survive and boss missions, with authored waves/hazards and optional star goals.
- Each ten-level biome ends with a named boss. Failure retains earned XP/loot at a reduced rate; retry is immediate.
- Procedural terrain is deterministic by chunk coordinate. Distant simulation entities are culled; islands regenerated on demand; bounded pools keep endless mode memory stable.
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
