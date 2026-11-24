extends Control

signal camera_changed
signal cinematic_requested

enum Cinematic { IDLE, ARMED, PLAYING }
var cinematic_state := Cinematic.IDLE
var steering := 0.0
var throttle := false
var braking := false
var handbrake_touch := false
var speed_kmh := 0
var distance_km := 0.0
var camera_mode := 0
var fingers := {}
var wheel_id := -99
var wheel_start := 0.0
var ui_time := 0.0
const ACCENT := Color("#bbef77")
const INK := Color(0.035,0.064,0.072,0.81)
const PAPER := Color("#f5f4e9")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func wheel_center() -> Vector2:
	return Vector2(119,size.y-118)

func gas_rect() -> Rect2:
	return Rect2(size.x-114,size.y-182,83,145)

func brake_rect() -> Rect2:
	return Rect2(size.x-221,size.y-143,85,106)

func handbrake_rect() -> Rect2:
	return Rect2(size.x-253, size.y-233, 113, 67)

func handbrake_active() -> bool:
	return handbrake_touch or Input.is_key_pressed(KEY_SPACE)

func camera_rect() -> Rect2:
	return Rect2(size.x-186,23,155,47)

func cinematic_rect() -> Rect2:
	var camera_button := camera_rect()
	return Rect2(camera_button.position + Vector2(0, 56), camera_button.size)

func reset_touches() -> void:
	fingers.clear()
	wheel_id = -99
	steering = 0
	throttle = false
	braking = false
	handbrake_touch = false
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_touches()

func touch(id: int, pos: Vector2, pressed: bool) -> void:
	if not pressed:
		fingers.erase(id)
		if wheel_id == id:
			wheel_id = -99
			steering = 0
	elif cinematic_rect().has_point(pos):
		cinematic_requested.emit()
	elif camera_rect().has_point(pos):
		camera_mode = (camera_mode+1)%3
		camera_changed.emit()
	elif wheel_id == -99 and pos.distance_to(wheel_center()) < 110:
		wheel_id = id
		wheel_start = pos.x
		fingers[id] = "wheel"
	else:
		var pedal_name := pedal_at(pos, 7)
		if not pedal_name.is_empty():
			fingers[id] = pedal_name
	update_pedals()

func pedal_at(pos: Vector2, margin: float) -> String:
	if handbrake_rect().grow(margin).has_point(pos):
		return "handbrake"
	if gas_rect().grow(margin).has_point(pos):
		return "gas"
	if brake_rect().grow(margin).has_point(pos):
		return "brake"
	return ""

func update_pedals() -> void:
	var held := fingers.values()
	throttle = held.has("gas")
	braking = held.has("brake")
	handbrake_touch = held.has("handbrake")
	queue_redraw()

func drag(id: int, pos: Vector2) -> void:
	if id == wheel_id:
		steering = clampf((pos.x-wheel_start)/64.0,-1,1)
		queue_redraw()
	elif fingers.has(id):
		fingers[id] = pedal_at(pos, 9)
		update_pedals()

func _input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		touch(e.index,e.position,e.pressed and not e.canceled)
	elif e is InputEventScreenDrag:
		drag(e.index,e.position)
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.device != InputEvent.DEVICE_ID_EMULATION:
		touch(-1,e.position,e.pressed)
	elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT and e.device != InputEvent.DEVICE_ID_EMULATION:
		drag(-1,e.position)
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_V:
		cinematic_requested.emit()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode==KEY_C:
		camera_mode=(camera_mode+1)%3
		camera_changed.emit()

func panel(r: Rect2, color: Color, radius: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color=color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(1)
	box.border_color=Color(1,1,1,0.23)
	draw_style_box(box,r)

func title(pos: Vector2, value: String, px: int, color := PAPER) -> void:
	draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func pedal(r: Rect2, label: String, on: bool, gas: bool) -> void:
	panel(r,Color("#87ad65") if on else INK,13)
	for i in 3:
		var y := r.position.y + 18.0 + i*7
		draw_line(Vector2(r.position.x+18,y),Vector2(r.end.x-18,y),Color(1,1,1,0.36),2)
	title(Vector2(r.position.x+16,r.end.y-16),label,18,ACCENT if gas and not on else PAPER)

func _process(dt: float) -> void:
	ui_time+=dt
	if ui_time>=0.1:
		ui_time=0
		queue_redraw()

func _draw() -> void:
	var w := wheel_center()
	draw_circle(w,86,INK,true,-1,true)
	draw_arc(w,85,0,TAU,80,Color(1,1,1,0.39),2,true)
	draw_arc(w,63,0,TAU,80,PAPER,7,true)
	var angle := steering*1.65
	for a in [0.10, PI-0.10, PI*0.5]:
		var vec := Vector2.from_angle(a+angle)
		draw_line(w+vec*15,w+vec*61,PAPER,6,true)
	draw_circle(w,21,Color("#354749"),true,-1,true)
	draw_arc(w,64,-PI/2-0.12+angle,-PI/2+0.12+angle,10,ACCENT,8,true)
	pedal(gas_rect(),"GAZ",throttle,true)
	pedal(brake_rect(),"FREN",braking,false)
	var lever := handbrake_rect()
	panel(lever, Color("#a94d29") if handbrake_active() else INK, 13)
	draw_string(ThemeDB.fallback_font, lever.position + Vector2(0, 40),
			"EL FRENİ", HORIZONTAL_ALIGNMENT_CENTER, lever.size.x, 18, PAPER)
	panel(Rect2(28,23,223,87),INK,10)
	title(Vector2(43,49),"VORTEX   /   GT",17)
	draw_circle(Vector2(46,76),4,ACCENT)
	title(Vector2(57,82),"%d FPS" % Engine.get_frames_per_second(),17)
	title(Vector2(135,82),"%0.1f KM" % distance_km,17)
	var cam := camera_rect()
	panel(cam,INK,9)
	title(cam.position+Vector2(15,30),["KAM  /  TAKİP","KAM  /  YAKIN","KAM  /  ÖN"][camera_mode],17)
	var cine := cinematic_rect()
	panel(cine, Color("#355746") if cinematic_state != Cinematic.IDLE else INK, 9)
	var label := ["SİNEMATİK", "KAYMA BEKLENİYOR", "ÇEKİMİ BİTİR"][cinematic_state] as String
	draw_string(ThemeDB.fallback_font, cine.position + Vector2(0, 29),
			label, HORIZONTAL_ALIGNMENT_CENTER, cine.size.x, 14, PAPER)
	var speed_box := Rect2(size.x/2-71,size.y-83,142,58)
	panel(speed_box,INK,12)
	title(speed_box.position+Vector2(14,41),"%03d"%speed_kmh,34)
	title(speed_box.position+Vector2(88,38),"KM/H",15,ACCENT)
