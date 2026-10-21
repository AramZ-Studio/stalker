extends Node3D

const State = preload("res://scripts/state.gd")
const Observation = preload("res://scripts/observation_3d.gd")
const Demo = preload("res://scripts/demo.gd")
var demo: RefCounted
var game = State.new()
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var prompt: Label
var notice: Label
var modal: PanelContainer
var content: VBoxContainer
var shade: ColorRect
var targets: Array[Dictionary] = []
var focused := ""
var ui: CanvasLayer
var tone: AudioStreamPlayer
var last_bell := ""

func _ready() -> void:
	build_room()
	build_ui()
	demo = Demo.new(self)
	game.log_entry("경찰: ‘용의자를 추적 중입니다. 3일차 06시까지 문단속하세요. 특징이나 차량을 보면 제보해주세요.’")
	game.log_entry("배송은 주문 1시간 후 도착하며, 3시간 내 회수해야 한다. 식량 2개와 42,000원이 있다.")
	show_intro()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	elif "--capture-preview" in OS.get_cmdline_user_args():
		call_deferred("capture_preview")
	elif "--test-demos" in OS.get_cmdline_user_args():
		call_deferred("test_demos")

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
	return mat

func block(pos: Vector3, dimensions: Vector3, color: Color, solid: bool = true, glow: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material(color, glow)
	mesh.position = pos
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = dimensions
		shape.shape = box_shape
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

func station(label: String, pos: Vector3, color: Color) -> void:
	targets.append({"name": label, "position": pos})
	var title := Label3D.new()
	title.text = label
	title.font_size = 38
	title.pixel_size = 0.004
	title.position = pos + Vector3(0, 0.55, 0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = color
	title.no_depth_test = false
	add_child(title)

func build_room() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("080e16")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("9daeb5")
	settings.ambient_light_energy = 0.36
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	block(Vector3(0, -0.15, 0), Vector3(10, 0.3, 10), Color("49463c"))
	block(Vector3(0, 3.1, 0), Vector3(10, 0.2, 10), Color("454945"))
	for x in [-5.0, 5.0]:
		block(Vector3(x, 1.5, 0), Vector3(0.2, 3, 10), Color("575e55"))
	for z in [-5.0, 5.0]:
		block(Vector3(0, 1.5, z), Vector3(10, 3, 0.2), Color("575e55"))
	for i in range(20):
		block(Vector3(-4.75 + i * 0.5, 0.008, 0), Vector3(0.015, 0.01, 10), Color("252a27"), false)
	# Entry, intercom and peephole.
	block(Vector3(0, 1.23, -4.84), Vector3(1.4, 2.46, 0.12), Color("292e2c"))
	block(Vector3(0.5, 1.0, -4.7), Vector3(0.12, 0.06, 0.08), Color("b3ab87"), false)
	block(Vector3(0, 1.65, -4.7), Vector3(0.07, 0.07, 0.08), Color("869e92"), false, true)
	station("현관", Vector3(0, 1.1, -4.6), Color("c2c5ac"))
	block(Vector3(1.5, 1.5, -4.76), Vector3(0.42, 0.55, 0.17), Color("b6b9a9"))
	block(Vector3(1.5, 1.57, -4.65), Vector3(0.3, 0.22, 0.03), Color("75a28c"), false, true)
	station("인터폰", Vector3(1.5, 1.5, -4.5), Color("92c8b6"))
	preload("res://scripts/furnished_room.gd").furnish(self)
	for pos in [Vector3(0, 2.7, 0), Vector3(-3.3, 2.4, -3.6)]:
		var light := OmniLight3D.new()
		light.position = pos
		light.light_color = Color("d5d0aa")
		light.light_energy = 1.1
		light.omni_range = 9
		add_child(light)
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.05, 1)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	player.add_child(collision)
	add_child(player)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 75
	player.add_child(camera)
	camera.current = true
	tone = AudioStreamPlayer.new()
	add_child(tone)

func style(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box

func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", Color("dce4dc"))
	theme.set_stylebox("panel", "PanelContainer", style(Color("101d22"), Color("3b5558")))
	theme.set_stylebox("normal", "Button", style(Color("213338"), Color("47615f"), 6))
	theme.set_stylebox("hover", "Button", style(Color("34514f"), Color("91b9a3"), 6))
	theme.set_stylebox("pressed", "Button", style(Color("142825"), Color("bfd2b2"), 6))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	ui.add_child(root)
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 20
	root.add_child(top)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 19)
	top.add_child(hud)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt.offset_left = -270
	prompt.offset_right = 270
	prompt.offset_top = 20
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	var dot := Label.new()
	dot.text = "·"
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.add_theme_font_size_override("font_size", 32)
	root.add_child(dot)
	notice = Label.new()
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice.offset_left = 30
	notice.offset_right = -30
	notice.offset_top = -95
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(notice)
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.025, 0.03, 0.8)
	root.add_child(shade)
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	modal.offset_left = -410
	modal.offset_right = 410
	modal.offset_top = -325
	modal.offset_bottom = 325
	root.add_child(modal)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

