# PiratePlunder finite campaign contract

The campaign contains 50 finite authored battles across five biomes, with 526 enemy ships organized into 142 named encounters. Every mission requires clearing its entire listed fleet. The four player ships share campaign unlocks and stars and earn experience separately.

This document describes `data/campaign.json` with `schema_version: 1`, `campaign_format: "finite_authored_fleets_v2"`, and `topology_revision: 3`. The format tag distinguishes this campaign from the earlier random-spawn prototype. Old coin-count and survive-a-timer missions have been replaced by authored fleet encounters while preserving level IDs, names, biomes, rewards, and star thresholds.

## Campaign completion and fleet sequencing

Level 1 starts unlocked. Winning level N unlocks N+1 for every ship. An unlocked mission can always be replayed.

The first named encounter deploys immediately at its authored coordinates. Later encounters deploy two seconds after the current fleet has been completely sunk. There is no elapsed-time victory, deadline defeat, recurring enemy population, or distance-based despawn in campaign mode. Every listed enemy remains accounted for until sunk. A voyage ends in victory only after the last group has deployed and every authored ship is sunk. Hull reaching zero ends in defeat.

`objective` is always `{"type": "fleet", "target": N}`, where N exactly equals the sum of all encounter ship counts. Collecting treasure, waiting, or sinking a flagship while its escorts remain cannot finish the level. Boss levels list their flagship exactly once in their final encounter; the boss configuration is combat data, not a separate spawn trigger.

Levels 1–3 contain 3, 4, and 6 ships in groups of no more than three. Later missions contain 8–14 ships in two or three groups, with at most five ships simultaneously active. Encounter sizes deliberately stay small enough for readable portrait combat and repeated short sessions.

## Source schema

A level supplies `id`, `name`, `biome`, `enemy_strength`, `layout`, `encounters`, `objective`, `reward`, `star_targets`, `boss`, `briefing`, `design_note`, and `tutorial`.

```json
{
  "id": 2,
  "name": "Coral Courtesy",
  "biome": "sunlit_shoals",
  "objective": {"type": "fleet", "target": 4},
  "layout": {
    "id": "coral_gate",
    "name": "Coral Gate",
    "archetype": "fork",
    "challenge": "Twin-island fork",
    "bounds": [-950, -800, 1900, 1600],
    "player_spawn": [-850, 0],
    "player_heading": 0,
    "islands": [
      {"id": "example_island", "pos": [0, -240], "radius": 160, "trees": 3}
    ],
    "hazards": [],
    "pickups": [
      {"id": "example_supply", "type": "repair", "pos": [-730, 0]}
    ]
  },
  "encounters": [
    {
      "id": "l02_fleet_1",
      "name": "Gate Watch",
      "delay": 0,
      "formation": "line",
      "ships": [
        {"id": "l02_f1_ship_1", "kind": "chaser", "pos": [-500, -60], "heading": 3.141593},
        {"id": "l02_f1_ship_2", "kind": "chaser", "pos": [-500, 60], "heading": 3.141593}
      ]
    },
    {
      "id": "l02_fleet_2",
      "name": "Outer Patrol",
      "delay": 2,
      "formation": "line",
      "ships": [
        {"id": "l02_f2_ship_1", "kind": "chaser", "pos": [270, -60], "heading": 3.141593},
        {"id": "l02_f2_ship_2", "kind": "chaser", "pos": [270, 60], "heading": 3.141593}
      ]
    }
  ]
}
```

The example illustrates field types; `data/campaign.json` contains the complete, validated map.

Coordinates are world units with +X east/right and +Y south/down. `bounds` is `[minimum_x, minimum_y, width, height]`. Headings are radians from +X. Arrays of two numbers are converted to Godot vectors. An island is a circular solid obstacle with decorative trees. Every pickup and hazard has an exact authored position.

