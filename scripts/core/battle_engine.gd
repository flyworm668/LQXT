extends RefCounted
const SpiritPool = preload("res://scripts/core/spirit_pool.gd")
## Deterministic 5v5 auto-battle simulation.
## The engine mutates internal copies only and returns an event stream for the
## battle screen, so playback can be fast-forwarded or skipped at any time.

const STATUS_NAMES := {
	"burn": "灼烧", "stun": "眩晕", "slow": "减速", "haste": "急速",
	"atk_up": "攻击提升", "atk_down": "攻击降低", "def_up": "防御提升", "def_down": "破甲",
	"taunt": "嘲讽",
	"vulnerable": "易伤", "thorns": "反伤", "vamp": "吸血",
	"seal": "封印", "lock": "禁加速", "nocrit": "无法暴击", "cc_immune": "免控",
	"ult_seal": "大招封印", "rage_seal": "气势封印", "immune": "免伤", "mirror": "反射",
	"wither": "禁疗",
}

var rng := RandomNumberGenerator.new()
var units: Array = []
var by_uid: Dictionary = {}
var events: Array = []
var combat: Dictionary = {}
var rage_max: int = 4
var spirit: int = 0
var rounds: int = 0
var winner: String = ""
var manual: bool = false
var waiting: bool = false
var start_snapshot: Array = []
var _phase: String = "done"
var _order: Array = []
var _index: int = 0
var _actor: Dictionary = {}
var _max_rounds: int = 60
var _end_emitted := false
var _reported_dead: Dictionary = {}
var _hp_alarm := false
var _in_alarm := false


static func status_name(key: String) -> String:
	return str(STATUS_NAMES.get(key, key))


func simulate(player_units: Array, enemy_units: Array, seed_value: int) -> Dictionary:
	_boot(player_units, enemy_units, seed_value)
	manual = false
	pump()
	return _pack()


func begin(player_units: Array, enemy_units: Array, seed_value: int, manual_mode: bool) -> void:
	_boot(player_units, enemy_units, seed_value)
	manual = manual_mode
	pump()


func pump() -> void:
	var guard := 0
	while not waiting and _phase != "done" and guard < 20000:
		guard += 1
		_step()


func choose(slot: String, target_uid: int) -> void:
	if not waiting or _actor.is_empty():
		return
	waiting = false
	_phase = "turns"
	_actor["forced_slot"] = slot
	_actor["forced_uid"] = target_uid
	_auto_turn(_actor)
	if not waiting:
		pump()


func throw_ball(target_uid: int) -> bool:
	if not waiting or _actor.is_empty():
		return false
	var tgt: Dictionary = by_uid.get(target_uid, {})
	if tgt.is_empty() or int(tgt.get("hp", 0)) <= 0 or str(tgt.get("side", "")) == str(_actor.get("side", "")):
		return false
	waiting = false
	_phase = "turns"
	_resolve_ball(_actor, tgt)
	_escort_feed(_actor)
	if bool(_actor.get("extra_action", false)) and int(_actor.get("hp", 0)) > 0 and winner == "":
		_actor["extra_action"] = false
		if manual:
			_prompt(_actor)
			return true
		_take_turn(_actor)
		_actor["extra_action"] = false
		_escort_feed(_actor)
	if not waiting:
		pump()
	return true


func auto_choose() -> void:
	if not waiting or _actor.is_empty():
		return
	waiting = false
	_phase = "turns"
	_auto_turn(_actor)
	if not waiting:
		pump()


func resume_auto() -> void:
	manual = false
	if waiting and not _actor.is_empty():
		waiting = false
		_phase = "turns"
		_auto_turn(_actor)
	if not waiting:
		pump()


func legal_target_ids() -> Array:
	if _actor.is_empty():
		return []
	var ids: Array = []
	for foe in _taunt_filter(_opponents(str(_actor.get("side", "player")))):
		ids.append(int(foe.get("uid", -1)))
	return ids


func ball_target_ids() -> Array:
	var ids: Array = []
	for foe in _opponents("player"):
		if bool(foe.get("demon_king", false)):
			continue
		ids.append(int(foe.get("uid", -1)))
	return ids


func needs_target(slot: String) -> bool:
	if _actor.is_empty():
		return false
	if slot == "ball":
		return true
	if slot.begins_with("a") and bool(_actor.get("uses_spirit", false)):
		return _spirit_needs_target(_actor, slot)
	if slot != "ultimate":
		return not bool(_actor.get("aoe_next", false))
	var skill: Dictionary = (_actor.get("skills", {}) as Dictionary).get("ultimate", {})
	return str(skill.get("kind", "")) not in ["ult_mage", "ult_boss_aoe", "ult_support"]


func _boot(player_units: Array, enemy_units: Array, seed_value: int) -> void:
	combat = ContentDB.combat()
	rage_max = int(combat.get("rage_max", 4))
	rng.seed = seed_value
	units.clear()
	by_uid.clear()
	events.clear()
	winner = ""
	rounds = 0
	waiting = false
	spirit = 0
	_phase = "round"
	_order = []
	_index = 0
	_actor = {}
	_end_emitted = false
	_reported_dead.clear()
	_max_rounds = int(combat.get("max_rounds", 60))
	for u in player_units:
		_add_unit(u)
	for u in enemy_units:
		_add_unit(u)
	start_snapshot = []
	for u in units:
		start_snapshot.append(_snapshot(u))
	_battle_start()


func _pack() -> Dictionary:
	return {
		"events": events,
		"winner": winner,
		"rounds": rounds,
		"start": start_snapshot,
		"final": _final_snapshot(),
	}


func _step() -> void:
	if _phase == "round":
		if rounds >= _max_rounds:
			_finish(true)
			return
		rounds += 1
		events.append({"t": "round", "round": rounds})
		_round_start()
		if _check_end():
			_finish(false)
			return
		_order = _turn_order()
		_index = 0
		_phase = "turns"
		return
	if _phase == "turns":
		if _check_end():
			_finish(false)
			return
		if _index >= _order.size():
			_phase = "round_end"
			return
		var u: Dictionary = _order[_index]
		_index += 1
		if int(u.get("hp", 0)) <= 0:
			return
		if (_has_status(u, "stun") or _has_status(u, "seal")) and int(u.get("fury_left", 0)) <= 0:
			u["statuses"].erase("stun")
			u["statuses"].erase("seal")
			if bool(u.get("demon_king", false)):
				u["fury_pending"] = true
			events.append({"t": "stunned", "uid": int(u["uid"]),
				"text": "%s 被控制，无法行动！" % u["name"]})
			_push_auras(int(u["uid"]))
			return
		if bool(u.get("fury_pending", false)) and int(u.get("fury_left", 0)) <= 0:
			u["fury_pending"] = false
			u["fury_left"] = 3
			events.append({"t": "log", "text": "%s 陷入狂怒，接下来三回合不受控制，气势保持满格。" % u["name"]})
		if int(u.get("fury_left", 0)) > 0:
			u["statuses"].erase("stun")
			u["statuses"].erase("seal")
			u["statuses"].erase("slow")
			_push_auras(int(u["uid"]))
			u["rage"] = rage_max
			u["fury_acting"] = true
			_take_turn(u)
			if int(u.get("hp", 0)) > 0:
				u["rage"] = rage_max
			u["fury_acting"] = false
			u["fury_left"] = int(u.get("fury_left", 1)) - 1
			_escort_feed(u)
			return
		if manual and str(u.get("side", "")) == "player":
			_actor = u
			_prompt(u)
			return
		_auto_turn(u)
		return
	if _phase == "round_end":
		if winner != "":
			_finish(false)
			return
		if _check_end():
			_finish(false)
			return
		_round_end()
		_phase = "round"


func _auto_turn(u: Dictionary) -> void:
	_take_turn(u)
	_escort_feed(u)
	if bool(u.get("extra_action", false)) and int(u.get("hp", 0)) > 0 and winner == "":
		u["extra_action"] = false
		if manual and str(u.get("side", "")) == "player" and int(u.get("fury_left", 0)) <= 0:
			_actor = u
			_prompt(u)
			return
		_take_turn(u)
		u["extra_action"] = false
		_escort_feed(u)


func _prompt(u: Dictionary) -> void:
	waiting = true
	_phase = "wait"
	if bool(u.get("uses_spirit", false)):
		var listed: Array = []
		for i in (u.get("arts", []) as Array).size():
			var art: Dictionary = (u.get("arts", []) as Array)[i]
			var price := _spirit_price(u, art)
			listed.append({
				"slot": "a%d" % i, "name": str(art.get("name", "技能")),
				"cost": price, "ready": spirit >= price, "text": SpiritPool.art_text(art),
			})
		events.append({
			"t": "choose", "uid": int(u.get("uid", -1)), "name": str(u.get("name", "")),
			"can_ult": false, "spirit": spirit, "arts": listed,
		})
		return
	var can_ult := int(u.get("rage", 0)) >= rage_max and (u.get("skills", {}) as Dictionary).has("ultimate") and not _has_status(u, "ult_seal")
	events.append({
		"t": "choose", "uid": int(u.get("uid", -1)), "name": str(u.get("name", "")),
		"can_ult": can_ult,
	})


func _resolve_ball(actor: Dictionary, tgt: Dictionary) -> void:
	if bool(tgt.get("demon_king", false)):
		events.append({"t": "log", "text": "魔王不受灵契球影响。"})
		return
	var rate := _catch_rate(tgt)
	if rng.randf() < rate:
		tgt["hp"] = 0
		tgt["caught"] = true
		events.append({
			"t": "caught", "uid": int(tgt.get("uid", -1)),
			"species": str(tgt.get("species", "")), "level": int(tgt.get("level", 1)),
			"name": str(tgt.get("name", "")), "rate": rate,
		})
	else:
		events.append({"t": "log", "text": "灵契球晃了晃，%s 挣脱了。成功率 %.0f%%。" % [tgt.get("name", ""), rate * 100.0]})
	_flush_deaths()


func _catch_rate(tgt: Dictionary) -> float:
	var rarity := str(tgt.get("rarity", "common"))
	var rates := {"common": 0.55, "rare": 0.40, "epic": 0.28, "legend": 0.16, "hero": 0.10, "demon": 0.08}
	var base := float(rates.get(rarity, 0.20))
	var missing := 1.0 - float(tgt.get("hp", 1)) / maxf(1.0, float(tgt.get("max_hp", 1)))
	var rate := float(base) + missing * 0.35
	if rarity == "hero" or rarity == "demon":
		rate += GameState.catch_bonus()
	return minf(0.90, rate)


func _finish(timeout: bool) -> void:
	if _phase == "done":
		return
	_phase = "done"
	waiting = false
	if winner == "":
		winner = _judge_by_hp()
		if timeout:
			events.append({"t": "log", "text": "战斗超时，按剩余生命比例判定。"})
	_end_emitted = true
	_flush_deaths()
	events.append({"t": "end", "winner": winner, "rounds": rounds})


func _add_unit(source: Dictionary) -> void:
	var u: Dictionary = source.duplicate(true)
	if not u.has("hooks"):
		u["hooks"] = {}
	if not u.has("statuses"):
		u["statuses"] = {}
	units.append(u)
	by_uid[int(u["uid"])] = u


func _snapshot(u: Dictionary) -> Dictionary:
	return {
		"uid": int(u["uid"]), "side": u["side"], "species": u["species"], "name": u["name"],
		"element": u["element"], "class": u["class"], "level": int(u["level"]),
		"stage": int(u.get("stage", 0)), "max_hp": int(u["max_hp"]), "hp": int(u["hp"]),
		"atk": int(u["atk"]), "def": int(u["def"]), "spd": int(u["spd"]),
		"rage": int(u.get("rage", 0)), "shield": int(u.get("shield", 0)),
		"row": int(u["row"]), "col": int(u["col"]), "is_boss": bool(u.get("is_boss", false)),
		"is_hero": bool(u.get("is_hero", false)), "hero_star": int(u.get("hero_star", 0)),
		"king_barrier": bool(u.get("king_barrier", false)),
		"rarity": str(u.get("rarity", "")),
		"uses_spirit": bool(u.get("uses_spirit", false)),
		"buff_ids": (u.get("buff_ids", []) as Array).duplicate(),
		"skills": (u.get("skills", {}) as Dictionary).duplicate(true),
		"affixes": (u.get("affixes", {}) as Dictionary).duplicate(true),
		"statuses": (u.get("statuses", {}) as Dictionary).duplicate(true),
	}


func _final_snapshot() -> Array:
	var out: Array = []
	for u in units:
		out.append(_snapshot(u))
	return out


func _alive_units(side: String) -> Array:
	var out: Array = []
	for u in units:
		if u["hp"] > 0 and str(u["side"]) == side:
			out.append(u)
	return out


func _opponents(side: String) -> Array:
	return _alive_units("enemy" if side == "player" else "player")


func _team_dead(side: String) -> bool:
	return _alive_units(side).is_empty()


func _has_status(u: Dictionary, key: String) -> bool:
	return (u["statuses"] as Dictionary).has(key)


func _status_pct(u: Dictionary, key: String) -> float:
	var st: Dictionary = u["statuses"].get(key, {})
	return float(st.get("pct", 0.0))


func _status_value(u: Dictionary, key: String) -> float:
	var st: Dictionary = u["statuses"].get(key, {})
	return float(st.get("value", 0.0))


