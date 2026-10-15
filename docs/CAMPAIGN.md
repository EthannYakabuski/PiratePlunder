# PiratePlunder campaign and progression design

This is the authored content contract for the portrait arcade MVP. The campaign has 50 levels across five biomes. Every biome contains combat, treasure, and survival challenges, followed by a flagship boss. The four player ships share campaign unlocks and stars; each ship earns its own experience.

## Content files

- `data/campaign.json`: five palettes, six enemy archetypes, 50 complete level configurations, and Endless Ocean tuning.
- `data/ships.json`: four base stat cards, reused asset paths, perks, and per-ship rank increments.
- `data/achievements.json`: 28 names, descriptions, conditions, icon keys, and blank Play Games IDs.
- `data/leaderboards.json`: four boards, metric bindings, score formats, and blank Play Games IDs.

All files use `schema_version: 1`. Load them with Godot's JSON parser as dictionaries. JSON numbers arrive as numeric variants; convert IDs/counts to integers where necessary.

## Asset review and ship choices

The supplied Kenney Pirate Pack preview and ship PNGs were inspected visually. Its flat, warm, playful style is the visual foundation: wooden brown hulls, thick simple outlines, bright sails, turquoise water, sand islands, and small cartoon explosions. No new player or enemy ship art is required for this MVP. Supplied ship PNGs point upward; rotation should use upward as the ship's forward direction.

| Ship ID | Ship | Reused default-size PNG | Hull | Speed | Damage per ball | Balls per broadside | Side cooldown |
|---|---|---|---:|---:|---:|---:|---:|
| `swiftfin` | Swiftfin | `ship (4).png`, green | 85 | 170 | 20 | 2 | 0.8s |
| `ironclad` | Ironclad | `ship (2).png`, intact skull | 150 | 110 | 26 | 3 | 1.4s |
| `redwake` | Redwake | `ship (3).png`, intact red | 110 | 140 | 28 | 2 | 1.1s |
| `golden_gull` | Golden Gull | `ship (6).png`, gold | 100 | 150 | 22 | 2 | 1.0s |

All ship paths are rooted at `res://Assets/PirateStuff/PNG/Retina/Ships/`. Swiftfin trades hull for maneuvering and reload speed. Ironclad rewards planned turns and close heavy volleys. Redwake has the strongest individual shots and balanced handling. Golden Gull attracts pickups over 130 world units and earns 20% more collected coins. The other ships' pickup radii are 76–88 units.

Speeds are world units per second; `turn_speed` is radians per second. `damage` applies to each cannonball. `cooldown` is independent for the left and right side. These statistics assume a portrait 540×960 reference viewport and a ship displayed at approximately 60–80px high.

## Campaign rules and data contract

Unlock level 1 initially. A victory in level N unlocks N+1 for all ships; replaying an unlocked level is always allowed. Every voyage earns its collected treasure and battle XP. `reward.coins` and `reward.xp` are additional first-clear rewards, paid once per level regardless of ship, and stored under a shared `campaign:<level_id>` reward event. Replays still improve stars, scores, treasure, and ship XP. The older authoring field `reward.first_clear_bonus` remains in the catalog as reference tuning and is not paid separately. The progression implementation is authoritative for reward accounting.

Every level explicitly supplies:

- `id`, `name`, `biome`, and a one-sentence `briefing`.
- `objective: {type, target}`, using `kills`, `coins`, `survive`, or `boss`.
- `duration_limit`, `spawn_interval`, `max_enemies`, weighted `enemy_pool`, and `enemy_strength`.
- `waves: [{at, enemies: [enemy_key, ...]}]` for scheduled additions. Times are elapsed voyage seconds. These additions respect the enemy cap.
- `hazards`, `treasure_count`, `treasure_value`, and `powerup_interval`.
- `boss` as null or a named flagship configuration, plus `star_targets`.

