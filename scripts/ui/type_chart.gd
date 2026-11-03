extends RefCounted
## In-game 17-type chart. Attack rows, defense columns.


const ORDER := [
	"normal", "fire", "water", "electric", "grass", "ice", "fighting", "poison",
	"ground", "flying", "psychic", "bug", "rock", "ghost", "dragon", "dark", "steel",
]


static func open(screen: Control) -> void:
	if not screen.has_method("show_modal"):
		return
	var body := UI.vbox(8)
	body.add_child(UI.label("行是攻击方，列是防守方。2 克制，½ 被抵抗，0 无效，· 为普通。", 13, UI.MUTED, true))
	var grid := GridContainer.new()
	grid.columns = ORDER.size() + 1
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	grid.add_child(_cell("攻\\防", UI.FAINT))
	for eid in ORDER:
		grid.add_child(_cell(ContentDB.element_name(eid), ContentDB.element_color(eid)))
	for atk in ORDER:
		grid.add_child(_cell(ContentDB.element_name(atk), ContentDB.element_color(atk)))
		for def in ORDER:
			var mult := ContentDB.element_multiplier(atk, def)
			var text := "·"
			var color := UI.FAINT
			if mult >= 1.9:
				text = "2"
				color = UI.DANGER
			elif mult <= 0.01:
				text = "0"
				color = UI.MUTED
			elif mult < 0.9:
				text = "½"
				color = UI.BLUE
			grid.add_child(_cell(text, color))
	body.add_child(grid)
	screen.show_modal("属性克制", body, 980, 480)


static func _cell(text: String, color: Color) -> Label:
	var label := UI.label(text, 12, color)
	label.custom_minimum_size = Vector2(46, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
