extends Node3D

const Coast = preload("res://scripts/coast.gd")
const HUD = preload("res://scripts/hud.gd")
const TrafficCar = preload("res://scripts/traffic.gd")
const GT := preload("res://assets/gt/VortexGT.gltf")
const SkidMarks = preload("res://scripts/skid_marks.gd")
const WHEEL_IDS := [1,2,3,7]
@export_group("Vortex GT visual trials")
@export var trial_hood_finish := false
@export var trial_running_lights := false
@export var trial_sky_contrast := false
@export var trial_near_shadows := false

var player := Node3D.new()
var cam := Camera3D.new()
var skid_marks := SkidMarks.new()
var rear_mounts: Array[Node3D] = []
var hud := HUD.new()
var wheel_mounts: Array[Node3D] = []
var wheels: Array[Node3D] = []
var traffic: Array[TrafficCar] = []
var speed := 0.0
var steer := 0.0
var lateral := 5.4
var progress := 0.0
var distance := 0.0
var yaw_offset := 0.0
var spin := 0.0
var rear_spin := 0.0
var slip_angle := 0.0
var drift_course_offset := 0.0
var brake_lamp: StandardMaterial3D
var brake_lamp_on := false
const SHOT_DURATION := 1.6
var shot_elapsed := 0.0
var shot_side := 1.0

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#4880aa")
	sky_mat.sky_horizon_color = Color("#e6e2d3")
	sky_mat.ground_horizon_color = Color("#d8d3bf")
	sky_mat.ground_bottom_color = Color("#606958")
	if trial_sky_contrast:
		sky_mat.ground_bottom_color = Color("#383c36")
	sky_mat.sun_angle_max=10.0
	sky.sky_material=sky_mat
	env.sky=sky
	env.background_mode=Environment.BG_SKY
	env.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy=0.74
	env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled=true
	env.fog_light_color=Color("#c9d1c9")
	env.fog_density=0.0028
	env.fog_sky_affect=0.14
	world.environment=env
	add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-38,-49,0)
	sun.light_color=Color("#fff1d7")
	sun.light_energy=1.03
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance = 40.0 if trial_near_shadows else 68.0
	add_child(sun)
	add_child(Coast.new())
	add_child(skid_marks)
	add_child(player)
	var visual := GT.instantiate() as Node3D
	player.add_child(visual)
	brake_lamp = instance_part_material(visual, 4)
	if brake_lamp != null:
		brake_lamp.emission_enabled = true
		brake_lamp.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		brake_lamp.emission = Color("#ff4026")
		brake_lamp.emission_texture = preload("res://assets/gt/lookdev/brake_strip.png")
		brake_lamp.emission_energy_multiplier = 0.0
	if trial_hood_finish:
		var hood := instance_part_material(visual, 5)
		if hood != null:
			hood.roughness = 0.28
	if trial_running_lights:
		set_trial_running_light(visual, 16, preload("res://assets/gt/lookdev/drl_16.png"))
		set_trial_running_light(visual, 23, preload("res://assets/gt/lookdev/drl_23.png"))
	# The source's bonnet points along +Z. Driving uses Godot forward (-Z).
	visual.rotation.y=PI
	visual.scale=Vector3.ONE*4.88
	for id: int in WHEEL_IDS:
		var wheel:=visual.find_child("tripo_part_%d"%id,true,false) as MeshInstance3D
		if wheel==null:
			push_error("Wheel mesh missing: %d"%id)
			continue
		var mount:=Node3D.new()
		wheel.get_parent().add_child(mount)
		var center:=wheel.get_aabb().get_center()
		mount.position=wheel.position+center
		wheel.reparent(mount,false)
		wheel.position=-center
		var pivot:=Node3D.new()
		mount.add_child(pivot)
		wheel.reparent(pivot,false)
		if id in [2, 7]:
			rear_mounts.append(mount)
		wheel_mounts.append(mount)
		wheels.append(pivot)
	for i in 12:
		var car:=TrafficCar.new()
		add_child(car)
		car.setup([Color("#697983"),Color("#a75040"),Color("#c8c5b9"),Color("#425264")][i%4])
		car.lane=[1.85,5.55,-1.85,-5.55][i%4]
		car.pace=[14.5,17.5,-18.0,-15.5][i%4]
		car.progress=33.0+i*37.0
		traffic.append(car)
		place_traffic(car)
	add_child(cam)
	cam.current=true
	cam.near=0.15
	cam.far=540
	cam.fov=59
	var layer:=CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.camera_changed.connect(restore_driving_camera)
	hud.cinematic_requested.connect(toggle_cinematic)
	place_player()
	update_camera(1.0,true)

