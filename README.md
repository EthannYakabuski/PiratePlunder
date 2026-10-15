# PiratePlunder

A complete portrait pirate arcade game built with **Godot 4.5.1** for Android. Pick a ship, chart a voyage, and cause an unreasonable amount of trouble. The game works offline; Google Play Games integration is optional until its backend is configured.

## Play

Open `project.godot` in Godot and press **F6** from `scenes/main.tscn`, or **F5** from anywhere. The opening screen immediately shows four ships. Tap one to open your shared campaign chart. Pick a level, Endless Seas, or Daily Drift, then tap the ship you want to sail.

- **Steer:** drag the large wheel toward your desired heading. Your ship sails continuously.
- **One thumb:** automatic broadsides fire at rivals crossing either side. This is enabled by default.
- **Two thumbs:** the bottom corner cannons fire their respective sides, each with an independent reload. Hold to keep firing; release the wheel to maintain your heading.
- **Desktop:** WASD or arrow keys steer; Q fires port, E or Space fires starboard.
- **Pause:** tap the top-right pause button. Android backgrounding pauses the voyage automatically.

Sink rivals, dodge cannonballs and hazards, collect gold, and complete the mission shown above the battle. Green pickups repair your hull, blue pickups grant a shield, orange pickups speed up reloads, and purple pickups attract treasure. Consecutive sinks build a score multiplier. Watch your health and the cannon reload rings.

Campaign wins unlock the next level for every ship. Earn one star for victory, another for keeping at least 60% hull, and another for beating the level's time goal. Each ship earns its own XP and automatic hull, damage, and reload perks. Replays improve your stars and earn run rewards; authored campaign rewards are paid once per level. The Logbook contains achievements, daily bounties, supply rewards, and personal records.

## Included content

- Four distinct ships: Swiftfin, Ironclad, Redwake, and Golden Gull.
- **50 authored campaign levels** across Sunlit Shoals, Mangrove Maze, Ember Archipelago, Frostwake Reach, and Tempest Crown.
- Sink, salvage, survival, and boss missions; six enemy archetypes; five named bosses with broadside, charging, fan, or spiral attacks.
- Endless procedural ocean with deterministic islands, changing biomes, supplies, escalating danger, and recurring bosses. Entities and terrain caches have strict bounds.
- Daily Drift, three daily bounties, supply streak rewards, per-ship ranks, persistent stars, and **28 achievements**.
- Four leaderboard definitions: endless score, endless survival, campaign stars, and lifetime plunder.
- Original looping shanty and cannon audio, supplied Kenney effects, particles, wakes, damaged ship sprites, shields, and reduced-motion/audio/haptic settings.
- App/adaptive icons, feature graphic, all achievement/leaderboard icons, store copy, setup worksheets, and actual Godot-rendered phone/tablet screenshots.

There are no ads, purchases, energy gates, or developer-operated analytics in this MVP.

## Android build

Install Godot 4.5.1 with matching export templates, JDK17, Android SDK Platform36 and build-tools36. Set the SDK/JDK paths in Godot's Android editor settings. Then use the checked-in **Android APK** or **Android AAB** export preset, or the helper:

```powershell
./tools/build_android.ps1 -Godot 'C:/path/to/Godot_v4.5.1-stable_win64_console.exe' -JavaSdk 'C:/path/to/jdk-17' -AndroidSdk 'C:/path/to/Android/Sdk'
```

The helper prepares the ignored Gradle template. The APK preset targets ARM64; the AAB preset includes ARMv7 and ARM64. The provisional package is `com.pirateplunder.game`, minimum API24, target API36. Confirm the permanent package name before publication. [Full Android build and signing instructions](docs/ANDROID_BUILD.md).

For a connected device, install `builds/PiratePlunder-debug.apk` with `adb install -r`, then launch PiratePlunder. Debug artifacts are local, ignored by Git, and unsuitable for Play publication. Use a privately configured release key for your final AAB; no signing credentials are checked in.

