class_name StalkerState
extends RefCounted

# All times are absolute hours. Day 1 starts at 18:00.
const START := 18.0
const BASE_DEADLINE := 54.0
var clock := START
var deadline := BASE_DEADLINE
var hunger := 18.0
var sanity := 78.0
var money := 42000
var food := 2
var defense := false
var defense_used := false
var visitor := ""
var parcel := false
var parcel_since := 0.0
var order_due := -1.0
var order_number := ""
var evidence: Array[String] = []
var reported: Array[String] = []
var events: Array[String] = []
var journal: Array[String] = []
var ended := false
var won := false
var ending := ""
var pending := 0.0
var activity := ""
var activity_hours := 0.0
var last_sleep := -1.0
var sleep_recovery := 6.0
var suspense := false
var rng := RandomNumberGenerator.new()
var threat_times: Dictionary = {}
var visit_started := -1.0
var visit_until := -1.0
var last_departure := -100.0
var last_walk := START
var awake_hours := 0.0
var good_food := 0
var camera_ready := false
var recorded_visit := false
var product := "pantry"
var product_name := "간편식 3개"
var defenses: Array[String] = []
var used_defenses: Array[String] = []
var sound_events: Array[String] = []
var asked_to_leave := false
var visit_style := 0
var first_night := false
var mail_waiting := false
const WEEK_END := 168.0
var weekly_survival := false
var meal_day := 0
var meals_today := 0
var meal_history: Dictionary = {}
const CATALOG := {
	"pantry": {"name": "생수·간편식 3개", "price": 12000},
	"meal": {"name": "좋아하는 따뜻한 음식", "price": 15000},
	"camera": {"name": "현관 기록 카메라", "price": 14000},
	"spray": {"name": "호신 스프레이", "price": 18000},
	"alarm": {"name": "휴대용 경보기", "price": 26000},
	"light": {"name": "고광도 손전등", "price": 36000}
}

func enable_full_game(seed_value: int = -1, weekly: bool = true) -> void:
	suspense = true
	weekly_survival = weekly
	if seed_value < 0: rng.randomize()
	else: rng.seed = seed_value
	clock = 0.0 if weekly else START
	last_walk = clock
	deadline = WEEK_END if weekly else 78.0
	meal_day = int(clock / 24)
	meals_today = 0
	meal_history.clear()
	food = 1
	hunger = 32.0
	for day in range(8):
		threat_times[day] = day * 24.0 + rng.randi_range(84, 93) * 0.25
	log_entry("7일차 자정까지 살아남아야 한다. 매일 최소 한 끼를 먹자. 제보하면 순찰이 강화된다." if weekly else "경찰: ‘수색 중입니다. 4일차 06시까지 버텨주세요. 제보가 있으면 더 빨라집니다.’")
	log_entry("남은 간편식 1개. 일해서 생활비를 벌고, 필요한 물품을 주문해야 한다.")

func price(key: String) -> int:
	if not CATALOG.has(key): return 0
	return int(CATALOG[key].price) + (used_defenses.size() * 7000 if key in ["spray", "alarm", "light"] else 0)

func purchase(key: String) -> String:
	if not CATALOG.has(key): return "판매하지 않는 물품이다."
	if order_due >= 0 or parcel: return "진행 중인 주문이나 회수하지 않은 물품이 있다."
	if key in used_defenses: return "이미 사용한 방법이다. 그는 같은 수단에 다시 당하지 않는다."
	if key in defenses or key == "camera" and camera_ready: return "이미 보유하고 있다."
	if money < price(key): return "돈이 부족하다. PC에서 업무를 하면 수입을 얻을 수 있다."
	money -= price(key)
	product = key
	product_name = str(CATALOG[key].name)
	order_number = "%04d" % rng.randi_range(1000, 9999)
	if key == "meal":
		order_due = clock + 0.75
	else:
		var h := fmod(clock, 24.0)
		if h < 9: order_due = floorf(clock / 24.0) * 24.0 + 11.0
		elif h <= 16: order_due = clock + 1.0
		else: order_due = floorf(clock / 24.0 + 1.0) * 24.0 + 11.0
	log_entry("%s 주문 · 번호 %s · 도착 예정 %d일차 %02d:%02d" % [product_name, order_number, int(order_due / 24) + 1, int(fmod(order_due, 24)), int(fmod(order_due * 60, 60))])
	return "주문했다. 물품은 직접 현관에서 회수해야 한다."

