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
- AdMob on Android: adaptive home banner, ready interstitial after every third finalized voyage, one optional rewarded full-hull rescue per voyage. Google test app/unit IDs are active; production app ID is reference-only until unit IDs and account setup are provided. UMP eligibility gates requests, and required privacy choices remain accessible from Settings.

## Assumptions / decisions
- Android is ad supported as of 0.3.0. No energy system, real-money purchases or developer-operated analytics server. AdMob/UMP have third-party advertising/data practices; release privacy and Contains ads declarations must reflect them. Shipyard purchases use earned in-game gold.
- Ship progression grants modest passive rank bonuses and a per-ship Shipyard tree purchased with earned gold. Extra broadside cannons unlock individually on alternating sides; separate per-side grapeshot buttons and much later auxiliary automation lead to the rank-20 primary automation capstone.
- Campaign missions use finite authored fleets, staged encounters and fixed island/hazard/supply layouts. Campaign never uses endless random spawning. Victory waits until every planned encounter and every surviving enemy is cleared. Endless and Daily Drift retain open-ocean spawning.
- Each ten-level biome ends with a named boss. Failure retains earned XP/loot at a reduced rate; retry is immediate.
- Endless procedural terrain is deterministic by chunk coordinate. Distant endless simulation entities are culled; islands regenerate on demand; bounded pools keep endless mode memory stable. Campaign fleets never use distance culling.
- All 28 achievement IDs and four leaderboard IDs were supplied on October 17, 2026 and are populated in config, catalogs and worksheets for version 0.2.1/code 3. Console points total 975. The owner reported draft entries; credentials, tester access, publication and authenticated Android testing remain separate. Sign-in stays optional and user initiated.
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
Use the existing project and tests; do not restart or regenerate the source asset library. Install the APK on a real ARM64 phone, collect steering/touch/performance feedback, finish credentials/testers and publish the already-mapped Console entries after verification, verify cloud round trips, then sign a release AAB privately. See docs/ANDROID_BUILD.md, docs/PLAY_GAMES.md and docs/STORE_LISTING.md. Any monetization or backend addition requires revisiting privacy/store declarations.

## Gameplay revision — October 15, 2026
User confirmed the MVP works and requested A–F: chart-first launch; manual cannons; gradual extra cannons; separate upgradeable secondary fire; enemies respecting islands; fully authored finite campaign maps. These override the original automatic-fire/start-screen assumptions. Google backend work is out of scope for this round. Preserve existing player saves, ranks, gold and campaign stars. Save migration must remove legacy free automation without erasing progress. The campaign rewrite must be verified against exact fleet counts, deferred-wave victory, navigable layouts and island collisions, including enemies.

Completed revision checkpoints: 50 finite maps / 142 named encounters / 526 ships; ten distinct topology graphs per biome with rotated routes; 9,585 data/geometry checks; 165 save/upgrade checks; 285 runtime checks including all 200 manual-control campaign combinations and 12 opening missions with normal damage. All six enemy archetypes route around land. A 20-minute endless soak remains bounded. Held controls clear on pause/release. UI checks cover chart-first flow, one ship choice, purchases and automation gates; long-description wrapping is verified with the real renderer. Capture playback cannot record progression or alter tutorial status. See docs/GAMEPLAY_UPDATE.md, docs/UPGRADES.md and the regenerated docs/campaign_maps diagrams.

Additional revision observations: 16/16 damage-enabled runs of levels 20/30/40/50 with all four ships at assumed ranks 7/9/11/13 passed, using purchased eligible upgrades and no automation or immunity; 140 setup/isolation checks passed. The 200-run full matrix deliberately uses immunity to isolate navigation/completion feasibility. UI passes 28 headless / 29 native-rendered checks. Eighteen actual-size phone/tablet screenshots include the Shipyard. Desktop rendering measured approximately 60 FPS; Android touch and performance still require hardware checks.

## Console ID configuration — October 17, 2026
Owner supplied 28 achievement and four leaderboard IDs by name. Version 0.2.1/code 3 maps all 32 in `config/play_games.json`, with consistent catalog mirrors and CSV worksheets. Do not regenerate blank IDs over them. Seven changed Console point values are reflected in the worksheet and listing metadata; total 975. These public IDs are safe in the public repository. The pasted Console entries were drafts; credential/tester/publication and authenticated-device checks are still separate. Incremental types/targets and leaderboard settings were not included in the paste and should be verified in Console.

No gameplay, save schema or adapter behavior changed. Optional user-initiated sign-in remains. The updated progression/service suite passes 272 checks including an independent exact-ID fixture, all 28 achievement/four leaderboard mock submissions, absolute steps, fallback/precedence and survival milliseconds. Data validation remains 9,585 checks. See docs/PLAY_GAMES.md, docs/VALIDATION.md and docs/ANDROID_BUILD.md for final build details and limits.

`tools/build_art.py` now preserves populated IDs, existing point values keyed by local ID, and `achievement_points_source` when rebuilding worksheets. Its isolated helper check passed 22 assertions without touching actual store files or regenerating artwork.

## AdMob integration — October 17, 2026
Version 0.3.0/code 4 adds Poing 5.1.0 from the supplied local addon snapshot plus matching official Android native binaries. Vendor provenance, hashes, dependency versions, source-only patches and owner production setup are in docs/ADMOB.md. GMA Next-Gen 1.4.0 and UMP4.0.0 are the pinned SDKs. Do not substitute legacy online API examples for the actual bundled wrappers.

Authored Progression, GodotPlayGameServices, PlayServices and Ads autoloads survive editor/export startup and exit. AdMob settings registration does not rewrite the project or delete unrelated keys. Automatic iOS downloads and mediation remain disabled. The tracked helper reproduces INTERNET, ACCESS_NETWORK_STATE and AD_ID permissions and verifies JSON/project/native inputs before export. Test app ID is ca-app-pub-3940256099942544~3347511713; production reference is ca-app-pub-7719473349082950~3314995170. Test adaptive banner / interstitial / rewarded IDs end in 9214589741 / 1033173712 / 5224354917 respectively. Production unit IDs are intentionally empty. No child-directed or G-rating override is imposed; UMP privacy choices and SDK defaults remain effective.

Death pauses the same arena before finalization. A ready ad offers one optional rescue per voyage; only SDK reward plus dismissal restores full health and adds three seconds of grace. Run score/time/kills/treasure/experience-related metrics/world and damage history persist; no damage-free achievement can be fabricated. Failure or incomplete viewing finalizes once and returns to chart; unavailable inventory gives normal results. Finalized games, including ended/lost games, advance a device-local persisted every-third cadence. Revival itself does not count as another game. Missing interstitial inventory skips that boundary, with no delayed surprise popup. An incomplete/failed rewarded attempt suppresses immediately stacking an interstitial; declining the offer before watching still uses normal cadence.

Ads tests pass 78 checks, integration flow 202 assertions, existing gameplay 285 including 200/200 campaign feasibility runs and 20-minute Endless, persistence/services 272, UI 28 and data 9,585. Failed ad loads use four-attempt bursts and a 240-second cooldown, then recover without restarting; native fullscreen ads never auto-show on loading. A native privacy form closing while backgrounded leaves the visible pause menu, avoiding a frozen HUD on return. Phone/tablet internal layouts were inspected; labeled banner placeholders are QA only. Desktop renderer averages approximately 60 FPS; real Android SDK delivery/consent/reward/touch/thermal testing remains unverified. No account configuration, release signing, production requests or publication occurred. See docs/VALIDATION.md and docs/ANDROID_BUILD.md for current build evidence.
