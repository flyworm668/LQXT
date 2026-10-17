extends Node
## Run state: trainer, roster, items, encounters and rewards.
## All randomness flows through one seeded RNG so a run is reproducible.

signal state_changed

const SAVE_PATH := "user://startower_record.json"
const MAX_DEPLOY := 5

const EMPTY_HOOKS := {
	"lifesteal": 0.0, "regen": 0.0, "reflect": 0.0, "vs_boss": 0.0,
	"ult_damage": 0.0, "double_normal": 0.0, "burn_on_hit": 0.0,
	"slow_on_hit": 0.0, "execute": 0.0, "crit": 0.0, "start_rage": 0,
	"start_shield": 0.0, "last_stand": 0.0, "resonance": 0.0,
	"item_luck": 0.0, "warded": 1.0, "oppress": 0.0,
}

var trainer: Dictionary = {}
var trainer_id: String = ""
var roster: Array = []
var owned_species: Dictionary = {}
var items: Array = []
var current_floor: int = 1
var encounter: Dictionary = {}
var deployed: Array = []
var formation_presets: Array = [[], [], []]
var active_preset: int = 0
var run_seed: int = 0
var rng := RandomNumberGenerator.new()
var next_uid: int = 1
var battle_counter: int = 0
var pending_rewards: Dictionary = {}
var run_active: bool = false
var run_won: bool = false
var run_stats: Dictionary = {}
var best_floor: int = 0
var total_runs: int = 0
var total_wins: int = 0
var persist_enabled: bool = true


func _ready() -> void:
	load_record()


func _empty_stats() -> Dictionary:
	return {
		"battles_won": 0, "pets_found": 0, "items_found": 0,
		"affixes_found": 0, "floors_cleared": 0, "damage_dealt": 0,
	}


func start_run(p_trainer_id: String, starter_id: String, seed_value: int = 0) -> void:
	trainer_id = p_trainer_id
	trainer = ContentDB.trainers_by_id.get(p_trainer_id, {})
	if trainer.is_empty():
		push_error("Unknown trainer: " + p_trainer_id)
		return
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system()) ^ randi()
	rng.seed = run_seed
	roster.clear()
	owned_species.clear()
	items.clear()
	deployed.clear()
	next_uid = 1
	battle_counter = 0
	current_floor = 1
	pending_rewards = {}
	run_active = true
	run_won = false
	run_stats = _empty_stats()
	var starter := create_pet(starter_id)
	roster.append(starter)
	owned_species[starter_id] = true
	# trainer starting perks
	for i in range(int(trainer.get("start_items", 0))):
		var it := ContentDB.random_item(rng)
		if not it.is_empty():
			items.append(it["id"])
			run_stats["items_found"] += 1
	var starting_affixes := int(trainer.get("start_affix", 0))
	for i in range(starting_affixes):
		var a := ContentDB.random_affix(rng)
		if not a.is_empty():
			attach_affix(starter["uid"], "normal", a["id"])
	auto_deploy()
	formation_presets = [[], [], []]
	formation_presets[0] = deployed.duplicate(true)
	active_preset = 0
	generate_encounter(1)
	if persist_enabled:
		total_runs += 1
		save_record()
	emit_signal("state_changed")


func create_pet(pid: String, level: int = 0) -> Dictionary:
	var lv := level if level > 0 else int(ContentDB.combat().get("base_level", 10))
	var entry := {
		"uid": next_uid,
		"species": pid,
		"level": lv,
		"resonance": 0,
		"affixes": {"normal": [], "ultimate": []},
	}
	next_uid += 1
	return entry


func party_level() -> int:
	var lv := int(ContentDB.combat().get("base_level", 10))
	for e in roster:
		lv = max(lv, int(e.get("level", lv)))
	return lv


func get_roster_entry(uid: int) -> Dictionary:
	for e in roster:
		if int(e["uid"]) == uid:
			return e
	return {}


