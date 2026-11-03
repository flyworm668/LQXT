# -*- coding: utf-8 -*-
"""Canonical game content for 灵契·星塔远征.

All names, art and numbers in this project are original.  The game is a
mechanical homage to the classic pet-collecting tower climbers of the 2010s,
not a copy of any existing title's assets or data.
"""
import hashlib

# 17 types, single-type, chart matches the classic table (no Fairy).
# Only non-1.0 matchups are listed.  2 = super effective, 0.5 = resisted, 0 = immune.
TYPE_CHART = {
    "normal":   {"rock": 0.5, "ghost": 0, "steel": 0.5},
    "fire":     {"fire": 0.5, "water": 0.5, "grass": 2, "ice": 2, "bug": 2, "rock": 0.5, "dragon": 0.5, "steel": 2},
    "water":    {"fire": 2, "water": 0.5, "grass": 0.5, "ground": 2, "rock": 2, "dragon": 0.5},
    "electric": {"water": 2, "electric": 0.5, "grass": 0.5, "ground": 0, "flying": 2, "dragon": 0.5},
    "grass":    {"fire": 0.5, "water": 2, "grass": 0.5, "poison": 0.5, "ground": 2, "flying": 0.5, "bug": 0.5, "rock": 2, "dragon": 0.5, "steel": 0.5},
    "ice":      {"fire": 0.5, "water": 0.5, "grass": 2, "ice": 0.5, "ground": 2, "flying": 2, "dragon": 2, "steel": 0.5},
    "fighting": {"normal": 2, "ice": 2, "poison": 0.5, "flying": 0.5, "psychic": 0.5, "bug": 0.5, "rock": 2, "ghost": 0, "dark": 2, "steel": 2},
    "poison":   {"grass": 2, "poison": 0.5, "ground": 0.5, "rock": 0.5, "ghost": 0.5, "steel": 0},
    "ground":   {"fire": 2, "electric": 2, "grass": 0.5, "poison": 2, "flying": 0, "bug": 0.5, "rock": 2, "steel": 2},
    "flying":   {"electric": 0.5, "grass": 2, "fighting": 2, "bug": 2, "rock": 0.5, "steel": 0.5},
    "psychic":  {"fighting": 2, "poison": 2, "psychic": 0.5, "dark": 0, "steel": 0.5},
    "bug":      {"fire": 0.5, "grass": 2, "fighting": 0.5, "poison": 0.5, "flying": 0.5, "psychic": 2, "ghost": 0.5, "dark": 2, "steel": 0.5},
    "rock":     {"fire": 2, "ice": 2, "fighting": 0.5, "ground": 0.5, "flying": 2, "bug": 2, "steel": 0.5},
    "ghost":    {"normal": 0, "psychic": 2, "ghost": 2, "dark": 0.5},
    "dragon":   {"dragon": 2, "steel": 0.5},
    "dark":     {"fighting": 0.5, "psychic": 2, "ghost": 2, "dark": 0.5},
    "steel":    {"fire": 0.5, "water": 0.5, "electric": 0.5, "ice": 2, "rock": 2, "steel": 0.5},
}

ELEMENT_META = {
    "normal":   ("一般", "#b9c4d8"),
    "fire":     ("火", "#ff7043"),
    "water":    ("水", "#41a6ff"),
    "electric": ("电", "#f5d76e"),
    "grass":    ("草", "#7dce6a"),
    "ice":      ("冰", "#9fd7ff"),
    "fighting": ("格斗", "#e07050"),
    "poison":   ("毒", "#b06ad4"),
    "ground":   ("地面", "#d9a94c"),
    "flying":   ("飞行", "#8fd0c8"),
    "psychic":  ("超能", "#ff8fb8"),
    "bug":      ("虫", "#b6c44a"),
    "rock":     ("岩石", "#b08a62"),
    "ghost":    ("幽灵", "#8a6ad4"),
    "dragon":   ("龙", "#6a7dff"),
    "dark":     ("恶", "#6d6480"),
    "steel":    ("钢", "#b9c6d6"),
}


def _elements_from_chart():
    elements = {}
    for eid, (name, color) in ELEMENT_META.items():
        row = TYPE_CHART.get(eid, {})
        elements[eid] = {
            "name": name,
            "color": color,
            "beats": [k for k, v in row.items() if v >= 2],
            "loses_to": [k for k, v in row.items() if 0 < v < 1],
            "immune": [k for k, v in row.items() if v == 0],
            "mutual": [],
        }
    return elements


ELEMENTS = _elements_from_chart()

CLASSES = {
    "guardian": {"name": "坦克", "color": "#8fd0ff", "hp": 1160, "atk": 86,  "def": 96, "spd": 84,
                 "role": "前排承伤，开出护盾", "target": "front"},
    "warrior":  {"name": "战士", "color": "#ff9a62", "hp": 980,  "atk": 116, "def": 70, "spd": 100,
                 "role": "前排输出，破军重击", "target": "front"},
    "mage":     {"name": "法师", "color": "#c98bff", "hp": 770,  "atk": 136, "def": 46, "spd": 106,
                 "role": "后排法伤，元素风暴", "target": "back"},
    "archer":   {"name": "射手", "color": "#6ee7b7", "hp": 800,  "atk": 126, "def": 50, "spd": 121,
                 "role": "高速狙击，收割残血", "target": "lowest"},
    "support":  {"name": "辅助", "color": "#ffd166", "hp": 910,  "atk": 88,  "def": 62, "spd": 111,
                 "role": "治疗与增益，团队核心", "target": "front"},
}

