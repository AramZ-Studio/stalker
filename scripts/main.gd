extends Node3D

const State = preload("res://scripts/state.gd")
const Observation = preload("res://scripts/observation_3d.gd")
const Demo = preload("res://scripts/demo.gd")
const DoorNight = preload("res://scripts/door_night.gd")
const FullGame = preload("res://scripts/full_game.gd")
const Presence = preload("res://scripts/presence.gd")
var presence: Node
var full: RefCounted
var night: RefCounted
var demo: RefCounted
var game = State.new()
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var prompt: Label
var notice: Label
var reticle: Label
var modal: PanelContainer
var content: VBoxContainer
var shade: ColorRect
var targets: Array[Dictionary] = []
var focused := ""
var ui: CanvasLayer
var tone: AudioStreamPlayer
var last_bell := ""
var entrance_hinge: Node3D
var door_handle: Node3D
var door_lock: Node3D
var intercom_surface: MeshInstance3D
var window_surface: MeshInstance3D
var mouse_sensitivity := 0.002
var preferred_fov := 75.0
var camera_motion := true
var walk_phase := 0.0
var step_distance := 0.0
var station_labels: Dictionary = {}
var activity_transition := false
var retired_snapshots: Array[Dictionary] = []

func _ready() -> void:
	build_room()
	build_ui()
	presence = Presence.new()
	add_child(presence)
	presence.setup(self)
	demo = Demo.new(self)
	night = DoorNight.new(self)
	full = FullGame.new(self)
	game.log_entry("경찰: ‘용의자를 추적 중입니다. 3일차 06시까지 문단속하세요. 특징이나 차량을 보면 제보해주세요.’")
	game.log_entry("배송은 주문 1시간 후 도착하며, 3시간 내 회수해야 한다. 식량 2개와 42,000원이 있다.")
	show_intro()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("smoke_test")
	elif "--capture-preview" in OS.get_cmdline_user_args():
		call_deferred("capture_preview")
	elif "--test-demos" in OS.get_cmdline_user_args():
		call_deferred("test_demos")
	elif "--test-night-ui" in OS.get_cmdline_user_args():
		call_deferred("test_night_ui")
	elif "--capture-night" in OS.get_cmdline_user_args():
		call_deferred("capture_night")
	elif "--test-full-ui" in OS.get_cmdline_user_args():
		call_deferred("test_full_ui")
	elif "--capture-full" in OS.get_cmdline_user_args():
		call_deferred("capture_full")
	elif "--test-upgrade" in OS.get_cmdline_user_args():
		call_deferred("test_upgrade")
	elif "--capture-upgrade" in OS.get_cmdline_user_args():
		call_deferred("capture_upgrade")
	elif "--test-presence" in OS.get_cmdline_user_args():
		call_deferred("test_presence")
	elif "--capture-presence" in OS.get_cmdline_user_args():
		call_deferred("capture_presence")

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
	station_labels[label] = title
	title.hide()

