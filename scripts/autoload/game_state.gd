extends Node
const SpiritPool = preload("res://scripts/core/spirit_pool.gd")
## Run state: trainer, roster, items, encounters and rewards.
## All randomness flows through one seeded RNG so a run is reproducible.

signal state_changed

const SAVE_PATH := "user://startower_record.json"
const RUN_PATH := "user://startower_run.dat"
const SLOT_COUNT := 3
const SLOT_PATH := "user://startower_slot_%d.dat"
const DISPLAY_PATH := "user://startower_display.json"
const MAX_DEPLOY := 6

const EMPTY_HOOKS := {
	"lifesteal": 0.0, "regen": 0.0, "reflect": 0.0, "vs_boss": 0.0,
	"ult_damage": 0.0, "double_normal": 0.0, "burn_on_hit": 0.0,
	"slow_on_hit": 0.0, "execute": 0.0, "crit": 0.0, "start_rage": 0, "start_spirit": 0,
	"start_shield": 0.0, "last_stand": 0.0, "resonance": 0.0,
	"item_luck": 0.0, "warded": 1.0, "oppress": 0.0,
	"pierce": 0.0, "enrage": 0.0, "barrier_blade": 0.0,
	"crit_bonus": 0.0, "vs_king": 0.0, "shard_lives": 0.0,
}
const BLADE_SHARDS := ["blade_shard_1", "blade_shard_2", "blade_shard_3", "blade_shard_4"]

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
var run_bonuses: Dictionary = {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0, "crit": 0.0}
var pending_event: Dictionary = {}
var event_done: Array = []
var curse_floors: Dictionary = {}
var heroes_found: int = 0
var save_screen: String = "map"
var saved_floor_hint: int = 0
var saved_screen_hint: String = ""
var saved_mode_hint: String = "tower"
var affix_bag: Array = []
var spirit_floor: int = 0
var run_mode: String = "tower"
var pending_mode: String = "tower"
var conquest_step: int = 0
var blade_trial_floor: int = 0
var blade_forged_pending: bool = false
var gold: int = 0
var route_done: Array = []
var pending_route: Dictionary = {}
var trainer_deaths: Dictionary = {}
var pokedex: Dictionary = {}
var tower_cleared: bool = false
var wonder_line: bool = false
var event_battle: bool = false
var conquest_clear: bool = false
var run_notice: String = ""
var screen_safe: bool = true
var screen_pad: Dictionary = {"left": 0, "right": 0, "top": 0, "bottom": 0}


func _ready() -> void:
	load_record()
	load_display()
	state_changed.connect(_autosave_run)


func load_display() -> void:
	if not FileAccess.file_exists(DISPLAY_PATH):
		return
	var f := FileAccess.open(DISPLAY_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	screen_safe = bool(data.get("safe", true))
	var pad: Variant = data.get("pad", {})
	if typeof(pad) != TYPE_DICTIONARY:
		return
	for key in ["left", "right", "top", "bottom"]:
		screen_pad[key] = clampi(int((pad as Dictionary).get(key, 0)), 0, 180)


func save_display() -> void:
	var f := FileAccess.open(DISPLAY_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"safe": screen_safe, "pad": screen_pad}))


func set_screen_pad(side: String, value: int) -> void:
	screen_pad[side] = clampi(value, 0, 180)
	save_display()


func set_screen_safe(on: bool) -> void:
	screen_safe = on
	save_display()


func _empty_stats() -> Dictionary:
	return {
		"battles_won": 0, "pets_found": 0, "items_found": 0,
		"affixes_found": 0, "floors_cleared": 0, "damage_dealt": 0,
		"heroes_found": 0,
	}


func start_run(p_trainer_id: String, starter_id: String, seed_value: int = 0, chosen_items: Array = []) -> void:
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
	run_bonuses = {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0, "crit": 0.0}
	pending_event = {}
	event_done = []
	curse_floors = {}
	heroes_found = 0
	affix_bag = ["unbound"]
	spirit_floor = 0
	blade_trial_floor = 0
	blade_forged_pending = false
	gold = 0
	route_done = []
	pending_route = {}
	wonder_line = false
	event_battle = false
	conquest_step = 0
	conquest_clear = false
	run_notice = ""
	run_mode = pending_mode if pending_mode != "" else "tower"
	pending_mode = "tower"
	var starter := create_pet(starter_id)
	starter["chosen"] = true
	var starter_rarity := str(ContentDB.pet(starter_id).get("rarity", "common"))
	if starter_rarity == "hero" or starter_rarity == "demon":
		starter["hero"] = true
		var buff := ContentDB.random_boss_buff(rng)
		starter["hero_buff"] = str(buff.get("id", "frenzy"))
		heroes_found += 1
		run_stats["heroes_found"] = 1
	roster.append(starter)
	owned_species[starter_id] = true
	var special := str(trainer.get("starter_affix", ""))
	if not special.is_empty() and not affix_bag.has(special):
		affix_bag.append(special)
	var start_balls := int({"novice": 5, "veteran": 10, "master": 15}.get(trainer_id, 5))
	for _ball in start_balls:
		add_item("pokeball")
	if not chosen_items.is_empty():
		for iid in chosen_items:
			add_item(str(iid))
	else:
		for i in range(int(trainer.get("start_items", 0))):
			var it := ContentDB.random_item(rng)
			if not it.is_empty():
				add_item(str(it["id"]))
	var starting_affixes := int(trainer.get("start_affix", 0))
	for i in range(starting_affixes):
		var a := ContentDB.random_affix(rng)
		if not a.is_empty():
			attach_affix(int(starter["uid"]), "basic", str(a["id"]))
	formation_presets = [[], [], []]
	active_preset = 0
	if run_mode == "conquest":
		current_floor = 1
		run_notice = "破魔圣剑不在开局背包里。个位数为 4 或 9 的奇遇关里接受圣剑试炼，打赢后它会进入道具背包，可以让一只精灵携带。"
		generate_conquest_encounter()
	else:
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
		"affixes": {"basic": [], "aid": [], "ult": []},
		"hero": false,
		"hero_buff": "",
		"hero_star": 0,
		"carried": [],
	}
	var pet: Dictionary = ContentDB.pet(pid)
	entry["arts"] = SpiritPool.starter_arts(pet)
	entry["passive"] = SpiritPool.passive_for(pet)
	next_uid += 1
	return entry