Hazards carry `pos`, `type`, `radius`, `damage`, `force`, `period`, `duration`, and `phase`. A current has no direct damage. Mines and whirlpools create danger circles. Storms have two active seconds in a nine-second cycle, with an intervening safe phase. Contact damage uses a grace period rather than applying once per frame.

The six enemy keys are `chaser`, `skirmisher`, `sniper`, `rammer`, `runner`, and `boss`; their base combat statistics and asset references remain in the global `enemies` dictionary. Ships have globally unique IDs so encounter accounting never depends on names or current screen visibility. `formation` explains the authored arrangement; runtime movement starts from the explicit ship coordinates.

Campaign levels intentionally omit the legacy `spawn_interval`, `max_enemies`, `enemy_pool`, `waves`, `spawn_pattern`, `spawn_safe_radius`, `treasure_count`, `treasure_value`, `powerups`, `powerup_interval`, `hazards`, and `duration_limit` fields at the level root. Geography, supplies, and enemies come from `layout` and `encounters`. The global `endless` tuning is retained for Endless Ocean.

## Geography and attack routes

Each biome contains all ten obstacle graphs below, with different orientations, enemy compositions, hazard placements, supplies, and encounter sizes. Maps include eastbound, westbound, southbound, and diagonal approaches as well as loops around islands and branching routes. The variation changes how players approach a fight, rather than only changing the number of enemies.

| Archetype | Spatial challenge |
|---|---|
| `open_cove` | A substantial headland divides open water into a direct approach and a protected outer bypass. |
| `fork` | Two 160-radius islands leave a 160-unit center gate; broad outside routes lead around either shore. |
| `citadel` | A 210-radius central island forces travel around the coast. Fleets occupy southern, western, and northern arcs. |
| `z_convoy` | Two large offset islands bend the attack route into a Z between southeast, western, and northeast fighting basins. |
| `atoll` | Six separate islets enclose a harbor with wide entrance and exit gates. Fleets guard the outside approach, inside water, and exit. |
| `crossroads` | Three large headlands define south, west, and east arms. Fleet groups occupy different branches. |
| `s_channel` | Four large alternating islands protect eastern, western, and eastern fleet pockets along an S-shaped crossing. |
| `archipelago` | Seven islands form several connected cross-channels between southeast, central, and northwest battle pockets. |
| `reef_perimeter` | Eight reef islands surround an open inner sea. Encounters follow its west, north, and east edges. |
| `boss_court` | Outer escort groups occupy opposing bays; the named flagship and its escorts fight in the open central court. |

The largest island radius is 210 units; a whole citadel coast is visible on a map thumbnail. The largest rotated map spans 2,829 world units on either axis. Every map remains rectangular, with all physical content contained inside it. Terrain appears at authored positions and cannot regenerate into a different shape during a campaign voyage.

The source intentionally leaves multiple safe attack and retreat routes. Narrow-looking island gates are checked for a real navigable route at the runtime's 48-unit navigation inflation. For example, twin-island forks have a 160-unit center gate in addition to their outer flanks.

## Biomes

| Levels | Biome | Main enemies and hazards | Visual theme |
|---|---|---|---|
| 1–10 | Sunlit Shoals | Readable deckhands, orbiters, treasure escorts; a gentle current late in the set | Turquoise water, coral, sandy palm islands |
| 11–20 | Mangrove Maze | Orbiting skirmishers, rammers, and currents around large roots and branches | Emerald water, mangroves, driftwood |
| 21–30 | Ember Archipelago | Sniper crossfire, ramming escorts, and placed powder kegs | Volcanic rock, black sand, warm embers |
| 31–40 | Frostwake Reach | Large iceberg channels, fast rammers, distant batteries, and storm cells | Arctic blue water, snow and ice |
| 41–50 | Tempest Crown | Mixed formations, whirlpools, mines, and timed storm lanes | Purple storm water and a golden final flagship |

## All 50 encounters

The route column gives compass directions between the player start and successive fleet centers. It describes the approach sequence, while islands and hazard circles determine the available water routes. Fleet sizes list each group in deployment order.

