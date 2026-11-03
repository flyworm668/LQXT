extends RefCounted
## Player skill pool. Cost is one less than the number of effects.
## A single effect is the old basic attack and costs nothing.

const MAX_SPIRIT := 30
const ROUND_GAIN := 6
const MAX_ARTS := 3
const MAX_EFFECTS := 10
const MAX_STACK := 3

const EFFECTS := {
	"hit": {"name": "命中", "text": "按倍率造成伤害"},
	"atk_down": {"name": "卸势", "text": "压低目标攻击"},
	"def_down": {"name": "卸甲", "text": "压低目标防御"},
	"burn": {"name": "火种", "text": "留下灼烧"},
	"slow": {"name": "滞步", "text": "压低目标速度"},
	"stun": {"name": "定身", "text": "有机会眩晕一回合，叠层提高概率"},
	"shield": {"name": "结界", "text": "为自己套一层护盾"},
	"heal": {"name": "疗愈", "text": "治疗最残的队友"},
	"spirit1": {"name": "回灵", "text": "回复 1 点灵力"},
	"spirit2": {"name": "聚灵", "text": "回复 2 点灵力"},
	"spirit3": {"name": "涌灵", "text": "回复 3 点灵力"},
	"spirit4": {"name": "潮灵", "text": "回复 4 点灵力"},
	"heavy": {"name": "重击", "text": "这招倍率提高"},
	"splash": {"name": "波及", "text": "伤害带到其他敌人，叠层提高伤害"},
	"aoe": {"name": "横扫", "text": "改为攻击全体，倍率降低"},
	"taunt": {"name": "挑衅", "text": "迫使敌人攻击自己"},
	"dump": {"name": "倾泻", "text": "打完剩余灵力，每点额外提高伤害"},
	"focus": {"name": "锁定", "text": "改为攻击生命最低的敌人，叠层提高伤害"},
	"expose": {"name": "破绽", "text": "让目标更容易受伤"},
	"leech": {"name": "嗜血", "text": "按造成的伤害回复生命"},
	"pierce": {"name": "洞穿", "text": "这次攻击无视部分防御"},
	"sprint": {"name": "疾行", "text": "自己速度提高"},
	"guard": {"name": "固守", "text": "自己防御提高"},
	"rally": {"name": "号令", "text": "提高友方攻击"},
	"purge": {"name": "净心", "text": "清除自己一个负面状态"},
	"keen": {"name": "会心", "text": "这一击更容易暴击"},
	"reap": {"name": "收割", "text": "目标残血时伤害提高"},
	"rear": {"name": "袭后", "text": "改为攻击后排，叠层提高伤害"},
	"seal": {"name": "封招", "text": "有机会封印目标的大招，叠层提高概率"},
	"blind": {"name": "失准", "text": "有机会使目标无法暴击，叠层提高概率"},
	"lock": {"name": "禁迅", "text": "有机会使目标不能加速，叠层提高概率"},
	"wither": {"name": "枯萎", "text": "目标暂时受到的治疗降低"},
	"barb": {"name": "反刺", "text": "自己短时间反弹伤害"},
	"empower": {"name": "蓄力", "text": "自己攻击提高"},
	"mend": {"name": "回春", "text": "治疗自己"},
	"cover": {"name": "庇护", "text": "给最残的队友一层护盾"},
	"aid_haste": {"name": "疾援", "text": "让最残的队友加速"},
}