func build_room() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101b1e")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("82999a")
	settings.ambient_light_energy = 0.2
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	block(Vector3(0, -0.15, 0), Vector3(10, 0.3, 10), Color("252e35"))
	block(Vector3(0, 3.1, 0), Vector3(10, 0.2, 10), Color("66716d"))
	for x in [-5.0, 5.0]:
		block(Vector3(x, 1.5, 0), Vector3(0.2, 3, 10), Color("66716d"))
	block(Vector3(0, 1.5, 5), Vector3(10, 3, 0.2), Color("66716d"))
	# Real doorway: the animated leaf opens onto a short dark corridor.
	for side in [-1.0, 1.0]:
		block(Vector3(side * 2.85, 1.5, -5), Vector3(4.3, 3, 0.2), Color("66716d"))
		block(Vector3(side * 0.77, 1.23, -4.85), Vector3(0.1, 2.46, 0.2), Color("82999a"))
		block(Vector3(side * 1.5, 1.5, -6.5), Vector3(0.15, 3, 3), Color("252e35"))
	block(Vector3(0, 2.73, -5), Vector3(1.4, 0.54, 0.2), Color("66716d"))
	block(Vector3(0, -0.15, -6.5), Vector3(3, 0.3, 3), Color("252e35"))
	block(Vector3(0, 1.5, -8), Vector3(3, 3, 0.2), Color("101b1e"))
	for i in range(20):
		block(Vector3(-4.75 + i * 0.5, 0.008, 0), Vector3(0.015, 0.01, 10), Color("252a27"), false)
	# Entry, intercom and peephole.
	var door := block(Vector3(0, 1.23, -4.84), Vector3(1.4, 2.46, 0.12), Color("101b1e"))
	entrance_hinge = Node3D.new()
	entrance_hinge.position = Vector3(-0.7, 0, -4.84)
	add_child(entrance_hinge)
	door.reparent(entrance_hinge, true)
	door_handle = Node3D.new()
	door_handle.position = Vector3(0.45, 1, -4.7)
	add_child(door_handle)
	block(Vector3(0.5, 1.0, -4.7), Vector3(0.15, 0.035, 0.05), Color("b8b0a0"), false).reparent(door_handle, true)
	door_handle.reparent(entrance_hinge, true)
	door_lock = Node3D.new()
	door_lock.position = Vector3(0.45, 1.28, -4.7)
	add_child(door_lock)
	block(Vector3(0.45, 1.28, -4.7), Vector3(0.065, 0.025, 0.035), Color("82999a"), false).reparent(door_lock, true)
	door_lock.reparent(entrance_hinge, true)
	block(Vector3(0, 1.65, -4.7), Vector3(0.045, 0.045, 0.012), Color("66716d"), false).reparent(entrance_hinge, true)
	station("현관", Vector3(0, 1.1, -4.6), Color("c2c5ac"))
	block(Vector3(1.5, 1.5, -4.76), Vector3(0.42, 0.55, 0.17), Color("82999a"))
	block(Vector3(1.5, 1.57, -4.65), Vector3(0.3, 0.22, 0.03), Color("426bc2"), false, true)
	intercom_surface = screen_surface(Vector3(1.5, 1.57, -4.631), Vector2(0.3, 0.22))
	block(Vector3(1.37, 1.31, -4.65), Vector3(0.025, 0.025, 0.03), Color("9b635b"), false, true)
	station("인터폰", Vector3(1.5, 1.5, -4.5), Color("92c8b6"))
	preload("res://scripts/furnished_room.gd").furnish(self)
	window_surface = screen_surface(Vector3(3, 1.8, 4.65), Vector2(2.5, 1.3), PI)
	for pos in [Vector3(0, 2.7, 0), Vector3(-3.3, 2.4, -3.6)]:
		var light := OmniLight3D.new()
		light.position = pos
		light.light_color = Color("d2dac2")
		light.light_energy = 1.1
		light.shadow_enabled = true
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

func screen_surface(pos: Vector3, size: Vector2, angle: float = 0) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = size
	result.mesh = plane
	result.material_override = material(Color("101b1e"))
	result.position = pos
	result.rotation.y = angle
	add_child(result)
	return result

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
	reticle = dot
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

func panel(title: String, text: String = "", animate_return: bool = false) -> void:
	if presence != null: presence.close_view(animate_return)
	if full != null:
		full.holding = false
		full.looking = false
	modal.set_anchors_preset(Control.PRESET_CENTER)
	modal.offset_left = -410
	modal.offset_right = 410
	modal.offset_top = -325
	modal.offset_bottom = 325
	for child in content.get_children():
		if child is SubViewportContainer:
			child.hide()
			child.reparent(self)
			retire_snapshot(child)
		else:
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

func compact_panel(title: String, text: String = "", phone_layout: bool = false) -> void:
	panel(title, text, true)
	shade.hide()
	if phone_layout:
		modal.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		modal.offset_left = -424
		modal.offset_right = -24
		modal.offset_top = 72
		modal.offset_bottom = 730
	else:
		modal.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		modal.offset_left = 24
		modal.offset_right = 468
		modal.offset_top = -272
		modal.offset_bottom = -24
	if content.get_child_count() > 0: content.get_child(0).add_theme_font_size_override("font_size", 20)

func retire_snapshot(snapshot: Node) -> void:
	# Let pending viewport render work finish before releasing its mesh materials.
	var held_materials: Array = []
	for mesh in snapshot.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_override != null:
			held_materials.append(mesh.material_override)
			mesh.material_override = null
		if mesh.mesh != null:
			for surface in range(mesh.mesh.get_surface_count()):
				var override = mesh.get_surface_override_material(surface)
				if override != null:
					held_materials.append(override)
					mesh.set_surface_override_material(surface, null)
	retired_snapshots.append({"node": snapshot, "materials": held_materials, "frames": 2})

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
	item.focus_mode = Control.FOCUS_NONE
	if game.suspense and modal.anchor_left != 0.5:
		item.custom_minimum_size.y = 32
		item.add_theme_font_size_override("font_size", 15)
		for state in ["normal", "hover", "pressed"]:
			var compact_style := style(Color("213338") if state == "normal" else Color("34514f"), Color("47615f"), 4)
			compact_style.content_margin_top = 4
			compact_style.content_margin_bottom = 4
			compact_style.content_margin_left = 10
			compact_style.content_margin_right = 10
			item.add_theme_stylebox_override(state, compact_style)
	item.pressed.connect(callback)
	content.add_child(item)

