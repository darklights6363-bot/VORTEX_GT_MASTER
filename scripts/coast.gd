extends Node3D

const LENGTH := 2400.0
const HALF_WIDTH := 7.5
var batches := {}
var rng := RandomNumberGenerator.new()

static func center(s: float) -> float:
	return 23.0 * sin(TAU * s / 1200.0) + 8.0 * sin(TAU * s / 600.0)

static func heading(s: float) -> float:
	return -atan(23.0 * TAU / 1200.0 * cos(TAU * s / 1200.0) + 8.0 * TAU / 600.0 * cos(TAU * s / 600.0))

static func point(s: float, lateral: float, height: float) -> Vector3:
	return Vector3(center(s), height, -s) + Vector3.RIGHT.rotated(Vector3.UP, heading(s)) * lateral

func surface(color: Color, metal := 0.0, rough := 0.86) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

func add_batch(key: String, geometry: Mesh, material: Material) -> void:
	geometry.material = material
	batches[key] = [geometry, []]

func instance(key: String, pos: Vector3, dims: Vector3, yaw := 0.0) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(dims)
	batches[key][1].append(Transform3D(basis, pos))

func scatter_batches() -> void:
	for key in batches:
		var transforms: Array = batches[key][1]
		# Keep culling local to a short section of road.
		var sections := {}
		for t: Transform3D in transforms:
			var region := floori(t.origin.z / 110.0)
			if not sections.has(region):
				sections[region] = []
			sections[region].append(t)
		for list: Array in sections.values():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = batches[key][0]
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var node := MultiMeshInstance3D.new()
			node.multimesh = mm
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)

func strip(a: float, b: float, h: float, mat: Material, terrain := false) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_material(mat)
	for s in range(-440, int(LENGTH) + 440, 8):
		var points := [Vector2(a,s),Vector2(a,s+8),Vector2(b,s),Vector2(b,s),Vector2(a,s+8),Vector2(b,s+8)]
		for coord: Vector2 in points:
			var y := h
			if terrain:
				y += hillside(coord.y, coord.x)
			var pos := point(coord.y, coord.x, y)
			mesh.set_uv(Vector2(coord.x, coord.y) * 0.26)
			mesh.add_vertex(pos)
	mesh.generate_normals()
	var inst := MeshInstance3D.new()
	inst.mesh = mesh.commit()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)

func hillside(s: float, x: float) -> float:
	var d := maxf(x - 19.0, 0.0)
	return d * (0.29 + 0.12 * sin(s * 0.017 + d * 0.013) + 0.15 * sin(s * 0.008 - d * 0.018))

func _ready() -> void:
	rng.seed = 15031
	var road := surface(Color.WHITE)
	road.albedo_texture = preload("res://assets/asphalt.jpg")
	road.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	strip(-HALF_WIDTH, HALF_WIDTH, 0, road)
	var sand := surface(Color("#d4c0a3"))
	sand.albedo_texture=preload("res://assets/coast-ground.jpg")
	strip(-15,-HALF_WIDTH,-0.045,sand)
	strip(HALF_WIDTH,20,-0.045,sand)
	var rock := surface(Color("#9d9d93"))
	rock.albedo_texture=preload("res://assets/coast-ground.jpg")
	var scrub := surface(Color("#aebd91"))
	scrub.albedo_texture=preload("res://assets/coast-ground.jpg")
	for bounds in [[20,45],[45,90],[90,160],[160,280],[280,450]]:
		strip(bounds[0],bounds[1],-0.08,rock if bounds[0]==45 else scrub,true)
	var water := surface(Color("#235c72"),0.09,0.38)
	strip(-700,-15,-2.6,water)
	var white := surface(Color("#e9e4d5"))
	strip(-7.3,-7.16,0.012,white)
	strip(7.16,7.3,0.012,white)
	strip(-0.16,-0.055,0.014,white)
	strip(0.055,0.16,0.014,white)
	add_batch("dash",BoxMesh.new(),white)
	add_batch("rail",BoxMesh.new(),surface(Color("#a8b0ad"),0.48))
	add_batch("post",BoxMesh.new(),surface(Color("#7b8584"),0.48))
	var needles := StandardMaterial3D.new()
	needles.albedo_texture=preload("res://assets/stone-pine.png")
	needles.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	needles.alpha_scissor_threshold=0.44
	needles.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	needles.billboard_keep_scale=true
	needles.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	needles.cull_mode=BaseMaterial3D.CULL_DISABLED
	add_batch("pine",QuadMesh.new(),needles)
	var distant := SphereMesh.new()
	distant.radial_segments = 12
	distant.rings = 5
	add_batch("ridge",distant,surface(Color("#4d655e")))
	for s in range(-432,int(LENGTH)+432,8):
		for x in [-3.72,3.72]:
			instance("dash",point(s,x,0.016),Vector3(0.13,0.014,3.6),heading(s))
		for x in [-8.15,8.15]:
			var start := point(s,x,0.68)
			var end := point(s+8,x,0.68)
			var d := end-start
			instance("rail",(start+end)*0.5,Vector3(0.12,0.23,d.length()+0.04),atan2(-d.x,-d.z))
			instance("post",point(s,x,0.35),Vector3(0.16,0.78,0.13),heading(s))
		var x := rng.randf_range(17.0,78.0)
		var spot := point(s + rng.randf_range(-3,3),x,hillside(s,x))
		var tall := rng.randf_range(3.8,7.5)
		instance("pine",spot+Vector3.UP*tall*0.5,Vector3(tall*0.96,tall,1.0))
		if s%48==0:
			var peak := rng.randf_range(25.0,52.0)
			instance("ridge",point(s,195,peak*0.25),Vector3(168,peak*1.5,210),rng.randf())
			instance("ridge",point(s,-360,-13),Vector3(132,peak*0.9,193),rng.randf())
	scatter_batches()