func camera_person() -> bool:
	return not visitor.is_empty() and (not suspense or visitor != "stalker" or (clock - visit_started < 0.25 and not asked_to_leave))

func lens_person() -> bool:
	return not visitor.is_empty()

func same_order_dialogue() -> String:
	if visitor.is_empty(): return "대답이 없다. 누군가 문 옆에 남아 있는지 소리도 확인해야 한다."
	if visitor == "neighbor": return "‘옆집이에요. 저희 집에 잘못 온 우편물 두고 갈게요. 열지 않으셔도 돼요.’"
	if visitor == "courier":
		return "‘%s, %s 맞으시죠? 문 앞에 두고 갈게요.’\n목소리는 무뚝뚝하지만 주문 내용과 일치한다." % [order_number, product_name]
	if not used_defenses.is_empty(): return "‘지난번에 쓴 건 이제 안 통해요. 이번에는 열어봐요.’\n상대는 주문과 관계없는 말을 하고 있다."
	return "‘%s 맞죠? 문 앞에 두었습니다. 문 여는 소리 듣고 갈게요.’\n물품명을 물으니 ‘냉동식품’이라고 답한다. 이번 주문과 맞는지 확인해야 한다." % (order_number if not order_number.is_empty() else "0417")

func ask(topic: String) -> String:
	if ended: return ""
	if visitor.is_empty(): return "응답이 없다. 멀리서 엘리베이터가 움직인다."
	if topic == "물품": return same_order_dialogue()
	if topic == "두고 가기":
		asked_to_leave = true
		if visitor == "stalker":
			sound_events.append("steps_near")
			return "‘네. 갈게요.’ 두어 걸음 소리가 나고 끊긴다."
		if visitor == "neighbor": mail_waiting = true
		visitor = ""
		sound_events.append("steps_away")
		log_entry("문 앞에 두고 가달라고 말했다. 발소리 뒤로 계단 방화문이 닫혔다.")
		return "‘네, 여기 두겠습니다.’ 발소리가 계단까지 이어지고 방화문이 닫힌다."
	if topic == "배송 알림":
		if visitor == "neighbor": return "‘배달 아니에요. 옆집 우편물이요. 봉투에 호수 보이시죠?’"
		if visitor == "courier": return "‘단말기가 늦네요. %s, %s입니다. 확인하시고 가져가세요.’" % [order_number, product_name]
		return "‘앱이 늦는 거예요. 열면 확인할 수 있잖아요.’ 물건 이름은 말하지 않는다."
	if visitor == "neighbor": return "‘옆집이에요. 엘리베이터에서 뵀었죠. 문은 안 여셔도 돼요.’"
	if visitor == "courier": return "‘오늘 이 층은 처음인데요. 바빠서 물건 놓고 가겠습니다.’"
	return "‘늘 이 시간까지 일하시네요.’ 잠깐 뒤, ‘아니, 불이 켜져 있어서요.’"

func listen() -> String:
	if visitor == "stalker":
		sound_events.append("shuffle")
		return "문 오른쪽, 아주 가까운 곳에서 고무 밑창이 바닥에 스친다. 그 뒤로는 조용하다."
	if visitor in ["courier", "neighbor"]:
		sound_events.append("rustle")
		return "종이와 비닐이 바스락거린다. 문 앞에서 누군가 자세를 고친다."
	return "형광등이 낮게 웅웅거린다. 가까운 곳에서는 발소리도 옷 스치는 소리도 들리지 않는다."

