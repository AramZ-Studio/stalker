extends SubViewportContainer

const Furniture = preload("res://scripts/furnished_room.gd")
var source := "인터폰"
var visitor := ""
var parcel := false
var hour := 18.0
var uncertain := false
var lurking := false
var peer_count := 0
var variant := 0
var clue_visible := false
var mail := false
var render_size := Vector2i(960, 340)
var snapshot_viewport: SubViewport
var capture_delay := 2

func _init() -> void:
	custom_minimum_size = Vector2(0, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func box(root: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> void:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	item.material_override = mat
	item.position = pos
	root.add_child(item)

func visitor_model() -> Node3D:
	# A self-contained silhouette avoids depending on a locally baked character GLB.
	var actor := Node3D.new()
	box(actor, Vector3(0, 1.08, 0), Vector3(0.43, 0.62, 0.27), Color("252e35"))
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0 else "LegR"
		leg.position = Vector3(side * 0.12, 0.86, 0)
		actor.add_child(leg)
		box(leg, Vector3(0, -0.43, 0), Vector3(0.17, 0.86, 0.2), Color("101b1e"))
		box(leg, Vector3(0, -0.8, 0.09), Vector3(0.19, 0.12, 0.34), Color("101b1e"))
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0 else "ArmR"
		arm.position = Vector3(side * 0.28, 1.32, 0)
		actor.add_child(arm)
		box(arm, Vector3(0, -0.28, 0), Vector3(0.14, 0.6, 0.18), Color("252e35"))
	var head_pivot := Node3D.new()
	head_pivot.name = "Head"
	head_pivot.position = Vector3(0, 1.59, 0)
	actor.add_child(head_pivot)
	var head := MeshInstance3D.new()
	var face := SphereMesh.new()
	face.radius = 0.15
	face.height = 0.38
	face.radial_segments = 12
	face.rings = 6
	head.mesh = face
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("b8b0a0")
	skin.roughness = 1
	head.material_override = skin
	head_pivot.add_child(head)
	for side in [-1.0, 1.0]:
		box(head_pivot, Vector3(side * 0.052, 0.04, 0.135), Vector3(0.045, 0.013, 0.025), Color("66716d"))
	return actor

func _ready() -> void:
	stretch = true
	if uncertain: stretch_shrink = 2
	if DisplayServer.get_name() != "headless":
		var filter := ShaderMaterial.new()
		filter.shader = preload("res://scripts/observation_filter.gdshader")
		filter.set_shader_parameter("monitor", source == "인터폰")
		filter.set_shader_parameter("peephole", source == "현관 렌즈")
		filter.set_shader_parameter("aspect", size.x / maxf(size.y, 1))
		material = filter
		resized.connect(func(): filter.set_shader_parameter("aspect", size.x / maxf(size.y, 1)))
	var viewport := SubViewport.new()
	snapshot_viewport = viewport
	viewport.size = render_size
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101b1e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("82999a")
	environment.ambient_light_energy = 0.3 if uncertain else 0.38
	world.environment = environment
	stage.add_child(world)
	var light := OmniLight3D.new()
	light.position = Vector3(-1.0, 2.8, -1)
	light.light_color = Color("d2dac2")
	light.light_energy = 1.2 if uncertain else 1.8
	light.shadow_enabled = true
	light.omni_range = 12
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	if source == "창밖":
		build_street(stage)
		camera.position = Vector3(1, 5, 7)
		camera.look_at(Vector3(0, 0, -2))
		camera.fov = 55
	else:
		build_corridor(stage)
		camera.position = Vector3(0.65, 1.65, 1.2) if source == "인터폰" else Vector3(-0.5, 1.2, 0.9)
		camera.look_at(Vector3(0, 0.8, -2.3))
		camera.fov = 57 if source == "현관 렌즈" else 48
		if uncertain and source == "현관 렌즈":
			camera.position = Vector3(0, 1.55, 1.2)
			camera.look_at(Vector3(2.15, 1.1, 1.1) if lurking else Vector3(0, 1.1, -2.2))
			camera.fov = 60
		if source == "조우":
			camera.position = Vector3(0, 1.58, -1.35)
			camera.look_at(Vector3(0, 1.48, -2.2))
			camera.fov = 65
			light.light_color = Color("d37b73")
	# Render the scene once. Observation never advances game time.
	var scan := Control.new()
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scan.draw.connect(func():
		if source == "인터폰":
			for y in range(0, int(scan.size.y), 4):
				scan.draw_line(Vector2(0, y), Vector2(scan.size.x, y), Color(0, 0, 0, 0.06))
		scan.draw_rect(Rect2(Vector2.ZERO, scan.size), Color("9b635b") if source == "조우" else Color("82999a"), false, 2))
	add_child(scan)

func _process(_delta: float) -> void:
	capture_delay -= 1
	if capture_delay <= 0:
		# Hierarchical limb transforms must reach the rendering server before freezing.
		if is_instance_valid(snapshot_viewport) and is_visible_in_tree():
			for node in snapshot_viewport.find_children("*", "Node3D", true, false): node.force_update_transform()
			snapshot_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		set_process(false)

func build_corridor(stage: Node3D) -> void:
	box(stage, Vector3(0, -0.12, -3), Vector3(5, 0.24, 14), Color("252e35"))
	box(stage, Vector3(-2.5, 1.5, -3), Vector3(0.15, 3, 14), Color("66716d"))
	box(stage, Vector3(2.5, 1.5, -3), Vector3(0.15, 3, 14), Color("66716d"))
	box(stage, Vector3(0, 2.75, -4), Vector3(0.85, 0.04, 0.2), Color("d2dac2"))
	box(stage, Vector3(0, 1.25, -8.85), Vector3(1.15, 2.5, 0.06), Color("82999a"))
	box(stage, Vector3(0, 2.6, -8.8), Vector3(0.2, 0.06, 0.02), Color("9b635b"))
	box(stage, Vector3(0, 1.5, -9), Vector3(5, 3, 0.1), Color("424c48"))
	for z in [-2.0, -5.0, -8.0]:
		Furniture.asset(stage, "doorwayFront", Vector3(-2.4, 0, z), 2.4, PI / 2)
	for i in range(14):
		box(stage, Vector3(0, 0.005, -9 + i), Vector3(5, 0.006, 0.012), Color("353f3b"))
	Furniture.asset(stage, "rugDoormat", Vector3(0, 0.01, -0.6), 0.02)
	if parcel:
		Furniture.asset(stage, "cardboardBoxClosed", Vector3(0.85, 0, -1.0), 0.42)
	if mail:
		box(stage, Vector3(-0.25, 0.02, -0.65), Vector3(0.32, 0.025, 0.24), Color("b8b0a0"))
	if not visitor.is_empty():
		var actor := visitor_model()
		stage.add_child(actor)
		actor.position = Vector3(0, 0, -2.2)
		if uncertain and peer_count >= 2 and not lurking:
			actor.position.z = -1.85
		if uncertain and lurking:
			actor.position = Vector3(2.15, 0, 1.1)
			actor.rotation.y = -PI / 2
		if uncertain:
			var p: Vector3 = actor.position
			# Identical rain hood and parcel props for all ambiguous visitors.
			box(stage, p + Vector3(0, 1.78, 0), Vector3(0.38, 0.12, 0.32), Color("101b1e"))
			for side in [-1.0, 1.0]:
				box(stage, p + Vector3(side * 0.17, 1.62, 0), Vector3(0.06, 0.3, 0.3), Color("101b1e"))
			box(stage, p + Vector3(0, 1.05, 0), Vector3(0.5, 0.6, 0.26), Color("253135"))
			if not lurking:
				Furniture.asset(stage, "cardboardBoxClosed", p + Vector3(0.2, 0.65, 0.25), 0.35)
			if variant == 1:
				box(stage, p + Vector3(0, 1.7, 0.18), Vector3(0.52, 0.035, 0.24), Color("101b1e"))
			elif variant == 2:
				box(stage, p + Vector3(-0.3, 1.0, 0.12), Vector3(0.15, 0.48, 0.16), Color("252e35"))
			if clue_visible:
				box(stage, p + Vector3(-0.28, 0.86, 0.28), Vector3(0.12, 0.19, 0.12), Color("b8b0a0"))
				var wrist := p + (Vector3(-0.346, 0.9, 0.28) if lurking else Vector3(-0.28, 0.9, 0.346))
				for i in range(11):
					var angle := deg_to_rad(60 + i * 24)
					var offset := Vector3(0, sin(angle), cos(angle)) if lurking else Vector3(cos(angle), sin(angle), 0)
					box(stage, wrist + offset * 0.033, Vector3(0.011, 0.011, 0.011), Color("101b1e"))
		elif visitor == "stalker":
			box(stage, Vector3(0, 1.73, -2.12), Vector3(0.43, 0.13, 0.38), Color("10171a"))
			box(stage, Vector3(0, 1.68, -1.95), Vector3(0.5, 0.04, 0.3), Color("10171a"))
			if source == "현관 렌즈":
				var clue := Label3D.new()
				clue.text = "☾ 손목 문신"
				clue.font_size = 34
				clue.position = Vector3(-0.4, 0.86, -1.75)
				clue.pixel_size = 0.0025
				clue.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				stage.add_child(clue)
		else:
			box(stage, Vector3(0, 1.04, -2.05), Vector3(0.46, 0.47, 0.15), Color("b0b24e"))
			box(stage, Vector3(0.13, 0.98, -1.92), Vector3(0.06, 0.35, 0.02), Color("e7dfb0"))
			box(stage, Vector3(-0.35, 0.9, -1.94), Vector3(0.13, 0.21, 0.06), Color("1d262d"))

func build_street(stage: Node3D) -> void:
	box(stage, Vector3(0, -0.2, -3), Vector3(24, 0.3, 30), Color("26343a"))
	for x in [-7.0, 7.0]:
		box(stage, Vector3(x, 3, -6), Vector3(6, 6, 16), Color("3e4745"))
		for z in range(-11, 1, 3):
			for y in [1.5, 4.0]:
				box(stage, Vector3(x * 0.59, y, z), Vector3(0.04, 1.2, 0.85), Color("899681") if z % 2 else Color("111e26"))
	if hour >= 23.0 or hour < 1.0:
		box(stage, Vector3(0, 0.65, -2.2), Vector3(1.8, 0.6, 3.6), Color("141b23"))
		box(stage, Vector3(0, 1.15, -2.4), Vector3(1.6, 0.55, 1.9), Color("263a42"))
		for x in [-0.85, 0.85]:
			for z in [-3.3, -1.1]:
				box(stage, Vector3(x, 0.35, z), Vector3(0.24, 0.6, 0.6), Color("080c10"))
		var plate := Label3D.new()
		plate.text = "7319"
		plate.position = Vector3(0, 0.62, -0.36)
		plate.font_size = 64
		plate.pixel_size = 0.004
		stage.add_child(plate)