func pet_name(entry: Dictionary) -> String:
	return ContentDB.pet_display_name(str(entry["species"]), int(entry["level"]))


func can_attach(entry_uid: int, slot: String) -> Dictionary:
	var entry := get_roster_entry(entry_uid)
	if entry.is_empty():
		return {"ok": false, "reason": "精灵不存在"}
	var slot_list: Array = entry["affixes"].get(slot, [])
	var max_slot := int(ContentDB.combat().get("affix_max_per_skill", 3))
	if slot_list.size() >= max_slot:
		return {"ok": false, "reason": "该技能词条已满（3/3）", "full_skill": true}
	var total := total_affixes(entry)
	if total >= int(ContentDB.combat().get("affix_max_per_pet", 6)):
		return {"ok": false, "reason": "该精灵词条已满（6/6）", "full_pet": true}
	return {"ok": true, "reason": ""}


func can_replace(entry_uid: int, slot: String) -> bool:
	var entry := get_roster_entry(entry_uid)
	if entry.is_empty():
		return false
	return (entry["affixes"].get(slot, []) as Array).size() > 0


func attach_affix(entry_uid: int, slot: String, affix_id: String, replace_index: int = -1) -> bool:
	var entry := get_roster_entry(entry_uid)
	if entry.is_empty() or slot not in ["normal", "ultimate"]:
		return false
	var slot_list: Array = entry["affixes"][slot]
	if affix_id in slot_list:
		return false
	if replace_index >= 0 and replace_index < slot_list.size():
		slot_list[replace_index] = affix_id
		run_stats["affixes_found"] += 1
		emit_signal("state_changed")
		return true
	var check := can_attach(entry_uid, slot)
	if not check["ok"]:
		return false
	slot_list.append(affix_id)
	run_stats["affixes_found"] += 1
	emit_signal("state_changed")
	return true


func total_affixes(entry: Dictionary) -> int:
	return (entry["affixes"]["normal"] as Array).size() + (entry["affixes"]["ultimate"] as Array).size()


func add_owned_species(pid: String) -> Dictionary:
	if not owned_species.has(pid):
		var entry := create_pet(pid, party_level())
		roster.append(entry)
		owned_species[pid] = true
		run_stats["pets_found"] += 1
		emit_signal("state_changed")
		return {"kind": "new", "entry": entry, "species": pid, "name": pet_name(entry)}
	# duplicate -> resonance
	var target := {}
	for e in roster:
		if str(e["species"]) == pid:
			target = e
			break
	if target.is_empty():
		target = create_pet(pid, party_level())
		roster.append(target)
	target["resonance"] = int(target.get("resonance", 0)) + 1
	run_stats["pets_found"] += 1
	emit_signal("state_changed")
	return {"kind": "resonance", "entry": target, "species": pid,
		"name": pet_name(target), "stacks": int(target["resonance"])}


func auto_deploy() -> void:
	deployed.clear()
	var count := mini(roster.size(), MAX_DEPLOY)
	var templates: Dictionary = ContentDB.data["formation"].get("player_templates", {})
	var positions: Array = templates.get(str(count), [])
	for i in range(mini(count, positions.size())):
		deployed.append({
			"uid": int(roster[i]["uid"]),
			"row": int(positions[i][0]),
			"col": int(positions[i][1]),
		})


func set_deployment(placements: Array) -> bool:
	if placements.size() > MAX_DEPLOY:
		return false
	var seen := {}
	for p in placements:
		var uid := int(p["uid"])
		if seen.has(uid):
			return false
		seen[uid] = true
		if int(p["row"]) < 0 or int(p["row"]) > 2 or int(p["col"]) < 0 or int(p["col"]) > 2:
			return false
		if get_roster_entry(uid).is_empty():
			return false
	deployed = placements.duplicate(true)
	emit_signal("state_changed")
	return true


func save_preset(index: int, placements: Array) -> void:
	if index < 0 or index > 2:
		return
	formation_presets[index] = placements.duplicate(true)


