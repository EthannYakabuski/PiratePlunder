# Android builds

The project includes two Gradle export presets: **Android APK** (ARM64 debug/device testing) and **Android AAB** (ARMv7 + ARM64 for eventual Play distribution). Both use `com.pirateplunder.game`, version `0.3.0` / code `4`, portrait orientation, optional Play Games services, Google-test AdMob integration, and separate adaptive launcher icon layers. Confirm the package name before first publication.

The minimum API is 24. The target API is **36**: Google requires Android 16/API 36 for new phone applications and updates from August 31, 2026. This was verified on October 14, 2026 against the [official target API requirement](https://developer.android.com/google/play/requirements/target-sdk). Recheck the rule when publishing.

## Requirements

Install Godot **4.5.1** and its matching export templates, JDK 17, Android SDK Platform36, platform-tools, command-line tools, and build-tools36. Configure your JDK and SDK directories in **Godot â†’ Editor Settings â†’ Export â†’ Android**. Both `GodotPlayGameServices` and `admob` editor addons must remain enabled. The public native AdMob bridge AARs are vendored and hash-checked; see [the AdMob audit](ADMOB.md). Follow the [Godot Android export instructions](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html).

The build helper extracts the stock `android_source.zip` to ignored `android/build` if necessary and changes that template's compile SDK from 35 to 36. The default Gradle build directory setting is intentionally blank: Godot resolves it to `res://android/build`. Setting the option to that exact path incorrectly appends another `build` directory.

The editor coexistence patches preserve project-authored autoloads through startup and shutdown. Keep their order `Progression`, `GodotPlayGameServices`, `PlayServices`, `Ads`. AdMob registers editor metadata without saving a stale project snapshot; GPGS removes only an unchanged singleton created by that exact editor instance. The build helper has a fallback that merges missing plugin entries into the latest settings instead of replacing the project file. It prefers the actual Windows engine executable over the console shim. `project.godot` remained byte-for-byte unchanged across two editor import/exit passes and both final exports.

Keep `textures/vram_compression/import_etc2_astc=true` in the project's rendering settings. Godot's Android export validation requires mobile texture import support even for this Compatibility renderer project; otherwise 4.5.1 may report an empty configuration error. Generated Android resources, caches, and native build outputs remain ignored.

## Debug APK

From the project root:

```powershell
./tools/build_android.ps1 -Godot 'C:/path/to/Godot_v4.5.1-stable_win64_console.exe' -JavaSdk 'C:/path/to/jdk-17' -AndroidSdk 'C:/path/to/Android/Sdk'
```

If the matching export templates are elsewhere, pass `-TemplateDirectory 'C:/path/to/4.5.1.stable'`. The helper reuses a conventional local Android debug keystore if present. It does not create release keys. The output is `builds/PiratePlunder-debug.apk`, with its build log beside it. A first Gradle build may need network access for dependencies and can take several minutes.

Install and launch on an authorized connected test device:

```powershell
adb install -r builds/PiratePlunder-debug.apk
adb shell monkey -p com.pirateplunder.game 1
```

## App Bundle and release signing

For a debug bundle that verifies the packaging path, pass `-Format AAB`. Debug bundles are **not publication builds**. A Play submission needs a signed release AAB, an incremented version code, the final package name, and the configured Play Games credentials.

Provide the release keystore path, alias, and password through `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, and `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`, set privately outside the repository. Then run the helper with `-Format AAB -Release`. The helper refuses that export when any signing field is missing. Never commit keystores, credentials, signing passwords, generated APKs/AABs, or account tokens.

## Validation still needed on hardware

Test API 24 and a recent Android 16 phone; notch and gesture safe areas; portrait tablets; simultaneous steering and manual port/starboard cannon holds; separately unlocked grapeshot controls; purchased per-side crews and the rank-20 primary automation capstone; haptics; audio focus/background interruptions; temperature and battery behavior during a 20-minute Endless run; sustained frame rate with the enemy/projectile cap; app restart persistence; and Play Games authentication/cloud round trips with test accounts. Also check Android 16's edge-to-edge and large-screen behavior on real devices.

The template shipped with Godot 4.5.1 uses Android Gradle Plugin 8.6.1. Compiling against API 36 can produce a tooling compatibility warning. Review and validate the template/toolchain against the current Play requirements before signing a production build. Android native 16KB page compatibility and Play's pre-launch report also require release-artifact validation; a successful desktop run cannot prove those properties.

## Build status

Both version **0.3.0 / code 4** debug exports completed successfully on October 17, 2026 with SDK 36 and JDK 17:

| Artifact | Size | Validation |
| --- | ---: | --- |
| `builds/PiratePlunder-debug.apk` | 95,420,024 bytes | APK signature v2; ARM64; manifest min24/target36/compile36; portrait; 16KB ZIP alignment; ELF LOAD alignment 16,384 bytes |
| `builds/PiratePlunder-debug.aab` | 71,092,991 bytes | Google bundletool 1.18.3 validation; ARMv7+ARM64 libraries and identical packaged gameplay scripts/campaign/configuration data |

These artifacts include the finite campaign (50 levels, 142 authored encounters and 526 ships), nine purchasable upgrades per ship, manual primary cannon controls, rank-gated grapeshot and purchased automation, and backward-compatible save version 3. The campaign catalog uses `finite_authored_fleets_v2` and topology revision 3. Version0.3.0 adds consent-gated test advertising and background/resume handling. Ad loads retry in four-attempt bursts followed by a 240-second cooldown. Before packaging, the frozen source passed 78 Ads checks and 202 ad-flow checks, alongside the existing progression/game/data regression suites. The final rendered UI smoke passed **29 checks with zero failures**.

Both artifacts contain all **28 achievement IDs and four leaderboard IDs**, exactly matching `config/play_games.json` and each catalog's `google_play_id`. Play Games integration and saved games are enabled in the packaged configuration, with sign-in initiated explicitly by the player. The public achievement setup CSV now totals **975 points**. APK/AAB JSON catalogs and all five compiled game/service/ads scripts are byte-identical between artifacts and match the frozen source configuration. The APK's Android APP_ID resource and the AAB's corresponding resource both resolve to `837392218124`. The separate AdMob `com.google.android.gms.ads.APPLICATION_ID` metadata is present in both manifests with the Google sample app ID `ca-app-pub-3940256099942544~3347511713`; it does not overwrite Play Games metadata. The correct Advertising ID permission, INTERNET, and ACCESS_NETWORK_STATE are present. These permissions are reproducible from the tracked presets/helper, including a fresh Android template.

The APK/AAB include the public Play Games and AdMob configurations, Google Play Games native/SDK classes, Poing banner/interstitial/rewarded and consent bridges, GMA Next-Gen SDK1.4.0, and UMP4.0.0. The active adaptive-banner/interstitial/rewarded units are Google test IDs. Production unit fields remain blank, and the supplied production app ID is retained as public setup reference. See [ADMOB.md](ADMOB.md) for dependency versions, vendor/license hashes, consent gates, and the production switch. Packaged fonts, ocean waves, particle textures, adaptive icon layers, and all four ships' direct sprite references were checked. Unused original asset variants, store/docs/test assets, and generated build verification fixtures are excluded from game exports. The store kit contains 18 refreshed actual gameplay/UI captures across phone, 7-inch tablet, and 10-inch tablet sizes.

Final SHA-256 checksums:

```text
PiratePlunder-debug.apk  BBF1D19DAB0A0EF58ACA6A5196C173F0F21356EB85EA09F5111DEF0050EBF76A
PiratePlunder-debug.aab  44ECD1A2C6631947585708102F2FC19CA7E4228633F1FB92CFFB93F9B2E7F37B
```

The public SHA-1 fingerprint for the debug certificate used for these local artifacts is `EE:50:07:90:8C:4A:8C:D2:48:E5:42:CA:A8:8A:1B:00:7C:58:DD:DE`. It can be registered for the debug Android credential. A future release/Play signing certificate will have a different fingerprint. This fingerprint is public certificate metadata, not a signing secret.

The debug AAB is an **unsigned packaging preview** produced by Godot's debug bundle export. Its game assets are in an install-time asset pack, and all 50 campaign levels are present. Google bundletool validates its structure and manifests. It must not be submitted as a production bundle. Release signing must be configured separately. All ARM64 native libraries (`libgodot_android.so` and `libc++_shared.so`) have 16,384-byte ELF LOAD alignment in both artifacts. Their ARMv7 counterparts in the AAB have 4,096-byte LOAD alignment. These packaging checks do not substitute for validating the signed release and its generated device APKs.

The final APK and AAB contain the same compiled `ads.gdc` SHA-256 `2bdd154f174a096cabb6b90ec2f2f139726268f8e673014e1b15806290f75886`, differing from the preliminary export. A read-only load of the packaged script confirmed `RETRY_BURST_COOLDOWN=240.0` and `MAX_LOAD_ATTEMPTS=4`. Frozen source `ads.gd` SHA-256 is `FC3F097A2E32838EC3B197DD77BDA60E9F5D8BBD968E32E6D421B24B366AD963`; the final background-resume `main.gd` source hash is recorded in the verification report.

Local verification records are in ignored `builds/package-check/verification-0.3.0.json`, `apk-signature-0.3.0.log`, `apk-zipalign-0.3.0.log`, `aab-validation-0.3.0.log`, and `aab-manifest-0.3.0.xml`; the final rendered launch check is `builds/final-0.3.0-ui-smoke.log`.

A bounded read-only ADB device inventory returned zero connected devices. These exports were not installed on Android hardware during this build refresh. On-device performance, Android 16 behavior, actual native ad serving/consent forms, and account-authorized Play Games operation remain unverified. Desktop fake-ad tests and compiled-class checks do not demonstrate a served ad or consent decision. The debug artifacts are for testing; no production signing key was created and no artifact was uploaded to Google Play.