func close_panel() -> void:
	if game.ended:
		return
	if full != null:
		full.looking = false
		full.holding = false
	modal.hide()
	shade.hide()
	if presence != null: presence.close_view()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_intro() -> void:
	panel("OPEN UP · 문열어 / 생활과 문밖", "혼자 사는 재택 개발자. 밤마다 누군가 찾아오지만 생활은 계속해야 한다.\n일해서 생활비를 벌고, 먹고 자고, 필요한 물품을 받아라.\n\n주문·대화·소리·정지 화면을 연결해 문을 열지 판단하라.\n증거를 제보하면 검거가 앞당겨진다. 그때까지 버티는 것이 목표다.\n\nWASD 이동 · E 확인 · Tab 휴대폰 · J 기록 · Esc 메뉴\n시간은 업무·식사·수면·대기·외출 등 행동으로 흐른다.")
	button("자유 시연 · 생활과 문밖", func(): full.start())
	button("첫날 밤 · 세 번의 방문", func(): full.start_first_night())
	button("현관 연출만 짧게 체험", func(): night.start())
	button("생활 시스템 시연 · 기존 버전", close_panel)
	button("사망 시연 · 주문하지 않은 방문", func(): demo.start("death"))
	button("생존 시연 · 관찰과 신고", func(): demo.start("survival"))
	button("종료", func(): get_tree().quit())
	button("시선 · 화면 설정", show_settings)

func _input(event: InputEvent) -> void:
	if activity_transition:
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]: activity_transition = false
		return
	if night != null and night.active:
		night.input(event)
		return
	if demo != null and demo.active:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			demo.pause()
		return
	if full != null and full.active and presence.input(event): return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		presence.look_impulse(event.relative)
		player.rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * mouse_sensitivity, -1.35, 1.35)
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
	if not modal.visible and not activity_transition and not presence.blocked() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var direction := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): direction.z -= 1
		if Input.is_physical_key_pressed(KEY_S): direction.z += 1
		if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
		if Input.is_physical_key_pressed(KEY_D): direction.x += 1
		direction = player.basis * direction.normalized()
		var speed := 1.15 if Input.is_physical_key_pressed(KEY_SHIFT) else 2.5
		var acceleration := 20.0 if direction.is_zero_approx() else 11.0
		player.velocity.x = move_toward(player.velocity.x, direction.x * speed, acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * speed, acceleration * delta)
		player.velocity.y -= 12 * delta
		player.move_and_slide()
		var travel := Vector2(player.get_real_velocity().x, player.get_real_velocity().z).length() * delta
		walk_phase += travel * 7.0
		step_distance += travel
		if step_distance > 0.85 and player.is_on_floor():
			step_distance = 0
			if full != null and full.active: full.audio.footstep()
		focused = find_focused()
		prompt.text = "E  ·  " + focused if not focused.is_empty() else ""
	else:
		player.velocity = Vector3.ZERO
		if not presence.blocked(): camera.position.y = lerpf(camera.position.y, 1.6, minf(1, delta * 12))
	for label_name in station_labels:
		station_labels[label_name].visible = not modal.visible and focused == label_name
	update_hud()

func find_focused() -> String:
	var result := ""
	var best := 0.88
	for target in targets:
		var offset: Vector3 = target.position - camera.global_position
		var alignment := -camera.global_basis.z.dot(offset.normalized())
		if offset.length() >= 2.2 or alignment <= best: continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, target.position)
		query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or camera.global_position.distance_to(hit.position) >= offset.length() - 0.2:
			best = alignment
			result = target.name
	return result

func _process(delta: float) -> void:
	for i in range(retired_snapshots.size() - 1, -1, -1):
		retired_snapshots[i].frames -= 1
		if retired_snapshots[i].frames <= 0:
			if is_instance_valid(retired_snapshots[i].node): retired_snapshots[i].node.queue_free()
			retired_snapshots.remove_at(i)
	if night != null and night.active:
		night.update(delta)
	if full != null and full.active:
		full.update(delta)
	if presence != null: presence.update(delta)

