extends SceneTree

const State = preload("res://scripts/state.gd")
var failures := 0

func check(value: bool, title: String) -> void:
	if value: print("PASS: " + title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func fresh() -> RefCounted:
	var state = State.new()
	state.enable_full_game(13)
	return state

func reach(state: RefCounted, time: float) -> void:
	while state.clock < time - 0.000001 and not state.ended:
		state.begin("대기", minf(0.25, time - state.clock))

func _initialize() -> void:
	var s = fresh()
	check(s.clock == 0 and s.deadline == 168 and s.threat_times.has(6), "seven complete calendar days with visits through day seven")
	reach(s, 24)
	check(s.ended and not s.won and s.ending.contains("한 끼"), "missing a meal fails at midnight even with remaining hunger capacity")
	s = fresh()
	s.food = 3
	s.eat()
	reach(s, 23.75)
	s.eat()
	reach(s, 24)
	check(s.meal_history[0] == 2 and s.meals_today == 0 and not s.ended, "multiple meals do not carry into the next day")
	reach(s, 48)
	check(s.ended and s.ending.contains("2일차"), "second day's missing meal cannot be covered by yesterday's food")
	s = fresh()
	s.clock = 23.95
	s.eat()
	s.begin("대기", 0.1)
	check(is_equal_approx(s.clock, 24.05) and s.meals_today == 0 and s.meal_history[0] == 1, "short waits split exactly at midnight")
	check(not s.eat() and s.meals_today == 0, "failed food use does not count as a meal")
	s = fresh()
	s.clock = 167.9
	s.meal_day = 6
	s.begin("대기", 0.2)
	check(s.ended and not s.won, "final day's required meal is checked before victory")
	s.evidence.append("손목 문신")
	s.report()
	check(not s.won, "reporting after a failed final day cannot turn it into a win")
	s = fresh()
	s.clock = 167.9
	s.meal_day = 6
	s.eat()
	s.begin("대기", 0.2)
	check(s.won and s.clock == 168, "a fed final day ends at day seven midnight without overshooting")
	s = fresh()
	s.evidence.assign(["손목 문신", "차량 번호"])
	s.report()
	check(s.deadline == 168 and not s.won, "reports do not shorten the one-week objective")
	s.clock = 22
	s.threat_times[0] = 22
	s.update_events()
	check(s.visit_until == 22.5, "two reports reduce later visits by thirty minutes")
	# Complete an ordinary week: buy, earn, collect, eat and sleep using game rules.
	s = fresh()
	var iterations := 0
	while not s.ended and iterations < 2500:
		iterations += 1
		if s.visitor == "stalker":
			s.collect("현관 렌즈")
			s.report()
			s.begin("대기", 0.25)
			continue
		if s.parcel:
			s.ask("두고 가기")
			s.open_door()
		if s.food < 3 and s.order_due < 0 and not s.parcel: s.purchase("pantry")
		if s.food > 0 and (s.meals_today == 0 or s.hunger > 50):
			s.eat()
			s.begin("식사", 0.5)
		elif s.sanity < 70: s.begin("수면", 4)
		else: s.begin("업무", 2)
	check(s.won and s.clock == 168, "complete week survives using actual income, deliveries, food and sleep")
	check(s.meal_history.size() == 7, "all seven days recorded")
	for meals in s.meal_history.values(): check(meals >= 1, "survived day contains at least one real meal")
	print("WEEK_TESTS_DONE failures=%d" % failures)
	quit(1 if failures else 0)
