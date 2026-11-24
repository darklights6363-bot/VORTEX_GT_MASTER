extends MultiMeshInstance3D

const CAPACITY := 256
const TIRE_WIDTH := 0.19
const MIN_SPACING := 0.32
const MAX_SPACING := 3.0
const ROAD_HEIGHT := 0.023

var next_slot := 0
var tracking := false
var last_left := Vector3.ZERO
var last_right := Vector3.ZERO

func _ready() -> void:
	var rubber := StandardMaterial3D.new()
	rubber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rubber.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rubber.albedo_color = Color(0.045, 0.04, 0.035, 0.44)
	var strip := PlaneMesh.new()
	strip.size = Vector2.ONE
	strip.material = rubber
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = strip
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func sample_wheels(left: Vector3, right: Vector3) -> void:
	left.y = ROAD_HEIGHT
	right.y = ROAD_HEIGHT
	if tracking:
		var movement := maxf(last_left.distance_to(left), last_right.distance_to(right))
		if movement < MIN_SPACING:
			return
		if movement <= MAX_SPACING:
			add_strip(last_left, left)
			add_strip(last_right, right)
	last_left = left
	last_right = right
	tracking = true

func add_strip(start: Vector3, finish: Vector3) -> void:
	var delta := finish - start
	var length := delta.length()
	if length < 0.001:
		return
	var along := delta / length
	var across := Vector3.UP.cross(along) * TIRE_WIDTH
	var axes := Basis(across, Vector3.UP, delta)
	multimesh.set_instance_transform(next_slot, Transform3D(axes, (start + finish) * 0.5))
	multimesh.visible_instance_count = mini(multimesh.visible_instance_count + 1, CAPACITY)
	next_slot = (next_slot + 1) % CAPACITY
