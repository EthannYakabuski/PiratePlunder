# AdMob integration audit and setup

PiratePlunder uses **Poing Godot AdMob 5.1.0**, alongside the existing **Godot Play Game Services 3.4.0** integration. The Android presets are version **0.3.0 / code 4**, min API24, compile/target API36, with Godot4.5.1 and JDK17. AdMob is configured for **Google test ads**. This document records the source, native dependency setup, and the boundary between local tests and real Android verification.

## Source and native artifacts

Only the user-provided `addons/admob` subtree was copied from the local Poing download. The source snapshot contained **526 files / 3,589,518 bytes**. Its MIT license is preserved in `addons/admob/LICENSE`. `VENDOR_SOURCE.json` records every original source file hash; its source inventory SHA-256 is `81b12e9eedc20b1b75ccc59a4784ea07bb6fcd2019aeca6e70ccc86ed0275f9d`. Godot import sidecars in the original local snapshot are regenerated and remain ignored by the repository.

The local download contained no Android AARs. The matching [official 5.1.0 release](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0) supplies `android-template-v4.5.1.zip`: **359,197 bytes**, SHA-256 `f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee`. The downloaded archive matched the checksum on the release asset listing before extraction. No iOS archive was downloaded.

The Android archive is installed under `addons/admob/android/bin`, including its version marker. `VENDOR_ANDROID.json` records its files and hashes. Public bridge binaries are tracked so a fresh checkout can export without an editor-managed native download. The enabled `ads` adapter contributes exactly these four variant files; each build includes the matching debug or release pair:

| Native bridge | SHA-256 |
| --- | --- |
| `ads/libs/poing-godot-admob-ads-debug.aar` | `fac3128d6e64b59666b1bac3097952bbbde2f1b1573656cd51b9f64f745edd79` |
| `ads/libs/poing-godot-admob-ads-release.aar` | `aeca6a3c813da770390dc1d574765b17d8ba78fe0cf1cb61438dc08df1fe1c67` |
| `ads/libs/poing-godot-admob-core-debug.aar` | `f78a4075635d4d3f27d7de66d350fb77c16f21e60e24ceee702c80efe5b96e29` |
| `ads/libs/poing-godot-admob-core-release.aar` | `f89e3f1096047fabc83208e4e00a3f0aef847229bcb68cc01e791bd57468fda0` |

Optional mediation bridge files are present in the upstream Android template but every mediation setting remains disabled. Their third-party SDK dependencies are not enabled. Export filters exclude platform native source files, downloads, sample scenes, C# bindings, skills, and vendor audit records from the game resource pack. The native bridge AARs are supplied to Gradle through the plugin exporter. Bridge code is MIT; Google and other Maven SDK dependencies retain their own licenses and terms.

## Dependency audit

The 5.1.0 Android exporter pins **GMA Next-Gen**, rather than the legacy `play-services-ads` SDK:

- `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0`
- `androidx.constraintlayout:constraintlayout:2.2.0`

