#!/usr/bin/env python3
"""Validate authored PiratePlunder content, asset links, and Play registration catalogs."""
from __future__ import annotations
import argparse
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
    hazards = {"reef","current","mine","maelstrom","storm"}
    objectives = {"kills","coins","survive","boss"}
    boss_ids = []
    for stage in levels:
        ident = stage["id"]
        obj = stage["objective"]
        check(stage["biome"] in biome_ids, f"Level {ident}: known biome")
        check(obj["type"] in objectives and obj["target"] > 0, f"Level {ident}: valid objective")
        check(30 <= stage["duration_limit"] <= 180, f"Level {ident}: short-session deadline")
        check(stage["spawn_interval"] > 0 and 1 <= stage["max_enemies"] <= 14, f"Level {ident}: bounded spawn tuning")
        check(bool(stage["enemy_pool"]) and set(stage["enemy_pool"]) <= set(enemies), f"Level {ident}: valid weighted enemy pool")
        check(0 <= stage["star_targets"]["health"] <= 1, f"Level {ident}: normalized health star threshold")
        check(stage["star_targets"]["time"] > 0, f"Level {ident}: valid time star threshold")
        times = [wave["at"] for wave in stage["waves"]]
        check(times == sorted(times), f"Level {ident}: chronological waves")
        for wave in stage["waves"]:
            check(0 <= wave["at"] < stage["duration_limit"], f"Level {ident}: wave before deadline")
            check(set(wave["enemies"]) <= set(enemies), f"Level {ident}: known wave enemies")
        for hazard in stage["hazards"]:
            check(hazard["type"] in hazards and hazard["count"] >= 1 and hazard["radius"] > 0, f"Level {ident}: valid hazard")
        if obj["type"] == "coins":
            check(stage["treasure_count"] * stage["treasure_value"] >= obj["target"], f"Level {ident}: enough reachable initial treasure")
        if obj["type"] == "survive":
            check(obj["target"] < stage["duration_limit"], f"Level {ident}: survival achievable before timeout")
        if obj["type"] == "boss":
            boss_ids.append(ident)
            check(isinstance(stage["boss"], dict), f"Level {ident}: boss definition")
            check(resource(stage["boss"]["asset"]).is_file(), f"Level {ident}: existing boss sprite")
            check(stage["boss"]["hp"] > 0 and stage["boss"]["cannon_count"] > 0, f"Level {ident}: valid boss stats")
        check(stage["reward"]["xp"] > 0 and stage["reward"]["coins"] > 0, f"Level {ident}: clear rewards")
    check(boss_ids == [10,20,30,40,50], "One finale boss per biome")
    for stage in levels[:3]:
        check(stage["max_enemies"] <= 3 and stage["objective"]["target"] <= 8, f"Level {stage['id']}: easy opening")
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
    print(f"DATA VALIDATION: {checks} checks; {len(failures)} failures; 50 levels / 5 biomes / 4 ships / {len(achievements)} achievements / {len(boards)} boards")
    return 1 if failures else 0

if __name__ == "__main__":
    raise SystemExit(main())