A repeated key in `enemy_pool` increases that archetype's selection probability. The six enemy keys are `chaser`, `skirmisher`, `sniper`, `rammer`, `runner`, and `boss`. Their stats and asset paths are stored under `campaign.enemies`. The runner flees the player and drops more loot. Bosses are larger versions of the supplied pirate ships.

For a coin objective, count actual coins collected during the current voyage, including enemy drops and stationary treasure. Golden Gull's wider pickup radius helps collection; its 20% multiplier applies to account rewards after the voyage, while the objective counter counts actual pickups. `treasure_count` is never lower than a treasure objective's target, so a movement-first solution remains possible.

For survival, win once elapsed seconds meet `objective.target`. For kills, win at the required enemy sink count. For bosses, win when the named flagship sinks. Winning ends the voyage immediately. If health reaches zero or a non-survival deadline expires first, the voyage ends in defeat.

Every victory earns one star. Earn a second star by finishing within `star_targets.time` seconds, and a third for remaining hull ratio ≥ `star_targets.health` (0.6). Persist each level's maximum star count, capped at three. Survival time stars are intentionally forgiving because the objective already fixes the finish time. `star_targets.score` is optional reference tuning and does not add a fourth star.

`spawn_pattern` and `design_note` are descriptive authoring fields. Core gameplay can consume the numerical spawn and wave fields without specialized formation logic. `spawn_safe_radius` prevents hazards or enemies appearing immediately on the player.

## Biomes and challenges

| Range | Biome | Main challenge | Visual theme |
|---|---|---|---|
| 1–10 | Sunlit Shoals | Learn broadsides, easy chasers, treasure runners | Turquoise sea, coral, sandy palm islands |
| 11–20 | Mangrove Maze | Currents, orbiters, charging ships | Green water, mangrove channels, driftwood |
| 21–30 | Ember Archipelago | Kiting snipers and explosive powder kegs | Volcanic rocks, black sand, warm ember lights |
| 31–40 | Frostwake Reach | Iceberg navigation and fast rammers | Arctic blue water, ice floes, bright snow |
| 41–50 | Tempest Crown | Mixed formations, whirlpools, timed storms | Purple sea, stormlight, a golden final flagship |

Hazard tuning:

| Type | Radius | Damage | Other effect |
|---|---:|---:|---|
| `reef` | 42 | 8 | Solid island/rock/iceberg; use biome label and palette |
| `current` | 88 | 0 | 28-unit directional drift |
| `mine` | 25 | 20 | Explosive collision hazard |
| `maelstrom` | 86 | 8 | Pull strength 38 toward the center |
| `storm` | 70 | 12 | Active for 2 seconds every 9 seconds; telegraph before activation |

Damage values are suggested collision or timed-hit amounts, not per-frame amounts. Use contact grace periods. Currents are readable and non-damaging; mines need room between them; storms require visual warnings. Every chunk should reserve a safe area around the player.

## All 50 authored levels

Each row is a distinct objective, enemy mix, timed wave set, and hazard combination. Complete wave lists and intent are in the JSON.