func update_hud() -> void:
	var immersive: bool = full != null and full.active
	hud.get_parent().visible = not immersive
	notice.visible = not immersive
	reticle.visible = not modal.visible and not presence.blocked()
	prompt.visible = not modal.visible and not presence.blocked()
	hud.text = "OPEN UP · 문열어   /   %s     공복 %d   정신력 %d   ₩%s   식량 %d" % [game.stamp(), int(game.hunger), int(game.sanity), str(game.money), game.food]
	if modal.visible:
		hud.text += "\n%s %.1f시간 · 신고 %d/%d" % ["아침까지" if game.first_night else "검거까지", maxf(0, game.deadline - game.clock), game.reported.size(), 3 if game.suspense else 2]
	else:
		hud.text += "\nShift 조심히 걷기 · E 확인 · Tab 휴대폰 · Esc 설정"
	if not game.journal.is_empty():
		notice.text = game.journal[0]
	if not game.suspense and (game.visitor == "stalker" or game.visitor == "courier"):
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
	for retired in retired_snapshots:
		if is_instance_valid(retired.node): retired.node.free()
	retired_snapshots.clear()
	if full != null: full.stop()
	if night != null: night.stop()
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
	if game.suspense:
		compact_panel(kind, "한 번에 얼마나 할까?\n초인종이 울리면 멈추고, 남은 시간은 휴대폰에서 재개한다.")
	else:
		panel(kind, "업무는 시간당 약 3,000~4,200원. 연속할수록 수입이 오른다.\n수면은 시간당 정신력 약 5 회복. 이전 취침 시각과 4시간 넘게 차이나면 회복이 낮아진다.\n초인종이 울리면 행동이 멈추며 남은 시간을 계속할 수 있다.")
	for hours in ([1, 2, 4] if kind == "업무" else [2, 4, 8]):
		button("%d시간 %s" % [hours, kind], func(): start_action(kind, hours))
	button("돌아가기", close_panel)

func start_action(kind: String, hours: float) -> void:
	if activity_transition: return
	if game.pending > 0:
		game.cancel_activity()
	if full != null and full.active and kind in ["업무", "수면", "식사"] and DisplayServer.get_name() != "headless":
		activity_transition = true
		close_panel()
		presence.activity(kind)
		presence.say(("키보드 소리만 방 안을 채운다." if kind == "업무" else ("눈을 감는다." if kind == "수면" else "포장을 뜯는다.")) + "  Space 건너뛰기")
		full.audio.cue("typing" if kind == "업무" else "rustle")
		var elapsed := 0.0
		while activity_transition and elapsed < 1.6:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
		activity_transition = false
		presence.finish_activity()
	game.begin(kind, hours)
	after_action()

func after_action() -> void:
	update_hud()
	if game.ended:
		ending()
	elif game.suspense:
		modal.hide()
		shade.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		presence.say("초인종. 하던 일을 멈췄다. 현관을 확인하자. 남은 행동은 휴대폰에서 재개할 수 있다." if game.pending > 0 else (game.journal[0] if not game.journal.is_empty() else "시간이 흘렀다."), 5)
	elif game.pending > 0:
		panel("딩동.   /   %s" % game.stamp(), "문밖에 누군가 있다. %s %.1f시간이 남았다.\n문을 열기 전에 주문 내역과 방문자의 말을 비교하자." % [game.activity, game.pending])
		if game.suspense:
			button("일어나 현관을 확인한다", close_panel)
		else:
			button("인터폰 확인", func(): observe("인터폰"))
			button("현관 렌즈 확인", func(): observe("현관 렌즈"))
		button("하던 행동 계속하기", func(): game.resume_activity(); after_action())
		button("행동 중단하고 일어나기", func(): game.cancel_activity(); close_panel())
	else:
		panel(game.stamp(), game.journal[0] if not game.journal.is_empty() else "시간이 흘렀다.")
		button("돌아가기", close_panel)

func observe(source: String) -> void:
	if game.suspense:
		full.observe(source)
		return
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
	if game.suspense:
		full.dialogue()
		return
	var reply := "대답이 없다."
	if game.visitor == "courier":
		reply = "‘간편식 세 개, 주문 번호 0417 맞으시죠? 문 앞에 두고 갑니다.’"
	elif game.visitor == "stalker":
		reply = "‘주문 번호요? …그냥 문 여세요. 안에 계신 거 알아요.’\n낮고 조급한 목소리다. 물건을 내려놓는 소리는 없다."
	message("문 너머의 목소리", reply, func(): observe("인터폰"))

