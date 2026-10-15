# PiratePlunder asset audit

Reviewed October 14, 2026. Every supplied file is recorded in [`asset_review/inventory.json`](asset_review/inventory.json), including byte size and SHA-256. Every bitmap was opened and verified; dimensions and color mode are recorded per file. Ogg files also have Vorbis sample rate, channel count, and duration metadata. All 11 packs contain a CC0 license. No supplied bitmap failed verification.

The starting repository contained **5,083 files, 3,742 PNGs, 282 Ogg files, and 37,580,438 bytes** of supplied assets. Counts include previews, source vectors, atlases, licenses, and mechanically duplicated resolutions/styles; they are not counts of unique gameplay objects. Godot-generated `.import` sidecars and our new `.gdignore` import filters are excluded from the supplied-asset audit.

## Pack-by-pack findings

| Pack | Files | PNG / Ogg / SVG | Size | License and review |
|---|---:|---|---:|---|
| PirateStuff | 411 | 403 / 0 / 2 | 3,503,326 bytes | `Assets/PirateStuff/License.txt`, CC0. Ships, component hulls/sails/cannons, tile coastline/ruins, five cartoon effects. Core game source. |
| UI | 393 | 260 / 0 / 128 | 678,777 bytes | `Assets/UI/License.txt`, CC0. Adventure parchment, wood, coral banners, bolts, rings, progress bars, compass markers. Strong theme match. |
| MobileControls | 1,435 | 948 / 0 / 462 | 3,402,668 bytes | `Assets/MobileControls/License.txt`, CC0. Eight styles plus highlights/icons, one/two-scale variants and atlases. White icons are useful; the supplied steering-wheel symbol is a car wheel, so a pirate wheel is added. |
| CrossHairs | 2,013 | 1,609 / 0 / 400 | 2,983,163 bytes | `Assets/CrossHairs/License.txt`, CC0. 200 crosshair designs in dark/light/outline/glow variants and two scales. Reserve subtle circles for targeting; no aiming reticle is needed for basic play. |
| Foliage | 230 | 219 / 0 / 1 | 2,582,808 bytes | `Assets/Foliage/License.txt`, CC0. Trees/shrubs/snow/rocks/leaves in default/Retina variants. Most trees are side-view; prefer PirateStuff top-down palms. Flat leaves and snow rocks can support future art. |
| Medals | 35 | 31 / 0 / 1 | 151,966 bytes | `Assets/Medals/License.txt`, CC0. Nine medal designs, flat/flat-shadow/shaded variants. Flat ribbons provide the achievement style system. |
| Particles | 195 | 193 / 0 / 0 | 15,222,316 bytes | `Assets/Particles/License.txt`, CC0, with additional template authors credited in that file. Mostly 512×512 white/transparent puffs, stars, muzzle flashes, circles, lightning, scratches. Contains black-background versions and a Unity sample archive; use transparent originals only in Godot. |
| SmokeParticles | 80 | 79 / 0 / 0 | 6,009,920 bytes | `Assets/SmokeParticles/license.txt`, CC0. 25 dark smoke, 25 white puff, 9 explosion, 9 green cloud, 9 flash frames plus previews. Soft, more realistic than the primary art; use briefly and at low opacity if needed. |
| ImpactSounds | 133 | 0 / 130 / 0 | 1,035,004 bytes | `Assets/ImpactSounds/License.txt`, CC0. Wood/plank/metal/glass/soft impacts, bells and footsteps. Strong hull-hit and destruction coverage. |
| InterfaceAudio | 103 | 0 / 100 / 0 | 961,273 bytes | `Assets/InterfaceAudio/License.txt`, CC0. Clicks, confirmations, errors, plucks, switches, toggles. Use sparse clicks and reward confirmations. |
| RPGAudio | 55 | 0 / 52 / 0 | 1,049,217 bytes | `Assets/RPGAudio/License.txt`, CC0. Coins, creaks, cloth, doors, knife and inventory sounds; includes one preview. Coin/wood sounds fit pirate rewards and damage. |

Source `.swf`, `Thumbs.db`, web shortcuts, previews, and Unity samples are review/reference material. They are not required by the runtime. Full dimension distributions, licenses, hashes, and exact names are retained in the inventory, rather than repeating thousands of rows here.

## Visual direction and dimensions