# name, element, class, rarity.  18 common / 14 rare / 9 epic / 6 legend / 3 hero.
# Starters are the epic fire / water / grass trio.
PET_SEEDS = [
    ("焰狐", "fire", "warrior", "epic"),
    ("赤雀", "fire", "archer", "rare"),
    ("熔岩獾", "ground", "guardian", "epic"),
    ("火绒猫", "normal", "support", "common"),
    ("烬狼", "fire", "warrior", "hero"),
    ("烈阳鹿", "dragon", "mage", "rare"),
    ("炎角犀", "dragon", "guardian", "epic"),
    ("焚羽鹰", "flying", "archer", "legend"),
    ("琥珀蜥", "steel", "mage", "rare"),
    ("水泡獭", "water", "support", "epic"),
    ("碧波豚", "water", "mage", "rare"),
    ("潮汐龟", "water", "guardian", "common"),
    ("珊瑚蟹", "steel", "guardian", "common"),
    ("霜鳍鲨", "ice", "warrior", "rare"),
    ("蓝鲸崽", "ice", "support", "common"),
    ("雾雨蛙", "poison", "mage", "rare"),
    ("涟漪鳗", "electric", "archer", "rare"),
    ("冰晶水母", "ice", "mage", "legend"),
    ("风铃鼠", "flying", "archer", "epic"),
    ("疾羽鸢", "flying", "archer", "rare"),
    ("云朵羊", "normal", "support", "common"),
    ("旋岚貂", "fighting", "warrior", "common"),
    ("惊雷燕", "electric", "mage", "legend"),
    ("青岚鹿", "electric", "support", "common"),
    ("蒲公英兔", "grass", "mage", "epic"),
    ("逐风狼", "rock", "warrior", "common"),
    ("岩壳龟", "rock", "guardian", "common"),
    ("泥土熊", "ground", "guardian", "common"),
    ("砂砾鼠", "ground", "archer", "common"),
    ("晶石蜥", "rock", "mage", "rare"),
    ("藤蔓蟒", "grass", "warrior", "common"),
    ("苔藓牛", "grass", "guardian", "common"),
    ("蘑菇蛙", "poison", "support", "common"),
    ("琥珀蚁", "bug", "archer", "common"),
    ("光羽雀", "psychic", "archer", "epic"),
    ("晨曦鹿", "psychic", "support", "rare"),
    ("圣辉猫", "fighting", "warrior", "rare"),
    ("日冕狮", "fighting", "warrior", "legend"),
    ("莹光蛾", "bug", "mage", "rare"),
    ("金铃羊", "normal", "support", "common"),
    ("星尘狐", "psychic", "mage", "hero"),
    ("白昼鸽", "steel", "archer", "common"),
    ("影刃豹", "dark", "warrior", "hero"),
    ("幽夜鸦", "ghost", "archer", "rare"),
    ("暮色蝠", "ghost", "mage", "epic"),
    ("暗焰犬", "dark", "warrior", "rare"),
    ("幻梦蛛", "poison", "support", "epic"),
    ("蚀月蛇", "dragon", "mage", "legend"),
    ("黑雾猫", "dark", "archer", "common"),
    ("夜巡枭", "ghost", "guardian", "legend"),
]

STARTER_IDS = ["p01", "p10", "p25"]  # 焰狐 / 水泡獭 / 蒲公英兔

RARITY_STAT = {
    "common": 1.00, "rare": 1.10, "epic": 1.22,
    "legend": 1.36, "hero": 1.50, "demon": 1.65,
}
CHEST_RARITY = {"common": 45, "rare": 25, "epic": 15, "legend": 10, "hero": 5}

EVO_STAGE = ["", "觉醒·", "王"]
SKILL_VERB = {
    "guardian": ("盾击", "壁垒"),
    "warrior": ("斩击", "破军"),
    "mage": ("弹", "风暴"),
    "archer": ("射击", "狙击"),
    "support": ("灵息", "赞歌"),
}
# What a type leaves behind after an ultimate.  The engine matches these riders.
ELEMENT_RIDER = {
    "fire": "burn", "water": "slow", "electric": "shock", "grass": "regen",
    "ice": "slow", "fighting": "atk_self", "poison": "poison", "ground": "def_down",
    "flying": "haste", "psychic": "shield", "bug": "slow", "rock": "def_down",
    "ghost": "atk_down", "dragon": "vulnerable", "dark": "atk_down",
    "steel": "def_down", "normal": "shield",
}
ELEMENT_ULT_TEXT = {
    "burn": "并附加灼烧", "slow": "并使其减速", "shock": "并附加感电",
    "regen": "并回复自身生命", "atk_self": "并提升自身攻击", "poison": "并附加中毒",
    "def_down": "并降低目标防御", "haste": "并提升自身速度", "shield": "并为友方附加护盾",
    "atk_down": "并降低目标攻击", "vulnerable": "并施加易伤",
}

SKILL_DESC = {
    "guardian": ("重盾猛击前排，自身获得少量护盾。", "击退前排目标，自身获得 12% 最大生命护盾，{extra}。"),
    "warrior": ("挥刃攻击敌方前排。", "对前排目标造成 2.15 倍重击，并溅射 25% 伤害至相邻敌人，{extra}。"),
    "mage": ("凝聚元素弹攻击敌方后排。", "对最多 3 名敌人造成 1.35 倍元素风暴，{extra}。"),
    "archer": ("射出一箭，优先攻击残血敌人。", "狙击生命最低的敌人，造成 2.0 倍伤害且暴击率 +25%，{extra}。"),
    "support": ("攻击前排，并为生命最低的友方回复少量生命。", "为全体友方回复 15% 最大生命并提升 10% 攻击，{extra}。"),
}


def _stat_var(pid: str) -> float:
    h = int(hashlib.md5(pid.encode("utf-8")).hexdigest()[:8], 16)
    return 0.94 + (h % 13) / 100.0


def _skill_pair(pid, name, element, cls):
    import pet_extras
    label = ELEMENT_META[element][0]
    rider = ELEMENT_RIDER[element]
    normal = {
        "id": f"n_{pid}",
        "name": label + SKILL_VERB[cls][0],
        "kind": "normal",
        "target": CLASSES[cls]["target"],
        "mult": 0.9 if cls in ("guardian", "support") else (0.95 if cls == "mage" else 1.0),
        "rider": rider,
        "desc": SKILL_DESC[cls][0],
    }
    extra = ELEMENT_ULT_TEXT[rider]
    signature = pet_extras.ULTS.get(name)
    ult_name = (signature["text"].split("，")[0][:8] if signature else label + SKILL_VERB[cls][1])
    if signature:
        ult_name = name[:2] + SKILL_VERB[cls][1]
        extra = signature["text"]
    ult = {
        "id": f"u_{pid}",
        "name": ult_name,
        "kind": "ult_" + cls,
        "target": CLASSES[cls]["target"],
        "mult": {"guardian": 1.8, "warrior": 2.15, "mage": 1.35, "archer": 2.0, "support": 0.0}[cls],
        "splash": 0.25 if cls == "warrior" else 0.0,
        "rider": rider,
        "desc": SKILL_DESC[cls][1].format(extra=extra),
    }
    if signature:
        ult["signature"] = signature
    return normal, ult


def make_pets():
    import pet_extras
    pets = []
    for i, (name, element, cls, rarity) in enumerate(PET_SEEDS, start=1):
        pid = f"p{i:02d}"
        var = _stat_var(pid)
        base = CLASSES[cls]
        stage_names = [name, "觉醒·" + name, name + "王"]
        normal, ult = _skill_pair(pid, name, element, cls)
        pet = {
            "id": pid,
            "names": stage_names,
            "element": element,
            "class": cls,
            "rarity": rarity,
            "starter": pid in STARTER_IDS,
            "stats": {
                "hp": round(base["hp"] * var),
                "atk": round(base["atk"] * var),
                "def": round(base["def"] * var),
                "spd": round(base["spd"] * var),
            },
            "skills": {"normal": normal, "ultimate": ult},
        }
        mark = pet_extras.MARKS.get(name)
        if mark:
            pet["mark"] = mark
        art = pet_extras.ART.get(name)
        if art:
            pet["art"] = dict(art)
            pet["art"]["aura"] = rarity
        pets.append(pet)
    return pets


