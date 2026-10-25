extends RefCounted

const ROOT := "res://assets/kenney_furniture/"

static func mesh_bounds(node: Node, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var transform := parent_transform
	if node is Node3D:
		transform = parent_transform * node.transform
	var result := AABB()
	if node is MeshInstance3D:
		result = transform * node.get_aabb()
	for child in node.get_children():
		var bounds := mesh_bounds(child, transform)
		if bounds.size.length() > 0.001:
			result = bounds if result.size.length() < 0.001 else result.merge(bounds)
	return result

static func asset(host: Node3D, name: String, pos: Vector3, height: float, angle: float = 0.0) -> Node3D:
	var scene := load(ROOT + name + ".glb") as PackedScene
	assert(scene != null, "Missing asset: " + name)
	var holder := Node3D.new()
	holder.name = "Asset_" + name
	host.add_child(holder)
	var model := scene.instantiate() as Node3D
	holder.add_child(model)
	# Keep original material separation while bringing furniture into the room palette.
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var original = mesh.mesh.surface_get_material(surface)
			if original is StandardMaterial3D:
				var muted: StandardMaterial3D = original.duplicate()
				var level := muted.albedo_color.v
				var pale := Color("b8b0a0") if name in ["books", "cardboardBoxClosed", "rugDoormat"] else Color("82999a")
				muted.albedo_color = pale if level > 0.72 else (Color("66716d") if level > 0.38 else Color("252e35"))
				muted.roughness = 0.94
				mesh.set_surface_override_material(surface, muted)
	var bounds := mesh_bounds(model)
	var factor := height / maxf(bounds.size.y, 0.001)
	model.scale *= factor
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	holder.position = pos
	holder.rotation.y = angle
	return holder

static func collider(host: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = pos
	body.add_child(shape)
	host.add_child(body)

static func furnish(host: Node3D) -> void:
	asset(host, "desk", Vector3(-3.4, 0, -3.9), 0.78)
	collider(host, Vector3(-3.4, 0.39, -3.9), Vector3(2.1, 0.78, 0.95))
	asset(host, "computerScreen", Vector3(-3.4, 0.78, -4.05), 0.55)
	asset(host, "computerKeyboard", Vector3(-3.4, 0.79, -3.65), 0.045)
	asset(host, "computerMouse", Vector3(-2.88, 0.79, -3.67), 0.04)
	asset(host, "chairDesk", Vector3(-3.5, 0, -2.7), 1.0)
	asset(host, "lampRoundTable", Vector3(-4.22, 0.78, -4.0), 0.48)
	host.station("업무 PC", Vector3(-3.4, 1.1, -3.1), Color("92c8b6"))
	asset(host, "kitchenCabinetDrawer", Vector3(3.3, 0, -4.3), 0.95)
	asset(host, "kitchenSink", Vector3(4.3, 0, -4.3), 0.95)
	asset(host, "kitchenFridge", Vector3(4.38, 0, -2.5), 1.95, -PI / 2)
	collider(host, Vector3(3.7, 0.47, -4.3), Vector3(2.2, 0.94, 1))
	collider(host, Vector3(4.38, 0.97, -2.5), Vector3(1, 1.94, 1))
	asset(host, "kitchenCabinetUpperDouble", Vector3(3.65, 1.8, -4.55), 0.7)
	asset(host, "kitchenMicrowave", Vector3(3.25, 0.96, -4.3), 0.34)
	asset(host, "kitchenCoffeeMachine", Vector3(4.1, 0.96, -4.5), 0.31)
	asset(host, "cardboardBoxClosed", Vector3(3.0, 0.96, -3.98), 0.24)
	host.station("식료품", Vector3(3.5, 1.15, -3.3), Color("d9bd84"))
	asset(host, "bedSingle", Vector3(-3.65, 0, 2.8), 0.86)
	collider(host, Vector3(-3.65, 0.4, 2.8), Vector3(1.6, 0.8, 2.7))
	asset(host, "cabinetBedDrawer", Vector3(-2.4, 0, 3.7), 0.6)
	asset(host, "lampRoundTable", Vector3(-2.4, 0.6, 3.7), 0.45)
	host.station("침대", Vector3(-2.6, 0.9, 2.3), Color("92c8b6"))
	asset(host, "rugRectangle", Vector3(0, 0.02, 2.6), 0.035)
	asset(host, "loungeSofa", Vector3(0, 0, 3.8), 1.05)
	collider(host, Vector3(0, 0.48, 3.8), Vector3(2.5, 0.96, 1))
	asset(host, "tableCoffee", Vector3(0, 0, 2.0), 0.44)
	collider(host, Vector3(0, 0.22, 2), Vector3(1.6, 0.44, 0.8))
	asset(host, "books", Vector3(0.2, 0.44, 2), 0.12)
	asset(host, "radio", Vector3(-0.4, 0.44, 2), 0.2)
	asset(host, "bookcaseOpen", Vector3(4.65, 0, 2), 1.8, -PI / 2)
	asset(host, "pottedPlant", Vector3(4.25, 0, 4.2), 1.1)
	asset(host, "plantSmall1", Vector3(4.5, 1.8, 2), 0.3)
	asset(host, "lampRoundFloor", Vector3(1.7, 0, 3.9), 1.9)
	asset(host, "coatRackStanding", Vector3(-1.5, 0, -4.3), 1.8)
	asset(host, "rugDoormat", Vector3(0, 0.015, -4.1), 0.02)
	asset(host, "trashcan", Vector3(2.55, 0, -4.35), 0.55)
	asset(host, "sideTable", Vector3(3.6, 0, 0.2), 0.72)
	collider(host, Vector3(3.6, 0.36, 0.2), Vector3(0.95, 0.72, 0.8))
	host.block(Vector3(3.6, 0.76, 0.2), Vector3(0.18, 0.035, 0.33), Color("72b6b1"), false, true)
	host.station("휴대폰", Vector3(3.1, 1, 0.2), Color("92c8b6"))
	host.block(Vector3(3.0, 1.8, 4.85), Vector3(2.8, 1.5, 0.12), Color("111e2b"), true, true)
	asset(host, "wallWindowSlide", Vector3(3.0, 1.0, 4.73), 1.65)
	host.station("창밖", Vector3(3, 1.6, 4.4), Color("92c8b6"))
	asset(host, "lampSquareCeiling", Vector3(0, 2.82, 0), 0.15)
