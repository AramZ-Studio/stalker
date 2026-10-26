extends PanelContainer

var clock_label: Label
var wallet_label: Label
var meal_label: Label
var hunger_label: Label
var sanity_label: Label
var hunger_bar: ProgressBar
var sanity_bar: ProgressBar
var hunger_fill: StyleBoxFlat
var sanity_fill: StyleBoxFlat

func label(parent: Node, font_size: int) -> Label:
	var result := Label.new()
	result.add_theme_font_size_override("font_size", font_size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func meter(parent: Node) -> ProgressBar:
	var result := ProgressBar.new()
	result.max_value = 100
	result.show_percentage = false
	result.custom_minimum_size = Vector2(120, 7)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.2, 0.27, 0.28, 0.7)
	background.set_corner_radius_all(2)
	result.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("82999a")
	fill.set_corner_radius_all(2)
	result.add_theme_stylebox_override("fill", fill)
	parent.add_child(result)
	return result

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -310
	offset_right = -24
	offset_top = 20
	offset_bottom = 146
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.04, 0.045, 0.66)
	background.border_color = Color(0.5, 0.6, 0.6, 0.2)
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_top = 10
	background.content_margin_bottom = 10
	add_theme_stylebox_override("panel", background)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 6)
	add_child(body)
	clock_label = label(body, 14)
	clock_label.modulate = Color("aabdbb")
	wallet_label = label(body, 16)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	body.add_child(row)
	for kind in ["hunger", "sanity"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 3)
		row.add_child(column)
		var caption := label(column, 13)
		var bar := meter(column)
		if kind == "hunger": hunger_label = caption; hunger_bar = bar
		else: sanity_label = caption; sanity_bar = bar
	hunger_fill = hunger_bar.get_theme_stylebox("fill")
	sanity_fill = sanity_bar.get_theme_stylebox("fill")
	meal_label = label(body, 13)
	hide()

func refresh(state: RefCounted, show_status: bool) -> void:
	visible = show_status
	if not show_status: return
	clock_label.text = state.stamp()
	var money: String = str(state.money)
	for index in range(money.length() - 3, 0, -3): money = money.insert(index, ",")
	wallet_label.text = "₩%s  ·  식량 %d끼" % [money, state.food + state.good_food]
	hunger_label.text = "배고픔 %d/100" % int(state.hunger)
	sanity_label.text = "정신력 %d/100" % int(state.sanity)
	hunger_bar.value = state.hunger
	sanity_bar.value = state.sanity
	hunger_fill.bg_color = Color("c68170") if state.hunger >= 80 else Color("b8b0a0")
	sanity_fill.bg_color = Color("c68170") if state.sanity < 25 else Color("82999a")
	if state.weekly_survival:
		meal_label.text = "오늘 식사 %d회 · %s" % [state.meals_today, "완료" if state.meals_today > 0 else "최소 한 끼 필요"]
		meal_label.modulate = Color("c68170") if state.meals_today == 0 and fmod(state.clock, 24) >= 20 else Color("d2dac2")
	else:
		meal_label.text = "Tab 휴대폰 · 주문과 기록"
		meal_label.modulate = Color("d2dac2")