func ensure_arts(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var pet: Dictionary = ContentDB.pet(str(entry.get("species", "")))
	var arts: Array = entry.get("arts", [])
	var roles := {}
	for raw in arts:
		var art: Dictionary = raw
		roles[str(art.get("role", ""))] = true
	if not (roles.has("basic") and roles.has("aid") and roles.has("ult")):
		entry["arts"] = SpiritPool.starter_arts(pet)
	elif str(pet.get("class", "")) == "support":
		_upgrade_support_arts(entry)
	if not entry.has("passive"):
		entry["passive"] = SpiritPool.passive_for(pet)
	var affixes: Dictionary = entry.get("affixes", {})
	if not affixes.has("basic"):
		affixes["basic"] = (affixes.get("normal", []) as Array).duplicate()
		affixes["aid"] = []
		affixes["ult"] = (affixes.get("ultimate", []) as Array).duplicate()
		entry["affixes"] = affixes


func _upgrade_support_arts(entry: Dictionary) -> void:
	var arts: Array = entry.get("arts", [])
	var changed := false
	for i in arts.size():
		var art: Dictionary = arts[i]
		var effects: Array = art.get("effects", [])
		if str(art.get("role", "")) == "aid" and effects == ["heal", "spirit1"]:
			art["effects"] = ["heal", "spirit3"]
			arts[i] = art
			changed = true
		elif str(art.get("role", "")) == "ult" and effects == ["hit", "heal", "spirit2", "heavy"]:
			var pet: Dictionary = ContentDB.pet(str(entry.get("species", "")))
			var next: Array = ["heal", "spirit4", "cover", "rally"]
			var cap := SpiritPool.effect_cap(str(pet.get("rarity", "common")), bool(entry.get("hero", false)))
			while next.size() > cap:
				next.pop_back()
			art["effects"] = next
			arts[i] = art
			changed = true
	if changed:
		entry["arts"] = arts


func can_train_pet(entry: Dictionary) -> bool:
	return int(entry.get("trained_floor", -1)) != current_floor


func can_train() -> bool:
	for entry in roster:
		if can_train_pet(entry):
			return true
	return false


func train_offers(uid: int) -> Array:
	var entry := get_roster_entry(uid)
	if entry.is_empty():
		return []
	ensure_arts(entry)
	var pet: Dictionary = ContentDB.pet(str(entry.get("species", "")))
	return SpiritPool.offers_for(pet, absi(hash("%d:%d:%d" % [run_seed, current_floor, uid])))


func train_apply(uid: int, effect_id: String, art_index: int) -> String:
	var entry := get_roster_entry(uid)
	if entry.is_empty():
		return "没有这只精灵。"
	if not can_train_pet(entry):
		return "这只精灵这一层已经培养过。"
	ensure_arts(entry)
	var arts: Array = entry["arts"]
	if art_index < 0:
		return "每只精灵只有普通、辅助、大招三招。"
	else:
		if art_index >= arts.size():
			return "没有这一招。"
		var art: Dictionary = arts[art_index]
		var effects: Array = art.get("effects", [])
		var pet: Dictionary = ContentDB.pet(str(entry.get("species", "")))
		var rarity := str(pet.get("rarity", "common"))
		var hero := bool(entry.get("hero", false))
		var role := str(art.get("role", "basic"))
		if SpiritPool.stack_count(effects, effect_id) >= SpiritPool.MAX_STACK:
			return "这个效果已经叠了三次。"
		if role == "ult":
			var cap := SpiritPool.effect_cap(rarity, hero)
			if effects.size() >= cap:
				return "大招最多 %d 个技能效果。" % cap
		else:
			var base_n := 0
			for raw in SpiritPool.starter_arts(pet):
				var starter: Dictionary = raw
				if str(starter.get("role", "")) == role:
					base_n = (starter.get("effects", []) as Array).size()
			var room := SpiritPool.add_cap(str(pet.get("class", "")), role, rarity, hero)
			if effects.size() - base_n >= room:
				return "这一招最多再添加 %d 个技能效果。" % room
		effects.append(effect_id)
		art["effects"] = effects
		arts[art_index] = art
	entry["arts"] = arts
	entry["trained_floor"] = current_floor
	save_run()
	return ""


func _ensure_chosen() -> void:
	for entry in roster:
		if bool(entry.get("chosen", false)):
			return
	if roster.is_empty():
		return
	var best: Dictionary = roster[0]
	for entry in roster:
		if int(entry.get("uid", 999999)) < int(best.get("uid", 999999)):
			best = entry
	best["chosen"] = true


func pet_max_level(entry: Dictionary) -> int:
	if entry.is_empty():
		return 60
	return ContentDB.pet_max_level(
		str(entry.get("species", "")),
		bool(entry.get("hero", false)),
		bool(entry.get("uncapped", false))
	)


func _growth_step() -> int:
	return int(ContentDB.combat().get("level_up_per_floor", 5))


func party_raw_level() -> int:
	var base := int(ContentDB.combat().get("base_level", 10))
	var lv := base + int(run_stats.get("battles_won", 0)) * _growth_step()
	for e in roster:
		lv = max(lv, int(e.get("level", lv)))
	return lv


func party_level_for(pid: String, is_hero: bool = false) -> int:
	var cap := ContentDB.pet_max_level(pid, is_hero, false)
	var raw := party_raw_level()
	return mini(cap, raw) if cap > 0 else raw


func party_level() -> int:
	var lv := int(ContentDB.combat().get("base_level", 10))
	var cap := int(ContentDB.combat().get("max_level", 150))
	var saw_capped := false
	for e in roster:
		if bool(e.get("uncapped", false)):
			continue
		saw_capped = true
		lv = max(lv, int(e.get("level", lv)))
	if not saw_capped:
		for e in roster:
			lv = max(lv, int(e.get("level", lv)))
	return mini(cap, lv)


func get_roster_entry(uid: int) -> Dictionary:
	for e in roster:
		if int(e["uid"]) == uid:
			return e
	return {}


func pet_name(entry: Dictionary) -> String:
	var base := ContentDB.pet_display_name(str(entry["species"]), int(entry["level"]))
	var rarity := str(ContentDB.pet(str(entry["species"])).get("rarity", "common"))
	if bool(entry.get("hero", false)) and rarity != "demon" and not base.begins_with("英雄"):
		return "英雄·" + base
	return base


func can_attach(entry_uid: int, slot: String) -> Dictionary:
	var entry := get_roster_entry(entry_uid)
	if entry.is_empty():
		return {"ok": false, "reason": "精灵不存在"}
	if bool(entry.get("uncapped", false)):
		return {"ok": true, "reason": ""}
	var slot_list: Array = entry["affixes"].get(slot, [])
	var max_slot := int(ContentDB.combat().get("affix_max_per_skill", 3))
	if slot_list.size() >= max_slot:
		return {"ok": false, "reason": "该技能词条已满（3/3）", "full_skill": true}
	var total := total_affixes(entry)
	var pet_cap := pet_affix_cap(entry)
	if total >= pet_cap:
		return {"ok": false, "reason": "该精灵词条已满（%d/%d）" % [total, pet_cap], "full_pet": true}
	return {"ok": true, "reason": ""}


func can_replace(entry_uid: int, slot: String) -> bool:
	var entry := get_roster_entry(entry_uid)
	if entry.is_empty():
		return false
	return (entry["affixes"].get(slot, []) as Array).size() > 0


func attach_affix(entry_uid: int, slot: String, affix_id: String, replace_index: int = -1) -> bool:
	var entry := get_roster_entry(entry_uid)
	if entry.is_empty() or slot not in ["normal", "ultimate", "basic", "aid", "ult"]:
		return false
	if not (entry["affixes"] as Dictionary).has(slot):
		entry["affixes"][slot] = []
	var slot_list: Array = entry["affixes"][slot]
	var uncapped := bool(entry.get("uncapped", false))
	if affix_id in slot_list and not uncapped:
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


func holds_affix(affix_id: String) -> bool:
	if affix_bag.has(affix_id):
		return true
	for entry in roster:
		var affixes: Dictionary = entry.get("affixes", {})
		for slot in _affix_slots(entry):
			if affix_id in (affixes.get(slot, []) as Array):
				return true
	return false


func attach_from_bag(entry_uid: int, slot: String, affix_id: String) -> String:
	var index := affix_bag.find(affix_id)
	if index < 0:
		return "背包里没有这个词条。"
	var entry := get_roster_entry(entry_uid)
	if entry.is_empty():
		return "没有这只精灵。"
	if affix_id == "unbound":
		if not bool(entry.get("chosen", false)):
			return "无限只能赋予开局选定的精灵。"
		if bool(entry.get("uncapped", false)):
			return "这只精灵已经没有上限。"
		entry["uncapped"] = true
		entry["boon"] = "unbound"
		affix_bag.remove_at(index)
		emit_signal("state_changed")
		return "无限已赋予 %s。等级和词条都不再封顶。" % pet_name(entry)
	if not attach_affix(entry_uid, slot, affix_id):
		return "这个技能贴不上。"
	var left := affix_bag.find(affix_id)
	if left >= 0:
		affix_bag.remove_at(left)
	emit_signal("state_changed")
	return "%s 已贴到 %s。" % [str(ContentDB.affix(affix_id).get("name", affix_id)), pet_name(entry)]


func _affix_slots(entry: Dictionary) -> Array:
	var affixes: Dictionary = entry.get("affixes", {})
	if affixes.has("basic"):
		return ["basic", "aid", "ult"]
	return ["normal", "ultimate"]


func total_affixes(entry: Dictionary) -> int:
	var affixes: Dictionary = entry.get("affixes", {})
	var count := 0
	for slot in _affix_slots(entry):
		count += (affixes.get(slot, []) as Array).size()
	return count


func pet_affix_cap(entry: Dictionary) -> int:
	if bool(entry.get("uncapped", false)):
		return 999
	return clampi(int(entry.get("affix_cap", int(ContentDB.combat().get("affix_max_per_pet", 6)))), 6, 9)


func catch_enemy(pid: String, level: int) -> Dictionary:
	var result := add_owned_species(pid)
	if str(result.get("kind", "")) != "new":
		return result
	var entry: Dictionary = result.get("entry", {})
	if entry.is_empty():
		return result
	entry["level"] = clampi(level, 1, pet_max_level(entry))
	emit_signal("state_changed")
	return result


func ball_count() -> int:
	var n := 0
	for iid in items:
		if str(iid) == "pokeball":
			n += 1
	return n


func use_ball() -> bool:
	var index := items.find("pokeball")
	if index < 0:
		return false
	items.remove_at(index)
	emit_signal("state_changed")
	return true


func add_owned_species(pid: String) -> Dictionary:
	if not owned_species.has(pid):
		var rarity := str(ContentDB.pet(pid).get("rarity", "common"))
		var is_hero := rarity == "hero" or rarity == "demon"
		var entry := create_pet(pid, party_level_for(pid, is_hero))
		if is_hero:
			entry["hero"] = true
			var buff := ContentDB.random_boss_buff(rng)
			entry["hero_buff"] = str(buff.get("id", "frenzy"))
			heroes_found += 1
			run_stats["heroes_found"] = int(run_stats.get("heroes_found", 0)) + 1
		roster.append(entry)
		owned_species[pid] = true
		_note_species(pid)
		run_stats["pets_found"] += 1
		emit_signal("state_changed")
		return {"kind": "new", "entry": entry, "species": pid, "name": pet_name(entry)}
	# duplicate -> resonance (hero copies are separate units, never resonance targets)
	var target := {}
	for e in roster:
		if str(e["species"]) == pid and not bool(e.get("hero", false)):
			target = e
			break
	if target.is_empty():
		var r2 := str(ContentDB.pet(pid).get("rarity", "common"))
		target = create_pet(pid, party_level_for(pid, r2 == "hero" or r2 == "demon"))
		roster.append(target)
	target["resonance"] = int(target.get("resonance", 0)) + 1
	run_stats["pets_found"] += 1
	emit_signal("state_changed")
	return {"kind": "resonance", "entry": target, "species": pid,
		"name": pet_name(target), "stacks": int(target["resonance"])}


func add_hero_pet(pid: String, buff_id: String) -> Dictionary:
	var entry := create_pet(pid, party_level_for(pid, true))
	entry["hero"] = true
	entry["hero_buff"] = buff_id
	entry["hero_star"] = 0
	roster.append(entry)
	heroes_found += 1
	run_stats["heroes_found"] = int(run_stats.get("heroes_found", 0)) + 1
	emit_signal("state_changed")
	return entry


func can_upgrade_hero(uid: int) -> Dictionary:
	var entry := get_roster_entry(uid)
	if entry.is_empty() or not bool(entry.get("hero", false)):
		return {"ok": false, "reason": "不是英雄精灵"}
	if int(entry.get("hero_star", 0)) >= ContentDB.hero_max_star():
		return {"ok": false, "reason": "已达最高星级"}
	if _epic_item_index() < 0:
		return {"ok": false, "reason": "需要一件史诗携带道具"}
	return {"ok": true, "reason": ""}


func upgrade_hero(uid: int) -> Dictionary:
	var check := can_upgrade_hero(uid)
	if not check["ok"]:
		return check
	var entry := get_roster_entry(uid)
	var consumed := _take_epic_item()
	entry["hero_star"] = int(entry.get("hero_star", 0)) + 1
	run_stats["heroes_upgraded"] = int(run_stats.get("heroes_upgraded", 0)) + 1
	emit_signal("state_changed")
	return {"ok": true, "reason": "", "consumed": consumed,
		"star": int(entry["hero_star"]), "max": ContentDB.hero_max_star()}


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


## Display order only. Does not reorder `roster`, so deploy and star-up cannot shuffle it.
## Same rarity keeps acquisition order.
func roster_view() -> Array:
	var rows: Array = []
	for i in range(roster.size()):
		rows.append([i, roster[i]])
	rows.sort_custom(func(a, b):
		var ea: Dictionary = a[1]
		var eb: Dictionary = b[1]
		var ra := ContentDB.rarity_rank(str(ContentDB.pet(str(ea.get("species", ""))).get("rarity", "common")))
		var rb := ContentDB.rarity_rank(str(ContentDB.pet(str(eb.get("species", ""))).get("rarity", "common")))
		if ra != rb:
			return ra > rb
		return int(a[0]) < int(b[0]))
	var out: Array = []
	for row in rows:
		out.append(row[1])
	return out


func roster_for_affix() -> Array:
	var ranked := roster_view()
	var rows: Array = []
	for i in range(ranked.size()):
		rows.append([i, ranked[i]])
	rows.sort_custom(func(a, b):
		var ca := total_affixes(a[1])
		var cb := total_affixes(b[1])
		if ca != cb:
			return ca > cb
		return int(a[0]) < int(b[0]))
	var out: Array = []
	for row in rows:
		out.append(row[1])
	return out


# ---------------------------------------------------------------- encounters

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _enemy_weight(pid: String) -> int:
	var rarity := str(ContentDB.pet(pid).get("rarity", "common"))
	var table: Dictionary = {"common": 70, "rare": 28, "epic": 2, "legend": 0, "hero": 0}
	if current_floor >= 15:
		table = {"common": 20, "rare": 30, "epic": 28, "legend": 16, "hero": 6}
	elif current_floor >= 10:
		table = {"common": 30, "rare": 36, "epic": 22, "legend": 10, "hero": 2}
	elif current_floor >= 5:
		table = {"common": 42, "rare": 38, "epic": 18, "legend": 2, "hero": 0}
	return int(table.get(rarity, 0))


func _weighted_species(pool: Array, used: Dictionary, cls: String = "") -> String:
	var ids: Array = []
	var weights: Array = []
	var total := 0
	for pid in pool:
		var key := str(pid)
		if used.has(key):
			continue
		if cls != "" and str(ContentDB.pet(key).get("class", "")) != cls:
			continue
		var weight := _enemy_weight(key)
		if weight <= 0:
			continue
		ids.append(key)
		weights.append(weight)
		total += weight
	if ids.is_empty():
		for pid in pool:
			var key := str(pid)
			if used.has(key):
				continue
			if cls != "" and str(ContentDB.pet(key).get("class", "")) != cls:
				continue
			return key
		return ""
	var roll := rng.randi_range(1, total)
	var acc := 0
	for i in range(ids.size()):
		acc += int(weights[i])
		if roll <= acc:
			return str(ids[i])
	return str(ids[0])


func pick_species(pool: Array, count: int) -> Array:
	var available: Array = pool.duplicate()
	var chosen: Array = []
	var used := {}
	var wanted: Array = []
	if count >= 3:
		wanted.append("guardian")
	if count >= 4:
		wanted.append("support")
	for cls in wanted:
		if chosen.size() >= count:
			break
		var pick := _weighted_species(available, used, str(cls))
		if pick.is_empty():
			continue
		chosen.append(pick)
		used[pick] = true
	while chosen.size() < count:
		var pick := _weighted_species(available, used)
		if pick.is_empty():
			break
		chosen.append(pick)
		used[pick] = true
	while chosen.size() < count and not pool.is_empty():
		chosen.append(pool[rng.randi_range(0, pool.size() - 1)])
	_shuffle(chosen)
	return chosen


func _new_hooks() -> Dictionary:
	return EMPTY_HOOKS.duplicate(true)


func resonance_records(placements: Array = []) -> Array:
	var source: Array = placements if not placements.is_empty() else deployed
	var counts := {}
	for d in source:
		var entry := get_roster_entry(int(d["uid"]))
		if entry.is_empty():
			continue
		var element := str(ContentDB.pet(str(entry["species"])).get("element", ""))
		if element.is_empty():
			continue
		counts[element] = int(counts.get(element, 0)) + 1
	var out: Array = []
	for eid in counts.keys():
		var tier := ContentDB.resonance_tier(str(eid), int(counts[eid]))
		if tier.is_empty():
			continue
		var cfg := ContentDB.resonance(str(eid))
		out.append({
			"element": str(eid), "count": int(counts[eid]),
			"name": str(cfg.get("name", eid)),
			"color": str(cfg.get("color", "#ffffff")),
			"tier": tier,
		})
	return out


func resonance_mods(placements: Array = []) -> Dictionary:
	var mods := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0, "crit": 0.0}
	for record in resonance_records(placements):
		var tier: Dictionary = record["tier"]
		for key in (tier.get("mods", {}) as Dictionary).keys():
			if mods.has(key):
				mods[key] = float(mods[key]) + float(tier["mods"][key])
	return mods