func load_preset(index: int) -> Array:
	if index < 0 or index > 2:
		return []
	return (formation_presets[index] as Array).duplicate(true)


func deployed_uids() -> Array:
	var out: Array = []
	for d in deployed:
		out.append(int(d["uid"]))
	return out


func is_deployed(uid: int) -> bool:
	return uid in deployed_uids()


# ---------------------------------------------------------------- encounters

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func pick_species(pool: Array, count: int) -> Array:
	var available: Array = pool.duplicate()
	_shuffle(available)
	var chosen: Array = []
	var used := {}
	# ensure a frontline and (for larger groups) a healer
	var wanted: Array = []
	if count >= 3:
		wanted.append("guardian")
	if count >= 4:
		wanted.append("support")
	for cls in wanted:
		if chosen.size() >= count:
			break
		for pid in available:
			if used.has(pid):
				continue
			if str(ContentDB.pet(pid).get("class", "")) == cls:
				chosen.append(pid)
				used[pid] = true
				break
	for pid in available:
		if chosen.size() >= count:
			break
		if used.has(pid):
			continue
		chosen.append(pid)
		used[pid] = true
	while chosen.size() < count and not pool.is_empty():
		chosen.append(pool[rng.randi_range(0, pool.size() - 1)])
	_shuffle(chosen)
	return chosen


func _new_hooks() -> Dictionary:
	return EMPTY_HOOKS.duplicate(true)


func build_enemy_unit(pid: String, level: int, stat_mult: float = 1.0) -> Dictionary:
	var p := ContentDB.pet(pid)
	var st := ContentDB.pet_stats(pid, level)
	var hp := maxi(1, int(round(float(st["hp"]) * stat_mult)))
	var unit := {
		"uid": next_uid, "side": "enemy", "species": pid,
		"name": ContentDB.pet_display_name(pid, level),
		"element": p.get("element", "fire"), "class": p.get("class", "warrior"),
		"level": level, "stage": int(st.get("stage", 0)),
		"max_hp": hp, "hp": hp,
		"atk": maxi(1, int(round(float(st["atk"]) * stat_mult))),
		"def": maxi(0, int(round(float(st["def"]) * stat_mult))),
		"spd": maxi(1, int(round(float(st["spd"]) * stat_mult))),
		"crit": float(ContentDB.combat().get("crit_base", 0.05)),
		"rage": 0, "shield": 0, "row": 1, "col": 0,
		"skills": p.get("skills", {}).duplicate(true),
		"affixes": {"normal": [], "ultimate": []},
		"hooks": _new_hooks(),
		"statuses": {}, "is_boss": false, "buff_ids": [],
		"last_stand_used": false, "tier": 0, "phases": [], "phase_index": 0,
	}
	next_uid += 1
	return unit


func build_boss_unit(boss_data: Dictionary, level: int, buff_ids: Array) -> Dictionary:
	var st := ContentDB.boss_stats(str(boss_data["id"]), level)
	var hp := int(st["hp"])
	var unit := {
		"uid": next_uid, "side": "enemy", "species": str(boss_data["id"]),
		"name": str(boss_data["name"]),
		"element": boss_data.get("element", "dark"), "class": boss_data.get("class", "warrior"),
		"level": level, "stage": 2,
		"max_hp": hp, "hp": hp, "atk": int(st["atk"]), "def": int(st["def"]), "spd": int(st["spd"]),
		"crit": float(ContentDB.combat().get("crit_base", 0.05)),
		"rage": 0, "shield": 0, "row": 1, "col": 2,
		"skills": boss_data.get("skills", {}).duplicate(true),
		"affixes": {"normal": [], "ultimate": []},
		"hooks": _new_hooks(),
		"statuses": {}, "is_boss": true, "buff_ids": buff_ids.duplicate(),
		"last_stand_used": false, "tier": int(boss_data.get("tier", 1)),
		"phases": boss_data.get("phases", []).duplicate(true), "phase_index": 0,
	}
	next_uid += 1
	_apply_boss_buffs(unit, buff_ids)
	return unit


