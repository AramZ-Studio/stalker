extends RefCounted

const NightState = preload("res://scripts/door_night_state.gd")
const Observation = preload("res://scripts/observation_3d.gd")
const Audio = preload("res://scripts/night_audio.gd")
var host: Node3D
var state: RefCounted
var active := false
var layer: CanvasLayer
var screen: Control
var feed: Control
var backdrop: ColorRect
var reticle: Label
var caption: Label
var status: Label
var hint: Label
var heading: Label
var actions: HBoxContainer
var card: PanelContainer
var card_body: VBoxContainer
var grain: ShaderMaterial
var audio: Node
var view := "room"
var holding := false
var hold_time := 0.0
var looking_time := 0.0
var death_in := -1.0
var muted := false
var flash := 0.0

func _init(owner_node: Node3D) -> void:
	host = owner_node

func start(seed_value: int = -1) -> void:
	if host.full != null: host.full.stop()
	active = true
	state = NightState.new(seed_value)
	state.paused = true
	death_in = -1
	host.ui.hide()
	host.modal.show()
	host.player.position = Vector3(0, 0.05, -0.2)
	host.player.rotation = Vector3.ZERO
	host.camera.rotation = Vector3.ZERO
	for node in host.get_children():
		if node is Label3D: node.hide()
		if node is OmniLight3D:
			node.light_energy = 0.62
			node.shadow_enabled = true
	if layer != null: layer.queue_free()
	if audio != null: audio.queue_free()
	audio = Audio.new()
	host.add_child(audio)
	build_ui()
	show_card("스토커\n문밖의 배달", "비가 오는 밤. 생필품 배송 세 건을 기다리고 있다.\n누군가 배송 기사들의 메시지를 흉내 내고 있다.\n\n포장 두 묶음 이상을 확보하고 동이 틀 때까지 버텨라.\n옷차림이나 송장 번호 하나만으로는 확신할 수 없다.\n\nWASD 이동 · E 상호작용 · Tab 주문 내역\n현관에서 1 인터폰 / 2 렌즈 / 3 귀 기울이기 / 4 대화\n문을 열려면 E 또는 버튼을 1.2초간 누른다.\nEsc 일시정지 · M 소리 켜기/끄기\n\n이 모드는 약 4–6분 동안 실시간으로 진행된다.")
	add_button(card_body, "불을 켜둔 채 기다린다", func(): state.paused = false; room_view())
	add_button(card_body, "시작 화면", exit_to_menu)

func label(text: String, font_size: int = 18) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return item

func anchor(item: Control, preset: int, left: float, top: float, right: float, bottom: float) -> void:
	item.set_anchors_and_offsets_preset(preset)
	item.offset_left = left
	item.offset_top = top
	item.offset_right = right
	item.offset_bottom = bottom

func build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	host.add_child(layer)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The original panel inherits its theme from the root control.
	screen.theme = host.modal.get_parent().theme
	layer.add_child(screen)
	backdrop = ColorRect.new()
	backdrop.color = Color(0.008, 0.012, 0.014, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(backdrop)
	reticle = label("·", 25)
	anchor(reticle, Control.PRESET_CENTER, -8, -16, 8, 16)
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(reticle)
	feed = Control.new()
	anchor(feed, Control.PRESET_FULL_RECT, 50, 88, -50, -248)
	screen.add_child(feed)
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float monitor = 0.0; uniform float flash = 0.0; void fragment(){ vec2 p=UV*2.0-1.0; float edge=smoothstep(0.30,1.3,length(p)); float n=fract(sin(dot(FRAGCOORD.xy+floor(TIME*12.0),vec2(12.9898,78.233)))*43758.5453); float line=step(0.6,fract(UV.y*240.0))*monitor*0.065; COLOR=vec4(vec3(flash*0.3),clamp(edge*0.58+n*0.045+line+flash*0.4,0.0,0.88)); }"
	grain.shader = shader
	overlay.material = grain
	screen.add_child(overlay)
	status = label("", 18)
	anchor(status, Control.PRESET_TOP_WIDE, 34, 24, -34, 64)
	screen.add_child(status)
	heading = label("", 22)
	anchor(heading, Control.PRESET_TOP_WIDE, 50, 62, -50, 90)
	screen.add_child(heading)
	caption = label("", 18)
	anchor(caption, Control.PRESET_BOTTOM_WIDE, 60, -240, -60, -157)
	screen.add_child(caption)
	actions = HBoxContainer.new()
	anchor(actions, Control.PRESET_BOTTOM_WIDE, 50, -146, -50, -98)
	actions.add_theme_constant_override("separation", 7)
	screen.add_child(actions)
	hint = label("", 17)
	anchor(hint, Control.PRESET_BOTTOM_WIDE, 50, -84, -50, -20)
	screen.add_child(hint)
	card = PanelContainer.new()
	anchor(card, Control.PRESET_CENTER, -390, -300, 390, 300)
	screen.add_child(card)
	card_body = VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 12)
	card.add_child(card_body)

