# Google Play Games setup

PiratePlunder is playable offline. Campaign unlocks, best stars, ship XP, achievements, personal records, login rewards, daily quests, and settings save locally. The Android build optionally connects to Google Play Games. Desktop builds show local achievements and personal records without requiring Google services.

## Included integration

The requested [Godot Play Game Services plugin](https://github.com/godot-sdk-integrations/godot-play-game-services) is vendored at `addons/GodotPlayGameServices`, including its MIT license and debug/release Android libraries. The pinned release is [v3.4.0](https://github.com/godot-sdk-integrations/godot-play-game-services/releases/tag/v3.4.0), downloaded October 14, 2026. The addon editor plugin is enabled, and its exact autoload name is `GodotPlayGameServices`.

`scripts/play_services.gd` initializes the plugin on Android, creates the upstream `PlayGamesSignInClient`, `PlayGamesAchievementsClient`, `PlayGamesLeaderboardsClient`, and `PlayGamesSnapshotsClient` nodes, and connects their documented signals. Sign-in is optional and user initiated by default. This adapter uses no server authorization requests, authorization tokens or client secrets. Android advertising and UMP privacy handling are provided separately by the [AdMob integration](ADMOB.md) as of version 0.3.0; no billing SDK or developer-operated analytics server was added.

Public configuration lives in `config/play_games.json`:

- Game ID: `837392218124`.
- Supplied OAuth client ID: `837392218124-oibe2ur3hterj4miav8s99s1dimkg0ff.apps.googleusercontent.com`.
- Snapshot: `pirateplunder_progress_v2`.
- Achievement and leaderboard mappings: all 28 achievement IDs and four leaderboard IDs supplied by the owner on October 17, 2026 are populated. The data catalogs and CSV worksheets mirror the canonical configuration maps.

Version **0.2.1 / code 3** includes these public IDs. The pasted Console entries were drafts; mapping them into the app does not publish them or prove account-authorized operation. The worksheet point values now match the Console's **975 total points**. Incremental targets, leaderboard score formats and gameplay triggers are unchanged.

The client ID is recorded for your setup reference. Client-only Android sign-in is authorized through the package name, signing certificate, and game ID. A web/server client ID is only required for a server authorization flow, which this game does not use. [Google setup guide](https://developer.android.com/games/pgs/console/setup).

## Configure your game project

1. Link the Android application to the existing Play Games project. The provisional package is `com.pirateplunder.game`; confirm it before your first publication.
2. Create/link Android OAuth credentials for the package and SHA-1 certificate of your debug build, your release upload build, and the certificate used by Play App Signing. Register the applicable testing accounts in Play Games and, if required, the OAuth consent screen.
3. Keep Saved Games enabled. Confirm the consent configuration includes the scopes required by Google's setup guidance. Allow time for configuration changes to propagate.
4. The 28 achievements have been created and mapped. Verify their Console type, visibility and incremental targets against `data/achievements.json` and `store/achievement_setup.csv`; the owner's pasted list contained IDs and points but not type/step settings. Incremental achievement step totals must exactly match each JSON `target`.
5. The four leaderboards have been created and mapped in `data/leaderboards.json`, `store/leaderboard_setup.csv` and configuration. Verify all use descending order. The survival board uses **time in milliseconds**, and the adapter multiplies seconds by 1,000.
6. Keep canonical `achievement_ids` / `leaderboard_ids` in `config/play_games.json` consistent with each catalog's `google_play_id` and its worksheet if recreating a Console entry. Local slugs such as `sea_legs` are not Google IDs. Configuration mappings take precedence over catalog fallbacks.
7. Export an Android debug build using Gradle and game ID `837392218124`, then test with an authorized account before enabling automatic authentication.

These are configuration instructions, not changes made to your Google account. The backend and account authorization cannot be verified until you configure them. [Google credentials and testers](https://developer.android.com/games/pgs/console/setup), [Saved Games overview](https://developer.android.com/games/pgs/savedgames), [upstream Android export configuration](https://github.com/godot-sdk-integrations/godot-play-game-services#configuring-the-plugin).

## Offline queues and save merge

Every result updates local progression before any network request. Achievement queues store absolute steps; the adapter calls `set_achievement_steps`, avoiding duplicated increments after retries. Normal achievements call `unlock_achievement`. Leaderboard queues retain best scores and are removed only when the plugin acknowledges submission. Empty remote IDs are retained locally until configured.

Every cloud upload first reads the current snapshot and merges it with the local state. Ship XP and lifetime run counters use per-installation counters merged by maximum, then summed. Stars, completed levels, best scores, and achievement unlocks never move backwards. Daily and first-clear rewards have globally unique event keys, so reconnecting or claiming on two devices cannot pay twice. Installation identity and delivery queues stay local. Newer setting preferences replace older preferences; on equal timestamps, the current device's preferences win.

Login rewards and daily quest rotations use **UTC dates**. A day's three quests are deterministic across devices. Claims grant gold and XP to the selected ship. First-clear rewards belong to the shared campaign level, while replaying still earns ordinary run XP and collected treasure. Shipyard upgrades spend earned gold; there is no energy system or real-money purchasing.

Local saves use a SHA-256 checksum, a temporary file, and a verified backup. This detects accidental corruption; it is not an anti-cheat or encryption feature. A corrupted primary file recovers the backup. A future incompatible cloud version is left untouched rather than overwritten.

## Upstream limitations to validate before publication

The native bridge already asks Google to resolve routine conflicts automatically: loading uses `RESOLUTION_POLICY_MOST_RECENTLY_MODIFIED`, and saving uses `RESOLUTION_POLICY_HIGHEST_PROGRESS`. The adapter adds a fresh remote read and monotonic progress merge before each upload. The GDScript API does not expose a configurable resolution policy.

The vendored v3.4.0 snapshot bridge emits any residual conflict snapshots but exposes **no `resolveConflict` method**. If such a conflict remains after Google's automatic policy, the adapter merges both snapshots into local progress and stops cloud retry loops. Local play continues. To guarantee resolution of these residual conflicts, upgrade to a release exposing it or extend/rebuild the native bridge and wire the conflict ID to Google's resolver. This is a real upstream limitation; no nonexistent API is called.

In this release, `SnapshotsProxy.saveGame` emits `gameSaved(true)` after starting `commitAndClose`, without awaiting its completion. The game's synced message therefore reflects the plugin acknowledgement, not independently verified durable storage. Before production, validate cloud round trips on two physical devices and consider updating that native implementation to report commit success/failure correctly. The relevant upstream source is [SnapshotsProxy.kt](https://github.com/godot-sdk-integrations/godot-play-game-services/blob/v3.4.0/plugin/src/main/java/com/jacobibanez/plugin/android/godotplaygameservices/snapshots/SnapshotsProxy.kt).

## Verification

Run `godot --headless --path . --script res://tests/test_progression.gd` from the project root. The suite passed **272 checks with zero failures** on October 17, 2026. It covers persistence, corruption recovery, rank rewards, fifty campaign completions, merge idempotence/convergence, deduplicated first-clear/login rewards, quest determinism/claims, invalid cloud inputs, Golden Gull bonuses, daily/campaign unlock isolation, and Shipyard purchases/migration. Mock service checks verify all 32 supplied IDs against an independent fixture, canonical configuration precedence, catalog fallback, complete 28-achievement/four-board dispatch, absolute incremental steps, survival milliseconds, durable offline queues, blank-ID no-ops, acknowledgement handling, and preservation of newer scores during older requests. Current results are recorded in [VALIDATION.md](VALIDATION.md). These checks do not substitute for Android sign-in, Play Console credentials, or real cloud round-trip tests.

Before release, test offline play followed by reconnect, two devices completing different levels and using different ships, achievement retry after disconnection, survival board formatting, a fresh device restoring a snapshot, cloud commit failures, and any native snapshot conflicts. Keep keystores, passwords, access tokens, and service account files outside this public repository.
