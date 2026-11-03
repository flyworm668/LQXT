# -*- coding: utf-8 -*-
"""Rare+ marks, ultimate signatures, silhouettes and the four event demons.

Marks are data.  The battle engine reads `fx` / `fx2` instead of a branch per pet.
`on` is who holds the stacks: foe (the target) or self (the attacker).
"""


def M(mid, name, on, fx, per, **kw):
    row = {"id": mid, "name": name, "on": on, "max": 3, "fx": fx, "per": per}
    row.update(kw)
    return row


def U(style, text, **kw):
    row = {"style": style, "text": text}
    row.update(kw)
    return row


# fx: elem_taken slow self_crit def_down self_atk poison antiheal self_heal
#     crit_taken atk_down self_skill self_thorns self_spd self_def vuln ward
#     tick_adj true_hp self_vamp self_ult self_elem dealt_down ignore_def
# full: burst freeze chain immune nocrit aoe_next
MARKS = {
    "赤雀": M("flame_scar", "焰痕", "foe", "elem_taken", 0.06, elem="fire", full="burst", burst=0.20),
    "碧波豚": M("tide", "潮涌", "foe", "slow", 0.06),
    "霜鳍鲨": M("frost_fang", "霜牙", "foe", "slow", 0.05, full="freeze"),
    "涟漪鳗": M("shock", "感电", "foe", "elem_taken", 0.08, elem="electric", full="chain", burst=0.15),
    "疾羽鸢": M("sharp_feather", "锐羽", "self", "self_crit", 0.06),
    "晶石蜥": M("crack", "裂晶", "foe", "def_down", 0.07),
    "圣辉猫": M("fight_spirit", "斗气", "self", "self_atk", 0.05),
    "雾雨蛙": M("venom", "毒雾", "foe", "poison", 0.04),
    "莹光蛾": M("dust", "粉尘", "foe", "antiheal", 0.25),
    "晨曦鹿": M("dawn", "晨光", "self", "self_heal", 0.08),
    "幽夜鸦": M("curse_feather", "咒羽", "foe", "crit_taken", 0.08),
    "暗焰犬": M("eclipse_fire", "蚀火", "foe", "atk_down", 0.05, fx2="self_vamp", per2=0.03),
    "烈阳鹿": M("dragon_glow", "龙晖", "self", "self_skill", 0.06),
    "琥珀蜥": M("crystal_armor", "晶甲", "self", "self_thorns", 0.06),
    "焰狐": M("fox_fire", "狐火", "foe", "vuln", 0.08),
    "水泡獭": M("bubble", "泡影", "self", "ward", 0.05),
    "风铃鼠": M("bell_wind", "铃风", "self", "self_spd", 0.06),
    "熔岩獾": M("lava", "岩熔", "foe", "def_down", 0.08),
    "炎角犀": M("horn", "龙角", "self", "self_def", 0.06, full="immune"),
    "蒲公英兔": M("seed", "绒种", "foe", "tick_adj", 0.08, elem="grass"),
    "光羽雀": M("spirit", "灵羽", "foe", "true_hp", 0.02),
    "暮色蝠": M("siphon", "吸魂", "self", "self_vamp", 0.05),
    "幻梦蛛": M("dream", "梦丝", "foe", "slow", 0.04, full="nocrit"),
    "焚羽鹰": M("sky_burn", "焚空", "foe", "elem_taken", 0.08, elem="fire", fx2="kill_spd", per2=0.08),
    "冰晶水母": M("jelly", "晶冻", "foe", "slow", 0.07, full="freeze", fx2="frozen_taken", per2=0.20),
    "惊雷燕": M("thunder_core", "雷核", "self", "self_elem", 0.10, elem="electric", full="aoe_next"),
    "日冕狮": M("pride", "王威", "foe", "dealt_down", 0.08),
    "蚀月蛇": M("moon", "月蚀", "foe", "elem_taken", 0.06, elem="dark", fx2="antiheal", per2=0.06),
    "夜巡枭": M("night_eye", "夜瞳", "self", "ignore_def", 0.10),
    "烬狼": M("ember_soul", "烬魂", "self", "self_atk", 0.08, fx2="death_nova", per2=0.20, elem="fire"),
    "星尘狐": M("star_orbit", "星轨", "self", "self_ult", 0.12, fx2="rage_chance", per2=0.10),
    "影刃豹": M("shadow_blade", "影刃", "foe", "crit_taken", 0.10, fx2="self_spd", per2=0.04),
}

