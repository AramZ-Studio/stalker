extends Node

# First-person presentation only. Life time and visitor decisions stay in state.gd.
var host: Node3D
var view := "room"
var root: Control
var feed_root: Control
var choices: PanelContainer
var rows: VBoxContainer
var subtitle: Label
var subtitle_box: PanelContainer
var veil: ColorRect
var snapshot: SubViewportContainer
var opening_button: Button
var actions: Array[Callable] = []
var camera_tween: Tween
var door_tween: Tween
var return_pose := Transform3D.IDENTITY
var returning := false
var gesture := "idle"
var gesture_time := 0.0
var hands: Array[Node3D] = []
var fingers: Array[Node3D] = []
var hands_root: Node3D
var cup: MeshInstance3D
var phone_prop: MeshInstance3D
var sway := Vector2.ZERO
var elapsed := 0.0
var subtitle_for := 0.0
var attacker: Node3D

func setup(owner_node: Node3D) -> void:
	host = owner_node
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = host.modal.get_parent().theme
	host.ui.add_child(root)
	feed_root = Control.new()
	feed_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feed_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(feed_root)
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0, 0, 0, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	choices = PanelContainer.new()
	choices.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	choices.offset_left = 24
	choices.offset_right = 446
	choices.offset_top = -166
	choices.offset_bottom = -24
	var background: StyleBoxFlat = host.style(Color(0.025, 0.04, 0.045, 0.72), Color(0.35, 0.43, 0.43, 0.25), 3)
	background.content_margin_left = 12
	background.content_margin_right = 12
	background.content_margin_top = 8
	background.content_margin_bottom = 8
	choices.add_theme_stylebox_override("panel", background)
	root.add_child(choices)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 3)
	choices.add_child(rows)
	subtitle_box = PanelContainer.new()
	subtitle_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	subtitle_box.offset_left = -780
	subtitle_box.offset_right = -24
	subtitle_box.offset_top = -126
	subtitle_box.offset_bottom = -24
	subtitle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_box.add_theme_stylebox_override("panel", host.style(Color(0.02, 0.03, 0.035, 0.62), Color.TRANSPARENT, 3))
	root.add_child(subtitle_box)
	subtitle = Label.new()
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_box.add_child(subtitle)
	choices.hide()
	subtitle_box.hide()
	build_hands()

