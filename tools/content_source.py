# -*- coding: utf-8 -*-
"""Canonical game content for 灵契·星塔远征.

All names, art and numbers in this project are original.  The game is a
mechanical homage to the classic pet-collecting tower climbers of the 2010s,
not a copy of any existing title's assets or data.
"""
import hashlib

ELEMENTS = {
    "fire":  {"name": "火", "color": "#ff7043", "beats": ["wind"],  "loses_to": ["water"]},
    "water": {"name": "水", "color": "#41a6ff", "beats": ["fire"],  "loses_to": ["earth"]},
    "wind":  {"name": "风", "color": "#3ddc97", "beats": ["earth"], "loses_to": ["fire"]},
    "earth": {"name": "土", "color": "#d9a94c", "beats": ["water"], "loses_to": ["wind"]},
    "light": {"name": "光", "color": "#ffd76a", "beats": ["dark"],  "loses_to": [], "mutual": ["dark"]},
    "dark":  {"name": "暗", "color": "#a875ff", "beats": ["light"], "loses_to": [], "mutual": ["light"]},
}

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

# name, element, class
PET_SEEDS = [
    # fire (9)
    ("焰狐", "fire", "warrior"),
    ("赤雀", "fire", "archer"),
    ("熔岩獾", "fire", "guardian"),
    ("火绒猫", "fire", "support"),
    ("烬狼", "fire", "warrior"),
    ("烈阳鹿", "fire", "mage"),
    ("炎角犀", "fire", "guardian"),
    ("焚羽鹰", "fire", "archer"),
    ("琥珀蜥", "fire", "mage"),
    # water (9)
    ("水泡獭", "water", "support"),
    ("碧波豚", "water", "mage"),
    ("潮汐龟", "water", "guardian"),
    ("珊瑚蟹", "water", "guardian"),
    ("霜鳍鲨", "water", "warrior"),
    ("蓝鲸崽", "water", "support"),
    ("雾雨蛙", "water", "mage"),
    ("涟漪鳗", "water", "archer"),
    ("冰晶水母", "water", "mage"),
    # wind (8)
    ("风铃鼠", "wind", "archer"),
    ("疾羽鸢", "wind", "archer"),
    ("云朵羊", "wind", "support"),
    ("旋岚貂", "wind", "warrior"),
    ("惊雷燕", "wind", "mage"),
    ("青岚鹿", "wind", "support"),
    ("蒲公英兔", "wind", "mage"),
    ("逐风狼", "wind", "warrior"),
    # earth (8)
    ("岩壳龟", "earth", "guardian"),
    ("泥土熊", "earth", "guardian"),
    ("砂砾鼠", "earth", "archer"),
    ("晶石蜥", "earth", "mage"),
    ("藤蔓蟒", "earth", "warrior"),
    ("苔藓牛", "earth", "guardian"),
    ("蘑菇蛙", "earth", "support"),
    ("琥珀蚁", "earth", "archer"),
    # light (8)
    ("光羽雀", "light", "archer"),
    ("晨曦鹿", "light", "support"),
    ("圣辉猫", "light", "warrior"),
    ("日冕狮", "light", "warrior"),
    ("莹光蛾", "light", "mage"),
    ("金铃羊", "light", "support"),
    ("星尘狐", "light", "mage"),
    ("白昼鸽", "light", "archer"),
    # dark (8)
    ("影刃豹", "dark", "warrior"),
    ("幽夜鸦", "dark", "archer"),
    ("暮色蝠", "dark", "mage"),
    ("暗焰犬", "dark", "warrior"),
    ("幻梦蛛", "dark", "support"),
    ("蚀月蛇", "dark", "mage"),
    ("黑雾猫", "dark", "archer"),
    ("夜巡枭", "dark", "guardian"),
]

STARTER_IDS = ["p01", "p10", "p19"]  # 焰狐 / 水泡獭 / 风铃鼠

EVO_PREFIX = {
    "fire":  ["", "炎·", "焚天·"],
    "water": ["", "碧波·", "沧海·"],
    "wind":  ["", "疾风·", "天穹·"],
    "earth": ["", "磐岩·", "大地·"],
    "light": ["", "圣辉·", "耀世·"],
    "dark":  ["", "幽影·", "永夜·"],
}
EVO_SUFFIX = ["", "", "王"]