func _attach_enemy_affixes(unit: Dictionary, count: int) -> void:
	if count <= 0:
		return
	var picks := ContentDB.affix_candidates(rng, count)
	for i in range(picks.size()):
		var slot := "normal" if i % 2 == 0 else "ultimate"
		var lst: Array = unit["affixes"][slot]
		if lst.size() < int(ContentDB.combat().get("affix_max_per_skill", 3)):
			lst.append(str(picks[i]["id"]))


func build_enemy_unit(pid: String, level: int, stat_mult: float = 1.0, affix_count: int = 0) -> Dictionary:
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
		"statuses": {}, "is_boss": false, "is_hero": false, "buff_ids": [],
		"last_stand_used": false, "tier": 0, "phases": [], "phase_index": 0,
		"mark": (p.get("mark", {}) as Dictionary).duplicate(true),
		"marks": {},
		"rarity": str(p.get("rarity", "common")),
	}
	next_uid += 1
	_attach_enemy_affixes(unit, affix_count)
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
		"statuses": {}, "is_boss": true, "is_hero": false, "buff_ids": buff_ids.duplicate(),
		"last_stand_used": false, "tier": int(boss_data.get("tier", 1)),
		"phases": boss_data.get("phases", []).duplicate(true), "phase_index": 0,
		"king_barrier": bool(boss_data.get("demon_king", false)),
		"demon_king": bool(boss_data.get("demon_king", false)),
		"rarity": "",
	}
	next_uid += 1
	_apply_boss_buffs(unit, buff_ids)
	return unit


func _apply_boss_buffs(unit: Dictionary, buff_ids: Array, scale: float = 1.0) -> void:
	for bid in buff_ids:
		match str(bid):
			"frenzy":
				unit["atk"] = int(round(float(unit["atk"]) * (1.0 + 0.30 * scale)))
			"undying":
				unit["max_hp"] = int(round(float(unit["max_hp"]) * (1.0 + 0.40 * scale)))
				unit["hp"] = unit["max_hp"]
			"bedrock":
				unit["def"] = int(round(float(unit["def"]) * (1.0 + 0.30 * scale)))
			"swift":
				unit["spd"] = int(round(float(unit["spd"]) * (1.0 + 0.25 * scale)))
			"bloodthirst":
				unit["hooks"]["lifesteal"] += 0.25 * scale
			"barbed":
				unit["hooks"]["reflect"] += 0.18 * scale
			"renewal":
				unit["hooks"]["regen"] += 0.07 * scale
			"oppress":
				unit["hooks"]["oppress"] += 0.15 * scale
			"warded":
				unit["hooks"]["warded"] = 1.0 - 0.15 * scale
			"surge":
				unit["hooks"]["ult_damage"] += 0.40 * scale
			"pierce":
				unit["hooks"]["pierce"] = float(unit["hooks"].get("pierce", 0.0)) + 0.30 * scale
			"enrage":
				unit["hooks"]["enrage"] = float(unit["hooks"].get("enrage", 0.0)) + 0.35 * scale
			"siphon":
				unit["hooks"]["lifesteal"] += 0.15 * scale
				unit["hooks"]["regen"] += 0.03 * scale


func _place_by_class(group: Array, slots: Array, skip_boss: bool) -> void:
	var body: Array = []
	for u in group:
		if skip_boss and bool(u.get("is_boss", false)):
			continue
		body.append(u)
	var rank := {"guardian": 0, "warrior": 1, "support": 2, "archer": 3, "mage": 4}
	body.sort_custom(func(a, b):
		var ra := int(rank.get(str(a.get("class", "")), 9))
		var rb := int(rank.get(str(b.get("class", "")), 9))
		if ra != rb:
			return ra < rb
		return int(a.get("uid", 0)) < int(b.get("uid", 0)))
	var ordered: Array = slots.duplicate()
	ordered.sort_custom(func(a, b):
		if int(a[1]) != int(b[1]):
			return int(a[1]) < int(b[1])
		return int(a[0]) < int(b[0]))
	for i in range(mini(body.size(), ordered.size())):
		body[i]["row"] = int(ordered[i][0])
		body[i]["col"] = int(ordered[i][1])


func _scale_enemy(unit: Dictionary, mult: float) -> void:
	unit["max_hp"] = maxi(1, int(round(float(unit["max_hp"]) * mult)))
	unit["hp"] = unit["max_hp"]
	unit["atk"] = maxi(1, int(round(float(unit["atk"]) * mult)))
	unit["def"] = maxi(0, int(round(float(unit["def"]) * mult)))
	unit["spd"] = maxi(1, int(round(float(unit["spd"]) * mult)))


func _king_escort_pool() -> Array:
	var ids: Array = []
	for pid in ContentDB.all_pet_ids():
		var rarity := str(ContentDB.pet(str(pid)).get("rarity", ""))
		if rarity == "legend" or rarity == "hero":
			ids.append(str(pid))
	for dmn in ContentDB.data.get("demons", []):
		var did := str(dmn.get("id", ""))
		if not did.is_empty():
			ids.append(did)
	return ids


func _pick_king_escorts(count: int) -> Array:
	var pool := _king_escort_pool()
	if pool.is_empty() or count <= 0:
		return []
	_shuffle(pool)
	var out: Array = []
	for i in range(mini(count, pool.size())):
		out.append(str(pool[i]))
	while out.size() < count:
		out.append(str(pool[rng.randi_range(0, pool.size() - 1)]))
	return out


func _make_fallen(unit: Dictionary) -> void:
	var scale := float(ContentDB.combat().get("fallen_stat_mult", 1.35))
	_scale_enemy(unit, scale)
	unit["fallen"] = true
	unit["is_hero"] = true
	unit["king_escort"] = true
	unit["skill_power"] = float(ContentDB.combat().get("fallen_skill_mult", 1.40))
	unit["name"] = "堕落·" + str(unit.get("name", ""))
	var skills: Dictionary = unit.get("skills", {})
	for slot in ["normal", "ultimate"]:
		if not skills.has(slot):
			continue
		var sk: Dictionary = skills[slot]
		if sk.has("chance"):
			sk["chance"] = minf(0.95, float(sk["chance"]) * 1.40)
		if sk.has("value"):
			sk["value"] = float(sk["value"]) * 1.35
		skills[slot] = sk
	unit["skills"] = skills
	var buff := ContentDB.random_boss_buff(rng)
	if not buff.is_empty():
		_apply_boss_buffs(unit, [str(buff.get("id", ""))], 0.80)
		var ids: Array = unit.get("buff_ids", [])
		ids.append(str(buff.get("id", "")))
		unit["buff_ids"] = ids


func _empower_king_escort(unit: Dictionary) -> void:
	unit["king_escort"] = true
	var rarity := str(unit.get("rarity", ""))
	if rarity == "hero":
		_make_fallen(unit)
		return
	if rarity == "demon":
		return
	var mults: Dictionary = ContentDB.combat().get("rarity_stat_mult", {})
	var mine := float(mults.get(rarity, 1.0))
	var demon_m := float(mults.get("demon", 1.65))
	if mine > 0.0 and mine < demon_m:
		_scale_enemy(unit, demon_m / mine)


func generate_encounter(floor_num: int) -> Dictionary:
	var f: Dictionary = ContentDB.floor(floor_num)
	if f.is_empty():
		push_error("Unknown floor %d" % floor_num)
		return {}
	var enemies: Array = []
	var boss_buffs: Array = []
	var formation: Dictionary = ContentDB.data.get("formation", {})
	var affix_count := int(f.get("minion_affix_count", 0))
	if str(f.get("kind", "normal")) == "boss" and f.get("boss"):
		var boss_data: Dictionary = ContentDB.boss(str(f["boss"]))
		var buff_count := int(boss_data.get("buff_count", 1))
		for i in range(buff_count):
			var b := ContentDB.random_boss_buff(rng, boss_buffs)
			if not b.is_empty():
				boss_buffs.append(str(b["id"]))
		var boss_level := int(f["level"]) + int(boss_data.get("level_offset", 0))
		if bool(boss_data.get("demon_king", false)):
			var king_cap := int(ContentDB.combat().get("rarity_max_level", {}).get("demon_king", 150))
			boss_level = mini(king_cap, boss_level)
		var boss_unit := build_boss_unit(boss_data, boss_level, boss_buffs)
		var bt: Dictionary = formation.get("boss_templates", {}).get(str(boss_data["id"]), {})
		var boss_pos: Array = bt.get("boss", [1, 2])
		boss_unit["row"] = int(boss_pos[0])
		boss_unit["col"] = int(boss_pos[1])
		enemies.append(boss_unit)
		var minion_positions: Array = bt.get("minions", [])
		var minion_ids: Array = []
		if bool(boss_data.get("demon_king", false)):
			var want := maxi(int(ContentDB.combat().get("king_escort_min", 2)), int(f.get("minion_count", 2)))
			if not minion_positions.is_empty():
				want = maxi(int(ContentDB.combat().get("king_escort_min", 2)), mini(want, minion_positions.size()))
			minion_ids = _pick_king_escorts(want)
		else:
			minion_ids = pick_species(f.get("pool", []), int(f.get("minion_count", 0)))
		for i in range(minion_ids.size()):
			var lv := maxi(1, int(f["level"]) + int(f.get("minion_level_offset", 0)))
			var mu := build_enemy_unit(str(minion_ids[i]), lv, float(f.get("minion_stat_mult", 1.0)), affix_count)
			if bool(boss_data.get("demon_king", false)):
				_empower_king_escort(mu)
			if i < minion_positions.size():
				mu["row"] = int(minion_positions[i][0])
				mu["col"] = int(minion_positions[i][1])
			enemies.append(mu)
	else:
		var ids := pick_species(f.get("pool", []), int(f.get("enemy_count", 1)))
		var template: Array = formation.get("enemy_templates", {}).get(str(ids.size()), [])
		for i in range(ids.size()):
			var mu := build_enemy_unit(str(ids[i]), int(f["level"]), float(f.get("enemy_stat_mult", 1.0)), affix_count)
			if i < template.size():
				mu["row"] = int(template[i][0])
				mu["col"] = int(template[i][1])
			enemies.append(mu)
	if str(f.get("kind", "normal")) == "boss":
		var minion_slots: Array = []
		var bt2: Dictionary = formation.get("boss_templates", {}).get(str(f.get("boss", "")), {})
		minion_slots = bt2.get("minions", [])
		_place_by_class(enemies, minion_slots, true)
	else:
		var slots: Array = formation.get("enemy_templates", {}).get(str(enemies.size()), [])
		_place_by_class(enemies, slots, false)
	var cursed := curse_floors.has(floor_num)
	if cursed:
		var cm := float(ContentDB.combat().get("curse_stat_mult", 1.25))
		for e in enemies:
			_scale_enemy(e, cm)
	encounter = {
		"floor": floor_num,
		"floor_data": f,
		"enemies": enemies,
		"boss_buffs": boss_buffs,
		"kind": f.get("kind", "normal"),
		"curse": cursed,
	}
	emit_signal("state_changed")
	return encounter


func conquest_plan() -> Array:
	var kings := ["k1", "k2", "k3", "k4"]
	var plan: Array = []
	for count in range(1, kings.size() + 1):
		var combos: Array = []
		_king_combos_rec(kings, count, 0, [], combos)
		for squad in combos:
			plan.append({"kings": squad})
	var five: Array = kings.duplicate()
	five.append("k1")
	plan.append({"kings": five})
	return plan


func _king_combos_rec(kings: Array, n: int, start: int, cur: Array, out: Array) -> void:
	if cur.size() == n:
		out.append(cur.duplicate())
		return
	for i in range(start, kings.size()):
		cur.append(kings[i])
		_king_combos_rec(kings, n, i + 1, cur, out)
		cur.pop_back()


func _conquest_king_index(floor_num: int) -> int:
	if floor_num <= 0 or floor_num % 10 != 0:
		return -1
	return int(floor_num / 10) - 1


func is_conquest_king_floor(floor_num: int = -1) -> bool:
	if floor_num < 0:
		floor_num = current_floor
	return _conquest_king_index(floor_num) >= 0