func limb(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = host.material(color)
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

func rounded_limb(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, depth: float = 1) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 12
	result.mesh = shape
	result.material_override = host.material(color)
	result.position = pos
	result.scale.z = depth
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result

func build_hands() -> void:
	hands_root = Node3D.new()
	host.camera.add_child(hands_root)
	for side in [-1.0, 1.0]:
		var wrist := Node3D.new()
		hands_root.add_child(wrist)
		hands.append(wrist)
		rounded_limb(wrist, Vector3(0, -0.3, 0.025), 0.055, 0.62, Color("252e35"), 0.85)
		rounded_limb(wrist, Vector3(0, 0.005, 0), 0.035, 0.1, Color("b8b0a0"), 0.65)
		rounded_limb(wrist, Vector3(0, 0.07, 0), 0.043, 0.12, Color("b8b0a0"), 0.55)
		for i in range(4):
			var finger := Node3D.new()
			finger.position = Vector3((i - 1.5) * 0.021, 0.12, 0)
			wrist.add_child(finger)
			rounded_limb(finger, Vector3(0, 0.017, -0.004), 0.009, 0.038, Color("b8b0a0"))
			var tip := Node3D.new()
			tip.position.y = 0.034
			finger.add_child(tip)
			rounded_limb(tip, Vector3(0, 0.014, 0), 0.008, 0.034 if i < 3 else 0.026, Color("b8b0a0"))
			fingers.append(finger)
		var thumb := rounded_limb(wrist, Vector3(side * 0.048, 0.055, 0.012), 0.013, 0.065, Color("b8b0a0"))
		thumb.rotation.z = side * -0.6
		wrist.position = Vector3(side * 0.29, -0.62, -0.36)
	cup = limb(hands[1], Vector3(0, 0.13, -0.065), Vector3(0.12, 0.15, 0.12), Color("b8b0a0"))
	cup.hide()
	phone_prop = limb(hands[0], Vector3(0, 0.16, -0.04), Vector3(0.12, 0.21, 0.025), Color("101b1e"))
	limb(phone_prop, Vector3(0, 0, 0.015), Vector3(0.102, 0.175, 0.004), Color("82999a"))
	phone_prop.hide()
	hands_root.hide()

func blocked() -> bool:
	return view != "room" or returning

func set_gesture(value: String) -> void:
	gesture = value
	gesture_time = 0

func clear_snapshot() -> void:
	# Detach screen materials before retiring the viewport they refer to.
	if is_instance_valid(host.intercom_surface): host.intercom_surface.material_override = host.material(Color("1c326e"), true)
	if is_instance_valid(host.window_surface): host.window_surface.material_override = host.material(Color("101b1e"))
	if is_instance_valid(snapshot):
		snapshot.hide()
		snapshot.reparent(host)
		host.retire_snapshot(snapshot)
	snapshot = null

func begin_view(source: String) -> void:
	if view == "room" and not returning: return_pose = host.camera.transform
	if is_instance_valid(camera_tween): camera_tween.kill()
	returning = false
	view = source
	host.modal.hide()
	host.shade.hide()
	host.prompt.text = ""
	clear_snapshot()
	var eye := Vector3(1.5, 1.56, -3.98)
	var target := Vector3(1.5, 1.57, -4.65)
	var roll := 0.0
	if source == "현관 렌즈":
		eye = Vector3(0, 1.61, -4.28)
		target = Vector3(0, 1.65, -4.7)
	elif source == "듣기":
		eye = Vector3(0.3, 1.6, -4.13)
		target = Vector3(0.07, 1.54, -4.7)
		roll = -0.055 if host.camera_motion else 0.0
	elif source == "창밖":
		eye = Vector3(3, 1.7, 3.72)
		target = Vector3(3, 1.8, 4.73)
	var desired := Transform3D.IDENTITY
	desired.origin = eye
	desired = desired.looking_at(target)
	desired = host.player.global_transform.affine_inverse() * desired
	var rotation := desired.basis.get_rotation_quaternion() * Quaternion(Vector3.FORWARD, roll)
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(host.camera, "position", desired.origin, 0.42)
	camera_tween.tween_property(host.camera, "quaternion", rotation, 0.42)
	camera_tween.tween_property(host.camera, "fov", minf(host.preferred_fov, 65), 0.42)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_gesture("listen" if source == "듣기" else ("lens" if source == "현관 렌즈" else "tap"))

func present_snapshot(frame: SubViewportContainer, source: String) -> void:
	snapshot = frame
	if source == "현관 렌즈":
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		feed_root.add_child(frame)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		# The viewport renders offscreen; its texture appears on the physical device.
		frame.position = Vector2(-4096, -4096)
		frame.size = Vector2(640, 480)
		frame.render_size = Vector2i(640, 480)
		feed_root.add_child(frame)
		var surface: MeshInstance3D = host.intercom_surface if source == "인터폰" else host.window_surface
		if DisplayServer.get_name() != "headless":
			var screen := ShaderMaterial.new()
			screen.shader = preload("res://scripts/monitor_surface.gdshader")
			screen.set_shader_parameter("feed", frame.snapshot_viewport.get_texture())
			screen.set_shader_parameter("monitor", source == "인터폰")
			screen.set_shader_parameter("activation", 0.0)
			surface.material_override = screen
			create_tween().tween_property(screen, "shader_parameter/activation", 1.0, 0.3)

func clear_choices(title: String, tall: bool = false) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	actions.clear()
	opening_button = null
	choices.offset_top = -204 if tall else -140
	choices.show()
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color("82999a")
	rows.add_child(label)

func choice(parent: Node, text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.focus_mode = Control.FOCUS_NONE
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.add_theme_font_size_override("font_size", 14)
	item.custom_minimum_size.y = 27
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.08, 0.11, 0.12, 0.35)
	flat.content_margin_left = 7
	flat.content_margin_right = 7
	item.add_theme_stylebox_override("normal", flat)
	for state in ["hover", "pressed"]:
		var highlighted: StyleBoxFlat = flat.duplicate()
		highlighted.bg_color = Color(0.14, 0.2, 0.2, 0.72)
		item.add_theme_stylebox_override(state, highlighted)
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func observation_choices(source: String) -> void:
	clear_choices(source + " · " + host.game.stamp())
	if source == "창밖":
		var window_actions := HBoxContainer.new()
		rows.add_child(window_actions)
		choice(window_actions, "R 기록", record)
		choice(window_actions, "X 물러나기", func(): close_view())
		choice(window_actions, "Tab 휴대폰", host.phone)
		choices.offset_top = -92
		return
	var row := HBoxContainer.new()
	rows.add_child(row)
	choice(row, "1 인터폰", func(): host.full.observe("인터폰"))
	choice(row, "2 렌즈", func(): host.full.observe("현관 렌즈"))
	choice(row, "3 듣기", host.full.listen)
	choice(row, "4 대화", host.full.dialogue)
	var second := HBoxContainer.new()
	rows.add_child(second)
	opening_button = choice(second, "E 꾹 · 문 열기", func(): pass)
	opening_button.button_down.connect(func(): host.full.holding = true; host.full.hold_cued = false)
	opening_button.button_up.connect(cancel_hold)
	choice(second, "R 기록", record)
	choice(second, "X 물러나기", func(): close_view())
	var third := HBoxContainer.new()
	rows.add_child(third)
	choice(third, "T 3분 기다리기", host.full.wait_at_door)
	choice(third, "Tab 주문", host.phone)
	choice(third, "G 산책", host.walk)

func say(text: String, seconds: float = -1) -> void:
	subtitle.text = text
	subtitle_box.show()
	subtitle_for = seconds

func record() -> void:
	var found: bool = host.game.collect(host.full.current_source)
	say("증거를 기록했다. 휴대폰으로 전달할 수 있다." if found else "새로 기록할 증거는 없다.", 4)
	set_gesture("tap")

func cancel_hold() -> void:
	if host.full == null: return
	host.full.holding = false
	host.full.hold_time = 0
	host.full.hold_cued = false
	if is_instance_valid(host.full.audio): host.full.audio.stop_cue("unlock")
	if gesture == "open": set_gesture("idle")
	if is_instance_valid(host.door_handle): host.door_handle.rotation.z = 0
	if is_instance_valid(host.door_lock): host.door_lock.rotation.z = 0

func begin_unlock() -> void:
	clear_snapshot()
	view = "unlock"
	set_gesture("open")
	if rows.get_child_count() > 0: rows.get_child(0).text = "현관 · 손을 뻗어 잠금쇠를 돌린다"
	if is_instance_valid(camera_tween): camera_tween.kill()
	var desired := Transform3D.IDENTITY
	desired.origin = Vector3(0.48, 1.42, -4.02)
	desired = desired.looking_at(Vector3(0.45, 1.25, -4.7))
	desired = host.player.global_transform.affine_inverse() * desired
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(host.camera, "position", desired.origin, 0.35)
	camera_tween.tween_property(host.camera, "quaternion", desired.basis.get_rotation_quaternion(), 0.35)

func close_view(animate: bool = true) -> void:
	cancel_hold()
	if host.full != null: host.full.looking = false
	var was_viewing := view != "room" or returning
	clear_snapshot()
	choices.hide()
	subtitle_box.hide()
	view = "room"
	set_gesture("idle")
	if is_instance_valid(camera_tween): camera_tween.kill()
	returning = false
	if was_viewing:
		if animate and DisplayServer.get_name() != "headless":
			returning = true
			camera_tween = create_tween().set_parallel(true)
			camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			camera_tween.tween_property(host.camera, "transform", return_pose, 0.32)
			camera_tween.tween_property(host.camera, "fov", host.preferred_fov, 0.32)
			camera_tween.chain().tween_callback(func(): returning = false)
		else:
			host.camera.transform = return_pose
			host.camera.fov = host.preferred_fov
	if not host.modal.visible: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func input(event: InputEvent) -> bool:
	if view == "room": return returning
	if event is InputEventKey:
		if event.keycode == KEY_E and not event.pressed:
			cancel_hold()
			return true
		if not event.pressed or event.echo: return true
		if view in ["opening", "death", "activity"]: return true
		if event.keycode in [KEY_X, KEY_ESCAPE]:
			close_view()
			return true
		if view == "dialogue":
			var index: int = event.keycode - KEY_1
			if index >= 0 and index < actions.size(): actions[index].call()
			return true
		if view == "창밖":
			if event.keycode == KEY_R: record()
			elif event.keycode == KEY_TAB: host.phone()
			return true
		match event.keycode:
			KEY_1: host.full.observe("인터폰")
			KEY_2: host.full.observe("현관 렌즈")
			KEY_3: host.full.listen()
			KEY_4: host.full.dialogue()
			KEY_E: host.full.holding = true
			KEY_R: record()
			KEY_T: host.full.wait_at_door()
			KEY_TAB: host.phone()
			KEY_G: host.walk()
	return true

func look_impulse(relative: Vector2) -> void:
	sway = (sway + relative * 0.0002).clamp(Vector2(-0.018, -0.012), Vector2(0.018, 0.012))

func update(delta: float) -> void:
	if host == null: return
	elapsed += delta
	gesture_time += delta
	var playing: bool = host.full != null and host.full.active
	hands_root.visible = playing and (not host.modal.visible or gesture == "phone")
	if subtitle_for > 0:
		subtitle_for -= delta
		if subtitle_for <= 0: subtitle_box.hide()
	if not playing: return
	sway = sway.lerp(Vector2.ZERO, minf(delta * 7, 1))
	if view == "room" and not returning and not host.activity_transition and not host.modal.visible:
		var velocity: Vector3 = host.player.velocity
		var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.08
		var motion: float = 1.0 if host.camera_motion else 0.0
		var breath: float = sin(elapsed * 1.7) * 0.003 * motion
		var bob: float = (absf(sin(host.walk_phase)) - 0.5) * 0.022 * motion if moving else 0.0
		var desired := Vector3(-sway.x * motion, 1.6 + breath + bob, 0)
		host.camera.position = host.camera.position.lerp(desired, minf(delta * 12, 1))
		host.camera.rotation.z = lerpf(host.camera.rotation.z, clampf(-host.player.basis.inverse().x.dot(velocity) * 0.006, -0.015, 0.015) * motion, minf(delta * 7, 1))
		var focus: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
		host.camera.fov = lerpf(host.camera.fov, maxf(55, host.preferred_fov - 8) if focus else host.preferred_fov, minf(delta * 8, 1))
	for i in range(hands.size()):
		var side: float = -1.0 if i == 0 else 1.0
		var pos := Vector3(side * 0.29, -0.62, -0.36)
		var rot := Vector3(-0.2, side * -0.12, side * -0.12)
		if gesture in ["tap", "lens"] and i == 1 and gesture_time < 0.85:
			pos = Vector3(0.17, -0.29, -0.52)
			rot = Vector3(-0.35, 0, -0.15)
			if gesture == "tap" and view in ["인터폰", "dialogue"]:
				pos = host.camera.to_local(Vector3(1.37, 1.31, -4.615)) - Vector3(0.03, 0.17, 0)
				rot = Vector3(-0.1, 0, 0)
		elif gesture == "listen" and i == 0:
			pos = host.camera.to_local(Vector3(-0.05, 1.3, -4.68)) - Vector3(0, 0.08, 0)
			rot = Vector3(-0.2, 0.3, -0.35)
		elif gesture == "open" and i == 1 and (view == "unlock" or gesture_time < 0.55):
			pos = host.camera.to_local(host.door_handle.global_position) - Vector3(0, 0.08, 0)
			rot = Vector3(-0.35, 0, -0.2 - minf(host.full.hold_time / 1.2, 1) * 0.5)
		elif gesture == "work":
			pos = Vector3(side * 0.2, -0.37 + sin(gesture_time * 19 + i) * 0.006, -0.49)
			var keyboard_hand: Vector3 = host.camera.to_local(Vector3(-3.4 + side * 0.2, 0.82, -3.47))
			if keyboard_hand.length() < 1.8:
				pos = keyboard_hand + Vector3(0, sin(gesture_time * 19 + i) * 0.006, 0)
			rot = Vector3(-1.45, 0, side * -0.15)
		elif gesture == "eat" and i == 1:
			pos = Vector3(0.12, -0.29 + sin(minf(gesture_time / 1.5, 1) * PI) * 0.12, -0.32)
			rot = Vector3(-0.1, 0, -0.25)
		elif gesture == "phone" and i == 0:
			pos = Vector3(-0.24, -0.35, -0.43)
			rot = Vector3(-0.4, 0.3, 0.15)
		if host.camera_motion:
			pos.x -= sway.x * 0.7
			pos.y += sin(elapsed * 1.7 + i) * 0.002
			if host.game.sanity < 25 and view != "room": pos.x += sin(elapsed * 24) * 0.002
		hands[i].position = hands[i].position.lerp(pos, minf(delta * 11, 1))
		hands[i].rotation = hands[i].rotation.lerp(rot, minf(delta * 10, 1))
	for i in range(fingers.size()):
		var curl: float = -0.3
		if gesture == "work": curl = -0.5 + sin(gesture_time * 21 + i * 1.8) * 0.35
		elif gesture == "open": curl = -0.9
		elif gesture == "tap" and i >= 4: curl = -0.15 if i == 7 else -0.95
		fingers[i].rotation.x = lerpf(fingers[i].rotation.x, curl, minf(delta * 12, 1))
		fingers[i].get_child(1).rotation.x = curl * 0.6
	cup.visible = gesture == "eat"
	phone_prop.visible = gesture == "phone"
	if is_instance_valid(attacker) and view == "death":
		var step := sin(maxf(0, gesture_time - 0.68) * 14)
		attacker.get_node("LegL").rotation.x = step * 0.23
		attacker.get_node("LegR").rotation.x = -step * 0.23
		attacker.get_node("ArmL").rotation.x = -step * 0.17
		attacker.get_node("ArmR").rotation.x = step * 0.17
		attacker.get_node("Head").rotation.z = 0.13

func activity(kind: String) -> void:
	close_view(false)
	return_pose = host.camera.transform
	view = "activity"
	set_gesture("work" if kind == "업무" else ("eat" if kind == "식사" else "sleep"))
	if is_instance_valid(camera_tween): camera_tween.kill()
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if kind == "업무":
		camera_tween.tween_property(host.camera, "position:y", 1.18, 0.5)
		camera_tween.tween_property(host.camera, "rotation:x", -0.12, 0.5)
	elif kind == "수면":
		camera_tween.tween_property(host.camera, "position:y", 1.23, 0.6)
		camera_tween.tween_property(host.camera, "rotation:z", 0.1 if host.camera_motion else 0.0, 0.6)
		camera_tween.tween_property(veil, "color:a", 0.98, 0.65)

func finish_activity() -> void:
	if veil.color.a > 0:
		create_tween().tween_property(veil, "color:a", 0.0, 0.28)
	close_view()

func animate_open(dead: bool, result: String) -> void:
	clear_snapshot()
	choices.hide()
	subtitle_box.hide()
	view = "death" if dead else "opening"
	set_gesture("open")
	if is_instance_valid(camera_tween): camera_tween.kill()
	var desired := Transform3D.IDENTITY
	desired.origin = Vector3(0.48, 1.58, -3.65)
	desired = desired.looking_at(Vector3(0.25, 1.1, -5.5))
	desired = host.player.global_transform.affine_inverse() * desired
	camera_tween = create_tween().set_parallel(true)
	camera_tween.tween_property(host.camera, "position", desired.origin, 0.25)
	camera_tween.tween_property(host.camera, "quaternion", desired.basis.get_rotation_quaternion(), 0.25)
	if is_instance_valid(door_tween): door_tween.kill()
	door_tween = create_tween()
	door_tween.tween_property(host.door_handle, "rotation:z", -0.35, 0.18)
	door_tween.tween_property(host.entrance_hinge, "rotation:y", -1.4 if dead else -0.92, 0.5).set_trans(Tween.TRANS_SINE)
	if dead:
		var builder := preload("res://scripts/observation_3d.gd").new()
		attacker = builder.visitor_model()
		builder.free()
		host.add_child(attacker)
		attacker.position = Vector3(0, 0, -5.45)
		door_tween.tween_callback(func(): host.full.audio.cue("steps_near"))
		door_tween.tween_property(attacker, "position:z", -4.3, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		door_tween.tween_property(veil, "color:a", 1.0, 0.18)
	else:
		door_tween.tween_interval(0.25)
		door_tween.tween_property(host.entrance_hinge, "rotation:y", 0, 0.42).set_trans(Tween.TRANS_SINE)
		door_tween.tween_property(host.door_handle, "rotation:z", 0, 0.15)
		door_tween.tween_callback(func():
			close_view()
			say(result, 4))

func reset() -> void:
	if is_instance_valid(door_tween): door_tween.kill()
	if is_instance_valid(attacker): attacker.queue_free()
	attacker = null
	veil.color.a = 0
	close_view(false)
	host.entrance_hinge.rotation.y = 0
	host.door_handle.rotation.z = 0
	host.door_lock.rotation.z = 0