func instance_part_material(visual: Node3D, part_id: int) -> StandardMaterial3D:
	var part := visual.find_child("tripo_part_%d" % part_id, true, false) as MeshInstance3D
	if part == null or part.mesh == null or part.mesh.get_surface_count() != 1:
		push_warning("Unexpected GT geometry for part %d" % part_id)
		return null
	var source := part.get_active_material(0) as StandardMaterial3D
	if source == null:
		push_warning("Unexpected GT material for part %d" % part_id)
		return null
	var material := source.duplicate(false) as StandardMaterial3D
	part.set_surface_override_material(0, material)
	return material

func set_trial_running_light(visual: Node3D, part_id: int, mask: Texture2D) -> void:
	var lens := instance_part_material(visual, part_id)
	if lens == null:
		return
	lens.emission_enabled = true
	lens.emission = Color(0.0, 0.0, 0.0)
	lens.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
	lens.emission_texture = mask
	lens.emission_energy_multiplier = 0.45

func place_traffic(car: TrafficCar) -> void:
	car.position=Coast.point(car.progress,car.lane,0.014)
	car.rotation.y=Coast.heading(car.progress)+(PI if car.pace<0 else 0.0)

func place_player() -> void:
	player.position=Coast.point(progress,lateral,0.015)
	player.rotation.y=Coast.heading(progress)+yaw_offset+slip_angle
	player.rotation.z=steer*minf(speed/42.0,1.0)*0.021

func _physics_process(dt: float) -> void:
	var gas:=hud.throttle or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var brake:=hud.braking or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	if brake != brake_lamp_on:
		brake_lamp_on = brake
		if brake_lamp != null:
			brake_lamp.emission_energy_multiplier = 1.6 if brake else 0.0
	var handbrake := hud.handbrake_active()
	var axis:=hud.steering
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		axis=-1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		axis=1.0
	steer=move_toward(steer,axis,dt*3.7)
	var accel:=-0.62-0.0017*speed*speed
	if brake:
		accel=-12.4
	elif handbrake:
		accel = -8.5
	elif gas:
		accel=6.9-0.08*speed-0.0012*speed*speed
	speed=clampf(speed+accel*dt,0,49.0)
	yaw_offset=lerpf(yaw_offset,-steer*lerpf(0.34,0.16,speed/49.0),1.0-exp(-4.8*dt))
	# The rear slides out while the direction of travel initially holds its line.
	var target_slip := 0.0
	if handbrake:
		target_slip = -steer * 0.48 * smoothstep(3.0, 17.0, speed)
	slip_angle = lerpf(slip_angle, target_slip, 1.0 - exp(-5.0 * dt))
	# Tire grip steers the velocity towards the rotated body over several ticks.
	# The rear wheels regain grip faster when the lever is released.
	var course_target := slip_angle * 0.45 if handbrake else 0.0
	var grip_rate := 2.4 if handbrake else 5.5
	drift_course_offset = lerpf(drift_course_offset, course_target, 1.0 - exp(-grip_rate * dt))
	var travel_heading := yaw_offset + drift_course_offset
	lateral += -sin(travel_heading) * speed * dt
	var touched_edge := absf(lateral) > 6.73
	if touched_edge:
		lateral=clampf(lateral,-6.73,6.73)
		speed=move_toward(speed,4.0,dt*10.0) if speed>4 else speed
	var travel := cos(travel_heading) * speed * dt
	progress+=travel
	distance+=travel
	var looped:=progress>=Coast.LENGTH
	if looped:
		progress-=Coast.LENGTH
		for car in traffic:
			car.progress-=Coast.LENGTH
	var hit_traffic := false
	for car in traffic:
		car.progress+=car.pace*dt
		var gap:=car.progress-progress
		if gap < -55.0:
			car.progress+=480.0
		elif gap>490.0:
			car.progress-=480.0
		if absf(car.progress-progress)<4.28 and absf(car.lane-lateral)<1.72:
			hit_traffic = true
			speed=minf(speed,maxf(0,car.pace)*0.72)
			if car.pace<0:
				car.progress=progress-58.0
			else:
				progress=minf(progress,car.progress-4.30)
		place_traffic(car)
	spin=fmod(spin+speed*dt/0.36,TAU)
	if not handbrake:
		rear_spin = fmod(rear_spin + speed * dt / 0.36, TAU)
	for i in wheels.size():
		var front_wheel: bool = WHEEL_IDS[i] in [1,3]
		wheels[i].rotation.x = spin if front_wheel else rear_spin
		if front_wheel:
			wheel_mounts[i].rotation.y=-steer*0.38
	place_player()
	if looped or not handbrake or speed < 5.0 or absf(slip_angle - drift_course_offset) < deg_to_rad(4.0):
		skid_marks.tracking = false
	elif rear_mounts.size() == 2:
		skid_marks.sample_wheels(rear_mounts[0].global_position, rear_mounts[1].global_position)
	hud.drift.tick(dt, speed, slip_angle - drift_course_offset, handbrake, touched_edge or hit_traffic)
	advance_cinematic(dt)
	update_camera(dt,looped)
	hud.speed_kmh=roundi(speed*3.6)
	hud.distance_km=distance/1000