| # | Level | Objective | Deadline | Hazards |
|---:|---|---|---:|---|
| 1 | First Broadside | kills 4 | 90s | None |
| 2 | Coral Courtesy | kills 6 | 95s | 1 coral reef |
| 3 | Two-Sided Trouble | kills 8 | 105s | 2 coral reef |
| 4 | Gold Rush Bay | coins 12 | 100s | 2 coral reef |
| 5 | Round the Palms | survive 50s | 80s | 3 coral reef |
| 6 | Broadside Boulevard | kills 12 | 110s | 2 coral reef |
| 7 | Treasure Tailwind | coins 18 | 115s | 1 tidal current, 1 coral reef |
| 8 | Sloop Soup | kills 15 | 120s | 3 coral reef |
| 9 | Sunset Skirmish | survive 70s | 100s | 4 coral reef |
| 10 | Captain Coconut | boss 1 | 150s | 2 coral reef |
| 11 | Greenwater Greeting | kills 12 | 110s | 1 tidal current, 2 mangrove island |
| 12 | Current Affairs | coins 20 | 110s | 2 tidal current, 1 mangrove island |
| 13 | Mangrove Mouths | kills 14 | 120s | 4 mangrove island |
| 14 | Driftwood Derby | survive 75s | 105s | 2 tidal current, 3 mangrove island |
| 15 | Smuggler's Shortcut | coins 24 | 115s | 3 tidal current |
| 16 | Root and Cannon | kills 18 | 125s | 4 mangrove island, 1 tidal current |
| 17 | Swamp Carousel | survive 85s | 115s | 3 tidal current, 2 mangrove island |
| 18 | Ram Jam | kills 16 | 125s | 2 mangrove island, 1 tidal current |
| 19 | Last Light Lagoon | coins 28 | 130s | 3 tidal current, 3 mangrove island |
| 20 | Admiral Alligator | boss 1 | 160s | 2 tidal current, 2 mangrove island |
| 21 | Welcome to the Boom | kills 16 | 120s | 2 powder keg |
| 22 | Powder Keg Picnic | coins 26 | 125s | 4 powder keg, 1 black-sand rocks |
| 23 | Longshot Lookout | kills 18 | 130s | 2 powder keg, 2 black-sand rocks |
| 24 | Black Sand Sprint | survive 85s | 115s | 3 powder keg, 1 tidal current |
| 25 | Cinder Smugglers | coins 30 | 130s | 5 powder keg |
| 26 | Ash and Splash | kills 22 | 135s | 3 powder keg, 3 black-sand rocks |
| 27 | Ember Evasion | survive 95s | 125s | 4 powder keg, 1 storm front |
| 28 | Barrel Roll Bay | kills 20 | 135s | 6 powder keg |
| 29 | The Last Hot Haul | coins 36 | 140s | 4 powder keg, 2 tidal current |
| 30 | Commodore Cinder | boss 1 | 170s | 3 powder keg |
| 31 | Cold Open | kills 20 | 130s | 3 iceberg |
| 32 | Iceberg Express | coins 32 | 135s | 5 iceberg, 1 tidal current |
| 33 | Snowball Fight | kills 24 | 140s | 3 iceberg |
| 34 | Polar Pursuit | survive 95s | 125s | 4 iceberg, 1 tidal current |
| 35 | Frozen Fortune | coins 38 | 140s | 6 iceberg |
| 36 | Hull on Ice | kills 26 | 145s | 4 iceberg, 2 tidal current |
| 37 | Whiteout Watch | survive 105s | 135s | 3 iceberg, 2 storm front |
| 38 | Berg Brawl | kills 28 | 150s | 5 iceberg |
| 39 | Northern Lights Heist | coins 42 | 150s | 4 iceberg, 2 tidal current |
| 40 | Baron Blizzard | boss 1 | 180s | 3 iceberg, 1 tidal current |
| 41 | Eye of the Tide | kills 26 | 145s | 1 whirlpool |
| 42 | Stormbound Spoils | coins 40 | 145s | 2 storm front, 1 whirlpool |
| 43 | Crown's Crossfire | kills 30 | 150s | 1 whirlpool, 2 storm rocks |
| 44 | Whirlpool Waltz | survive 110s | 140s | 2 whirlpool, 1 tidal current |
| 45 | Royal Ransom | coins 46 | 150s | 1 whirlpool, 3 powder keg |
| 46 | Thunderstruck Fleet | kills 32 | 155s | 3 storm front, 2 storm rocks |
| 47 | The Sea Bites Back | survive 120s | 150s | 2 whirlpool, 1 storm front |
| 48 | Last Broadside Standing | kills 36 | 165s | 1 whirlpool, 2 storm front, 2 powder keg |
| 49 | Crown Jewel Caper | coins 50 | 165s | 2 whirlpool, 3 powder keg |
| 50 | The Pirate Monarch | boss 1 | 180s | 1 whirlpool, 2 storm front |