func is_conquest_finale() -> bool:
	if run_mode != "conquest":
		return false
	return _conquest_king_index(current_floor) >= conquest_plan().size() - 1


func _conquest_template_floor(floor_num: int) -> int:
	if floor_num % 10 == 0:
		return -1
	var decade := int((floor_num - 1) / 10)
	var slot := (floor_num - 1) % 10
	return 1 + (decade % 4) * 10 + slot


func _conquest_slots() -> Array:
	return [[1, 2], [0, 2], [2, 2], [0, 1], [2, 1], [1, 1], [1, 0], [0, 0], [2, 0]]


func generate_conquest_encounter() -> Dictionary:
	if is_conquest_king_floor():
		return _generate_conquest_king()
	return _generate_conquest_normal()


func _generate_conquest_normal() -> Dictionary:
	var base_n := _conquest_template_floor(current_floor)
	if base_n < 1:
		base_n = 1
	var base: Dictionary = ContentDB.floor(base_n)
	var target_lv := party_level()
	var base_lv := maxi(1, int(base.get("level", 10)))
	generate_encounter(base_n)
	var scale := float(target_lv) / float(base_lv)
	if absf(scale - 1.0) > 0.01:
		for e in encounter.get("enemies", []):
			_scale_enemy(e, scale)
			e["level"] = target_lv
	var title := "第 %d 层" % current_floor
	if str(encounter.get("kind", "normal")) == "boss":
		title = "第 %d 层 · 首领" % current_floor
	encounter["floor"] = current_floor
	encounter["name"] = title
	encounter["king_ids"] = []
	encounter["grant_blade"] = false
	encounter["level"] = target_lv
	_fill_conquest_lineup(target_lv, int(base.get("minion_affix_count", 0)))
	var cursed := curse_floors.has(current_floor)
	if cursed and not bool(encounter.get("curse", false)):
		var cm := float(ContentDB.combat().get("curse_stat_mult", 1.25))
		for e in encounter.get("enemies", []):
			_scale_enemy(e, cm)
	elif not cursed and bool(encounter.get("curse", false)):
		var cm := float(ContentDB.combat().get("curse_stat_mult", 1.25))
		if cm > 0.0:
			for e in encounter.get("enemies", []):
				_scale_enemy(e, 1.0 / cm)
	encounter["curse"] = cursed
	_arm_conquest_infinite()
	conquest_step = maxi(0, int((current_floor - 1) / 10))
	emit_signal("state_changed")
	return encounter


func _generate_conquest_king() -> Dictionary:
	var plan := conquest_plan()
	var idx := clampi(_conquest_king_index(current_floor), 0, plan.size() - 1)
	var node: Dictionary = plan[idx]
	var level := party_level()
	var enemies: Array = []
	var king_ids: Array = []
	var slots := _conquest_slots()
	var used := 0
	var squad: Array = node.get("kings", [])
	for bid in squad:
		var boss_data := ContentDB.boss(str(bid))
		var buffs: Array = []
		var buff := ContentDB.random_boss_buff(rng)
		if not buff.is_empty():
			buffs.append(str(buff.get("id", "")))
		var boss_unit := build_boss_unit(boss_data, level, buffs)
		boss_unit["row"] = int(slots[used][0])
		boss_unit["col"] = int(slots[used][1])
		used += 1
		enemies.append(boss_unit)
		king_ids.append(str(bid))
	var title := "关底魔王"
	if not king_ids.is_empty():
		var names: Array = []
		for bid in king_ids:
			names.append(str(ContentDB.boss(str(bid)).get("name", bid)))
		title = "、".join(names)
	encounter = {
		"floor": current_floor,
		"name": title,
		"kind": "boss",
		"enemies": enemies,
		"boss_buffs": [],
		"king_ids": king_ids,
		"grant_blade": false,
		"level": level,
		"curse": false,
	}
	_fill_conquest_lineup(level, 0)
	if not is_conquest_king_floor():
		_arm_conquest_infinite()
	conquest_step = idx
	emit_signal("state_changed")
	return encounter


func _conquest_strong_pool() -> Array:
	var ids: Array = []
	for pid in ContentDB.all_pet_ids():
		if str(ContentDB.pet(str(pid)).get("rarity", "")) == "legend":
			ids.append(str(pid))
	for dmn in ContentDB.data.get("demons", []):
		var did := str(dmn.get("id", ""))
		if not did.is_empty():
			ids.append(did)
	return ids


func _fill_conquest_lineup(level: int, affix_count: int) -> void:
	if current_floor <= 5 and not is_conquest_king_floor():
		return
	var enemies: Array = encounter.get("enemies", [])
	while enemies.size() > 5:
		var drop := enemies.size() - 1
		for i in range(enemies.size() - 1, -1, -1):
			if not bool(enemies[i].get("demon_king", false)) and not bool(enemies[i].get("is_boss", false)):
				drop = i
				break
		enemies.remove_at(drop)
	var pool := _conquest_strong_pool()
	var slots := _conquest_slots()
	var used := {}
	for e in enemies:
		used["%d,%d" % [int(e.get("row", 0)), int(e.get("col", 0))]] = true
	var cap := 5
	if is_conquest_king_floor():
		var kings := 0
		for e2 in enemies:
			if bool(e2.get("demon_king", false)):
				kings += 1
		cap = mini(5, kings + 1)
	var guard := 0
	while enemies.size() < cap and not pool.is_empty() and guard < 8:
		guard += 1
		var pid := str(pool[rng.randi_range(0, pool.size() - 1)])
		var unit := build_enemy_unit(pid, level, 1.0, affix_count)
		var placed := false
		for s in slots:
			var key := "%d,%d" % [int(s[0]), int(s[1])]
			if used.has(key):
				continue
			unit["row"] = int(s[0])
			unit["col"] = int(s[1])
			used[key] = true
			placed = true
			break
		if not placed:
			break
		enemies.append(unit)
	encounter["enemies"] = enemies


func _arm_conquest_infinite() -> void:
	var enemies: Array = encounter.get("enemies", [])
	if enemies.is_empty():
		return
	var picks: Array = []
	for e in enemies:
		if not bool(e.get("demon_king", false)):
			picks.append(e)
	if picks.is_empty():
		picks = enemies
	var unit: Dictionary = picks[rng.randi_range(0, picks.size() - 1)]
	var affix_n := 1 + int(current_floor / 5)
	var item_n := 1 + int(current_floor / 10)
	if not unit.has("affixes"):
		unit["affixes"] = {"normal": [], "ultimate": []}
	for i in affix_n:
		var a := ContentDB.random_affix(rng)
		if a.is_empty():
			continue
		var slot := "normal" if i % 2 == 0 else "ultimate"
		(unit["affixes"][slot] as Array).append(str(a["id"]))
	var ids: Array = []
	for _i in item_n:
		var it := ContentDB.random_item(rng, 0.0, ["barrier_blade"])
		if it.is_empty() or str(it.get("id", "")) == "barrier_blade":
			continue
		ids.append(str(it["id"]))
	var packed := _mods_from_ids(ids)
	var sm: Dictionary = packed["mods"]
	unit["max_hp"] = maxi(1, int(round(float(unit["max_hp"]) * (1.0 + float(sm.get("hp", 0.0))))))
	unit["hp"] = int(unit["max_hp"])
	unit["atk"] = maxi(1, int(round(float(unit["atk"]) * (1.0 + float(sm.get("atk", 0.0))))))
	unit["def"] = maxi(0, int(round(float(unit["def"]) * (1.0 + float(sm.get("def", 0.0))))))
	unit["spd"] = maxi(1, int(round(float(unit["spd"]) * (1.0 + float(sm.get("spd", 0.0))))))
	var hooks: Dictionary = unit.get("hooks", _new_hooks())
	for key in (packed["hooks"] as Dictionary).keys():
		hooks[key] = packed["hooks"][key]
	hooks["barrier_blade"] = 0.0
	unit["hooks"] = hooks
	unit["crit"] = float(unit.get("crit", 0.05)) + float(hooks.get("crit", 0.0))
	unit["carried_items"] = ids
	if not str(unit.get("name", "")).begins_with("无限·"):
		unit["name"] = "无限·" + str(unit.get("name", ""))
	unit["uncapped_enemy"] = true


# ---------------------------------------------------------------- items/units

func item_counts() -> Dictionary:
	var counts := {}
	for iid in items:
		counts[iid] = int(counts.get(iid, 0)) + 1
	for entry in roster:
		for iid in entry.get("carried", []):
			counts[iid] = int(counts.get(iid, 0)) + 1
	return counts


func carry_cap(entry: Dictionary) -> int:
	if bool(entry.get("uncapped", false)):
		return 0
	return 3


func carry_item(uid: int, iid: String) -> String:
	var index := items.find(iid)
	if index < 0:
		return "行囊里没有这件道具。"
	var entry := get_roster_entry(uid)
	if entry.is_empty():
		return "没有这只精灵。"
	if not entry.has("carried"):
		entry["carried"] = []
	var carried: Array = entry["carried"]
	var cap := carry_cap(entry)
	if cap > 0 and carried.size() >= cap:
		return "%s 已经带了 %d 件。贴了无限的精灵才不限数量。" % [pet_name(entry), cap]
	carried.append(iid)
	items.remove_at(index)
	emit_signal("state_changed")
	return "%s 带上了 %s。" % [pet_name(entry), str(ContentDB.item(iid).get("name", iid))]


func unequip_item(uid: int, index: int) -> String:
	var entry := get_roster_entry(uid)
	if entry.is_empty():
		return "没有这只精灵。"
	var carried: Array = entry.get("carried", [])
	if index < 0 or index >= carried.size():
		return "没有这件道具。"
	var iid := str(carried[index])
	carried.remove_at(index)
	items.append(iid)
	emit_signal("state_changed")
	return "%s 卸下了 %s。" % [pet_name(entry), str(ContentDB.item(iid).get("name", iid))]


func add_item(iid: String) -> bool:
	var cap := ContentDB.max_stack_for(iid)
	if cap > 0 and int(item_counts().get(iid, 0)) >= cap:
		return false
	items.append(iid)
	run_stats["items_found"] += 1
	emit_signal("state_changed")
	return true


func remove_weakest_item() -> String:
	var best_rank := 99
	var bag_index := -1
	for i in range(items.size()):
		var rarity := str(ContentDB.item(str(items[i])).get("rarity", "common"))
		var rank: int = {"common": 0, "rare": 1, "epic": 2}.get(rarity, 0)
		if rank < best_rank:
			best_rank = rank
			bag_index = i
	var pet_uid := -1
	var pet_index := -1
	for entry in roster:
		var carried: Array = entry.get("carried", [])
		for i in range(carried.size()):
			var rarity := str(ContentDB.item(str(carried[i])).get("rarity", "common"))
			var rank: int = {"common": 0, "rare": 1, "epic": 2}.get(rarity, 0)
			if rank < best_rank:
				best_rank = rank
				bag_index = -1
				pet_uid = int(entry["uid"])
				pet_index = i
	if bag_index >= 0:
		var removed := str(items[bag_index])
		items.remove_at(bag_index)
		return removed
	if pet_uid >= 0:
		var entry := get_roster_entry(pet_uid)
		var carried: Array = entry.get("carried", [])
		var removed := str(carried[pet_index])
		carried.remove_at(pet_index)
		return removed
	return ""


func item_mods_for(entry: Dictionary) -> Dictionary:
	return _mods_from_ids(entry.get("carried", []))


func item_mods() -> Dictionary:
	return _mods_from_ids(items)