func panel(title: String, text: String = "") -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	modal.show()
	shade.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 28)
	content.add_child(heading)
	if not text.is_empty():
		paragraph(text)

func paragraph(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)

func button(text: String, callback: Callable) -> void:
	var item := Button.new()
	item.text = text
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 42
	item.pressed.connect(callback)
	content.add_child(item)

func close_panel() -> void:
	if game.ended:
		return
	modal.hide()
	shade.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_intro() -> void:
	panel("스토커   /   01. 문밖의 사람", "당신은 혼자 사는 재택 개발자다. 며칠 전부터 누군가 찾아온다.\n경찰이 범인을 검거할 때까지 식량과 정신력을 유지해야 한다.\n\nWASD 이동 · 마우스 시선 · E 상호작용 · Tab 휴대폰 · J 기록 · Esc 메뉴\n시간은 행동할 때만 흐른다. 방 안을 걷거나 관찰하는 동안에는 흐르지 않는다.\n\n첫 목표: 휴대폰으로 간편식을 주문하고 PC에서 2시간 일해보자.\n야간 방문은 22시. 떠나는 소리를 들으면 창밖도 확인하자.")
	button("자유 시연", close_panel)
	button("사망 시연 · 주문하지 않은 방문", func(): demo.start("death"))
	button("생존 시연 · 관찰과 신고", func(): demo.start("survival"))
	button("종료", func(): get_tree().quit())

func _input(event: InputEvent) -> void:
	if demo != null and demo.active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			demo.pause()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.002)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.002, -1.35, 1.35)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if modal.visible and not game.ended:
				close_panel()
			elif not game.ended:
				show_pause()
		elif not modal.visible:
			if event.keycode == KEY_E and not focused.is_empty():
				interact(focused)
			elif event.keycode == KEY_TAB:
				phone()
			elif event.keycode == KEY_J:
				journal()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if not modal.visible:
		var direction := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): direction.z -= 1
		if Input.is_physical_key_pressed(KEY_S): direction.z += 1
		if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
		if Input.is_physical_key_pressed(KEY_D): direction.x += 1
		direction = player.basis * direction.normalized()
		player.velocity.x = direction.x * 2.8
		player.velocity.z = direction.z * 2.8
		player.velocity.y -= 12 * delta
		player.move_and_slide()
		focused = ""
		var best := 0.65
		for target in targets:
			var offset: Vector3 = target.position - camera.global_position
			var alignment := -camera.global_basis.z.dot(offset.normalized())
			if offset.length() < 2.7 and alignment > best:
				best = alignment
				focused = target.name
		prompt.text = "E  ·  " + focused if not focused.is_empty() else ""
	update_hud()

func update_hud() -> void:
	hud.text = "스토커   /   %s     공복 %d   정신력 %d   ₩%s   식량 %d\n검거까지 %.1f시간   ·   신고 %d/2   ·   WASD 이동 / E 확인 / Tab 휴대폰 / J 기록" % [game.stamp(), int(game.hunger), int(game.sanity), str(game.money), game.food, maxf(0, game.deadline - game.clock), game.reported.size()]
	if not game.journal.is_empty():
		notice.text = game.journal[0]
	if game.visitor == "stalker" or game.visitor == "courier":
		var key := "%s_%s" % [game.visitor, game.stamp()]
		if key != last_bell:
			last_bell = key
			ring()

