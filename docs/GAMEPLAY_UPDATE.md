# Gameplay update 0.2.0 — October 15, 2026

This revision implements the A–F gameplay feedback. It does not change the Play Games integration or require Google configuration to play.

## A. Choose a voyage, then a ship

The application opens on **Your Next Adventure**, showing shared campaign progress, Endless Seas, Daily Drift, and the Shipyard. Select a mission or mode, then choose the ship for that run. There is no preliminary ship-selection screen.

## B. Manual cannons

New players and migrated players fire their own port/starboard broadsides. Hold a corner cannon to repeat shots when that side reloads. The ship maintains its heading while the wheel is released. Mouse/touch releases are captured even over other UI, and pausing clears held controls, preventing unwanted firing after resuming.

Automatic primary fire is available only after purchasing **Master Gunner** at ship rank 20, with all preceding upgrades installed. A saved preference or settings toggle cannot grant the ability. Manual firing retains its existing small amount of aim assistance within the selected broadside arc.

## C. One additional cannon at a time

The Shipyard uses earned gold and separate ship ranks. Port Cannon I unlocks at rank 4, Starboard Cannon I at 6, Port Cannon II at 9, and Starboard Cannon II at 11. Each purchase adds exactly one cannon to that side. Other ships and the opposite side retain their own configuration. Passive hull, damage and reload bonuses still come from rank progression.

## D. Separate secondary guns

Port and starboard grapeshot controls unlock at ranks 7 and 10 respectively. Each fires a three-shot heavy fan, slows hit rivals briefly, and has its own cooldown independent of both primary broadsides and the other secondary gun. Buttons appear above their side's cannon only after purchase; desktop keys are Z/C. Grapeshot remains manual until its side's Powder Crew upgrade is bought at rank 17/18. [Full upgrade tree, costs and save rules](UPGRADES.md).

## E. Enemies respect islands

Every ship uses the same island geometry, bounded-water rules and swept movement resolution. Campaign enemies find routes through an inflated navigation grid, with local avoidance and shoreline recovery. Endless enemies also avoid and collide with regenerated islands. Enemy shots and player shots respect solid land. Distant campaign enemies are indicated at the edge of the battle view and remain part of their authored fleet.

## F. Finite authored campaign

All 50 levels now define their own world bounds, starting point/heading, island geometry, hazard and supply positions, enemy types, ship coordinates and finite encounter groups. Across the campaign there are 142 named encounters containing 526 enemy ships. No random spawner, replenishment wave, procedural island generator or enemy distance culling runs in campaign mode.

Each biome includes ten spatial designs: open cove, twin fork, central citadel, Z-convoy, split atoll, three-arm crossroads, S-channel, split archipelago, reef perimeter and open boss court. Routes approach from different compass directions; fleets use columns, arcs, gates, crossfires and perimeter patrols. Group compositions, hazards, map dimensions and routes vary across biomes. Bosses are explicit members of the final fleet and cannot be duplicated by a timer.

Later groups deploy after the previous group is cleared and a short announced interval. The HUD shows the exact fleet total and current encounter. Victory requires **all planned groups deployed, every authored ship sunk, and no enemies still alive**. A low kill target or elapsed timer cannot end the mission in mid-battle. Time goals now affect stars rather than forcing a premature campaign ending. Endless and Daily Drift keep their separate procedural/timed rules.

Review the exact maps in [Sunlit Shoals](campaign_maps/sunlit_shoals.png), [Mangrove Maze](campaign_maps/mangrove_maze.png), [Ember Archipelago](campaign_maps/ember_archipelago.png), [Frostwake Reach](campaign_maps/frostwake_reach.png), and [Tempest Crown](campaign_maps/tempest_crown.png). These diagrams are generated from the actual level data, not concept images. Rebuild them with `tools/preview_campaign.py`.

## Existing progress

Version-2 saves migrate to version 3 without resetting XP, earned gold, campaign unlocks, stars, achievements or daily rewards. The old free-auto-fire preference is reset. Purchased upgrades use durable per-ship receipts; repeated saves/merges cannot charge for one upgrade twice. Failed saves roll back a purchase. APK version code 2 allows updating the prior version with the same debug signing identity.

## Verification and remaining limits

Current results are recorded in [VALIDATION.md](VALIDATION.md), with upgrade tests in [UPGRADES.md](UPGRADES.md) and authored schemas in [CAMPAIGN.md](CAMPAIGN.md). The tests cover legacy saves, upgrade gates, per-side cooldowns, exact fleet spawning, deferred encounter completion, swept land collisions, enemy navigation and bounded endless simulation. Phone/tablet layouts are rendered at their native capture sizes.

Physical Android touch ergonomics, thermal behavior and sustained mobile performance still need device testing. The user's Google backend configuration remains outside this gameplay revision.