func door_menu() -> void:
	if game.suspense:
		full.observe("현관 렌즈")
		return
	var protection := "호신 스프레이를 갖고 있다." if game.defense else "사용할 수 있는 호신용품이 없다."
	if game.suspense:
		var owned: Array[String] = []
		for method in game.defenses: owned.append(str(State.CATALOG[method].name))
		protection = "보유한 호신용품: " + (", ".join(owned) if not owned.is_empty() else "없음")
	panel("현관", "문은 잠겨 있다. 관찰과 주문 내역을 확인한 뒤 판단하자.\n배송 물품은 도착 3시간 뒤 사라진다.\n" + protection)
	button("인터폰 확인", func(): observe("인터폰"))
	button("현관 렌즈 확인", func(): observe("현관 렌즈"))
	button("문 열기 / 물품 회수", func():
		if game.suspense:
			full.observe("현관 렌즈")
			return
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
		var response: String = game.open_door()
		if game.ended: ending()
		else: message("현관", response + " 산책은 포기했다.", door_menu)
		return
	game.sanity = minf(100.0, game.sanity + (5.0 if game.night() else 18.0))
	game.last_walk = game.clock
	game.log_entry("동네를 산책했다. " + ("어둠 속에서는 마음이 좀처럼 놓이지 않았다." if game.night() else "햇빛과 바깥 공기에 조금 진정됐다."))
	start_action("산책", 1.0)

func phone() -> void:
	if game.suspense:
		full_phone()
		return
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
	if game.suspense:
		compact_panel("식료품 / 식사", "간편식 %d개 · 좋아하는 음식 %d개\n식사는 30분. 좋아하는 음식은 정신력을 더 회복한다." % [game.food, game.good_food])
		button("간편식 먹기", func(): full_eat(false))
		button("좋아하는 음식 먹기", func(): full_eat(true))
		button("돌아가기", close_panel)
		return
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
	var info := "확보: " + (", ".join(game.evidence) if not game.evidence.is_empty() else "없음")
	if game.suspense: compact_panel("생활·관찰 기록", info, true)
	else: panel("생활·관찰 기록", info)
	for entry in game.journal:
		paragraph(entry)
	button("돌아가기", close_panel)

func full_eat(tasty: bool) -> void:
	if not game.eat(tasty):
		message("음식이 없다", "주문하고 회수한 뒤 먹을 수 있다.", food_menu)
		return
	start_action("식사", 0.5)

func full_phone() -> void:
	var info := "진행 중인 주문 없음"
	if game.order_due >= 0:
		info = "%s / 번호 %s / %d일차 %02d:%02d 예정" % [game.product_name, game.order_number, int(game.order_due / 24) + 1, int(fmod(game.order_due, 24)), int(fmod(game.order_due * 60, 60))]
	elif game.parcel:
		info = "%s / 번호 %s / 미회수 · 남은 회수 시간 %.1f시간" % [game.product_name, game.order_number, maxf(0, 3 - game.clock + game.parcel_since)]
	compact_panel("휴대폰 · Esc 닫기", "%s · 잔액 %d원\n공복 %d · 정신력 %d\n간편식 %d개 · 좋아하는 음식 %d개\n%s\n확보 증거 %d개 · 신고 %d개\n일반 물품은 낮 배송, 음식은 약 45분 후 도착." % [game.stamp(), game.money, int(game.hunger), int(game.sanity), game.food, game.good_food, info, game.evidence.size(), game.reported.size()], true)
	presence.set_gesture("phone")
	for key in State.CATALOG.keys():
		button("%s 주문 · %d원" % [State.CATALOG[key].name, game.price(key)], func():
			var reply: String = game.purchase(key)
			message("주문", reply, full_phone))
	button("확보한 증거 경찰에 전달", func():
		var count: int = game.report()
		if game.ended: ending()
		else: message("경찰 제보", "새 증거 %d개 전달. 검거 예상 %d시간 단축." % [count, count * 6], full_phone))
	if game.camera_ready:
		button("설치한 카메라의 녹화 확인", func():
			var recorded: bool = game.collect("카메라")
			message("현관 녹화", "새 녹화 증거를 저장했다." if recorded else "방문이 촬영되면 추가 증거를 확보할 수 있다.", full_phone))
	button("지역 뉴스", func(): message("지역 뉴스", "빌라 주거 침입 사건의 용의자를 경찰이 수색 중이다.\n배달원을 사칭하고 실제 송장 번호를 알고 있을 수 있다.\n주문 물품·대화·소리를 함께 확인하고, 손목 특징·이동 차량·녹화를 제보해달라고 당부했다.", full_phone))
	button("기록 / 확보한 정보", journal)
	if game.pending > 0:
		button("남은 %s %.1f시간 계속" % [game.activity, game.pending], func(): game.resume_activity(); after_action())
	button("휴대폰 닫기", close_panel)

func show_pause() -> void:
	panel("OPEN UP · 문열어 / 잠깐 멈춤", "WASD 이동 · 마우스 시선 · E 상호작용 · Tab 휴대폰 · J 기록\n현관은 방 정면, PC는 왼쪽, 식료품은 오른쪽, 침대와 창은 뒤쪽이다.\n시간은 선택한 행동으로만 흐른다.")
	button("계속하기", close_panel)
	button("시선 · 화면 설정", show_settings)
	button("30분 대기", func(): start_action("대기", 0.5))
	if game.pending > 0:
		button("남은 행동 계속", func(): game.resume_activity(); after_action())
	button("처음부터 다시 시작", func(): get_tree().reload_current_scene())
	button("종료", func(): get_tree().quit())

func show_settings() -> void:
	panel("시선 · 화면 설정", "Shift 천천히 걷기 · 설정은 현재 실행 동안 유지됩니다.")
	paragraph("마우스 감도")
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0005
	sensitivity.max_value = 0.004
	sensitivity.step = 0.0001
	sensitivity.value = mouse_sensitivity
	sensitivity.value_changed.connect(func(value: float): mouse_sensitivity = value)
	content.add_child(sensitivity)
	paragraph("시야각")
	var field := HSlider.new()
	field.min_value = 60
	field.max_value = 95
	field.value = preferred_fov
	field.value_changed.connect(func(value: float): preferred_fov = value; camera.fov = value)
	content.add_child(field)
	var motion := CheckButton.new()
	motion.text = "걷기 카메라 움직임"
	motion.button_pressed = camera_motion
	motion.toggled.connect(func(value: bool): camera_motion = value)
	content.add_child(motion)
	button("돌아가기", show_pause)

func message(title: String, text: String, back: Callable) -> void:
	if game.suspense: compact_panel(title, text, true)
	else: panel(title, text)
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

func test_night_ui() -> void:
	night.start(17)
	await get_tree().process_frame
	night.resume()
	night.state.arrive()
	for source in ["인터폰", "현관 렌즈"]:
		night.observe(source)
		night.ask()
		night.listen()
		await get_tree().process_frame
	night.phone()
	await get_tree().process_frame
	night.pause()
	assert(night.state.paused)
	night.resume()
	assert(not night.state.paused)
	# Exercise routed input and the hold-to-open interaction, including cancellation.
	night.state.kind = "rain"
	night.state.age = 20
	night.observe("인터폰")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	_input(key)
	night.update(0.55)
	assert(night.state.supplies == 0)
	key.pressed = false
	_input(key)
	assert(night.hold_time == 0 and not night.holding)
	key.pressed = true
	_input(key)
	night.update(1.3)
	assert(night.state.supplies == 1 and night.view == "room")
	night.state.arrive()
	night.state.kind = "copied"
	night.state.age = 20
	night.open()
	assert(night.state.ended and not night.state.won)
	night.update(2)
	await get_tree().process_frame
	night.stop()
	print("NIGHT_UI_OK")
	get_tree().quit()


func capture_night() -> void:
	night.start(17)
	for i in range(12): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/night_intro.png")
	night.resume()
	night.state.arrive()
	night.state.kind = "copied"
	night.state.age = 2
	night.observe("인터폰")
	for i in range(12): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/night_camera.png")
	night.state.age = 20
	night.observe("현관 렌즈")
	for i in range(12): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/night_lens.png")
	night.phone()
	for i in range(12): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/night_phone.png")
	night.stop()
	print("NIGHT_CAPTURE_OK")
	get_tree().quit()

func test_full_ui() -> void:
	full.start(13)
	await get_tree().process_frame
	for target in ["업무 PC", "침대", "휴대폰", "식료품", "창밖", "인터폰", "현관"]:
		interact(target)
		await get_tree().process_frame
	game.visitor = "stalker"
	game.visit_started = game.clock - 0.5
	game.defenses.append("alarm")
	full.observe("현관 렌즈")
	await get_tree().process_frame
	full.opening_button.button_down.emit()
	full.update(1.3)
	assert(not game.ended and game.used_defenses.has("alarm"))
	game.visitor = "stalker"
	full.open()
	assert(game.ended and not game.won)
	full.update(2)
	await get_tree().process_frame
	full.stop()
	print("FULL_UI_OK")
	get_tree().quit()

func capture_full() -> void:
	full.start(13)
	for i in range(12): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/full_intro.png")
	game.purchase("pantry")
	phone()
	for i in range(12): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/full_phone.png")
	game.threat_times[0] = 22
	game.begin("업무", 4)
	game.begin("대기", 0.25)
	full.observe("현관 렌즈")
	for i in range(12): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/full_lens.png")
	full.stop()
	print("FULL_CAPTURE_OK")
	get_tree().quit()

func test_upgrade() -> void:
	full.start_first_night()
	assert(game.first_night and game.order_due == 18.75)
	game.begin("업무", 1)
	assert(game.visitor == "courier")
	assert(game.ask("물품").contains(game.product_name))
	game.ask("두고 가기")
	assert(game.visitor.is_empty() and game.parcel)
	game.open_door()
	game.eat(true)
	game.begin("대기", 0.75)
	assert(game.visitor == "neighbor")
	game.ask("두고 가기")
	assert(game.mail_waiting and game.visitor.is_empty())
	game.open_door()
	assert(not game.mail_waiting)
	game.begin("업무", 2)
	assert(game.visitor == "stalker")
	var original_time: float = game.clock
	print("UPGRADE: checking fixed observations")
	full.observe("인터폰")
	await get_tree().process_frame
	full.update(10)
	assert(game.clock == original_time and game.camera_person())
	game.ask("두고 가기")
	assert(not game.camera_person() and game.lens_person())
	full.observe("현관 렌즈")
	await get_tree().process_frame
	full.opening_button.button_down.emit()
	full.update(0.5)
	full.opening_button.button_up.emit()
	full.update(1)
	assert(not game.ended and full.hold_time == 0)
	game.pending = 0.75
	print("UPGRADE: checking short wait")
	game.activity = "업무"
	game.activity_hours = 1.25
	full.wait_at_door()
	assert(is_equal_approx(game.clock, original_time + 0.05))
	assert(game.pending == 0.75 and game.activity_hours == 1.25)
	game.collect("현관 렌즈")
	game.report()
	assert(game.deadline == 30)
	while game.clock < 22.5: game.begin("대기", minf(0.25, 22.5 - game.clock))
	game.begin("수면", 8)
	assert(game.won and game.ending.contains("첫날 밤"))
	preferred_fov = 85
	full.update(1)
	assert(camera.fov == 85)
	show_settings()
	print("UPGRADE: checking settings and visibility")
	await get_tree().process_frame
	player.position = Vector3(0, 0.05, -2.8)
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	await get_tree().physics_frame
	assert(find_focused() == "현관")
	var obstruction := block(Vector3(0, 1.5, -3.6), Vector3(2, 3, 0.1), Color("252e35"))
	await get_tree().physics_frame
	assert(find_focused() != "현관")
	obstruction.queue_free()
	await get_tree().physics_frame
	player.position = Vector3(-3.4, 0.05, -1.5)
	await get_tree().physics_frame
	assert(find_focused() == "업무 PC")
	full.stop()
	print("UPGRADE_TESTS_OK: visitor decisions, fixed snapshots, cancelled opening, short wait, first-night survival, settings")
	get_tree().quit()

func capture_upgrade_frame(file_name: String) -> void:
	for i in range(15): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/" + file_name + ".png")

func capture_upgrade() -> void:
	full.start_first_night()
	await capture_upgrade_frame("upgrade_intro")
	close_panel()
	player.position = Vector3(0, 0.05, 0.4)
	await capture_upgrade_frame("upgrade_room")
	game.begin("업무", 1)
	full.observe("인터폰")
	await capture_upgrade_frame("upgrade_intercom")
	full.dialogue()
	await capture_upgrade_frame("upgrade_dialogue")
	game.ask("두고 가기")
	game.open_door()
	while game.clock < 21.5: game.begin("업무", minf(0.25, 21.5 - game.clock))
	game.ask("두고 가기")
	full.observe("인터폰")
	await capture_upgrade_frame("upgrade_blindspot")
	full.observe("현관 렌즈")
	await capture_upgrade_frame("upgrade_lens")
	full.listen()
	await capture_upgrade_frame("upgrade_listen")
	full.stop()
	print("UPGRADE_CAPTURE_OK")
	get_tree().quit()

func test_presence() -> void:
	full.start_first_night()
	close_panel()
	player.position = Vector3(1.5, 0.05, -2.9)
	game.begin("업무", 1)
	var original_time: float = game.clock
	full.observe("인터폰")
	assert(not modal.visible and not shade.visible and presence.blocked())
	await get_tree().create_timer(0.65).timeout
	assert(camera.global_position.distance_to(intercom_surface.global_position) < 0.8)
	var screen_area: float = get_viewport().get_visible_rect().get_area()
	assert(presence.choices.get_rect().get_area() < screen_area * 0.1)
	assert(game.clock == original_time)
	if DisplayServer.get_name() != "headless": assert(intercom_surface.material_override is ShaderMaterial)
	full.dialogue()
	assert(presence.actions.size() == 4 and not modal.visible)
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	presence.input(key)
	assert(game.visitor.is_empty() and game.parcel)
	key.keycode = KEY_E
	presence.input(key)
	full.update(0.4)
	assert(absf(door_lock.rotation.z) > 0.2 and game.parcel)
	await get_tree().create_timer(0.45).timeout
	assert(presence.hands[1].global_position.distance_to(door_handle.global_position) < 0.22)
	key.pressed = false
	presence.input(key)
	assert(door_lock.rotation.z == 0 and door_handle.rotation.z == 0 and game.parcel)
	full.open()
	assert(game.good_food == 1 and not game.parcel and presence.view == "opening")
	await get_tree().create_timer(0.8).timeout
	assert(absf(entrance_hinge.rotation.y) > 0.3 and presence.blocked())
	await get_tree().create_timer(1.4).timeout
	assert(absf(entrance_hinge.rotation.y) < 0.01 and not presence.blocked())
	assert(game.clock == original_time)
	full_phone()
	await get_tree().process_frame
	assert(not shade.visible and modal.get_global_rect().position.x > get_viewport().get_visible_rect().size.x * 0.6)
	close_panel()
	presence.activity("업무")
	await get_tree().create_timer(0.65).timeout
	assert(camera.position.y < 1.23 and presence.gesture == "work")
	presence.finish_activity()
	await get_tree().create_timer(0.45).timeout
	assert(not presence.blocked())
	game.visitor = "stalker"
	game.visit_started = game.clock - 0.5
	full.observe("현관 렌즈")
	full.open()
	assert(game.ended and presence.view == "death")
	await get_tree().create_timer(0.9).timeout
	assert(is_instance_valid(presence.attacker) and presence.attacker.position.z > -5.45)
	await get_tree().create_timer(1.1).timeout
	assert(modal.visible)
	full.stop()
	print("PRESENCE_TESTS_OK: compact choices, physical screen, frozen clock, keyboard dialogue, reversible lock, live doorway, phone layout, body gestures, encounter animation")
	get_tree().quit()

func capture_presence_frame(file_name: String, seconds: float = 0.7) -> void:
	await get_tree().create_timer(seconds).timeout
	for i in range(3): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://docs/" + file_name + ".png")

func capture_presence() -> void:
	full.start_first_night()
	close_panel()
	player.position = Vector3(0, 0.05, -1.5)
	await capture_presence_frame("presence_room")
	game.begin("업무", 1)
	full.observe("인터폰")
	await capture_presence_frame("presence_intercom")
	full.dialogue()
	await capture_presence_frame("presence_dialogue", 0.15)
	full.ask_topic("두고 가기")
	full.opening_button.button_down.emit()
	await capture_presence_frame("presence_unlock", 0.6)
	full.opening_button.button_up.emit()
	full.open()
	await capture_presence_frame("presence_open", 0.78)
	await get_tree().create_timer(1.4).timeout
	while game.clock < 21.5: game.begin("대기", minf(0.25, 21.5 - game.clock))
	game.ask("두고 가기")
	full.observe("현관 렌즈")
	await capture_presence_frame("presence_lens")
	full.listen()
	await capture_presence_frame("presence_listen")
	full_phone()
	await capture_presence_frame("presence_phone")
	close_panel()
	player.position = Vector3(-3.4, 0.05, -2.8)
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	presence.activity("업무")
	await capture_presence_frame("presence_work")
	presence.finish_activity()
	await get_tree().create_timer(0.45).timeout
	full.observe("현관 렌즈")
	full.open()
	await capture_presence_frame("presence_encounter", 0.95)
	full.stop()
	print("PRESENCE_CAPTURE_OK")
	get_tree().quit()