## Google Play Games

The requested [Godot Play Game Services plugin](https://github.com/godot-sdk-integrations/godot-play-game-services) is included and pinned to v3.4.0. The application has real adapters for sign-in, achievements, leaderboards, and Saved Games, with local progress and durable submission queues when offline.

Game ID **837392218124** and the supplied public OAuth client identifier are in `config/play_games.json`. Configure Android credentials with the final package and signing certificates, add testers, create the 28 achievements/four boards, and paste their generated IDs into the configuration or data catalogs. Empty IDs never produce bogus submissions. No server authorization flow or client secret is required by this implementation.

[Play Games setup and cloud limitations](docs/PLAY_GAMES.md) explains native automatic conflict resolution, merged local saves, and two upstream snapshot limitations that must be checked before production. Cloud operation has not been authenticated against your unfinished backend.

## Developer guide

`scripts/main.gd` builds the responsive screens and connects runs to progression. `scripts/arena.gd` owns combat, touch input, enemy behaviors, procedural terrain, hazards, pickups, drawing, and bounded effects. `scripts/progression.gd` owns versioned atomic saves with backup/checksum recovery, progression, daily rewards, and monotonic cloud merging. `scripts/play_services.gd` adapts the pinned plugin and persistent online queues.

Author content in `data/campaign.json`, `ships.json`, `achievements.json`, and `leaderboards.json`. Level definitions specify numeric objectives, enemy pools and timed waves, hazards, boss attacks, rewards, and star goals. The [campaign document](docs/CAMPAIGN.md) lists every level and the precise schema/implementation limits. [Project memory](docs/PROJECT_MEMORY.md) preserves the product decisions and assumptions.

The [asset audit](docs/ASSET_AUDIT.md) inventories and visually reviews all 11 supplied packs. Original assets are preserved; `.gdignore` files exclude unused source packs, duplicate resolutions, and authoring references from runtime imports. Curated pirate sprites/terrain and supplied audio are reused. Generated artwork/audio can be rebuilt with `tools/build_art.py`; the fonts retain their OFL licenses. Kenney assets are CC0; the Play Games addon is MIT.

To validate the project after importing it:

```powershell
./tools/run_tests.ps1 -GodotExe 'C:/path/to/Godot_v4.5.1-stable_win64_console.exe' -PythonExe 'C:/path/to/python.exe' -Render
```

Python data/art validators need Pillow; artwork generation also uses NumPy, and font instancing optionally uses fontTools. Godot handles all gameplay/save/UI suites. Test profiles use isolated temporary repository files and never replace a player's save. [Validation evidence and performance limits](docs/VALIDATION.md), [balance observations](docs/BALANCE.md).

To reproduce exact-size store captures:

```powershell
./tools/capture_screenshots.ps1 -GodotExe 'C:/path/to/Godot_v4.5.1-stable_win64_console.exe' -PythonExe 'C:/path/to/python.exe'
```

## Publishing next steps

1. Confirm package identity, support contact, and signing setup; complete Play Games credentials, IDs, and test accounts.
2. Install the debug APK on real phones/tablets. Test one-thumb play, simultaneous touch, safe areas, audio interruptions, save/restart, and a 20-minute thermal/performance session. Validate cloud round trips on two accounts/devices as appropriate.
3. Review release signing, Android16/large-screen behavior, native 16KB page compatibility, and Play's pre-launch report. Export a signed release AAB and increase its version code.
4. Use the [store listing kit](docs/STORE_LISTING.md); replace or supplement desktop-rendered screenshots with final Android captures. Supply a hosted privacy policy/support email and complete Data safety, content-rating, audience, app-access, and account-specific testing requirements.
5. Upload to internal testing, gather human playtest feedback on steering/difficulty, then proceed through the Console's required testing and release steps.

The game and local submission kit are implemented. Physical-device, backend-authenticated, and production-signing checks remain publishing work; they are not represented as completed tests.
