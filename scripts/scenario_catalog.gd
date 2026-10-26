extends RefCounted

const State = preload("res://scripts/state.gd")
# Every entry uses the same State rules and first-person presentation as the demo.
const CASES := [
	{"id":"courier", "group":"방문", "name":"정상 배송", "view":"인터폰", "action":"open", "hour":11, "hint":"주문·대화·퇴장 확인 후 회수한다."},
	{"id":"hurried", "group":"방문", "name":"번호를 못 읽는 배달원", "view":"인터폰", "action":"open", "hour":11, "hint":"번호 하나 대신 물품·앱·퇴장 행동을 비교한다."},
	{"id":"neighbor", "group":"방문", "name":"이웃과 잘못 온 우편물", "view":"인터폰", "action":"open", "hour":17, "hint":"질문하거나 우편물을 받아 이웃의 정보를 얻는다."},
	{"id":"empty", "group":"방문", "name":"아무도 없는 복도", "view":"인터폰", "action":"listen", "hint":"빈 화면과 실제 문밖 소리를 확인한다.", "order":false},
	{"id":"impostor", "group":"방문", "name":"주문 번호를 아는 사칭", "view":"인터폰", "action":"ask", "hint":"물품명과 배송 설명을 비교한다."},
	{"id":"mimic", "group":"방문", "name":"배달원의 대답을 흉내 내는 범인", "view":"인터폰", "action":"ask", "hint":"정확한 대답만으로 확정하지 말고 소리·렌즈를 확인한다."},
	{"id":"false_exit", "group":"방문", "name":"간다고 말하고 남아 있는 방문자", "view":"인터폰", "action":"leave", "hint":"두고 가달라고 한 뒤 다른 시야로 확인한다."},
	{"id":"blind", "group":"방문", "name":"카메라 사각지대", "view":"인터폰", "action":"listen", "hint":"카메라에는 없지만 렌즈와 듣기로 확인할 수 있다."},
	{"id":"knock", "group":"방문", "name":"없는 척한 뒤 반복 노크", "view":"인터폰", "action":"wait", "hint":"기다리면 반복 호출이 발생한다."},
	{"id":"work_bell", "group":"생활", "name":"업무 중 초인종", "view":"room", "action":"work", "hour":10, "hint":"업무 시작 후 실제 배송이 중단시킨다. 남은 시간은 휴대폰에서 재개한다."},
	{"id":"sleep_bell", "group":"생활", "name":"수면 중 초인종", "view":"room", "action":"sleep", "hour":10, "hint":"잠든 뒤 배송 초인종으로 깨어난다."},
	{"id":"stock", "group":"생활", "name":"비축 식량으로 식사", "view":"room", "action":"eat", "hour":12, "hint":"실제 재고를 소비하며 오늘 식사를 기록한다."},
	{"id":"favorite", "group":"생활", "name":"좋아하는 음식", "view":"room", "action":"tasty", "hour":12, "sanity":40, "hint":"공복과 정신력 회복을 확인한다."},
	{"id":"late_parcel", "group":"생활", "name":"회수 기한이 얼마 남지 않은 배송", "view":"인터폰", "action":"open", "hour":13, "hint":"지금 회수하거나 더 기다린 결과를 비교한다."},
	{"id":"theft", "group":"생활", "name":"미회수 물품 도난", "view":"인터폰", "action":"wait", "hour":13, "hint":"기다리면 3시간 회수 기한을 넘겨 물건을 잃는다."},
	{"id":"delayed_shipping", "group":"생활", "name":"5일차 배송 지연", "view":"phone", "action":"work", "day":4, "hour":14, "hint":"5일차 일반 주문은 두 시간 늦어진다. 예정 시각과 업무 중 도착을 확인한다."},
	{"id":"no_food", "group":"생활", "name":"식량 부족", "view":"room", "action":"eat", "hint":"음식이 없는 식사는 인정되지 않는다. 주문과 회수가 필요하다."},
	{"id":"daily_meal", "group":"생활", "name":"하루 식사를 놓친 자정", "view":"room", "action":"wait", "hint":"필수 조건: 오늘 식사 0회, 자정 직전. 기다리면 실패한다."},
	{"id":"shifted_sleep", "group":"생활", "name":"달라진 취침 시각", "view":"room", "action":"sleep", "hour":3, "hint":"이전 취침 시각 차이 때문에 수면과 회복이 줄어든다."},
	{"id":"night_walk", "group":"생활", "name":"밤 산책과 두려움", "view":"room", "action":"walk", "sanity":20, "hint":"정신력이 낮으면 밤 외출을 거부한다. 조건을 높여 비교할 수 있다."},
	{"id":"day_walk", "group":"생활", "name":"낮 산책", "view":"room", "action":"walk", "hour":12, "sanity":40, "hint":"낮과 밤의 정신력 회복을 비교한다."},
	{"id":"hunger", "group":"생활", "name":"공복 한계", "view":"room", "action":"wait", "hint":"필수 조건: 공복이 한계 직전. 식사 또는 대기로 결과를 비교한다."},
	{"id":"sanity", "group":"생활", "name":"정신력 한계", "view":"room", "action":"wait", "hint":"필수 조건: 정신력이 한계 직전. 기다리면 실패한다."},
	{"id":"tattoo", "group":"조사", "name":"손목 특징 기록", "view":"현관 렌즈", "action":"collect", "hint":"렌즈에서 기록한 정보를 휴대폰으로 제보한다."},
	{"id":"vehicle", "group":"조사", "name":"떠난 뒤 차량 확인", "view":"창밖", "action":"collect", "hint":"방문자가 떠난 뒤 제한된 시간 안에 차량을 기록한다."},
	{"id":"camera_delivery", "group":"조사", "name":"조사 카메라 배송·설치", "view":"인터폰", "action":"open", "hour":11, "hint":"배송을 회수한 시점부터 녹화가 가능하다."},
	{"id":"recording", "group":"조사", "name":"설치 이후 녹화 증거", "view":"인터폰", "action":"recording", "hint":"과거 방문이 아닌 설치 이후 촬영된 녹화를 기록한다."},
	{"id":"no_recording", "group":"조사", "name":"설치 전 방문은 녹화되지 않음", "view":"phone", "action":"recording", "hint":"카메라를 설치해도 이전 방문의 증거가 소급 생성되지는 않는다."},
	{"id":"report", "group":"조사", "name":"경찰 제보·순찰 강화", "view":"phone", "action":"report", "hint":"확보한 새 증거를 전달한다. 일주일 목표는 유지된다."},
	{"id":"spray", "group":"방어", "name":"호신 스프레이 방어", "view":"현관 렌즈", "action":"open", "defense":"spray", "hint":"준비한 물품 하나가 실제로 소비된다. 조건에서 다른 물품과 비교할 수 있다."},
	{"id":"alarm", "group":"방어", "name":"휴대용 경보기 방어", "view":"현관 렌즈", "action":"open", "defense":"alarm", "hint":"방어 후 남은 수단과 다음 구매 가격을 확인한다."},
	{"id":"light", "group":"방어", "name":"고광도 손전등 방어", "view":"현관 렌즈", "action":"open", "defense":"light", "hint":"방어와 문 닫기 연출을 확인한다."},
	{"id":"reuse", "group":"방어", "name":"같은 방어 수단 재사용 실패", "view":"현관 렌즈", "action":"open", "hint":"필수 조건: 선택한 수단은 이미 사용됐다. 재주문도 허용되지 않는다."},
	{"id":"defense_delivery", "group":"방어", "name":"호신용품 배송·회수", "view":"인터폰", "action":"open", "hour":11, "defense":"spray", "hint":"선택한 호신용품을 배송으로 받아야 보유하게 된다."},
	{"id":"unarmed", "group":"방어", "name":"호신용품 없는 조우", "view":"현관 렌즈", "action":"open", "hint":"방어 물품을 없음으로 두면 침입·사망 연출을 확인한다."},
	{"id":"survived", "group":"결말", "name":"일주일 생존 결말", "view":"room", "action":"wait", "day":6, "hint":"필수 조건: 마지막 날 식사 완료, 자정 직전. 기다려 실제 승리 판정을 확인한다."},
	{"id":"prepared", "group":"결말", "name":"증거를 갖춘 생존 결말", "view":"room", "action":"wait", "day":6, "hint":"세 종류의 제보를 마친 마지막 자정이다."},
	{"id":"scarred", "group":"결말", "name":"방어의 흔적이 남은 생존 결말", "view":"room", "action":"wait", "day":6, "hint":"이미 한 번 방어한 상태에서 마지막 자정을 넘긴다."}
]