func ring() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 22050
	var data := PackedByteArray()
	for i in range(15435):
		var t := float(i) / 22050.0
		var frequency := 660.0 if t < 0.3 else 440.0
		var value := int(sin(t * TAU * frequency) * exp(-t * 4.0) * 7000)
		data.append(value & 255)
		data.append((value >> 8) & 255)
	sample.data = data
	tone.stream = sample
	tone.play()

func _exit_tree() -> void:
	if demo != null:
		demo.active = false
		demo.automatic = false
	if is_instance_valid(tone):
		tone.stop()
		tone.stream = null

func interact(target: String) -> void:
	match target:
		"업무 PC": activity_menu("업무")
		"침대": activity_menu("수면")
		"휴대폰": phone()
		"식료품": food_menu()
		"창밖": observe("창밖")
		"인터폰": observe("인터폰")
		"현관": door_menu()

func activity_menu(kind: String) -> void:
	panel(kind, "업무는 시간당 약 3,000~4,200원. 연속할수록 수입이 오른다.\n수면은 시간당 정신력 약 5 회복. 이전 취침 시각과 4시간 넘게 차이나면 회복이 낮아진다.\n초인종이 울리면 행동이 멈추며 남은 시간을 계속할 수 있다.")
	for hours in ([1, 2, 4] if kind == "업무" else [2, 4, 8]):
		button("%d시간 %s" % [hours, kind], func(): start_action(kind, hours))
	button("돌아가기", close_panel)

func start_action(kind: String, hours: float) -> void:
	if game.pending > 0:
		game.cancel_activity()
	game.begin(kind, hours)
	after_action()

func after_action() -> void:
	update_hud()
	if game.ended:
		ending()
	elif game.pending > 0:
		panel("딩동.   /   %s" % game.stamp(), "문밖에 누군가 있다. %s %.1f시간이 남았다.\n문을 열기 전에 주문 내역과 방문자의 말을 비교하자." % [game.activity, game.pending])
		button("인터폰 확인", func(): observe("인터폰"))
		button("현관 렌즈 확인", func(): observe("현관 렌즈"))
		button("하던 행동 계속하기", func(): game.resume_activity(); after_action())
		button("행동 중단하고 일어나기", func(): game.cancel_activity(); close_panel())
	else:
		panel(game.stamp(), game.journal[0] if not game.journal.is_empty() else "시간이 흘렀다.")
		button("돌아가기", close_panel)

func observe(source: String) -> void:
	panel(source + "   /   정지 화면", game.observe(source))
	var frame = Observation.new()
	frame.source = source
	frame.visitor = game.visitor
	frame.parcel = game.parcel
	frame.hour = fmod(game.clock, 24.0)
	content.add_child(frame)
	button("관찰 내용 기록", func():
		var found: bool = game.collect(source)
		message("기록", "새로운 증거를 기록했다. 휴대폰에서 신고할 수 있다." if found else "추가로 기록할 새로운 증거는 없다.", func(): observe(source)))
	if source != "창밖":
		button("상대에게 방문 목적 묻기", dialogue)
		button("다른 시야: " + ("현관 렌즈" if source == "인터폰" else "인터폰"), func(): observe("현관 렌즈" if source == "인터폰" else "인터폰"))
		button("현관에서 대응하기", door_menu)
	button("관찰 종료", close_panel)

func dialogue() -> void:
	var reply := "대답이 없다."
	if game.visitor == "courier":
		reply = "‘간편식 세 개, 주문 번호 0417 맞으시죠? 문 앞에 두고 갑니다.’"
	elif game.visitor == "stalker":
		reply = "‘주문 번호요? …그냥 문 여세요. 안에 계신 거 알아요.’\n낮고 조급한 목소리다. 물건을 내려놓는 소리는 없다."
	message("문 너머의 목소리", reply, func(): observe("인터폰"))

