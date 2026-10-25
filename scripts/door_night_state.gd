extends RefCounted

# A self-contained, replayable night. Truth stays in this model; observations
# expose incomplete facts rather than a visitor's role.
const ORDERS := [
	{"code": "0417", "items": "생수 · 컵라면", "time": "22:40–05:30 · 우천으로 순서 변경 가능"},
	{"code": "5826", "items": "즉석밥 · 통조림", "time": "22:40–05:30 · 우천으로 순서 변경 가능"},
	{"code": "9032", "items": "약 · 휴지", "time": "22:40–05:30 · 우천으로 순서 변경 가능"}
]
var rng := RandomNumberGenerator.new()
var sequence: Array[String] = []
var round_index := -1
var arrival_in := 9.0
var age := 0.0
var elapsed := 0.0
var visitor := false
var active := true
var paused := false
var ended := false
var won := false
var reason := ""
var supplies := 0
var missed := 0
var delivered := 0
var rings := 0
var looked := 0
var asked := false
var listening := false
var notes: Array[String] = []
var kind := ""
var events: Array[String] = []

func _init(seed_value: int = -1) -> void:
	if seed_value < 0: rng.randomize()
	else: rng.seed = seed_value
	# Three legitimate deliveries, two impostors. All permutations are possible.
	sequence.assign(["rain", "hurried", "quiet", "copied", "insistent"])
	for i in range(sequence.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := sequence[i]
		sequence[i] = sequence[j]
		sequence[j] = temp
	note("야간 배송 3건이 예정되어 있다. 두 묶음 이상 확보하고 날이 밝을 때까지 문을 지켜야 한다.")

func note(text: String) -> void:
	notes.push_front(text)

func order() -> Dictionary:
	return ORDERS[mini(delivered, ORDERS.size() - 1)]

func dangerous() -> bool:
	return kind in ["copied", "insistent"]

func threat_present() -> bool:
	return visitor and dangerous() and age < 44.0

func camera_person() -> bool:
	if not visitor: return false
	if dangerous(): return age < 12.0
	return age < 18.0

func lens_person() -> bool:
	return camera_person() or (threat_present() and age < 36.0)

func package_visible() -> bool:
	return visitor and (not dangerous() or age < 44.0)

func code_matches() -> bool:
	return not dangerous() or kind == "copied"

func tick(delta: float) -> void:
	if ended or paused: return
	elapsed += delta
	if not visitor:
		arrival_in -= delta
		if arrival_in <= 0: arrive()
		return
	var previous := age
	age += delta
	if previous < 12 and age >= 12 and dangerous():
		events.append("shuffle")
		note("문 바로 옆에서 옷깃이 스친다. 화면에서는 사람이 보이지 않는다.")
	if previous < 18 and age >= 18 and not dangerous():
		events.append("steps_away")
		note("발소리가 계단 쪽으로 멀어진다. 엘리베이터 도착음이 들린다.")
	if dangerous() and previous < 27 and age >= 27:
		rings += 1
		events.append("knock")
		note("똑. 똑똑. 초인종 대신 문을 두드린다.")
	if dangerous() and previous < 44 and age >= 44:
		events.append("steps_away")
		note("무언가를 집어 드는 소리. 이번에는 발소리가 계단 아래로 멀어진다.")
	if age >= 62.0:
		if not dangerous():
			missed += 1
			delivered += 1
			note("도착 알림이 취소됐다. 오래 둔 물품이 사라졌다.")
		resolve_visit()

func arrive() -> void:
	round_index += 1
	if round_index >= sequence.size():
		finish(supplies >= 2, "동이 텄다. 필요한 물품을 확보했고, 끝내 문은 지켜냈다." if supplies >= 2 else "아침은 왔지만 생필품을 충분히 확보하지 못했다. 두 묶음 이상이 필요했다.")
		return
	kind = sequence[round_index]
	visitor = true
	age = 0
	asked = false
	looked = 0
	rings += 1
	events.append("bell")
	note("딩동. 휴대폰에 ‘배송 기사 메시지: 문 앞입니다’가 떴다.")

func resolve_visit() -> void:
	visitor = false
	age = 0
	kind = ""
	arrival_in = 9.0

func ask() -> String:
	asked = true
	if not visitor or age >= 44 and dangerous(): return "……대답이 없다."
	if not camera_person() and not dangerous(): return "이미 내려간 것 같다. 휴대폰에는 ‘문 앞에 두었습니다’라는 메시지가 남았다."
	if kind == "copied":
		return "‘%s 맞죠? 문 앞에 두었습니다.’\n잠시 뒤 덧붙인다. ‘문 여는 소리 듣고 갈게요.’\n무슨 물건인지 물으니 ‘세제요’라고 답한다." % order().code
	if kind == "insistent":
		return "‘냉동식품이라 직접 받으셔야 해요. 서명만 해주세요.’\n주문 번호는 잡음 때문에 끝까지 들리지 않는다."
	if kind == "hurried":
		return "‘%s, %s요. 다음 배송 있어서 먼저 내려갈게요.’\n말이 빠르고 다소 짜증이 섞여 있다." % [order().code, order().items]
	return "‘%s, %s 맞으시죠? 비가 와서 상자가 좀 젖었어요. 두고 갈게요.’" % [order().code, order().items]

func listen() -> String:
	if not visitor: return "냉장고 소리 사이로 복도의 형광등이 낮게 운다."
	if threat_present():
		if age < 12: return "상자 바닥이 바닥에 닿는 소리. 그런데 발소리가 이어지지 않는다."
		return "문 바로 옆에서 고무 밑창이 비빈다.\n숨을 죽이자, 바깥에서도 누군가 숨을 멈춘다."
	if not dangerous() and age < 18: return "비닐이 바스락거리고 단말기 버튼음이 짧게 난다.\n잠시 뒤 계단 쪽에서 발소리가 들린다."
	return "발소리가 멀어졌다. 엘리베이터 소리가 끊긴 뒤 복도가 조용해진다."

func observation(source: String) -> String:
	looked += 1
	if not visitor: return "빈 복도. 형광등 아래, 낡은 매트만 놓여 있다."
	if source == "현관 렌즈":
		if threat_present() and not camera_person():
			return "카메라에는 없던 사람이 문 옆 벽에 붙어 있다.\n신발도, 그림자도 아직 문을 향하고 있다."
		if lens_person(): return "후드에 얼굴이 가려져 있다. 한 손에는 젖은 상자.\n렌즈가 흐려 송장 번호를 읽기 어렵다."
		return "양옆 복도까지 보인다. 움직이는 그림자는 없다.\n" + ("매트 위에 상자 하나가 남아 있다." if package_visible() else "상자도 보이지 않는다.")
	if camera_person():
		return "젖은 후드, 바랜 작업복, 갈색 상자. 얼굴은 빛에 가려져 있다.\n송장에는 %s. 화면 아래쪽은 카메라 사각지대다." % (order().code if code_matches() else "0?1?")
	return "화면에는 사람이 없다.\n" + ("상자는 아직 문 앞에 있다. 화면 바깥의 상황은 보이지 않는다." if package_visible() else "상자도 사라졌다. 복도 끝에서 형광등이 한 번 깜빡인다.")

func open_door() -> String:
	if ended: return ""
	if threat_present():
		finish(false, "잠금을 푼 순간 문 옆에 숨어 있던 사람이 밀고 들어왔다.\n빈 인터폰 화면은 빈 복도를 뜻하지 않았다.")
		return "death"
	if visitor and not dangerous():
		var items: String = order().items
		supplies += 1
		delivered += 1
		note("%s를 회수했다. 젖은 포장 안에는 주문한 물품이 들어 있다." % items)
		resolve_visit()
		return "collected"
	return "empty"

func finish(success: bool, text: String) -> void:
	ended = true
	won = success
	reason = text
	note(text)

func clock_text() -> String:
	var base_times := [1367, 1416, 72, 145, 258]
	var minutes := int(base_times[maxi(0, mini(round_index, 4))]) + int(age / 4)
	return "%02d:%02d" % [int(minutes / 60) % 24, minutes % 60]
