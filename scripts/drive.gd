extends Node3D

const Coast = preload("res://scripts/coast.gd")
const HUD = preload("res://scripts/hud.gd")
const TrafficCar = preload("res://scripts/traffic.gd")
const GT := preload("res://assets/gt/VortexGT.gltf")
const WHEEL_IDS := [1,2,3,7]
var player := Node3D.new()
var cam := Camera3D.new()
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

func _ready() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#4880aa")
	sky_mat.sky_horizon_color = Color("#e6e2d3")
	sky_mat.ground_horizon_color = Color("#d8d3bf")
	sky_mat.ground_bottom_color = Color("#606958")
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
	sun.directional_shadow_max_distance=68
	add_child(sun)
	add_child(Coast.new())
	add_child(player)
	var visual := GT.instantiate() as Node3D
	player.add_child(visual)
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
	hud.camera_changed.connect(func(): update_camera(1.0,true))
	place_player()
	update_camera(1.0,true)

func place_traffic(car: TrafficCar) -> void:
	car.position=Coast.point(car.progress,car.lane,0.014)
	car.rotation.y=Coast.heading(car.progress)+(PI if car.pace<0 else 0.0)

func place_player() -> void:
	player.position=Coast.point(progress,lateral,0.015)
	player.rotation.y=Coast.heading(progress)+yaw_offset
	player.rotation.z=steer*minf(speed/42.0,1.0)*0.021

func _physics_process(dt: float) -> void:
	var gas:=hud.throttle or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var brake:=hud.braking or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var axis:=hud.steering
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		axis=-1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		axis=1.0
	steer=move_toward(steer,axis,dt*3.7)
	var accel:=-0.62-0.0017*speed*speed
	if brake:
		accel=-12.4
	elif gas:
		accel=6.9-0.08*speed-0.0012*speed*speed
	speed=clampf(speed+accel*dt,0,49.0)
	yaw_offset=lerpf(yaw_offset,-steer*lerpf(0.34,0.16,speed/49.0),1.0-exp(-4.8*dt))
	lateral+=-sin(yaw_offset)*speed*dt
	if absf(lateral)>6.73:
		lateral=clampf(lateral,-6.73,6.73)
		speed=move_toward(speed,4.0,dt*10.0) if speed>4 else speed
	var travel:=cos(yaw_offset)*speed*dt
	progress+=travel
	distance+=travel
	var looped:=progress>=Coast.LENGTH
	if looped:
		progress-=Coast.LENGTH
		for car in traffic:
			car.progress-=Coast.LENGTH
	for car in traffic:
		car.progress+=car.pace*dt
		var gap:=car.progress-progress
		if gap < -55.0:
			car.progress+=480.0
		elif gap>490.0:
			car.progress-=480.0
		if absf(car.progress-progress)<4.28 and absf(car.lane-lateral)<1.72:
			speed=minf(speed,maxf(0,car.pace)*0.72)
			if car.pace<0:
				car.progress=progress-58.0
			else:
				progress=minf(progress,car.progress-4.30)
		place_traffic(car)
	spin=fmod(spin+speed*dt/0.36,TAU)
	for i in wheels.size():
		wheels[i].rotation.x=spin
		if WHEEL_IDS[i] in [1,3]:
			wheel_mounts[i].rotation.y=-steer*0.38
	place_player()
	update_camera(dt,looped)
	hud.speed_kmh=roundi(speed*3.6)
	hud.distance_km=distance/1000

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
	var frame:=Basis(Vector3.UP,Coast.heading(progress)+yaw_offset*0.4)
	var target:=player.position+frame*back
	cam.position=target if snap else cam.position.lerp(target,1.0-exp(-12.0*dt))
	cam.look_at(player.position+frame*aim)