func eat(tasty: bool = false) -> bool:
	if ended: return false
	if tasty:
		if good_food <= 0: return false
		good_food -= 1
		hunger = maxf(0, hunger - 48)
		sanity = minf(100, sanity + 20)
	else:
		if food <= 0: return false
		food -= 1
		hunger = maxf(0, hunger - 42)
		sanity = minf(100, sanity + 3)
	if weekly_survival: meals_today += 1
	log_entry(("좋아하는 음식을 먹고 조금 마음이 풀렸다." if tasty else "비축한 간편식을 먹었다.") + (" 오늘 식사 %d회 / 최소 1회." % meals_today if weekly_survival else ""))
	return true

func meal_status() -> String:
	if not weekly_survival: return ""
	if won: return "7일 모두 식사 완료"
	return "오늘 식사 %d회 / 최소 1회 · %s" % [meals_today, "완료" if meals_today > 0 else "자정 전 식사 필요"]

func stamp() -> String:
	if weekly_survival and clock >= WEEK_END: return "7일차 24:00"
	return "%d일차 %02d:%02d" % [int(clock / 24.0) + 1, int(fmod(clock, 24.0)), int(fmod(clock * 60.0, 60.0))]

func log_entry(message: String) -> void:
	journal.push_front("%s  %s" % [stamp(), message])

func night() -> bool:
	var h := fmod(clock, 24.0)
	return h >= 21.0 or h < 6.0

func finish(success: bool, reason: String) -> void:
	ended = true
	won = success
	ending = reason
	log_entry(reason)

func order() -> void:
	if suspense:
		purchase("pantry")
		return
	if money < 12000 or order_due >= 0.0 or parcel:
		return
	money -= 12000
	order_due = clock + 1.0
	order_number = "0417"
	log_entry("간편식 3개 주문. 주문 번호 0417 / 1시간 후 도착 예정.")

func begin(kind: String, hours: float) -> void:
	activity = kind
	activity_hours = 0.0
	if kind == "수면":
		sleep_recovery = 6.0
		if last_sleep >= 0.0:
			var gap := absf(wrapf(clock - last_sleep, -12.0, 12.0))
			if gap > 4.0:
				sleep_recovery = 3.0
		last_sleep = clock
	pending = hours
	if suspense and kind == "수면" and sleep_recovery < 6:
		pending = maxf(1, hours - 2)
		log_entry("취침 시각이 크게 달라져 잠이 얕다. 이번 수면은 최대 %.0f시간이다." % pending)
	resume_activity()

func resume_activity() -> void:
	var duration := pending
	pending = 0.0
	advance(duration, activity)
	if pending <= 0.0 and not ended:
		log_entry("%s 종료. 실제 진행 %.1f시간." % [activity, activity_hours])

func cancel_activity() -> void:
	log_entry("%s 중단. 진행한 시간의 수입·회복은 유지된다." % activity)
	pending = 0.0
	activity = ""

