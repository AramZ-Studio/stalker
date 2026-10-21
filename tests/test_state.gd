extends SceneTree

const State = preload("res://scripts/state.gd")
var failures := 0

func check(condition: bool, name: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + name)
	else:
		print("PASS: " + name)

func _initialize() -> void:
	var s = State.new()
	s.order()
	s.begin("업무", 2)
	check(is_equal_approx(s.clock, 19.0) and is_equal_approx(s.pending, 1.0), "delivery interrupts work at correct hour")
	check(s.parcel and s.visitor == "courier", "ordered parcel appears")
	s.open_door()
	check(s.food == 5 and not s.parcel, "safe collection adds three meals exactly once")
	s.open_door()
	check(s.food == 5, "cannot duplicate parcel")
	s.resume_activity()
	check(is_equal_approx(s.clock, 20.0) and s.pending == 0, "interrupted work resumes remaining duration")
	s.begin("업무", 4)
	check(is_equal_approx(s.clock, 22.0) and is_equal_approx(s.pending, 2.0), "stalker interrupts work at 22")
	check(s.collect("현관 렌즈"), "wrist evidence visible during encounter")
	check(not s.collect("현관 렌즈"), "evidence cannot duplicate")
	s.cancel_activity()
	s.begin("대기", 1)
	check(s.visitor.is_empty(), "stalker leaves at 23")
	check(s.collect("창밖"), "vehicle clue visible after departure")
	check(s.report() == 2 and is_equal_approx(s.deadline, 42.0), "two reports shorten deadline by twelve hours")
	check(s.report() == 0 and is_equal_approx(s.deadline, 42.0), "report cannot reduce deadline twice")
	s.food = 10
	while not s.ended and s.clock < 43:
		s.hunger = 10
		s.begin("수면", 4)
	check(s.ended and s.won, "full evidence survival reaches arrest ending")
	var death = State.new()
	death.visitor = "stalker"
	death.open_door()
	check(death.ended and not death.won, "opening to stalker is fatal")
	var defense = State.new()
	defense.defense = true
	defense.visitor = "stalker"
	defense.open_door()
	check(not defense.ended and defense.defense_used, "spray prevents first death")
	defense.visitor = "stalker"
	defense.defense = true
	defense.open_door()
	check(defense.ended, "same defense fails on second encounter")
	var theft = State.new()
	theft.order()
	theft.begin("대기", 1)
	theft.begin("대기", 3)
	check(not theft.parcel, "uncollected delivery disappears after three hours")
	var starving = State.new()
	starving.hunger = 99.9
	starving.advance(0.25)
	check(starving.ended and not starving.won, "hunger failure")
	var exhausted = State.new()
	exhausted.sanity = 0.01
	exhausted.advance(0.25)
	check(exhausted.ended and not exhausted.won, "sanity failure")
	var sleep_regular = State.new()
	sleep_regular.clock = 30.0
	sleep_regular.last_sleep = 6.0
	sleep_regular.sanity = 20.0
	sleep_regular.begin("수면", 8)
	check(is_equal_approx(sleep_regular.sanity, 63.6), "sleep uses bedtime difference for entire session")
	var sleep_shifted = State.new()
	sleep_shifted.clock = 30.0
	sleep_shifted.last_sleep = 0.0
	sleep_shifted.sanity = 20.0
	sleep_shifted.begin("수면", 8)
	check(is_equal_approx(sleep_shifted.sanity, 39.6), "shifted bedtime reduces recovery")
	print("STATE_TESTS_DONE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