func _mods_from_ids(ids: Array) -> Dictionary:
	var mods := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	var hooks := _new_hooks()
	for iid in ids:
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
	var mods_data := item_mods_for(entry)
	var stat_mods: Dictionary = mods_data["mods"]
	var hooks: Dictionary = mods_data["hooks"]
	var trainer_mods: Dictionary = trainer.get("mods", {})
	var res_mods := resonance_mods()
	var pid := str(entry["species"])
	var lv := int(entry["level"])
	var st: Dictionary = ContentDB.pet_stats(pid, lv)
	var resonance := int(entry.get("resonance", 0))
	var res_mult := 1.0 + float(resonance) * float(ContentDB.combat().get("resonance_bonus", 0.08)) * (1.0 + float(hooks.get("resonance", 0.0)))
	var hero := bool(entry.get("hero", false))
	var hstar := int(entry.get("hero_star", 0))
	var hm := ContentDB.hero_stat_mult()
	var rarity := str(ContentDB.pet(pid).get("rarity", "common"))
	var innate := rarity == "hero" or rarity == "demon"
	var hp := float(st["hp"]) * res_mult * (1.0 + float(stat_mods["hp"])) * (1.0 + float(trainer_mods.get("hp_mult", 0.0)))
	var atk := float(st["atk"]) * res_mult * (1.0 + float(stat_mods["atk"])) * (1.0 + float(trainer_mods.get("atk_mult", 0.0)))
	var def := float(st["def"]) * res_mult * (1.0 + float(stat_mods["def"])) * (1.0 + float(trainer_mods.get("def_mult", 0.0)))
	var spd := float(st["spd"]) * res_mult * (1.0 + float(stat_mods["spd"])) * (1.0 + float(trainer_mods.get("spd_mult", 0.0)))
	if hero:
		var star_mult := 1.0 + float(hstar) * float(ContentDB.combat().get("hero_star_bonus", 0.06))
		if not innate:
			hp *= float(hm.get("hp", 1.0))
			atk *= float(hm.get("atk", 1.0))
			def *= float(hm.get("def", 1.0))
			spd *= float(hm.get("spd", 1.0))
		hp *= star_mult
		atk *= star_mult
		def *= star_mult
		spd *= star_mult
	hp *= 1.0 + float(run_bonuses["hp"]) + float(res_mods["hp"])
	atk *= 1.0 + float(run_bonuses["atk"]) + float(res_mods["atk"])
	def *= 1.0 + float(run_bonuses["def"]) + float(res_mods["def"])
	spd *= 1.0 + float(run_bonuses["spd"]) + float(res_mods["spd"])
	return {
		"hp": int(round(hp)), "atk": int(round(atk)),
		"def": int(round(def)), "spd": int(round(spd)),
	}


func build_player_units() -> Array:
	var stat_mods := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	var hooks := _new_hooks()
	var trainer_mods: Dictionary = trainer.get("mods", {})
	var res_mods := resonance_mods()
	var units: Array = []
	for d in deployed:
		var entry := get_roster_entry(int(d["uid"]))
		if entry.is_empty():
			continue
		var mods_data := item_mods_for(entry)
		stat_mods = mods_data["mods"]
		hooks = mods_data["hooks"]
		var pid := str(entry["species"])
		var p: Dictionary = ContentDB.pet(pid)
		var lv := int(entry["level"])
		var st: Dictionary = ContentDB.pet_stats(pid, lv)
		var resonance := int(entry.get("resonance", 0))
		var res_mult := 1.0 + float(resonance) * float(ContentDB.combat().get("resonance_bonus", 0.08)) * (1.0 + float(hooks.get("resonance", 0.0)))
		var hero := bool(entry.get("hero", false))
		var hstar := int(entry.get("hero_star", 0))
		var hm := ContentDB.hero_stat_mult()
		var rarity := str(p.get("rarity", "common"))
		var innate := rarity == "hero" or rarity == "demon"
		var hp := float(st["hp"]) * res_mult * (1.0 + float(stat_mods["hp"])) * (1.0 + float(trainer_mods.get("hp_mult", 0.0)))
		var atk := float(st["atk"]) * res_mult * (1.0 + float(stat_mods["atk"])) * (1.0 + float(trainer_mods.get("atk_mult", 0.0)))
		var def := float(st["def"]) * res_mult * (1.0 + float(stat_mods["def"])) * (1.0 + float(trainer_mods.get("def_mult", 0.0)))
		var spd := float(st["spd"]) * res_mult * (1.0 + float(stat_mods["spd"])) * (1.0 + float(trainer_mods.get("spd_mult", 0.0)))
		if hero:
			var star_mult := 1.0 + float(hstar) * float(ContentDB.combat().get("hero_star_bonus", 0.06))
			if not innate:
				hp *= float(hm.get("hp", 1.0))
				atk *= float(hm.get("atk", 1.0))
				def *= float(hm.get("def", 1.0))
				spd *= float(hm.get("spd", 1.0))
			hp *= star_mult
			atk *= star_mult
			def *= star_mult
			spd *= star_mult
		hp *= 1.0 + float(run_bonuses["hp"]) + float(res_mods["hp"])
		atk *= 1.0 + float(run_bonuses["atk"]) + float(res_mods["atk"])
		def *= 1.0 + float(run_bonuses["def"]) + float(res_mods["def"])
		spd *= 1.0 + float(run_bonuses["spd"]) + float(res_mods["spd"])
		var display := pet_name(entry)
		ensure_arts(entry)
		var skills: Dictionary = p.get("skills", {}).duplicate(true)
		var phases: Array = []
		if hero:
			var ult: Dictionary = skills.get("ultimate", {})
			if ult.has("mult"):
				ult["mult"] = float(ult["mult"]) * ContentDB.hero_skill_mult()
			phases.append({
				"hp_pct": 0.45, "buff": str(entry.get("hero_buff", "")),
				"scale": ContentDB.hero_buff_scale(hstar),
				"text": "%s 觉醒！英雄之力全面爆发！" % display,
			})
		var unit := {
			"uid": int(entry["uid"]), "side": "player", "species": pid,
			"name": display,
			"element": p.get("element", "fire"), "class": p.get("class", "warrior"),
			"level": lv, "stage": int(st.get("stage", 0)),
			"max_hp": int(round(hp)), "hp": int(round(hp)),
			"atk": int(round(atk)), "def": int(round(def)), "spd": int(round(spd)),
			"crit": float(ContentDB.combat().get("crit_base", 0.05)) + float(hooks.get("crit", 0.0)) + float(trainer_mods.get("crit", 0.0)) + float(run_bonuses["crit"]) + float(res_mods["crit"]),
			"rage": 0, "shield": 0,
			"row": int(d["row"]), "col": int(d["col"]),
			"skills": skills,
			"affixes": (entry["affixes"] as Dictionary).duplicate(true),
			"hooks": hooks.duplicate(true),
			"statuses": {}, "is_boss": false, "is_hero": hero, "buff_ids": [],
			"last_stand_used": false, "tier": 1 if hero else 0,
			"phases": phases, "phase_index": 0,
			"resonance": resonance, "hero_star": hstar,
			"mark": (p.get("mark", {}) as Dictionary).duplicate(true),
			"marks": {},
			"rarity": str(p.get("rarity", "common")),
			"blade_lives": _blade_lives_for(entry),
			"uses_spirit": true,
			"arts": (entry.get("arts", []) as Array).duplicate(true),
			"passive": (entry.get("passive", {}) as Dictionary).duplicate(true),
		}
		if hero and not str(entry.get("hero_buff", "")).is_empty():
			_apply_boss_buffs(unit, [str(entry["hero_buff"])], ContentDB.hero_buff_scale(hstar))
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
	_maybe_grant_blade()
	run_stats["battles_won"] += 1
	run_stats["floors_cleared"] = maxi(int(run_stats["floors_cleared"]), current_floor)
	var old_names := {}
	for e in roster:
		old_names[int(e["uid"])] = pet_name(e)
	var step := _growth_step()
	for e in roster:
		if bool(e.get("uncapped", false)):
			e["level"] = int(e["level"]) + step
		else:
			var cap := pet_max_level(e)
			e["level"] = mini(cap, int(e["level"]) + step)
	var evolutions: Array = []
	for e in roster:
		var uid := int(e["uid"])
		var new_name := pet_name(e)
		if old_names.has(uid) and str(old_names[uid]) != new_name:
			evolutions.append({"uid": uid, "from": old_names[uid], "to": new_name})
	var cleared := false
	if run_mode == "conquest":
		cleared = is_conquest_finale()
		if cleared:
			conquest_clear = true
	else:
		cleared = current_floor >= ContentDB.total_floors()
		best_floor = maxi(best_floor, current_floor)
	var gained := 16 + current_floor * 4
	if curse_floors.has(current_floor):
		gained += 20
	gold += gained
	if cleared:
		if run_mode != "conquest":
			tower_cleared = true
		if not run_won and persist_enabled:
			total_wins += 1
		run_won = true
		run_active = false
		save_record()
	else:
		save_record()
	roll_rewards()
	if blade_forged_pending:
		pending_rewards["forged"] = true
		blade_forged_pending = false
	if run_notice != "":
		pending_rewards["notice"] = run_notice
		run_notice = ""
	emit_signal("state_changed")
	return {"evolutions": evolutions, "rewards": pending_rewards, "won": run_won}


func _maybe_grant_blade() -> void:
	var due := int(blade_trial_floor) == current_floor or bool(encounter.get("grant_blade", false))
	if not due:
		return
	blade_trial_floor = 0
	encounter["grant_blade"] = false
	if holds_sword():
		return
	var shard := _next_blade_shard()
	if shard == "":
		return
	if not add_item(shard):
		return
	var got := _owned_shard_count()
	if got >= BLADE_SHARDS.size():
		_forge_blade()
		return
	var shard_name := str(ContentDB.item(shard).get("name", shard))
	run_notice = "试炼通过，获得%s（%d/4）。让一只精灵携带后生效。集齐四块会合成破魔圣剑。" % [shard_name, got]


func _capped_item_ids() -> Array:
	var out: Array = []
	var counts := item_counts()
	for iid in counts.keys():
		var cap := ContentDB.max_stack_for(str(iid))
		if cap > 0 and int(counts[iid]) >= cap:
			out.append(str(iid))
	return out


func _roll_item_dict() -> Dictionary:
	var luck := float(trainer.get("item_bonus", 0.0)) + float(item_mods()["hooks"].get("item_luck", 0.0))
	return ContentDB.random_item(rng, luck, _capped_item_ids())


func _unowned_of_rarity(rarity: String) -> Array:
	var out: Array = []
	for pid in ContentDB.all_pet_ids():
		if owned_species.has(str(pid)):
			continue
		if str(ContentDB.pet(str(pid)).get("rarity", "common")) == rarity:
			out.append(str(pid))
	return out


func _roll_chest_pet() -> Dictionary:
	var weights: Dictionary = ContentDB.combat().get("chest_rarity_weights", {})
	var order: Array = ["hero", "legend", "epic", "rare", "common"]
	var total := 0
	for key in order:
		total += int(weights.get(str(key), 0))
	var chosen := "common"
	if total > 0:
		var roll := rng.randi_range(1, total)
		var acc := 0
		for key in order:
			acc += int(weights.get(str(key), 0))
			if roll <= acc:
				chosen = str(key)
				break
	var start := order.find(chosen)
	if start < 0:
		start = order.size() - 1
	for i in range(start, order.size()):
		var bucket := _unowned_of_rarity(str(order[i]))
		if not bucket.is_empty():
			return {"kind": "new", "species": str(bucket[rng.randi_range(0, bucket.size() - 1)])}
	var all: Array = ContentDB.all_pet_ids()
	if all.is_empty():
		return {"kind": "none"}
	return {"kind": "resonance", "species": str(all[rng.randi_range(0, all.size() - 1)])}


func owns_breaker() -> bool:
	for entry in roster:
		if _entry_breaks_barrier(entry):
			return true
	return false


func deployed_breaker() -> bool:
	for uid in deployed_uids():
		if _entry_breaks_barrier(get_roster_entry(uid)):
			return true
	return false


