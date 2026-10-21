extends SceneTree

func _initialize() -> void:
	call_deferred("prepare")

func prepare() -> void:
	var scene = load("res://assets/kenney_character/characterMedium.fbx").instantiate()
	root.add_child(scene)
	var animation_scene = load("res://assets/kenney_character/idle.fbx").instantiate()
	var source_player: AnimationPlayer = animation_scene.find_child("AnimationPlayer", true, false)
	var animator := AnimationPlayer.new()
	scene.add_child(animator)
	animator.add_animation_library("", source_player.get_animation_library("").duplicate(true))
	animator.play("Root|Idle")
	animator.seek(0.5, true)
	animator.advance(0)
	for i in range(3):
		await process_frame
	var baked_root := Node3D.new()
	root.add_child(baked_root)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var baked := MeshInstance3D.new()
		baked.mesh = node.bake_mesh_from_current_skeleton_pose()
		baked.transform = node.global_transform
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/kenney_character/humanMaleA.png")
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		baked.material_override = mat
		baked_root.add_child(baked)
		baked.owner = baked_root
	var bounds: AABB = preload("res://scripts/furnished_room.gd").mesh_bounds(baked_root)
	var scale_factor := 1.8 / bounds.size.y
	for child in baked_root.get_children():
		child.position = (child.position - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)) * scale_factor
		child.scale *= scale_factor
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(baked_root, state) == OK)
	assert(document.write_to_filesystem(state, "res://assets/kenney_character/person.glb") == OK)
	print("CHARACTER_PREPARED ", bounds)
	scene.free()
	animation_scene.free()
	baked_root.free()
	quit()