func add_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func clear(node: Node) -> void:
	for child in node.get_children():
		if child is SubViewportContainer:
			child.hide()
			child.reparent(host)
			host.retire_snapshot(child)
		else:
			node.remove_child(child)
			child.queue_free()

func show_card(title: String, text: String) -> void:
	holding = false
	hold_time = 0
	clear(card_body)
	card_body.add_child(label(title, 30))
	card_body.add_child(label(text, 18))
	card.show()
	backdrop.show()
	reticle.hide()
	heading.text = ""
	caption.text = ""
	feed.hide()
	actions.hide()
	host.modal.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func room_view() -> void:
	view = "room"
	holding = false
	hold_time = 0
	card.hide()
	backdrop.hide()
	reticle.show()
	feed.hide()
	actions.hide()
	heading.text = ""
	caption.text = ""
	grain.set_shader_parameter("monitor", 0.0)
	host.modal.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func near_door() -> bool:
	return host.player.position.distance_to(Vector3(0.5, 0.05, -4.1)) < 3.6

func interact(target: String) -> void:
	if target in ["현관", "인터폰"]: observe("인터폰")
	elif target == "휴대폰": phone()
	else:
		caption.text = "지금은 집 안에서 배송을 기다려야 한다. 현관과 휴대폰을 확인하자."

func controls() -> void:
	clear(actions)
	add_button(actions, "1 인터폰", func(): observe("인터폰"))
	add_button(actions, "2 렌즈", func(): observe("현관 렌즈"))
	add_button(actions, "3 듣기", listen)
	add_button(actions, "4 묻기", ask)
	add_button(actions, "Tab 주문", phone)
	var opening := add_button(actions, "E 꾹 · 문 열기", func(): pass)
	opening.button_down.connect(func(): holding = true)
	opening.button_up.connect(func(): holding = false; hold_time = 0)
	add_button(actions, "X 물러나기", room_view)
	actions.show()

func observe(source: String) -> void:
	if state.ended or state.paused: return
	view = source
	holding = false
	hold_time = 0
	card.hide()
	backdrop.show()
	reticle.hide()
	host.modal.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear(feed)
	var frame = Observation.new()
	frame.source = source
	frame.uncertain = true
	frame.visitor = "visitor" if (state.camera_person() if source == "인터폰" else state.lens_person()) else ""
	frame.parcel = state.package_visible() and not state.camera_person()
	frame.lurking = state.threat_present() and not state.camera_person()
	frame.peer_count = state.looked
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feed.add_child(frame)
	feed.show()
	heading.text = "현관 카메라  /  CAM 01  ·  NO AUDIO" if source == "인터폰" else "도어 렌즈  /  복도 측면"
	caption.text = state.observation(source)
	grain.set_shader_parameter("monitor", 1.0 if source == "인터폰" else 0.0)
	flash = 0.18
	controls()
	audio.cue("hiss")

func ask() -> void:
	if view == "room": observe("인터폰")
	caption.text = state.ask()
	flash = 0.1

func listen() -> void:
	if view == "room": observe("현관 렌즈")
	caption.text = state.listen()
	audio.cue("shuffle" if state.threat_present() else "steps_away")

func phone() -> void:
	if state.ended: return
	view = "phone"
	var order: Dictionary = state.order()
	var message := "‘문 앞입니다.’" if state.visitor else "새 메시지 없음"
	var text := "야간 배송 예약 3건\n\n현재 주문  %s\n물품  %s\n도착 예정  %s\n\n기사 메시지  %s\n※ 기사 메시지는 배송 완료 인증이 아닙니다.\n\n주문에 없는 물건이나 대면 수령을 요구하면 주의하세요.\n문 앞 화면이 비어도, 양옆과 소리를 확인하세요.\n\n확보한 생필품  %d / 2 묶음 이상" % [order.code, order.items, order.time, message, state.supplies]
	show_card("휴대폰 / 주문 내역", text)
	add_button(card_body, "현관 화면으로" if near_door() else "휴대폰을 넣고 현관으로", func():
		if near_door(): observe("인터폰")
		else: room_view())
	add_button(card_body, "휴대폰 넣기", room_view)