func _entry_breaks_barrier(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if bool(entry.get("hero", false)):
		return true
	if str(ContentDB.pet(str(entry.get("species", ""))).get("rarity", "")) == "demon":
		return true
	var affixes: Dictionary = entry.get("affixes", {})
	for slot in _affix_slots(entry):
		if "barrier_blade" in (affixes.get(slot, []) as Array):
			return true
	if "barrier_blade" in (entry.get("carried", []) as Array):
		return true
	return false


func _entry_has_sword(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	if "barrier_blade" in (entry.get("carried", []) as Array):
		return true
	var affixes: Dictionary = entry.get("affixes", {})
	for slot in _affix_slots(entry):
		if "barrier_blade" in (affixes.get(slot, []) as Array):
			return true
	return false


func _owns_item_anywhere(iid: String) -> bool:
	if items.has(iid):
		return true
	for entry in roster:
		if iid in (entry.get("carried", []) as Array):
			return true
	return false


func _next_blade_shard() -> String:
	for iid in BLADE_SHARDS:
		if not _owns_item_anywhere(str(iid)):
			return str(iid)
	return ""


func _owned_shard_count() -> int:
	var n := 0
	for iid in BLADE_SHARDS:
		if _owns_item_anywhere(str(iid)):
			n += 1
	return n


func _strip_item_everywhere(iid: String) -> void:
	while items.has(iid):
		items.erase(iid)
	for entry in roster:
		var carried: Array = entry.get("carried", [])
		var kept: Array = []
		for owned in carried:
			if str(owned) != iid:
				kept.append(owned)
		entry["carried"] = kept


func _forge_blade() -> void:
	for iid in BLADE_SHARDS:
		_strip_item_everywhere(str(iid))
	add_item("barrier_blade")
	blade_forged_pending = true
	run_notice = "四块圣剑碎片汇聚，破魔圣剑已经合成，放进了道具背包。"


func _blade_lives_for(entry: Dictionary) -> int:
	if _entry_has_sword(entry):
		return 10
	if "blade_shard_4" in (entry.get("carried", []) as Array):
		return 5
	return 0


func holds_sword() -> bool:
	if items.has("barrier_blade"):
		return true
	for entry in roster:
		if "barrier_blade" in (entry.get("carried", []) as Array):
			return true
	return holds_affix("barrier_blade")


func next_king_floor() -> int:
	if run_mode == "conquest":
		var nxt := (int(current_floor / 10) + 1) * 10
		if _conquest_king_index(nxt) >= conquest_plan().size():
			return 0
		return nxt
	for n in range(current_floor + 1, ContentDB.total_floors() + 1):
		var boss_id := str(ContentDB.floor(n).get("boss", ""))
		if bool(ContentDB.boss(boss_id).get("demon_king", false)):
			return n
	return 0


func grant_pact() -> String:
	var demon := _unowned_demon()
	if not demon.is_empty():
		var added := add_owned_species(demon)
		return "%s 回应了世代契约！" % str(added.get("name", demon))
	var heroes := _unowned_of_rarity("hero")
	if not heroes.is_empty():
		var pid := str(heroes[rng.randi_range(0, heroes.size() - 1)])
		var added_hero := add_owned_species(pid)
		return "英雄 %s 回应了世代契约！" % str(added_hero.get("name", pid))
	var uid := _random_uid()
	var entry := get_roster_entry(uid)
	if entry.is_empty():
		return "世代契约没有回应。"
	entry["resonance"] = int(entry.get("resonance", 0)) + 1
	return "契约已尽，%s 共鸣 +1。" % pet_name(entry)


func _king_ids_here() -> Array:
	if run_mode == "conquest":
		return encounter.get("king_ids", [])
	var boss_id := str(ContentDB.floor(current_floor).get("boss", ""))
	if bool(ContentDB.boss(boss_id).get("demon_king", false)):
		return [boss_id]
	return []


func _contract_species(boss_id: String) -> String:
	var preferred := str(ContentDB.boss(boss_id).get("reward_demon", ""))
	var pool: Array = []
	var weights: Array = []
	for dmn in ContentDB.data.get("demons", []):
		var did := str(dmn.get("id", ""))
		if did.is_empty() or owned_species.has(did):
			continue
		pool.append(did)
		weights.append(4 if did == preferred else 1)
	if pool.is_empty():
		return preferred
	var total := 0
	for w in weights:
		total += int(w)
	var roll := rng.randi_range(1, maxi(1, total))
	var acc := 0
	for i in range(pool.size()):
		acc += int(weights[i])
		if roll <= acc:
			return str(pool[i])
	return str(pool[0])


func _king_reward() -> Dictionary:
	var chance := float(ContentDB.combat().get("king_contract_chance", 0.15))
	var got: Array = []
	for bid in _king_ids_here():
		if rng.randf() >= chance:
			continue
		var species := _contract_species(str(bid))
		if not species.is_empty():
			got.append(species)
	if got.is_empty():
		return {"kind": "none"}
	return {"kind": "king", "species": str(got[0]), "species_list": got}


func claim_king_reward() -> Dictionary:
	if pending_rewards.is_empty() or bool(pending_rewards.get("claimed", {}).get("king", true)):
		return {}
	pending_rewards["claimed"]["king"] = true
	var reward: Dictionary = pending_rewards.get("king", {})
	if str(reward.get("kind", "")) != "king":
		return {}
	var species_list: Array = reward.get("species_list", [])
	if species_list.is_empty():
		species_list = [str(reward.get("species", ""))]
	var added := {}
	for species in species_list:
		if str(species).is_empty():
			continue
		added = add_owned_species(str(species))
	emit_signal("state_changed")
	return added


func _unowned_demon() -> String:
	var pool: Array = []
	var fallback: Array = []
	for dmn in ContentDB.data.get("demons", []):
		var did := str(dmn.get("id", ""))
		if did.is_empty() or owned_species.has(did):
			continue
		if str(dmn.get("from_boss", "")).begins_with("k"):
			fallback.append(did)
		else:
			pool.append(did)
	if pool.is_empty():
		pool = fallback
	if pool.is_empty():
		return ""
	return str(pool[rng.randi_range(0, pool.size() - 1)])


func roll_rewards() -> void:
	var pet_reward := _roll_chest_pet()
	# item is guaranteed; capped items (e.g. 战意项链, max 2) are excluded
	var item_reward := {"kind": "none"}
	var it := _roll_item_dict()
	if not it.is_empty():
		item_reward = {"kind": "item", "id": str(it["id"])}
	# affix is guaranteed; always offer three candidates
	var affix_reward := {"kind": "none"}
	var candidates := ContentDB.affix_candidates(rng, 3)
	var rare_chance := float(ContentDB.combat().get("rare_affix_chance", 0.10))
	var rare_ids: Array = ContentDB.combat().get("rare_affix_ids", [])
	if not candidates.is_empty() and not rare_ids.is_empty() and rng.randf() < rare_chance:
		var rare: Dictionary = ContentDB.affix(str(rare_ids[rng.randi_range(0, rare_ids.size() - 1)]))
		if not rare.is_empty():
			candidates[rng.randi_range(0, candidates.size() - 1)] = rare
	if not candidates.is_empty():
		affix_reward = {"kind": "affix", "candidates": candidates}
	# Heroes are a rarity tier inside the pet roll. Demons never come from chests.
	var hero_reward := {"kind": "none"}
	# cursed / elite floors pay out extra items
	var bonus_items: Array = []
	if curse_floors.has(current_floor):
		for i in range(int(ContentDB.combat().get("curse_bonus_items", 1))):
			var bonus := _roll_item_dict()
			if not bonus.is_empty():
				bonus_items.append(str(bonus["id"]))
	pending_rewards = {
		"floor": current_floor,
		"pet": pet_reward,
		"item": item_reward,
		"affix": affix_reward,
		"hero": hero_reward,
		"king": _king_reward(),
		"bonus_items": bonus_items,
		"claimed": {"pet": false, "item": false, "affix": false, "hero": false, "king": false},
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


func claim_hero_reward() -> Dictionary:
	if pending_rewards.is_empty() or bool(pending_rewards.get("claimed", {}).get("hero", true)):
		return {}
	pending_rewards["claimed"]["hero"] = true
	var r: Dictionary = pending_rewards.get("hero", {})
	if str(r.get("kind", "")) != "hero":
		emit_signal("state_changed")
		return {}
	var entry := add_hero_pet(str(r["species"]), str(r.get("buff", "frenzy")))
	return {"kind": "hero", "species": str(r["species"]), "entry": entry,
		"name": pet_name(entry), "buff": str(r.get("buff", ""))}


func claim_bonus_items() -> Array:
	var claimed: Array = []
	if pending_rewards.is_empty():
		return claimed
	for iid in pending_rewards.get("bonus_items", []):
		if add_item(str(iid)):
			claimed.append(str(iid))
	pending_rewards["bonus_items"] = []
	emit_signal("state_changed")
	return claimed


func claim_item_reward() -> Dictionary:
	if pending_rewards.is_empty() or pending_rewards["claimed"]["item"]:
		return {}
	var r: Dictionary = pending_rewards["item"]
	if str(r.get("kind", "")) != "item":
		pending_rewards["claimed"]["item"] = true
		return {}
	var iid := str(r["id"])
	add_item(iid)
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
	var it := _roll_item_dict()
	if not it.is_empty():
		add_item(str(it["id"]))
	pending_rewards["claimed"]["affix"] = true
	emit_signal("state_changed")
	return it


func skip_affix_reward() -> void:
	if pending_rewards.is_empty():
		return
	pending_rewards["claimed"]["affix"] = true
	emit_signal("state_changed")


func stash_affix_reward(affix_id: String) -> bool:
	if pending_rewards.is_empty() or pending_rewards["claimed"]["affix"]:
		return false
	var candidates: Array = pending_rewards["affix"].get("candidates", [])
	var allowed := false
	for a in candidates:
		if str(a.get("id", "")) == affix_id:
			allowed = true
			break
	if not allowed:
		return false
	affix_bag.append(affix_id)
	pending_rewards["claimed"]["affix"] = true
	emit_signal("state_changed")
	return true


func advance_floor() -> bool:
	if run_mode == "conquest":
		if is_conquest_finale():
			return false
		current_floor += 1
		pending_rewards = {}
		pending_event = {}
		generate_conquest_encounter()
		emit_signal("state_changed")
		return true
	if current_floor >= ContentDB.total_floors():
		return false
	current_floor += 1
	pending_rewards = {}
	pending_event = {}
	generate_encounter(current_floor)
	emit_signal("state_changed")
	return true


# ---------------------------------------------------------------- events

func is_event_floor(floor_num: int = -1) -> bool:
	if floor_num < 0:
		floor_num = current_floor
	if floor_num <= 0:
		return false
	if run_mode != "conquest":
		return false
	if is_conquest_king_floor(floor_num):
		return false
	var slot := floor_num % 10
	return slot == 4 or slot == 9


func should_offer_event() -> bool:
	if current_floor in event_done:
		return false
	return is_event_floor()


func is_route_floor(floor_num: int = -1) -> bool:
	if run_mode == "conquest":
		return false
	if floor_num < 0:
		floor_num = current_floor
	if floor_num <= 0 or floor_num >= ContentDB.total_floors():
		return false
	if floor_num % 10 == 0:
		return false
	return floor_num % 3 == 0


func should_offer_route() -> bool:
	return is_route_floor() and not route_done.has(current_floor)


func destination_after_floor() -> String:
	if should_offer_route():
		if pending_route.is_empty() or int(pending_route.get("floor", -1)) != current_floor:
			roll_route()
		return "route"
	if should_offer_event():
		if pending_event.is_empty():
			roll_event()
		return "event"
	return "map"


func roll_route() -> Dictionary:
	var kinds: Array = ["fight", "elite", "shop", "event"]
	_shuffle(kinds)
	var options: Array = []
	for i in range(mini(3, kinds.size())):
		options.append(_route_option(str(kinds[i])))
	if not holds_sword():
		options[0] = _route_option("blade")
	pending_route = {"floor": current_floor, "options": options}
	emit_signal("state_changed")
	return pending_route


func _route_option(kind: String) -> Dictionary:
	match kind:
		"fight":
			return {"kind": "fight", "title": "普通战斗", "desc": "按这一层原来的敌人开战。", "color": "#8fd0ff"}
		"elite":
			return {"kind": "elite", "title": "精英战斗", "desc": "敌人全属性 +25%，胜利多一笔金币。", "color": "#ff5d6c"}
		"shop":
			return {"kind": "shop", "title": "行商", "desc": "这一层不战斗。用金币买道具、词条、词条上限或灵契球。", "color": "#ffd166"}
		"blade":
			var n := _trial_hero_goal()
			return {"kind": "blade", "title": "圣剑试炼",
				"desc": "立刻开战，敌方有 %d 名英雄。打赢获得一块圣剑碎片。" % n, "color": "#f2d38a"}
		_:
			return {"kind": "event", "title": "奇遇", "desc": "三选一祝福。不战斗，直接进入下一层。", "color": "#c98bff"}


func apply_route(kind: String) -> String:
	if not route_done.has(current_floor):
		route_done.append(current_floor)
	pending_route = {}
	match kind:
		"elite":
			curse_floors[current_floor] = true
			generate_encounter(current_floor)
			return "map"
		"shop":
			return "shop"
		"event":
			roll_event(false)
			return "event"
		"blade":
			apply_event(_make_event("blade_trial"))
			return "map"
		_:
			return "map"


func leave_shop() -> void:
	grant_floor_growth()
	advance_floor()


func _quest_item(iid: String) -> bool:
	return iid == "barrier_blade" or iid == "pokeball" or str(iid).begins_with("blade_shard_")


func _epic_item_index() -> int:
	for i in range(items.size()):
		var iid := str(items[i])
		if _quest_item(iid):
			continue
		if str(ContentDB.item(iid).get("rarity", "")) == "epic":
			return i
	return -1


func _take_epic_item() -> String:
	var index := _epic_item_index()
	if index < 0:
		return ""
	var iid := str(items[index])
	items.remove_at(index)
	return iid


func raise_affix_cap(uid: int) -> String:
	var entry := get_roster_entry(uid)
	if entry.is_empty():
		return "没有这只精灵。"
	if bool(entry.get("uncapped", false)):
		return "这只精灵的词条已经没有上限。"
	var cap := pet_affix_cap(entry)
	if cap >= 9:
		return "词条上限已经是 9。"
	if gold < 80:
		return "金币不够。提升上限需要 80 金币。"
	gold -= 80
	entry["affix_cap"] = cap + 1
	emit_signal("state_changed")
	return "%s 的词条上限变为 %d。" % [pet_name(entry), cap + 1]


func item_pick_count(tid: String) -> int:
	var base := int(ContentDB.trainers_by_id.get(tid, {}).get("pick_items", 0))
	if tid != "veteran":
		return base
	return mini(9, base + int(trainer_deaths.get("veteran", 0)))


func miracle_bonus() -> float:
	return minf(0.28, float(int(trainer_deaths.get("novice", 0))) * 0.01)


func catch_bonus() -> float:
	return minf(0.20, float(int(trainer_deaths.get("master", 0))) * 0.02)


func _note_species(pid: String) -> void:
	if pid == "":
		return
	pokedex[pid] = true


func _note_death() -> void:
	var tid := trainer_id
	var before := _trainer_power(tid)
	trainer_deaths[tid] = int(trainer_deaths.get(tid, 0)) + 1
	if _trainer_power(tid) > before + 0.0001:
		wonder_line = true


func _trainer_power(tid: String) -> float:
	var deaths := int(trainer_deaths.get(tid, 0))
	if tid == "novice":
		return minf(0.28, float(deaths) * 0.01)
	if tid == "veteran":
		return float(mini(6, deaths))
	if tid == "master":
		return minf(0.20, float(deaths) * 0.02)
	return 0.0


func _random_uid(hero_only: bool = false) -> int:
	var pool: Array = []
	for e in roster:
		if hero_only and not bool(e.get("hero", false)):
			continue
		pool.append(int(e["uid"]))
	if pool.is_empty():
		return -1
	return int(pool[rng.randi_range(0, pool.size() - 1)])


func _random_unowned_species() -> String:
	var pool: Array = []
	for pid in ContentDB.all_pet_ids():
		if owned_species.has(str(pid)):
			continue
		if str(ContentDB.pet(str(pid)).get("rarity", "")) == "demon":
			continue
		pool.append(str(pid))
	if pool.is_empty():
		return ""
	return str(pool[rng.randi_range(0, pool.size() - 1)])


func _make_event(kind: String) -> Dictionary:
	match kind:
		"items":
			return {"id": "items", "kind": "items", "value": 2, "title": "星辉宝库",
				"desc": "获得 2 件随机道具，稀有度小幅提升。", "color": "#ffd166"}
		"relic":
			return {"id": "relic", "kind": "relic", "value": 1, "title": "远古遗物",
				"desc": "获得 1 件高品质道具，更可能是史诗。", "color": "#c98bff"}
		"bless_atk":
			return {"id": "bless_atk", "kind": "bless", "stat": "atk", "value": 0.06,
				"title": "力量祝福", "desc": "全队攻击永久 +6%。", "color": "#ff9a62"}
		"bless_hp":
			return {"id": "bless_hp", "kind": "bless", "stat": "hp", "value": 0.06,
				"title": "生命祝福", "desc": "全队最大生命永久 +6%。", "color": "#5be0a0"}
		"bless_def":
			return {"id": "bless_def", "kind": "bless", "stat": "def", "value": 0.08,
				"title": "铁壁祝福", "desc": "全队防御永久 +8%。", "color": "#8fd0ff"}
		"bless_spd":
			return {"id": "bless_spd", "kind": "bless", "stat": "spd", "value": 0.06,
				"title": "疾风祝福", "desc": "全队速度永久 +6%。", "color": "#3ddc97"}
		"resonance":
			return {"id": "resonance", "kind": "resonance", "title": "共鸣之泉",
				"desc": "随机一只精灵共鸣 +1（全属性 +8%）。", "color": "#5bb8ff"}
		"contract":
			return {"id": "contract", "kind": "contract", "title": "远古契约",
				"desc": "一只未拥有的精灵加入队伍。", "color": "#ffd76a"}
		"trial":
			return {"id": "trial", "kind": "trial", "title": "试炼之门",
				"desc": "下一层变为精英试炼：敌人全属性 +25%，胜利额外获得 1 件道具。",
				"color": "#ff5d6c"}
		"sacrifice":
			return {"id": "sacrifice", "kind": "sacrifice", "title": "献祭祭坛",
				"desc": "失去 1 件最弱道具，换取随机精灵共鸣 +2。", "color": "#c98bff"}
		"hero_forge":
			return {"id": "hero_forge", "kind": "hero_forge", "title": "英雄熔炉",
				"desc": "消耗一件史诗道具，让随机一名英雄升 1 星。", "color": "#ffd166"}
		"abyss":
			return {"id": "abyss", "kind": "abyss", "title": "深渊契约",
				"desc": "献祭 1 件道具，契约一只未拥有的魔人。若已全部契约，改为共鸣 +1。",
				"color": "#ff5d6c"}
		"pact":
			return {"id": "pact", "kind": "pact", "title": "世代契约",
				"desc": "免费契约一只魔人。魔人已尽时，改为契约一只英雄精灵。",
				"color": "#ffd166"}
		"blade_trial":
			return {"id": "blade_trial", "kind": "blade_trial", "title": "圣剑试炼",
				"desc": "立刻在本层开战。敌方里有英雄精灵，而且更强。打赢后获得一块圣剑碎片。集齐四块会自动合成破魔圣剑。不会跳到下一层。",
				"color": "#f2d38a"}
	return {}


func roll_event(include_blade: bool = true) -> Dictionary:
	var kinds: Array = []
	for kind in ["items", "relic", "bless_atk", "bless_hp", "bless_def", "bless_spd",
			"resonance", "contract", "trial", "sacrifice", "hero_forge"]:
		if kind == "contract" and _random_unowned_species().is_empty():
			continue
		if kind == "hero_forge" and _random_uid(true) < 0:
			continue
		if kind == "sacrifice" and items.is_empty():
			continue
		kinds.append(kind)
	_shuffle(kinds)
	var options: Array = []
	for i in range(mini(3, kinds.size())):
		options.append(_make_event(str(kinds[i])))
	var offer_blade := include_blade and not holds_sword()
	if offer_blade:
		var trial := _make_event("blade_trial")
		var hero_n := _trial_hero_goal()
		trial["desc"] = "立刻在本层开战。敌方有 %d 名英雄精灵，而且更强。打赢后获得一块圣剑碎片。集齐四块会自动合成破魔圣剑，之后试炼不再出现。不会跳到下一层。" % hero_n
		var replaced := false
		for i in range(options.size()):
			if str(options[i].get("kind", "")) != "blade_trial":
				options[i] = trial
				replaced = true
				break
		if not replaced:
			if options.is_empty():
				options.append(trial)
			else:
				options[options.size() - 1] = trial
	pending_event = {"floor": current_floor, "options": options}
	emit_signal("state_changed")
	return pending_event


func apply_event(option: Dictionary) -> String:
	var text := ""
	match str(option.get("kind", "")):
		"items":
			var got: Array = []
			for i in range(int(option.get("value", 2))):
				var it := _roll_item_dict()
				if not it.is_empty() and add_item(str(it["id"])):
					got.append(str(it["name"]))
			text = "获得道具：" + ("、".join(got) if not got.is_empty() else "宝库已空")
		"relic":
			var it2 := ContentDB.random_item(rng, 1.6, _capped_item_ids())
			if not it2.is_empty() and add_item(str(it2["id"])):
				text = "获得史诗道具：%s" % str(it2["name"])
			else:
				text = "遗物箱已空。"
		"bless":
			var stat := str(option.get("stat", "atk"))
			var value := float(option.get("value", 0.06))
			run_bonuses[stat] = float(run_bonuses.get(stat, 0.0)) + value
			var stat_name: String = {"hp": "最大生命", "atk": "攻击", "def": "防御", "spd": "速度"}.get(stat, stat)
			text = "全队%s永久 +%d%%。" % [stat_name, int(round(value * 100.0))]
		"resonance":
			var uid := _random_uid()
			var entry := get_roster_entry(uid)
			if not entry.is_empty():
				entry["resonance"] = int(entry.get("resonance", 0)) + 1
				text = "%s 共鸣 +1（全属性 +8%%）。" % pet_name(entry)
			else:
				text = "共鸣之泉暂无回应。"
		"contract":
			var pid := _random_unowned_species()
			if pid.is_empty():
				text = "所有精灵都已缔结契约。"
			else:
				var added := add_owned_species(pid)
				text = "%s 加入了队伍！" % str(added.get("name", pid))
		"trial":
			var nxt := current_floor + 1
			if nxt > ContentDB.total_floors():
				text = "星塔已到尽头，试炼之力无处施展。"
			else:
				curse_floors[nxt] = true
				text = "第 %d 层变为精英试炼：敌人全属性 +25%%，胜利额外获得道具。" % nxt
		"sacrifice":
			var removed := remove_weakest_item()
			if removed.is_empty():
				text = "祭坛需要一件道具作为代价。"
			else:
				var uid2 := _random_uid()
				var entry2 := get_roster_entry(uid2)
				if not entry2.is_empty():
					entry2["resonance"] = int(entry2.get("resonance", 0)) + 2
					text = "献祭 %s，%s 共鸣 +2。" % [str(ContentDB.item(removed).get("name", removed)), pet_name(entry2)]
				else:
					text = "祭坛吞下了道具，却没有任何回应。"
		"abyss", "pact":
			text = "魔人不再回应奇遇。只有打败魔王，才有机会契约魔人。"
		"blade_trial":
			curse_floors[current_floor] = true
			blade_trial_floor = current_floor
			event_battle = true
			if run_mode == "conquest":
				generate_conquest_encounter()
			else:
				generate_encounter(current_floor)
			_inject_blade_trial_hero()
			text = "本层化为第 %d 次圣剑试炼，敌方有 %d 名英雄精灵。打赢后获得一块圣剑碎片，集齐四块合成破魔圣剑。不会跳到下一层。" % [_trial_hero_goal(), _trial_hero_goal()]
		"hero_forge":
			var uid3 := _random_uid(true)
			var forged := upgrade_hero(uid3)
			if bool(forged.get("ok", false)):
				text = "%s 消耗一件史诗道具，升至 %d 星。" % [pet_name(get_roster_entry(uid3)), int(forged.get("star", 0))]
			else:
				text = str(forged.get("reason", "熔炉中没有可供锻造的英雄。"))
	event_done.append(current_floor)
	pending_event = {}
	if str(option.get("kind", "")) != "blade_trial":
		grant_floor_growth()
	emit_signal("state_changed")
	return text


func skip_event() -> void:
	if pending_event.is_empty():
		return
	event_done.append(current_floor)
	pending_event = {}
	grant_floor_growth()
	emit_signal("state_changed")


func _trial_hero_goal() -> int:
	return clampi(_owned_shard_count() + 1, 1, 4)


func _inject_blade_trial_hero() -> void:
	var enemies: Array = encounter.get("enemies", [])
	var want := _trial_hero_goal()
	var have := 0
	for e in enemies:
		if str(e.get("rarity", "")) == "hero" or bool(e.get("is_hero", false)):
			have += 1
	var heroes: Array = []
	for pid in ContentDB.all_pet_ids():
		if str(ContentDB.pet(str(pid)).get("rarity", "")) == "hero":
			heroes.append(str(pid))
	if heroes.is_empty():
		return
	_shuffle(heroes)
	var lv := int(encounter.get("level", 10))
	if not enemies.is_empty():
		lv = int(enemies[0].get("level", lv))
	var made := 0
	while have < want:
		var hero := _make_trial_hero(str(heroes[made % heroes.size()]), lv)
		made += 1
		if made > want + enemies.size():
			break
		var slot := -1
		for i in range(enemies.size()):
			var foe: Dictionary = enemies[i]
			if str(foe.get("rarity", "")) == "hero" or bool(foe.get("is_hero", false)):
				continue
			if bool(foe.get("is_boss", false)) or bool(foe.get("demon_king", false)):
				continue
			slot = i
			break
		if slot >= 0:
			hero["row"] = int(enemies[slot].get("row", 1))
			hero["col"] = int(enemies[slot].get("col", 1))
			enemies[slot] = hero
		elif enemies.size() < 5:
			hero["row"] = enemies.size() % 3
			hero["col"] = mini(2, int(enemies.size() / 3))
			enemies.append(hero)
		else:
			break
		have += 1
	encounter["enemies"] = enemies


func _make_trial_hero(pid: String, lv: int) -> Dictionary:
	var hero := build_enemy_unit(pid, lv, 1.0, 1)
	hero["is_hero"] = true
	var hname := str(hero.get("name", ""))
	if not hname.begins_with("英雄"):
		hero["name"] = "英雄·" + hname
	if curse_floors.has(current_floor):
		_scale_enemy(hero, float(ContentDB.combat().get("curse_stat_mult", 1.25)))
	return hero


func grant_floor_growth() -> void:
	run_stats["battles_won"] = int(run_stats.get("battles_won", 0)) + 1
	run_stats["floors_cleared"] = maxi(int(run_stats.get("floors_cleared", 0)), current_floor)
	var step := _growth_step()
	for e in roster:
		if bool(e.get("uncapped", false)):
			e["level"] = int(e["level"]) + step
		else:
			e["level"] = mini(pet_max_level(e), int(e["level"]) + step)


func end_run_defeat() -> void:
	run_active = false
	best_floor = maxi(best_floor, int(run_stats.get("floors_cleared", 0)))
	_note_death()
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
		"heroes": int(run_stats.get("heroes_found", 0)),
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
		tower_cleared = bool(parsed.get("tower_cleared", false)) or best_floor >= 40
		trainer_deaths = (parsed.get("trainer_deaths", {}) as Dictionary).duplicate(true)
		pokedex = (parsed.get("pokedex", {}) as Dictionary).duplicate(true)
	_peek_saved_run()


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
		"tower_cleared": tower_cleared,
		"trainer_deaths": trainer_deaths.duplicate(true),
		"pokedex": pokedex.duplicate(true),
	}, "  "))