func advance(hours: float, kind: String = "대기") -> void:
	var remaining := hours
	while remaining > 0.001 and not ended:
		var step := minf(0.25, remaining)
		var midnight := float(int(clock / 24) + 1) * 24
		if weekly_survival: step = minf(step, minf(midnight - clock, deadline - clock))
		clock += step
		remaining -= step
		activity_hours += step
		hunger = minf(100.0, hunger + 2.4 * step)
		sanity -= (0.55 + (1.5 if hunger >= 80.0 else 0.0)) * step
		if suspense:
			if kind != "수면": awake_hours += step
			if clock - last_walk > 18: sanity -= 0.7 * step
			if awake_hours > 16: sanity -= 0.5 * step
		if kind == "업무":
			money += int((3000.0 + minf(activity_hours, 4.0) * 300.0) * step)
			sanity -= step * 0.8
		elif kind == "수면":
			awake_hours = maxf(0, awake_hours - step * 2)
			sanity = minf(100.0, sanity + sleep_recovery * step)
		if weekly_survival and clock >= midnight - 0.000001:
			clock = midnight
			meal_history[meal_day] = meals_today
			if meals_today == 0:
				finish(false, "%d일차에 한 끼도 먹지 못했다. 하루 최소 한 번은 식사해야 한다." % (meal_day + 1))
				break
			if clock < deadline:
				meal_day = int(clock / 24)
				meals_today = 0
				log_entry("새로운 날. 오늘도 최소 한 끼를 먹어야 한다.")
		if weekly_survival and meals_today == 0 and fmod(clock, 24) >= 20:
			var warning := "meal_warning_%d" % meal_day
			if not events.has(warning):
				events.append(warning)
				log_entry("아직 오늘 식사를 하지 않았다. 자정 전에 한 끼를 먹어야 한다.")
		if parcel and clock - parcel_since >= 3.0:
			parcel = false
			log_entry("문 앞에 3시간 동안 둔 물품이 사라졌다.")
		var bell := update_events()
		if sanity <= 0.0 or hunger >= 100.0:
			finish(false, "더는 버틸 수 없었다. " + ("공복이 한계에 도달했다." if hunger >= 100.0 else "정신력이 바닥났다."))
		elif clock >= deadline:
			finish(true, "일주일을 버텼다. 7일 동안 매일 식사를 챙겼고, 경찰이 용의자를 검거했다." if weekly_survival else ("첫날 밤을 버텼다. 날이 밝았다. 경찰의 수색은 계속된다." if first_night else "경찰이 용의자를 검거했다. 이제, 잠들 수 있다."))
		elif bell:
			pending = remaining
			if remaining > 0.001:
				activity = kind
			log_entry("초인종. 하던 행동이 멈췄다.")
			break
	sanity = clampf(sanity, 0.0, 100.0)

func update_events() -> bool:
	if suspense: return update_full_events()
	var bell := false
	if order_due >= 0.0 and clock >= order_due and visitor != "stalker":
		visitor = "courier"
		parcel = true
		parcel_since = clock
		order_due = -1.0
		log_entry("배송 도착 알림. 주문 0417. 문 앞에 물품이 놓였다.")
		bell = true
	var day := int(clock / 24.0)
	var h := fmod(clock, 24.0)
	var key := "visit_%d" % day
	if h >= 22.0 and h < 23.0 and not events.has(key):
		events.append(key)
		visitor = "stalker"
		asked_to_leave = false
		visit_style = mini(day, 2)
		log_entry("주문하지 않은 방문. 문 너머에서 느린 발소리가 들린다.")
		bell = true
	if visitor == "courier" and clock - parcel_since >= 0.5:
		visitor = ""
	if visitor == "stalker" and h >= 23.0:
		visitor = ""
		log_entry("계단을 내려가는 발소리. 창밖에서 엔진 소리가 들린다.")
	return bell

func update_full_events() -> bool:
	var bell := false
	var day := int(clock / 24)
	var key := "full_visit_%d" % day
	if visitor != "stalker" and clock >= float(threat_times.get(day, day * 24 + 22)) and not events.has(key):
		events.append(key)
		visitor = "stalker"
		asked_to_leave = false
		visit_style = mini(day, 2)
		visit_started = clock
		visit_until = clock + (maxf(0.25, 1.0 - reported.size() * 0.25) if weekly_survival else 1.0)
		if camera_ready: recorded_visit = true
		log_entry(["초인종. ‘문 앞입니다’라는 메시지. 젖은 상자가 카메라 아래 보인다.", "초인종. ‘오늘은 늦게 주무시네요.’ 잠깐 뒤 배달이라는 말이 이어진다.", "초인종이 울리기 전, 현관 손잡이에서 금속이 스쳤다. ‘문 앞입니다.’"][mini(day, 2)])
		sound_events.append("bell")
		bell = true
	if visitor == "stalker" and clock < visit_until and clock >= visit_started + 0.5 and not events.has(key + "_repeat"):
		events.append(key + "_repeat")
		sound_events.append("knock")
		log_entry("똑똑. 문 옆에서 다시 두드린다.")
		bell = true
	if not visitor.is_empty() and clock >= visit_until:
		if visitor == "stalker": last_departure = clock
		visitor = ""
		sound_events.append("steps_away")
		log_entry("이번에는 발소리가 계단 아래로 멀어진다.")
	if order_due >= 0 and clock >= order_due and visitor != "stalker":
		visitor = "courier"
		asked_to_leave = false
		visit_style = rng.randi_range(0, 2)
		visit_started = clock
		visit_until = clock + 0.5
		parcel = true
		parcel_since = clock
		order_due = -1
		log_entry("초인종. ‘문 앞에 두겠습니다.’ 주문의 도착 예정 시각과 가까운 시간이다.")
		sound_events.append("bell")
		bell = true
	var neighbor_key := "neighbor_%d" % day
	var neighbor_time := (day > 0 and fmod(clock, 24) >= 17 and fmod(clock, 24) < 18) or (first_night and day == 0 and clock >= 19.5 and clock < 20)
	if neighbor_time and visitor.is_empty() and not events.has(neighbor_key):
		events.append(neighbor_key)
		visitor = "neighbor"
		asked_to_leave = false
		mail_waiting = true
		visit_started = clock
		visit_until = clock + 0.25
		log_entry("초인종. 문 앞에서 종이봉투가 스치는 소리가 난다.")
		sound_events.append("bell")
		bell = true
	return bell