ULTS = {
    "赤雀": U("wounded", "对已受伤目标伤害 +25%，并留下 1 层焰痕。", bonus=0.25, leave=1),
    "碧波豚": U("haste_lock", "目标 2 回合无法加速，自身回复 8% 生命。", heal=0.08),
    "霜鳍鲨": U("shatter", "对冰封或减速目标伤害翻倍，并溅射 30%。", mult=2.0, splash=0.30),
    "涟漪鳗": U("bounce", "额外弹射 2 次；目标带感电时伤害 +20%。", jumps=2, bonus=0.20),
    "疾羽鸢": U("sure_crit", "必定暴击，每消耗 1 层锐羽伤害 +15%。", per=0.15),
    "晶石蜥": U("back_shred", "后排防御 -15%，持续 2 回合。", pct=0.15),
    "圣辉猫": U("double_hit", "追加一击（50%），每次命中叠加 1 层斗气。", ratio=0.50),
    "雾雨蛙": U("poison_pop", "敌方全体 +1 层毒雾，已有毒立刻结算 2 层。"),
    "莹光蛾": U("antiheal_dispel", "对禁疗目标伤害 +35%，并驱散 1 个增益。", bonus=0.35),
    "晨曦鹿": U("team_mend", "全队回复 12% 生命，晨光层数化为等额护盾。", heal=0.12),
    "幽夜鸦": U("missing", "优先残血，每层咒羽按已损失生命追加伤害，最多 +24%。", per=0.08, cap=0.24),
    "暗焰犬": U("drain", "消耗蚀火，每层造成 30% 攻击的暗蚀伤害并吸血。", per=0.30),
    "烈阳鹿": U("column", "轰击目标所在一列，每层龙晖伤害 +12%。", per=0.12),
    "琥珀蜥": U("thorn_shield", "每层晶甲化为 8% 最大生命护盾，并对前排造成等额伤害。", per=0.08),
    "焰狐": U("triple", "对前排连击 3 次（0.7 倍）；第 3 击在目标有狐火时变为全体。", hits=3, ratio=0.70),
    "水泡獭": U("team_ward", "全队获得 2 层泡影，并回复 10% 生命。", stacks=2, heal=0.10),
    "风铃鼠": U("by_stacks", "狙击残血，命中次数 = 1 + 铃风层数，每次 0.6 倍。", ratio=0.60),
    "熔岩獾": U("pierce_shield", "无视 50% 防御，岩熔层数化为自身护盾。", ignore=0.50, per=0.06),
    "炎角犀": U("shove", "将前排目标撞到后排并眩晕 1 回合。"),
    "蒲公英兔": U("seed_burst", "每层绒种引爆 30% 草系伤害，并回复该伤害的 30%。", per=0.30, heal=0.30),
    "光羽雀": U("random_mark", "随机攻击 4 次，优先命中带灵羽的目标。", hits=4),
    "暮色蝠": U("fear", "敌方攻击 -12% 持续 2 回合，层数最高者眩晕 1 回合。", pct=0.12),
    "幻梦蛛": U("seal", "封印目标 1 回合，梦丝层数化为自身护盾。", per=0.06),
    "焚羽鹰": U("back_exec", "优先后排，目标生命低于 40% 时伤害 +50%。", line=0.40, bonus=0.50),
    "冰晶水母": U("freeze_all", "敌方全体 +1 层晶冻，冰封者受到 40% 冰系碎裂伤害。", burst=0.40),
    "惊雷燕": U("chain", "连锁全体，每次跳跃伤害 -20%，并减速。", falloff=0.20),
    "日冕狮": U("roar", "敌方攻击 -15% 持续 2 回合，并眩晕前排 1 回合。", pct=0.15),
    "蚀月蛇": U("eclipse", "目标每损失 1% 生命，伤害 +0.4%，并偷取 1 个增益。", per=0.004),
    "夜巡枭": U("owl", "对残血连击两次，若击杀则立即再行动一次。"),
    "烬狼": U("true_exec", "消耗烬魂，每层对前排造成 50% 真实伤害；目标低于 25% 生命时斩杀。", per=0.50, line=0.25),
    "星尘狐": U("star_purge", "攻击全体，每层星轨伤害 +15%，并驱散 2 个增益。", per=0.15, dispel=2),
    "影刃豹": U("shadow_refund", "随机攻击 4 次，暴击时返还 1 点气势。", hits=4),
}