def make_demons():
    import pet_extras
    demons = []
    for spec in pet_extras.DEMONS:
        element, cls = spec["element"], spec["class"]
        normal, ult = _skill_pair(spec["id"], spec["name"], element, cls)
        ult["signature"] = pet_extras.DEMON_ULTS[spec["id"]]
        ult["name"] = spec["name"].split("·")[0]
        demons.append({
            "id": spec["id"],
            "names": [spec["name"], spec["name"], spec["name"]],
            "name": spec["name"],
            "element": element,
            "class": cls,
            "rarity": "demon",
            "starter": False,
            "from_boss": spec["from_boss"],
            "stats": {
                "hp": round(CLASSES[cls]["hp"] * 1.05),
                "atk": round(CLASSES[cls]["atk"] * 1.05),
                "def": round(CLASSES[cls]["def"] * 1.05),
                "spd": round(CLASSES[cls]["spd"] * 1.05),
            },
            "mark": pet_extras.DEMON_MARKS[spec["id"]],
            "art": dict(pet_extras.DEMON_ART[spec["id"]], aura="demon"),
            "skills": {"normal": normal, "ultimate": ult},
        })
    return demons


AFFIXES = [
    {"id": "sharp",        "name": "锋锐",     "rarity": "common", "desc": "该技能伤害 +15%。", "value": 0.15},
    {"id": "drain",        "name": "汲取",     "rarity": "common", "desc": "回复该技能造成伤害的 25% 生命。", "value": 0.25},
    {"id": "armor_break",  "name": "破甲",     "rarity": "common", "desc": "使目标防御 -15%，持续 2 回合。", "value": 0.15},
    {"id": "splash",       "name": "溅射",     "rarity": "common", "desc": "对另一名敌人造成 30% 溅射伤害。", "value": 0.30},
    {"id": "haste",        "name": "迅捷",     "rarity": "common", "desc": "使用后自身速度 +20%，持续 2 回合。", "value": 0.20},
    {"id": "shield",       "name": "护盾",     "rarity": "common", "desc": "使用后获得 8% 最大生命护盾。", "value": 0.08},
    {"id": "cleanse",      "name": "净化",     "rarity": "common", "desc": "使用后清除自身 1 个负面状态。", "value": 1},
    {"id": "heal_ally",    "name": "恩泽",     "rarity": "common", "desc": "使用后治疗生命最低的友方 6% 最大生命。", "value": 0.06},
    {"id": "thorns",       "name": "荆棘",     "rarity": "common", "desc": "使用后获得 2 回合 15% 反伤。", "value": 0.15},
    {"id": "burn",         "name": "灼烧",     "rarity": "rare",   "desc": "命中后附加 2 回合灼烧，每回合造成 6% 攻击力伤害。", "value": 0.06},
    {"id": "frost",        "name": "冰封",     "rarity": "rare",   "desc": "20% 概率眩晕目标 1 回合。", "value": 0.20},
    {"id": "double",       "name": "连击",     "rarity": "rare",   "desc": "25% 概率追加一次 50% 伤害的攻击。", "value": 0.25},
    {"id": "crit",         "name": "致命",     "rarity": "rare",   "desc": "该技能暴击率 +20%。", "value": 0.20},
    {"id": "execute",      "name": "追击",     "rarity": "rare",   "desc": "对生命低于 35% 的目标伤害 +35%。", "value": 0.35},
    {"id": "vulnerability","name": "弱点",     "rarity": "rare",   "desc": "使目标受到伤害 +15%，持续 2 回合。", "value": 0.15},
    {"id": "war_cry",      "name": "战吼",     "rarity": "epic",   "desc": "使用后全体友方攻击 +10%，持续 2 回合。", "value": 0.10},
    {"id": "vamp_aura",    "name": "噬血光环", "rarity": "epic",   "desc": "使用后全体友方吸血 +8%，持续 2 回合。", "value": 0.08},
    {"id": "spirit_cut",   "name": "节灵",     "rarity": "epic",   "desc": "该技能灵力消耗 -1，最低为 0。", "value": 1},
    {"id": "miracle",      "name": "天命",     "rarity": "epic",   "desc": "2% 概率直接造成 99999 点伤害。不进入宝箱。", "value": 0.02, "pool": False},
    {"id": "rebound",      "name": "反震",     "rarity": "epic",   "desc": "使用后获得 1 回合，受到的伤害全部反弹。", "value": 1.0, "pool": False},
    {"id": "volley",       "name": "齐射",     "rarity": "epic",   "desc": "攻击有 20% 概率令其他友方一起攻击同一目标。", "value": 0.20, "pool": False},
    {"id": "aegis",        "name": "无伤",     "rarity": "epic",   "desc": "使用后获得 1 回合免疫伤害。", "value": 1.0, "pool": False},
    {"id": "still",        "name": "断势",     "rarity": "epic",   "desc": "攻击使目标气势归零，并锁定 1 回合。", "value": 1.0, "pool": False},
    {"id": "barrier_blade", "name": "破魔圣剑", "rarity": "epic",  "desc": "旧档里贴在技能上的圣剑仍然有效。新获得的圣剑是可携带道具。", "value": 1.0, "pool": False},
    {"id": "unbound",      "name": "无限",     "rarity": "epic",   "desc": "只能赋予开局选定的精灵：没有等级上限，技能词条可以无限叠加。", "value": 1.0, "pool": False},
]
RARITY_WEIGHT = {"common": 60, "rare": 30, "epic": 10}