const OFFERS := [
	{"id": "atk_down", "rank": 0},
	{"id": "focus", "rank": 0},
	{"id": "rear", "rank": 0},
	{"id": "keen", "rank": 0},
	{"id": "sprint", "rank": 0},
	{"id": "empower", "rank": 0},
	{"id": "mend", "rank": 0},
	{"id": "barb", "rank": 0},
	{"id": "heavy", "rank": 0, "classes": ["warrior", "assassin"]},
	{"id": "shield", "rank": 0, "classes": ["guardian", "support"]},
	{"id": "guard", "rank": 0, "classes": ["guardian", "warrior"]},
	{"id": "heal", "rank": 0, "classes": ["support"], "elements": ["grass", "water", "light"]},
	{"id": "spirit1", "rank": 0, "classes": ["support"]},
	{"id": "purge", "rank": 0, "classes": ["support", "mage"]},
	{"id": "burn", "rank": 1, "elements": ["fire"]},
	{"id": "slow", "rank": 1, "elements": ["water", "electric", "ice"]},
	{"id": "expose", "rank": 1},
	{"id": "reap", "rank": 1},
	{"id": "seal", "rank": 1},
	{"id": "blind", "rank": 1},
	{"id": "wither", "rank": 1, "classes": ["support", "mage"]},
	{"id": "cover", "rank": 1, "classes": ["guardian", "support"]},
	{"id": "aid_haste", "rank": 1, "classes": ["support"]},
	{"id": "lock", "rank": 1, "elements": ["electric", "ice", "water"]},
	{"id": "leech", "rank": 1, "classes": ["warrior", "assassin", "support"]},
	{"id": "def_down", "rank": 1, "classes": ["warrior", "guardian"]},
	{"id": "aoe", "rank": 1, "classes": ["mage", "archer"]},
	{"id": "spirit2", "rank": 1, "classes": ["support"]},
	{"id": "splash", "rank": 2, "classes": ["warrior", "mage"]},
	{"id": "stun", "rank": 2, "classes": ["warrior", "guardian"]},
	{"id": "taunt", "rank": 2, "classes": ["guardian"]},
	{"id": "rally", "rank": 2, "classes": ["support", "warrior"]},
	{"id": "pierce", "rank": 2, "classes": ["assassin", "archer", "mage"]},
	{"id": "dump", "rank": 2},
	{"id": "spirit3", "rank": 2, "classes": ["support"]},
	{"id": "spirit4", "rank": 3, "classes": ["support"]},
]


static func rank_of(rarity: String) -> int:
	match rarity:
		"rare":
			return 1
		"epic":
			return 2
		"legend":
			return 3
		"hero", "demon":
			return 4
		_:
			return 0


static func cost_of(art: Dictionary) -> int:
	var effects: Array = art.get("effects", [])
	return maxi(0, effects.size() - 1)


static func effect_name(eid: String) -> String:
	var row: Dictionary = EFFECTS.get(eid, {})
	return str(row.get("name", eid))


static func effect_text(eid: String) -> String:
	var row: Dictionary = EFFECTS.get(eid, {})
	return str(row.get("text", ""))


static func rarity_step(rarity: String, hero: bool = false) -> int:
	if rarity == "demon":
		return 5
	if hero or rarity == "hero":
		return 4
	match rarity:
		"legend":
			return 3
		"epic":
			return 2
		"rare":
			return 1
		_:
			return 0


static func add_cap(pet_class: String, role: String, rarity: String, hero: bool = false) -> int:
	if role == "aid":
		return 2
	if role == "basic" and pet_class == "support":
		return 2 + rarity_step(rarity, hero)
	if role == "basic":
		return 1
	return effect_cap(rarity, hero)


static func effect_cap(rarity: String, hero: bool = false) -> int:
	if rarity == "demon":
		return 10
	if hero or rarity == "hero":
		return 9
	match rarity:
		"legend":
			return 7
		"epic":
			return 6
		"rare":
			return 4
		_:
			return 3


static func stack_count(effects: Array, effect_id: String) -> int:
	var count := 0
	for eid in effects:
		if str(eid) == effect_id:
			count += 1
	return count


static func art_text(art: Dictionary) -> String:
	var parts: Array = []
	var seen: Array = []
	for eid in art.get("effects", []):
		var key := str(eid)
		if key == "hit" or seen.has(key):
			continue
		seen.append(key)
		var n := stack_count(art.get("effects", []), key)
		var label := effect_name(key)
		if n > 1:
			label += "×%d" % n
		parts.append(label)
	var body := "只造成伤害" if parts.is_empty() else "、".join(parts)
	return "%s · %s · %d 灵力 · 技能效果：%s" % [role_name(str(art.get("role", "basic"))), str(art.get("name", "技能")), cost_of(art), body]


static func role_name(role: String) -> String:
	match role:
		"aid":
			return "辅助"
		"ult":
			return "大招"
		_:
			return "普通"


