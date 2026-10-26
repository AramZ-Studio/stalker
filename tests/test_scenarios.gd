extends SceneTree
const Catalog = preload("res://scripts/scenario_catalog.gd")
const State = preload("res://scripts/state.gd")
var failures := 0

func check(value: bool, title: String) -> void:
	if value: print("PASS: " + title)
	else: failures += 1; push_error("FAIL: " + title)

func _initialize() -> void:
	var ids: Array[String] = []
	for item in Catalog.CASES:
		check(not ids.has(item.id), "unique scenario " + str(item.id))
		ids.append(item.id)
		var s = Catalog.build(item.id)
		check(not s.ended, str(item.id) + " begins before the actual outcome")
		Catalog.perform(s, item.id)
		match str(item.id):
			"courier", "hurried": check(s.food == 3, "actual two-meal delivery collection")
			"neighbor": check(s.neighbor_tip, "neighbor information persists")
			"work_bell", "sleep_bell": check(s.pending > 0 and s.visitor == "courier", "actual activity interrupted by delivery")
			"favorite": check(s.good_food == 0 and s.sanity > 40, "favorite meal consumed")
			"no_food": check(s.food == 0 and s.meals_today == 1, "missing inventory grants no meal")
			"theft": check(not s.parcel and s.missed_deliveries == 1, "actual collection deadline loses parcel")
			"daily_meal", "hunger", "sanity", "unarmed", "reuse": check(s.ended and not s.won, "actual failure " + str(item.id))
			"night_walk": check(s.clock == 22, "low sanity refuses night walk")
			"spray", "alarm", "light": check(not s.ended and s.used_defenses.has(item.id), "actual distinct defense " + str(item.id))
			"camera_delivery": check(s.camera_ready, "camera acquired by delivery")
			"defense_delivery": check(s.defenses.has("spray"), "defense acquired by delivery")
			"no_recording": check(s.evidence.is_empty(), "no retroactive recording")
			"recording": check(s.evidence.has("현관 녹화"), "actual recording collected")
			"report": check(s.reported.size() == 3 and s.deadline == 168, "real reporting leaves week target intact")
			"survived", "prepared", "scarred": check(s.won and s.ending_tag == item.id, "actual ending variant " + str(item.id))
	var modified = Catalog.build("courier", {"day":2, "hour":14, "sanity":40, "food":0, "order":false, "defense":"alarm"})
	check(modified.clock == 62 and modified.sanity == 40 and not modified.parcel and modified.defenses.has("alarm"), "custom conditions applied")
	var unexpected = Catalog.build("work_bell", {"order":false})
	Catalog.perform(unexpected, "work_bell")
	check(unexpected.visitor == "stalker" and unexpected.order_due < 0, "no-order interruption creates an unsolicited visitor instead of a fabricated real delivery")
	var a = Catalog.build("courier")
	a.food = 99
	check(Catalog.build("courier").food == 1, "restarting scenarios never shares mutable state")
	var week = State.new()
	week.enable_full_game(13)
	check(week.price("pantry") == 10000 and week.money == 24000, "initial budget requires preparation priorities")
	check(week.threat_times[0] > 168 and week.threat_times[1] > 168 and week.threat_times[2] < 72, "first two days teach normal visits before lethal impersonation")
	week.clock = 110
	week.meal_day = 4
	week.purchase("pantry")
	check(week.order_due == 113, "day five general shipping delay is disclosed and applied")
	var fake = Catalog.build("mimic")
	check(fake.ask("물품").contains(fake.product_name), "later impersonation can match the item")
	fake.ask("두고 가기")
	check(not fake.camera_person() and fake.lens_person() and fake.listen().contains("밑창"), "matching answer still leaves fair independent clues")
	var last = State.new()
	last.enable_full_game(13)
	last.clock = last.threat_times[6]
	last.update_events()
	check(last.visitor == "stalker" and last.threat_profile == "mimic", "final day uses learned impersonation")
	last.clock = last.visit_until
	last.update_events()
	last.clock += 1
	last.update_events()
	check(last.visitor == "stalker" and last.threat_profile == "silent" and last.events.has("full_visit_6_return"), "final night can return after an actual departure")
	print("SCENARIO_TESTS_DONE cases=%d failures=%d" % [Catalog.CASES.size(), failures])
	quit(1 if failures else 0)