ITEMS = [
    {"id": "hp_charm",       "name": "生命护符", "rarity": "common", "desc": "携带者最大生命 +12%。", "stat": "hp", "value": 0.12},
    {"id": "atk_charm",      "name": "力量护符", "rarity": "common", "desc": "携带者攻击 +10%。", "stat": "atk", "value": 0.10},
    {"id": "def_charm",      "name": "铁壁护符", "rarity": "common", "desc": "携带者防御 +15%。", "stat": "def", "value": 0.15},
    {"id": "spd_boots",      "name": "疾风之靴", "rarity": "common", "desc": "携带者速度 +10%。", "stat": "spd", "value": 0.10},
    {"id": "vampire_fang",   "name": "吸血獠牙", "rarity": "rare",   "desc": "携带者攻击吸血 +10%。", "hook": "lifesteal", "value": 0.10},
    {"id": "crit_eye",       "name": "暴击之瞳", "rarity": "rare",   "desc": "携带者暴击率 +10%。", "hook": "crit", "value": 0.10},
    {"id": "tide_pendant",   "name": "潮汐吊坠", "rarity": "rare",   "desc": "每回合开始，携带者回复 2% 最大生命。", "hook": "regen", "value": 0.02},
    {"id": "rage_amulet",    "name": "战意项链", "rarity": "common", "desc": "战斗开始，灵力 +1。最多持有 2 件。", "hook": "start_spirit", "value": 1, "max_stack": 2},
    {"id": "thorn_mail",     "name": "荆棘之甲", "rarity": "rare",   "desc": "受到攻击时反弹 12% 伤害。", "hook": "reflect", "value": 0.12},
    {"id": "phoenix_feather", "name": "不死羽",  "rarity": "epic",   "desc": "携带者一次：受到致死伤害后保留 1 点生命。", "hook": "last_stand", "value": 1},
    {"id": "giant_slayer",   "name": "屠龙徽记", "rarity": "rare",   "desc": "对首领与英雄造成的伤害 +25%。", "hook": "vs_boss", "value": 0.25},
    {"id": "arcane_core",    "name": "秘法核心", "rarity": "rare",   "desc": "大招伤害 +20%。", "hook": "ult_damage", "value": 0.20},
    {"id": "dual_strike",    "name": "双生指环", "rarity": "rare",   "desc": "普通攻击 20% 概率追加一次 50% 伤害。", "hook": "double_normal", "value": 0.20},
    {"id": "flame_heart",    "name": "烈焰之心", "rarity": "rare",   "desc": "攻击附加 2 回合灼烧（每回合 4% 攻击力）。", "hook": "burn_on_hit", "value": 0.04},
    {"id": "frost_heart",    "name": "寒冰之心", "rarity": "rare",   "desc": "攻击使目标速度 -10%，持续 2 回合。", "hook": "slow_on_hit", "value": 0.10},
    {"id": "hunter_mark",    "name": "猎手印记", "rarity": "rare",   "desc": "对生命低于 40% 的敌人伤害 +20%。", "hook": "execute", "value": 0.20},
    {"id": "guardian_angel", "name": "守护天使", "rarity": "rare",   "desc": "战斗开始时，携带者获得 8% 最大生命护盾。", "hook": "start_shield", "value": 0.08},
    {"id": "resonance_core", "name": "共鸣水晶", "rarity": "epic",   "desc": "重复精灵的共鸣加成 +50%。", "hook": "resonance", "value": 0.50},
    {"id": "lucky_coin",     "name": "幸运金币", "rarity": "rare",   "desc": "道具稀有度提升（更易开出稀有 / 史诗）。", "hook": "item_luck", "value": 0.35},
    {"id": "nourish_seed",   "name": "森林之种", "rarity": "common", "desc": "携带者防御 +8%，每回合回复 1.5% 最大生命。", "stat": "def", "value": 0.08, "hook": "regen", "hook_value": 0.015},
    {"id": "barrier_blade", "name": "破魔圣剑", "rarity": "epic", "pool": False, "max_stack": 1,
     "desc": "四块碎片合成。携带者的攻击击碎魔王屏障，暴击率 +20%，暴击伤害 +80%，对魔王和魔人伤害翻倍。免疫 10 次致命伤害。魔王战中，每有 1 名队友倒下就升一档：9999 真实伤害，再削减生命上限、斩杀，最后免控。",
     "hook": "barrier_blade", "value": 1},
    {"id": "blade_shard_1", "name": "圣剑碎片·一", "rarity": "epic", "pool": False, "max_stack": 1,
     "desc": "试炼碎片。携带者暴击率 +10%。集齐四块后自动合成破魔圣剑。", "hook": "crit", "value": 0.10},
    {"id": "blade_shard_2", "name": "圣剑碎片·二", "rarity": "epic", "pool": False, "max_stack": 1,
     "desc": "试炼碎片。携带者暴击伤害 +50%。集齐四块后自动合成破魔圣剑。", "hook": "crit_bonus", "value": 0.50},
    {"id": "blade_shard_3", "name": "圣剑碎片·三", "rarity": "epic", "pool": False, "max_stack": 1,
     "desc": "试炼碎片。携带者对魔王精灵伤害 +50%。集齐四块后自动合成破魔圣剑。", "hook": "vs_king", "value": 0.50},
    {"id": "blade_shard_4", "name": "圣剑碎片·四", "rarity": "epic", "pool": False, "max_stack": 1,
     "desc": "试炼碎片。携带者免疫 5 次致命伤害。集齐四块后自动合成破魔圣剑。", "hook": "shard_lives", "value": 5},
    {"id": "pokeball", "name": "灵契球", "rarity": "rare", "pool": False,
     "desc": "商店购入。战斗中丢出占一次行动。除魔王外都有机会收服，稀有度越低越容易。", "value": 1},
]

TRAINERS = [
    {"id": "novice", "name": "新手训练家", "title": "天命一击", "color": "#7ed6a5",
     "desc": "没有属性加成。开局「天命」放在词条背包里，自己决定贴给谁。另有「无限」，只能赋予开局选定的精灵。",
     "mods": {}, "start_items": 0, "item_bonus": 0.0, "starter_affix": "miracle"},
    {"id": "veteran", "name": "高级训练家", "title": "整装出发", "color": "#ffb35c",
     "desc": "全队生命、攻击、防御、速度 +10%。开局自选 3 件道具。",
     "mods": {"hp_mult": 0.10, "atk_mult": 0.10, "def_mult": 0.10, "spd_mult": 0.10},
     "start_items": 0, "item_bonus": 0.0, "pick_items": 3},
    {"id": "master", "name": "老练训练家", "title": "英雄之契", "color": "#c49bff",
     "desc": "全队生命、攻击、防御、速度 +20%。初始精灵从英雄中选择。",
     "mods": {"hp_mult": 0.20, "atk_mult": 0.20, "def_mult": 0.20, "spd_mult": 0.20},
     "start_items": 0, "item_bonus": 0.0, "hero_starter": True},
]

BOSS_BUFF_POOL = [
    {"id": "frenzy",     "name": "狂暴",     "desc": "攻击 +30%。"},
    {"id": "undying",    "name": "不灭",     "desc": "最大生命 +40% 并回满。"},
    {"id": "bedrock",    "name": "磐石",     "desc": "防御 +30%。"},
    {"id": "swift",      "name": "疾影",     "desc": "速度 +25%。"},
    {"id": "bloodthirst","name": "嗜血",     "desc": "攻击吸血 25%。"},
    {"id": "barbed",     "name": "荆棘",     "desc": "反弹 18% 受到的伤害。"},
    {"id": "renewal",    "name": "复苏",     "desc": "每回合回复 7% 最大生命。"},
    {"id": "oppress",    "name": "威压",     "desc": "敌方全体攻击 -15%。"},
    {"id": "warded",     "name": "元素护体", "desc": "受到伤害 -15%。"},
    {"id": "surge",      "name": "狂潮",     "desc": "大招伤害 +40%。"},
    {"id": "pierce",     "name": "破防",     "desc": "无视目标 30% 防御。"},
    {"id": "enrage",     "name": "狂怒",     "desc": "生命越低伤害越高，最多 +35%。"},
    {"id": "siphon",     "name": "噬魂",     "desc": "吸血 15%，每回合回复 3% 最大生命。"},
]