# body drives the silhouette.  aura is filled from rarity at draw time.
ART = {
    "赤雀": {"body": "bird", "trait": "crest"},
    "碧波豚": {"body": "fish", "trait": "round"},
    "霜鳍鲨": {"body": "shark", "trait": "fin"},
    "涟漪鳗": {"body": "eel", "trait": "spark"},
    "疾羽鸢": {"body": "bird", "trait": "bladewing"},
    "晶石蜥": {"body": "lizard", "trait": "crystal"},
    "圣辉猫": {"body": "cat", "trait": "fist"},
    "雾雨蛙": {"body": "frog", "trait": "hood"},
    "莹光蛾": {"body": "moth", "trait": "dust"},
    "晨曦鹿": {"body": "deer", "trait": "soft"},
    "幽夜鸦": {"body": "bird", "trait": "shroud"},
    "暗焰犬": {"body": "hound", "trait": "ember"},
    "烈阳鹿": {"body": "deer", "trait": "sun"},
    "琥珀蜥": {"body": "lizard", "trait": "plate"},
    "焰狐": {"body": "fox", "trait": "twin_tail"},
    "水泡獭": {"body": "otter", "trait": "bubble"},
    "风铃鼠": {"body": "mouse", "trait": "bell"},
    "熔岩獾": {"body": "badger", "trait": "shell"},
    "炎角犀": {"body": "rhino", "trait": "horn"},
    "蒲公英兔": {"body": "rabbit", "trait": "fluff"},
    "光羽雀": {"body": "bird", "trait": "halo"},
    "暮色蝠": {"body": "bat", "trait": "fang"},
    "幻梦蛛": {"body": "spider", "trait": "web"},
    "焚羽鹰": {"body": "hawk", "trait": "firewing"},
    "冰晶水母": {"body": "jelly", "trait": "bell"},
    "惊雷燕": {"body": "bird", "trait": "bolt"},
    "日冕狮": {"body": "lion", "trait": "mane"},
    "蚀月蛇": {"body": "snake", "trait": "moon"},
    "夜巡枭": {"body": "owl", "trait": "eye"},
    "烬狼": {"body": "wolf", "trait": "myth"},
    "星尘狐": {"body": "fox", "trait": "stars"},
    "影刃豹": {"body": "panther", "trait": "blade"},
}

DEMONS = [
    {"id": "d1", "name": "熔核魔人·赫炎", "element": "fire", "class": "warrior", "rarity": "demon",
     "from_boss": "b1"},
    {"id": "d2", "name": "永夜魔人·瑟琳影", "element": "dark", "class": "mage", "rarity": "demon",
     "from_boss": "b2"},
    {"id": "d3", "name": "雷岩魔人·罡石", "element": "rock", "class": "guardian", "rarity": "demon",
     "from_boss": "b4"},
    {"id": "d4", "name": "星蚀魔人·奥羽", "element": "dragon", "class": "warrior", "rarity": "demon",
     "from_boss": "b3"},
    {"id": "d5", "name": "赤潮魔人·烬牙", "element": "fire", "class": "warrior", "rarity": "demon",
     "from_boss": "k1"},
    {"id": "d6", "name": "霜狱魔人·白澪", "element": "ice", "class": "mage", "rarity": "demon",
     "from_boss": "k2"},
    {"id": "d7", "name": "蚀月魔人·晦羽", "element": "dark", "class": "mage", "rarity": "demon",
     "from_boss": "k3"},
    {"id": "d8", "name": "终焉魔人·陨卫", "element": "dragon", "class": "guardian", "rarity": "demon",
     "from_boss": "k4"},
    {"id": "d9", "name": "渊律魔人·沧骨", "element": "water", "class": "guardian", "rarity": "demon",
     "from_boss": "k9"},
    {"id": "d10", "name": "焚天魔人·赤冕", "element": "fire", "class": "warrior", "rarity": "demon",
     "from_boss": "k10"},
    {"id": "d11", "name": "无相魔人·归墟", "element": "ghost", "class": "mage", "rarity": "demon",
     "from_boss": "k11"},
]