func _apply_boss_buffs(unit: Dictionary, buff_ids: Array) -> void:
	for bid in buff_ids:
		match str(bid):
			"frenzy":
				unit["atk"] = int(unit["atk"] * 1.25)
			"undying":
				unit["max_hp"] = int(unit["max_hp"] * 1.30)
				unit["hp"] = unit["max_hp"]
			"bedrock":
				unit["def"] = int(unit["def"] * 1.25)
			"swift":
				unit["spd"] = int(unit["spd"] * 1.20)
			"bloodthirst":
				unit["hooks"]["lifesteal"] += 0.20
			"barbed":
				unit["hooks"]["reflect"] += 0.12
			"renewal":
				unit["hooks"]["regen"] += 0.05
			"oppress":
				unit["hooks"]["oppress"] += 0.10
			"warded":
				unit["hooks"]["warded"] = 0.90
			"surge":
				unit["hooks"]["ult_damage"] += 0.30


func generate_encounter(floor_num: int) -> Dictionary:
	var f: Dictionary = ContentDB.floor(floor_num)
	if f.is_empty():
		push_error("Unknown floor %d" % floor_num)
		return {}
	var enemies: Array = []
	var boss_buffs: Array = []
	var formation: Dictionary = ContentDB.data.get("formation", {})
	if str(f.get("kind", "normal")) == "boss" and f.get("boss"):
		var boss_data: Dictionary = ContentDB.boss(str(f["boss"]))
		var buff_count := int(boss_data.get("buff_count", 1))
		for i in range(buff_count):
			var b := ContentDB.random_boss_buff(rng, boss_buffs)
			if not b.is_empty():
				boss_buffs.append(str(b["id"]))
		var boss_level := int(f["level"]) + int(boss_data.get("level_offset", 0))
		var boss_unit := build_boss_unit(boss_data, boss_level, boss_buffs)
		var bt: Dictionary = formation.get("boss_templates", {}).get(str(boss_data["id"]), {})
		var boss_pos: Array = bt.get("boss", [1, 2])
		boss_unit["row"] = int(boss_pos[0])
		boss_unit["col"] = int(boss_pos[1])
		enemies.append(boss_unit)
		var minion_ids := pick_species(f.get("pool", []), int(f.get("minion_count", 0)))
		var minion_positions: Array = bt.get("minions", [])
		for i in range(minion_ids.size()):
			var lv := maxi(1, int(f["level"]) + int(f.get("minion_level_offset", 0)))
			var mu := build_enemy_unit(str(minion_ids[i]), lv, float(f.get("minion_stat_mult", 1.0)))
			if i < minion_positions.size():
				mu["row"] = int(minion_positions[i][0])
				mu["col"] = int(minion_positions[i][1])
			enemies.append(mu)
	else:
		var ids := pick_species(f.get("pool", []), int(f.get("enemy_count", 1)))
		var template: Array = formation.get("enemy_templates", {}).get(str(ids.size()), [])
		for i in range(ids.size()):
			var mu := build_enemy_unit(str(ids[i]), int(f["level"]), float(f.get("enemy_stat_mult", 1.0)))
			if i < template.size():
				mu["row"] = int(template[i][0])
				mu["col"] = int(template[i][1])
			enemies.append(mu)
	encounter = {
		"floor": floor_num,
		"floor_data": f,
		"enemies": enemies,
		"boss_buffs": boss_buffs,
		"kind": f.get("kind", "normal"),
	}
	emit_signal("state_changed")
	return encounter


# ---------------------------------------------------------------- items/units

func item_counts() -> Dictionary:
	var counts := {}
	for iid in items:
		counts[iid] = int(counts.get(iid, 0)) + 1
	return counts