NORMAL_NAMES = {
    "fire":  {"guardian": "火盾击", "warrior": "焰刃斩", "mage": "火花弹", "archer": "焰羽箭", "support": "暖心灵息"},
    "water": {"guardian": "碧潮盾击", "warrior": "潮刃斩", "mage": "水泡弹", "archer": "霜羽箭", "support": "润泽灵息"},
    "wind":  {"guardian": "岚风盾击", "warrior": "风刃斩", "mage": "风旋弹", "archer": "疾风箭", "support": "清风灵息"},
    "earth": {"guardian": "岩壳盾击", "warrior": "裂地斩", "mage": "岩刺弹", "archer": "砂砾箭", "support": "大地灵息"},
    "light": {"guardian": "圣光盾击", "warrior": "圣辉斩", "mage": "光矢弹", "archer": "光羽箭", "support": "晨光灵息"},
    "dark":  {"guardian": "暗影盾击", "warrior": "暗刃斩", "mage": "影球弹", "archer": "暗羽箭", "support": "夜歌灵息"},
}
ULT_PREFIX = {"fire": "烈焰", "water": "碧涛", "wind": "青岚", "earth": "裂地", "light": "圣辉", "dark": "暗蚀"}
ULT_BASE = {"guardian": "壁垒", "warrior": "破军", "mage": "风暴", "archer": "狙击", "support": "赞歌"}

ELEMENT_ULT_TEXT = {
    "fire": "并附加 2 回合灼烧",
    "water": "并使目标减速 2 回合",
    "wind": "并提升自身速度 2 回合",
    "earth": "并降低目标防御 2 回合",
    "light": "并为友方附加护盾",
    "dark": "并降低目标攻击 2 回合",
}

SKILL_DESC = {
    "guardian": ("重盾猛击前排，自身获得少量护盾。", "击退前排目标，自身获得 20% 最大生命护盾，{extra}。"),
    "warrior": ("挥刃攻击敌方前排。", "对前排目标造成 2.6 倍重击，并溅射 30% 伤害至相邻敌人，{extra}。"),
    "mage": ("凝聚元素弹攻击敌方后排。", "对最多 3 名敌人造成 1.35 倍元素风暴，{extra}。"),
    "archer": ("射出一箭，优先攻击残血敌人。", "狙击生命最低的敌人，造成 2.4 倍伤害且暴击率 +30%，{extra}。"),
    "support": ("攻击前排，并为生命最低的友方回复少量生命。", "为全体友方回复 15% 最大生命并提升 10% 攻击，{extra}。"),
}


def _stat_var(pid: str) -> float:
    h = int(hashlib.md5(pid.encode("utf-8")).hexdigest()[:8], 16)
    return 0.94 + (h % 13) / 100.0


def make_pets():
    pets = []
    for i, (name, element, cls) in enumerate(PET_SEEDS, start=1):
        pid = f"p{i:02d}"
        var = _stat_var(pid)
        base = CLASSES[cls]
        stage_names = [EVO_PREFIX[element][0] + name,
                       EVO_PREFIX[element][1] + name,
                       EVO_PREFIX[element][2] + name + EVO_SUFFIX[2]]
        normal = {
            "id": f"n_{pid}",
            "name": NORMAL_NAMES[element][cls],
            "kind": "normal",
            "target": CLASSES[cls]["target"],
            "mult": 0.9 if cls in ("guardian", "support") else (0.95 if cls == "mage" else 1.0),
            "desc": SKILL_DESC[cls][0],
        }
        ult = {
            "id": f"u_{pid}",
            "name": ULT_PREFIX[element] + ULT_BASE[cls],
            "kind": "ult_" + cls,
            "target": CLASSES[cls]["target"],
            "mult": {"guardian": 1.8, "warrior": 2.6, "mage": 1.35, "archer": 2.4, "support": 0.0}[cls],
            "splash": 0.3 if cls == "warrior" else 0.0,
            "desc": SKILL_DESC[cls][1].format(extra=ELEMENT_ULT_TEXT[element]),
        }
        pets.append({
            "id": pid,
            "names": stage_names,
            "element": element,
            "class": cls,
            "starter": pid in STARTER_IDS,
            "stats": {
                "hp": round(base["hp"] * var),
                "atk": round(base["atk"] * var),
                "def": round(base["def"] * var),
                "spd": round(base["spd"] * var),
            },
            "skills": {"normal": normal, "ultimate": ult},
        })
    return pets


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
    {"id": "rage_fuel",    "name": "燃魂",     "rarity": "epic",   "desc": "使用后额外获得 1 点气势。", "value": 1},
]
RARITY_WEIGHT = {"common": 60, "rare": 30, "epic": 10}

