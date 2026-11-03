# -*- coding: utf-8 -*-
"""Build data/content.json and the editable XLSX workbook from content_source.py."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import content_source  # noqa: E402

import openpyxl  # noqa: E402
from openpyxl.styles import Font, PatternFill, Alignment  # noqa: E402
from openpyxl.utils import get_column_letter  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data")
XLSX_PATH = os.path.join(DATA_DIR, "StarTower_Content.xlsx")
JSON_PATH = os.path.join(DATA_DIR, "content.json")

HEADER_FILL = PatternFill("solid", fgColor="1F2937")
HEADER_FONT = Font(color="FFFFFF", bold=True)
NOTE_FONT = Font(color="6B7280", italic=True)


def as_json(value):
    return json.dumps(value, ensure_ascii=False)


def write_sheet(wb, title, headers, rows, widths=None, note=None):
    ws = wb.create_sheet(title)
    row_offset = 0
    if note:
        ws.cell(row=1, column=1, value=note).font = NOTE_FONT
        row_offset = 1
    for c, header in enumerate(headers, start=1):
        cell = ws.cell(row=1 + row_offset, column=c, value=header)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal="center")
    for r, row in enumerate(rows, start=2 + row_offset):
        for c, value in enumerate(row, start=1):
            ws.cell(row=r, column=c, value=value)
    if widths:
        for i, width in enumerate(widths, start=1):
            ws.column_dimensions[get_column_letter(i)].width = width
    ws.freeze_panes = ws.cell(row=2 + row_offset, column=1)
    return ws


def build_xlsx(content):
    wb = openpyxl.Workbook()
    wb.remove(wb.active)

    write_sheet(wb, "Elements", ["id", "name", "color", "beats", "loses_to", "immune", "mutual"],
                [[eid, e["name"], e["color"], "|".join(e.get("beats", [])),
                  "|".join(e.get("loses_to", [])), "|".join(e.get("immune", [])),
                  "|".join(e.get("mutual", []))]
                 for eid, e in content["elements"].items()],
                [12, 10, 12, 28, 28, 16, 14])

    write_sheet(wb, "Classes", ["id", "name", "color", "hp", "atk", "def", "spd", "role", "target"],
                [[cid, c["name"], c["color"], c["hp"], c["atk"], c["def"], c["spd"], c["role"], c["target"]]
                 for cid, c in content["classes"].items()],
                [12, 10, 12, 8, 8, 8, 8, 26, 12])

    write_sheet(wb, "Trainers", ["id", "name", "title", "color", "desc", "mods", "start_items", "item_bonus", "start_affix", "pick_items", "hero_starter", "starter_affix"],
                [[t["id"], t["name"], t["title"], t["color"], t["desc"], as_json(t["mods"]),
                  t.get("start_items", 0), t.get("item_bonus", 0.0), t.get("start_affix", 0),
                  t.get("pick_items", 0), 1 if t.get("hero_starter") else 0, t.get("starter_affix", "")]
                 for t in content["trainers"]],
                [12, 16, 14, 12, 44, 32, 12, 12, 12, 12, 14, 16])

    write_sheet(wb, "Starters", ["id", "note"],
                [[s["id"], s["note"]] for s in content["starters"]], [10, 44])

    pet_rows = []
    for p in content["pets"]:
        n, u = p["skills"]["normal"], p["skills"]["ultimate"]
        pet_rows.append([
            p["id"], "|".join(p["names"]), p["element"], p["class"], p.get("rarity", "common"),
            1 if p["starter"] else 0,
            p["stats"]["hp"], p["stats"]["atk"], p["stats"]["def"], p["stats"]["spd"],
            n["id"], u["id"],
            as_json(p.get("mark", {})), as_json(u.get("signature", {})), as_json(p.get("art", {})),
        ])
    write_sheet(wb, "Pets_50", ["id", "names", "element", "class", "rarity", "starter",
                               "hp", "atk", "def", "spd", "normal_id", "ult_id",
                               "mark", "signature", "art"],
                pet_rows, [10, 30, 10, 10, 10, 9, 8, 8, 8, 8, 12, 12, 36, 36, 24],
                note="names = 3 evolution stages separated by | ; mark/signature/art are JSON")

    skill_rows = []
    for p in content["pets"]:
        for slot in ("normal", "ultimate"):
            s = p["skills"][slot]
            skill_rows.append([p["id"], slot, s["id"], s["name"], s["kind"], s["target"],
                               s["mult"], s.get("splash", 0.0), s["desc"]])
    for owner_list in (content["bosses"], content.get("demons", [])):
        for b in owner_list:
            for slot in ("normal", "ultimate"):
                s = b["skills"][slot]
                skill_rows.append([b["id"], slot, s["id"], s["name"], s["kind"], s["target"],
                                   s["mult"], s.get("splash", 0.0), s["desc"]])
    write_sheet(wb, "Skills", ["owner_id", "slot", "skill_id", "name", "kind", "target", "mult", "splash", "desc"],
                skill_rows, [10, 10, 14, 16, 16, 12, 8, 8, 52])

    write_sheet(wb, "Affixes", ["id", "name", "rarity", "desc", "value", "pool"],
                [[a["id"], a["name"], a["rarity"], a["desc"], a["value"], 0 if a.get("pool", True) is False else 1]
                 for a in content["affixes"]],
                [16, 14, 10, 52, 8, 8])

    write_sheet(wb, "Items", ["id", "name", "rarity", "desc", "stat", "value", "hook", "hook_value", "max_stack"],
                [[i["id"], i["name"], i["rarity"], i["desc"], i.get("stat", ""), i.get("value", ""),
                  i.get("hook", ""), i.get("hook_value", ""), i.get("max_stack", "")] for i in content["items"]],
                [18, 14, 10, 52, 8, 8, 16, 10, 10])

    boss_rows = []
    for b in content["bosses"]:
        m = b["stat_mult"]
        n, u = b["skills"]["normal"], b["skills"]["ultimate"]
        boss_rows.append([b["id"], b["name"], b["element"], b["class"], b["level_offset"],
                          m["hp"], m["atk"], m["def"], m["spd"], b["buff_count"], b["tier"],
                          as_json(b["phases"]), n["id"], u["id"],
                          1 if b.get("demon_king") else 0, b.get("generation", ""),
                          b.get("reward_demon", "")])
    write_sheet(wb, "Bosses", ["id", "name", "element", "class", "level_offset",
                              "hp_mult", "atk_mult", "def_mult", "spd_mult",
                              "buff_count", "tier", "phases", "normal_id", "ult_id",
                              "demon_king", "generation", "reward_demon"],
                boss_rows, [8, 22, 10, 10, 12, 10, 10, 10, 10, 11, 8, 48, 12, 12, 12, 12, 14])

    write_sheet(wb, "Boss_Buffs", ["id", "name", "desc"],
                [[b["id"], b["name"], b["desc"]] for b in content["boss_buff_pool"]],
                [14, 12, 42])

    write_sheet(wb, "Maps", ["id", "name", "sky", "accent", "style"],
                [[mid, m["name"], "|".join(m["sky"]), m["accent"], m["style"]]
                 for mid, m in content["maps"].items()],
                [12, 16, 30, 12, 12])

    write_sheet(wb, "Floors", ["floor", "name", "map", "kind", "enemy_count", "level", "pool",
                              "boss", "minion_count", "minion_level_offset", "minion_stat_mult",
                              "enemy_stat_mult", "minion_affix_count", "elite"],
                [[f["floor"], f["name"], f["map"], f["kind"], f["enemy_count"], f["level"],
                  ",".join(f["pool"]), f.get("boss") or "", f["minion_count"],
                  f["minion_level_offset"], f["minion_stat_mult"], f["enemy_stat_mult"],
                  f.get("minion_affix_count", 0), 1 if f["elite"] else 0]
                 for f in content["floors"]],
                [8, 22, 10, 10, 13, 8, 60, 8, 13, 18, 16, 16, 18, 8])

    form = content["formation"]
    form_rows = [["row_damage", "front/mid/back", as_json(form["row_damage"])],
                 ["row_names", "front/mid/back", as_json(form["row_names"])]]
    for key in ("player_templates", "enemy_templates", "boss_templates", "links"):
        if key in form:
            form_rows.append([key, "all", as_json(form[key])])
    write_sheet(wb, "Formation", ["section", "key", "value"], form_rows, [22, 18, 80],
                note="value is JSON. Templates are [row, col] pairs; row 0/1/2 = top/mid/bottom, col 0/1/2 = front/mid/back")

    write_sheet(wb, "Combat", ["key", "value"],
                [[k, as_json(v)] for k, v in content["combat"].items()], [28, 24])

    write_sheet(wb, "Resonance", ["element", "name", "color", "tiers"],
                [[eid, r["name"], r["color"], as_json(r["tiers"])]
                 for eid, r in content["resonance"].items()], [12, 16, 12, 90],
                note="tiers is JSON: [{count, name, desc, mods:{hp/atk/def/spd/crit}}]")

    demon_rows = []
    for d in content.get("demons", []):
        n, u = d["skills"]["normal"], d["skills"]["ultimate"]
        demon_rows.append([
            d["id"], d["name"], d["element"], d["class"], d["rarity"], d.get("from_boss", ""),
            d["stats"]["hp"], d["stats"]["atk"], d["stats"]["def"], d["stats"]["spd"],
            n["id"], u["id"], as_json(d.get("mark", {})), as_json(u.get("signature", {})),
            as_json(d.get("art", {})),
        ])
    write_sheet(wb, "Demons", ["id", "name", "element", "class", "rarity", "from_boss",
                              "hp", "atk", "def", "spd", "normal_id", "ult_id",
                              "mark", "signature", "art"],
                demon_rows, [8, 22, 10, 10, 10, 12, 8, 8, 8, 8, 12, 12, 36, 36, 24],
                note="Event-only. Never rolled from chests.")

    write_sheet(wb, "Import_Report", ["check", "status", "detail"],
                [["build", "OK", f"generated {len(content['pets'])} pets / {len(content['floors'])} floors"]],
                [28, 12, 70], note="Run tools/import_content.py after editing to validate and rewrite content.json")

    wb.save(XLSX_PATH)


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    content = content_source.build_content()
    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False, indent=2)
    build_xlsx(content)
    print(f"wrote {JSON_PATH}")
    print(f"wrote {XLSX_PATH}")
    print(f"pets={len(content['pets'])} floors={len(content['floors'])} "
          f"items={len(content['items'])} affixes={len(content['affixes'])}")


if __name__ == "__main__":
    main()