DEMON_MARKS = {
    "d1": M("demon_fire", "魔炎", "foe", "elem_taken", 0.08, elem="fire", full="burst", burst=0.25),
    "d2": M("demon_night", "魔夜", "foe", "atk_down", 0.07, fx2="antiheal", per2=0.08),
    "d3": M("demon_rock", "魔岩", "foe", "def_down", 0.08, full="freeze"),
    "d4": M("demon_star", "魔星", "foe", "vuln", 0.08, fx2="crit_taken", per2=0.08),
    "d5": M("demon_tide", "赤潮", "foe", "elem_taken", 0.08, elem="fire", full="burst", burst=0.22),
    "d6": M("demon_frost", "霜狱", "foe", "slow", 0.08, full="freeze"),
    "d7": M("demon_moon", "蚀月", "foe", "atk_down", 0.08, fx2="antiheal", per2=0.08),
    "d8": M("demon_end", "终焉", "foe", "vuln", 0.09, fx2="def_down", per2=0.08),
    "d9": M("demon_tidewell", "渊律", "foe", "slow", 0.09, full="freeze"),
    "d10": M("demon_crown", "焚天", "foe", "elem_taken", 0.09, elem="fire", full="burst", burst=0.24),
    "d11": M("demon_void", "无相", "foe", "vuln", 0.10, fx2="antiheal", per2=0.09),
}
DEMON_ULTS = {
    "d1": U("triple", "熔核三连击，第 3 击在目标有魔炎时轰向全体。", hits=3, ratio=0.75),
    "d2": U("fear", "永夜压低全体攻击，并眩晕层数最高的目标。", pct=0.15),
    "d3": U("roar", "雷岩震慑，全体攻击下降并眩晕前排。", pct=0.12),
    "d4": U("eclipse", "按目标已损失生命追加伤害，并偷取 1 个增益。", per=0.005),
    "d5": U("triple", "赤潮三连击，第 3 击轰向全体。", hits=3, ratio=0.72),
    "d6": U("fear", "霜狱压低全体速度，并眩晕层数最高的目标。", pct=0.14),
    "d7": U("roar", "蚀月震慑，全体攻击下降并眩晕前排。", pct=0.12),
    "d8": U("eclipse", "按目标已损失生命追加伤害，并偷取 1 个增益。", per=0.006),
    "d9": U("roar", "渊律震慑，全体攻击下降并眩晕前排。", pct=0.13),
    "d10": U("triple", "焚天三连击，第 3 击轰向全体。", hits=3, ratio=0.74),
    "d11": U("eclipse", "按目标已损失生命追加伤害，并偷取 1 个增益。", per=0.007),
}
DEMON_ART = {
    "d1": {"body": "demon", "trait": "horn"},
    "d2": {"body": "demon", "trait": "veil"},
    "d3": {"body": "demon", "trait": "boulder"},
    "d4": {"body": "demon", "trait": "wing"},
    "d5": {"body": "demon", "trait": "horn"},
    "d6": {"body": "demon", "trait": "veil"},
    "d7": {"body": "demon", "trait": "boulder"},
    "d8": {"body": "demon", "trait": "wing"},
    "d9": {"body": "demon", "trait": "boulder"},
    "d10": {"body": "demon", "trait": "horn"},
    "d11": {"body": "demon", "trait": "veil"},
}