| # | Level | Obstacle graph | Route | Fleet sizes |
|---:|---|---|---|---|
| 1 | First Broadside | open cove | NE | 3 |
| 2 | Coral Courtesy | fork | E → E | 2 + 2 |
| 3 | Two-Sided Trouble | citadel | W → SW | 3 + 3 |
| 4 | Gold Rush Bay | z convoy | NE → N | 3 + 3 |
| 5 | Round the Palms | atoll | S → S | 3 + 4 |
| 6 | Broadside Boulevard | crossroads | E → NE | 4 + 4 |
| 7 | Treasure Tailwind | s channel | NW → W | 3 + 4 |
| 8 | Sloop Soup | archipelago | W → SW → SW | 3 + 3 + 2 |
| 9 | Sunset Skirmish | reef perimeter | SE → SW → NW | 3 + 4 + 2 |
| 10 | Captain Coconut | boss court | NW → NE → SW | 2 + 2 + 3 |
| 11 | Greenwater Greeting | fork | E → E → E | 3 + 4 + 1 |
| 12 | Current Affairs | s channel | N → NW → E | 3 + 4 + 1 |
| 13 | Mangrove Mouths | atoll | S → S → S | 3 + 3 + 3 |
| 14 | Driftwood Derby | z convoy | NW → W → N | 3 + 3 + 3 |
| 15 | Smuggler's Shortcut | archipelago | W → SW → SW | 3 + 4 + 3 |
| 16 | Root and Cannon | citadel | NE → N → E | 3 + 4 + 3 |
| 17 | Swamp Carousel | reef perimeter | NW → NE → SE | 3 + 4 + 3 |
| 18 | Ram Jam | crossroads | S → SE → W | 3 + 4 + 3 |
| 19 | Last Light Lagoon | open cove | SE → E → SE | 3 + 4 + 4 |
| 20 | Admiral Alligator | boss court | SW → NW → SE | 3 + 2 + 4 |
| 21 | Welcome to the Boom | open cove | NW → W → NW | 3 + 4 + 3 |
| 22 | Powder Keg Picnic | archipelago | S → SE → SE | 3 + 4 + 3 |
| 23 | Longshot Lookout | citadel | NE → N → E | 3 + 4 + 4 |
| 24 | Black Sand Sprint | s channel | E → NE → S | 3 + 4 + 5 |
| 25 | Cinder Smugglers | z convoy | N → NW → NE | 3 + 4 + 3 |
| 26 | Ash and Splash | crossroads | NW → W → NE | 4 + 4 + 4 |
| 27 | Ember Evasion | atoll | S → S → S | 3 + 4 + 4 |
| 28 | Barrel Roll Bay | reef perimeter | SW → NW → NE | 4 + 4 + 4 |
| 29 | The Last Hot Haul | fork | E → E → E | 3 + 4 + 5 |
| 30 | Commodore Cinder | boss court | NW → NE → SW | 3 + 3 + 4 |
| 31 | Cold Open | fork | S → S → S | 4 + 4 + 4 |
| 32 | Iceberg Express | s channel | NW → W → NE | 4 + 4 + 4 |
| 33 | Snowball Fight | archipelago | E → NE → NE | 4 + 4 + 4 |
| 34 | Polar Pursuit | z convoy | N → NW → NE | 4 + 4 + 5 |
| 35 | Frozen Fortune | atoll | W → W → W | 4 + 4 + 4 |
| 36 | Hull on Ice | crossroads | S → SE → W | 4 + 4 + 5 |
| 37 | Whiteout Watch | citadel | NE → N → E | 4 + 4 + 4 |
| 38 | Berg Brawl | reef perimeter | NE → SE → SW | 4 + 5 + 5 |
| 39 | Northern Lights Heist | open cove | N → NW → N | 4 + 5 + 5 |
| 40 | Baron Blizzard | boss court | SE → SW → NE | 4 + 3 + 4 |
| 41 | Eye of the Tide | citadel | NE → N → E | 4 + 4 + 4 |
| 42 | Stormbound Spoils | archipelago | W → SW → SW | 4 + 4 + 4 |
| 43 | Crown's Crossfire | fork | S → S → S | 4 + 4 + 5 |
| 44 | Whirlpool Waltz | atoll | E → E → E | 4 + 4 + 5 |
| 45 | Royal Ransom | z convoy | NW → W → N | 4 + 5 + 5 |
| 46 | Thunderstruck Fleet | crossroads | N → NW → E | 4 + 5 + 5 |
| 47 | The Sea Bites Back | s channel | E → NE → S | 4 + 5 + 5 |
| 48 | Last Broadside Standing | reef perimeter | SE → SW → NW | 4 + 5 + 5 |
| 49 | Crown Jewel Caper | open cove | NW → W → NW | 4 + 5 + 5 |
| 50 | The Pirate Monarch | boss court | N → E → W | 4 + 4 + 4 |

