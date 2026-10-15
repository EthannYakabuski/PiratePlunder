# Shipyard upgrades

Each ship has its own nine-purchase upgrade tree. Gold is shared across the fleet; ship rank, bought cannons, grapeshot, and gun crews belong to the selected ship. Ranking up keeps the existing automatic hull, damage, and reload improvements. Rank alone never grants a purchasable weapon or automatic fire.

| Upgrade | Ship rank | Gold | Prerequisites | Effect |
| --- | ---: | ---: | --- | --- |
| Port Cannon I | 4 | 180 | None | One additional port cannon |
| Starboard Cannon I | 6 | 260 | None | One additional starboard cannon |
| Port Grapeshot | 7 | 320 | Port Cannon I | Separate manual port grapeshot control |
| Port Cannon II | 9 | 420 | Port Cannon I | One more port cannon |
| Starboard Grapeshot | 10 | 450 | Starboard Cannon I | Separate manual starboard grapeshot control |
| Starboard Cannon II | 11 | 520 | Starboard Cannon I | One more starboard cannon |
| Port Powder Crew | 17 | 1,200 | Port Grapeshot and Port Cannon II | Automatically fires port grapeshot at broadside targets |
| Starboard Powder Crew | 18 | 1,400 | Starboard Grapeshot and Starboard Cannon II | Automatically fires starboard grapeshot at broadside targets |
| Master Gunner | 20 | 2,800 | Every other upgrade on this ship | Unlocks automatic primary broadsides |

The complete tree costs **7,550 gold per ship**. Swiftfin, Redwake, and Golden Gull start with two primary cannons on each side and can buy up to four. Ironclad starts with three and can buy up to five. Every cannon purchase adds exactly one cannon to its named side.

Grapeshot fires a three-projectile heavy fan on its own side's cooldown. It reloads more slowly than the primary cannons: base cooldown 3.8 seconds, projectile speed 245, spread 0.24 radians, and damage per projectile 1.6 times the ship's upgraded primary damage. Ship rank's reload multiplier also applies to grapeshot. Buying the weapon enables its separate manual control; buying its much later Powder Crew unlocks that side's automatic targeting. Port and starboard reload independently.

Automatic primary fire is disabled by default. Master Gunner is the final purchase and enables the automatic-fire preference immediately, so the paid upgrade works as soon as it is equipped. Owners can switch that preference off. A preference or a flag copied from an older save cannot enable automation on a ship without the required paid upgrades and rank. Auxiliary Powder Crews operate independently of the primary-fire preference.

## Developer contract

`data/upgrades.json` is the catalog. IDs and prices are immutable for save schema 3; if changing a published price or removing a published ID, provide an explicit save migration rather than silently changing paid receipts.

- `Progression.get_ship_upgrades(ship_id)` returns catalog entries enriched with `owned`, `active`, `eligible`, and a human-readable `reason`. `required_rank`, `requires`, `cost`, and `effects` remain available for rendering the tree.
- `Progression.purchase_upgrade(ship_id, upgrade_id)` returns `success`, `message`, `ship_id`, `upgrade_id`, `cost`, and the resulting `gold`. Owned, unknown, rank-gated, prerequisite-gated, and unaffordable purchases fail without charging. Saving happens before success is reported. A failed save rolls back both ownership and spending.
- `Progression.ship_loadout(ship_id)` returns the base ship dictionary with rank-adjusted `hp`, `damage`, and `cooldown`; `cannons_port` and `cannons_starboard`; boolean `secondary_port`, `secondary_starboard`, `secondary_auto_port`, `secondary_auto_starboard`, and `primary_auto`; and numeric `secondary_damage`, `secondary_cooldown`, `secondary_speed`, `secondary_spread`, `secondary_count`, and `secondary_radius`.
- `primary_auto` describes a paid, rank-qualified capability. `effective_primary_auto` additionally requires the `auto_fire` preference. Gameplay must gate automation on the loadout capability even when a preference is manually set to true. Secondary automation is per-side ownership, independent of that primary preference.
- `Progression.owns_upgrade(ship_id, upgrade_id)` reports a valid persisted receipt. `ship_bonus()` retains its original API. `gold_spent()` reports the total unique purchase cost; lifetime `coins_collected` is gross earnings and is never rewritten by spending.

A successful purchase emits `Progression.changed` after writing the save. Existing listeners refresh the UI and queue the next service sync. No Google integration changes are required for this tree: purchase receipts are included in the normal progression snapshot.

## Existing saves and cloud merging

The save filename stays unchanged. Checksum-wrapped version 2 local saves and version 2 cloud snapshots are accepted and migrated to version 3. All previous XP, earned gold, stars, shared level unlocks, achievements, daily rewards, and delivery queues remain intact. Purchases start empty. Only the legacy free `auto_fire` preference is reset to false. Old settings cannot fabricate paid automation.

Each valid purchase is a single immutable receipt keyed by **ship ID and upgrade ID**. Ownership merges by union. The wallet is gross earned gold minus the costs of these unique receipts, so syncing repeatedly cannot charge again, and the same upgrade purchased on two offline devices is charged only once after merging. Stale pre-upgrade saves cannot erase purchases or refund spending.

Different offline devices can each spend a balance before learning about the other's different purchase. Both purchases are preserved; any resulting outstanding spend is covered by future earnings before more gold becomes available. The displayed wallet stays at zero until that balance settles. Each local transaction still requires enough currently available gold, and a purchase is never repeated locally. This is an offline concurrency rule rather than a server-authorized economy or anti-cheat system.

## Verification

`godot --headless --path . --script res://tests/test_progression.gd` passes **165 checks**. Upgrade coverage includes every rank boundary and prerequisite; exact one-cannon increments; individual ship ownership; independent grapeshot/automation gates; locked manual-auto flags; the final capstone preference; immediate persistence; save-failure rollback; insufficient funds; version 2 migration without progress loss; unique charging and union across devices; repeated and stale syncs; and concurrent spending settlement. Existing persistence, campaign, achievement, and service-queue checks also remain passing.
