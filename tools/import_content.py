# -*- coding: utf-8 -*-
"""Validate StarTower_Content.xlsx and rewrite data/content.json from it.

Usage:  python tools/import_content.py
After editing the workbook, run this script.  The Import_Report sheet is
refreshed with the result; a non-zero exit code means content.json was NOT
written because a reference is dangling.
"""
import json
import os
import sys

import openpyxl

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XLSX_PATH = os.path.join(ROOT, "data", "StarTower_Content.xlsx")
JSON_PATH = os.path.join(ROOT, "data", "content.json")

REQUIRED_COUNTS = {"Pets_50": 50, "Items": 20, "Affixes": 19, "Trainers": 3,
                   "Starters": 3, "Bosses": 8, "Floors": 40}
BANNED_TERMS = ("mirror", "highestStat")


def sheet_rows(wb, title):
    """Return list of dicts, skipping the optional note row and blank rows."""
    ws = wb[title]
    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        return []
    header_idx = 0
    for i, row in enumerate(rows[:3]):
        if row and str(row[0] or "").strip() in ("id", "floor", "section", "key", "owner_id", "check", "element"):
            header_idx = i
            break
    header = [str(h).strip() if h is not None else "" for h in rows[header_idx]]
    out = []
    for row in rows[header_idx + 1:]:
        if row is None or all(v is None or str(v).strip() == "" for v in row):
            continue
        out.append({header[i]: row[i] for i in range(min(len(header), len(row)))})
    return out


def jload(value, default=None):
    if value is None or str(value).strip() == "":
        return default
    if isinstance(value, (dict, list)):
        return value
    return json.loads(str(value))


def as_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def as_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def split_pipe(value):
    return [x.strip() for x in str(value or "").split("|") if x.strip()]


def split_comma(value):
    return [x.strip() for x in str(value or "").replace("|", ",").split(",") if x.strip()]


def collect_banned(wb):
    hits = []
    for ws in wb.worksheets:
        for row in ws.iter_rows(values_only=True):
            for cell in row:
                if cell is None:
                    continue
                text = str(cell)
                for term in BANNED_TERMS:
                    if term.lower() in text.lower():
                        hits.append(f"{ws.title}: {term} in {text[:60]}")
    return hits