The five flagships are Captain Coconut (220 hull), Admiral Alligator (300), Commodore Cinder (380), Baron Blizzard (460), and the Pirate Monarch (600). Their attack patterns are broadside, charge, fan, charge, and spiral. Their speed, damage, cooldown, and cannon count use their explicit boss dictionaries; fan attacks add two spread shots to their base count. All escorts must also be sunk.

Map previews are available for [Sunlit Shoals](campaign_maps/sunlit_shoals.png), [Mangrove Maze](campaign_maps/mangrove_maze.png), [Ember Archipelago](campaign_maps/ember_archipelago.png), [Frostwake Reach](campaign_maps/frostwake_reach.png), and [Tempest Crown](campaign_maps/tempest_crown.png).

## Stars, rewards, and per-ship progression

A victory earns one star. Finishing within `star_targets.time` earns another, and remaining hull ratio at or above `star_targets.health` earns the third. The current threshold is 0.6. `star_targets.score` is reference tuning and does not create an extra star. Persist each level's best result, capped at three; replaying a level cannot inflate the total above 150.

`reward.coins` and `reward.xp` are additional first-clear rewards, paid once per shared level under `campaign:<level_id>`. Collected treasure and battle XP remain available on every voyage, including replays. The retained `reward.first_clear_bonus` field is reference tuning and is not paid separately. The progression implementation is authoritative for accounting.

Battle XP is `15 + 5 × ships sunk + floor(seconds sailed / 5)`. Each ship starts at rank 1. Reaching rank N+1 requires cumulative XP `120 × N × (N + 1) / 2`, up to rank 20. Each earned rank adds the ship's authored hull and damage increments and reduces its side-cooldown multiplier by 0.01, with a 0.65 floor.

The supplied Kenney ships, terrain, UI, foliage, and audio remain the visual foundation. Full ship PNGs have their bows toward the image bottom; the renderer applies its rotation offset to match world heading. Intact player variants are green `ship (4).png` for Swiftfin, skull `ship (2).png` for Ironclad, red `ship (3).png` for Redwake, and gold `ship (6).png` for Golden Gull, under `res://Assets/PirateStuff/PNG/Retina/Ships/`.

| Ship | Hull | Speed | Damage per cannonball | Cannonballs per side | Side cooldown |
|---|---:|---:|---:|---:|---:|
| Swiftfin | 85 | 170 | 20 | 2 | 0.8s |
| Ironclad | 150 | 110 | 26 | 3 | 1.4s |
| Redwake | 110 | 140 | 28 | 2 | 1.1s |
| Golden Gull | 100 | 150 | 22 | 2 | 1.0s |

Speed is world units per second and turning speed is radians per second. Left and right side cooldowns are independent. Swiftfin rewards sharp turns and fast reloads; Ironclad trades speed for hull and a third cannon; Redwake deals the highest individual-shot damage. Golden Gull attracts pickups over 130 units and applies a 20% multiplier to account coin rewards after the voyage. Objective progress and in-voyage treasure displays count actual pickups.

