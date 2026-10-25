extends SceneTree

const Night = preload("res://scripts/door_night_state.gd")
var failures := 0

func check(value: bool, text: String) -> void:
	if not value:
		push_error("FAIL: " + text)
		failures += 1
	else: print("PASS: " + text)

func _initialize() -> void:
	var s = Night.new(7)
	s.arrive()
	s.kind = "copied"
	s.age = 20
	check(not s.camera_person() and s.threat_present(), "empty camera can conceal a lethal visitor")
	check(s.lens_person(), "side lens exposes hidden visitor")
	check(s.code_matches(), "impostor can know the real order number")
	check(s.ask().contains("세제"), "copied code has a contradictory item clue")
	check(s.listen().contains("고무 밑창"), "listening exposes presence")
	check(s.open_door() == "death" and s.ended and not s.won, "opening into blind spot causes real failure")
	var safe = Night.new(7)
	safe.arrive()
	safe.kind = "rain"
	safe.age = 20
	check(not safe.camera_person() and not safe.lens_person(), "departed courier leaves both views empty")
	check(safe.open_door() == "collected" and safe.supplies == 1, "safe parcel can be collected")
	check(safe.notes[0].contains("생수 · 컵라면"), "collection records the correct order items")
	check(safe.open_door() == "empty" and safe.supplies == 1, "parcel cannot be duplicated")
	var expired = Night.new(2)
	expired.arrive()
	expired.kind = "quiet"
	expired.tick(63)
	check(expired.missed == 1 and expired.supplies == 0, "waiting forever loses essential deliveries")
	var left = Night.new(3)
	left.arrive()
	left.kind = "insistent"
	left.age = 43
	left.tick(2)
	check(not left.threat_present() and left.open_door() == "empty", "departed threat takes its decoy away")
	var paused = Night.new(3)
	paused.paused = true
	paused.tick(100)
	check(paused.elapsed == 0 and paused.round_index == -1, "pause freezes arrivals and deadlines")
	var all_won := true
	var varied: Dictionary = {}
	for seed_value in range(100):
		var night = Night.new(seed_value)
		varied[str(night.sequence)] = true
		for i in range(5):
			night.tick(night.arrival_in + 0.1)
			if night.dangerous(): night.tick(63)
			else:
				night.tick(19)
				night.open_door()
			night.events.clear()
		if not night.ended: night.tick(10)
		if not night.ended or not night.won or night.supplies != 3: all_won = false
	check(all_won, "all 100 seeded nights can be won with valid observations")
	check(varied.size() > 10, "restarts change encounter order")
	var starved = Night.new(4)
	for i in range(5):
		starved.tick(starved.arrival_in + 0.1)
		starved.tick(63)
	starved.tick(10)
	check(starved.ended and not starved.won, "permanent avoidance does not win")
	print("NIGHT_TESTS_DONE failures=%d" % failures)
	quit(1 if failures else 0)