func _link_of(u: Dictionary) -> Dictionary:
	var raw: Variant = u.get("link", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _link_val(u: Dictionary, key: String) -> float:
	return float(_link_of(u).get(key, 0.0))


func _marks_of(u: Dictionary) -> Dictionary:
	var raw: Variant = u.get("marks", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _mark_sum(u: Dictionary, fx: String) -> float:
	return _mark_sum_elem(u, fx, "")


func _mark_sum_elem(u: Dictionary, fx: String, element: String) -> float:
	var total := 0.0
	var bag := _marks_of(u)
	for key in bag.keys():
		var row: Dictionary = bag[key]
		var elem := str(row.get("elem", ""))
		if element != "" and elem != "" and elem != element:
			continue
		var n := float(row.get("n", 0))
		if str(row.get("fx", "")) == fx:
			total += float(row.get("per", 0.0)) * n
		if str(row.get("fx2", "")) == fx:
			total += float(row.get("per2", 0.0)) * n
	return total


func _atk_eff(u: Dictionary) -> float:
	var atk := float(u["atk"]) * maxf(0.05, 1.0 + _status_pct(u, "atk_up") - _status_pct(u, "atk_down"))
	atk *= maxf(0.2, 1.0 + _mark_sum(u, "self_atk") - _mark_sum(u, "atk_down"))
	atk *= maxf(0.2, 1.0 + _link_val(u, "atk"))
	var might := int(u.get("might", 0))
	if might > 0:
		atk *= 1.0 + float(combat.get("king_might_pct", 0.08)) * float(might)
	return atk


func _def_eff(u: Dictionary) -> float:
	var defense := float(u["def"]) * maxf(0.0, 1.0 + _status_pct(u, "def_up") - _status_pct(u, "def_down"))
	defense *= maxf(0.15, 1.0 + _mark_sum(u, "self_def") - _mark_sum(u, "def_down"))
	defense *= maxf(0.15, 1.0 + _link_val(u, "def"))
	var might := int(u.get("might", 0))
	if might > 0:
		defense *= 1.0 + float(combat.get("king_might_pct", 0.08)) * float(might)
	return defense


func _spd_eff(u: Dictionary) -> float:
	var haste := _status_pct(u, "haste")
	if _has_status(u, "lock"):
		haste = 0.0
	return float(u["spd"]) * maxf(0.1, 1.0 + haste - _status_pct(u, "slow") + _mark_sum(u, "self_spd") - _mark_sum(u, "slow") + _link_val(u, "spd"))


func _hp_ratio(u: Dictionary) -> float:
	return float(u["hp"]) / maxf(1.0, float(u["max_hp"]))


# ---------------------------------------------------------------- setup

func _battle_start() -> void:
	for u in units:
		var hooks: Dictionary = u.get("hooks", {})
		var start_rage := int(hooks.get("start_rage", 0))
		if start_rage > 0 and not bool(u.get("uses_spirit", false)):
			u["rage"] = mini(rage_max, int(u.get("rage", 0)) + start_rage)
		if bool(u.get("uses_spirit", false)):
			spirit += int(hooks.get("start_spirit", 0))
		var start_shield := float(hooks.get("start_shield", 0.0))
		if start_shield > 0.0:
			u["shield"] = int(float(u["max_hp"]) * start_shield)
	spirit = mini(SpiritPool.MAX_SPIRIT, spirit)
	# boss "oppress" aura
	for u in units:
		var hooks: Dictionary = u.get("hooks", {})
		var pct := float(hooks.get("oppress", 0.0))
		if pct <= 0.0:
			continue
		for foe in _opponents(str(u["side"])):
			_apply_status(foe, "atk_down", 99, pct)
			events.append({"t": "status", "uid": int(foe["uid"]), "status": "atk_down",
				"dur": 99, "pct": pct, "text": "%s 受到威压，攻击降低！" % foe["name"]})
	_apply_links()
	_apply_cells()


func _round_start() -> void:
	var tick_entries: Array = []
	var heal_entries: Array = []
	var deaths: Array = []
	for u in units:
		if u["hp"] <= 0:
			continue
		# regeneration from items / boss buffs
		var regen := float((u.get("hooks", {}) as Dictionary).get("regen", 0.0))
		if regen > 0.0:
			var h := _heal(u, int(float(u["max_hp"]) * regen))
			if int(h["amount"]) > 0:
				heal_entries.append(h)
		# burn damage
		if _has_status(u, "burn"):
			var dmg := maxi(1, int(_status_value(u, "burn")))
			var entry := _deal_damage({}, u, dmg, false, 1.0, false)
			tick_entries.append(entry)
			if entry["dead"]:
				deaths.append({"t": "death", "uid": int(u["uid"]), "side": u["side"],
					"text": "%s 被灼烧击倒。" % u["name"]})
		var poison := _poison_damage(u)
		if poison > 0 and int(u["hp"]) > 0:
			var pentry := _deal_damage({}, u, poison, false, 1.0, false)
			tick_entries.append(pentry)
		if int(u["hp"]) > 0:
			_tick_adjacent(u, tick_entries)
	if not tick_entries.is_empty() or not heal_entries.is_empty():
		events.append({"t": "tick", "targets": tick_entries, "heals": heal_entries,
			"text": "回合开始结算。"})
	_flush_deaths()
	_spirit_round()


func _turn_order() -> Array:
	var alive: Array = []
	for u in units:
		if u["hp"] > 0:
			alive.append(u)
	var scores := {}
	for u in alive:
		scores[int(u["uid"])] = _spd_eff(u) * rng.randf_range(0.94, 1.06)
	alive.sort_custom(func(a, b):
		var sa := float(scores[int(a["uid"])])
		var sb := float(scores[int(b["uid"])])
		if is_equal_approx(sa, sb):
			return int(a["uid"]) < int(b["uid"])
		return sa > sb)
	return alive


func _round_end() -> void:
	for u in units:
		if u["hp"] <= 0:
			continue
		var keys: Array = (u["statuses"] as Dictionary).keys()
		for key in keys:
			if key == "stun":
				continue
			var st: Dictionary = u["statuses"][key]
			if int(st.get("applied_round", 0)) == rounds:
				continue
			st["dur"] = int(st.get("dur", 1)) - 1
			if int(st["dur"]) <= 0:
				u["statuses"].erase(key)
			else:
				u["statuses"][key] = st
	_push_auras(-1)


func _push_auras(only_uid: int) -> void:
	var list: Array = []
	for u in units:
		if int(u.get("hp", 0)) <= 0:
			continue
		if only_uid >= 0 and int(u["uid"]) != only_uid:
			continue
		var marks: Array = []
		for mid in _marks_of(u).keys():
			var row: Dictionary = _marks_of(u)[mid]
			if int(row.get("n", 0)) <= 0:
				continue
			marks.append({"name": str(row.get("name", mid)), "n": int(row.get("n", 0))})
		list.append({
			"uid": int(u["uid"]),
			"statuses": (u.get("statuses", {}) as Dictionary).duplicate(true),
			"marks": marks,
		})
	if not list.is_empty():
		events.append({"t": "auras", "units": list})


func _check_end() -> bool:
	if winner != "":
		return true
	if _team_dead("player"):
		winner = "enemy"
		return true
	if _team_dead("enemy"):
		winner = "player"
		return true
	return false


func _judge_by_hp() -> String:
	var player_hp := 0.0
	var player_max := 1.0
	var enemy_hp := 0.0
	var enemy_max := 1.0
	for u in units:
		if str(u["side"]) == "player":
			player_hp += float(maxi(0, int(u["hp"])))
			player_max += float(u["max_hp"])
		else:
			enemy_hp += float(maxi(0, int(u["hp"])))
			enemy_max += float(u["max_hp"])
	return "player" if player_hp / player_max >= enemy_hp / enemy_max else "enemy"


# ---------------------------------------------------------------- turn

func _take_turn(u: Dictionary) -> void:
	_king_revive(u)
	if bool(u.get("uses_spirit", false)) and str(u.get("side", "")) == "player":
		_take_spirit_turn(u)
		return
	var forced := str(u.get("forced_slot", ""))
	u.erase("forced_slot")
	var use_ult := int(u.get("rage", 0)) >= rage_max and (u["skills"] as Dictionary).has("ultimate")
	if forced == "normal":
		use_ult = false
	elif forced == "ultimate":
		use_ult = (u["skills"] as Dictionary).has("ultimate") and not _has_status(u, "ult_seal") and int(u.get("rage", 0)) >= rage_max
	if use_ult and _has_status(u, "ult_seal"):
		use_ult = false
		events.append({"t": "log", "text": "%s 被封印，无法释放大招。" % u["name"]})
	if use_ult:
		u["rage"] = 0
		_use_ultimate(u)
		if bool(u.get("fury_acting", false)):
			u["rage"] = rage_max
		elif bool(u.get("demon_king", false)) and int(u.get("rage_sustain", 0)) > 0:
			u["rage"] = rage_max
			u["rage_sustain"] = int(u.get("rage_sustain", 0)) - 1
			events.append({"t": "log", "text": "%s 的气势被魔阵维持在满格。" % u["name"]})
	else:
		_use_normal(u)
		u["rage"] = mini(rage_max, int(u.get("rage", 0)) + 1)
	_clamp_locked_rage(u)
	events.append({"t": "rage", "uid": int(u["uid"]), "rage": int(u.get("rage", 0))})


func _slot_has_affix(u: Dictionary, slot: String, affix_id: String) -> bool:
	return _slot_affix_count(u, slot, affix_id) > 0


func _slot_affix_count(u: Dictionary, slot: String, affix_id: String) -> int:
	var list: Array = (u.get("affixes", {}) as Dictionary).get(slot, [])
	var n := 0
	for aid in list:
		if str(aid) == affix_id:
			n += 1
	return n


func _taunt_filter(foes: Array) -> Array:
	var forced: Array = []
	for f in foes:
		if int(f.get("hp", 0)) > 0 and _has_status(f, "taunt"):
			forced.append(f)
	if not forced.is_empty():
		return forced
	var guards: Array = []
	for f in foes:
		if str(f.get("class", "")) == "guardian" and int(f.get("hp", 0)) > 0:
			guards.append(f)
	if guards.is_empty():
		return foes
	return guards


func _front_target(u: Dictionary) -> Dictionary:
	var foes := _taunt_filter(_opponents(str(u["side"])))
	if foes.is_empty():
		return {}
	foes.sort_custom(func(a, b):
		var ca := int(a["col"])
		var cb := int(b["col"])
		if ca != cb:
			return ca < cb
		var da := absi(int(a["row"]) - int(u["row"]))
		var db := absi(int(b["row"]) - int(u["row"]))
		if da != db:
			return da < db
		return _hp_ratio(a) < _hp_ratio(b))
	return foes[0]


func _back_target(u: Dictionary) -> Dictionary:
	var foes := _taunt_filter(_opponents(str(u["side"])))
	if foes.is_empty():
		return {}
	foes.sort_custom(func(a, b):
		var ca := int(a["col"])
		var cb := int(b["col"])
		if ca != cb:
			return ca > cb
		return _hp_ratio(a) < _hp_ratio(b))
	return foes[0]


func _lowest_target(u: Dictionary) -> Dictionary:
	var foes := _taunt_filter(_opponents(str(u["side"])))
	if foes.is_empty():
		return {}
	var best: Dictionary = foes[0]
	for f in foes:
		if _hp_ratio(f) < _hp_ratio(best):
			best = f
	return best


func _aoe_targets(u: Dictionary, count: int) -> Array:
	var foes := _opponents(str(u["side"]))
	foes.sort_custom(func(a, b):
		var ca := int(a["col"])
		var cb := int(b["col"])
		if ca != cb:
			return ca > cb
		return _hp_ratio(a) < _hp_ratio(b))
	return foes.slice(0, mini(count, foes.size()))


func _lowest_ally(u: Dictionary) -> Dictionary:
	var allies := _alive_units(str(u["side"]))
	if allies.is_empty():
		return {}
	var best: Dictionary = allies[0]
	for a in allies:
		if _hp_ratio(a) < _hp_ratio(best):
			best = a
	return best


func _consume_pick(u: Dictionary) -> Dictionary:
	var uid := int(u.get("forced_uid", -1))
	u.erase("forced_uid")
	if uid < 0:
		return {}
	var legal := _taunt_filter(_opponents(str(u.get("side", "player"))))
	for foe in legal:
		if int(foe.get("uid", -2)) == uid and int(foe.get("hp", 0)) > 0:
			return foe
	if legal.is_empty():
		return {}
	return legal[0]


func _lowest_foe(u: Dictionary) -> Dictionary:
	var foes := _taunt_filter(_opponents(str(u.get("side", "player"))))
	if foes.is_empty():
		return {}
	var best: Dictionary = foes[0]
	for foe in foes:
		if _hp_ratio(foe) < _hp_ratio(best):
			best = foe
	return best


func _normal_target(u: Dictionary) -> Dictionary:
	var skill: Dictionary = (u["skills"] as Dictionary).get("normal", {})
	match str(skill.get("target", "front")):
		"back":
			return _back_target(u)
		"lowest":
			return _lowest_target(u)
		_:
			return _front_target(u)


# ---------------------------------------------------------------- skills

func _use_normal(u: Dictionary) -> void:
	var skill: Dictionary = (u["skills"] as Dictionary).get("normal", {})
	var action := _new_action(u, "normal", str(skill.get("name", "普通攻击")))
	var picked := _consume_pick(u)
	var targets: Array = []
	if bool(u.get("aoe_next", false)):
		u["aoe_next"] = false
		targets = _opponents(str(u["side"]))
	else:
		var one := picked if not picked.is_empty() else _normal_target(u)
		if not one.is_empty():
			targets.append(one)
	if targets.is_empty():
		return
	var deaths: Array = []
	var total := 0
	var first_name := ""
	for target in targets:
		if int(target.get("hp", 0)) <= 0:
			continue
		var dmg_info := _calc_damage(u, target, float(skill.get("mult", 1.0)), "normal")
		var entry := _deal_damage(u, target, int(dmg_info["amount"]), bool(dmg_info["crit"]), float(dmg_info["element"]), true)
		action["targets"].append(entry)
		total += int(entry["damage"])
		if first_name == "":
			first_name = str(target.get("name", ""))
		if entry["dead"]:
			deaths.append(entry["uid"])
		_stamp_mark(u, target, action)
		_apply_on_hit_affixes(u, target, "normal", int(entry["damage"]), action, targets.size() == 1, deaths)
		if targets.size() == 1:
			_apply_item_on_hit(u, target, "normal", action, true)
		if (bool(u.get("is_boss", false)) or bool(u.get("is_hero", false))) and int(target.get("hp", 0)) > 0:
			_apply_boss_normal_element(u, target, action)
	if str(u["class"]) == "support":
		var ally := _lowest_ally(u)
		if not ally.is_empty():
			var h := _powered_heal(u, ally, int(float(ally["max_hp"]) * 0.05))
			if int(h["amount"]) > 0:
				action["heals"].append(h)
	elif str(u["class"]) == "guardian":
		action["shields"].append(_powered_shield(u, u, int(float(u["max_hp"]) * 0.03)))
	if rng.randf() < clampf(_mark_sum(u, "rage_chance"), 0.0, 0.85):
		u["rage"] = mini(rage_max, int(u.get("rage", 0)) + 1)
	if targets.size() > 1:
		action["text"] = "%s 使用【%s】横扫，共造成 %d 伤害。" % [u["name"], action["skill_name"], total]
	else:
		action["text"] = "%s 使用【%s】攻击 %s，造成 %d 伤害。" % [u["name"], action["skill_name"], first_name, total]
	_emit_action(action, deaths, [])
	for target in targets:
		_check_phase_after(target)


func _use_ultimate(u: Dictionary) -> void:
	var skill: Dictionary = (u["skills"] as Dictionary).get("ultimate", {})
	if skill.is_empty():
		_use_normal(u)
		return
	var action := _new_action(u, "ultimate", str(skill.get("name", "大招")))
	var picked := _consume_pick(u)
	var kind := str(skill.get("kind", "ult_warrior"))
	var deaths: Array = []
	var primary_damage := 0
	match kind:
		"ult_guardian":
			var t := picked if not picked.is_empty() else _front_target(u)
			if not t.is_empty():
				var info := _calc_damage(u, t, float(skill.get("mult", 1.8)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
				_apply_on_hit_affixes(u, t, "ultimate", primary_damage, action, true, deaths)
				_apply_item_on_hit(u, t, "ultimate", action, true)
			action["shields"].append(_powered_shield(u, u, int(float(u["max_hp"]) * 0.12)))
		"ult_warrior":
			var t := picked if not picked.is_empty() else _front_target(u)
			if not t.is_empty():
				var info := _calc_damage(u, t, float(skill.get("mult", 2.6)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
				_apply_on_hit_affixes(u, t, "ultimate", primary_damage, action, true, deaths)
				_apply_item_on_hit(u, t, "ultimate", action, true)
				var others := _other_targets(u, t)
				if not others.is_empty():
					var splash_amount := int(float(primary_damage) * float(skill.get("splash", 0.3)))
					var se := _deal_damage(u, others[0], maxi(1, splash_amount), false, float(info["element"]), false)
					se["splash"] = true
					action["targets"].append(se)
					if se["dead"]:
						deaths.append(se["uid"])
		"ult_mage":
			var targets := _aoe_targets(u, 3)
			for t in targets:
				var info := _calc_damage(u, t, float(skill.get("mult", 1.35)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				if primary_damage == 0:
					primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
				_apply_on_hit_affixes(u, t, "ultimate", int(e["damage"]), action, false, deaths)
			if not targets.is_empty():
				_apply_item_on_hit(u, targets[0], "ultimate", action, false)
		"ult_archer":
			var t := picked if not picked.is_empty() else _lowest_target(u)
			if not t.is_empty():
				var info := _calc_damage(u, t, float(skill.get("mult", 2.0)), "ultimate", 0.25)
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
				_apply_on_hit_affixes(u, t, "ultimate", primary_damage, action, true, deaths)
				_apply_item_on_hit(u, t, "ultimate", action, true)
		"ult_support":
			for ally in _alive_units(str(u["side"])):
				var h := _powered_heal(u, ally, int(float(ally["max_hp"]) * 0.15))
				action["heals"].append(h)
				_apply_status(ally, "atk_up", 2, 0.10)
				action["statuses"].append({"uid": int(ally["uid"]), "status": "atk_up",
					"dur": 2, "pct": 0.10})
		"ult_boss_aoe":
			var targets := _aoe_targets(u, 3)
			for t in targets:
				var info := _calc_damage(u, t, float(skill.get("mult", 1.5)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				if primary_damage == 0:
					primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
		_:
			var t := picked if not picked.is_empty() else _front_target(u)
			if not t.is_empty():
				var info := _calc_damage(u, t, float(skill.get("mult", 1.5)), "ultimate")
				var e := _deal_damage(u, t, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
				action["targets"].append(e)
				primary_damage = int(e["damage"])
				if e["dead"]:
					deaths.append(e["uid"])
	if kind != "ult_support":
		_apply_ultimate_element(u, action["targets"], action, kind)
	else:
		_apply_support_element(u, action)
	_apply_signature(u, action, deaths)
	action["text"] = "%s 释放【%s】！" % [u["name"], action["skill_name"]]
	if not action["targets"].is_empty():
		var total := 0
		for t in action["targets"]:
			total += int(t.get("damage", 0))
		action["text"] += " 共造成 %d 伤害。" % total
	if not action["heals"].is_empty():
		var healed := 0
		for h in action["heals"]:
			healed += int(h.get("amount", 0))
		action["text"] += " 治疗 %d 生命。" % healed
	if bool(u.get("demon_king", false)) and not bool(u.get("alarm_strike", false)):
		if rounds < int(u.get("seal_ready", 0)):
			action["text"] += " 封印还在冷却。"
		else:
			var sealed := 0
			var tried := 0
			for foe in units:
				if str(foe.get("side", "")) != "player" or int(foe.get("hp", 0)) <= 0:
					continue
				tried += 1
				if rng.randf() < 0.50:
					_apply_status(foe, "ult_seal", 1)
					sealed += 1
			u["seal_ready"] = rounds + 2
			if tried > 0:
				action["text"] += " 魔王尝试封印，%d/%d 只精灵 1 回合无法释放大招。" % [sealed, tried]
	_emit_action(action, deaths, [])
	for t in action["targets"]:
		var tu = by_uid.get(int(t["uid"]))
		if tu != null:
			_check_phase_after(tu)


func _new_action(u: Dictionary, slot: String, skill_name: String) -> Dictionary:
	return {
		"t": "action", "actor": int(u["uid"]), "side": u["side"], "slot": slot,
		"skill_name": skill_name, "targets": [], "heals": [], "shields": [],
		"statuses": [], "text": "",
	}


func _emit_action(action: Dictionary, deaths: Array, phases: Array) -> void:
	events.append(action)
	_flush_deaths()
	for p in phases:
		events.append(p)
	_flush_hp_alarm()


func _flush_hp_alarm() -> void:
	if _in_alarm or not _hp_alarm:
		return
	_hp_alarm = false
	_in_alarm = true
	events.append({"t": "log", "text": "生命上限警报！魔王立即行动。"})
	for u in units:
		if not bool(u.get("demon_king", false)) or int(u.get("hp", 0)) <= 0:
			continue
		if str(u.get("side", "")) != "enemy":
			continue
		u["alarm_strike"] = true
		_take_turn(u)
		u["alarm_strike"] = false
	_hp_alarm = false
	_in_alarm = false


func _flush_deaths() -> void:
	for u in units:
		if int(u["hp"]) > 0:
			continue
		var uid := int(u["uid"])
		if _reported_dead.has(uid):
			continue
		_reported_dead[uid] = true
		var gone := "%s 被收服了。" if bool(u.get("caught", false)) else "%s 倒下了。"
		events.append({"t": "death", "uid": uid, "side": u.get("side", ""),
			"text": gone % u.get("name", "")})


func _other_targets(u: Dictionary, except: Dictionary) -> Array:
	var out: Array = []
	for f in _opponents(str(u["side"])):
		if int(f["uid"]) != int(except["uid"]):
			out.append(f)
	out.sort_custom(func(a, b): return int(a["col"]) < int(b["col"]))
	return out


func _apply_ultimate_element(u: Dictionary, targets: Array, action: Dictionary, _kind: String) -> void:
	_apply_rider(u, _rider_units(targets), action, _rider_for(u, "ultimate"))


func _apply_boss_normal_element(u: Dictionary, target: Dictionary, action: Dictionary) -> void:
	_apply_rider(u, [target], action, _rider_for(u, "normal"))


func _apply_support_element(u: Dictionary, action: Dictionary) -> void:
	var rider := _rider_for(u, "ultimate")
	if rider in ["haste", "shield", "regen", "atk_self"]:
		_apply_rider(u, [u], action, rider)
		return
	var t := _front_target(u)
	if t.is_empty():
		return
	_apply_rider(u, [t], action, rider)


# ---------------------------------------------------------------- damage

func _calc_damage(src: Dictionary, tgt: Dictionary, mult: float, slot: String,
		extra_crit: float = 0.0, extra_pierce: float = 0.0) -> Dictionary:
	var miracles := _slot_affix_count(src, slot, "miracle")
	for _i in range(miracles):
		var chance := float(ContentDB.affix("miracle").get("value", 0.02))
		if str(src.get("side", "")) == "player":
			chance = minf(0.30, chance + GameState.miracle_bonus())
		if rng.randf() < chance:
			return {"amount": 99999, "crit": true, "element": 1.0, "row": 1.0, "miracle": true}
	var atk := _atk_eff(src)
	var hooks: Dictionary = src.get("hooks", {})
	var defense := _def_eff(tgt)
	# boss buff: pierce ignores part of the target's defense
	var pierce := clampf(float(hooks.get("pierce", 0.0)) + _mark_sum(src, "ignore_def") + extra_pierce, 0.0, 0.9)
	defense *= 1.0 - pierce
	var def_coeff := float(combat.get("def_coefficient", 0.4))
	var damage := atk * mult * 100.0 / (100.0 + defense * def_coeff)
	damage *= maxf(1.0, float(src.get("skill_power", 1.0)))
	# Formation position affects targeting only; it no longer changes damage.
	var row_mult := 1.0
	var elem_mult := ContentDB.element_multiplier(str(src["element"]), str(tgt["element"]))
	if elem_mult <= 0.0:
		return {"amount": 0, "crit": false, "element": 0.0, "row": row_mult}
	damage *= elem_mult
	damage *= float(combat.get("stab", 1.0))
	var atk_elem := str(src.get("element", ""))
	damage *= 1.0 + _mark_sum_elem(tgt, "elem_taken", atk_elem)
	damage *= 1.0 + _mark_sum(tgt, "vuln")
	damage *= maxf(0.25, 1.0 - _mark_sum(src, "dealt_down"))
	damage *= 1.0 + _mark_sum_elem(src, "self_elem", atk_elem)
	if slot == "ultimate" or slot == "ult":
		damage *= 1.0 + _mark_sum(src, "self_skill") + _mark_sum(src, "self_ult") + _link_val(src, "skill")
	if _has_status(tgt, "stun") or _has_status(tgt, "seal"):
		damage *= 1.0 + _mark_sum(tgt, "frozen_taken")
	damage += float(tgt.get("max_hp", 0)) * _mark_sum(tgt, "true_hp")
	# affix: sharp / execute
	var sharp_n := _slot_affix_count(src, slot, "sharp")
	if sharp_n > 0:
		damage *= pow(1.15, sharp_n)
	var execute_n := _slot_affix_count(src, slot, "execute")
	if execute_n > 0 and _hp_ratio(tgt) < 0.35:
		damage *= pow(1.35, execute_n)
	# status: vulnerable
	if _has_status(tgt, "vulnerable"):
		damage *= 1.0 + _status_pct(tgt, "vulnerable")
	# item hooks
	if float(hooks.get("execute", 0.0)) > 0.0 and _hp_ratio(tgt) < 0.40:
		damage *= 1.0 + float(hooks["execute"])
	if (bool(tgt.get("is_boss", false)) or bool(tgt.get("is_hero", false))) and float(hooks.get("vs_boss", 0.0)) > 0.0:
		damage *= 1.0 + float(hooks["vs_boss"])
	if bool(tgt.get("demon_king", false)) and float(hooks.get("vs_king", 0.0)) > 0.0:
		damage *= 1.0 + float(hooks["vs_king"])
	if (slot == "ultimate" or slot == "ult") and float(hooks.get("ult_damage", 0.0)) > 0.0:
		damage *= 1.0 + float(hooks["ult_damage"])
	# boss buff: enrage scales with missing health
	var enrage := float(hooks.get("enrage", 0.0))
	if enrage > 0.0:
		damage *= 1.0 + enrage * (1.0 - _hp_ratio(src))
	# crit
	var crit_chance := clampf(float(src.get("crit", 0.05)) + extra_crit + _mark_sum(src, "self_crit") + _link_val(src, "crit"), 0.0, 1.0)
	if _has_status(src, "nocrit"):
		crit_chance = 0.0
	var crit_n := _slot_affix_count(src, slot, "crit")
	if crit_n > 0:
		crit_chance = clampf(crit_chance + 0.20 * float(crit_n), 0.0, 1.0)
	var blade_n := _slot_affix_count(src, slot, "barrier_blade")
	if float((src.get("hooks", {}) as Dictionary).get("barrier_blade", 0.0)) > 0.0:
		blade_n = maxi(blade_n, 1)
	if blade_n > 0:
		crit_chance = clampf(crit_chance + 0.20 * float(blade_n), 0.0, 1.0)
		var foe := str(tgt.get("rarity", ""))
		if bool(tgt.get("demon_king", false)) or foe == "demon":
			damage *= 2.0
	var crit := rng.randf() < crit_chance
	if crit:
		var crit_mult := float(combat.get("crit_mult", 1.6)) + 0.80 * float(blade_n) + float(hooks.get("crit_bonus", 0.0))
		damage *= crit_mult * (1.0 + _mark_sum(tgt, "crit_taken"))
	damage *= rng.randf_range(0.94, 1.06)
	return {"amount": maxi(1, int(round(damage))), "crit": crit, "element": elem_mult, "row": row_mult}


func _can_break_barrier(src: Dictionary) -> bool:
	if src.is_empty():
		return false
	if bool(src.get("is_hero", false)):
		return true
	if str(src.get("rarity", "")) == "demon":
		return true
	for slot in ["normal", "ultimate", "basic", "aid", "ult"]:
		if _slot_has_affix(src, slot, "barrier_blade"):
			return true
	if float((src.get("hooks", {}) as Dictionary).get("barrier_blade", 0.0)) > 0.0:
		return true
	return false


func _unit_has_blade(u: Dictionary) -> bool:
	if u.is_empty():
		return false
	if float((u.get("hooks", {}) as Dictionary).get("barrier_blade", 0.0)) > 0.0:
		return true
	for slot in ["normal", "ultimate", "basic", "aid", "ult"]:
		if _slot_has_affix(u, slot, "barrier_blade"):
			return true
	return false


func _king_battle() -> bool:
	for u in units:
		if bool(u.get("demon_king", false)):
			return true
	return false


func _blade_tier(u: Dictionary) -> int:
	if not _unit_has_blade(u) or not _king_battle():
		return 0
	var dead := 0
	for ally in units:
		if str(ally.get("side", "")) != str(u.get("side", "")):
			continue
		if int(ally.get("uid", -1)) == int(u.get("uid", -2)):
			continue
		if int(ally.get("hp", 0)) <= 0:
			dead += 1
	return mini(4, dead)


func _apply_blade_grief(src: Dictionary, tgt: Dictionary) -> void:
	var tier := _blade_tier(src)
	if tier <= 0:
		return
	if not tgt.has("base_max_hp"):
		tgt["base_max_hp"] = int(tgt.get("max_hp", 1))
	var shred := 0.0
	var execute_line := 0.0
	if tier >= 4:
		shred = 0.20
		execute_line = 0.30
	elif tier >= 3:
		shred = 0.15
		execute_line = 0.20
	elif tier >= 2:
		shred = 0.10
	if shred > 0.0:
		var before_cap := int(tgt["max_hp"])
		tgt["max_hp"] = maxi(1, int(round(float(tgt["max_hp"]) * (1.0 - shred))))
		tgt["hp"] = mini(int(tgt["hp"]), int(tgt["max_hp"]))
		if int(tgt["max_hp"]) < before_cap:
			_hp_alarm = true
	tgt["hp"] = maxi(0, int(tgt["hp"]) - 9999)
	if execute_line > 0.0 and int(tgt["max_hp"]) <= int(round(float(tgt["base_max_hp"]) * execute_line)):
		tgt["hp"] = 0


func _cheat_death(u: Dictionary) -> bool:
	if int(u.get("hp", 0)) > 0:
		return false
	if int(u.get("blade_lives", 0)) > 0:
		u["hp"] = 1
		u["blade_lives"] = int(u["blade_lives"]) - 1
		var guard := "圣剑" if _unit_has_blade(u) else "碎片"
		events.append({"t": "log", "text": "%s 被%s护住，还剩 %d 次免死。" % [u.get("name", ""), guard, int(u["blade_lives"])]})
		return true
	var hooks: Dictionary = u.get("hooks", {})
	if float(hooks.get("last_stand", 0.0)) > 0.0 and not bool(u.get("last_stand_used", false)):
		u["hp"] = 1
		u["last_stand_used"] = true
		return true
	return false


func _king_revive(u: Dictionary) -> void:
	if not bool(u.get("demon_king", false)) or int(u.get("hp", 0)) <= 0:
		return
	if int(u.get("revive_wait", 0)) > 0:
		u["revive_wait"] = int(u["revive_wait"]) - 1
		return
	var dead: Array = []
	for ally in units:
		if str(ally.get("side", "")) != str(u.get("side", "")):
			continue
		if int(ally.get("hp", 0)) > 0 or bool(ally.get("demon_king", false)):
			continue
		if bool(ally.get("caught", false)):
			continue
		if str(ally.get("rarity", "")) != "demon":
			continue
		dead.append(ally)
	if dead.is_empty():
		return
	var ally: Dictionary = dead[rng.randi_range(0, dead.size() - 1)]
	ally["atk"] = maxi(1, int(round(float(ally.get("atk", 1)) * 1.25)))
	ally["def"] = maxi(0, int(round(float(ally.get("def", 0)) * 1.25)))
	ally["max_hp"] = maxi(1, int(round(float(ally.get("max_hp", 1)) * 1.15)))
	ally["hp"] = maxi(1, int(round(float(ally["max_hp"]) * 0.50)))
	u["revive_wait"] = 3
	_reported_dead.erase(int(ally.get("uid", -1)))
	events.append({
		"t": "revive", "uid": int(ally.get("uid", -1)),
		"hp": int(ally["hp"]), "max_hp": int(ally["max_hp"]),
		"text": "%s 复活并强化了 %s。" % [u.get("name", ""), ally.get("name", "")],
	})


func _deal_damage(src: Dictionary, tgt: Dictionary, amount: int, crit: bool,
		element_mult: float, allow_reflect: bool = true, redirected: bool = false) -> Dictionary:
	tgt.erase("_ward_swing")
	if bool(tgt.get("king_barrier", false)) and amount > 0:
		var swing := "hold"
		if _can_break_barrier(src):
			tgt["king_barrier"] = false
			swing = "break"
		tgt["_ward_swing"] = swing
		return {
			"uid": int(tgt["uid"]), "damage": 0, "absorbed": 0, "crit": false,
			"element": element_mult, "hp": int(tgt["hp"]), "max_hp": int(tgt["max_hp"]),
			"shield": int(tgt.get("shield", 0)), "dead": false, "saved": false,
			"rage": int(tgt.get("rage", 0)), "barrier": swing,
		}
	if _has_status(tgt, "immune") and amount > 0:
		return {
			"uid": int(tgt["uid"]), "damage": 0, "absorbed": 0, "crit": false,
			"element": element_mult, "hp": int(tgt["hp"]), "max_hp": int(tgt["max_hp"]),
			"shield": int(tgt.get("shield", 0)), "dead": false, "saved": false,
			"rage": int(tgt.get("rage", 0)),
		}
	if amount <= 0 and element_mult <= 0.0:
		return {
			"uid": int(tgt["uid"]), "damage": 0, "absorbed": 0, "crit": false,
			"element": 0.0, "hp": int(tgt["hp"]), "max_hp": int(tgt["max_hp"]),
			"shield": int(tgt.get("shield", 0)), "dead": false, "saved": false,
			"rage": int(tgt.get("rage", 0)),
		}
	var incoming := maxi(0, amount)
	var warded := float((tgt.get("hooks", {}) as Dictionary).get("warded", 1.0))
	incoming = int(round(float(incoming) * warded))
	incoming = int(round(float(incoming) * maxf(0.25, 1.0 + _link_val(tgt, "taken"))))
	incoming = int(round(float(incoming) * (1.0 - _ward_of(tgt))))
	if allow_reflect and not redirected and not src.is_empty() and incoming > 1:
		var guard := _guard_for(tgt)
		if not guard.is_empty():
			var share := int(round(float(incoming) * 0.30))
			if share > 0 and share < incoming:
				incoming -= share
				_deal_damage(src, guard, share, false, element_mult, false, true)
	var absorbed := 0
	if int(tgt.get("shield", 0)) > 0 and incoming > 0:
		absorbed = mini(int(tgt["shield"]), incoming)
		tgt["shield"] = int(tgt["shield"]) - absorbed
		incoming -= absorbed
		if incoming == 0 and absorbed > 0 and not src.is_empty() and str(src.get("side", "")) != str(tgt.get("side", "")):
			_queue_riposte(tgt)
	var hp_before := int(tgt["hp"])
	tgt["hp"] = maxi(0, hp_before - incoming)
	if not src.is_empty() and str(src.get("side", "")) != str(tgt.get("side", "")):
		_apply_blade_grief(src, tgt)
		if bool(src.get("alarm_strike", false)):
			var extra := maxi(1, int(round(float(src.get("max_hp", 0)) * 0.10)))
			tgt["hp"] = maxi(0, int(tgt["hp"]) - extra)
	var saved := _cheat_death(tgt)
	var dead := int(tgt["hp"]) <= 0
	if not dead:
		tgt["rage"] = mini(rage_max, int(tgt.get("rage", 0)) + 1)
		_clamp_locked_rage(tgt)
	# lifesteal
	var lifesteal := float((src.get("hooks", {}) as Dictionary).get("lifesteal", 0.0)) if not src.is_empty() else 0.0
	if not src.is_empty():
		lifesteal += _status_pct(src, "vamp")
		lifesteal += _mark_sum(src, "self_vamp")
	if lifesteal > 0.0 and not dead and not src.is_empty():
		var heal_amt := int(float(hp_before - int(tgt["hp"])) * lifesteal)
		if heal_amt > 0:
			_heal(src, heal_amt)
	# reflect
	if allow_reflect and not src.is_empty() and int(src.get("hp", 0)) > 0:
		var reflect_pct := float((tgt.get("hooks", {}) as Dictionary).get("reflect", 0.0))
		if _has_status(tgt, "thorns"):
			reflect_pct += _status_pct(tgt, "thorns")
		if _has_status(tgt, "mirror"):
			reflect_pct = maxf(reflect_pct, 1.0)
		reflect_pct += _mark_sum(tgt, "self_thorns")
		if reflect_pct > 0.0 and incoming > 0:
			var reflected := maxi(1, int(float(incoming) * reflect_pct))
			var rs := int(src.get("shield", 0))
			var absorbed2 := mini(rs, reflected)
			src["shield"] = rs - absorbed2
			src["hp"] = maxi(0, int(src["hp"]) - (reflected - absorbed2))
			_cheat_death(src)
	if dead:
		_on_death_marks(tgt)
	return {
		"uid": int(tgt["uid"]), "damage": int(hp_before - int(tgt["hp"])),
		"absorbed": absorbed, "crit": crit, "element": element_mult,
		"hp": int(tgt["hp"]), "max_hp": int(tgt["max_hp"]), "shield": int(tgt.get("shield", 0)),
		"dead": dead, "saved": saved, "rage": int(tgt.get("rage", 0)),
	}


func _signature_style(u: Dictionary) -> String:
	var skills: Variant = u.get("skills", {})
	if typeof(skills) != TYPE_DICTIONARY:
		return ""
	var ult: Variant = (skills as Dictionary).get("ultimate", {})
	if typeof(ult) != TYPE_DICTIONARY:
		return ""
	var sig: Variant = (ult as Dictionary).get("signature", {})
	if typeof(sig) != TYPE_DICTIONARY:
		return ""
	return str((sig as Dictionary).get("style", ""))


func _queue_riposte(u: Dictionary) -> void:
	if _signature_style(u) != "owl" or int(u.get("hp", 0)) <= 0:
		return
	if _has_status(u, "stun") or _has_status(u, "seal"):
		return
	var last := int(u.get("riposte_round", -99))
	if _phase != "turns" or (last >= 0 and rounds - last < 3):
		return
	u["riposte_round"] = rounds
	if _index < _order.size() and int(_order[_index].get("uid", -2)) == int(u.get("uid", -1)):
		return
	_order.insert(_index, u)
	events.append({"t": "log", "text": "%s 格挡住了攻击，立即行动！" % str(u.get("name", ""))})


func _heal(u: Dictionary, amount: int) -> Dictionary:
	var scaled := int(round(float(maxi(0, amount)) * maxf(0.0, 1.0 - _mark_sum(u, "antiheal") - _status_pct(u, "wither"))))
	var before := int(u["hp"])
	u["hp"] = mini(int(u["max_hp"]), before + scaled)
	return {"uid": int(u["uid"]), "amount": int(u["hp"]) - before,
		"hp": int(u["hp"]), "max_hp": int(u["max_hp"])}


func _add_shield(u: Dictionary, amount: int) -> Dictionary:
	u["shield"] = int(u.get("shield", 0)) + maxi(0, amount)
	return {"uid": int(u["uid"]), "amount": amount, "shield": int(u["shield"])}


func _apply_status(u: Dictionary, key: String, dur: int, pct: float = 0.0, value: float = 0.0) -> void:
	if str(u.get("_ward_swing", "")) != "":
		return
	var fury_up := int(u.get("fury_left", 0)) > 0 or bool(u.get("fury_acting", false))
	var controlled := key == "stun" or key == "slow" or key == "seal" or key == "ult_seal" or key == "rage_seal"
	if controlled and _blade_tier(u) >= 4:
		return
	if (key == "stun" or key == "slow" or key == "seal") and (_has_status(u, "cc_immune") or fury_up):
		if _has_status(u, "cc_immune"):
			u["statuses"].erase("cc_immune")
		return
	var statuses: Dictionary = u["statuses"]
	var st: Dictionary = statuses.get(key, {"dur": 0, "pct": 0.0, "value": 0.0})
	st["dur"] = maxi(int(st.get("dur", 0)), dur)
	if pct > 0.0:
		st["pct"] = maxf(float(st.get("pct", 0.0)), pct)
	if value > 0.0:
		st["value"] = maxf(float(st.get("value", 0.0)), value)
	st["applied_round"] = rounds
	statuses[key] = st


func _cleanse_one(u: Dictionary) -> String:
	for key in ["stun", "burn", "slow", "atk_down", "def_down", "vulnerable"]:
		if (u["statuses"] as Dictionary).has(key):
			u["statuses"].erase(key)
			return key
	return ""


func _clamp_locked_rage(u: Dictionary) -> void:
	if u.is_empty():
		return
	if bool(u.get("fury_acting", false)) or int(u.get("fury_left", 0)) > 0:
		return
	if _has_status(u, "rage_seal"):
		u["rage"] = 0


func _escort_feed(u: Dictionary) -> void:
	if u.is_empty() or str(u.get("side", "")) != "enemy":
		return
	if not bool(u.get("king_escort", false)) or int(u.get("hp", 0)) <= 0:
		return
	var cap := int(combat.get("king_might_cap", 5))
	for ally in units:
		if str(ally.get("side", "")) != "enemy" or not bool(ally.get("demon_king", false)):
			continue
		if int(ally.get("hp", 0)) <= 0:
			continue
		ally["might"] = mini(cap, int(ally.get("might", 0)) + 1)
		ally["rage_sustain"] = int(ally.get("rage_sustain", 0)) + 1


func _volley(actor: Dictionary, target: Dictionary, action: Dictionary, deaths: Array) -> void:
	if int(target.get("hp", 0)) <= 0:
		return
	for ally in units:
		if str(ally.get("side", "")) != str(actor.get("side", "")):
			continue
		if int(ally.get("uid", -1)) == int(actor.get("uid", -2)) or int(ally.get("hp", 0)) <= 0:
			continue
		if int(target.get("hp", 0)) <= 0:
			break
		var skill: Dictionary = (ally.get("skills", {}) as Dictionary).get("normal", {})
		var info := _calc_damage(ally, target, float(skill.get("mult", 1.0)), "normal")
		var entry := _deal_damage(ally, target, int(info.get("amount", 0)), bool(info.get("crit", false)), float(info.get("element", 1.0)), true)
		action["targets"].append(entry)
		if bool(entry.get("dead", false)):
			deaths.append(int(entry.get("uid", 0)))
	events.append({"t": "log", "text": "%s 带动友方齐射 %s。" % [actor.get("name", ""), target.get("name", "")]})


func _apply_on_hit_affixes(actor: Dictionary, target: Dictionary, slot: String, primary_damage: int,
		action: Dictionary, allow_extra: bool, deaths: Array, hit_target: bool = true, self_cast: bool = true) -> void:
	if str(target.get("_ward_swing", "")) != "":
		return
	var list: Array = (actor.get("affixes", {}) as Dictionary).get(slot, [])
	if list.is_empty():
		return
	for aid in list:
		var affix: Dictionary = ContentDB.affix(str(aid))
		if affix.is_empty():
			continue
		match str(aid):
			"burn":
				if hit_target:
					var burn := maxi(1, int(float(actor["atk"]) * 0.06))
					_apply_status(target, "burn", 2, 0.0, burn)
					action["statuses"].append({"uid": int(target["uid"]), "status": "burn", "dur": 2, "value": burn})
			"frost":
				if hit_target and rng.randf() < 0.20:
					_apply_status(target, "stun", 1)
					action["statuses"].append({"uid": int(target["uid"]), "status": "stun", "dur": 1})
			"drain":
				if hit_target:
					var h := _heal(actor, int(float(primary_damage) * 0.25))
					if int(h["amount"]) > 0:
						action["heals"].append(h)
			"armor_break":
				if hit_target:
					_apply_status(target, "def_down", 2, 0.15)
					action["statuses"].append({"uid": int(target["uid"]), "status": "def_down", "dur": 2, "pct": 0.15})
			"rebound":
				if self_cast:
					_apply_status(actor, "mirror", 1)
			"aegis":
				if self_cast:
					_apply_status(actor, "immune", 1)
			"still":
				if hit_target:
					target["rage"] = 0
					_apply_status(target, "rage_seal", 1)
					action["statuses"].append({"uid": int(target["uid"]), "status": "rage_seal", "dur": 1})
			"volley":
				if hit_target and allow_extra and rng.randf() < float(affix.get("value", 0.20)):
					_volley(actor, target, action, deaths)
			"double":
				if hit_target and allow_extra and not target.is_empty() and int(target["hp"]) > 0 and rng.randf() < 0.25:
					var info := _calc_damage(actor, target, 0.5, slot)
					var e := _deal_damage(actor, target, int(info["amount"]), bool(info["crit"]), float(info["element"]), false)
					e["extra"] = true
					action["targets"].append(e)
					if e["dead"]:
						deaths.append(e["uid"])
			"splash":
				if hit_target and allow_extra:
					var others := _other_targets(actor, target)
					if not others.is_empty():
						var amount := maxi(1, int(float(primary_damage) * 0.30))
						var e := _deal_damage(actor, others[0], amount, false, 1.0, false)
						e["splash"] = true
						action["targets"].append(e)
						if e["dead"]:
							deaths.append(e["uid"])
			"haste":
				if self_cast:
					_apply_status(actor, "haste", 2, 0.20)
					action["statuses"].append({"uid": int(actor["uid"]), "status": "haste", "dur": 2, "pct": 0.20})
			"shield":
				if self_cast:
					var sh := _add_shield(actor, int(float(actor["max_hp"]) * 0.08))
					action["shields"].append(sh)
			"cleanse":
				if self_cast:
					_cleanse_one(actor)
			"heal_ally":
				if self_cast:
					var ally := _lowest_ally(actor)
					if not ally.is_empty():
						var h2 := _heal(ally, int(float(ally["max_hp"]) * 0.06))
						if int(h2["amount"]) > 0:
							action["heals"].append(h2)
			"thorns":
				if self_cast:
					_apply_status(actor, "thorns", 2, 0.15)
					action["statuses"].append({"uid": int(actor["uid"]), "status": "thorns", "dur": 2, "pct": 0.15})
			"war_cry":
				if self_cast:
					for ally2 in _alive_units(str(actor["side"])):
						_apply_status(ally2, "atk_up", 2, 0.10)
						action["statuses"].append({"uid": int(ally2["uid"]), "status": "atk_up", "dur": 2, "pct": 0.10})
			"vamp_aura":
				if self_cast:
					for ally3 in _alive_units(str(actor["side"])):
						_apply_status(ally3, "vamp", 2, 0.08)
						action["statuses"].append({"uid": int(ally3["uid"]), "status": "vamp", "dur": 2, "pct": 0.08})
			"vulnerability":
				if hit_target:
					_apply_status(target, "vulnerable", 2, 0.15)
					action["statuses"].append({"uid": int(target["uid"]), "status": "vulnerable", "dur": 2, "pct": 0.15})


func _apply_item_on_hit(actor: Dictionary, target: Dictionary, slot: String,
		action: Dictionary, allow_extra: bool) -> void:
	if str(target.get("_ward_swing", "")) != "":
		return
	var hooks: Dictionary = actor.get("hooks", {})
	var burn_rate := float(hooks.get("burn_on_hit", 0.0))
	if burn_rate > 0.0 and int(target["hp"]) > 0:
		var burn := maxi(1, int(float(actor["atk"]) * burn_rate))
		_apply_status(target, "burn", 2, 0.0, burn)
		action["statuses"].append({"uid": int(target["uid"]), "status": "burn", "dur": 2, "value": burn})
	var slow_rate := float(hooks.get("slow_on_hit", 0.0))
	if slow_rate > 0.0 and int(target["hp"]) > 0:
		_apply_status(target, "slow", 2, slow_rate)
		action["statuses"].append({"uid": int(target["uid"]), "status": "slow", "dur": 2, "pct": slow_rate})
	var double_chance := float(hooks.get("double_normal", 0.0))
	if allow_extra and (slot == "normal" or slot == "basic") and double_chance > 0.0 and int(target["hp"]) > 0:
		if rng.randf() < double_chance:
			var info := _calc_damage(actor, target, 0.5, slot)
			var e := _deal_damage(actor, target, int(info["amount"]), bool(info["crit"]), float(info["element"]), false)
			e["extra"] = true
			action["targets"].append(e)


func _check_phase_after(u: Dictionary) -> void:
	if int(u.get("hp", 0)) <= 0:
		return
	if not (bool(u.get("is_boss", false)) or bool(u.get("is_hero", false))):
		return
	var phases: Array = u.get("phases", [])
	if phases.is_empty():
		return
	while int(u.get("phase_index", 0)) < phases.size():
		var ph: Dictionary = phases[int(u["phase_index"])]
		if _hp_ratio(u) <= float(ph.get("hp_pct", 0.0)):
			u["phase_index"] = int(u["phase_index"]) + 1
			var buff_id := str(ph.get("buff", ""))
			_apply_single_boss_buff(u, buff_id, float(ph.get("scale", 1.0)))
			u["rage"] = rage_max
			var shield_amount := int(float(u["max_hp"]) * 0.12)
			_add_shield(u, shield_amount)
			events.append({"t": "phase", "uid": int(u["uid"]), "shield": shield_amount,
				"text": str(ph.get("text", "首领进入新阶段！"))})
		else:
			break


func _apply_single_boss_buff(u: Dictionary, bid: String, scale: float = 1.0) -> void:
	var hooks: Dictionary = u.get("hooks", {})
	match bid:
		"frenzy":
			u["atk"] = int(round(float(u["atk"]) * (1.0 + 0.30 * scale)))
		"undying":
			u["max_hp"] = int(round(float(u["max_hp"]) * (1.0 + 0.40 * scale)))
			u["hp"] = int(u["max_hp"])
		"bedrock":
			u["def"] = int(round(float(u["def"]) * (1.0 + 0.30 * scale)))
		"swift":
			u["spd"] = int(round(float(u["spd"]) * (1.0 + 0.25 * scale)))
		"bloodthirst":
			hooks["lifesteal"] = float(hooks.get("lifesteal", 0.0)) + 0.25 * scale
		"barbed":
			hooks["reflect"] = float(hooks.get("reflect", 0.0)) + 0.18 * scale
		"renewal":
			hooks["regen"] = float(hooks.get("regen", 0.0)) + 0.07 * scale
		"oppress":
			hooks["oppress"] = float(hooks.get("oppress", 0.0)) + 0.15 * scale
		"warded":
			hooks["warded"] = 1.0 - 0.15 * scale
		"surge":
			hooks["ult_damage"] = float(hooks.get("ult_damage", 0.0)) + 0.40 * scale
		"pierce":
			hooks["pierce"] = float(hooks.get("pierce", 0.0)) + 0.30 * scale
		"enrage":
			hooks["enrage"] = float(hooks.get("enrage", 0.0)) + 0.35 * scale
		"siphon":
			hooks["lifesteal"] = float(hooks.get("lifesteal", 0.0)) + 0.15 * scale
			hooks["regen"] = float(hooks.get("regen", 0.0)) + 0.03 * scale
	u["hooks"] = hooks


# ---------------------------------------------------------------- formation, marks, signatures

func _apply_links() -> void:
	var formation: Dictionary = ContentDB.data.get("formation", {})
	var links: Array = formation.get("links", [])
	if links.is_empty():
		return
	for side in ["player", "enemy"]:
		var alive := _alive_units(side)
		for i in range(alive.size()):
			for j in range(i + 1, alive.size()):
				var a: Dictionary = alive[i]
				var b: Dictionary = alive[j]
				if absi(int(a["row"]) - int(b["row"])) + absi(int(a["col"]) - int(b["col"])) != 1:
					continue
				_try_link(a, b, links)


func _try_link(a: Dictionary, b: Dictionary, links: Array) -> void:
	var ca := str(a.get("class", ""))
	var cb := str(b.get("class", ""))
	for link in links:
		var row: Dictionary = link
		var la := str(row.get("a", ""))
		var lb := str(row.get("b", ""))
		if not ((ca == la and cb == lb) or (ca == lb and cb == la)):
			continue
		var mods: Dictionary = row.get("mods", {})
		_add_link(a, mods.get(ca, {}))
		_add_link(b, mods.get(cb, {}))


func _add_link(u: Dictionary, mods: Variant) -> void:
	if typeof(mods) != TYPE_DICTIONARY:
		return
	var bucket: Dictionary = mods
	if bucket.is_empty():
		return
	var link := _link_of(u)
	if not u.has("link"):
		link = {"atk": 0.0, "def": 0.0, "spd": 0.0, "crit": 0.0, "taken": 0.0, "skill": 0.0, "heal": 0.0, "shield": 0.0}
	for key in bucket.keys():
		link[str(key)] = float(link.get(key, 0.0)) + float(bucket[key])
	u["link"] = link


func _apply_cells() -> void:
	var elements: Dictionary = ContentDB.data.get("elements", {})
	var ids: Array = elements.keys()
	if ids.is_empty():
		return
	for side in ["player", "enemy"]:
		var used := {}
		var placed := 0
		var guard := 0
		while placed < 2 and guard < 30:
			guard += 1
			var row := rng.randi_range(0, 2)
			var col := rng.randi_range(0, 2)
			var key := "%d:%d" % [row, col]
			if used.has(key):
				continue
			used[key] = true
			var el := str(ids[rng.randi_range(0, ids.size() - 1)])
			placed += 1
			for u in _alive_units(side):
				if int(u["row"]) == row and int(u["col"]) == col and str(u["element"]) == el:
					u["rage"] = mini(rage_max, int(u.get("rage", 0)) + 1)
					events.append({"t": "log", "text": "%s 站在%s地格上，气势 +1。" % [u["name"], ContentDB.element_name(el)]})


func _poison_damage(u: Dictionary) -> int:
	var total := 0.0
	var bag := _marks_of(u)
	for key in bag.keys():
		var row: Dictionary = bag[key]
		if str(row.get("fx", "")) != "poison":
			continue
		total += float(row.get("atk", 1)) * float(row.get("per", 0.0)) * float(row.get("n", 0))
	if total <= 0.0:
		return 0
	return maxi(1, int(total))


func _tick_adjacent(u: Dictionary, tick_entries: Array) -> void:
	var bag := _marks_of(u)
	for key in bag.keys():
		var row: Dictionary = bag[key]
		if str(row.get("fx", "")) != "tick_adj":
			continue
		var raw := float(row.get("atk", 1)) * float(row.get("per", 0.0)) * float(row.get("n", 0))
		if raw <= 0.0:
			continue
		var dmg := maxi(1, int(raw))
		for ally in _adjacent(u):
			if int(ally.get("hp", 0)) <= 0:
				continue
			tick_entries.append(_deal_damage({}, ally, dmg, false, 1.0, false))


func _adjacent(u: Dictionary) -> Array:
	var out: Array = []
	for a in _alive_units(str(u.get("side", ""))):
		if int(a["uid"]) == int(u["uid"]):
			continue
		if absi(int(a["row"]) - int(u["row"])) + absi(int(a["col"]) - int(u["col"])) == 1:
			out.append(a)
	return out


func _guard_for(tgt: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_col := -1
	for ally in _alive_units(str(tgt.get("side", ""))):
		if int(ally["uid"]) == int(tgt["uid"]):
			continue
		if str(ally.get("class", "")) != "guardian":
			continue
		if int(ally["row"]) != int(tgt["row"]):
			continue
		if int(ally["col"]) >= int(tgt["col"]):
			continue
		if int(ally["col"]) > best_col:
			best = ally
			best_col = int(ally["col"])
	return best


func _ward_of(tgt: Dictionary) -> float:
	var allies := _alive_units(str(tgt.get("side", "")))
	if allies.is_empty():
		return 0.0
	var lowest: Dictionary = allies[0]
	for ally in allies:
		if _hp_ratio(ally) < _hp_ratio(lowest):
			lowest = ally
	if int(lowest["uid"]) != int(tgt["uid"]):
		return 0.0
	var best := 0.0
	for ally in allies:
		best = maxf(best, _mark_sum(ally, "ward"))
	return clampf(best, 0.0, 0.6)


func _on_death_marks(u: Dictionary) -> void:
	if bool(u.get("nova_done", false)):
		return
	u["nova_done"] = true
	var bag := _marks_of(u)
	for key in bag.keys():
		var row: Dictionary = bag[key]
		var n := float(row.get("n", 0))
		if n <= 0.0:
			continue
		if str(row.get("fx2", "")) == "death_nova" or str(row.get("fx", "")) == "death_nova":
			var dmg := maxi(1, int(float(u.get("atk", 1)) * float(row.get("per2", row.get("per", 0.2))) * n))
			for foe in _opponents(str(u.get("side", ""))):
				_deal_damage({}, foe, dmg, false, 1.0, false)
		if str(row.get("fx2", "")) == "kill_spd":
			var src_id := int(row.get("src", -1))
			if by_uid.has(src_id):
				var src: Dictionary = by_uid[src_id]
				if int(src.get("hp", 0)) > 0:
					_apply_status(src, "haste", 2, float(row.get("per2", 0.08)) * n)


func _powered_heal(caster: Dictionary, target: Dictionary, amount: int) -> Dictionary:
	var bonus := _mark_sum(caster, "self_heal") + _link_val(caster, "heal")
	return _heal(target, int(round(float(amount) * maxf(0.0, 1.0 + bonus))))


func _powered_shield(caster: Dictionary, target: Dictionary, amount: int) -> Dictionary:
	var bonus := _link_val(caster, "shield")
	return _add_shield(target, int(round(float(amount) * maxf(0.0, 1.0 + bonus))))


func _our_mark(u: Dictionary) -> Dictionary:
	var raw: Variant = u.get("mark", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw


func _mark_id(u: Dictionary) -> String:
	return str(_our_mark(u).get("id", ""))


func _stacks_on(holder: Dictionary, mid: String) -> int:
	if mid == "" or holder.is_empty():
		return 0
	var bag := _marks_of(holder)
	if not bag.has(mid):
		return 0
	var row: Dictionary = bag[mid]
	return int(row.get("n", 0))


func _blank_row(attacker: Dictionary, mark: Dictionary, n: int) -> Dictionary:
	return {
		"n": n,
		"src": int(attacker.get("uid", 0)),
		"atk": int(attacker.get("atk", 1)),
		"fx": str(mark.get("fx", "")),
		"per": float(mark.get("per", 0.0)),
		"fx2": str(mark.get("fx2", "")),
		"per2": float(mark.get("per2", 0.0)),
		"elem": str(mark.get("elem", "")),
		"full": str(mark.get("full", "")),
		"burst": float(mark.get("burst", 0.0)),
		"name": str(mark.get("name", "")),
	}


func _write_mark(holder: Dictionary, mid: String, row: Dictionary) -> void:
	var bag := _marks_of(holder)
	bag[mid] = row
	holder["marks"] = bag


func _holder_for(attacker: Dictionary, target: Dictionary) -> Dictionary:
	if str(_our_mark(attacker).get("on", "foe")) == "self":
		return attacker
	return target


func _set_stacks(attacker: Dictionary, holder: Dictionary, n: int) -> void:
	var mark := _our_mark(attacker)
	if mark.is_empty() or holder.is_empty():
		return
	var mid := str(mark.get("id", "mark"))
	var capped := clampi(n, 0, int(mark.get("max", 3)))
	var bag := _marks_of(holder)
	if capped <= 0:
		bag.erase(mid)
		holder["marks"] = bag
		return
	_write_mark(holder, mid, _blank_row(attacker, mark, capped))


func _force_stack(attacker: Dictionary, holder: Dictionary, add: int, action: Dictionary) -> void:
	var mark := _our_mark(attacker)
	if mark.is_empty() or holder.is_empty() or int(holder.get("hp", 0)) <= 0:
		return
	var mid := str(mark.get("id", "mark"))
	var n := mini(int(mark.get("max", 3)), _stacks_on(holder, mid) + add)
	_write_mark(holder, mid, _blank_row(attacker, mark, n))
	action["statuses"].append({"uid": int(holder["uid"]), "status": "mark", "name": str(mark.get("name", "")), "n": n})


func _stamp_mark(attacker: Dictionary, target: Dictionary, action: Dictionary) -> void:
	if str(target.get("_ward_swing", "")) != "":
		return
	var mark := _our_mark(attacker)
	if mark.is_empty():
		return
	var on_self := str(mark.get("on", "foe")) == "self"
	var holder: Dictionary = attacker if on_self else target
	if holder.is_empty() or (not on_self and int(holder.get("hp", 0)) <= 0):
		return
	var mid := str(mark.get("id", "mark"))
	var old_n := _stacks_on(holder, mid)
	var n := mini(int(mark.get("max", 3)), old_n + 1)
	var row := _blank_row(attacker, mark, n)
	_write_mark(holder, mid, row)
	action["statuses"].append({"uid": int(holder["uid"]), "status": "mark", "name": str(mark.get("name", "")), "n": n})
	if n >= int(mark.get("max", 3)):
		var full_kind := str(mark.get("full", ""))
		if full_kind != "shield" or old_n < int(mark.get("max", 3)):
			_mark_full(attacker, holder, row, action)


func _mark_full(attacker: Dictionary, holder: Dictionary, row: Dictionary, action: Dictionary) -> void:
	var atk := float(attacker.get("atk", 1))
	match str(row.get("full", "")):
		"burst":
			if int(holder.get("hp", 0)) > 0 and str(holder.get("side", "")) != str(attacker.get("side", "")):
				var dmg := maxi(1, int(atk * float(row.get("burst", 0.2))))
				action["targets"].append(_deal_damage(attacker, holder, dmg, false, 1.0, false))
		"freeze":
			if int(holder.get("hp", 0)) > 0:
				_apply_status(holder, "stun", 1, 0.0)
				action["statuses"].append({"uid": int(holder["uid"]), "status": "stun", "dur": 1})
		"chain":
			for ally in _adjacent(holder):
				var splash := maxi(1, int(atk * float(row.get("burst", 0.15))))
				action["targets"].append(_deal_damage(attacker, ally, splash, false, 1.0, false))
		"immune":
			_apply_status(attacker, "cc_immune", 2, 0.0)
			action["statuses"].append({"uid": int(attacker["uid"]), "status": "cc_immune", "dur": 2})
		"nocrit":
			_apply_status(holder, "nocrit", 2, 1.0)
			action["statuses"].append({"uid": int(holder["uid"]), "status": "nocrit", "dur": 2})
		"aoe_next":
			attacker["aoe_next"] = true
		"shield":
			var shell := int(float(holder.get("max_hp", 1)) * float(row.get("burst", 0.5)))
			action["shields"].append(_powered_shield(attacker, holder, shell))


func _rider_for(u: Dictionary, slot: String) -> String:
	var skill: Dictionary = (u.get("skills", {}) as Dictionary).get(slot, {})
	var rider := str(skill.get("rider", ""))
	if rider != "":
		return rider
	return _fallback_rider(str(u.get("element", "")))


func _fallback_rider(element: String) -> String:
	match element:
		"fire":
			return "burn"
		"water", "ice", "bug":
			return "slow"
		"electric":
			return "shock"
		"grass":
			return "regen"
		"fighting":
			return "atk_self"
		"poison":
			return "poison"
		"ground", "rock", "steel":
			return "def_down"
		"flying":
			return "haste"
		"psychic", "normal":
			return "shield"
		"ghost", "dark":
			return "atk_down"
		"dragon":
			return "vulnerable"
	return ""


func _rider_units(targets: Array) -> Array:
	var out: Array = []
	for t in targets:
		if bool(t.get("dead", false)):
			continue
		var uid := int(t.get("uid", -1))
		if by_uid.has(uid):
			var unit: Dictionary = by_uid[uid]
			if int(unit.get("hp", 0)) > 0:
				out.append(unit)
		elif int(t.get("hp", 0)) > 0:
			out.append(t)
	return out


func _apply_rider(u: Dictionary, targets: Array, action: Dictionary, rider: String) -> void:
	match rider:
		"burn", "poison":
			var burn := maxi(1, int(float(u["atk"]) * 0.06))
			for t in targets:
				_apply_status(t, "burn", 2, 0.0, burn)
				action["statuses"].append({"uid": int(t["uid"]), "status": "burn", "dur": 2, "value": burn})
		"slow", "shock":
			for t in targets:
				_apply_status(t, "slow", 2, 0.15)
				action["statuses"].append({"uid": int(t["uid"]), "status": "slow", "dur": 2, "pct": 0.15})
		"haste":
			_apply_status(u, "haste", 2, 0.20)
			action["statuses"].append({"uid": int(u["uid"]), "status": "haste", "dur": 2, "pct": 0.20})
		"def_down":
			for t in targets:
				_apply_status(t, "def_down", 2, 0.20)
				action["statuses"].append({"uid": int(t["uid"]), "status": "def_down", "dur": 2, "pct": 0.20})
		"shield":
			for ally in _alive_units(str(u["side"])):
				action["shields"].append(_add_shield(ally, int(float(ally["max_hp"]) * 0.08)))
		"regen":
			action["heals"].append(_powered_heal(u, u, int(float(u["max_hp"]) * 0.06)))
		"atk_self":
			_apply_status(u, "atk_up", 2, 0.12)
			action["statuses"].append({"uid": int(u["uid"]), "status": "atk_up", "dur": 2, "pct": 0.12})
		"atk_down":
			for t in targets:
				_apply_status(t, "atk_down", 2, 0.15)
				action["statuses"].append({"uid": int(t["uid"]), "status": "atk_down", "dur": 2, "pct": 0.15})
		"vulnerable":
			for t in targets:
				_apply_status(t, "vulnerable", 2, 0.15)
				action["statuses"].append({"uid": int(t["uid"]), "status": "vulnerable", "dur": 2, "pct": 0.15})


func _skill_hit(src: Dictionary, tgt: Dictionary, mult: float, action: Dictionary, deaths: Array, stamp: bool = false) -> Dictionary:
	if tgt.is_empty() or int(tgt.get("hp", 0)) <= 0:
		return {}
	var info := _calc_damage(src, tgt, mult, "ultimate")
	var entry := _deal_damage(src, tgt, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
	action["targets"].append(entry)
	if entry["dead"]:
		deaths.append(entry["uid"])
	if stamp:
		_stamp_mark(src, tgt, action)
	return entry


func _flat_hit(src: Dictionary, tgt: Dictionary, amount: int, action: Dictionary, deaths: Array) -> Dictionary:
	if tgt.is_empty() or int(tgt.get("hp", 0)) <= 0 or amount <= 0:
		return {}
	var entry := _deal_damage(src, tgt, amount, false, 1.0, true)
	action["targets"].append(entry)
	if entry["dead"]:
		deaths.append(entry["uid"])
	return entry


func _random_foe(u: Dictionary) -> Dictionary:
	var foes := _opponents(str(u["side"]))
	if foes.is_empty():
		return {}
	return foes[rng.randi_range(0, foes.size() - 1)]


func _marked_foe(u: Dictionary) -> Dictionary:
	var mid := _mark_id(u)
	var marked: Array = []
	for foe in _opponents(str(u["side"])):
		if _stacks_on(foe, mid) > 0:
			marked.append(foe)
	if marked.is_empty():
		return _random_foe(u)
	return marked[rng.randi_range(0, marked.size() - 1)]


func _highest_mark_foe(u: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_n := -1
	var mid := _mark_id(u)
	for foe in _opponents(str(u["side"])):
		var n := _stacks_on(foe, mid)
		if n > best_n:
			best = foe
			best_n = n
	if best_n <= 0:
		return _front_target(u)
	return best


func _same_file(target: Dictionary) -> Array:
	var out: Array = []
	if target.is_empty():
		return out
	for foe in _alive_units(str(target["side"])):
		if int(foe["row"]) == int(target["row"]):
			out.append(foe)
	return out


func _dispel_buff(u: Dictionary) -> String:
	for key in ["atk_up", "haste", "thorns", "vamp"]:
		if _has_status(u, key):
			u["statuses"].erase(key)
			return key
	return ""


func _steal_buff(caster: Dictionary, target: Dictionary, action: Dictionary) -> void:
	var key := _dispel_buff(target)
	if key == "":
		return
	_apply_status(caster, key, 2, 0.10)
	action["statuses"].append({"uid": int(caster["uid"]), "status": key, "dur": 2, "pct": 0.10})


func _apply_signature(u: Dictionary, action: Dictionary, deaths: Array) -> void:
	var skill: Dictionary = (u.get("skills", {}) as Dictionary).get("ultimate", {})
	var sig: Variant = skill.get("signature", {})
	if typeof(sig) != TYPE_DICTIONARY:
		return
	var spec: Dictionary = sig
	if spec.is_empty():
		return
	var dealt := 0
	var was_crit := false
	if not (action["targets"] as Array).is_empty():
		dealt = int(action["targets"][0].get("damage", 0))
		was_crit = bool(action["targets"][0].get("crit", false))
	var primary: Dictionary = {}
	if not (action["targets"] as Array).is_empty():
		var uid := int(action["targets"][0].get("uid", -1))
		if by_uid.has(uid):
			primary = by_uid[uid]
	var mid := _mark_id(u)
	match str(spec.get("style", "")):
		"wounded":
			if not primary.is_empty() and int(primary["hp"]) + dealt < int(primary["max_hp"]):
				_flat_hit(u, primary, int(round(float(dealt) * float(spec.get("bonus", 0.25)))), action, deaths)
			_set_stacks(u, _holder_for(u, primary), int(spec.get("leave", 1)))
		"haste_lock":
			if not primary.is_empty():
				_apply_status(primary, "lock", 2, 1.0)
				action["statuses"].append({"uid": int(primary["uid"]), "status": "lock", "dur": 2})
			action["heals"].append(_powered_heal(u, u, int(float(u["max_hp"]) * float(spec.get("heal", 0.08)))))
		"shatter":
			if not primary.is_empty() and (_has_status(primary, "stun") or _has_status(primary, "slow") or _has_status(primary, "seal")):
				_flat_hit(u, primary, dealt, action, deaths)
				for ally in _adjacent(primary):
					_flat_hit(u, ally, int(float(dealt) * float(spec.get("splash", 0.30))), action, deaths)
					break
		"bounce":
			var jumps := int(spec.get("jumps", 2))
			for _j in range(jumps):
				var foe := _random_foe(u)
				var mult := 0.55
				if _stacks_on(foe, mid) > 0:
					mult *= 1.0 + float(spec.get("bonus", 0.20))
				_skill_hit(u, foe, mult, action, deaths, false)
		"sure_crit":
			var stacks := _stacks_on(u, mid)
			if not was_crit and not primary.is_empty():
				_flat_hit(u, primary, int(float(dealt) * (float(combat.get("crit_mult", 1.6)) - 1.0)), action, deaths)
			if stacks > 0 and not primary.is_empty():
				_flat_hit(u, primary, int(float(dealt) * float(spec.get("per", 0.15)) * float(stacks)), action, deaths)
			_set_stacks(u, u, 0)
		"back_shred":
			for foe in _opponents(str(u["side"])):
				if int(foe["col"]) >= 2:
					_apply_status(foe, "def_down", 2, float(spec.get("pct", 0.15)))
					action["statuses"].append({"uid": int(foe["uid"]), "status": "def_down", "dur": 2, "pct": float(spec.get("pct", 0.15))})
		"double_hit":
			_skill_hit(u, primary if not primary.is_empty() else _front_target(u), float(spec.get("ratio", 0.50)), action, deaths, true)
		"poison_pop":
			for foe in _opponents(str(u["side"])):
				_force_stack(u, foe, 1, action)
				var n := _stacks_on(foe, mid)
				if n > 0 and int(foe.get("hp", 0)) > 0:
					var tick := int(float(u["atk"]) * float(_our_mark(u).get("per", 0.04)) * float(mini(2, n)))
					_flat_hit(u, foe, maxi(1, tick), action, deaths)
		"antiheal_dispel":
			if not primary.is_empty() and _mark_sum(primary, "antiheal") > 0.0:
				_flat_hit(u, primary, int(float(dealt) * float(spec.get("bonus", 0.35))), action, deaths)
				_dispel_buff(primary)
		"team_mend":
			for ally in _alive_units(str(u["side"])):
				action["heals"].append(_powered_heal(u, ally, int(float(ally["max_hp"]) * float(spec.get("heal", 0.12)))))
			var mend_stacks := _stacks_on(u, mid)
			if mend_stacks > 0:
				action["shields"].append(_powered_shield(u, u, int(float(u["max_hp"]) * 0.04 * float(mend_stacks))))
				_set_stacks(u, u, 0)
		"missing":
			if not primary.is_empty():
				var curse := _stacks_on(primary, mid)
				var missing_hp := maxi(0, int(primary["max_hp"]) - int(primary["hp"]) - dealt)
				var extra := int(float(missing_hp) * float(spec.get("per", 0.08)) * float(curse))
				extra = mini(extra, int(float(primary["max_hp"]) * float(spec.get("cap", 0.24))))
				_flat_hit(u, primary, extra, action, deaths)
		"drain":
			if not primary.is_empty():
				var layers := _stacks_on(primary, mid)
				if layers > 0:
					var bite := int(float(u["atk"]) * float(spec.get("per", 0.30)) * float(layers))
					var hit := _flat_hit(u, primary, maxi(1, bite), action, deaths)
					if int(hit.get("damage", 0)) > 0:
						action["heals"].append(_heal(u, int(hit["damage"])))
					_set_stacks(u, primary, 0)
		"column":
			var glow := _stacks_on(_holder_for(u, primary), mid)
			var bonus := 0.55 * (1.0 + float(spec.get("per", 0.12)) * float(glow))
			for foe in _same_file(primary):
				_skill_hit(u, foe, bonus, action, deaths, false)
		"thorn_shield":
			var plates := _stacks_on(u, mid)
			if plates > 0:
				var shell := int(float(u["max_hp"]) * float(spec.get("per", 0.08)) * float(plates))
				action["shields"].append(_powered_shield(u, u, shell))
				_flat_hit(u, _front_target(u), shell, action, deaths)
				_set_stacks(u, u, 0)
		"triple":
			var extra_hits := maxi(0, int(spec.get("hits", 3)) - 1)
			var ratio := float(spec.get("ratio", 0.70))
			var marked := not primary.is_empty() and _stacks_on(primary, mid) > 0
			for hit_i in range(extra_hits):
				if primary.is_empty() or int(primary.get("hp", 0)) <= 0:
					primary = _front_target(u)
				if primary.is_empty():
					break
				if marked and hit_i == extra_hits - 1:
					for foe in _opponents(str(u["side"])):
						_skill_hit(u, foe, ratio, action, deaths, true)
				else:
					_skill_hit(u, primary, ratio, action, deaths, true)
		"team_ward":
			for ally in _alive_units(str(u["side"])):
				_force_stack(u, ally, int(spec.get("stacks", 2)), action)
				action["heals"].append(_powered_heal(u, ally, int(float(ally["max_hp"]) * float(spec.get("heal", 0.10)))))
		"by_stacks":
			var bells := _stacks_on(u, mid)
			var sniper := _lowest_target(u)
			for _b in range(bells):
				if sniper.is_empty() or int(sniper.get("hp", 0)) <= 0:
					sniper = _lowest_target(u)
				if sniper.is_empty():
					break
				_skill_hit(u, sniper, float(spec.get("ratio", 0.60)), action, deaths, false)
		"pierce_shield":
			if not primary.is_empty():
				_flat_hit(u, primary, int(float(dealt) * float(spec.get("ignore", 0.50)) * 0.35), action, deaths)
			var lava := _stacks_on(_holder_for(u, primary), mid)
			if lava > 0:
				action["shields"].append(_powered_shield(u, u, int(float(u["max_hp"]) * float(spec.get("per", 0.06)) * float(lava))))
				_set_stacks(u, _holder_for(u, primary), 0)
		"shove":
			if not primary.is_empty():
				primary["col"] = 2
				_apply_status(primary, "stun", 1, 0.0)
				action["statuses"].append({"uid": int(primary["uid"]), "status": "stun", "dur": 1})
		"seed_burst":
			var seeds := _stacks_on(_holder_for(u, primary), mid)
			if seeds > 0 and not primary.is_empty():
				var bloom := int(float(u["atk"]) * float(spec.get("per", 0.30)) * float(seeds))
				_flat_hit(u, primary, maxi(1, bloom), action, deaths)
				action["heals"].append(_powered_heal(u, u, int(float(bloom) * float(spec.get("heal", 0.30)))))
				_set_stacks(u, _holder_for(u, primary), 0)
		"random_mark", "shadow_refund":
			var refund := false
			for _h in range(int(spec.get("hits", 4))):
				var foe := _marked_foe(u) if str(spec.get("style", "")) == "random_mark" else _random_foe(u)
				var shot := _skill_hit(u, foe, 0.55, action, deaths, false)
				if bool(shot.get("crit", false)):
					refund = true
			if str(spec.get("style", "")) == "shadow_refund" and refund:
				u["rage"] = mini(rage_max, int(u.get("rage", 0)) + 1)
		"fear", "roar":
			for foe in _opponents(str(u["side"])):
				_apply_status(foe, "atk_down", 2, float(spec.get("pct", 0.12)))
				action["statuses"].append({"uid": int(foe["uid"]), "status": "atk_down", "dur": 2, "pct": float(spec.get("pct", 0.12))})
			var victim := _highest_mark_foe(u) if str(spec.get("style", "")) == "fear" else _front_target(u)
			if not victim.is_empty():
				_apply_status(victim, "stun", 1, 0.0)
				action["statuses"].append({"uid": int(victim["uid"]), "status": "stun", "dur": 1})
		"seal":
			if not primary.is_empty():
				_apply_status(primary, "seal", 1, 0.0)
				action["statuses"].append({"uid": int(primary["uid"]), "status": "seal", "dur": 1})
				var silk := _stacks_on(primary, mid)
				if silk > 0:
					action["shields"].append(_powered_shield(u, u, int(float(u["max_hp"]) * float(spec.get("per", 0.06)) * float(silk))))
		"back_exec":
			if not primary.is_empty() and int(primary["col"]) >= 2 and _hp_ratio(primary) < float(spec.get("line", 0.40)):
				_flat_hit(u, primary, int(float(dealt) * float(spec.get("bonus", 0.50))), action, deaths)
		"freeze_all":
			for foe in _opponents(str(u["side"])):
				_force_stack(u, foe, 1, action)
				if int(foe.get("hp", 0)) > 0 and (_has_status(foe, "stun") or _has_status(foe, "seal")):
					_flat_hit(u, foe, int(float(u["atk"]) * float(spec.get("burst", 0.40))), action, deaths)
		"chain":
			var chain_mult := 0.80
			for foe in _opponents(str(u["side"])):
				_skill_hit(u, foe, chain_mult, action, deaths, false)
				if int(foe.get("hp", 0)) > 0:
					_apply_status(foe, "slow", 2, 0.15)
					action["statuses"].append({"uid": int(foe["uid"]), "status": "slow", "dur": 2, "pct": 0.15})
				chain_mult = maxf(0.25, chain_mult - float(spec.get("falloff", 0.20)))
		"eclipse":
			if not primary.is_empty():
				var before_missing := clampf((float(primary["max_hp"]) - float(primary["hp"]) - float(dealt)) / maxf(1.0, float(primary["max_hp"])), 0.0, 1.0)
				_flat_hit(u, primary, int(round(float(dealt) * before_missing * 100.0 * float(spec.get("per", 0.004)))), action, deaths)
				_steal_buff(u, primary, action)
		"owl":
			_apply_status(u, "taunt", 2, 0.0)
			action["statuses"].append({"uid": int(u["uid"]), "status": "taunt", "dur": 2})
			_apply_status(u, "def_up", 2, float(spec.get("def_up", 0.40)))
			action["statuses"].append({"uid": int(u["uid"]), "status": "def_up", "dur": 2, "pct": float(spec.get("def_up", 0.40))})
		"true_exec":
			var souls := _stacks_on(u, mid)
			if souls > 0 and not primary.is_empty():
				_flat_hit(u, primary, maxi(1, int(float(u["atk"]) * float(spec.get("per", 0.50)) * float(souls))), action, deaths)
				_set_stacks(u, u, 0)
				if int(primary.get("hp", 0)) > 0 and _hp_ratio(primary) < float(spec.get("line", 0.25)):
					_flat_hit(u, primary, int(primary["hp"]), action, deaths)
		"star_purge":
			var orbits := _stacks_on(u, mid)
			var seen: Array = (action["targets"] as Array).duplicate()
			for shot in seen:
				var foe_id := int(shot.get("uid", -1))
				if not by_uid.has(foe_id):
					continue
				var foe: Dictionary = by_uid[foe_id]
				_flat_hit(u, foe, int(float(shot.get("damage", 0)) * float(spec.get("per", 0.15)) * float(orbits)), action, deaths)
				for _d in range(int(spec.get("dispel", 2))):
					if _dispel_buff(foe) == "":
						break


func _spirit_round() -> void:
	var players := _alive_units("player")
	if players.is_empty():
		return
	spirit = mini(SpiritPool.MAX_SPIRIT, spirit + SpiritPool.ROUND_GAIN)
	var heals: Array = []
	for u in players:
		var passive: Dictionary = u.get("passive", {})
		var pid := str(passive.get("id", ""))
		if pid == "tide":
			var h := _heal(u, int(float(u["max_hp"]) * 0.04))
			if int(h["amount"]) > 0:
				heals.append(h)
		elif pid == "mend":
			var ally := _lowest_ally(u)
			if not ally.is_empty():
				var h2 := _powered_heal(u, ally, int(float(ally["max_hp"]) * 0.05))
				if int(h2["amount"]) > 0:
					heals.append(h2)
		elif pid == "shell" and rounds == 1 and not bool(u.get("shell_used", false)):
			u["shell_used"] = true
			var shell := _powered_shield(u, u, int(float(u["max_hp"]) * 0.08))
			events.append({"t": "action", "actor": int(u["uid"]), "side": "player", "slot": "spirit", "skill_name": "岩壳",
				"targets": [], "heals": [], "shields": [shell], "statuses": [], "text": "%s 撑起岩壳。" % u["name"]})
	events.append({"t": "spirit", "spirit": spirit, "gain": SpiritPool.ROUND_GAIN, "heals": heals,
		"text": "灵力回复 %d，当前 %d。" % [SpiritPool.ROUND_GAIN, spirit]})


func _take_spirit_turn(u: Dictionary) -> void:
	var forced := str(u.get("forced_slot", ""))
	u.erase("forced_slot")
	var index := _spirit_auto_index(u)
	if forced.begins_with("a"):
		index = int(forced.substr(1))
	var arts: Array = u.get("arts", [])
	if index < 0 or index >= arts.size() or _spirit_price(u, arts[index]) > spirit:
		index = _spirit_free_index(arts)
	if index < 0 or index >= arts.size() or _spirit_price(u, arts[index]) > spirit:
		events.append({"t": "log", "text": "%s 灵力不足，无法行动。" % u["name"]})
		return
	var art: Dictionary = arts[index]
	var price := _spirit_price(u, art)
	spirit -= price
	var dumped := 0
	if (art.get("effects", []) as Array).has("dump"):
		dumped = spirit
		spirit = 0
	_cast_spirit(u, art, dumped)
	u.erase("forced_uid")
	var back := 0
	var bonus := 0
	if str(u.get("class", "")) == "support":
		for eid in art.get("effects", []):
			back += SpiritPool.spirit_gain(str(eid))
		if back > 0:
			bonus = _support_spirit_bonus(u)
			back += bonus
	if back > 0:
		spirit = mini(SpiritPool.MAX_SPIRIT, spirit + back)
	var spirit_text := "灵力剩余 %d。" % spirit
	if bonus > 0:
		spirit_text = "灵力剩余 %d（辅助加成 +%d）。" % [spirit, bonus]
	events.append({"t": "spirit", "spirit": spirit, "text": spirit_text})


func _support_spirit_bonus(u: Dictionary) -> int:
	match str(u.get("rarity", "")):
		"epic":
			return 1
		"legend":
			return 2
		"hero":
			return 3
		_:
			return 0


func _spirit_price(u: Dictionary, art: Dictionary) -> int:
	var role := str(art.get("role", "basic"))
	var cut := _slot_affix_count(u, role, "spirit_cut")
	return maxi(0, SpiritPool.cost_of(art) - cut)


func _spirit_free_index(arts: Array) -> int:
	for i in arts.size():
		if SpiritPool.cost_of(arts[i]) == 0:
			return i
	return -1


func _spirit_auto_index(u: Dictionary) -> int:
	var arts: Array = u.get("arts", [])
	var cls := str(u.get("class", ""))
	if cls == "support" or cls == "guardian":
		for i in arts.size():
			var art: Dictionary = arts[i]
			if str(art.get("role", "")) != "aid":
				continue
			if _spirit_price(u, art) <= spirit:
				return i
	var best := _spirit_free_index(arts)
	var best_cost := -1
	for i in arts.size():
		var art: Dictionary = arts[i]
		var price := _spirit_price(u, art)
		if price > spirit or price < best_cost:
			continue
		if not _spirit_hostile(art) and best_cost >= 0:
			continue
		best = i
		best_cost = price
	return best


func _spirit_needs_target(u: Dictionary, slot: String) -> bool:
	var art := _spirit_art(u, slot)
	if art.is_empty() or not _spirit_hostile(art):
		return false
	return not (art.get("effects", []) as Array).has("aoe")


func _spirit_art(u: Dictionary, slot: String) -> Dictionary:
	var index := int(slot.substr(1)) if slot.begins_with("a") else -1
	var arts: Array = u.get("arts", [])
	if index < 0 or index >= arts.size():
		return {}
	return arts[index]


func _fx(effects: Array, id: String) -> int:
	return SpiritPool.stack_count(effects, id)


func _spirit_hostile(art: Dictionary) -> bool:
	for eid in art.get("effects", []):
		if str(eid) in ["hit", "heavy", "dump", "atk_down", "def_down", "burn", "slow", "stun", "splash", "taunt", "focus", "expose", "leech", "pierce", "keen", "reap", "rear", "seal", "blind", "lock", "wither"]:
			return true
	return false


func _cast_spirit(u: Dictionary, art: Dictionary, dumped: int) -> void:
	var effects: Array = art.get("effects", [])
	var action := _new_action(u, "spirit", str(art.get("name", "技能")))
	var deaths: Array = []
	var affix_slot := str(art.get("role", "basic"))
	if affix_slot not in ["basic", "aid", "ult"]:
		affix_slot = "basic"
	var extra_pierce := minf(0.9, 0.30 * float(_fx(effects, "pierce")))
	var extra_crit := 0.25 * float(_fx(effects, "keen"))
	var passive: Dictionary = u.get("passive", {})
	if _spirit_hostile(art):
		var mult := float(art.get("mult", 1.0))
		mult += 0.35 * float(_fx(effects, "heavy"))
		if str(passive.get("id", "")) == "edge":
			mult *= 1.12
		var dump_n := maxi(1, _fx(effects, "dump"))
		mult *= 1.0 + 0.25 * float(dump_n) * float(dumped)
		if effects.has("aoe"):
			mult *= minf(1.0, 0.6 + 0.1 * float(_fx(effects, "aoe")))
		mult += 0.20 * float(_fx(effects, "focus"))
		mult += 0.20 * float(_fx(effects, "rear"))
		mult += 0.15 * float(_fx(effects, "splash"))
		var targets: Array = []
		if effects.has("aoe"):
			targets = _opponents(str(u["side"]))
		else:
			var one := _consume_pick(u)
			if one.is_empty():
				if effects.has("focus"):
					one = _lowest_foe(u)
				elif effects.has("rear"):
					one = _back_target(u)
				else:
					one = _normal_target(u)
			if not one.is_empty():
				targets.append(one)
		var total := 0
		var first_name := ""
		var splashed := false
		var first_hit := true
		for target in targets:
			if int(target.get("hp", 0)) <= 0:
				continue
			var hit_mult := mult
			var reap_n := _fx(effects, "reap")
			if reap_n > 0 and _hp_ratio(target) < 0.40:
				hit_mult += 0.40 * float(reap_n)
			var info := _calc_damage(u, target, hit_mult, affix_slot, extra_crit, extra_pierce)
			var entry := _deal_damage(u, target, int(info["amount"]), bool(info["crit"]), float(info["element"]), true)
			action["targets"].append(entry)
			total += int(entry["damage"])
			if first_name == "":
				first_name = str(target.get("name", ""))
			if entry["dead"]:
				deaths.append(entry["uid"])
			_stamp_mark(u, target, action)
			_spirit_rider(u, target, effects, action)
			var leech_n := _fx(effects, "leech")
			if leech_n > 0:
				var leech := _heal(u, maxi(1, int(float(entry["damage"]) * 0.20 * float(leech_n))))
				if int(leech["amount"]) > 0:
					action["heals"].append(leech)
			_apply_on_hit_affixes(u, target, affix_slot, int(entry["damage"]), action, first_hit, deaths, true, first_hit)
			first_hit = false
			if effects.has("splash") and not splashed:
				splashed = true
				for foe in _opponents(str(u["side"])):
					if int(foe.get("uid", -1)) == int(target.get("uid", -2)) or int(foe.get("hp", 0)) <= 0:
						continue
					var splash := _deal_damage(u, foe, maxi(1, int(float(entry["damage"]) * 0.25 * float(maxi(1, _fx(effects, "splash"))))), false, 1.0, false)
					action["targets"].append(splash)
					total += int(splash["damage"])
					if splash["dead"]:
						deaths.append(splash["uid"])
		if targets.size() > 1:
			action["text"] = "%s 使用【%s】横扫，共造成 %d 伤害。" % [u["name"], action["skill_name"], total]
		elif first_name != "":
			action["text"] = "%s 使用【%s】攻击 %s，造成 %d 伤害。" % [u["name"], action["skill_name"], first_name, total]
		else:
			action["text"] = "%s 使用【%s】。" % [u["name"], action["skill_name"]]
	else:
		action["text"] = "%s 使用【%s】。" % [u["name"], action["skill_name"]]
		_apply_on_hit_affixes(u, u, affix_slot, 0, action, false, deaths, false, true)
	var sprint_n := _fx(effects, "sprint")
	if sprint_n > 0:
		_apply_status(u, "haste", 2, 0.25 * float(sprint_n))
		action["statuses"].append({"uid": int(u["uid"]), "status": "haste", "dur": 2, "pct": 0.25 * float(sprint_n)})
	var guard_n := _fx(effects, "guard")
	if guard_n > 0:
		_apply_status(u, "def_up", 2, 0.25 * float(guard_n))
		action["statuses"].append({"uid": int(u["uid"]), "status": "def_up", "dur": 2, "pct": 0.25 * float(guard_n)})
	var rally_n := _fx(effects, "rally")
	if rally_n > 0:
		for ally in _alive_units(str(u["side"])):
			_apply_status(ally, "atk_up", 2, 0.12 * float(rally_n))
			action["statuses"].append({"uid": int(ally["uid"]), "status": "atk_up", "dur": 2, "pct": 0.12 * float(rally_n)})
	for _i in _fx(effects, "purge"):
		if _cleanse_one(u) == "":
			break
	var barb_n := _fx(effects, "barb")
	if barb_n > 0:
		_apply_status(u, "thorns", 2, 0.20 * float(barb_n))
		action["statuses"].append({"uid": int(u["uid"]), "status": "thorns", "dur": 2, "pct": 0.20 * float(barb_n)})
	var empower_n := _fx(effects, "empower")
	if empower_n > 0:
		_apply_status(u, "atk_up", 2, 0.20 * float(empower_n))
		action["statuses"].append({"uid": int(u["uid"]), "status": "atk_up", "dur": 2, "pct": 0.20 * float(empower_n)})
	var mend_n := _fx(effects, "mend")
	if mend_n > 0:
		var self_heal := _heal(u, int(float(u["max_hp"]) * 0.08 * float(mend_n)))
		if int(self_heal["amount"]) > 0:
			action["heals"].append(self_heal)
	var cover_n := _fx(effects, "cover")
	var haste_n := _fx(effects, "aid_haste")
	if cover_n > 0 or haste_n > 0:
		var covered := _lowest_ally(u)
		if not covered.is_empty():
			if cover_n > 0:
				action["shields"].append(_powered_shield(u, covered, int(float(covered["max_hp"]) * 0.08 * float(cover_n))))
			if haste_n > 0:
				_apply_status(covered, "haste", 2, 0.20 * float(haste_n))
				action["statuses"].append({"uid": int(covered["uid"]), "status": "haste", "dur": 2, "pct": 0.20 * float(haste_n)})
	var heal_n := _fx(effects, "heal")
	if heal_n > 0:
		var ally := _lowest_ally(u)
		if not ally.is_empty():
			var h := _powered_heal(u, ally, int(float(ally["max_hp"]) * 0.12 * float(heal_n)))
			if int(h["amount"]) > 0:
				action["heals"].append(h)
	var shield_n := _fx(effects, "shield")
	if shield_n > 0:
		action["shields"].append(_powered_shield(u, u, int(float(u["max_hp"]) * 0.10 * float(shield_n))))
	var taunt_n := _fx(effects, "taunt")
	if taunt_n > 0:
		var taunt_dur := mini(4, taunt_n + 1)
		_apply_status(u, "taunt", taunt_dur)
		action["statuses"].append({"uid": int(u["uid"]), "status": "taunt", "dur": taunt_dur})
	if dumped > 0:
		action["text"] += " 倾泻了 %d 点灵力。" % dumped
	_emit_action(action, deaths, [])


func _spirit_rider(u: Dictionary, target: Dictionary, effects: Array, action: Dictionary) -> void:
	var passive: Dictionary = u.get("passive", {})
	var burn_n := maxi(_fx(effects, "burn"), 1 if str(passive.get("id", "")) == "fire" else 0)
	if burn_n > 0 and (_fx(effects, "burn") > 0 or str(passive.get("id", "")) == "fire"):
		var burn := maxi(1, int(float(u["atk"]) * 0.08 * float(maxi(1, _fx(effects, "burn")))))
		_apply_status(target, "burn", 2, 0.0, float(burn))
		action["statuses"].append({"uid": int(target["uid"]), "status": "burn", "dur": 2})
	var slow_n := _fx(effects, "slow")
	if slow_n > 0 or str(passive.get("id", "")) == "chill":
		_apply_status(target, "slow", 2, 0.2 * float(maxi(1, slow_n)))
		action["statuses"].append({"uid": int(target["uid"]), "status": "slow", "dur": 2})
	var atk_n := _fx(effects, "atk_down")
	if atk_n > 0 or str(passive.get("id", "")) == "pressure":
		_apply_status(target, "atk_down", 2, 0.15 * float(maxi(1, atk_n)))
		action["statuses"].append({"uid": int(target["uid"]), "status": "atk_down", "dur": 2})
	var def_n := _fx(effects, "def_down")
	if def_n > 0:
		_apply_status(target, "def_down", 2, 0.15 * float(def_n))
		action["statuses"].append({"uid": int(target["uid"]), "status": "def_down", "dur": 2})
	var stun_n := _fx(effects, "stun")
	if stun_n > 0 and rng.randf() < minf(0.95, 0.35 * float(stun_n)):
		_apply_status(target, "stun", 1)
		action["statuses"].append({"uid": int(target["uid"]), "status": "stun", "dur": 1})
	var expose_n := _fx(effects, "expose")
	if expose_n > 0:
		_apply_status(target, "vulnerable", 2, 0.18 * float(expose_n))
		action["statuses"].append({"uid": int(target["uid"]), "status": "vulnerable", "dur": 2, "pct": 0.18 * float(expose_n)})
	var seal_n := _fx(effects, "seal")
	if seal_n > 0 and rng.randf() < minf(0.85, 0.40 * float(seal_n)):
		_apply_status(target, "ult_seal", seal_n)
		action["statuses"].append({"uid": int(target["uid"]), "status": "ult_seal", "dur": seal_n})
	var blind_n := _fx(effects, "blind")
	if blind_n > 0 and rng.randf() < minf(0.90, 0.45 * float(blind_n)):
		_apply_status(target, "nocrit", 2)
		action["statuses"].append({"uid": int(target["uid"]), "status": "nocrit", "dur": 2})
	var lock_n := _fx(effects, "lock")
	if lock_n > 0 and rng.randf() < minf(0.90, 0.45 * float(lock_n)):
		_apply_status(target, "lock", 2)
		action["statuses"].append({"uid": int(target["uid"]), "status": "lock", "dur": 2})
	var wither_n := _fx(effects, "wither")
	if wither_n > 0:
		_apply_status(target, "wither", 2, minf(0.9, 0.40 * float(wither_n)))
		action["statuses"].append({"uid": int(target["uid"]), "status": "wither", "dur": 2, "pct": minf(0.9, 0.40 * float(wither_n))})