static func entry(id: String) -> Dictionary:
	for item in CASES:
		if item.id == id: return item
	return {}

static func defaults(id: String) -> Dictionary:
	var item := entry(id)
	return {"day":item.get("day", 0), "hour":item.get("hour", 22), "sanity":item.get("sanity", 70), "food":0 if id == "no_food" else 1, "order":item.get("order", true), "defense":item.get("defense", "none"), "product":"camera" if id == "camera_delivery" else "pantry"}

static func build(id: String, overrides: Dictionary = {}) -> RefCounted:
	assert(not entry(id).is_empty())
	var config := defaults(id)
	config.merge(overrides, true)
	var s = State.new()
	s.enable_full_game(13)
	s.campaign = false
	s.clock = clampi(int(config.day), 0, 6) * 24.0 + clampi(int(config.hour), 0, 23)
	s.meal_day = int(s.clock / 24)
	s.meals_today = 1
	s.last_walk = s.clock
	s.sanity = clampf(float(config.sanity), 5, 100)
	s.food = maxi(0, int(config.food))
	s.money = 30000
	s.product = str(config.product)
	s.product_name = s.product_label(s.product)
	s.order_number = "6248" if config.order else ""
	for day in range(8): s.threat_times[day] = 9999.0
	for day in range(s.meal_day): s.meal_history[day] = 1
	if config.defense != "none": s.defenses.append(str(config.defense))
	if entry(id).group in ["방어"] or id in ["impostor", "mimic", "false_exit", "blind", "knock", "tattoo", "recording"]:
		s.visitor = "stalker"
		s.visit_started = s.clock
		s.visit_until = s.clock + 1
		s.events.append("full_visit_%d" % s.meal_day)
	match id:
		"courier", "hurried", "camera_delivery":
			s.visitor = "courier"
			s.parcel = bool(config.order)
			s.parcel_since = s.clock
			s.visit_started = s.clock
			s.visit_until = s.clock + 0.5
			if id == "hurried": s.delivery_persona = 1
			if id == "camera_delivery": s.product = "camera"; s.product_name = s.product_label("camera")
		"neighbor": s.visitor = "neighbor"; s.mail_waiting = true; s.visit_until = s.clock + 0.25
		"mimic": s.threat_profile = "mimic"
		"blind": s.asked_to_leave = true; s.visit_started -= 0.5
		"knock": s.visit_started -= 0.45
		"work_bell", "sleep_bell":
			if config.order: s.order_due = s.clock + 0.25
			else: s.threat_times[s.meal_day] = s.clock + 0.25
		"delayed_shipping": s.campaign = true; s.purchase(s.product); s.campaign = false
		"favorite": s.good_food = 1
		"late_parcel", "theft": s.parcel = true; s.parcel_since = s.clock - (2.95 if id == "theft" else 2.5)
		"no_food": s.food = 0; s.good_food = 0
		"daily_meal": s.clock = s.meal_day * 24 + 23.95; s.meals_today = 0
		"shifted_sleep": s.last_sleep = s.clock - 8
		"hunger": s.hunger = 99.9
		"sanity": s.sanity = 0.05
		"vehicle": s.last_departure = s.clock
		"recording": s.camera_ready = true; s.recorded_visit = true
		"no_recording": s.camera_ready = true; s.recorded_visit = false
		"defense_delivery":
			s.defenses.clear()
			s.visitor = "courier"
			s.visit_until = s.clock + 0.5
			s.parcel = true
			s.parcel_since = s.clock
			s.product = str(config.defense) if config.defense != "none" else "spray"
			s.product_name = s.product_label(s.product)
		"report": s.evidence.assign(["손목 문신", "차량 번호", "현관 녹화"])
		"reuse":
			var used: String = str(config.defense) if config.defense != "none" else "spray"
			s.used_defenses.append(used)
			s.defenses.clear()
		"survived", "prepared", "scarred":
			s.clock = 167.95
			s.meal_day = 6
			for day in range(6): s.meal_history[day] = 1
			if id == "prepared": s.reported.assign(["손목 문신", "차량 번호", "현관 녹화"])
			if id == "scarred": s.used_defenses.append("spray")
	s.journal.clear()
	s.log_entry("체험 조건: " + str(entry(id).name) + " · " + str(entry(id).hint))
	return s

static func perform(s: RefCounted, id: String) -> String:
	match str(entry(id).action):
		"open": return s.open_door()
		"ask": return s.ask("물품")
		"leave": return s.ask("두고 가기")
		"listen": return s.listen()
		"work": s.begin("업무", 4)
		"sleep": s.begin("수면", 8)
		"eat", "tasty":
			if s.eat(entry(id).action == "tasty"): s.begin("식사", 0.5)
			else: return "먹을 음식이 없다. 주문과 회수가 필요하다."
		"walk": return s.take_walk()
		"collect": return "증거 기록 완료" if s.collect("창밖" if id == "vehicle" else "현관 렌즈") else "새 증거 없음"
		"recording": return "녹화 기록 완료" if s.collect("카메라") else "새 녹화 없음"
		"report": return "증거 %d개 제보" % s.report()
		"wait": s.begin("대기", 0.25)
	return s.ending if s.ended else (s.journal[0] if not s.journal.is_empty() else "상황을 확인했다.")