Daily quests and login rewards use the progression service's UTC date keys and merge claimed events across saves. No campaign battle requires a purchase or a ship rank to unlock.

## Endless Ocean

Endless Ocean retains a separate generative ruleset. Its voyage seed controls regenerating world chunks, visual biomes change every 90 seconds, recurring enemy pressure increases over time, and a new boss can arrive every 90 seconds. Enemy, cannonball, particle, pickup, and terrain caches remain bounded.

Campaign never consumes these random population rules. Endless best score and longest survival are persisted independently because they can come from different voyages. It uses the same battle XP formula; the global `xp_per_minute` value remains reference tuning rather than a second XP payment.

## Achievements

Icons are `store/achievements/<id>.png`, with each exact path included in the JSON. The `condition` field is `{metric, target}`; top-level `metric` and `target` are included for simple consumers. Incremental achievements use lifetime counts. Unique completed levels and best per-level stars must not grow when replaying the same level.

| ID | Name | Condition | Description |
|---|---|---|---|
| `sea_legs` | Sea Legs | `runs_started` ≥ 1 | Launch your first voyage. |
| `first_broadside` | First Broadside | `cannon_shots` ≥ 1 | Fire a cannon broadside. |
| `first_plunder` | Pocket Change | `coins_collected` ≥ 25 | Collect 25 coins across your voyages. |
| `deck_clear` | Deck Clear | `enemies_sunk` ≥ 25 | Sink 25 enemy ships. |
| `fleet_breaker` | Fleet Breaker | `enemies_sunk` ≥ 100 | Sink 100 enemy ships. |
| `sea_scourge` | Scourge of the Sea | `enemies_sunk` ≥ 500 | Sink 500 enemy ships. |
| `powder_monkey` | Powder Monkey | `cannon_shots` ≥ 250 | Fire 250 cannonballs. |
| `flawless_voyage` | Flawless Voyage | `perfect_victories` ≥ 1 | Win a campaign level without taking damage. |
| `shoal_sheriff` | Sheriff of the Shoals | `campaign_levels_completed` ≥ 10 | Complete 10 campaign levels. |
| `swamp_escape` | Mangrove Marauder | `campaign_levels_completed` ≥ 20 | Complete 20 campaign levels. |
| `hot_streak` | Too Hot to Handle | `campaign_levels_completed` ≥ 30 | Complete 30 campaign levels. |
| `ice_breaker` | Ice Breaker | `campaign_levels_completed` ≥ 40 | Complete 40 campaign levels. |
| `pirate_king` | Pirate Monarch | `campaign_levels_completed` ≥ 50 | Complete all 50 campaign levels. |
| `boss_buster` | Boss Buster | `bosses_sunk` ≥ 1 | Sink your first campaign boss. |
| `tyrant_tamer` | Tyrant Tamer | `bosses_sunk` ≥ 5 | Sink 5 bosses across your voyages. |
| `treasure_tide` | Treasure Tide | `coins_collected` ≥ 1000 | Collect 1,000 coins across your voyages. |
| `power_pirate` | Power Pirate | `powerups_collected` ≥ 25 | Collect 25 powerups. |
| `four_of_a_kind` | Four of a Kind | `ships_played` ≥ 4 | Take all four ships on a voyage. |
| `seasoned_captain` | Seasoned Captain | `ship_rank_max` ≥ 5 | Raise any ship to rank 5. |
| `fleet_of_legends` | Fleet of Legends | `total_ship_ranks` ≥ 20 | Reach a combined ship rank of 20. |
| `endless_appetite` | Endless Appetite | `endless_best_seconds` ≥ 120 | Survive 2 minutes in Endless Ocean. |
| `marathon_marauder` | Marathon Marauder | `endless_best_seconds` ≥ 300 | Survive 5 minutes in Endless Ocean. |
| `high_tide` | High Tide | `endless_best_score` ≥ 20000 | Score 20,000 points in one Endless Ocean voyage. |
| `star_chart` | Star Chart | `campaign_stars` ≥ 75 | Earn 75 stars across the campaign. |
| `constellation_captain` | Constellation Captain | `campaign_stars` ≥ 150 | Earn all 150 campaign stars. |
| `daily_deckhand` | Daily Deckhand | `quests_completed` ≥ 3 | Complete 3 daily quests. |
| `welcome_aboard` | Crew Regular | `daily_rewards_claimed` ≥ 3 | Claim a daily reward on 3 different days. |
| `chain_reaction` | Chain Reaction | `combo_max` ≥ 10 | Build a 10-sink combo in one voyage. |