The [official 1.4.0 Maven POM](https://dl.google.com/dl/android/maven2/com/google/android/libraries/ads/mobile/sdk/ads-mobile-sdk/1.4.0/ads-mobile-sdk-1.4.0.pom) lists these direct dependencies of the ads SDK:

```text
androidx.activity:activity:1.2.3
androidx.annotation:annotation:1.6.0
androidx.browser:browser:1.8.0
androidx.core:core:1.12.0
androidx.core:core-ktx:1.12.0
androidx.datastore:datastore:1.0.0
androidx.webkit:webkit:1.15.0
androidx.work:work-runtime:2.7.0
com.google.android.gms:play-services-ads-identifier:18.0.0
com.google.android.gms:play-services-appset:16.0.1
com.google.android.gms:play-services-basement:18.9.0
com.google.android.gms:play-services-cronet:18.0.1
com.google.android.gms:play-services-tasks:18.2.0
com.google.android.play:hsdp:2.0.1
com.google.android.ump:user-messaging-platform:4.0.0
com.google.code.gson:gson:2.10.1
com.google.crypto.tink:tink-android:1.20.0
com.google.guava:guava:32.0.0-android
com.squareup.okhttp3:okhttp:4.11.0
org.chromium.net:cronet-api:143.7445.0
org.chromium.net:cronet-fallback:143.7445.0
org.jetbrains.kotlin:kotlin-stdlib:1.9.20
org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0
org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.5.0
```

This is the published POM graph, before Gradle reconciles versions with Godot and Play Games. GPGS continues to request `play-services-games-v2:21.0.0` and `gson:2.11.0`. The AdMob exporter excludes legacy `play-services-ads` / `play-services-ads-lite` and forces Browser1.8.0, as supplied upstream. The ads/core native bridges declare minSDK24 and minCompileSDK35. Inspected WebKit1.15.0 metadata requires minCompileSDK33/minAGP7.2.0. The existing compileSDK36 satisfies those requirements; no SDK version was silently upgraded. The pinned SDK is intentional even if a newer Google guide demonstrates a newer release.

The native `PoingGodotAdMob.initialize()` method reads `com.google.android.gms.ads.APPLICATION_ID` and starts SDK initialization on a background Java thread. It does not initialize the SDK merely because its Godot singleton is registered. [Google's Next-Gen setup guide](https://developers.google.com/admob/android/next-gen/quick-start) requires initialization before ad operations and consent handling before initialization where applicable.

## Configuration and consent

`config/admob.json` is the runtime configuration. Current public identifiers are:

| Purpose | Identifier |
| --- | --- |
| Active test application | `ca-app-pub-3940256099942544~3347511713` |
| Adaptive banner test unit | `ca-app-pub-3940256099942544/9214589741` |
| Interstitial test unit | `ca-app-pub-3940256099942544/1033173712` |
| Rewarded test unit | `ca-app-pub-3940256099942544/5224354917` |
| Retained production app reference | `ca-app-pub-7719473349082950~3314995170` |

`use_test_ads=true` selects Google's sample app and units. Production banner/interstitial/rewarded unit fields remain empty. The sample banner uses the anchored adaptive format; Google's `6300978111` sample is for a fixed-size banner and is not used for this adaptive placement. These IDs are public configuration, not credentials. They were checked against [Google's test ad documentation](https://developers.google.com/admob/android/test-ads).

The `Ads` autoload is registered after `Progression`, `GodotPlayGameServices`, and `PlayServices`. The adapter delays Mobile Ads initialization and ad requests until the consent path permits them. It sets no forced COPPA flag, under-age flag, or G-rated content cap. Store audience declarations remain a separate publishing decision.

Failed inventory loads use four-attempt bursts with exponential spacing, followed by a 240-second cooldown before another burst. Recovery requires an initialized SDK and current privacy eligibility; banner retries also require the home screen. A late load never triggers an interstitial or rewarded presentation. Showing a rewarded ad always requires a fresh user choice. Timers pause in the background, and SDK-confirmed visible ads/forms wait for actual dismissal/error callbacks rather than a timer-based game resume.

The plugin includes UMP4.0.0 through the ads SDK. Its `ConsentInformation` bridge exposes status, form availability, privacy-options requirement, update, and reset; neither the GDScript nor the native5.1.0 bridge exposes `canRequestAds`. The adapter therefore requires a current-launch update attempt and an SDK status of `NOT_REQUIRED` or `OBTAINED`. Unknown/required consent cannot enable ads through saved local preferences. It loads/shows a required consent form and exposes privacy options when required. The SDK's own current status can support a previously obtained consent decision following an update error; the application does not invent a persisted consent grant. [Google's UMP guide](https://developers.google.com/admob/android/next-gen/privacy) describes per-launch updates, required forms, privacy options, and the SDK's request gate. Desktop tests cannot establish a user's Android consent status.

## Editor coexistence patches

`addons/admob/VENDOR_PATCHES.json` records original/patched hashes and reasons. Native AARs and runtime Play Games APIs were not modified.

- AdMob dependency installers now respect the Android/iOS enable settings in graphical and headless editor startup. `admob/general/ios/enabled=false` prevents unsolicited iOS downloads.
- AdMob property registration adds editor hints/defaults without saving a complete in-memory project snapshot or pruning project-owned keys.
- The AdMob Android `.gitignore` allows the pinned public native bridges to be tracked; C# bindings are hidden with `.gdignore` in this GDScript project.
- GPGS's editor plugin preserves an already-authored singleton. It may remove only an unchanged singleton that this exact editor plugin instance created. A matching persistent singleton is never removed on editor exit.

Two sequential headless editor import/start/exit passes returned exit0 with no script parse/load errors. The entire `project.godot` SHA-256 stayed `135307CABBE98BDA6FBC7914C622878C1ACFE14ED8A4AEB2872915ED2A29003F` across both passes, preserving all four entries and their order. Logs are in ignored `builds/admob-editor-preservation-1.log` and `-2.log`. The sandbox prevented writing global editor settings; it did not alter the project or cause script failures.

## Reproducible Android setup

Both tracked export presets enable INTERNET and ACCESS_NETWORK_STATE and declare the correct custom permission `com.google.android.gms.permission.AD_ID`. `tools/build_android.ps1` also inserts missing permissions into a fresh generated template without deleting existing XML. The bridge's upstream manifest includes an older `android.permission.AD_ID` entry; the correct Google permission is explicitly supplied by this project.

The helper checks all four native AAR hashes and verifies that the active JSON app ID matches `admob/general/android/app_id` in `project.godot`. The plugin writes the ads application ID directly as manifest metadata, so GPGS's separate `res/values/strings.xml` update cannot erase it. The final APK/AAB checks must verify both:

```text
com.google.android.gms.games.APP_ID -> @string/game_services_project_id -> 837392218124
com.google.android.gms.ads.APPLICATION_ID -> ca-app-pub-3940256099942544~3347511713
```

Run template/dependency/permission preparation without exporting:

```powershell
./tools/build_android.ps1 -Godot 'C:/path/to/Godot_v4.5.1-stable_win64_console.exe' -JavaSdk 'C:/path/to/jdk-17' -AndroidSdk 'C:/path/to/Android/Sdk' -PrepareOnly
```

Remove `-PrepareOnly` to build the debug APK; add `-Format AAB` for a debug bundle. The helper prefers the real Windows engine executable over its console shim so the tracked exporter process exits cleanly. Its final fallback merges only missing authored plugin autoload entries into the latest project file, preserving unrelated/concurrent settings and changed custom URI values. Synthetic merge fixtures verified those cases. No full project snapshot is restored over current edits. Release signing still requires private external credentials; see `ANDROID_BUILD.md`.

## Before enabling production ads

Create the three production ad units and the appropriate AdMob Privacy & messaging configuration. Replace the empty production unit IDs, set `use_test_ads=false`, and change the authored Android app ID in `project.godot` to the retained production app ID. The helper rejects inconsistent app IDs or missing production units. Confirm the final Play Data safety/Advertising ID/contains-ads disclosures and privacy policy against the actual SDK use and [Google's Next-Gen SDK disclosure guide](https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure).

Complete the AdMob app verification/readiness steps and link the final store listing. New apps require app-ads.txt verification. `store/app-ads.txt` contains a candidate Google seller record derived from the publisher ID in the supplied app ID; compare it with the personalized snippet in AdMob, then host it at `/app-ads.txt` on the developer website linked from the store listing. Including the file in this repository or APK does not host or verify it. No website was published. See [Google's verification requirements](https://support.google.com/admob/answer/14538460?hl=en) and [app-ads.txt setup](https://developers.google.com/admob/android/next-gen/app-ads).

Validate on an authorized Android test device: native initialization and sample labels, per-launch consent and privacy options, offline/update/form failures, adaptive banner insets/rotation, rewarded dismissal versus earned reward, duplicate callbacks, full-screen return/audio pause behavior, and coexistence with Play Games authentication/saved games. Desktop fake-ad tests verify adapter logic but do not demonstrate a served ad, native consent flow, or account configuration. No production ad request or backend change is needed to complete local integration.
