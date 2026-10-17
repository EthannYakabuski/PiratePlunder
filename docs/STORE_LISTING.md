# Store listing and publishing assets

Prepared October 14, refreshed for gameplay 0.2.0 on October 15, 2026. This is the submission kit, not a record of publication. Copy now describes manual cannons, earned-gold upgrades and finite authored campaign battles. It does not promise operational Google cloud services before owner configuration and device testing.

## Copy-ready files

- App title: `store/app_name.txt` — **PiratePlunder**.
- Short description: `store/short_description.txt` — **Steer, blast and plunder through 50 pirate levels or an endless ocean**.
- Long description: `store/full_description.txt`.
- Machine-readable copy, character counts, and asset alt text: `store/listing_metadata.json`.

The copy stays within the 30-character title, 80-character short-description and 4,000-character full-description limits. Category suggestion: **Game / Arcade**; review available tags in Play Console rather than promising a fixed tag set. Add your real developer support email and privacy-policy URL before submission. [Google Play app setup and listing fields](https://support.google.com/googleplay/android-developer/answer/9859152).

## Graphics

| Upload | File | Verified format |
|---|---|---|
| High-resolution app icon | `store/app_icon_512.png` | 512×512 RGBA PNG; below 1,024 KB; no rounded-corner mask |
| Feature graphic | `store/feature_graphic_1024x500.png` | 1024×500 RGB PNG; no alpha |
| Android launcher foreground | `assets_generated/ui/app_icon_foreground.png` | 432×432 transparent PNG; centered 264 px safe circle |
| Android launcher background | `assets_generated/ui/app_icon_background.png` | 432×432 RGB PNG |
| Achievement icons | `store/achievements/<local_id>.png` | 28 distinct 512×512 PNGs |
| Leaderboard icons | `store/leaderboards/<local_id>.png` | Four distinct 512×512 PNGs |

The app icon and feature graphic meet the published Play dimensions and alpha requirements. The feature graphic is promotional artwork composed from the game's supplied pirate assets. It is not labeled as a screenshot. [Google Play preview asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151).

Use the native app PNG/SVG in the project; the exported launcher may use the separate adaptive layers. Preserve original full-square uploads and let Android/Play apply masks. Source artwork and rebuild instructions are in [`ASSET_AUDIT.md`](ASSET_AUDIT.md).

## Screenshots

Fifteen actual game renders are supplied under `store/screenshots/`: five each for phone (1080×1920), 7-inch tablet (1200×1920), and 10-inch tablet (1600×2560). Each family includes ships, chart, combat, boss and logbook states. All are RGB PNGs, with native output dimensions and SHA-256 hashes recorded in `store/screenshots/manifest.json`. `tools/capture_screenshots.ps1` and `tools/capture_viewport.gd` reproduce them from Godot. The latter uses a native-sized SubViewport so the desktop monitor does not clamp tall captures, while preserving the project's logical expand layout. No resizing or promotional overlays are applied; only an all-opaque alpha channel is removed. Desktop Godot renders are layout evidence and do not establish physical Android testing. Replace or supplement them with device/emulator captures of the final signed build before publishing.

Play accepts JPEG or RGB PNG screenshots, at least two across supported device types, between 320 and 3,840 pixels, with the longer edge no more than twice the shorter. For strong coverage, target four portrait screenshots per form factor showing ship selection, the campaign chart, gameplay and progression. Use genuine current UI, avoid added device frames or claims, and check the Console's current large-screen requirements when uploading. [Google Play screenshot requirements](https://support.google.com/googleplay/android-developer/answer/9866151).

The current kit contains 18 actual renders: chart, ship choice, manual combat, boss, logbook and Shipyard for each device shape. `tools/build_art.py` produces promotional art; screenshots come from the real application. Capture mode now bypasses progression writes and simulates the authored fleets rather than inserting extra ships or geography.

## Play Games setup kit

`data/achievements.json` is the authoritative set of names, descriptions, metrics, target steps and local IDs. All 28 icons have corresponding names in `store/achievements/`. `store/achievement_setup.csv` is a human-readable setup worksheet, with suggested point values and exact step targets; it is not claimed to be an automatic Console bulk-import format. Keep most achievements visible and revealed; confirm the first few unlock early during your internal playtest. Google currently requires unique names/descriptions/icons and at least ten lifetime achievements. Suggested points stay well below the current 2,000-point budget. [Play Games achievement concepts](https://developer.android.com/games/pgs/achievements).

`store/leaderboard_setup.csv` mirrors `data/leaderboards.json`: Endless Ocean score, Endless Ocean survival, campaign stars and lifetime plunder. All sort high-to-low. Survival submits integer milliseconds; campaign stars have a maximum of 150. Google provides daily, weekly and all-time views for each configured board; do not create redundant separate boards just for those timeframes. Icons use 512×512 PNGs and avoid localized text. [Play Games leaderboards](https://developer.android.com/games/pgs/leaderboards).

The worksheet's local IDs are not the IDs issued by Google. All 28 Google achievement IDs and four leaderboard IDs supplied on October 17, 2026 are now populated in the worksheets, catalogs and configuration. The achievement worksheet reflects the owner's actual Console point values, totaling 975. The supplied game ID, OAuth client ID and achievement/leaderboard IDs are public identifiers; account credentials, private signing keys, passwords and OAuth secrets must remain outside the repository.

For entry points that open Google's built-in achievement/leaderboard UI, use the official Play Games controller icon in the surrounding service area. The custom achievement/leaderboard pictures identify individual awards and boards; they do not replace required service branding. [Play Games branding](https://developer.android.com/games/pgs/branding).

## Owner's final publishing work

1. Review the permanent Android package name, release signing setup and Play App Signing certificate before creating credentials. Export and test a signed Android App Bundle.
2. Complete Play Games owner configuration: Android credentials for each test/release signing certificate, test accounts, saved-game configuration, and testing/publication of the already-created 28 achievements/four boards. Test sign-in, offline queue recovery, save conflicts, and achievements on real Android devices before enabling cloud claims in the listing.
3. Supply the actual support email and a hosted privacy policy covering the release's real behavior and SDK data practices. Complete Data safety, app access, ads, target audience, content-rating and other Console declarations based on the actual build. Do not assume a rating without completing the questionnaire.
4. Run device/emulator QA across phones and both tablet classes: touch targets, safe areas, multi-touch broadside control, audio focus, pause/resume, orientation, long-session performance, storage recovery, battery/thermal behavior and accessibility. Recapture final Android screenshots.
5. Upload the listing kit and signed bundle to internal testing. Review any account-specific closed-testing requirements in the Console, then progress through testing and managed publication when ready. [Google Play app creation and release setup](https://support.google.com/googleplay/android-developer/answer/9859152).

As verified October 14, 2026, new phone/tablet apps and updates must target **Android 16 / API 36 or higher** under the policy effective August 31, 2026. Install the matching SDK and use a compatible Android export/build toolchain. Recheck the Console policy when releasing later. [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-EN).

The MVP does not introduce advertising, billing or a developer-operated analytics backend. Revisit the listing and privacy declarations if these are added later. All supplied Kenney art/audio is CC0, original generated art/audio is CC0, and the bundled fonts retain their included SIL Open Font Licenses.