BOSSES = [
    {"id": "b1", "name": "熔核领主·赫岩", "element": "fire", "class": "guardian",
     "level_offset": 3, "stat_mult": {"hp": 1.72, "atk": 1.76, "def": 1.28, "spd": 1.00},
     "buff_count": 2, "tier": 1,
     "phases": [
         {"hp_pct": 0.65, "buff": "frenzy", "text": "熔核领主的岩浆沸腾了！攻击力大幅提升！"},
         {"hp_pct": 0.30, "buff": "barbed", "text": "熔核领主硬化外壳，反弹一切伤害！"}],
     "skills": {
         "normal": {"id": "n_b1", "name": "熔岩重锤", "kind": "normal", "target": "front", "mult": 1.10,
                    "desc": "重锤前排，附加灼烧。"},
         "ultimate": {"id": "u_b1", "name": "熔核震击", "kind": "ult_boss_aoe", "target": "front", "mult": 1.75,
                      "desc": "震荡最多 3 名敌人并附加灼烧。"}}},
    {"id": "b2", "name": "幽夜女巫·瑟琳", "element": "dark", "class": "mage",
     "level_offset": 3, "stat_mult": {"hp": 2.00, "atk": 1.92, "def": 1.14, "spd": 1.08},
     "buff_count": 2, "tier": 1,
     "phases": [
         {"hp_pct": 0.60, "buff": "swift", "text": "永夜帷幕展开，女巫的速度攀升！"},
         {"hp_pct": 0.30, "buff": "frenzy", "text": "瑟琳撕开夜幕，暗影之力沸腾！"}],
     "skills": {
         "normal": {"id": "n_b2", "name": "暮影弹", "kind": "normal", "target": "back", "mult": 1.10,
                    "desc": "攻击后排并降低攻击。"},
         "ultimate": {"id": "u_b2", "name": "永夜帷幕", "kind": "ult_boss_aoe", "target": "all", "mult": 1.85,
                      "desc": "对全体敌人造成暗影伤害并降低攻击。"}}},
    {"id": "b4", "name": "雷霆巨像·罡岳", "element": "rock", "class": "guardian",
     "level_offset": 3, "stat_mult": {"hp": 2.16, "atk": 1.96, "def": 1.36, "spd": 1.04},
     "buff_count": 2, "tier": 1,
     "phases": [
         {"hp_pct": 0.60, "buff": "bedrock", "text": "巨像拔起大地之铠，防御暴涨！"},
         {"hp_pct": 0.28, "buff": "frenzy", "text": "雷霆核心过载，巨像的攻击失去节制！"}],
     "skills": {
         "normal": {"id": "n_b4", "name": "雷岩重踏", "kind": "normal", "target": "front", "mult": 1.15,
                    "desc": "踏碎前排，附加破甲。"},
         "ultimate": {"id": "u_b4", "name": "天雷崩落", "kind": "ult_boss_aoe", "target": "front", "mult": 1.90,
                      "desc": "召来天雷轰击最多 3 名敌人并降低防御。"}}},
    {"id": "b3", "name": "星蚀龙皇·奥瑞恩", "element": "dragon", "class": "warrior",
     "level_offset": 4, "stat_mult": {"hp": 2.45, "atk": 2.12, "def": 1.48, "spd": 1.06},
     "buff_count": 3, "tier": 2,
     "phases": [
         {"hp_pct": 0.70, "buff": "frenzy", "text": "龙皇的血液沸腾了！攻击力大幅提升！"},
         {"hp_pct": 0.45, "buff": "swift", "text": "星蚀之力爆发！龙皇的速度与气势攀升至极限！"},
         {"hp_pct": 0.20, "buff": "undying", "text": "星蚀龙皇拒绝终结，生命与护盾再度充盈！"}],
     "skills": {
         "normal": {"id": "n_b3", "name": "星蚀爪", "kind": "normal", "target": "front", "mult": 1.25,
                    "desc": "撕裂前排，附加易伤。"},
         "ultimate": {"id": "u_b3", "name": "星蚀灭世", "kind": "ult_boss_aoe", "target": "all", "mult": 2.05,
                      "desc": "对最多 3 名敌人造成毁灭打击并施加易伤。"}}},

    {"id": "k1", "name": "赤潮魔王·焚渊", "element": "fire", "class": "warrior",
     "level_offset": 3, "stat_mult": {"hp": 2.35, "atk": 1.95, "def": 1.32, "spd": 1.02},
     "buff_count": 2, "tier": 2, "demon_king": True, "generation": 1, "reward_demon": "d5",
     "phases": [
         {"hp_pct": 0.65, "buff": "frenzy", "text": "赤潮翻涌！焚渊的攻击变得狂暴！"},
         {"hp_pct": 0.30, "buff": "swift", "text": "熔核贴地奔流，焚渊的速度骤然拔高！"}],
     "skills": {
         "normal": {"id": "n_k1", "name": "赤潮斩", "kind": "normal", "target": "front", "mult": 1.2,
                    "desc": "灼热的潮刃劈向前排。"},
         "ultimate": {"id": "u_k1", "name": "焚渊潮", "kind": "ult_boss_aoe", "target": "all", "mult": 1.9,
                      "desc": "赤潮席卷最多 3 名敌人。"}}},
    {"id": "k2", "name": "霜狱魔王·溟雪", "element": "ice", "class": "mage",
     "level_offset": 4, "stat_mult": {"hp": 2.9, "atk": 2.25, "def": 1.48, "spd": 1.04},
     "buff_count": 3, "tier": 2, "demon_king": True, "generation": 2, "reward_demon": "d6",
     "phases": [
         {"hp_pct": 0.70, "buff": "bedrock", "text": "霜狱合拢，溟雪的防御与护盾同时抬升！"},
         {"hp_pct": 0.45, "buff": "frenzy", "text": "寒潮倒灌，溟雪的攻击变得刺骨！"},
         {"hp_pct": 0.22, "buff": "swift", "text": "冰晶碎裂，溟雪抢在所有人之前出手！"}],
     "skills": {
         "normal": {"id": "n_k2", "name": "霜狱刺", "kind": "normal", "target": "front", "mult": 1.22,
                    "desc": "冰刺钉向前排。"},
         "ultimate": {"id": "u_k2", "name": "溟雪葬", "kind": "ult_boss_aoe", "target": "all", "mult": 2.0,
                      "desc": "暴雪埋葬最多 3 名敌人。"}}},
    {"id": "k3", "name": "蚀月魔王·夜冕", "element": "dark", "class": "mage",
     "level_offset": 6, "stat_mult": {"hp": 4.6, "atk": 2.85, "def": 1.78, "spd": 1.06},
     "buff_count": 3, "tier": 3, "demon_king": True, "generation": 3, "reward_demon": "d7",
     "phases": [
         {"hp_pct": 0.72, "buff": "frenzy", "text": "月蚀加深，夜冕的攻击被黑暗放大！"},
         {"hp_pct": 0.46, "buff": "bedrock", "text": "夜冕拉起暗幕，防御与护盾同时充盈！"},
         {"hp_pct": 0.22, "buff": "undying", "text": "蚀月拒绝坠落，生命再度充盈！"}],
     "skills": {
         "normal": {"id": "n_k3", "name": "夜冕击", "kind": "normal", "target": "lowest", "mult": 1.24,
                    "desc": "暗芒追着最脆弱的目标。"},
         "ultimate": {"id": "u_k3", "name": "蚀月礼", "kind": "ult_boss_aoe", "target": "all", "mult": 2.1,
                      "desc": "月蚀砸向最多 3 名敌人。"}}},
    {"id": "k4", "name": "终焉魔王·星陨", "element": "dragon", "class": "warrior",
     "level_offset": 12, "stat_mult": {"hp": 16.0, "atk": 4.6, "def": 2.4, "spd": 1.12},
     "buff_count": 4, "tier": 3, "demon_king": True, "generation": 4, "reward_demon": "d8",
     "phases": [
         {"hp_pct": 0.78, "buff": "frenzy", "text": "星陨苏醒，终焉的攻击压过整座塔！"},
         {"hp_pct": 0.55, "buff": "bedrock", "text": "陨铁合拢，终焉的防御与护盾同时抬升！"},
         {"hp_pct": 0.32, "buff": "swift", "text": "星屑加速，终焉抢在所有人之前出手！"},
         {"hp_pct": 0.15, "buff": "undying", "text": "终焉拒绝落幕，生命与护盾再度充盈！"}],
     "skills": {
         "normal": {"id": "n_k4", "name": "星陨爪", "kind": "normal", "target": "front", "mult": 1.32,
                    "desc": "陨星般的爪击撕裂前排。"},
         "ultimate": {"id": "u_k4", "name": "终焉坠落", "kind": "ult_boss_aoe", "target": "all", "mult": 2.35,
                      "desc": "星辰坠落，砸向最多 3 名敌人。"}}},

]