The five bosses are Captain Coconut (220 hull), Admiral Alligator (300), Commodore Cinder (380), Baron Blizzard (460), and the Pirate Monarch (600). Their attack patterns are broadside, charge, fan, charge, and spiral respectively. Each appears after eight seconds. Regular reinforcement cadence is deliberately slower on boss stages, preserving time to line up attacks.

## Experience and session rewards

Each ship starts at rank 1 and uses the same rank threshold curve. The cumulative XP threshold for reaching rank N+1 is `120 × N × (N + 1) / 2`, with rank capped at 20. Each earned rank adds hull and damage and reduces the side-cooldown multiplier by 0.01, with a 0.65 multiplier floor. The ship JSON carries the exact increments, including Ironclad's extra hull and Redwake's larger damage bonus.

Every voyage earns `15 + 5 × ships sunk + floor(seconds sailed / 5)` battle XP. The first clear also pays the authored `reward.xp`. A ship's base perk works immediately. No content or ship needs a purchase. Coins are a reward score and can support future cosmetic progression; the MVP avoids mandatory grinding.

Daily quest and login reward generation belongs to the progression service. Goals cover sinks, treasure, powerups, successful voyages, firing, and sailing, and should fit one to three runs. The current daily calendar uses UTC date keys consistently across devices. Cloud merge preserves claimed dates and quest progress to prevent accidental double claims.

## Endless Ocean

Endless Ocean uses a fresh voyage seed with deterministic world chunks. Start in Sunlit Shoals and change the visual biome every 90 seconds. Enemy pressure grows from a 5-second spawn interval toward a 1.35-second floor over five minutes. Raise the concurrent enemy cap from 4 to at most 14. Add a named or reskinned boss every 90 seconds and increase enemy strength by 12% per minute.

The ocean continues indefinitely. Island/hazard chunks and offscreen enemies are recycled to keep memory bounded; enemy cap and particle limits take priority over decorative density. Endless runs use the same battle XP formula as campaign runs, including approximately 12 survival XP per minute. The catalog's `xp_per_minute: 20` is reference tuning, not an additional payment. Preserve best score and longest survival independently, because they may come from different voyages.

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

## Assumptions and validation boundaries

- The latest user flow is mode/level selection, then ship selection for that voyage; an initial ship showcase may introduce the four choices on first launch.
- Campaign targets assume forward sailing plus wheel steering, independent left/right cannon buttons, and a one-hand assistance option.
- Level 1 is the optional guided introduction. Levels 1–3 remain forgiving, with at most three simultaneous enemies and 4/6/8 sink targets.
- Typical completion targets are 60–120 seconds; later bosses and demanding levels permit up to three minutes.
- Ship and enemy PNG files were visually checked. JSON structure, IDs, objective consistency, and asset existence are validated independently of gameplay.
- Numerical tuning is an authored starting point. Touch-device playtesting should check every ship, especially broadside hit rates, iceberg congestion, boss attack telegraphs, and late-stage survivability.
- `design_note`, `spawn_pattern`, and music moods are descriptive authoring fields. Boss pattern labels select implemented broadside, charge, fan, or spiral attacks.
- The runtime consumes authored enemy hull, speed, damage, reload, cannon count, coin drops, and score. Per-enemy `xp`, exact authoring `radius`, biome prose, and the `powerups` selection list are reference fields; XP and collision sizes use runtime policies, and supplies draw from the four implemented powerups.
- Cannonball damage scales with the level, but hull uses a softened `0.8 + 0.2 × enemy_strength` scale. Boss speed, damage, reload, cannon count, and attack pattern use their explicit definitions. Fan-pattern bosses add two spread shots to their base cannon count.
- Read [BALANCE.md](BALANCE.md) for automated gameplay results, navigation checks, and limits of headless performance evidence.