def build_from_workbook(wb):
    errors = []
    warnings = []

    elements = {}
    for r in sheet_rows(wb, "Elements"):
        eid = str(r["id"]).strip()
        elements[eid] = {
            "name": str(r["name"]).strip(),
            "color": str(r["color"]).strip(),
            "beats": split_pipe(r.get("beats")),
            "loses_to": split_pipe(r.get("loses_to")),
            "immune": split_pipe(r.get("immune")),
            "mutual": split_pipe(r.get("mutual")),
        }

    classes = {}
    for r in sheet_rows(wb, "Classes"):
        cid = str(r["id"]).strip()
        classes[cid] = {
            "name": str(r["name"]).strip(),
            "color": str(r["color"]).strip(),
            "hp": as_int(r.get("hp")), "atk": as_int(r.get("atk")),
            "def": as_int(r.get("def")), "spd": as_int(r.get("spd")),
            "role": str(r.get("role") or "").strip(),
            "target": str(r.get("target") or "front").strip(),
        }

    trainers = []
    for r in sheet_rows(wb, "Trainers"):
        trainers.append({
            "id": str(r["id"]).strip(), "name": str(r["name"]).strip(),
            "title": str(r.get("title") or "").strip(),
            "color": str(r.get("color") or "#ffffff").strip(),
            "desc": str(r.get("desc") or "").strip(),
            "mods": jload(r.get("mods"), {}),
            "start_items": as_int(r.get("start_items")),
            "item_bonus": as_float(r.get("item_bonus")),
            "start_affix": as_int(r.get("start_affix")),
        })
        picks = as_int(r.get("pick_items"))
        if picks > 0:
            trainers[-1]["pick_items"] = picks
        if str(r.get("hero_starter") or "").strip() in ["1", "true", "True"]:
            trainers[-1]["hero_starter"] = True
        special = str(r.get("starter_affix") or "").strip()
        if special:
            trainers[-1]["starter_affix"] = special

    starters = [{"id": str(r["id"]).strip(), "note": str(r.get("note") or "").strip()}
                for r in sheet_rows(wb, "Starters")]

    skills_by_owner = {}
    for r in sheet_rows(wb, "Skills"):
        owner = str(r["owner_id"]).strip()
        slot = str(r["slot"]).strip()
        skill = {
            "id": str(r["skill_id"]).strip(),
            "name": str(r["name"]).strip(),
            "kind": str(r["kind"]).strip(),
            "target": str(r["target"]).strip(),
            "mult": as_float(r.get("mult")),
            "splash": as_float(r.get("splash")),
            "desc": str(r.get("desc") or "").strip(),
        }
        skills_by_owner.setdefault(owner, {})[slot] = skill

    pets = []
    for r in sheet_rows(wb, "Pets_50"):
        pid = str(r["id"]).strip()
        names = split_pipe(r.get("names"))
        skills = skills_by_owner.get(pid, {})
        if "normal" not in skills or "ultimate" not in skills:
            errors.append(f"Pets_50 {pid}: missing normal/ultimate skill row")
        pet = {
            "id": pid,
            "names": names if len(names) == 3 else (names + [names[-1] if names else pid] * 3)[:3],
            "element": str(r["element"]).strip(),
            "class": str(r["class"]).strip(),
            "rarity": str(r.get("rarity") or "common").strip(),
            "starter": bool(as_int(r.get("starter"))),
            "stats": {"hp": as_int(r.get("hp")), "atk": as_int(r.get("atk")),
                      "def": as_int(r.get("def")), "spd": as_int(r.get("spd"))},
            "skills": {"normal": skills.get("normal", {}), "ultimate": skills.get("ultimate", {})},
        }
        mark = jload(r.get("mark"), {})
        art = jload(r.get("art"), {})
        signature = jload(r.get("signature"), {})
        if mark:
            pet["mark"] = mark
        if art:
            pet["art"] = art
        if signature and pet["skills"]["ultimate"]:
            pet["skills"]["ultimate"]["signature"] = signature
        pets.append(pet)

    affixes = []
    for r in sheet_rows(wb, "Affixes"):
        affix = {
            "id": str(r["id"]).strip(), "name": str(r["name"]).strip(),
            "rarity": str(r["rarity"]).strip(), "desc": str(r.get("desc") or "").strip(),
            "value": as_float(r.get("value")),
        }
        if str(r.get("pool") or "").strip() in ["0", "false", "False"]:
            affix["pool"] = False
        affixes.append(affix)

    items = []
    for r in sheet_rows(wb, "Items"):
        item = {
            "id": str(r["id"]).strip(), "name": str(r["name"]).strip(),
            "rarity": str(r["rarity"]).strip(), "desc": str(r.get("desc") or "").strip(),
        }
        if str(r.get("stat") or "").strip():
            item["stat"] = str(r["stat"]).strip()
            item["value"] = as_float(r.get("value"))
        if str(r.get("hook") or "").strip():
            item["hook"] = str(r["hook"]).strip()
            item["value"] = as_float(r.get("value"))
            if str(r.get("hook_value") or "").strip():
                item["hook_value"] = as_float(r.get("hook_value"))
        if str(r.get("max_stack") or "").strip():
            item["max_stack"] = as_int(r.get("max_stack"))
        items.append(item)

    bosses = []
    for r in sheet_rows(wb, "Bosses"):
        bid = str(r["id"]).strip()
        skills = skills_by_owner.get(bid, {})
        if "normal" not in skills or "ultimate" not in skills:
            errors.append(f"Bosses {bid}: missing normal/ultimate skill row")
        bosses.append({
            "id": bid, "name": str(r["name"]).strip(),
            "element": str(r["element"]).strip(), "class": str(r["class"]).strip(),
            "level_offset": as_int(r.get("level_offset")),
            "stat_mult": {"hp": as_float(r.get("hp_mult")), "atk": as_float(r.get("atk_mult")),
                          "def": as_float(r.get("def_mult")), "spd": as_float(r.get("spd_mult"))},
            "buff_count": as_int(r.get("buff_count")), "tier": as_int(r.get("tier")),
            "phases": jload(r.get("phases"), []),
            "skills": {"normal": skills.get("normal", {}), "ultimate": skills.get("ultimate", {})},
        })
        if str(r.get("demon_king") or "").strip() in ("1", "true", "True"):
            bosses[-1]["demon_king"] = True
            bosses[-1]["generation"] = as_int(r.get("generation"))
            bosses[-1]["reward_demon"] = str(r.get("reward_demon") or "").strip()

    boss_buffs = [{"id": str(r["id"]).strip(), "name": str(r["name"]).strip(),
                   "desc": str(r.get("desc") or "").strip()}
                  for r in sheet_rows(wb, "Boss_Buffs")]

    maps = {}
    for r in sheet_rows(wb, "Maps"):
        mid = str(r["id"]).strip()
        maps[mid] = {"name": str(r["name"]).strip(), "sky": split_pipe(r.get("sky")),
                     "accent": str(r.get("accent") or "#ffffff").strip(),
                     "style": str(r.get("style") or mid).strip()}

    floors = []
    for r in sheet_rows(wb, "Floors"):
        floors.append({
            "floor": as_int(r.get("floor")), "name": str(r["name"]).strip(),
            "map": str(r["map"]).strip(), "kind": str(r["kind"]).strip(),
            "enemy_count": as_int(r.get("enemy_count")), "level": as_int(r.get("level")),
            "pool": split_comma(r.get("pool")),
            "boss": str(r.get("boss") or "").strip() or None,
            "minion_count": as_int(r.get("minion_count")),
            "minion_level_offset": as_int(r.get("minion_level_offset")),
            "minion_stat_mult": as_float(r.get("minion_stat_mult"), 1.0),
            "enemy_stat_mult": as_float(r.get("enemy_stat_mult"), 1.0),
            "minion_affix_count": as_int(r.get("minion_affix_count")),
            "elite": bool(as_int(r.get("elite"))),
        })

    form_rows = sheet_rows(wb, "Formation")
    formation = {}
    for r in form_rows:
        section = str(r["section"]).strip()
        formation[section] = jload(r.get("value"), {})

    combat = {}
    for r in sheet_rows(wb, "Combat"):
        combat[str(r["key"]).strip()] = jload(r.get("value"))

    resonance = {}
    for r in sheet_rows(wb, "Resonance"):
        eid = str(r["element"]).strip()
        resonance[eid] = {
            "name": str(r.get("name") or "").strip(),
            "color": str(r.get("color") or "#ffffff").strip(),
            "tiers": jload(r.get("tiers"), []),
        }

    demons = []
    if "Demons" in wb.sheetnames:
        for r in sheet_rows(wb, "Demons"):
            did = str(r["id"]).strip()
            skills = skills_by_owner.get(did, {})
            demon = {
                "id": did, "name": str(r.get("name") or did).strip(),
                "names": [str(r.get("name") or did).strip()] * 3,
                "element": str(r["element"]).strip(), "class": str(r["class"]).strip(),
                "rarity": str(r.get("rarity") or "demon").strip(),
                "starter": False,
                "from_boss": str(r.get("from_boss") or "").strip(),
                "stats": {"hp": as_int(r.get("hp")), "atk": as_int(r.get("atk")),
                          "def": as_int(r.get("def")), "spd": as_int(r.get("spd"))},
                "skills": {"normal": skills.get("normal", {}), "ultimate": skills.get("ultimate", {})},
            }
            mark = jload(r.get("mark"), {})
            art = jload(r.get("art"), {})
            signature = jload(r.get("signature"), {})
            if mark:
                demon["mark"] = mark
            if art:
                demon["art"] = art
            if signature and demon["skills"]["ultimate"]:
                demon["skills"]["ultimate"]["signature"] = signature
            demons.append(demon)

    content = {
        "version": 3, "title": "灵契·星塔远征", "subtitle": "怀旧肉鸽爬塔",
        "meta": {"pets": len(pets), "affixes": len(affixes), "items": len(items),
                 "bosses": len(bosses), "floors": len(floors),
                 "note": "All names and vector art are original; no third-party assets are bundled."},
        "elements": elements, "classes": classes, "trainers": trainers, "starters": starters,
        "pets": pets, "demons": demons, "type_chart": combat.get("type_chart", {}),
        "affixes": affixes, "items": items, "bosses": bosses,
        "boss_buff_pool": boss_buffs, "maps": maps, "floors": floors,
        "formation": formation, "combat": combat, "resonance": resonance,
    }
    return content, errors, warnings


