extends SceneTree
const Score = preload("res://scripts/drift_score.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func drive(score, frames: int, side: float, lever := true, speed := 22.0) -> void:
	for i in frames:
		score.tick(1.0/60.0, speed, side, lever, false)

func _initialize() -> void:
	var score := Score.new()
	drive(score, 40, 0.0)
	drive(score, 40, 0.25, false)
	drive(score, 40, 0.25, true, 3.0)
	check(score.points == 0, "no score on a straight or at low speed")
	drive(score, 5, 0.25)
	check(score.multiplier == 0, "short taps do not start a combo")
	drive(score, 45, 0.25)
	check(score.multiplier == 1 and score.points > 0, "first drift")
	drive(score, 5, 0.0)
	drive(score, 20, 0.25)
	check(score.multiplier == 1, "no bonus from brief input loss")
	drive(score, 22, 0.0)
	drive(score, 25, 0.25)
	check(score.multiplier == 2, "linked same-side drifts")
	drive(score, 25, -0.25)
	check(score.multiplier == 3, "linked opposite-side drift")
	for side in [0.25,-0.25,0.25,-0.25]:
		drive(score, 24, side)
	check(score.multiplier == 5, "multiplier cap")
	var result := roundi(score.points)
	drive(score, 95, 0.0)
	check(score.multiplier == 0 and score.best == result, "bank the combo")
	var reloaded := Score.new()
	reloaded.load_record()
	check(reloaded.best == result, "persist exact record")
	drive(score, 30, -0.25)
	score.tick(1.0/60.0,22,-0.25,true,true)
	check(score.multiplier == 0 and score.points == 0 and score.best == result, "collision forfeits pending score")
	print("Drift regression checks: ",failures," failures")
	quit(failures)
