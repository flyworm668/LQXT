extends Node
## Shared visual language: theme, colors and small UI factories.

const BG := Color("#080c14")
const BG2 := Color("#0f1728")
const PANEL := Color("#131c2e")
const PANEL2 := Color("#1a2740")
const PANEL3 := Color("#22324f")
const BORDER := Color("#2b3c5c")
const TEXT := Color("#e9eef9")
const MUTED := Color("#8e9cb6")
const FAINT := Color("#5c6b85")
const ACCENT := Color("#ff8a4c")
const ACCENT_DARK := Color("#c45a2a")
const GOLD := Color("#ffd166")
const DANGER := Color("#ff5d6c")
const GOOD := Color("#5be0a0")
const BLUE := Color("#5bb8ff")
const PURPLE := Color("#c98bff")

const PetAvatarScript = preload("res://scripts/ui/pet_avatar.gd")
const BackdropScript = preload("res://scripts/ui/backdrop.gd")

var theme: Theme


func _ready() -> void:
	theme = build_theme()


func soft_style(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0,
		radius: int = 12, margin: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


func _cjk_font() -> Font:
	var path := "res://fonts/NotoSansCJKsc-Regular.otf"
	if ResourceLoader.exists(path):
		var loaded: Font = load(path)
		if loaded != null:
			return _bold(loaded)
	if FileAccess.file_exists(path):
		var file := FontFile.new()
		if file.load_dynamic_font(path) == OK:
			file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			return _bold(file)
	push_warning("中文字体读取失败，退回系统字体")
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Songti SC",
		"Noto Sans CJK SC", "Arial Unicode MS",
	])
	font.font_weight = 700
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _bold(font)


func _bold(base: Font) -> Font:
	var varied := FontVariation.new()
	varied.base_font = base
	varied.variation_embolden = 0.85
	return varied


func build_theme() -> Theme:
	var t := Theme.new()
	var font := _cjk_font()
	t.default_font = font
	t.default_font_size = 19

	var normal := soft_style(PANEL2, BORDER, 1, 10, 14)
	var hover := soft_style(PANEL3, ACCENT.darkened(0.15), 1, 10, 14)
	var pressed := soft_style(PANEL, ACCENT, 1, 10, 14)
	var disabled := soft_style(Color("#111827"), BORDER.darkened(0.3), 1, 10, 14)
	var focus := soft_style(Color(0, 0, 0, 0), ACCENT, 1, 10, 14)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = normal
		match state:
			"hover": box = hover
			"pressed": box = pressed
			"disabled": box = disabled
			"focus": box = focus
		t.set_stylebox(state, "Button", box)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", FAINT)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 20)

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("panel", "PanelContainer", soft_style(PANEL, BORDER, 1, 14, 16))
	t.set_stylebox("panel", "Panel", soft_style(PANEL, BORDER, 1, 14, 16))

	t.set_stylebox("background", "ProgressBar", soft_style(Color("#0b1220"), Color.TRANSPARENT, 0, 6, 0))
	t.set_stylebox("fill", "ProgressBar", soft_style(ACCENT, Color.TRANSPARENT, 0, 6, 0))
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	t.set_font_size("font_size", "ProgressBar", 12)

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_constant("line_separation", "RichTextLabel", 4)
	t.set_font_size("normal_font_size", "RichTextLabel", 19)

	t.set_stylebox("panel", "PopupPanel", soft_style(PANEL, BORDER, 1, 14, 16))
	t.set_stylebox("panel", "TooltipPanel", soft_style(Color("#0d1524"), BORDER, 1, 8, 10))
	return t


func label(text: String, size: int = 19, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size + 2)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 100
	return l


func rich(text: String, size: int = 19, color: Color = TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_size_override("normal_font_size", size + 2)
	r.add_theme_color_override("default_color", color)
	return r


func panel(bg: Color = PANEL, border: Color = BORDER, radius: int = 14, margin: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", soft_style(bg, border, 1 if border.a > 0 else 0, radius, margin))
	return p


func panel_with(style: StyleBoxFlat) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	return p


func button(text: String, accent: Color = Color.TRANSPARENT, size: int = 20) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", size + 2)
	if accent.a > 0:
		var n := soft_style(accent, accent.lightened(0.2), 1, 10, 14)
		var h := soft_style(accent.lightened(0.12), Color.WHITE, 1, 10, 14)
		var p := soft_style(accent.darkened(0.15), accent, 1, 10, 14)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", p)
		b.add_theme_color_override("font_color", Color("#14110d"))
		b.add_theme_color_override("font_hover_color", Color("#0b0907"))
		b.add_theme_color_override("font_pressed_color", Color("#14110d"))
	return b


func ghost_button(text: String, size: int = 15) -> Button:
	var b := button(text, Color.TRANSPARENT, size)
	b.custom_minimum_size = Vector2(0, 34)
	var n := soft_style(Color(0, 0, 0, 0), BORDER, 1, 8, 10)
	var h := soft_style(Color(1, 1, 1, 0.06), ACCENT, 1, 8, 10)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	return b


func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func spacer(w: float = 0, h: float = 0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func grow() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func pill(text: String, color: Color, size: int = 12) -> PanelContainer:
	var p := panel(Color(color.r, color.g, color.b, 0.14), Color(color.r, color.g, color.b, 0.38), 8, 7)
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


func avatar(pid: String, size: float = 72.0, level: int = 10, boss: bool = false, enemy: bool = false) -> Control:
	var a: Control = PetAvatarScript.new()
	a.setup(pid, size, level, boss, enemy)
	return a


func backdrop(map_id: String) -> Control:
	var b: Control = BackdropScript.new()
	b.setup(map_id)
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func fade_in(c: Control, duration: float = 0.28) -> void:
	c.modulate.a = 0.0
	var t := c.create_tween()
	t.tween_property(c, "modulate:a", 1.0, duration)


func fit_width(c: Control, min_w: float) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size.x = min_w
	return c


func hline(color: Color = BORDER, height: float = 1.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func tooltip(control: Control, text: String) -> void:
	control.tooltip_text = text
	control.mouse_filter = Control.MOUSE_FILTER_STOP


func hp_color(ratio: float) -> Color:
	if ratio > 0.55:
		return GOOD
	if ratio > 0.28:
		return GOLD
	return DANGER
