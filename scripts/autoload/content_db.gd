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
var resonance_data: Dictionary = {}
var demons_by_id: Dictionary = {}
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
	demons_by_id.clear()
	for dmn in data.get("demons", []):
		demons_by_id[dmn["id"]] = dmn
	resonance_data = data.get("resonance", {})
	loaded = true
	if pets_by_id.size() < 50:
		push_warning("Expected at least 50 pets, content has %d" % pets_by_id.size())
	if floors_by_num.size() != total_floors():
		push_warning("Expected %d floors, content has %d" % [total_floors(), floors_by_num.size()])
	return true


func combat() -> Dictionary:
	return data.get("combat", {})


func total_floors() -> int:
	return int(combat().get("total_floors", floors_by_num.size()))


func resonance(eid: String) -> Dictionary:
	return resonance_data.get(eid, {})


func resonance_tier(eid: String, count: int) -> Dictionary:
	var cfg := resonance(eid)
	var best := {}
	for tier in cfg.get("tiers", []):
		if count >= int(tier.get("count", 99)):
			best = tier
	return best


func hero_stat_mult() -> Dictionary:
	return combat().get("hero_stat_mult", {"hp": 1.55, "atk": 1.50, "def": 1.35, "spd": 1.10})


func hero_buff_scale(star: int = 0) -> float:
	return float(combat().get("hero_buff_scale", 0.6)) + float(star) * float(combat().get("hero_star_bonus", 0.06))


func hero_max_star() -> int:
	return int(combat().get("hero_max_star", 3))


func hero_skill_mult() -> float:
	return float(combat().get("hero_skill_mult", 1.12))


func max_stack_for(iid: String) -> int:
	return int(item(iid).get("max_stack", 0))


func pet(pid: String) -> Dictionary:
	if pets_by_id.has(pid):
		return pets_by_id[pid]
	return demons_by_id.get(pid, {})


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


func is_king_demon(pid: String) -> bool:
	var p := pet(pid)
	return bool(p.get("demon_king", false)) or str(p.get("from_boss", "")).begins_with("k")


func pet_max_level(pid: String, is_hero: bool = false, uncapped: bool = false) -> int:
	if uncapped:
		return 0
	var caps: Dictionary = combat().get("rarity_max_level", {})
	var p := pet(pid)
	if is_king_demon(pid):
		var kings: Dictionary = combat().get("king_level_caps", {})
		if kings.has(pid):
			return int(kings[pid])
		return int(caps.get("demon_king", 150))
	var rarity := str(p.get("rarity", "common"))
	if rarity == "demon":
		return int(caps.get("demon", 180))
	if is_hero or rarity == "hero":
		return int(caps.get("hero", 100))
	match rarity:
		"legend":
			return int(caps.get("legend", 90))
		"epic":
			return int(caps.get("epic", 80))
		"rare":
			return int(caps.get("rare", 70))
		"common":
			return int(caps.get("common", 60))
		_:
			return int(caps.get(rarity, 60))


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
	var mults: Dictionary = combat().get("rarity_stat_mult", {})
	evo *= float(mults.get(str(p.get("rarity", "common")), 1.0))
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
		"legend": return Color("#ffb35c")
		"hero": return Color("#ffd166")
		"demon": return Color("#ff5d6c")
		_: return Color.WHITE


func rarity_name(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legend": return "传说"
		"hero": return "英雄"
		"demon": return "魔人"
		_: return rarity


## Higher means rarer. Star rank is intentionally not part of this.
func rarity_rank(rarity: String) -> int:
	match rarity:
		"demon": return 6
		"hero": return 5
		"legend": return 4
		"epic": return 3
		"rare": return 2
		"common": return 1
		_: return 0


func element_multiplier(attacker: String, defender: String) -> float:
	var chart: Dictionary = combat().get("type_chart", {})
	if chart.is_empty():
		chart = data.get("type_chart", {})
	if chart.has(attacker):
		var row: Dictionary = chart[attacker]
		if row.has(defender):
			return float(row[defender])
		return 1.0
	var atk_el: Dictionary = data.get("elements", {}).get(attacker, {})
	var cfg := combat()
	if defender in atk_el.get("beats", []):
		return float(cfg.get("element_advantage", 2.0))
	if defender in atk_el.get("immune", []):
		return 0.0
	if defender in atk_el.get("loses_to", []):
		return float(cfg.get("element_disadvantage", 0.5))
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
	var pool: Array = []
	for a in data.get("affixes", []):
		if bool(a.get("pool", true)):
			pool.append(a)
	return _weighted_pick(rng, pool, weights)


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


func random_item(rng: RandomNumberGenerator, luck: float = 0.0, exclude: Array = []) -> Dictionary:
	var base: Dictionary = combat().get("item_weights", {"common": 50, "rare": 35, "epic": 15})
	var weights := {}
	for key in base.keys():
		weights[key] = float(base[key])
	if luck > 0.0:
		weights["rare"] = float(weights.get("rare", 35.0)) * (1.0 + luck)
		weights["epic"] = float(weights.get("epic", 15.0)) * (1.0 + luck * 1.8)
	var pool: Array = []
	for i in data.get("items", []):
		if bool(i.get("pool", true)) == false:
			continue
		if i["id"] not in exclude:
			pool.append(i)
	if pool.is_empty():
		pool = data.get("items", [])
	return _weighted_pick(rng, pool, weights)


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
