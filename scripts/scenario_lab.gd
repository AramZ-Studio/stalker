extends RefCounted

const Catalog = preload("res://scripts/scenario_catalog.gd")
const State = preload("res://scripts/state.gd")
var host: Node3D
var active := false
var page := "none"
var selected := "courier"
var category := "전체"
var config: Dictionary = {}
var toolbar: PanelContainer
var toolbar_label: Label
var navigation: Array[Button] = []

func _init(owner_node: Node3D) -> void:
	host = owner_node

func busy() -> bool:
	return host.activity_transition or (host.presence.view in ["opening", "death"] and not host.modal.visible)

func stop() -> void:
	active = false
	page = "none"
	if is_instance_valid(toolbar): toolbar.hide()

func reset_session() -> void:
	if host.full.active: host.full.stop()
	if host.night.active: host.night.stop()
	host.demo.active = false
	host.demo.automatic = false
	host.game = State.new()
	if is_instance_valid(toolbar): toolbar.hide()
	active = false

func show_list() -> void:
	if busy(): return
	reset_session()
	page = "list"
	host.panel("상황 체험실", "상황을 고르고 시간대·정신력·주문·식량·호신용품을 설정해 바로 체험한다.\n각 체험은 데모와 분리된 새 상태로 시작한다.")
	var groups := OptionButton.new()
	for name in ["전체", "방문", "생활", "조사", "방어", "결말"]: groups.add_item(name)
	groups.select(["전체", "방문", "생활", "조사", "방어", "결말"].find(category))
	groups.item_selected.connect(func(index: int): category = groups.get_item_text(index); show_list())
	host.content.add_child(groups)
	for item in Catalog.CASES:
		if category != "전체" and item.group != category: continue
		var id: String = item.id
		host.button("[%s] %s" % [item.group, item.name], func(): select_case(id))
		var button: Button = host.content.get_child(host.content.get_child_count() - 1)
		button.custom_minimum_size.y = 36
		button.add_theme_font_size_override("font_size", 16)
		compact_styles(button)
	host.button("시작 메뉴", host.show_intro)

func select_case(id: String) -> void:
	selected = id
	config = Catalog.defaults(id)
	show_conditions()

func option(field: String, label: String, labels: Array, values: Array) -> void:
	var row := HBoxContainer.new()
	var caption := Label.new()
	caption.text = label
	caption.custom_minimum_size.x = 150
	row.add_child(caption)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.custom_minimum_size.y = 34
	selector.add_theme_font_size_override("font_size", 16)
	compact_styles(selector)
	for text in labels: selector.add_item(str(text))
	selector.select(maxi(0, values.find(config[field])))
	selector.item_selected.connect(func(index: int): config[field] = values[index])
	row.add_child(selector)
	host.content.add_child(row)