func input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and view == "room" and not state.paused and not state.ended:
		host.player.rotate_y(-event.relative.x * 0.002)
		host.camera.rotation.x = clampf(host.camera.rotation.x - event.relative.y * 0.002, -1.35, 1.35)
	if event is not InputEventKey or event.echo: return
	if event.keycode == KEY_E and not event.pressed:
		holding = false
		hold_time = 0
		return
	if not event.pressed: return
	if event.keycode == KEY_ESCAPE:
		if state.ended: return
		if state.paused: resume()
		else: pause()
		return
	if event.keycode == KEY_M:
		muted = not muted
		audio.set_muted(muted)
		return
	if state.paused or state.ended: return
	if event.keycode == KEY_TAB: phone()
	elif event.keycode == KEY_X: room_view()
	elif event.keycode == KEY_E:
		if view == "room":
			if near_door(): observe("인터폰")
			elif not host.focused.is_empty(): interact(host.focused)
		elif view != "phone": holding = true
	elif near_door() or view not in ["room", "phone"]:
		match event.keycode:
			KEY_1: observe("인터폰")
			KEY_2: observe("현관 렌즈")
			KEY_3: listen()
			KEY_4: ask()

func update(delta: float) -> void:
	if not active: return
	if death_in > 0:
		death_in -= delta
		if death_in <= 0: show_ending()
	state.tick(delta)
	if not state.paused and not state.ended:
		looking_time = looking_time + delta if view not in ["room", "phone"] else 0.0
		audio.update(delta, looking_time > 5)
		if holding:
			hold_time += delta
			if hold_time >= 1.2: open()
		else: hold_time = 0
	for event in state.events:
		audio.cue(event)
		if event == "bell": flash = 0.12
		if event in ["shuffle", "steps_away"] and view not in ["room", "phone"]:
			# A still image does not silently update. Re-check to see the change.
			caption.text = state.notes[0] + "\n다시 확인하면 화면의 모습이 달라질 수 있다."
	state.events.clear()
	flash = maxf(0, flash - delta)
	grain.set_shader_parameter("flash", flash)
	status.text = "%s    /    스토커    ·    생필품 %d / 2    ·    밤을 버텨라" % [state.clock_text(), state.supplies]
	if muted: status.text += "    [음소거]"
	if hold_time > 0:
		hint.text = "잠금 해제 중   " + "▰".repeat(int(hold_time / 1.2 * 12)) + "▱".repeat(12 - int(hold_time / 1.2 * 12)) + "   손을 떼면 취소"
	elif view == "room":
		hint.text = ("E 현관 확인 / 1 인터폰 / 2 렌즈" if near_door() else "WASD 이동 · E 사물 확인 · Tab 주문 내역") + "\n" + (state.notes[0] if not state.notes.is_empty() else "")
	else: hint.text = "화면은 확인한 순간의 모습이다. 다시 확인하면 바뀔 수 있다.    ·    E 1.2초 유지: 문 열기    ·    Esc 일시정지"
	if state.ended and death_in < 0: show_ending()

func open() -> void:
	holding = false
	hold_time = 0
	var result: String = state.open_door()
	audio.cue("unlock")
	if result == "death":
		audio.cue("death")
		death_in = 1.7
		card.hide()
		clear(feed)
		var frame = Observation.new()
		frame.source = "조우"
		frame.visitor = "stalker"
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		feed.add_child(frame)
		feed.show()
		backdrop.show()
		reticle.hide()
		actions.hide()
		heading.text = "문이, 안쪽으로 밀린다."
		caption.text = ""
		flash = 0.5
	elif result == "collected":
		animate_door()
		room_view()
	else:
		caption.text = "문 앞에는 아무것도 없었다. 조용히 다시 잠갔다."

func animate_door() -> void:
	if not is_instance_valid(host.entrance_hinge): return
	var tween := host.create_tween()
	tween.tween_property(host.entrance_hinge, "rotation:y", -0.55, 0.28)
	tween.tween_interval(0.3)
	tween.tween_property(host.entrance_hinge, "rotation:y", 0.0, 0.45)

func pause() -> void:
	state.paused = true
	audio.set_muted(true)
	show_card("잠깐, 숨을 고른다", "시간과 방문은 멈춰 있다.\n\n화면에 사람이 없다는 것만으로 안전을 판단하지 마라.\n주문 물품과 상대의 말을 비교하고, 떠나는 소리를 확인하라.")
	add_button(card_body, "계속하기", resume)
	add_button(card_body, "이번 밤 다시 시작", func(): stop(); start())
	add_button(card_body, "시작 화면", exit_to_menu)

func resume() -> void:
	state.paused = false
	audio.set_muted(muted)
	room_view()

func show_ending() -> void:
	death_in = 0
	audio.set_muted(true)
	show_card("06:03 / 문밖이 밝아졌다" if state.won else "문밖의 사람", state.reason + "\n\n확보한 생필품 %d묶음  /  놓친 배송 %d건\n\n다시 시작하면 방문 순서가 달라진다." % [state.supplies, state.missed])
	add_button(card_body, "다른 밤 다시 시작", func(): stop(); start())
	add_button(card_body, "시작 화면", exit_to_menu)

func stop() -> void:
	active = false
	if is_instance_valid(audio): audio.stop_all()

func exit_to_menu() -> void:
	stop()
	host.get_tree().reload_current_scene()