MAPS = {
    "lava":   {"name": "熔岩峡谷", "sky": ["#2a0e12", "#571a1b"], "accent": "#ff6b3d", "style": "lava"},
    "ocean":  {"name": "幽蓝深海", "sky": ["#04121f", "#0b3450"], "accent": "#41a6ff", "style": "ocean"},
    "sky":    {"name": "天空浮岛", "sky": ["#0b2030", "#1d5a63"], "accent": "#5fe0c0", "style": "sky"},
    "forest": {"name": "远古森林", "sky": ["#08170e", "#1c3a1e"], "accent": "#7bdc8a", "style": "forest"},
    "storm":  {"name": "雷鸣高地", "sky": ["#120d24", "#34204f"], "accent": "#b28dff", "style": "storm"},
    "desert": {"name": "荒芜沙海", "sky": ["#2b1a0a", "#5c3c17"], "accent": "#f0c66a", "style": "desert"},
    "temple": {"name": "星辉圣殿", "sky": ["#0c1129", "#26345f"], "accent": "#ffd76a", "style": "temple"},
    "night":  {"name": "永夜回廊", "sky": ["#0a0614", "#24143f"], "accent": "#a875ff", "style": "night"},
    "void":   {"name": "虚空裂隙", "sky": ["#170618", "#3d0f38"], "accent": "#ff5bd0", "style": "void"},
    "throne": {"name": "星蚀王座", "sky": ["#0b0817", "#2a1a3f"], "accent": "#ff8a5c", "style": "throne"},
    "lava2":   {"name": "熔心深渊", "sky": ["#320610", "#731512"], "accent": "#ff4426", "style": "lava"},
    "ocean2":  {"name": "沉没神殿", "sky": ["#020d18", "#073a4a"], "accent": "#35d6cf", "style": "ocean"},
    "sky2":    {"name": "云端天阶", "sky": ["#101c3a", "#2a6a7a"], "accent": "#8ef0dc", "style": "sky"},
    "storm2":  {"name": "雷罚高原", "sky": ["#1a0f2e", "#452a63"], "accent": "#c9a0ff", "style": "storm"},
    "forest2": {"name": "世界树根", "sky": ["#06130b", "#274a26"], "accent": "#a4f07c", "style": "forest"},
    "desert2": {"name": "流沙王陵", "sky": ["#33200c", "#6d4a1c"], "accent": "#ffd98a", "style": "desert"},
    "temple2": {"name": "星辉中枢", "sky": ["#101430", "#364a7a"], "accent": "#ffe08a", "style": "temple"},
    "night2":  {"name": "永夜圣所", "sky": ["#0d0718", "#301a52"], "accent": "#c48bff", "style": "night"},
    "void2":   {"name": "次元夹缝", "sky": ["#1d0620", "#4d1248"], "accent": "#ff6bdc", "style": "void"},
    "throne2": {"name": "终焉星座", "sky": ["#0d0718", "#38205a"], "accent": "#ff9a6a", "style": "throne"},
}

