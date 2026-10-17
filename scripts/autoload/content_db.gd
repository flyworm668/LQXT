extends Node
## Loads and indexes data/content.json.  The JSON is produced from the editable
## XLSX workbook by tools/import_content.py.

var data: Dictionary = {}
var pets_by_id: Dictionary = {}
var affixes_by_id: Dictionary = {}
var items_by_id: Dictionary = {}
var bosses_by_id: Dictionary = {}
var floors_by_num: Dictionary = {}
var trainers_by_id: Dictionary = {}
var boss_buffs_by_id: Dictionary = {}
var loaded: bool = false


func _ready() -> void:
	load_content()


func load_content() -> bool:
	var file := FileAccess.open("res://data/content.json", FileAccess.READ)
	if file == null:
		push_error("content.json not found. Run tools/build_content.py first.")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("content.json is not a JSON object.")
		return false
	data = parsed
	pets_by_id.clear()
	affixes_by_id.clear()
	items_by_id.clear()
	bosses_by_id.clear()
	floors_by_num.clear()
	trainers_by_id.clear()
	boss_buffs_by_id.clear()
	for p in data.get("pets", []):
		pets_by_id[p["id"]] = p
	for a in data.get("affixes", []):
		affixes_by_id[a["id"]] = a
	for i in data.get("items", []):
		items_by_id[i["id"]] = i
	for b in data.get("bosses", []):
		bosses_by_id[b["id"]] = b
	for f in data.get("floors", []):
		floors_by_num[int(f["floor"])] = f
	for t in data.get("trainers", []):
		trainers_by_id[t["id"]] = t
	for b in data.get("boss_buff_pool", []):
		boss_buffs_by_id[b["id"]] = b
	loaded = true
	if pets_by_id.size() != 50:
		push_warning("Expected 50 pets, content has %d" % pets_by_id.size())
	if floors_by_num.size() != 10:
		push_warning("Expected 10 floors, content has %d" % floors_by_num.size())
	return true


func combat() -> Dictionary:
	return data.get("combat", {})


func pet(pid: String) -> Dictionary:
	return pets_by_id.get(pid, {})


func affix(aid: String) -> Dictionary:
	return affixes_by_id.get(aid, {})


func item(iid: String) -> Dictionary:
	return items_by_id.get(iid, {})


func boss(bid: String) -> Dictionary:
	return bosses_by_id.get(bid, {})


func floor(n: int) -> Dictionary:
	return floors_by_num.get(n, {})


func map_data(mid: String) -> Dictionary:
	return data.get("maps", {}).get(mid, {})


func stage_for_level(level: int) -> int:
	var evo_levels: Array = combat().get("evo_levels", [30, 60])
	var idx := 0
	for threshold in evo_levels:
		if level >= int(threshold):
			idx += 1
	return min(idx, 2)


func pet_display_name(pid: String, level: int) -> String:
	var p := pet(pid)
	var names: Array = p.get("names", [pid])
	return str(names[stage_for_level(level)])


func _level_scaled(base: float, stat: String, level: int, mult: float) -> int:
	var steps: Dictionary = combat().get("level_steps", {})
	var step := float(steps.get(stat, 0.05))
	return int(round(base * (1.0 + step * float(level - 1)) * mult))


func pet_stats(pid: String, level: int) -> Dictionary:
	var p := pet(pid)
	var base: Dictionary = p.get("stats", {})
	var stage := stage_for_level(level)
	var evo_mults: Array = combat().get("evo_mult", [1.0, 1.25, 1.55])
	var evo := float(evo_mults[stage])
	return {
		"hp": _level_scaled(float(base.get("hp", 1000)), "hp", level, evo),
		"atk": _level_scaled(float(base.get("atk", 100)), "atk", level, evo),
		"def": _level_scaled(float(base.get("def", 60)), "def", level, evo),
		"spd": _level_scaled(float(base.get("spd", 100)), "spd", level, evo),
		"stage": stage,
	}


func boss_stats(bid: String, level: int) -> Dictionary:
	var b := boss(bid)
	var cls: Dictionary = data.get("classes", {}).get(b.get("class", "warrior"), {})
	var m: Dictionary = b.get("stat_mult", {})
	var out := {}
	for stat in ["hp", "atk", "def", "spd"]:
		out[stat] = _level_scaled(float(cls.get(stat, 100)), stat, level, float(m.get(stat, 1.0)))
	return out


func element_color(eid: String) -> Color:
	var e: Dictionary = data.get("elements", {}).get(eid, {})
	return Color.from_string(str(e.get("color", "#ffffff")), Color.WHITE)


func class_color(cid: String) -> Color:
	var c: Dictionary = data.get("classes", {}).get(cid, {})
	return Color.from_string(str(c.get("color", "#ffffff")), Color.WHITE)


func element_name(eid: String) -> String:
	return str(data.get("elements", {}).get(eid, {}).get("name", eid))


func class_name_for(cid: String) -> String:
	return str(data.get("classes", {}).get(cid, {}).get("name", cid))


func rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color("#b9c4d8")
		"rare": return Color("#5bb8ff")
		"epic": return Color("#c98bff")
		_: return Color.WHITE


func rarity_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		_: return rarity


func element_multiplier(attacker: String, defender: String) -> float:
	var atk_el: Dictionary = data.get("elements", {}).get(attacker, {})
	var def_el: Dictionary = data.get("elements", {}).get(defender, {})
	var cfg := combat()
	if defender in atk_el.get("mutual", []) or attacker in def_el.get("mutual", []):
		return float(cfg.get("element_advantage", 1.25))
	if defender in atk_el.get("beats", []):
		return float(cfg.get("element_advantage", 1.25))
	if defender in atk_el.get("loses_to", []):
		return float(cfg.get("element_disadvantage", 0.8))
	return 1.0


func _weighted_pick(rng: RandomNumberGenerator, pool: Array, weights: Dictionary, weight_key: String = "rarity") -> Dictionary:
	var total := 0
	for entry in pool:
		total += int(weights.get(str(entry.get(weight_key, "")), 1))
	if total <= 0:
		return {}
	var roll := rng.randi_range(1, total)
	for entry in pool:
		roll -= int(weights.get(str(entry.get(weight_key, "")), 1))
		if roll <= 0:
			return entry
	return pool.back()


func random_affix(rng: RandomNumberGenerator) -> Dictionary:
	var weights: Dictionary = combat().get("affix_weights", {"common": 60, "rare": 30, "epic": 10})
	return _weighted_pick(rng, data.get("affixes", []), weights)


func affix_candidates(rng: RandomNumberGenerator, count: int) -> Array:
	var out: Array = []
	var used := {}
	var guard := 0
	while out.size() < count and guard < 200:
		guard += 1
		var a := random_affix(rng)
		if a.is_empty() or used.has(a["id"]):
			continue
		used[a["id"]] = true
		out.append(a)
	return out


func random_item(rng: RandomNumberGenerator) -> Dictionary:
	var weights: Dictionary = combat().get("item_weights", {"common": 50, "rare": 35, "epic": 15})
	return _weighted_pick(rng, data.get("items", []), weights)


func random_boss_buff(rng: RandomNumberGenerator, exclude: Array = []) -> Dictionary:
	var pool: Array = []
	for b in data.get("boss_buff_pool", []):
		if b["id"] not in exclude:
			pool.append(b)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]


func boss_buff(bid: String) -> Dictionary:
	return boss_buffs_by_id.get(bid, {})


func all_pet_ids() -> Array:
	var ids: Array = []
	for p in data.get("pets", []):
		ids.append(p["id"])
	return ids


func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
