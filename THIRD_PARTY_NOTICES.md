# Third-party assets and software

The original source files and their license notices remain in this repository.

- **Kenney** — CrossHairs, Foliage, ImpactSounds, InterfaceAudio, Medals, MobileControls, Particles, PirateStuff, RPGAudio, SmokeParticles, and UI packs. All supplied packs carry **CC0** licenses in their respective `Assets/<pack>/License.txt` files (SmokeParticles uses lowercase `license.txt`). Thank you, [Kenney](https://kenney.nl).
- **Godot Play Game Services v3.4.0** — [upstream project](https://github.com/godot-sdk-integrations/godot-play-game-services), **MIT**, preserved in `addons/GodotPlayGameServices/LICENSE`.
- **Lilita One and Nunito** — official Google Fonts sources, **SIL Open Font License 1.1**, preserved in `assets_generated/fonts/*-OFL.txt`. Nunito SemiBold is a static instance of the supplied variable font.
- **Project-generated art and audio** — vector compositions, tiled waves, wheel, app icon, medals/boards, feature graphic, procedural cannon effect, and original shanty. The artwork build notes and source provenance are recorded in `docs/ASSET_AUDIT.md` and the generated manifests. These generated assets are provided under CC0 as documented there.

The Android build also resolves the libraries required by Godot and the Google Play Games plugin through Gradle. Keep their embedded license notices and review the final release dependency report before publication. This notice does not assign a new license to the game's application source code.