`perfect_victories` means a won voyage with zero damage taken. `ships_played` counts distinct ship IDs used. `ship_rank_max` is the highest current ship rank, while `total_ship_ranks` sums all four ranks. `combo_max` is the largest sink streak achieved before the game's combo timer expires; the progression service also accepts the arena's `max_combo` summary alias. `cannon_shots` counts individual cannonballs. Daily metrics count claimed/completed entries, not merely offered rewards.

## Leaderboards and Play Games registration

| ID | Name | Metric | Play Games value format |
|---|---|---|---|
| `endless_score` | Endless Ocean: Score | `endless_best_score` | integer |
| `endless_survival` | Endless Ocean: Survival | `endless_best_seconds` | time_milliseconds |
| `campaign_stars` | Campaign: Star Captains | `campaign_stars` | integer |
| `total_plunder` | Lifetime: Total Plunder | `coins_collected` | integer |

Every leaderboard uses higher-is-better ordering. Multiply `endless_best_seconds` by 1,000 and round to an integer before submission; the other board multipliers are 1. Register the corresponding achievements and leaderboards in the Play Console, then fill the returned opaque resource IDs in `google_play_id`. An empty ID must skip network submission gracefully.

The public Android game identifier `837392218124` and OAuth client identifier supplied by the project owner are application configuration, not secret keys. Signing keystores, passwords, private keys, and service credentials must stay out of the repository. The resource IDs cannot be guessed from the names. This content catalog supports offline operation while backend configuration is incomplete.

For incremental achievements, synchronize absolute local totals to Play Games where the plugin offers an absolute step method; otherwise track submitted totals and send only positive deltas. Do not submit the full lifetime value as a fresh increment on every launch.


## Validation and limits

Run `python tools/validate_data.py` from the project directory. The current authored catalog passes 9,585 checks covering:

- Exact total fleet targets, finite encounter ordering, unique ship and encounter IDs, one final flagship per boss map, and removal of random campaign fields.
- World bounds, initial player clearance, hull clearance around islands and damaging hazards, separation between ships in the same fleet, and collectible placement.
- A flood-fill of navigable water using 32-unit grid cells, the runtime's cell-center lattice, 48-unit island inflation, and four-neighbor movement. Every enemy and supply must connect to the player's component. The validator additionally avoids damaging hazard circles with a 40-unit margin.
- Ten different obstacle graphs in every biome and unique physical map geometry after removing all names, IDs, and prose from the comparison.
- Regression fixtures that intentionally introduce an incorrect objective total, an enemy on the player spawn, a player inside an island, a legacy random spawn field, and a sealed inner basin made from non-overlapping islands.
- Ship resource paths, achievement and leaderboard definitions, service icons, and store image dimensions.

A source clearance check proves routes exist; it does not prove that a human can steer them comfortably or that an enemy's movement AI will choose the best one. Engine integration tests and physical Android testing remain separate. Old random-spawn campaign performance numbers should not be used to claim this finite revision has been verified. See [BALANCE.md](BALANCE.md) and the latest test logs for runtime results.

The desired ordinary session is approximately one to three minutes, with a forgiving introduction. Short, well-executed broadside runs may finish faster. Timers award stars rather than replacing the central requirement: sink the complete finite fleet.