ITEMS = [
    {"id": "hp_charm",       "name": "生命护符", "rarity": "common", "desc": "全队最大生命 +12%。", "stat": "hp", "value": 0.12},
    {"id": "atk_charm",      "name": "力量护符", "rarity": "common", "desc": "全队攻击 +10%。", "stat": "atk", "value": 0.10},
    {"id": "def_charm",      "name": "铁壁护符", "rarity": "common", "desc": "全队防御 +15%。", "stat": "def", "value": 0.15},
    {"id": "spd_boots",      "name": "疾风之靴", "rarity": "common", "desc": "全队速度 +10%。", "stat": "spd", "value": 0.10},
    {"id": "vampire_fang",   "name": "吸血獠牙", "rarity": "rare",   "desc": "全队攻击吸血 +10%。", "hook": "lifesteal", "value": 0.10},
    {"id": "crit_eye",       "name": "暴击之瞳", "rarity": "rare",   "desc": "全队暴击率 +10%。", "hook": "crit", "value": 0.10},
    {"id": "tide_pendant",   "name": "潮汐吊坠", "rarity": "rare",   "desc": "每回合开始全体回复 2% 最大生命。", "hook": "regen", "value": 0.02},
    {"id": "rage_amulet",    "name": "战意项链", "rarity": "common", "desc": "战斗开始全员气势 +1。", "hook": "start_rage", "value": 1},
    {"id": "thorn_mail",     "name": "荆棘之甲", "rarity": "rare",   "desc": "受到攻击时反弹 12% 伤害。", "hook": "reflect", "value": 0.12},
    {"id": "phoenix_feather", "name": "不死羽",  "rarity": "epic",   "desc": "每只精灵一次：受到致死伤害后保留 1 点生命。", "hook": "last_stand", "value": 1},
    {"id": "giant_slayer",   "name": "屠龙徽记", "rarity": "rare",   "desc": "对 Boss 造成的伤害 +25%。", "hook": "vs_boss", "value": 0.25},
    {"id": "arcane_core",    "name": "秘法核心", "rarity": "rare",   "desc": "大招伤害 +20%。", "hook": "ult_damage", "value": 0.20},
    {"id": "dual_strike",    "name": "双生指环", "rarity": "rare",   "desc": "普通攻击 20% 概率追加一次 50% 伤害。", "hook": "double_normal", "value": 0.20},
    {"id": "flame_heart",    "name": "烈焰之心", "rarity": "rare",   "desc": "攻击附加 2 回合灼烧（每回合 4% 攻击力）。", "hook": "burn_on_hit", "value": 0.04},
    {"id": "frost_heart",    "name": "寒冰之心", "rarity": "rare",   "desc": "攻击使目标速度 -10%，持续 2 回合。", "hook": "slow_on_hit", "value": 0.10},
    {"id": "hunter_mark",    "name": "猎手印记", "rarity": "rare",   "desc": "对生命低于 40% 的敌人伤害 +20%。", "hook": "execute", "value": 0.20},
    {"id": "guardian_angel", "name": "守护天使", "rarity": "rare",   "desc": "战斗开始时全队获得 8% 最大生命护盾。", "hook": "start_shield", "value": 0.08},
    {"id": "resonance_core", "name": "共鸣水晶", "rarity": "epic",   "desc": "重复精灵的共鸣加成 +50%。", "hook": "resonance", "value": 0.50},
    {"id": "lucky_coin",     "name": "幸运金币", "rarity": "rare",   "desc": "道具宝箱判定概率 +15%。", "hook": "item_luck", "value": 0.15},
    {"id": "nourish_seed",   "name": "森林之种", "rarity": "common", "desc": "全队防御 +8%，每回合回复 1.5% 最大生命。", "stat": "def", "value": 0.08, "hook": "regen", "hook_value": 0.015},
]

TRAINERS = [
    {"id": "novice", "name": "新手训练家", "title": "初次启程", "color": "#7ed6a5",
     "desc": "全队最大生命 +12%，开局获得 1 件随机道具。",
     "mods": {"hp_mult": 0.12}, "start_items": 1, "item_bonus": 0.0},
    {"id": "veteran", "name": "高玩训练家", "title": "老练指挥", "color": "#ffb35c",
     "desc": "全队攻击 +12%，道具宝箱判定概率 +10%。",
     "mods": {"atk_mult": 0.12}, "start_items": 0, "item_bonus": 0.10},
    {"id": "master", "name": "大神训练家", "title": "天赋异禀", "color": "#c49bff",
     "desc": "全队速度 +12%、暴击率 +8%，初始精灵自带 1 条随机词条。",
     "mods": {"spd_mult": 0.12, "crit": 0.08}, "start_items": 0, "item_bonus": 0.0, "start_affix": 1},
]