func door_menu() -> void:
	panel("현관", "문은 잠겨 있다. 관찰과 주문 내역을 확인한 뒤 판단하자.\n배송 물품은 도착 3시간 뒤 사라진다.\n" + ("호신 스프레이를 갖고 있다." if game.defense else "사용할 수 있는 호신용품이 없다."))
	button("인터폰 확인", func(): observe("인터폰"))
	button("현관 렌즈 확인", func(): observe("현관 렌즈"))
	button("문 열기 / 물품 회수", func():
		var result: String = game.open_door()
		if game.ended: ending()
		else: message("현관", result, door_menu))
	button("없는 척 30분 기다리기", func(): start_action("대기", 0.5))
	button("산책 1시간", walk)
	button("돌아가기", close_panel)

func walk() -> void:
	if game.night() and game.sanity < 35:
		message("산책", "너무 두렵다. 지금은 밤에 나갈 수 없다.", door_menu)
		return
	if game.visitor == "stalker":
		game.open_door()
		if game.ended: ending()
		else: message("현관", "스프레이를 쓰고 겨우 문을 닫았다. 산책은 포기했다.", door_menu)
		return
	game.sanity = minf(100.0, game.sanity + (5.0 if game.night() else 18.0))
	game.log_entry("동네를 산책했다. " + ("어둠 속에서는 마음이 좀처럼 놓이지 않았다." if game.night() else "햇빛과 바깥 공기에 조금 진정됐다."))
	start_action("산책", 1.0)

func phone() -> void:
	var order_text := "진행 중인 주문 없음"
	if game.order_due >= 0:
		order_text = "간편식 3개 / 주문 0417 / %.1f시간 뒤 도착" % (game.order_due - game.clock)
	elif game.parcel:
		order_text = "주문 0417 배송 완료 / 문 앞 물품 있음 / 회수 기한 %.1f시간" % maxf(0, 3.0 - game.clock + game.parcel_since)
	panel("휴대폰", "주문 내역: %s\n증거 %d개 확보 / %d개 신고\n검거 예정: %d일차 %02d시" % [order_text, game.evidence.size(), game.reported.size(), int(game.deadline / 24) + 1, int(fmod(game.deadline, 24))])
	button("간편식 3개 주문 · 12,000원 · 1시간 배송", func():
		if game.money < 12000 or game.order_due >= 0 or game.parcel:
			message("주문 불가", "잔액이 부족하거나 진행 중인 주문·미회수 물품이 있다.", phone)
		else: game.order(); phone())
	button("호신 스프레이 구매 · 18,000원 · MVP 즉시 지급", func():
		if game.money < 18000 or game.defense or game.defense_used:
			message("구매 불가", "잔액이 부족하거나 보유 중이다. 한 번 사용한 방법은 다시 통하지 않는다.", phone)
		else:
			game.money -= 18000
			game.defense = true
			game.log_entry("호신 스프레이를 준비했다. 한 번만 방어할 수 있다.")
			phone())
	button("확보한 증거 경찰에 전달", func():
		var count: int = game.report()
		if game.ended: ending()
		else: message("경찰 제보", "새 증거 %d개 전달. 예상 검거가 %d시간 앞당겨졌다." % [count, count * 6], phone))
	button("지역 뉴스", func(): message("지역 뉴스 / 빌라가 밀집한 동네에서", "경찰은 야간 주거 침입 용의자를 수색 중이다.\n배달원을 사칭할 수 있으니 주문 내역과 방문 목적을 확인할 것.\n손목의 특징, 이동 차량 정보는 수사에 도움이 된다.", phone))
	button("관찰·생활 기록", journal)
	if game.pending > 0:
		button("남은 %s %.1f시간 계속" % [game.activity, game.pending], func(): game.resume_activity(); after_action())
	button("휴대폰 닫기", close_panel)

func food_menu() -> void:
	panel("식료품", "비축 식량 %d개. 식사 한 번에 공복 42 감소, 정신력 3 회복.\n식사에는 30분이 걸린다." % game.food)
	button("간편식 먹기", func():
		if game.food <= 0: message("식량 없음", "휴대폰으로 간편식을 주문해야 한다.", food_menu)
		else:
			game.food -= 1
			game.hunger = maxf(0, game.hunger - 42)
			game.sanity = minf(100, game.sanity + 3)
			game.log_entry("간편식을 먹었다.")
			start_action("식사", 0.5))
	button("돌아가기", close_panel)

