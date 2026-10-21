extends SubViewportContainer

const Furniture = preload("res://scripts/furnished_room.gd")
var source := "인터폰"
var visitor := ""
var parcel := false
var hour := 18.0

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

func _ready() -> void:
	stretch = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 340)
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("080e16")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("95b4c4")
	environment.ambient_light_energy = 0.38
	world.environment = environment
	stage.add_child(world)
	var light := OmniLight3D.new()
	light.position = Vector3(-1.0, 2.8, -1)
	light.light_color = Color("bac8a9")
	light.light_energy = 1.8
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
		camera.look_at(Vector3(0, 1.0, -2.3))
		camera.fov = 57 if source == "현관 렌즈" else 48
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
		for y in range(0, int(scan.size.y), 4):
			scan.draw_line(Vector2(0, y), Vector2(scan.size.x, y), Color(0, 0, 0, 0.14))
		scan.draw_rect(Rect2(Vector2.ZERO, scan.size), Color("c26c66") if source == "조우" else Color("71918b"), false, 2))
	add_child(scan)

func build_corridor(stage: Node3D) -> void:
	box(stage, Vector3(0, -0.12, -3), Vector3(5, 0.24, 14), Color("62685c"))
	box(stage, Vector3(-2.5, 1.5, -3), Vector3(0.15, 3, 14), Color("636c60"))
	box(stage, Vector3(2.5, 1.5, -3), Vector3(0.15, 3, 14), Color("636c60"))
	box(stage, Vector3(0, 1.5, -9), Vector3(5, 3, 0.1), Color("424c48"))
	for z in [-2.0, -5.0, -8.0]:
		Furniture.asset(stage, "doorwayFront", Vector3(-2.4, 0, z), 2.4, PI / 2)
	for i in range(14):
		box(stage, Vector3(0, 0.005, -9 + i), Vector3(5, 0.006, 0.012), Color("353f3b"))
	Furniture.asset(stage, "rugDoormat", Vector3(0, 0.01, -0.6), 0.02)
	if parcel:
		Furniture.asset(stage, "cardboardBoxClosed", Vector3(0.85, 0, -1.0), 0.42)
	if not visitor.is_empty():
		var actor = load("res://assets/kenney_character/person.glb").instantiate()
		stage.add_child(actor)
		actor.position = Vector3(0, 0, -2.2)
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			var mat: StandardMaterial3D = mesh.get_active_material(0).duplicate()
			mat.albedo_color = Color("48515a") if visitor == "stalker" else Color("d2c695")
			mesh.material_override = mat
		if visitor == "stalker":
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