BOSS_BUFF_POOL = [
    {"id": "frenzy",    "name": "狂暴",     "desc": "攻击 +25%。"},
    {"id": "undying",   "name": "不灭",     "desc": "最大生命 +30%。"},
    {"id": "bedrock",   "name": "磐石",     "desc": "防御 +25%。"},
    {"id": "swift",     "name": "疾影",     "desc": "速度 +20%。"},
    {"id": "bloodthirst","name": "嗜血",    "desc": "攻击吸血 20%。"},
    {"id": "barbed",    "name": "荆棘",     "desc": "反弹 12% 受到的伤害。"},
    {"id": "renewal",   "name": "复苏",     "desc": "每回合回复 5% 最大生命。"},
    {"id": "oppress",   "name": "威压",     "desc": "敌方全体攻击 -10%。"},
    {"id": "warded",    "name": "元素护体", "desc": "受到伤害 -10%。"},
    {"id": "surge",     "name": "狂潮",     "desc": "大招伤害 +30%。"},
]

BOSSES = [
    {"id": "b1", "name": "熔核领主·赫岩", "element": "fire", "class": "guardian",
     "level_offset": 2, "stat_mult": {"hp": 1.85, "atk": 2.10, "def": 1.40, "spd": 0.95},
     "buff_count": 1, "phases": [], "tier": 1,
     "skills": {
         "normal": {"id": "n_b1", "name": "熔岩重锤", "kind": "normal", "target": "front", "mult": 1.0,
                    "desc": "重锤前排，附加灼烧。"},
         "ultimate": {"id": "u_b1", "name": "熔核震击", "kind": "ult_boss_aoe", "target": "front", "mult": 1.55,
                      "desc": "震荡最多 3 名敌人并附加灼烧。"}}},
    {"id": "b2", "name": "幽夜女巫·瑟琳", "element": "dark", "class": "mage",
     "level_offset": 2, "stat_mult": {"hp": 2.35, "atk": 2.25, "def": 1.25, "spd": 1.10},
     "buff_count": 1, "phases": [], "tier": 1,
     "skills": {
         "normal": {"id": "n_b2", "name": "暮影弹", "kind": "normal", "target": "back", "mult": 1.0,
                    "desc": "攻击后排并降低攻击。"},
         "ultimate": {"id": "u_b2", "name": "永夜帷幕", "kind": "ult_boss_aoe", "target": "all", "mult": 1.70,
                      "desc": "对全体敌人造成暗影伤害并降低攻击。"}}},
    {"id": "b3", "name": "星蚀龙皇·奥瑞恩", "element": "dark", "class": "warrior",
     "level_offset": 3, "stat_mult": {"hp": 2.40, "atk": 2.35, "def": 1.55, "spd": 1.05},
     "buff_count": 2, "tier": 2,
     "phases": [
         {"hp_pct": 0.70, "buff": "frenzy", "text": "龙皇的血液沸腾了！攻击力大幅提升！"},
         {"hp_pct": 0.40, "buff": "swift", "text": "星蚀之力爆发！龙皇的速度与气势攀升至极限！"}],
     "skills": {
         "normal": {"id": "n_b3", "name": "星蚀爪", "kind": "normal", "target": "front", "mult": 1.1,
                    "desc": "撕裂前排，附加易伤。"},
         "ultimate": {"id": "u_b3", "name": "星蚀灭世", "kind": "ult_boss_aoe", "target": "all", "mult": 2.0,
                      "desc": "对最多 3 名敌人造成毁灭打击并施加易伤。"}}},
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
}