func toggle_cinematic() -> void:
	if hud.cinematic_state == HUD.Cinematic.IDLE:
		hud.cinematic_state = HUD.Cinematic.ARMED
	elif hud.cinematic_state == HUD.Cinematic.ARMED:
		hud.cinematic_state = HUD.Cinematic.IDLE
	else:
		restore_driving_camera()
	hud.queue_redraw()

func restore_driving_camera() -> void:
	hud.cinematic_state = HUD.Cinematic.IDLE
	shot_elapsed = 0.0
	update_camera(0.0, true)
	hud.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		hud.drift.finish(false)
		restore_driving_camera()

func advance_cinematic(dt: float) -> void:
	if hud.cinematic_state == HUD.Cinematic.ARMED:
		var sideslip := slip_angle - drift_course_offset
		if speed >= 6.0 and absf(sideslip) >= deg_to_rad(6.0):
			hud.cinematic_state = HUD.Cinematic.PLAYING
			# Near the road edge, put the camera on the road-facing side.
			shot_side = -signf(lateral) if absf(lateral) > 3.0 else signf(sideslip)
			shot_elapsed = 0.0
			hud.queue_redraw()
	elif hud.cinematic_state == HUD.Cinematic.PLAYING:
		shot_elapsed += dt
		if shot_elapsed >= SHOT_DURATION:
			hud.cinematic_state = HUD.Cinematic.IDLE
			hud.queue_redraw()

func update_camera(dt: float, snap: bool) -> void:
	var idle:=1.0-smoothstep(1.0,10.0,speed)
	var back:=Vector3(-2.48*idle,2.12+0.30*(1.0-idle),6.55-0.65*idle)
	var aim:=Vector3(0,0.72,-2.8)
	match hud.camera_mode:
		1:
			back=Vector3(-2.45,1.65,4.55)
			aim=Vector3(0,0.62,-0.3)
		2:
			back=Vector3(2.85,1.63,-5.55)
			aim=Vector3(0,0.62,0)
	var shot_weight := 0.0
	if hud.cinematic_state == HUD.Cinematic.PLAYING:
		shot_weight = smoothstep(0.0, 0.35, shot_elapsed) * smoothstep(0.0, 0.45, SHOT_DURATION - shot_elapsed)
		var sweep := lerpf(0.78, 1.12, shot_elapsed / SHOT_DURATION) * shot_side
		# Orbit at a positive radius even when starting from the front camera.
		var angle := lerp_angle(atan2(back.x, back.z), sweep, shot_weight)
		var radius := lerpf(Vector2(back.x, back.z).length(), 5.7, shot_weight)
		back = Vector3(sin(angle) * radius, lerpf(back.y, 1.3, shot_weight), cos(angle) * radius)
		aim = aim.lerp(Vector3(0.0, 0.74, -0.35), shot_weight)
	cam.fov = lerpf(59.0, 54.0, shot_weight)
	var frame:=Basis(Vector3.UP,Coast.heading(progress)+yaw_offset*0.4)
	var target:=player.position+frame*back
	cam.position=target if snap else cam.position.lerp(target,1.0-exp(-12.0*dt))
	cam.look_at(player.position+frame*aim)
