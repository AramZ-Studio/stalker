extends SceneTree

const State = preload("res://scripts/state.gd")
var failures := 0

func check(value: bool, title: String) -> void:
	if value: print("PASS: " + title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func reach(s: RefCounted, target: float, kind: String = "대기") -> void:
	var guard := 0
	while s.clock < target - 0.001 and not s.ended and guard < 500:
		s.begin(kind, minf(0.25, target - s.clock))
		guard += 1

func fresh() -> RefCounted:
	var s = State.new()
	s.enable_full_game(13)
	s.threat_times[0] = 22.0
	s.threat_times[1] = 46.0
	return s

func _initialize() -> void:
	var s = fresh()
	check(s.food == 1 and s.deadline == 78, "full play starts with limited stock and police deadline")
	s.purchase("pantry")
	check(s.money == 30000 and s.food == 1 and s.order_due == 35, "night pantry order costs money and awaits daytime delivery")
	s.begin("업무", 4)
	check(s.clock == 22 and s.visitor == "stalker" and s.money > 30000, "work earns money and stops at a suspicious visitor")
	s.collect("현관 렌즈")
	s.begin("대기", 0.25)
	check(not s.camera_person() and s.lens_person(), "blind spot is present inside the same life simulation")
	check(s.same_order_dialogue().contains(s.order_number), "impostor can quote real order number")
	check(s.same_order_dialogue().contains("냉동식품"), "order content contradicts impostor's answer")
	reach(s, 23)
	check(s.visitor.is_empty() and s.collect("창밖"), "departure creates time-limited vehicle evidence")
	check(s.report() == 2 and s.deadline == 66, "evidence shortens the same survival deadline")
	check(s.eat(), "starting stock can be eaten")
	s.begin("식사", 0.5)
	s.begin("수면", 8)
	check(s.sanity > 80 and s.clock == 31.5, "sleep restores sanity and advances same clock")
	reach(s, 35, "업무")
	check(s.parcel and s.visitor == "courier", "real order arrives through normal interrupted time progression")
	s.open_door()
	check(s.food == 3 and not s.parcel, "safe collection adds the ordered stock")
	s.purchase("meal")
	check(s.order_due == 35.75 and s.good_food == 0, "favorite food requires delivery instead of instant recovery")
	reach(s, 35.75)
	s.open_door()
	var before: float = s.sanity
	s.sanity = 40
	s.eat(true)
	check(s.sanity == 60 and s.good_food == 0, "favorite meal restores additional sanity")
	s.sanity = before
	s.purchase("camera")
	reach(s, 36.75)
	s.open_door()
	check(s.camera_ready and not s.collect("카메라"), "investigation camera must be collected and cannot record past visits")
	reach(s, 46)
	check(s.recorded_visit and s.collect("카메라"), "installed camera records a later encounter as evidence")
	s.report()
	check(s.deadline == 60, "recording further accelerates arrest")
	# Continue using ordinary meals, sleep and work; no end flag or meter is forced.
	while not s.ended:
		if s.hunger > 55 and s.food > 0:
			s.eat()
			s.begin("식사", 0.5)
		elif s.sanity < 65: s.begin("수면", 4)
		else: s.begin("업무", 2)
	check(s.won and s.clock == 60, "complete full loop reaches arrest using real food, work and sleep")
	var guard = fresh()
	guard.defenses.assign(["spray", "alarm"])
	guard.visitor = "stalker"
	guard.open_door()
	check(not guard.ended and guard.used_defenses.has("spray"), "first distinct defense prevents death")
	check(guard.price("alarm") == 33000, "later defense becomes more expensive")
	guard.visitor = "stalker"
	guard.open_door()
	check(not guard.ended and guard.used_defenses.has("alarm"), "different second defense still works")
	guard.visitor = "stalker"
	guard.open_door()
	check(guard.ended and not guard.won, "encounter without remaining defense is fatal")
	var thief = fresh()
	thief.purchase("pantry")
	reach(thief, 38.25)
	check(not thief.parcel and thief.food == 1, "sleeping through collection loses the ordered parcel")
	var worn = fresh()
	worn.begin("대기", 2)
	check(worn.money == 42000, "waiting does not provide income")
	print("FULL_GAME_TESTS_DONE failures=%d" % failures)
	quit(1 if failures else 0)
