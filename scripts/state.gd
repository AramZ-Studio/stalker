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

func stamp() -> String:
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
		clock += step
		remaining -= step
		activity_hours += step
		hunger = minf(100.0, hunger + 2.4 * step)
		sanity -= (0.55 + (1.5 if hunger >= 80.0 else 0.0)) * step
		if kind == "업무":
			money += int((3000.0 + minf(activity_hours, 4.0) * 300.0) * step)
			sanity -= step * 0.8
		elif kind == "수면":
			sanity = minf(100.0, sanity + sleep_recovery * step)
		if parcel and clock - parcel_since >= 3.0:
			parcel = false
			log_entry("문 앞에 3시간 동안 둔 물품이 사라졌다.")
		var bell := update_events()
		if sanity <= 0.0 or hunger >= 100.0:
			finish(false, "더는 버틸 수 없었다. " + ("공복이 한계에 도달했다." if hunger >= 100.0 else "정신력이 바닥났다."))
		elif clock >= deadline:
			finish(true, "경찰이 용의자를 검거했다. 이제, 잠들 수 있다.")
		elif bell:
			pending = remaining
			if remaining > 0.001:
				activity = kind
			log_entry("초인종. 하던 행동이 멈췄다.")
			break
	sanity = clampf(sanity, 0.0, 100.0)

func update_events() -> bool:
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
		log_entry("주문하지 않은 방문. 문 너머에서 느린 발소리가 들린다.")
		bell = true
	if visitor == "courier" and clock - parcel_since >= 0.5:
		visitor = ""
	if visitor == "stalker" and h >= 23.0:
		visitor = ""
		log_entry("계단을 내려가는 발소리. 창밖에서 엔진 소리가 들린다.")
	return bell

func observe(source: String) -> String:
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

func collect(source: String) -> bool:
	var clue := ""
	if source == "현관 렌즈" and visitor == "stalker":
		clue = "손목 문신"
	var h := fmod(clock, 24.0)
	if source == "창밖" and (h >= 23.0 or h < 1.0):
		clue = "차량 번호"
	if clue.is_empty() or evidence.has(clue):
		return false
	evidence.append(clue)
	log_entry("증거 기록: %s. 휴대폰에서 경찰에 전달할 수 있다." % clue)
	return true

func report() -> int:
	var count := 0
	for clue in evidence:
		if not reported.has(clue):
			reported.append(clue)
			count += 1
	deadline -= count * 6.0
	if count > 0:
		log_entry("증거 %d개 전달. 경찰: ‘순찰과 수색을 앞당기겠습니다.’ 검거 예상 %d시간 단축." % [count, count * 6])
	if clock >= deadline:
		finish(true, "제보한 증거로 경찰이 용의자를 검거했다. 이제, 잠들 수 있다.")
	return count

func open_door() -> String:
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