func journal() -> void:
	panel("생활·관찰 기록", "확보: " + (", ".join(game.evidence) if not game.evidence.is_empty() else "없음"))
	for entry in game.journal:
		paragraph(entry)
	button("돌아가기", close_panel)

func show_pause() -> void:
	panel("스토커 / 잠깐 멈춤", "WASD 이동 · 마우스 시선 · E 상호작용 · Tab 휴대폰 · J 기록\n현관은 방 정면, PC는 왼쪽, 식료품은 오른쪽, 침대와 창은 뒤쪽이다.\n시간은 선택한 행동으로만 흐른다.")
	button("계속하기", close_panel)
	button("30분 대기", func(): start_action("대기", 0.5))
	if game.pending > 0:
		button("남은 행동 계속", func(): game.resume_activity(); after_action())
	button("처음부터 다시 시작", func(): get_tree().reload_current_scene())
	button("종료", func(): get_tree().quit())

func message(title: String, text: String, back: Callable) -> void:
	panel(title, text)
	button("확인", back)

func ending() -> void:
	panel("생존 / 문밖은 조용하다" if game.won else "사망 / 문이 열렸다", "%s\n\n%s · 확보 증거 %d · 신고 %d\n이 MVP는 생활과 방문 판단, 제보의 흐름을 시험하는 짧은 시제품이다." % [game.ending, game.stamp(), game.evidence.size(), game.reported.size()])
	button("처음부터 다시 시작", func(): get_tree().reload_current_scene())
	button("사망 시연", func(): demo.start("death"))
	button("생존 시연", func(): demo.start("survival"))
	button("종료", func(): get_tree().quit())

func smoke_test() -> void:
	# Exercise every major UI construction path, including procedural observation.
	for target in ["업무 PC", "침대", "휴대폰", "식료품", "창밖", "인터폰", "현관"]:
		interact(target)
		await get_tree().process_frame
	game.visitor = "stalker"
	observe("현관 렌즈")
	await get_tree().process_frame
	game.finish(true, "Smoke test")
	ending()
	await get_tree().process_frame
	await get_tree().process_frame
	print("UI_SMOKE_OK")
	tone.stop()
	tone.stream = null
	await get_tree().process_frame
	get_tree().quit()

func test_demos() -> void:
	for route in ["death", "survival"]:
		demo.start(route)
		await get_tree().process_frame
		while demo.index < demo.steps.size() - 1:
			demo.advance()
			await get_tree().process_frame
		assert(game.ended, "Demo must reach a real ending")
		assert(game.won == (route == "survival"), "Wrong demo ending")
		if route == "survival":
			assert(game.reported.size() == 2 and is_equal_approx(game.clock, 42.0))
		print("DEMO_PASS: ", route, " steps=", demo.steps.size(), " clock=", game.clock)
	demo.start("death")
	demo.toggle_auto()
	await get_tree().create_timer(5.3).timeout
	assert(demo.index == 1, "Automatic playback must advance one step after five seconds")
	demo.pause()
	assert(not demo.automatic, "Pause must stop automatic playback")
	print("AUTO_DEMO_PASS")
	demo.active = false
	await get_tree().process_frame
	print("DEMO_TESTS_OK")
	get_tree().quit()

func capture_preview() -> void:
	for i in range(20):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/preview_intro.png")
	close_panel()
	for i in range(10):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/preview_room.png")
	game.clock = 22.0
	game.visitor = "stalker"
	observe("현관 렌즈")
	for i in range(10):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/preview_observation.png")
	for route in ["death", "survival"]:
		demo.start(route)
		while demo.index < demo.steps.size() - 1:
			demo.advance()
			for i in range(3):
				await get_tree().process_frame
		for i in range(10):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://docs/preview_" + route + ".png")
	print("PREVIEW_CAPTURE_OK")
	get_tree().quit()