def validate(content):
    errors, warnings = [], []
    pet_ids = {p["id"] for p in content["pets"]}
    boss_ids = {b["id"] for b in content["bosses"]}
    affix_ids = {a["id"] for a in content["affixes"]}
    item_ids = {i["id"] for i in content["items"]}
    trainer_ids = {t["id"] for t in content["trainers"]}
    map_ids = set(content["maps"])
    element_ids = set(content["elements"])
    class_ids = set(content["classes"])

    if len(pet_ids) != len(content["pets"]):
        errors.append("duplicate pet id")
    for p in content["pets"]:
        if p["element"] not in element_ids:
            errors.append(f"pet {p['id']}: unknown element {p['element']}")
        if p["class"] not in class_ids:
            errors.append(f"pet {p['id']}: unknown class {p['class']}")
        if len(p["names"]) != 3 or not all(p["names"]):
            errors.append(f"pet {p['id']}: need 3 non-empty evolution names")
        for slot in ("normal", "ultimate"):
            sk = p["skills"].get(slot, {})
            if not sk.get("id"):
                errors.append(f"pet {p['id']}: missing {slot} skill")
            elif sk.get("mult") is None:
                errors.append(f"pet {p['id']}: {slot} has no multiplier")

    if len(content["starters"]) != 3:
        errors.append("Starters must contain exactly 3 entries")
    for s in content["starters"]:
        if s["id"] not in pet_ids:
            errors.append(f"starter {s['id']}: not found in Pets_50")

    for t in content["trainers"]:
        if t["id"] not in trainer_ids:
            errors.append(f"trainer {t['id']}: duplicate")
    if len(trainer_ids) != 3:
        warnings.append(f"expected 3 trainers, found {len(trainer_ids)}")

    for b in content["bosses"]:
        if b["element"] not in element_ids or b["class"] not in class_ids:
            errors.append(f"boss {b['id']}: bad element/class")
        for slot in ("normal", "ultimate"):
            if not b["skills"].get(slot, {}).get("id"):
                errors.append(f"boss {b['id']}: missing {slot} skill")

    for f in content["floors"]:
        if f["map"] not in map_ids:
            errors.append(f"floor {f['floor']}: unknown map {f['map']}")
        for pid in f["pool"]:
            if pid not in pet_ids:
                errors.append(f"floor {f['floor']}: dangling pool pet {pid}")
        if f.get("boss") and f["boss"] not in boss_ids:
            errors.append(f"floor {f['floor']}: unknown boss {f['boss']}")
        if f["kind"] == "boss" and not f.get("boss"):
            errors.append(f"floor {f['floor']}: boss floor without boss id")

    templ = content["formation"].get("enemy_templates", {})
    for count in ("1", "2", "3", "4", "5"):
        if count not in templ:
            errors.append(f"Formation: missing enemy template for {count}")
    boss_templates = content["formation"].get("boss_templates", {})
    for b in content["bosses"]:
        if b["id"] not in boss_templates:
            errors.append(f"Formation: missing boss template for {b['id']}")
    for eid, el in content["elements"].items():
        for target in el.get("beats", []) + el.get("loses_to", []) + el.get("immune", []) + el.get("mutual", []):
            if target not in element_ids:
                errors.append(f"element {eid}: unknown relation {target}")

    resonance = content.get("resonance", {})
    for eid in element_ids:
        if eid not in resonance:
            warnings.append(f"Resonance: missing entry for element {eid}")
            continue
        tiers = resonance[eid].get("tiers", [])
        if not tiers:
            errors.append(f"Resonance {eid}: empty tier list")
        for tier in tiers:
            if as_int(tier.get("count")) < 2:
                errors.append(f"Resonance {eid}: tier count must be >= 2")
            for key in tier.get("mods", {}):
                if key not in ("hp", "atk", "def", "spd", "crit"):
                    errors.append(f"Resonance {eid}: unknown mod {key}")

    for f in content["floors"]:
        if int(f.get("minion_affix_count", 0)) < 0:
            errors.append(f"floor {f['floor']}: minion_affix_count must be >= 0")
    for item in content["items"]:
        if "max_stack" in item and as_int(item["max_stack"]) < 1:
            errors.append(f"item {item['id']}: max_stack must be >= 1")

    rarity_weights = content["combat"].get("affix_weights", {})
    for a in content["affixes"]:
        if a["rarity"] not in rarity_weights:
            errors.append(f"affix {a['id']}: rarity {a['rarity']} has no weight")
    if len(affix_ids) != len(content["affixes"]):
        errors.append("duplicate affix id")
    if len(item_ids) != len(content["items"]):
        errors.append("duplicate item id")

    actual_counts = {
        "Pets_50": len(content["pets"]),
        "Items": len(content["items"]),
        "Affixes": len(content["affixes"]),
        "Trainers": len(content["trainers"]),
        "Starters": len(content["starters"]),
        "Bosses": len(content["bosses"]),
        "Floors": len(content["floors"]),
    }
    for name, expected in REQUIRED_COUNTS.items():
        if actual_counts.get(name, -1) != expected:
            errors.append(f"{name}: expected {expected}, found {actual_counts.get(name, -1)}")

    for f in content["floors"]:
        if int(f["level"]) <= 0:
            errors.append(f"floor {f['floor']}: level must be positive")
        if int(f["enemy_count"]) <= 0:
            errors.append(f"floor {f['floor']}: enemy_count must be positive")
        if not f["pool"]:
            errors.append(f"floor {f['floor']}: empty spawn pool")
        if float(f.get("enemy_stat_mult", 1.0)) <= 0.0:
            errors.append(f"floor {f['floor']}: enemy_stat_mult must be positive")
        if int(f["minion_count"]) < 0 or float(f["minion_stat_mult"]) <= 0.0:
            errors.append(f"floor {f['floor']}: invalid minion settings")
    return errors, warnings