func item_mods() -> Dictionary:
	var mods := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	var hooks := _new_hooks()
	for iid in items:
		var it: Dictionary = ContentDB.item(str(iid))
		if it.is_empty():
			continue
		if it.has("stat"):
			var st := str(it["stat"])
			if mods.has(st):
				mods[st] += float(it.get("value", 0.0))
		if it.has("hook"):
			var hook := str(it["hook"])
			if not hooks.has(hook):
				continue
			if hook == "last_stand":
				hooks[hook] = 1.0
			elif hook == "warded":
				hooks[hook] = float(it.get("value", 0.9))
			else:
				var v := float(it.get("hook_value", it.get("value", 0.0)))
				hooks[hook] += v
	return {"mods": mods, "hooks": hooks}


func effective_stats(entry: Dictionary) -> Dictionary:
	var mods_data := item_mods()
	var stat_mods: Dictionary = mods_data["mods"]
	var hooks: Dictionary = mods_data["hooks"]
	var trainer_mods: Dictionary = trainer.get("mods", {})
	var pid := str(entry["species"])
	var lv := int(entry["level"])
	var st: Dictionary = ContentDB.pet_stats(pid, lv)
	var resonance := int(entry.get("resonance", 0))
	var res_mult := 1.0 + float(resonance) * float(ContentDB.combat().get("resonance_bonus", 0.08)) * (1.0 + float(hooks.get("resonance", 0.0)))
	return {
		"hp": int(round(float(st["hp"]) * res_mult * (1.0 + float(stat_mods["hp"])) * (1.0 + float(trainer_mods.get("hp_mult", 0.0))))),
		"atk": int(round(float(st["atk"]) * res_mult * (1.0 + float(stat_mods["atk"])) * (1.0 + float(trainer_mods.get("atk_mult", 0.0))))),
		"def": int(round(float(st["def"]) * res_mult * (1.0 + float(stat_mods["def"])) * (1.0 + float(trainer_mods.get("def_mult", 0.0))))),
		"spd": int(round(float(st["spd"]) * res_mult * (1.0 + float(stat_mods["spd"])) * (1.0 + float(trainer_mods.get("spd_mult", 0.0))))),
	}


func build_player_units() -> Array:
	var mods_data := item_mods()
	var stat_mods: Dictionary = mods_data["mods"]
	var hooks: Dictionary = mods_data["hooks"]
	var trainer_mods: Dictionary = trainer.get("mods", {})
	var units: Array = []
	for d in deployed:
		var entry := get_roster_entry(int(d["uid"]))
		if entry.is_empty():
			continue
		var pid := str(entry["species"])
		var p: Dictionary = ContentDB.pet(pid)
		var lv := int(entry["level"])
		var st: Dictionary = ContentDB.pet_stats(pid, lv)
		var resonance := int(entry.get("resonance", 0))
		var res_mult := 1.0 + float(resonance) * float(ContentDB.combat().get("resonance_bonus", 0.08)) * (1.0 + float(hooks.get("resonance", 0.0)))
		var hp := float(st["hp"]) * res_mult * (1.0 + float(stat_mods["hp"])) * (1.0 + float(trainer_mods.get("hp_mult", 0.0)))
		var atk := float(st["atk"]) * res_mult * (1.0 + float(stat_mods["atk"])) * (1.0 + float(trainer_mods.get("atk_mult", 0.0)))
		var def := float(st["def"]) * res_mult * (1.0 + float(stat_mods["def"])) * (1.0 + float(trainer_mods.get("def_mult", 0.0)))
		var spd := float(st["spd"]) * res_mult * (1.0 + float(stat_mods["spd"])) * (1.0 + float(trainer_mods.get("spd_mult", 0.0)))
		var unit := {
			"uid": int(entry["uid"]), "side": "player", "species": pid,
			"name": ContentDB.pet_display_name(pid, lv),
			"element": p.get("element", "fire"), "class": p.get("class", "warrior"),
			"level": lv, "stage": int(st.get("stage", 0)),
			"max_hp": int(round(hp)), "hp": int(round(hp)),
			"atk": int(round(atk)), "def": int(round(def)), "spd": int(round(spd)),
			"crit": float(ContentDB.combat().get("crit_base", 0.05)) + float(hooks.get("crit", 0.0)) + float(trainer_mods.get("crit", 0.0)),
			"rage": 0, "shield": 0,
			"row": int(d["row"]), "col": int(d["col"]),
			"skills": p.get("skills", {}).duplicate(true),
			"affixes": (entry["affixes"] as Dictionary).duplicate(true),
			"hooks": hooks.duplicate(true),
			"statuses": {}, "is_boss": false, "buff_ids": [],
			"last_stand_used": false, "tier": 0, "phases": [], "phase_index": 0,
			"resonance": resonance,
		}
		unit["affixes"] = (entry["affixes"] as Dictionary).duplicate(true)
		units.append(unit)
	return units


