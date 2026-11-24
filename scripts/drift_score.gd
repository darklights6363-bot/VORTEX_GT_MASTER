extends RefCounted

const RECORD_PATH := "user://drift_record.cfg"
const LINK_WINDOW := 1.5
const ENTRY_TIME := 0.18
const REARM_TIME := 0.25
const MAX_MULTIPLIER := 5

var points := 0.0
var multiplier := 0
var best := 0
var message := ""
var message_time := 0.0
var gap := 0.0
var segment_side := 0
var candidate_side := 0
var candidate_time := 0.0

func load_record() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD_PATH) == OK:
		var saved: Variant = cfg.get_value("drift", "best", 0)
		if saved is int:
			best = maxi(0, saved)

func tick(dt: float, speed: float, slip: float, lever: bool, hit: bool) -> void:
	message_time = maxf(0.0, message_time - dt)
	if hit:
		finish(true)
		return
	if not lever or speed < 6.0 or absf(slip) < deg_to_rad(6.0):
		candidate_side = 0
		candidate_time = 0.0
		gap += dt
		if gap >= REARM_TIME:
			segment_side = 0
		if gap >= LINK_WINDOW:
			finish(false)
		return

	var side := int(signf(slip))
	if candidate_side != side:
		candidate_side = side
		candidate_time = 0.0
	if segment_side != side:
		candidate_time += dt
		if candidate_time < ENTRY_TIME:
			gap += dt
			if gap >= LINK_WINDOW and multiplier > 0:
				finish(false)
			return
		segment_side = side
		multiplier = mini(multiplier + 1, MAX_MULTIPLIER)
		message_time = 0.0
	gap = 0.0
	points += speed * absf(slip) * 12.0 * float(multiplier) * dt

func finish(lost: bool) -> void:
	if multiplier > 0:
		var result := roundi(points)
		if lost:
			message = "KOMBO KESİLDİ"
		elif result > best:
			best = result
			var cfg := ConfigFile.new()
			cfg.set_value("drift", "best", best)
			if cfg.save(RECORD_PATH) != OK:
				push_warning("Could not save drift record")
			message = "YENİ REKOR  %d" % result
		else:
			message = "DRİFT  %d" % result
		message_time = 2.0
	points = 0.0
	multiplier = 0
	gap = 0.0
	segment_side = 0
	candidate_side = 0
	candidate_time = 0.0
