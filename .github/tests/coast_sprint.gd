extends SceneTree

const Sprint := preload("res://scripts/coast_sprint.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var timer := Sprint.new()
	timer.start()
	check(timer.running_delta(2.9) == 0.0, "countdown freezes motion")
	check(is_equal_approx(timer.running_delta(0.2), 0.1), "countdown preserves partial tick")
	timer.advance(11.0, 220.0)
	timer.advance(8.0, 380.0)
	timer.advance(12.0, 620.0)
	check(timer.splits.size() == 3 and is_equal_approx(timer.elapsed, 30.0), "finish interpolated at 600 m")
	check(is_equal_approx(timer.splits[0], 10.0) and is_equal_approx(timer.splits[1], 20.0), "ordered splits")
	var saved := Sprint.new()
	saved.load_record()
	check(saved.best_ms == 30000, "best time persists")
	saved.start()
	saved.running_delta(3.0)
	saved.advance(33.0, 600.0)
	check(saved.best_ms == 30000 and not saved.personal_best, "slower time cannot replace record")
	var scene = load("res://drive.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	var h = scene.hud
	var timer_button: Vector2 = h.sprint_rect().get_center()
	h.touch(7, timer_button, true)
	h.touch(7, timer_button, false)
	h.touch(1, h.gas_rect().get_center(), true)
	for i in 179:
		scene._physics_process(1.0 / 60)
	check(scene.progress == 0.0 and scene.traffic[0].progress == 33.0 and scene.speed == 0, "fair standing start")
	check(scene.sprint_markers.visible, "course markers")
	for i in 9000:
		scene._physics_process(1.0 / 60)
		if h.sprint.phase == Sprint.Phase.FINISHED:
			break
	check(h.sprint.phase == Sprint.Phase.FINISHED and h.sprint.splits.size() == 3, "finish via normal gas control")
	check(not scene.sprint_markers.visible and h.sprint.elapsed > 0, "finish returns to free driving")
	h.touch(7, timer_button, true)
	h.touch(7, timer_button, false)
	check(scene.progress == 0.0 and scene.speed == 0.0 and h.sprint.splits.is_empty(), "retry reset")
	h.touch(7, timer_button, true)
	h.touch(7, timer_button, false)
	check(h.sprint.phase == Sprint.Phase.FREE and not scene.sprint_markers.visible, "tap to cancel")
	scene.toggle_sprint()
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(h.sprint.phase == Sprint.Phase.FREE, "background interrupts timed run")
	print("Coast sprint checks: ", failures, " failures")
	quit(failures)