The established style is flat, softly beveled Kenney vector art: warm timber, cream sails, round cannonballs, simple white emblems, and saturated green/red/blue/gold accents. Keep crisp silhouettes and broad color blocks. Primary palette: ocean teal `#168A9B`, deep navy `#103D4C`, sand/cream `#FFF1C8`, wood `#B77C39`, coral `#EC6B58`, gold `#F9C64B`. Campaign biome colors intentionally tint this family.

**Ships point downward in their source PNGs (+Y).** Their mast knob is at the top and their pointed bow at the bottom. An engine convention where forward is up must rotate the supplied art by PI. Each complete ship is **66×113 pixels**. Importantly, the `Retina/Ships`, `Retina/Ship parts`, and `Retina/Effects` files have the same dimensions as their `Default size` counterparts; do not assume a 2× ship image. Only the tile images in that pack double from 64×64 to 128×128. Avoid unnecessarily scaling ship textures beyond their native detail.

## Exact runtime selections

The shared prefix for ships is `res://Assets/PirateStuff/PNG/Default size/Ships/`.

| Look | Intact | Mild damage | Severe damage | Ghost |
|---|---|---|---|---|
| Bone/cream | `ship (1).png` | `ship (7).png` | `ship (13).png` | `ship (19).png` |
| Skull gray | `ship (2).png` | `ship (8).png` | `ship (14).png` | `ship (20).png` |
| Coral red | `ship (3).png` | `ship (9).png` | `ship (15).png` | `ship (21).png` |
| Green swords | `ship (4).png` | `ship (10).png` | `ship (16).png` | `ship (22).png` |
| Blue horse | `ship (5).png` | `ship (11).png` | `ship (17).png` | `ship (23).png` |
| Gold swords | `ship (6).png` | `ship (12).png` | `ship (18).png` | `ship (24).png` |

There are also six dinghies: `dinghySmall1–3.png` are 16×26, and `dinghyLarge1–3.png` are 20×38. Ship parts are under `res://Assets/PirateStuff/PNG/Default size/Ship parts/`: `cannonBall.png` is 10×10, `cannon.png` is 29×16, hulls are 40/50×108, and large sails are 66×46/47. The provided complete ship size does not imply ship class stats; class differences are defined in game data.

Tiles use `res://Assets/PirateStuff/PNG/Default size/Tiles/`:

- Sand outer corners: `tile_01.png`, `tile_03.png`, `tile_33.png`, `tile_35.png`; edges `tile_02.png`, `tile_17.png`, `tile_19.png`, `tile_34.png`; center `tile_18.png`.
- Green land and sand transitions: `tile_06–09.png`, `tile_22–25.png`, `tile_36–41.png`, `tile_52–57.png`.
- Plain rock decorations: `tile_49.png`, `tile_50.png`, `tile_51.png`; mossy versions `tile_65.png`, `tile_66.png`, `tile_67.png`.
- Palm/leaf silhouettes: `tile_70.png`, `tile_71.png`, `tile_72.png`; small vegetation `tile_87.png`, `tile_88.png`.
- Cartoon water: `tile_73.png`; speckled sand `tile_68.png`, `tile_69.png`.
- Ruins/stone walls/turrets: `tile_13–16.png`, `tile_29–32.png`, `tile_45–48.png`, `tile_60–64.png`, `tile_76–80.png`, `tile_89–96.png`.

Primary flat explosions are `res://Assets/PirateStuff/PNG/Default size/Effects/explosion1.png` (74×75), `explosion2.png` (60×59), `explosion3.png` (42×41). Flat fires are `fire1.png` (18×39), `fire2.png` (11×27). Additional white particles include `res://Assets/Particles/PNG (Transparent)/muzzle_01.png`, `smoke_03.png`, `star_04.png`, `circle_02.png`; each is 512×512 and can be color-modulated. Use bounded particle counts for phones.

Adventure UI assets use `res://Assets/UI/PNG/Default/`: `panel_brown.png` (64×64), `panel_brown_corners_b.png`, `round_brown.png` (64×64), `minimap_ring_brown.png` (128×128), `banner_hanging.png` (256×64), and `minimap_icon_star_yellow.png` (16×16). Nine-patch panel corners preserve texture proportions on larger cards. Modern icons use `res://Assets/MobileControls/Sprites/Icons/Default/icon_pause.png`, `icon_sound.png`, `icon_sound_disabled.png`, `icon_music.png`, `icon_music_disabled.png`, `icon_cog.png`, `icon_star.png`, `icon_shield.png`, `icon_skull.png`; these are 48×48 white shapes suitable for tinting.