func compact_styles(button: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var background: StyleBoxFlat = host.style(Color("213338") if state == "normal" else Color("34514f"), Color("47615f"), 4)
		background.content_margin_top = 5
		background.content_margin_bottom = 5
		background.content_margin_left = 10
		background.content_margin_right = 10
		button.add_theme_stylebox_override(state, background)

func show_conditions() -> void:
	if busy(): return
	reset_session()
	page = "conditions"
	var item: Dictionary = Catalog.entry(selected)
	host.panel("체험 조건 / " + str(item.name), str(item.hint) + "\n필수 경계 조건 외에는 선택한 값으로 시작한다.\n체험 중 N 상황 진행 · F5 재시작 · F6 조건 · F7 목록")
	if item.group == "결말": host.paragraph("고정 조건: 7일차 23:57 · 매일 식사 완료")
	else: option("day", "날짜", ["1일차", "2일차", "3일차", "4일차", "5일차", "6일차", "7일차"], [0, 1, 2, 3, 4, 5, 6])
	var hours: Array = []
	var times: Array = []
	for hour in range(24): hours.append(hour); times.append("%02d:00" % hour)
	if selected == "daily_meal": host.paragraph("고정 조건: 자정 직전 · 오늘 식사 0회")
	elif item.group != "결말": option("hour", "시간대", times, hours)
	if selected == "sanity": host.paragraph("고정 조건: 정신력 0.05 · 한계 직전")
	else: option("sanity", "정신력", ["매우 낮음 · 10", "낮음 · 20", "불안 · 40", "보통 · 70", "안정 · 100"], [10, 20, 40, 70, 100])
	if selected == "no_food": host.paragraph("고정 조건: 간편식·따뜻한 음식 재고 없음")
	else: option("food", "간편식 재고", ["없음", "1끼", "2끼", "3끼", "6끼"], [0, 1, 2, 3, 6])
	if selected in ["camera_delivery", "defense_delivery"]:
		host.paragraph("고정 배송: 기록 카메라" if selected == "camera_delivery" else "고정 배송: 아래에서 선택한 호신용품")
	elif selected == "delayed_shipping":
		host.paragraph("고정 조건: 일반 물품 주문 완료")
		option("product", "주문한 물품", ["간편식", "기록 카메라"], ["pantry", "camera"])
	else:
		option("order", "주문 내역", ["주문 있음", "주문 없음"], [true, false])
		option("product", "주문한 물품", ["간편식", "따뜻한 음식", "기록 카메라"], ["pantry", "meal", "camera"])
	option("defense", "호신용품", ["없음", "스프레이", "경보기", "손전등"], ["none", "spray", "alarm", "light"])
	host.button("이 조건으로 체험 시작", start_case)
	host.button("상황 목록", show_list)
	host.button("시작 메뉴", host.show_intro)

func build_toolbar() -> void:
	if is_instance_valid(toolbar): toolbar.queue_free()
	navigation.clear()
	toolbar = PanelContainer.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	toolbar.offset_left = 24
	toolbar.offset_right = 490
	toolbar.offset_top = 16
	toolbar.offset_bottom = 106
	toolbar.theme = host.modal.get_parent().theme
	toolbar.add_theme_stylebox_override("panel", host.style(Color(0.025, 0.04, 0.045, 0.82), Color("47615f"), 3))
	host.ui.add_child(toolbar)
	var body := VBoxContainer.new()
	toolbar.add_child(body)
	toolbar_label = Label.new()
	toolbar_label.add_theme_font_size_override("font_size", 13)
	toolbar_label.text = "체험실 · " + str(Catalog.entry(selected).name)
	body.add_child(toolbar_label)
	var row := HBoxContainer.new()
	body.add_child(row)
	navigation.append(host.presence.choice(row, "N 상황 진행", trigger))
	navigation.append(host.presence.choice(row, "F5 다시", start_case))
	navigation.append(host.presence.choice(row, "F6 조건", show_conditions))
	navigation.append(host.presence.choice(row, "F7 목록", show_list))

func start_case() -> void:
	if busy(): return
	if config.is_empty(): config = Catalog.defaults(selected)
	reset_session()
	host.full.start(13, false)
	host.game = Catalog.build(selected, config)
	host.close_panel()
	host.player.rotation = Vector3.ZERO
	host.camera.position = Vector3(0, 1.6, 0)
	host.camera.rotation = Vector3.ZERO
	var item: Dictionary = Catalog.entry(selected)
	host.player.position = Vector3(0, 0.05, -2.8)
	if item.action == "work": host.player.position = Vector3(-3.4, 0.05, -2.8)
	elif item.action == "sleep": host.player.position = Vector3(-2.6, 0.05, 2.3)
	active = true
	page = "playing"
	build_toolbar()
	if item.view == "phone": host.full_phone()
	elif item.view != "room": host.full.observe(str(item.view))
	host.presence.say(str(item.hint), 8)

func trigger() -> void:
	if not active or busy() or host.game.ended: return
	var action: String = Catalog.entry(selected).action
	match action:
		"open": host.full.open(); return
		"work": host.start_action("업무", 4); return
		"sleep": host.start_action("수면", 8); return
		"eat", "tasty": host.full_eat(action == "tasty"); return
		"walk": host.walk(); return
	var result: String = Catalog.perform(host.game, selected)
	if host.game.ended: host.ending()
	else:
		if action == "leave": host.full.observe("인터폰")
		if host.modal.visible: host.message("체험 결과", result, host.full_phone)
		else: host.presence.say(result, 8)

func input(event: InputEvent) -> bool:
	if page in ["list", "conditions"] and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if page == "conditions": show_list()
		else: host.show_intro()
		return true
	if not active or event is not InputEventKey or not event.pressed or event.echo: return false
	match event.keycode:
		KEY_F5: start_case(); return true
		KEY_F6: show_conditions(); return true
		KEY_F7: show_list(); return true
		KEY_N: trigger(); return true
	return false

func update() -> void:
	if not active or not is_instance_valid(toolbar): return
	toolbar.visible = not host.modal.visible
	for button in navigation: button.disabled = busy()
	if navigation.size() > 0: navigation[0].disabled = busy() or host.game.ended

func result_controls() -> void:
	host.button("다시 체험", start_case)
	host.button("조건 변경", show_conditions)
	host.button("상황 목록", show_list)
	host.button("시작 메뉴", host.show_intro)