func _autosave_run() -> void:
	if not persist_enabled:
		return
	if run_active:
		save_run()
	else:
		clear_saved_run()


func _screen_for_save() -> String:
	if not pending_event.is_empty():
		return "event"
	if not pending_rewards.is_empty() and not run_won:
		return "reward"
	return save_screen if save_screen != "" else "map"


func note_screen(screen: String) -> void:
	save_screen = screen
	save_run(screen)


func capture_run(screen: String = "") -> Dictionary:
	var where := screen if screen != "" else _screen_for_save()
	return {
		"screen": where,
		"trainer_id": trainer_id,
		"run_seed": run_seed,
		"rng_state": rng.state,
		"roster": roster.duplicate(true),
		"owned_species": owned_species.duplicate(true),
		"items": items.duplicate(),
		"current_floor": current_floor,
		"encounter": encounter.duplicate(true),
		"deployed": deployed.duplicate(true),
		"formation_presets": formation_presets.duplicate(true),
		"active_preset": active_preset,
		"next_uid": next_uid,
		"battle_counter": battle_counter,
		"pending_rewards": pending_rewards.duplicate(true),
		"run_active": run_active,
		"run_won": run_won,
		"run_stats": run_stats.duplicate(true),
		"run_bonuses": run_bonuses.duplicate(true),
		"pending_event": pending_event.duplicate(true),
		"event_done": event_done.duplicate(),
		"curse_floors": curse_floors.duplicate(true),
		"heroes_found": heroes_found,
		"affix_bag": affix_bag.duplicate(),
		"spirit_floor": spirit_floor,
		"run_mode": run_mode,
		"conquest_step": conquest_step,
		"blade_trial_floor": blade_trial_floor,
		"gold": gold,
		"route_done": route_done.duplicate(),
		"pending_route": pending_route.duplicate(true),
		"wonder_line": wonder_line,
		"event_battle": event_battle,
		"conquest_clear": conquest_clear,
	}