static func starter_arts(pet: Dictionary) -> Array:
	var skills: Dictionary = pet.get("skills", {})
	var normal: Dictionary = skills.get("normal", {})
	var ult: Dictionary = skills.get("ultimate", {})
	var pet_class := str(pet.get("class", "warrior"))
	var element := str(pet.get("element", "fire"))
	var basic := {
		"role": "basic",
		"name": str(normal.get("name", "直击")),
		"effects": ["hit"],
		"mult": float(normal.get("mult", 1.0)),
		"target": str(normal.get("target", "front")),
	}
	var aid_name := "破阵"
	var aid_effects := ["hit", "atk_down"]
	match pet_class:
		"support":
			aid_name = "灵愈"
			aid_effects = ["heal", "spirit3"]
		"guardian":
			aid_name = "坚守"
			aid_effects = ["hit", "shield"]
		"mage":
			aid_name = "咏咒"
			aid_effects = ["hit", _element_rider(element)]
		"archer":
			aid_name = "牵制"
			aid_effects = ["hit", "slow"]
	var aid := {
		"role": "aid",
		"name": aid_name,
		"effects": aid_effects,
		"mult": float(normal.get("mult", 1.0)),
		"target": "front",
	}
	var ult_effects := ["hit", "heavy", _element_rider(element)]
	match pet_class:
		"support":
			ult_effects = ["heal", "spirit4", "cover", "rally"]
		"guardian":
			ult_effects.append("taunt")
		"mage", "archer":
			ult_effects.append("aoe")
		_:
			ult_effects.append("splash")
	var cap := effect_cap(str(pet.get("rarity", "common")), str(pet.get("rarity", "")) == "hero")
	if pet_class != "support":
		ult_effects = _fill_effects(ult_effects, mini(4, cap))
	while ult_effects.size() > cap:
		ult_effects.pop_back()
	return [basic, aid, {
		"role": "ult",
		"name": str(ult.get("name", "崩击")),
		"effects": ult_effects,
		"mult": float(ult.get("mult", 2.0)),
		"target": str(ult.get("target", "front")),
	}]


static func _element_rider(element: String) -> String:
	match element:
		"fire":
			return "burn"
		"water", "electric", "ice":
			return "slow"
		"rock", "steel":
			return "def_down"
		_:
			return "atk_down"


static func _fill_effects(effects: Array, want: int) -> Array:
	var out: Array = []
	for eid in effects:
		if not out.has(eid):
			out.append(eid)
	for extra in ["atk_down", "def_down", "heavy"]:
		if out.size() >= want:
			break
		if not out.has(extra):
			out.append(extra)
	return out


static func passive_for(pet: Dictionary) -> Dictionary:
	if rank_of(str(pet.get("rarity", "common"))) < 2:
		return {}
	var element := str(pet.get("element", "fire"))
	var pet_class := str(pet.get("class", "warrior"))
	var pid := element
	var name := "余烬"
	var text := "造成伤害时附加轻微灼烧。"
	if element == "water" or element == "grass":
		pid = "tide"
		name = "潮息"
		text = "每回合开始回复少量生命。"
	elif element == "light" or pet_class == "support":
		pid = "mend"
		name = "照拂"
		text = "每回合开始治疗最残的队友。"
	elif element == "electric" or element == "ice":
		pid = "chill"
		name = "滞足"
		text = "造成伤害时降低目标速度。"
	elif element == "rock" or element == "steel" or pet_class == "guardian":
		pid = "shell"
		name = "岩壳"
		text = "开战时获得一层护盾。"
	elif element == "dark" or element == "ghost":
		pid = "pressure"
		name = "威压"
		text = "造成伤害时降低目标攻击。"
	elif pet_class == "warrior" or pet_class == "assassin" or element == "dragon":
		pid = "edge"
		name = "锋芒"
		text = "自己的技能伤害提高。"
	return {"id": pid, "name": name, "text": text}


static func offers_for(pet: Dictionary, salt: int) -> Array:
	var rarity := rank_of(str(pet.get("rarity", "common")))
	var element := str(pet.get("element", ""))
	var pet_class := str(pet.get("class", ""))
	var pool: Array = []
	for row in OFFERS:
		if rarity < int(row.get("rank", 0)):
			continue
		var elements: Array = row.get("elements", [])
		var classes: Array = row.get("classes", [])
		var element_ok := elements.is_empty() or elements.has(element)
		var class_ok := classes.is_empty() or classes.has(pet_class)
		if elements.is_empty() and classes.is_empty():
			pool.append(row)
		elif element_ok and class_ok:
			pool.append(row)
		elif element_ok and classes.is_empty():
			pool.append(row)
		elif class_ok and elements.is_empty():
			pool.append(row)
	if pool.is_empty():
		pool.append(OFFERS[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var out: Array = []
	var guard := 0
	while out.size() < mini(5, pool.size()) and guard < 30:
		guard += 1
		var pick: Dictionary = pool[rng.randi() % pool.size()]
		var seen := false
		for have in out:
			if str(have.get("id", "")) == str(pick.get("id", "")):
				seen = true
		if not seen:
			out.append(pick)
	return out


static func spirit_gain(eid: String) -> int:
	match eid:
		"spirit1":
			return 1
		"spirit2":
			return 2
		"spirit3":
			return 3
		"spirit4":
			return 4
		_:
			return 0
