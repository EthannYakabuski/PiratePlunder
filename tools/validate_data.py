#!/usr/bin/env python3
"""Validate authored PiratePlunder content, asset links, and Play registration catalogs."""
from __future__ import annotations
import argparse
import copy
import math
from collections import deque
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []
checks = 0

def check(condition: bool, label: str) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(label)

def read(name: str) -> dict:
    path = ROOT / "data" / f"{name}.json"
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    check(payload.get("schema_version") == 1, f"{name}: supported schema")
    return payload

def resource(path: str) -> Path:
    check(path.startswith("res://"), f"Godot resource path: {path}")
    return ROOT / path.removeprefix("res://")

def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as file:
        header = file.read(24)
    check(header[:8] == b"\x89PNG\r\n\x1a\n", f"Valid PNG: {path.relative_to(ROOT)}")
    return struct.unpack(">II", header[16:24])

def unique(records: list[dict], field: str, label: str) -> None:
    values = [entry[field] for entry in records]
    check(len(values) == len(set(values)), f"Unique {label}")

def distance(first: list[float], second: list[float]) -> float:
    return math.hypot(first[0] - second[0], first[1] - second[1])

def validate_stage(stage: dict, enemies: dict, verify=check) -> None:
    ident = stage["id"]
    label = f"Level {ident}"
    layout = stage["layout"]
    groups = stage["encounters"]
    bounds = layout["bounds"]
    min_x, min_y, width, height = bounds
    max_x, max_y = min_x + width, min_y + height
    islands, hazards, pickups = layout["islands"], layout["hazards"], layout["pickups"]
    all_ships = [vessel for group in groups for vessel in group["ships"]]
    legacy = {"spawn_interval","max_enemies","enemy_pool","waves","hazards","treasure_count","treasure_value","spawn_pattern","spawn_safe_radius","powerups","powerup_interval","duration_limit"}
    verify(not (set(stage) & legacy), f"{label}: no procedural campaign or timer fields")
    verify(stage["objective"] == {"type":"fleet","target":len(all_ships)}, f"{label}: victory requires exactly every authored ship")
    verify(1 <= len(groups) <= 3, f"{label}: one to three finite encounters")
    verify(groups[0]["delay"] == 0 and all(group["delay"] == 2 for group in groups[1:]), f"{label}: first fleet immediate and next fleets delayed after clear")
    verify(800 <= width <= 3000 and 1100 <= height <= 3000, f"{label}: playable finite world dimensions")
    verify(1 <= len(islands) <= 8, f"{label}: deliberate bounded island count")
    verify(0 <= stage["star_targets"]["health"] <= 1 and stage["star_targets"]["time"] > 0, f"{label}: valid star targets")
    verify(stage["reward"]["xp"] > 0 and stage["reward"]["coins"] > 0, f"{label}: clear rewards retained")
    def contained(pos: list[float], margin: float) -> bool:
        return min_x + margin <= pos[0] <= max_x - margin and min_y + margin <= pos[1] <= max_y - margin
    def clear_islands(pos: list[float], margin: float) -> bool:
        return all(distance(pos, island["pos"]) >= island["radius"] + margin for island in islands)
    def clear_danger(pos: list[float], margin: float) -> bool:
        return all(hazard["type"] == "current" or distance(pos, hazard["pos"]) >= hazard["radius"] + margin for hazard in hazards)
    player = layout["player_spawn"]
    verify(contained(player, 52), f"{label}: player within boundary with hull clearance")
    verify(clear_islands(player, 48), f"{label}: player spawn clear of islands")
    verify(clear_danger(player, 48), f"{label}: player spawn outside damaging hazards")
    verify(math.isfinite(layout["player_heading"]), f"{label}: finite initial heading")
    for index, island in enumerate(islands):
        verify(island["radius"] >= 50 and contained(island["pos"], island["radius"] + 20), f"{label}: island {index+1} wholly within map")
        verify(0 <= island["trees"] <= 5, f"{label}: bounded decoration count")
        for other in islands[index+1:]:
            verify(distance(island["pos"], other["pos"]) >= island["radius"] + other["radius"] + 48, f"{label}: islands do not overlap and leave water gaps")
    for hazard in hazards:
        verify(hazard["type"] in {"reef","current","mine","maelstrom","storm"}, f"{label}: known hazard type")
        verify(hazard["radius"] > 0 and contained(hazard["pos"], hazard["radius"] + 20), f"{label}: hazard within map")
        verify(clear_islands(hazard["pos"], hazard["radius"] + 24), f"{label}: hazard circle clear of islands")
        verify(hazard["damage"] >= 0 and hazard["force"] >= 0, f"{label}: finite nonnegative hazard tuning")
        if hazard["type"] == "storm":
            verify(0 < hazard["duration"] < hazard["period"], f"{label}: storm has safe and active windows")
    for group in groups:
        verify(1 <= len(group["ships"]) <= 5, f"{label}: manageable active fleet size")
        verify(bool(group["name"]) and bool(group["id"]), f"{label}: named encounter")
        for index, vessel in enumerate(group["ships"]):
            radius = 48 if vessel["kind"] == "boss" else 28
            verify(vessel["kind"] in enemies, f"{label}: known authored ship archetype")
            verify(contained(vessel["pos"], radius + 20), f"{label}: {vessel['id']} within world with hull clearance")
            verify(clear_islands(vessel["pos"], radius + 20), f"{label}: {vessel['id']} outside islands")
            verify(clear_danger(vessel["pos"], radius + 20), f"{label}: {vessel['id']} outside damaging hazards")
            verify(math.isfinite(vessel["heading"]), f"{label}: finite ship heading")
            for other in group["ships"][index+1:]:
                other_radius = 48 if other["kind"] == "boss" else 28
                verify(distance(vessel["pos"], other["pos"]) >= radius + other_radius + 24, f"{label}: active fleet ships do not overlap")
        if group is groups[0]:
            verify(all(distance(vessel["pos"], player) >= 180 for vessel in group["ships"]), f"{label}: initial fleet has player spawn clearance")
    for pickup in pickups:
        verify(pickup["type"] in {"coin","repair","shield","rapid","magnet"}, f"{label}: implemented supply type")
        verify(contained(pickup["pos"], 36), f"{label}: supply within map")
        verify(clear_islands(pickup["pos"], 32), f"{label}: supply clear of islands")
        verify(clear_danger(pickup["pos"], 32), f"{label}: supply outside damaging hazards")
        verify(all(distance(pickup["pos"], vessel["pos"]) >= (48 if vessel["kind"] == "boss" else 28) + 30 for vessel in all_ships), f"{label}: supply not hidden under an authored ship")
    boss_ships = [vessel for vessel in all_ships if vessel["kind"] == "boss"]
    verify(len(boss_ships) == (1 if stage.get("boss") else 0), f"{label}: flagship appears exactly once when configured")
    if stage.get("boss"):
        verify(any(vessel["kind"] == "boss" for vessel in groups[-1]["ships"]), f"{label}: flagship belongs to final fleet")
        verify("at" not in stage["boss"], f"{label}: boss arrival is encounter based")
        verify(stage["boss"]["hp"] > 0 and stage["boss"]["cannon_count"] > 0, f"{label}: valid flagship stats")
    # Flood-fill navigable water for a ship with a generous 48-unit radius.
    # Damaging hazards are also blocked, proving that every target has a safe route.
    cell = 32
    columns = int((width - 96) // cell) + 1
    rows = int((height - 96) // cell) + 1
    def point(key: tuple[int,int]) -> list[float]:
        return [min_x + 48 + key[0]*cell, min_y + 48 + key[1]*cell]
    water = {(x,y) for x in range(columns) for y in range(rows) if clear_islands(point((x,y)), 48) and clear_danger(point((x,y)), 40)}
    def nearest(pos: list[float]) -> tuple[int,int] | None:
        anchor_x = round((pos[0] - min_x - 48) / cell)
        anchor_y = round((pos[1] - min_y - 48) / cell)
        candidates = [(x,y) for x in range(anchor_x-2,anchor_x+3) for y in range(anchor_y-2,anchor_y+3) if (x,y) in water and distance(point((x,y)),pos) <= cell*1.6]
        return min(candidates, key=lambda key: distance(point(key),pos)) if candidates else None
    origin = nearest(player)
    verify(origin is not None, f"{label}: player has navigable water")
    visited = set()
    if origin is not None:
        visited.add(origin)
        queue = deque([origin])
        while queue:
            x,y = queue.popleft()
            for key in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if key in water and key not in visited:
                    visited.add(key)
                    queue.append(key)
    for target in all_ships + pickups:
        destination = nearest(target["pos"])
        verify(destination in visited, f"{label}: navigable route to {target['id']} without crossing islands or danger")

def validator_regression_checks(stage: dict, enemies: dict) -> None:
    def rejects(mutated: dict, expected: str) -> bool:
        errors = []
        validate_stage(mutated, enemies, lambda condition, label: errors.append(label) if not condition else None)
        return any(expected in error for error in errors)
    bad = copy.deepcopy(stage)
    bad["objective"]["target"] += 1
    check(rejects(bad, "exactly every authored ship"), "Validator rejects a victory count that leaves a ship unaccounted for")
    bad = copy.deepcopy(stage)
    bad["encounters"][0]["ships"][0]["pos"] = bad["layout"]["player_spawn"].copy()
    check(rejects(bad, "player spawn clearance"), "Validator rejects an enemy on the player's spawn")
    bad = copy.deepcopy(stage)
    bad["layout"]["islands"][0]["pos"] = bad["layout"]["player_spawn"].copy()
    check(rejects(bad, "player spawn clear"), "Validator rejects a player embedded in an island")
    bad = copy.deepcopy(stage)
    bad["spawn_interval"] = 3
    check(rejects(bad, "no procedural campaign"), "Validator rejects legacy random-spawn fields")
    # A ring with real water gaps that are too narrow for a ship. Simple
    # non-overlap tests pass, but flood-fill must detect the sealed inner basin.
    bad = copy.deepcopy(stage)
    bad["layout"]["bounds"] = [-600,-750,1200,1500]
    bad["layout"]["player_spawn"] = [0,0]
    bad["layout"]["islands"] = [{"pos":[round(math.cos(index*math.pi/4)*260),round(math.sin(index*math.pi/4)*260)],"radius":75,"trees":0} for index in range(8)]
    bad["layout"]["hazards"] = []
    bad["layout"]["pickups"] = []
    for index, vessel in enumerate(bad["encounters"][0]["ships"]):
        vessel["pos"] = [(index-1)*120,-550]
    check(rejects(bad, "navigable route"), "Validator detects an enclosed basin despite non-overlapping islands")

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-media", action="store_true", help="Validate content while store icons are still being generated.")
    args = parser.parse_args()
    campaign = read("campaign")
    ships = read("ships")["ships"]
    achievements = read("achievements")["achievements"]
    boards = read("leaderboards")["leaderboards"]
    levels, biomes, enemies = campaign["levels"], campaign["biomes"], campaign["enemies"]
    check(len(levels) == 50, "Exactly 50 campaign levels")
    check(len(biomes) == 5, "Exactly five biomes")
    check(len(ships) == 4, "Exactly four ships")
    check(len(achievements) >= 20, "At least 20 achievement definitions")
    check(3 <= len(boards) <= 5, "Three to five leaderboard definitions")
    for records, label in ((levels,"levels"),(biomes,"biomes"),(ships,"ships"),(achievements,"achievements"),(boards,"boards")):
        unique(records, "id", label)
    unique(levels, "name", "level names")
    check([entry["id"] for entry in levels] == list(range(1,51)), "Sequential numeric level IDs")
    check({entry["id"] for entry in ships} == {"swiftfin","ironclad","redwake","golden_gull"}, "Progression ship IDs match")
    biome_ids = {entry["id"] for entry in biomes}
    for biome in biomes:
        check(sum(stage["biome"] == biome["id"] for stage in levels) == 10, f"{biome['id']}: ten levels")
        check(all(key in biome["colors"] for key in ("water","sand","accent")), f"{biome['id']}: complete palette")
    for enemy_id, enemy in enemies.items():
        check(resource(enemy["asset"]).is_file(), f"{enemy_id}: existing sprite")
        check(all(enemy[field] > 0 for field in ("hp","speed","damage","cooldown")), f"{enemy_id}: positive stats")
    for ship in ships:
        check(resource(ship["asset"]).is_file(), f"{ship['id']}: existing sprite")
        check(all(ship[field] > 0 for field in ("hp","speed","turn_speed","damage","cooldown","cannon_count")), f"{ship['id']}: positive stats")
        check(ship["progression"]["max_rank"] >= 5 and ship["progression"]["xp_per_rank"] > 0, f"{ship['id']}: usable XP curve")
        check(ship["perk"]["pickup_radius"] > 0 and ship["perk"]["coin_multiplier"] >= 1, f"{ship['id']}: defined perk")
    check(campaign.get("campaign_format") == "finite_authored_fleets_v2", "Finite authored campaign format")
    boss_ids = []
    world_signatures = set()
    encounter_ids = []
    ship_ids = []
    ship_total = 0
    formation_types = set()
    for stage in levels:
        validate_stage(stage, enemies)
        ship_total += stage["objective"]["target"]
        encounter_ids.extend(group["id"] for group in stage["encounters"])
        ship_ids.extend(vessel["id"] for group in stage["encounters"] for vessel in group["ships"])
        formation_types.update(group["formation"] for group in stage["encounters"])
        # IDs, names, descriptions, and pickup labels cannot make copied maps
        # appear unique. Compare only physical water, land, and danger geometry.
        physical = {"bounds":stage["layout"]["bounds"], "spawn":stage["layout"]["player_spawn"], "islands":[(island["pos"],island["radius"]) for island in stage["layout"]["islands"]], "hazards":[(hazard["type"],hazard["pos"],hazard["radius"]) for hazard in stage["layout"]["hazards"]]}
        signature = json.dumps(physical, sort_keys=True)
        check(signature not in world_signatures, f"Level {stage['id']}: unique physical geography independent of names and IDs")
        world_signatures.add(signature)
        if stage.get("boss"):
            boss_ids.append(stage["id"])
    check(len(encounter_ids) == len(set(encounter_ids)), "Globally unique encounter IDs")
    check(len(ship_ids) == len(set(ship_ids)), "Globally unique authored ship IDs")
    check(boss_ids == [10,20,30,40,50], "One explicit finale boss per biome")
    check(len(formation_types) >= 5, "At least five authored formation shapes")
    known_archetypes = {entry["id"] for entry in campaign["layout_archetypes"]}
    check(len(known_archetypes) == 10, "Ten materially distinct obstacle graphs")
    for biome in biomes:
        local_archetypes = {stage["layout"]["archetype"] for stage in levels if stage["biome"] == biome["id"]}
        check(local_archetypes == known_archetypes, f"{biome['id']}: all ten obstacle graphs represented")
    check([stage["objective"]["target"] for stage in levels[:3]] == [3,4,6], "Gradual three-level opening fleets")
    check(all(8 <= stage["objective"]["target"] <= 14 for stage in levels[10:]), "Later finite missions contain eight to fourteen ships")
    validator_regression_checks(levels[0], enemies)
    check(campaign["endless"]["max_enemies_cap"] <= 20, "Endless cap suitable for mobile")
    metrics = {"runs_started","enemies_sunk","cannon_shots","coins_collected","powerups_collected","bosses_sunk","perfect_victories","campaign_levels_completed","campaign_stars","ships_played","ship_rank_max","total_ship_ranks","endless_best_seconds","endless_best_score","quests_completed","daily_rewards_claimed","combo_max"}
    for entry in achievements:
        check(entry["metric"] in metrics and entry["target"] > 0, f"{entry['id']}: valid achievement metric")
        check(entry["condition"] == {"metric":entry["metric"],"target":entry["target"]}, f"{entry['id']}: condition fields agree")
        check(len(entry["name"]) <= 100 and len(entry["description"]) <= 500, f"{entry['id']}: Play text limits")
        check(entry["icon_key"] == entry["id"], f"{entry['id']}: stable icon key")
    for entry in boards:
        check(entry["metric"] in metrics and entry["order"] == "descending", f"{entry['id']}: valid board metric")
        check(entry["value_multiplier"] in (1,1000), f"{entry['id']}: score conversion")
    if not args.skip_media:
        for entry in achievements + boards:
            icon = resource(entry["icon"])
            check(icon.is_file(), f"{entry['id']}: generated icon exists")
            if icon.is_file():
                check(png_size(icon) == (512,512), f"{entry['id']}: 512px service icon")
        for name, dimensions in (("app_icon_512.png",(512,512)),("feature_graphic_1024x500.png",(1024,500))):
            path = ROOT / "store" / name
            check(path.is_file(), f"{name}: exists")
            if path.is_file():
                check(png_size(path) == dimensions, f"{name}: correct store dimensions")
    for failure in failures:
        print(f"FAIL: {failure}")
    print(f"DATA VALIDATION: {checks} checks; {len(failures)} failures; 50 finite levels / {ship_total} authored ships / {len(encounter_ids)} encounters / {len(achievements)} achievements / {len(boards)} boards")
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())

