extends RefCounted

enum Phase { FREE, COUNTDOWN, RACING, FINISHED }
const COURSE_LENGTH := 600.0
const GATE_SPACING := 200.0
const RECORD := "user://coast_sprint.cfg"

var phase := Phase.FREE
var countdown := 0.0
var elapsed := 0.0
var meters := 0.0
var splits: Array[float] = []
var best_ms := 0
var personal_best := false

func load_record() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD) == OK:
		var value: Variant = cfg.get_value("sprint_600", "best_ms", 0)
		if value is int and value > 0:
			best_ms = value

func start() -> void:
	elapsed = 0.0
	meters = 0.0
	splits.clear()
	personal_best = false
	countdown = 3.0
	phase = Phase.COUNTDOWN

func cancel() -> void:
	phase = Phase.FREE

func running_delta(dt: float) -> float:
	if phase != Phase.COUNTDOWN:
		return dt
	if dt < countdown - 0.000001:
		countdown -= dt
		return 0.0
	var leftover := maxf(0.0, dt - countdown)
	countdown = 0.0
	phase = Phase.RACING
	return leftover

func advance(dt: float, position_on_course: float) -> void:
	if phase != Phase.RACING or dt <= 0.0:
		return
	var movement := position_on_course - meters
	while movement > 0.0 and splits.size() < 3:
		var gate := (splits.size() + 1) * GATE_SPACING
		if position_on_course < gate:
			break
		splits.append(elapsed + dt * clampf((gate - meters) / movement, 0.0, 1.0))
	meters = clampf(position_on_course, 0.0, COURSE_LENGTH)
	if splits.size() < 3:
		elapsed += dt
		return
	elapsed = splits.back()
	phase = Phase.FINISHED
	var time_ms := maxi(1, roundi(elapsed * 1000.0))
	personal_best = best_ms == 0 or time_ms < best_ms
	if personal_best:
		best_ms = time_ms
		var cfg := ConfigFile.new()
		cfg.set_value("sprint_600", "best_ms", best_ms)
		if cfg.save(RECORD) != OK:
			push_warning("Could not save coast sprint record")

static func format_time(seconds: float) -> String:
	var hundredths := roundi(seconds * 100.0)
	return "%d:%02d.%02d" % [hundredths / 6000, (hundredths / 100) % 60, hundredths % 100]