func restore_run(snap: Dictionary) -> void:
	trainer_id = str(snap.get("trainer_id", ""))
	trainer = ContentDB.trainers_by_id.get(trainer_id, {})
	run_seed = int(snap.get("run_seed", 0))
	rng.state = int(snap.get("rng_state", 0))
	roster = (snap.get("roster", []) as Array).duplicate(true)
	_ensure_chosen()
	owned_species = (snap.get("owned_species", {}) as Dictionary).duplicate(true)
	items = (snap.get("items", []) as Array).duplicate()
	current_floor = int(snap.get("current_floor", 1))
	encounter = (snap.get("encounter", {}) as Dictionary).duplicate(true)
	deployed = (snap.get("deployed", []) as Array).duplicate(true)
	formation_presets = (snap.get("formation_presets", [[], [], []]) as Array).duplicate(true)
	active_preset = int(snap.get("active_preset", 0))
	next_uid = int(snap.get("next_uid", 1))
	battle_counter = int(snap.get("battle_counter", 0))
	pending_rewards = (snap.get("pending_rewards", {}) as Dictionary).duplicate(true)
	run_active = true
	run_won = bool(snap.get("run_won", false))
	run_stats = (snap.get("run_stats", _empty_stats()) as Dictionary).duplicate(true)
	run_bonuses = (snap.get("run_bonuses", {}) as Dictionary).duplicate(true)
	pending_event = (snap.get("pending_event", {}) as Dictionary).duplicate(true)
	event_done = (snap.get("event_done", []) as Array).duplicate()
	curse_floors = (snap.get("curse_floors", {}) as Dictionary).duplicate(true)
	heroes_found = int(snap.get("heroes_found", 0))
	affix_bag = (snap.get("affix_bag", []) as Array).duplicate()
	spirit_floor = int(snap.get("spirit_floor", 0))
	run_mode = str(snap.get("run_mode", "tower"))
	conquest_step = int(snap.get("conquest_step", 0))
	blade_trial_floor = int(snap.get("blade_trial_floor", 0))
	gold = int(snap.get("gold", 0))
	route_done = (snap.get("route_done", []) as Array).duplicate()
	pending_route = (snap.get("pending_route", {}) as Dictionary).duplicate(true)
	wonder_line = bool(snap.get("wonder_line", false))
	event_battle = bool(snap.get("event_battle", false))
	conquest_clear = bool(snap.get("conquest_clear", false))
	save_screen = str(snap.get("screen", "map"))
	saved_floor_hint = current_floor
	saved_screen_hint = save_screen
	saved_mode_hint = run_mode
	_migrate_affixes()


func _migrate_affixes() -> void:
	for i in affix_bag.size():
		if str(affix_bag[i]) == "rage_fuel":
			affix_bag[i] = "spirit_cut"
	for entry in roster:
		var affixes: Dictionary = entry.get("affixes", {})
		for key in affixes.keys():
			var list: Array = affixes.get(key, [])
			for i in list.size():
				if str(list[i]) == "rage_fuel":
					list[i] = "spirit_cut"
			affixes[key] = list
		entry["affixes"] = affixes


func save_run(screen: String = "") -> void:
	if screen != "":
		save_screen = screen
	if not persist_enabled or not run_active:
		return
	var snap := capture_run(screen)
	var f := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(snap)
	saved_floor_hint = int(snap.get("current_floor", 1))
	saved_screen_hint = str(snap.get("screen", "map"))
	saved_mode_hint = str(snap.get("run_mode", "tower"))


func clear_saved_run() -> void:
	saved_floor_hint = 0
	saved_screen_hint = ""
	saved_mode_hint = "tower"
	if not persist_enabled:
		return
	if FileAccess.file_exists(RUN_PATH):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove("startower_run.dat")


func has_saved_run() -> bool:
	return saved_floor_hint > 0


func resume_run() -> String:
	if not FileAccess.file_exists(RUN_PATH):
		return ""
	var f := FileAccess.open(RUN_PATH, FileAccess.READ)
	if f == null:
		return ""
	var snap: Variant = f.get_var()
	if typeof(snap) != TYPE_DICTIONARY:
		return ""
	restore_run(snap)
	emit_signal("state_changed")
	return str(snap.get("screen", "map"))


func _peek_saved_run() -> void:
	saved_floor_hint = 0
	saved_screen_hint = ""
	saved_mode_hint = "tower"
	if not FileAccess.file_exists(RUN_PATH):
		return
	var f := FileAccess.open(RUN_PATH, FileAccess.READ)
	if f == null:
		return
	var snap: Variant = f.get_var()
	if typeof(snap) != TYPE_DICTIONARY:
		return
	saved_floor_hint = int(snap.get("current_floor", 0))
	saved_screen_hint = str(snap.get("screen", "map"))
	saved_mode_hint = str(snap.get("run_mode", "tower"))


func slot_path(index: int) -> String:
	return SLOT_PATH % index


func screen_label(screen: String) -> String:
	match screen:
		"reward":
			return "宝箱"
		"event":
			return "奇遇"
		"formation":
			return "布阵"
		"battle":
			return "本层开战前"
		_:
			return "地图"


func save_slot(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT or not persist_enabled or not run_active:
		return false
	var snap := capture_run()
	snap["saved_at"] = int(Time.get_unix_time_from_system())
	snap["manual"] = true
	var f := FileAccess.open(slot_path(index), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(snap)
	f.close()
	return true


func load_slot(index: int) -> String:
	if index < 0 or index >= SLOT_COUNT or not FileAccess.file_exists(slot_path(index)):
		return ""
	var f := FileAccess.open(slot_path(index), FileAccess.READ)
	if f == null:
		return ""
	var snap: Variant = f.get_var()
	if typeof(snap) != TYPE_DICTIONARY:
		return ""
	restore_run(snap)
	emit_signal("state_changed")
	return str(snap.get("screen", "map"))


func delete_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	if FileAccess.file_exists(slot_path(index)):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.remove(slot_path(index).trim_prefix("user://"))


func slot_summary(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT or not FileAccess.file_exists(slot_path(index)):
		return {}
	var f := FileAccess.open(slot_path(index), FileAccess.READ)
	if f == null:
		return {}
	var snap: Variant = f.get_var()
	if typeof(snap) != TYPE_DICTIONARY:
		return {}
	var trainer_name := str(ContentDB.trainers_by_id.get(str(snap.get("trainer_id", "")), {}).get("name", ""))
	return {
		"floor": int(snap.get("current_floor", 1)),
		"mode": str(snap.get("run_mode", "tower")),
		"trainer": trainer_name,
		"screen": str(snap.get("screen", "map")),
		"saved_at": int(snap.get("saved_at", 0)),
		"roster": (snap.get("roster", []) as Array).size(),
		"seed": int(snap.get("run_seed", 0)),
	}


func autosave_summary() -> Dictionary:
	if not FileAccess.file_exists(RUN_PATH):
		return {}
	var f := FileAccess.open(RUN_PATH, FileAccess.READ)
	if f == null:
		return {}
	var snap: Variant = f.get_var()
	if typeof(snap) != TYPE_DICTIONARY:
		return {}
	var trainer_name := str(ContentDB.trainers_by_id.get(str(snap.get("trainer_id", "")), {}).get("name", ""))
	return {
		"floor": int(snap.get("current_floor", 1)),
		"mode": str(snap.get("run_mode", "tower")),
		"trainer": trainer_name,
		"screen": str(snap.get("screen", "map")),
		"saved_at": 0,
		"roster": (snap.get("roster", []) as Array).size(),
		"seed": int(snap.get("run_seed", 0)),
	}