FLOOR_POOLS = {
    1: ["fire", "ground"],
    2: ["water", "ice"],
    3: ["flying", "psychic"],
    4: ["electric", "flying"],
    5: ["fire", "rock"],
    6: ["grass", "bug"],
    7: ["ground", "rock"],
    8: ["psychic", "fighting"],
    9: ["dark", "ghost"],
    10: ["dark", "ghost"],
    11: ["ghost", "psychic"],
    12: ["fire", "dragon"],
    13: ["water", "poison"],
    14: ["flying", "electric"],
    15: ["electric", "rock"],
    16: ["grass", "poison"],
    17: ["ground", "steel"],
    18: ["psychic", "normal"],
    19: ["ghost", "dragon"],
    20: ["dragon", "dark"],
    21: ["fire", "dragon"],
    22: ["water", "ice"],
    23: ["flying", "electric"],
    24: ["rock", "ground"],
    25: ["dark", "ghost"],
    26: ["grass", "bug"],
    27: ["steel", "rock"],
    28: ["psychic", "fighting"],
    29: ["ghost", "dark"],
    30: ["dark", "dragon"],
    31: ["poison", "ghost"],
    32: ["fire", "rock"],
    33: ["water", "steel"],
    34: ["electric", "flying"],
    35: ["dragon", "fire"],
    36: ["grass", "ground"],
    37: ["steel", "fighting"],
    38: ["psychic", "ghost"],
    39: ["dark", "dragon"],
    40: ["dragon", "dark"],
}
FLOOR_MAPS = {
    1: "lava", 2: "ocean", 3: "sky", 4: "storm", 5: "lava",
    6: "forest", 7: "desert", 8: "temple", 9: "night", 10: "night2",
    11: "void", 12: "lava2", 13: "ocean2", 14: "sky2", 15: "storm2",
    16: "forest2", 17: "desert2", 18: "temple2", 19: "void2", 20: "ocean2",
    21: "lava2", 22: "ocean2", 23: "sky2", 24: "desert2", 25: "night2",
    26: "forest2", 27: "storm2", 28: "temple2", 29: "void", 30: "night2",
    31: "void2", 32: "lava2", 33: "ocean", 34: "sky2", 35: "throne",
    36: "forest2", 37: "desert2", 38: "temple2", 39: "void2", 40: "throne2",
}
FLOOR_NAMES = {
    1: "第一层 · 熔岩峡谷", 2: "第二层 · 幽蓝深海", 3: "第三层 · 天空浮岛",
    4: "第四层 · 雷鸣裂谷", 5: "第五层 · 熔心祭坛", 6: "第六层 · 远古森林",
    7: "第七层 · 荒芜沙海", 8: "第八层 · 星辉圣殿", 9: "第九层 · 永夜回廊",
    10: "第十层 · 赤潮王座", 11: "第十一层 · 虚空裂隙", 12: "第十二层 · 熔心深渊",
    13: "第十三层 · 沉没神殿", 14: "第十四层 · 云端天阶", 15: "第十五层 · 幽夜边陲",
    16: "第十六层 · 世界树根", 17: "第十七层 · 流沙王陵", 18: "第十八层 · 星辉中枢",
    19: "第十九层 · 次元夹缝", 20: "第二十层 · 霜狱王庭",
    21: "第二十一层 · 熔核回廊", 22: "第二十二层 · 潮汐墓道", 23: "第二十三层 · 浮空断桥",
    24: "第二十四层 · 流沙神殿", 25: "第二十五层 · 永夜祭坛", 26: "第二十六层 · 森影回廊",
    27: "第二十七层 · 雷罚高坛", 28: "第二十八层 · 星辉回廊", 29: "第二十九层 · 虚空阶梯",
    30: "第三十层 · 蚀月魔庭", 31: "第三十一层 · 次元深井", 32: "第三十二层 · 熔心深座",
    33: "第三十三层 · 沉渊海沟", 34: "第三十四层 · 云巅裂口", 35: "第三十五层 · 星蚀龙庭",
    36: "第三十六层 · 世界树冠", 37: "第三十七层 · 铁砂王陵", 38: "第三十八层 · 圣殿穹顶",
    39: "第三十九层 · 次元深渊", 40: "第四十层 · 终焉魔座",
}
FLOOR_COUNTS = {1: 1, 2: 2, 3: 3, 4: 4}
for _f in range(5, 41):
    FLOOR_COUNTS[_f] = 5
BOSS_FLOORS = {5: "b1", 15: "b2", 25: "b4", 35: "b3"}
KING_FLOORS = {10: "k1", 20: "k2", 30: "k3", 40: "k4"}
TOTAL_FLOORS = 40


def floor_level(f: int) -> int:
    # After floor 18 non-starter pets begin hitting rarity caps, so enemy levels rise slower.
    # Final demon king (floor 40, offset +12) reaches the demon king cap of Lv.150.
    if f <= 18:
        return 10 + (f - 1) * 5
    if f <= 30:
        return 95 + int(round((f - 18) * 2.0))
    return 119 + int(round((f - 30) * 1.9))


def minion_affix_count(f: int) -> int:
    if f < 5:
        return 0
    if f < 14:
        return 1
    return 2


def make_floors(pets):
    by_element = {}
    for p in pets:
        by_element.setdefault(p["element"], []).append(p["id"])
    floors = []
    for f in range(1, TOTAL_FLOORS + 1):
        pool = []
        for el in FLOOR_POOLS[f]:
            pool.extend(by_element[el])
        is_boss = f in BOSS_FLOORS or f in KING_FLOORS
        if f in KING_FLOORS:
            enemy_mult = round(min(1.35, 0.95 + 0.01 * (f - 1)), 3)
            minion_mult = round(min(1.25, 0.82 + 0.01 * (f - 1)), 3)
        elif is_boss:
            # Keep each later boss ahead of the previous king, including floor 35.
            enemy_mult = round(min(1.28, 0.86 + 0.012 * (f - 1)), 3)
            minion_mult = round(min(1.08, 0.74 + 0.009 * (f - 1)), 3)
        else:
            # Floors 1–20 use the early ramp. After that the old cap froze every
            # normal floor at 1.0 while the party kept growing.
            raw = 0.78 + 0.012 * (f - 1)
            if f >= 21:
                raw = 1.0 + 0.006 * (f - 20)
            enemy_mult = round(min(1.16, raw), 3)
            minion_mult = 1.0
        floors.append({
            "floor": f,
            "name": FLOOR_NAMES[f],
            "map": FLOOR_MAPS[f],
            "kind": "boss" if is_boss else "normal",
            "enemy_count": FLOOR_COUNTS[f],
            "level": floor_level(f),
            "pool": sorted(set(pool)),
            "boss": KING_FLOORS.get(f) or BOSS_FLOORS.get(f),
            "minion_count": 4 if is_boss else 0,
            "minion_level_offset": -5 if is_boss else 0,
            "minion_stat_mult": minion_mult,
            "enemy_stat_mult": enemy_mult,
            "minion_affix_count": (1 if f <= 10 else 2) if is_boss else minion_affix_count(f),
            "elite": is_boss,
        })
    return floors


FORMATION = {
    "row_damage": {"0": 1.00, "1": 1.00, "2": 1.00},
    "row_names": {"0": "前排", "1": "中排", "2": "后排"},
    "player_templates": {
        "1": [[1, 0]],
        "2": [[0, 0], [2, 0]],
        "3": [[0, 0], [2, 0], [1, 1]],
        "4": [[0, 0], [2, 0], [1, 1], [1, 2]],
        "5": [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]],
    },
    "enemy_templates": {
        "1": [[1, 0]],
        "2": [[0, 0], [2, 0]],
        "3": [[0, 0], [2, 0], [1, 1]],
        "4": [[0, 0], [2, 0], [1, 1], [1, 2]],
        "5": [[0, 0], [2, 0], [1, 1], [0, 2], [2, 2]],
    },
    "boss_templates": {
        "b1": {"boss": [1, 2], "minions": [[0, 0], [2, 0], [0, 1], [2, 1]]},
        "b2": {"boss": [1, 2], "minions": [[0, 0], [2, 0], [0, 1], [2, 1]]},
        "b3": {"boss": [1, 2], "minions": [[0, 0], [2, 0], [0, 1], [2, 1]]},
        "b4": {"boss": [1, 2], "minions": [[0, 0], [2, 0], [0, 1], [2, 1]]},
        "k1": {"boss": [1, 2], "minions": [[0, 0], [2, 0], [0, 1], [2, 1]]},
        "k2": {"boss": [1, 2], "minions": [[0, 0], [2, 0], [0, 1], [2, 1]]},
        "k3": {"boss": [1, 2], "minions": [[0, 0], [2, 0], [0, 1], [2, 1]]},
        "k4": {"boss": [1, 2], "minions": [[0, 0], [2, 0], [0, 1], [2, 1]]},
    },
    # Orthogonal neighbors.  mods[class] is added to that side of the pair.
    "links": [
        {"a": "guardian", "b": "archer", "mods": {"archer": {"taken": -0.12}}},
        {"a": "guardian", "b": "mage", "mods": {"mage": {"taken": -0.10}}},
        {"a": "guardian", "b": "support", "mods": {"support": {"shield": 0.20}}},
        {"a": "guardian", "b": "warrior", "mods": {"warrior": {"atk": 0.08}, "guardian": {"def": 0.08}}},
        {"a": "warrior", "b": "warrior", "mods": {"warrior": {"atk": 0.08}}},
        {"a": "warrior", "b": "archer", "mods": {"warrior": {"atk": 0.06}, "archer": {"crit": 0.08}}},
        {"a": "mage", "b": "support", "mods": {"mage": {"heal": 0.15}, "support": {"heal": 0.15}}},
        {"a": "mage", "b": "archer", "mods": {"mage": {"skill": 0.08}, "archer": {"skill": 0.08}}},
        {"a": "archer", "b": "support", "mods": {"archer": {"spd": 0.08}, "support": {"heal": 0.08}}},
        {"a": "support", "b": "support", "mods": {"support": {"heal": 0.12}}},
    ],
}

