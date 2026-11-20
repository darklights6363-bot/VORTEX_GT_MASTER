extends Node3D

var progress := 0.0
var lane := 0.0
var pace := 0.0

func shape(rings: Array, mat: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mat)
	for i in range(rings.size()-1):
		for side in 4:
			var j := (side+1)%4
			for entry in [[i,side],[i,j],[i+1,side],[i+1,side],[i,j],[i+1,j]]:
				surface.add_vertex(rings[entry[0]][entry[1]])
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh=surface.commit()
	add_child(mesh)

func ring(z: float, low: float, high: float, bottom: float, top: float) -> Array:
	return [Vector3(-bottom,low,z),Vector3(bottom,low,z),Vector3(top,high,z),Vector3(-top,high,z)]

func material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color=color
	m.metallic=metallic
	m.roughness=0.42
	m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m

func part(geom: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	geom.material=mat
	node.mesh=geom
	node.position=pos
	add_child(node)
	return node

func setup(color: Color) -> void:
	shape([ring(-2.02,0.4,0.69,0.75,0.78),ring(-1.65,0.32,0.89,0.88,0.87),ring(-0.7,0.32,0.96,0.90,0.87),ring(1.45,0.32,0.94,0.88,0.83),ring(1.95,0.43,0.79,0.8,0.78)],material(color,0.42))
	shape([ring(-0.83,0.92,0.94,0.82,0.81),ring(-0.2,0.93,1.45,0.85,0.68),ring(0.72,0.93,1.44,0.84,0.66),ring(1.40,0.90,0.94,0.8,0.78)],material(Color("#394957"),0.26))
	var rubber:=material(Color("#23282b"))
	for z in [-1.24,1.23]:
		for x in [-0.86,0.86]:
			var tire:=CylinderMesh.new()
			tire.top_radius=0.32
			tire.bottom_radius=0.32
			tire.height=0.19
			tire.radial_segments=12
			tire.rings=0
			part(tire,rubber,Vector3(x,0.32,z)).rotation.z=PI/2
	for z in [-2.025,1.955]:
		var nose:=BoxMesh.new()
		nose.size=Vector3(1.55,0.25,0.05)
		part(nose,material(color),Vector3(0,0.57,z))
		for x in [-0.57,0.57]:
			var lamp:=BoxMesh.new()
			lamp.size=Vector3(0.33,0.11,0.055)
			part(lamp,material(Color("#eee6be") if z<0 else Color("#bf382f")),Vector3(x,0.69,z+signf(z)*0.035))