Audio choices from the inventory:

| Use | Exact resource | Format and duration |
|---|---|---|
| Hull impact | `res://Assets/ImpactSounds/Audio/impactWood_heavy_000.ogg` | Vorbis, 44.1 kHz stereo, 0.313 s |
| UI tap | `res://Assets/InterfaceAudio/Audio/click_003.ogg` | Vorbis, 44.1 kHz mono, 0.010 s |
| Reward | `res://Assets/InterfaceAudio/Audio/confirmation_002.ogg` | Vorbis, 44.1 kHz mono, 0.539 s |
| Treasure | `res://Assets/RPGAudio/Audio/handleCoins.ogg` | Vorbis, 48 kHz stereo, 0.8455 s |
| Wood creak | `res://Assets/RPGAudio/Audio/creak1.ogg` | Vorbis, 48 kHz stereo, 0.661 s |

No supplied music loop or explicit cannon report exists. Those two gaps are filled with original procedural synthesis.

## Added assets and provenance

`tools/build_art.py` recreates the following, using supplied art as composition inputs and keeping the flat-vector style:

- `assets_generated/ui/ship_wheel.svg` and `.png`: a wooden eight-spoke pirate helm; 256×256, transparent.
- `assets_generated/ui/app_icon.svg` and `.png`: coral skull sail, wooden boat, side cannons, and teal surf; 512×512. The SVG is code-native and the PNG is rasterized from exactly that SVG.
- `assets_generated/ui/app_icon_foreground.png`: 432×432 transparent Android adaptive layer, ship/cannon silhouette within a centered 264 px safe circle.
- `assets_generated/ui/app_icon_background.png`: 432×432 teal RGB adaptive background.
- `store/app_icon_512.png`: matching 512×512 RGBA Play icon; no pre-applied corner mask.
- `store/feature_graphic_1024x500.png`: original 1024×500 RGB composition with the existing ship, palm, explosion and cannonball assets; promotional artwork, not a gameplay screenshot.
- `store/achievements/*.png`: 28 unique 512×512 award icons. Ribbon geometry/palette is derived from the supplied flat Kenney medals; native symbols and color combinations distinguish the awards.
- `store/leaderboards/*.png`: four unique 512×512 score/time/star/treasure icons, without localized text.
- `assets_generated/audio/cannon.wav`: original 0.58 s synthesized low cannon report with decaying noise; 22,050 Hz mono, 16-bit PCM, peak 0.85.
- `assets_generated/audio/pirate_loop.wav`: original 16-bar 6/8 plucked shanty with bass, soft reed chords, and brush taps; 92 dotted-quarter BPM, 20.8696 s, 460,174 samples, peak 0.313. Enable forward looping from sample 0 to 460,174. The tune wraps its tails into the beginning, avoiding an appended silence.

New artwork, compositions, and synthesized audio are dedicated to CC0. Their metadata is in `store/asset_manifest.json` and `assets_generated/audio/manifest.json`. No generative image model or downloaded stock image was needed: existing assets covered gameplay and the added images extend the established native vector system.

The original Google Fonts files `assets_generated/fonts/LilitaOne-Regular.ttf` and `Nunito-Variable.ttf` were downloaded from [google/fonts](https://github.com/google/fonts). Both include their original **SIL Open Font License** files alongside them. `Nunito-SemiBold.ttf` is a static weight-600 instance of the variable font, created with fontTools to ensure legible interface text. Nunito has no Reserved Font Name restriction in its license; its original OFL is retained. Lilita One is the display face; static Nunito SemiBold is the interface face. Fonts retain OFL rather than being relicensed CC0.

## Review evidence and reproduction

Labelled contact sheets in `docs/asset_review/` cover complete ships, all ship components, all 96 tiles, flat effects, medals, every default UI design, each MobileControls style/icons/highlights, 200 canonical crosshairs, all foliage/leaf designs, transparent particles, and smoke sequences. Pack preview sheets show the intended original style. Duplicate scales/color variants remain indexed per-file in JSON.

Run `python tools/asset_audit.py` with Pillow to rebuild the inventory/contact sheets. Run `python tools/build_art.py` with Pillow and NumPy to rebuild generated art/audio after campaign achievement IDs exist. Add fontTools if recreating the static Nunito font from its variable source; the committed static font lets artwork rebuild without fontTools. These are offline operations once fonts are present. Godot does not require Python to play or export the game.