def _tiers(kind):
    table = {
        "atk": ("全队攻击 +8%。", {"atk": 0.08}, "全队攻击 +16%，暴击 +5%。", {"atk": 0.16, "crit": 0.05}),
        "hp": ("全队最大生命 +8%。", {"hp": 0.08}, "全队最大生命 +16%，防御 +8%。", {"hp": 0.16, "def": 0.08}),
        "spd": ("全队速度 +8%。", {"spd": 0.08}, "全队速度 +16%，暴击 +4%。", {"spd": 0.16, "crit": 0.04}),
        "def": ("全队防御 +10%。", {"def": 0.10}, "全队防御 +20%，最大生命 +6%。", {"def": 0.20, "hp": 0.06}),
        "mix": ("全队暴击 +5%，攻击 +5%。", {"crit": 0.05, "atk": 0.05}, "全队暴击 +10%，攻击 +10%。", {"crit": 0.10, "atk": 0.10}),
    }
    d2, m2, d3, m3 = table[kind]
    return [
        {"count": 2, "name": "二重", "desc": d2, "mods": m2},
        {"count": 3, "name": "三重", "desc": d3, "mods": m3},
    ]


_RESONANCE_KIND = {
    "fire": "atk", "fighting": "atk", "dragon": "atk", "dark": "atk",
    "water": "hp", "normal": "hp", "grass": "hp",
    "electric": "spd", "flying": "spd", "bug": "spd",
    "rock": "def", "ground": "def", "steel": "def", "ice": "def",
    "psychic": "mix", "ghost": "mix", "poison": "mix",
}
RESONANCE = {
    eid: {"name": name + "系共鸣", "color": color, "tiers": _tiers(_RESONANCE_KIND[eid])}
    for eid, (name, color) in ELEMENT_META.items()
}

COMBAT = {
    "level_steps": {"hp": 0.050, "atk": 0.060, "def": 0.050, "spd": 0.020},
    "max_level": 500,
    "rarity_max_level": {
        "common": 60,
        "rare": 70,
        "epic": 80,
        "legend": 90,
        "hero": 100,
        "demon": 180,
        "demon_king": 150,
    },
    "king_level_caps": {
        "d5": 195, "d6": 215, "d7": 220, "d8": 230,
        "d9": 280, "d10": 350, "d11": 500,
    },
    "level_up_per_floor": 5,
    "level_per_floor": 5,
    "base_level": 10,
    "total_floors": TOTAL_FLOORS,
    "evo_levels": [30, 60],
    "evo_mult": [1.0, 1.25, 1.55],
    "def_coefficient": 0.40,
    "rage_max": 4,
    "crit_base": 0.05,
    "crit_mult": 1.6,
    "element_advantage": 2.0,
    "element_disadvantage": 0.5,
    "stab": 1.2,
    "type_chart": TYPE_CHART,
    "chest_pet_chance": 1.0,
    "chest_item_chance": 1.0,
    "chest_affix_chance": 1.0,
    "chest_hero_chance": 0.0,
    "chest_rarity_weights": CHEST_RARITY,
    "rarity_stat_mult": RARITY_STAT,
    "hero_stat_mult": {"hp": 1.55, "atk": 1.50, "def": 1.35, "spd": 1.10},
    "hero_buff_scale": 0.60,
    "hero_star_bonus": 0.06,
    "hero_max_star": 6,
    "hero_skill_mult": 1.12,
    "hero_upgrade_cost": 1,
    "affix_weights": RARITY_WEIGHT,
    "item_weights": {"common": 50, "rare": 35, "epic": 15},
    "affix_max_per_skill": 3,
    "affix_max_per_pet": 6,
    "resonance_bonus": 0.08,
    "max_rounds": 80,
    "event_floors": [2, 5, 8, 11, 14, 17, 20, 23, 26, 29, 32, 35, 38],
    "curse_stat_mult": 1.25,
    "curse_bonus_items": 1,
    "king_contract_chance": 0.15,
    "rare_affix_chance": 0.10,
    "rare_affix_ids": ["rebound", "volley", "aegis", "still"],
    "king_escort_min": 2,
    "king_might_pct": 0.08,
    "king_might_cap": 5,
    "fallen_stat_mult": 1.35,
    "fallen_skill_mult": 1.40,
}

STARTER_NOTES = {
    "p01": "火系战士，稳健的前排核心，普攻叠狐火。",
    "p10": "水系辅助，普攻治疗，泡影保护最脆弱的队友。",
    "p25": "草系法师，绒种会在回合结束时蔓延到相邻敌人。",
}


def build_content():
    pets = make_pets()
    demons = make_demons()
    starters = []
    for pid in STARTER_IDS:
        pet = next(p for p in pets if p["id"] == pid)
        starters.append({"id": pid, "note": STARTER_NOTES[pid]})
    return {
        "version": 3,
        "title": "灵契·星塔远征",
        "subtitle": "怀旧肉鸽爬塔",
        "meta": {
            "pets": len(pets), "affixes": len(AFFIXES), "items": len(ITEMS),
            "bosses": len(BOSSES), "floors": TOTAL_FLOORS,
            "note": "All names and vector art are original; no third-party assets are bundled.",
        },
        "elements": ELEMENTS,
        "classes": CLASSES,
        "trainers": TRAINERS,
        "starters": starters,
        "pets": pets,
        "demons": demons,
        "type_chart": TYPE_CHART,
        "affixes": AFFIXES,
        "items": ITEMS,
        "bosses": BOSSES,
        "boss_buff_pool": BOSS_BUFF_POOL,
        "maps": MAPS,
        "floors": make_floors(pets),
        "formation": FORMATION,
        "combat": COMBAT,
        "resonance": RESONANCE,
    }


if __name__ == "__main__":
    import json
    print(json.dumps(build_content(), ensure_ascii=False, indent=2)[:2000])