func observe(source: String) -> String:
	if suspense: return observe_full(source)
	if source == "인터폰":
		if visitor == "courier":
			return "밝은 배달 조끼. 손에는 단말기가 있다.\n문 앞 상자에 ‘0417’이 적혀 있다.\n소리: ‘주문하신 간편식입니다. 문 앞에 두겠습니다.’"
		if visitor == "stalker":
			return "모자를 깊이 쓴 사람이 카메라 아래 서 있다.\n손도, 얼굴도 보이지 않는다.\n소리: ‘배달입니다. 문 좀 열어주세요.’"
		return "복도는 조용하다. %s" % ("문 앞에 상자가 놓여 있다." if parcel else "물건은 보이지 않는다.")
	if source == "현관 렌즈":
		if visitor == "stalker":
			return "렌즈의 낮은 시야에 맨손이 보인다. 배달 물품은 없다.\n오른손 손목에 초승달 문신이 있다.\n[관찰 증거: 손목 문신]"
		return "복도 끝까지 보인다. 숨어 있는 사람은 없다.\n" + ("문 앞에 주문 번호 0417의 상자가 있다." if parcel else "현관 앞은 비어 있다.")
	var h := fmod(clock, 24.0)
	if h >= 23.0 or h < 1.0:
		return "가로등 아래 검은 차가 서 있다.\n모자를 쓴 사람이 올라탄다. 번호판 끝 네 자리: 7319.\n[관찰 증거: 차량 번호]"
	return "젖은 골목. 건너편 창 몇 개만 불이 켜져 있다.\n지금은 눈에 띄는 움직임이 없다."

func observe_full(source: String) -> String:
	if source == "창밖":
		return "검은 차에 후드를 쓴 사람이 올라탄다. 번호판 끝 네 자리는 7319." if clock - last_departure <= 1 else "젖은 골목. 형광등이 켜진 창 아래로 비가 내린다."
	if visitor.is_empty(): return "지금 보이는 복도에는 사람이 없다.\n" + ("주문한 상자가 매트 위에 남아 있다." if parcel else ("매트 위에 종이봉투가 놓여 있다." if mail_waiting else "매트 위에도 물건은 없다."))
	if source == "현관 렌즈" and visitor == "stalker":
		return "오른쪽 아래로 젖은 신발 끝이 보인다. 소매와 장갑 사이, 손목의 초승달 모양.\n문 양옆 깊숙한 곳은 렌즈에서도 가려져 있다."
	if not camera_person(): return "카메라에는 사람이 없다. 상자 하나만 보인다.\n문 바로 양옆은 이 화면으로 확인할 수 없다."
	if visitor == "neighbor": return "후드를 쓴 사람이 종이봉투를 들고 있다. 얼굴은 형광등 아래에서도 어둡다."
	var detail: String = ["젖은 후드와 갈색 상자. 얼굴은 빛에 가려져 있다.", "모자를 깊이 눌러쓴 사람. 손에 든 봉투가 젖어 있다.", "고개를 숙인 사람. 한쪽 소매가 길게 손을 덮고 있다."][visit_style]
	return "%s\n송장의 번호: %s. 상자 옆면은 이 각도에서 보이지 않는다." % [detail, order_number if not order_number.is_empty() else "0?1?"]