func build_enemy_units() -> Array:
	return encounter.get("enemies", []).duplicate(true)


func next_battle_seed() -> int:
	battle_counter += 1
	var h := hash("%d:%d:%d" % [run_seed, current_floor, battle_counter])
	return absi(h)


# ---------------------------------------------------------------- rewards

func apply_victory() -> Dictionary:
	run_stats["battles_won"] += 1
	run_stats["floors_cleared"] = maxi(int(run_stats["floors_cleared"]), current_floor)
	var old_names := {}
	for e in roster:
		old_names[int(e["uid"])] = pet_name(e)
	var step := int(ContentDB.combat().get("level_up_per_floor", 10))
	var cap := int(ContentDB.combat().get("max_level", 100))
	for e in roster:
		e["level"] = mini(cap, int(e["level"]) + step)
	var evolutions: Array = []
	for e in roster:
		var uid := int(e["uid"])
		var new_name := pet_name(e)
		if old_names.has(uid) and str(old_names[uid]) != new_name:
			evolutions.append({"uid": uid, "from": old_names[uid], "to": new_name})
	if current_floor >= 10:
		if not run_won and persist_enabled:
			total_wins += 1
		run_won = true
		run_active = false
		best_floor = maxi(best_floor, current_floor)
		save_record()
	else:
		best_floor = maxi(best_floor, current_floor)
		save_record()
	roll_rewards()
	emit_signal("state_changed")
	return {"evolutions": evolutions, "rewards": pending_rewards, "won": run_won}


func roll_rewards() -> void:
	var f: Dictionary = ContentDB.floor(current_floor)
	var pool: Array = f.get("pool", [])
	var unowned: Array = []
	for pid in pool:
		if not owned_species.has(pid):
			unowned.append(pid)
	if unowned.is_empty():
		for pid in ContentDB.all_pet_ids():
			if not owned_species.has(pid):
				unowned.append(pid)
	var pet_reward := {}
	if unowned.is_empty():
		var species_pool: Array = pool if not pool.is_empty() else ContentDB.all_pet_ids()
		var pick := str(species_pool[rng.randi_range(0, species_pool.size() - 1)])
		pet_reward = {"kind": "resonance", "species": pick}
	else:
		var pick := str(unowned[rng.randi_range(0, unowned.size() - 1)])
		pet_reward = {"kind": "new", "species": pick}
	var item_reward := {"kind": "none"}
	var item_chance := float(ContentDB.combat().get("chest_item_chance", 0.5))
	item_chance += float(trainer.get("item_bonus", 0.0))
	item_chance += float(item_mods()["hooks"].get("item_luck", 0.0))
	if rng.randf() < item_chance:
		var it := ContentDB.random_item(rng)
		if not it.is_empty():
			item_reward = {"kind": "item", "id": str(it["id"])}
	var affix_reward := {"kind": "none"}
	if rng.randf() < float(ContentDB.combat().get("chest_affix_chance", 0.25)):
		var candidates := ContentDB.affix_candidates(rng, 3)
		if not candidates.is_empty():
			affix_reward = {"kind": "affix", "candidates": candidates}
	pending_rewards = {
		"floor": current_floor,
		"pet": pet_reward,
		"item": item_reward,
		"affix": affix_reward,
		"claimed": {"pet": false, "item": false, "affix": false},
	}