FLOOR_POOLS = {
    1: ["fire", "earth"],
    2: ["water", "wind"],
    3: ["wind", "light"],
    4: ["fire", "earth"],
    5: ["wind", "light"],
    6: ["earth", "fire"],
    7: ["light", "water"],
    8: ["dark", "wind"],
    9: ["dark", "water", "fire"],
    10: ["dark", "light"],
}
FLOOR_MAPS = {
    1: "lava", 2: "ocean", 3: "sky", 4: "storm", 5: "forest",
    6: "desert", 7: "temple", 8: "night", 9: "void", 10: "throne",
}
FLOOR_NAMES = {
    1: "第一层 · 熔岩峡谷", 2: "第二层 · 幽蓝深海", 3: "第三层 · 天空浮岛",
    4: "第四层 · 雷鸣裂谷", 5: "第五层 · 远古森林", 6: "第六层 · 荒芜沙海",
    7: "第七层 · 星辉圣殿", 8: "第八层 · 永夜回廊", 9: "第九层 · 虚空裂隙",
    10: "第十层 · 星蚀王座",
}
FLOOR_COUNTS = {1: 1, 2: 2, 3: 3, 4: 5, 5: 5, 6: 5, 7: 5, 8: 5, 9: 5, 10: 5}
BOSS_FLOORS = {4: "b1", 8: "b2", 10: "b3"}


def make_floors(pets):
    by_element = {}
    for p in pets:
        by_element.setdefault(p["element"], []).append(p["id"])
    floors = []
    for f in range(1, 11):
        pool = []
        for el in FLOOR_POOLS[f]:
            pool.extend(by_element[el])
        is_boss = f in BOSS_FLOORS
        floors.append({
            "floor": f,
            "name": FLOOR_NAMES[f],
            "map": FLOOR_MAPS[f],
            "kind": "boss" if is_boss else "normal",
            "enemy_count": FLOOR_COUNTS[f],
            "level": f * 10,
            "pool": sorted(set(pool)),
            "boss": BOSS_FLOORS.get(f),
            "minion_count": 4 if is_boss else 0,
            "minion_level_offset": -5 if is_boss else 0,
            "minion_stat_mult": (0.90 if f == 8 else 0.80) if is_boss else 1.0,
            "enemy_stat_mult": 0.80 if f <= 2 else (0.90 if f == 3 else (0.92 if f in (5, 6, 7) else (1.03 if f == 9 else 1.0))),
            "elite": is_boss,
        })
    return floors


FORMATION = {
    "row_damage": {"0": 1.20, "1": 1.00, "2": 0.85},
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
    },
}

COMBAT = {
    "level_steps": {"hp": 0.050, "atk": 0.060, "def": 0.050, "spd": 0.020},
    "max_level": 100,
    "level_up_per_floor": 10,
    "base_level": 10,
    "evo_levels": [30, 60],
    "evo_mult": [1.0, 1.25, 1.55],
    "def_coefficient": 0.40,
    "rage_max": 2,
    "crit_base": 0.05,
    "crit_mult": 1.6,
    "element_advantage": 1.25,
    "element_disadvantage": 0.80,
    "chest_pet_chance": 1.0,
    "chest_item_chance": 0.5,
    "chest_affix_chance": 0.25,
    "affix_weights": RARITY_WEIGHT,
    "item_weights": {"common": 50, "rare": 35, "epic": 15},
    "affix_max_per_skill": 3,
    "affix_max_per_pet": 6,
    "resonance_bonus": 0.08,
    "max_rounds": 60,
}

STARTER_NOTES = {
    "p01": "火系战士，稳健的前排核心，大招带溅射。",
    "p10": "水系辅助，普攻即可治疗，续航极佳。",
    "p19": "风系射手，高速狙击残血，收割利器。",
}


def build_content():
    pets = make_pets()
    starters = []
    for pid in STARTER_IDS:
        pet = next(p for p in pets if p["id"] == pid)
        starters.append({"id": pid, "note": STARTER_NOTES[pid]})
    return {
        "version": 1,
        "title": "灵契·星塔远征",
        "subtitle": "怀旧肉鸽爬塔",
        "meta": {
            "pets": len(pets), "affixes": len(AFFIXES), "items": len(ITEMS),
            "bosses": len(BOSSES), "floors": 10,
            "note": "All names and vector art are original; no third-party assets are bundled.",
        },
        "elements": ELEMENTS,
        "classes": CLASSES,
        "trainers": TRAINERS,
        "starters": starters,
        "pets": pets,
        "affixes": AFFIXES,
        "items": ITEMS,
        "bosses": BOSSES,
        "boss_buff_pool": BOSS_BUFF_POOL,
        "maps": MAPS,
        "floors": make_floors(pets),
        "formation": FORMATION,
        "combat": COMBAT,
    }


if __name__ == "__main__":
    import json
    print(json.dumps(build_content(), ensure_ascii=False, indent=2)[:2000])