func collect(source: String) -> bool:
	var clue := ""
	if source == "현관 렌즈" and visitor == "stalker":
		clue = "손목 문신"
	var h := fmod(clock, 24.0)
	if source == "창밖" and ((clock - last_departure <= 1) if suspense else (h >= 23.0 or h < 1.0)):
		clue = "차량 번호"
	if source == "카메라" and camera_ready and recorded_visit: clue = "현관 녹화"
	if clue.is_empty() or evidence.has(clue):
		return false
	evidence.append(clue)
	log_entry("증거 기록: %s. 휴대폰에서 경찰에 전달할 수 있다." % clue)
	return true

func report() -> int:
	if ended: return 0
	var count := 0
	for clue in evidence:
		if not reported.has(clue):
			reported.append(clue)
			count += 1
	if not first_night and not weekly_survival: deadline -= count * 6.0
	if count > 0:
		if weekly_survival: log_entry("증거 %d개 전달. 순찰 강화로 이후 범인의 체류 시간이 짧아진다. 생존 목표는 7일차 자정이다." % count)
		elif first_night: log_entry("경찰에 증거를 전달했다. ‘아침까지 문단속하세요. 순찰을 보내겠습니다.’")
		else: log_entry("증거 %d개 전달. 경찰: ‘순찰과 수색을 앞당기겠습니다.’ 검거 예상 %d시간 단축." % [count, count * 6])
	if clock >= deadline and not weekly_survival:
		finish(true, "제보한 증거로 경찰이 용의자를 검거했다. 이제, 잠들 수 있다.")
	return count

func open_door() -> String:
	if suspense: return open_full_door()
	if visitor == "stalker":
		if defense and not defense_used:
			defense_used = true
			defense = false
			visitor = ""
			sanity = maxf(1.0, sanity - 25.0)
			log_entry("호신 스프레이로 겨우 문을 닫았다. ‘다음엔 그거 안 통해.’")
			return "스프레이를 사용해 살아남았다. 같은 방어는 다시 통하지 않는다."
		finish(false, "문을 연 순간, 그가 안으로 들어왔다.")
		return ending
	if parcel:
		food += 3
		parcel = false
		visitor = ""
		log_entry("주문한 간편식 3개를 안전하게 회수했다.")
		return "간편식 3개를 회수했다."
	return "문 앞은 비어 있다. 조용히 문을 닫았다."

func open_full_door() -> String:
	if visitor == "stalker":
		if not defenses.is_empty():
			var method: String = defenses.pop_front()
			used_defenses.append(method)
			defense = not defenses.is_empty()
			visitor = ""
			last_departure = clock
			sanity = maxf(1, sanity - 25)
			log_entry("%s를 써서 겨우 문을 닫았다. ‘다음엔 그건 안 통해.’" % CATALOG[method].name)
			return "한 번 살아남았다. 사용한 수단은 다시 통하지 않는다."
		finish(false, "문 옆에 남아 있던 사람이 문을 밀고 들어왔다.")
		return ending
	if parcel:
		match product:
			"pantry": food += 3
			"meal": good_food += 1
			"camera": camera_ready = true
			_: defenses.append(product); defense = true
		parcel = false
		visitor = ""
		log_entry("%s를 회수했다." % product_name)
		return product_name + " 회수 완료."
	if visitor == "neighbor":
		visitor = ""
		mail_waiting = false
		return "이웃이 두고 간 우편물을 받았다. 주문한 물품은 아니었다."
	if mail_waiting:
		mail_waiting = false
		return "잘못 배송되었던 우편물을 회수했다. 봉투에 내 호수가 적혀 있다."
	return "문 앞은 비어 있다. 다시 잠갔다."