func claim_pet_reward() -> Dictionary:
	if pending_rewards.is_empty() or pending_rewards["claimed"]["pet"]:
		return {}
	var r: Dictionary = pending_rewards["pet"]
	var result: Dictionary = {}
	if str(r.get("kind", "")) == "new":
		result = add_owned_species(str(r["species"]))
	else:
		result = add_owned_species(str(r["species"]))
	pending_rewards["claimed"]["pet"] = true
	emit_signal("state_changed")
	return result


func claim_item_reward() -> Dictionary:
	if pending_rewards.is_empty() or pending_rewards["claimed"]["item"]:
		return {}
	var r: Dictionary = pending_rewards["item"]
	if str(r.get("kind", "")) != "item":
		pending_rewards["claimed"]["item"] = true
		return {}
	var iid := str(r["id"])
	items.append(iid)
	run_stats["items_found"] += 1
	pending_rewards["claimed"]["item"] = true
	emit_signal("state_changed")
	return ContentDB.item(iid)


func claim_affix_reward(entry_uid: int, slot: String, affix_id: String, replace_index: int = -1) -> bool:
	if pending_rewards.is_empty() or pending_rewards["claimed"]["affix"]:
		return false
	var candidates: Array = pending_rewards["affix"].get("candidates", [])
	var allowed := false
	for a in candidates:
		if str(a["id"]) == affix_id:
			allowed = true
			break
	if not allowed:
		return false
	var ok := attach_affix(entry_uid, slot, affix_id, replace_index)
	if ok:
		pending_rewards["claimed"]["affix"] = true
		emit_signal("state_changed")
	return ok


func convert_affix_reward() -> Dictionary:
	if pending_rewards.is_empty() or pending_rewards["claimed"]["affix"]:
		return {}
	var it := ContentDB.random_item(rng)
	if not it.is_empty():
		items.append(str(it["id"]))
		run_stats["items_found"] += 1
	pending_rewards["claimed"]["affix"] = true
	emit_signal("state_changed")
	return it


func skip_affix_reward() -> void:
	if pending_rewards.is_empty():
		return
	pending_rewards["claimed"]["affix"] = true
	emit_signal("state_changed")


func advance_floor() -> bool:
	if current_floor >= 10:
		return false
	current_floor += 1
	pending_rewards = {}
	if deployed.size() < mini(roster.size(), MAX_DEPLOY):
		auto_deploy()
	generate_encounter(current_floor)
	emit_signal("state_changed")
	return true


func end_run_defeat() -> void:
	run_active = false
	best_floor = maxi(best_floor, int(run_stats.get("floors_cleared", 0)))
	save_record()
	emit_signal("state_changed")


func run_summary() -> Dictionary:
	return {
		"won": run_won,
		"floor": current_floor,
		"floors_cleared": int(run_stats.get("floors_cleared", 0)),
		"pets": int(run_stats.get("pets_found", 0)),
		"items": items.size(),
		"affixes": int(run_stats.get("affixes_found", 0)),
		"seed": run_seed,
		"trainer": trainer.get("name", ""),
		"roster": roster.size(),
		"best_floor": best_floor,
	}


# ---------------------------------------------------------------- record

func load_record() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		best_floor = int(parsed.get("best_floor", 0))
		total_runs = int(parsed.get("total_runs", 0))
		total_wins = int(parsed.get("total_wins", 0))


func save_record() -> void:
	if not persist_enabled:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"best_floor": best_floor,
		"total_runs": total_runs,
		"total_wins": total_wins,
	}, "  "))