def write_report(wb, errors, warnings, ok):
    if "Import_Report" in wb.sheetnames:
        del wb["Import_Report"]
    ws = wb.create_sheet("Import_Report")
    ws.append(["check", "status", "detail"])
    rows = [["import", "OK" if ok else "FAIL", "content.json rewritten" if ok else "content.json not written"]]
    rows += [["error", "FAIL", e] for e in errors]
    rows += [["warning", "WARN", w] for w in warnings]
    if not errors and not warnings:
        rows.append(["all checks", "OK", "references, counts and required tables are valid"])
    for row in rows:
        ws.append(row)
    ws.column_dimensions["A"].width = 22
    ws.column_dimensions["B"].width = 10
    ws.column_dimensions["C"].width = 90
    wb.save(XLSX_PATH)


def main():
    wb = openpyxl.load_workbook(XLSX_PATH)
    content, parse_errors, parse_warnings = build_from_workbook(wb)
    errors, warnings = validate(content)
    errors = parse_errors + errors
    warnings = parse_warnings + warnings
    banned = collect_banned(wb)
    errors += [f"banned enemy rule found: {h}" for h in banned]

    ok = not errors
    write_report(wb, errors, warnings, ok)
    if not ok:
        print("IMPORT FAILED:")
        for e in errors:
            print(" -", e)
        sys.exit(1)
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False, indent=2)
    print(f"OK: imported {len(content['pets'])} pets, {len(content['floors'])} floors -> {JSON_PATH}")
    for w in warnings:
        print(" warning:", w)


if __name__ == "__main__":
    main()
