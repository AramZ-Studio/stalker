extends RefCounted

const State = preload("res://scripts/state.gd")
const Observation = preload("res://scripts/observation_3d.gd")
var host: Node3D
var active := false
var automatic := false
var generation := 0
var timer: Timer
var route := ""
var index := 0
var steps: Array[Dictionary] = []

func _init(owner_node: Node3D) -> void:
	host = owner_node
	timer = Timer.new()
	timer.wait_time = 5.0
	timer.timeout.connect(on_auto_timeout)
	host.add_child(timer)

func death_steps() -> Array[Dictionary]:
	return [
		{"title": "01 / 혼자 있는 밤", "text": "오늘도 밀린 작업을 시작한다. 음식은 주문하지 않았다.\n이 시연은 방문자의 말을 믿고 문을 열었을 때의 결과를 보여준다.", "action": "", "focus": "pc", "next": "4시간 업무 → 밤 10시"},
		{"title": "02 / 주문하지 않은 배달", "text": "밤 10시. 초인종이 울린다.\n‘배달입니다. 문 좀 열어주세요.’\n하지만 오늘 주문한 물건은 없다.", "action": "work4", "source": "인터폰", "focus": "door", "next": "주문 번호를 물어본다"},
		{"title": "03 / 마지막 판단", "text": "‘번호요? …그냥 문 여세요. 안에 계신 거 알아요.’\n상자를 내려놓는 소리도, 단말기 소리도 없다.\n피곤한 나는 배달일 거라고 생각하며 잠금장치에 손을 뻗는다.", "action": "", "source": "현관 렌즈", "focus": "door", "next": "문을 연다 → 사망"},
		{"title": "04 / 문을 열었다", "text": "문틈으로 그가 몸을 밀어 넣었다.\n주문하지 않은 방문이라는 단서를 무시한 대가였다.", "action": "open", "source": "조우", "focus": "door", "next": ""}
	]

func survival_steps() -> Array[Dictionary]:
	return [
		{"title": "01 / 저녁의 준비", "text": "간편식 세 개를 주문했다. 주문 번호 0417, 한 시간 뒤 도착 예정이다.\n정상 배송과 수상한 방문을 비교하고, 증거를 신고해 살아남는 경로다.", "action": "order", "focus": "phone", "next": "2시간 업무를 시작한다"},
		{"title": "02 / 일하다 들린 초인종", "text": "19시. 배송 때문에 업무가 중단됐다. 한 시간의 업무가 남아 있다.\n배달 조끼, 단말기, 상자의 번호 0417. 내 주문과 일치한다.", "action": "work2", "source": "인터폰", "focus": "door", "next": "물품을 회수하고 남은 업무를 마친다"},
		{"title": "03 / 안전한 회수", "text": "간편식 세 개를 받았다. 남은 한 시간의 업무도 마쳤다.\n식량이 생겼고, 실제 일한 만큼의 수입도 유지됐다.", "action": "retrieve_resume", "focus": "pc", "next": "다시 4시간 업무를 시작한다"},
		{"title": "04 / 두 번째 방문", "text": "22시. 초인종 때문에 다시 업무가 멈췄다.\n이번에는 주문이 없다. 화면 아래에 모자를 쓴 사람이 서 있다.", "action": "work4", "source": "인터폰", "focus": "door", "next": "현관 렌즈로 손과 물품을 확인한다"},
		{"title": "05 / 다른 시야의 단서", "text": "그는 맨손이고 배달 물품도 없다. 오른손 손목에 초승달 문신이 보인다.\n문신을 기록하고 문을 잠근 채 기다리기로 한다.", "action": "wrist", "source": "현관 렌즈", "focus": "door", "next": "업무를 중단하고 1시간 기다린다"},
		{"title": "06 / 떠나는 발소리", "text": "23시. 그가 계단을 내려간다. 복도는 비었다.\n잠시 뒤 창밖에서 차 시동 소리가 들린다.", "action": "wait1", "source": "현관 렌즈", "focus": "door", "next": "창밖 차량 번호를 기록한다"},
		{"title": "07 / 두 번째 증거", "text": "검은 차에 같은 사람이 올라탄다. 번호판 끝 네 자리 7319.\n문신과 차량 번호, 서로 다른 증거 두 개를 확보했다.", "action": "vehicle", "source": "창밖", "focus": "window", "next": "휴대폰으로 경찰에 증거 두 개를 신고한다"},
		{"title": "08 / 수색이 빨라진다", "text": "경찰: ‘제보 감사합니다. 차량을 중심으로 수색하겠습니다.’\n예상 검거 시각이 3일차 06시에서 2일차 18시로, 12시간 앞당겨졌다.", "action": "report", "focus": "phone", "next": "간편식을 먹는다 · 30분"},
		{"title": "09 / 생활을 이어간다", "text": "받아둔 음식으로 공복을 해결했다. 문을 다시 열 필요가 없다.\n긴장이 풀리자 피로가 몰려온다.", "action": "eat", "focus": "food", "next": "8시간 잠을 잔다"},
		{"title": "10 / 다음 날 아침", "text": "아침 7시 30분. 밤새 초인종은 울리지 않았다.\n충분히 쉬고 정신력을 회복했다. 검거까지 10시간 30분 남았다.", "action": "sleep8", "focus": "bed", "next": "4시간 업무를 한다"},
		{"title": "11 / 평소처럼", "text": "오전 11시 30분. 오늘도 생활비를 벌었다.\n경찰 연락을 기다리며 점심을 먹는다.", "action": "work4", "focus": "pc", "next": "간편식으로 점심을 먹는다"},
		{"title": "12 / 문을 열지 않는 오후", "text": "정오. 비축한 식량 덕분에 외부 접촉을 줄였다.\n공복과 정신력에 여유가 있다. 오후 업무를 시작한다.", "action": "eat", "focus": "food", "next": "4시간 업무를 한다"},
		{"title": "13 / 마지막 두 시간", "text": "오후 4시. 추가 방문은 없었다.\n경찰: ‘차량을 확인했습니다. 집 안에서 기다리세요.’", "action": "work4", "focus": "phone", "next": "문을 잠그고 2시간 기다린다"},
		{"title": "14 / 이제 잠들 수 있다", "text": "오후 6시. 제보한 차량 번호와 문신을 바탕으로 용의자가 검거됐다.\n문을 열지 않고 증거를 모은 선택이, 안전한 밤을 되찾아 주었다.", "action": "wait2", "focus": "window", "next": ""}
	]

func start(kind: String) -> void:
	generation += 1
	automatic = false
	timer.stop()
	active = true
	route = kind
	index = 0
	host.game = State.new()
	host.last_bell = ""
	steps = death_steps() if route == "death" else survival_steps()
	host.game.log_entry("시연 시작: " + ("사망 경로" if route == "death" else "생존 경로"))
	apply_step(steps[0].action)
	render()

func apply_step(action: String) -> void:
	var s = host.game
	match action:
		"order": s.order()
		"work2": s.begin("업무", 2)
		"work4": s.begin("업무", 4)
		"retrieve_resume":
			s.open_door()
			s.resume_activity()
		"wrist": s.collect("현관 렌즈")
		"vehicle": s.collect("창밖")
		"report": s.report()
		"wait1", "wait2":
			if s.pending > 0: s.cancel_activity()
			s.begin("대기", 1 if action == "wait1" else 2)
		"eat":
			assert(s.food > 0)
			s.food -= 1
			s.hunger = maxf(0, s.hunger - 42)
			s.sanity = minf(100, s.sanity + 3)
			s.log_entry("간편식을 먹었다.")
			s.begin("식사", 0.5)
		"sleep8": s.begin("수면", 8)
		"open": s.open_door()

func advance() -> void:
	if index >= steps.size() - 1:
		return
	index += 1
	apply_step(steps[index].action)
	render()

func focus_room(key: String) -> void:
	var point := Vector3(0, 1.5, -4.8)
	var position := Vector3(0, 0.05, -1.7)
	match key:
		"pc": point = Vector3(-3.4, 1.1, -3.9); position = Vector3(-1.0, 0.05, -1.2)
		"phone": point = Vector3(3.6, 0.9, 0.2); position = Vector3(0, 0.05, -0.8)
		"food": point = Vector3(3.5, 1.1, -4); position = Vector3(1.4, 0.05, -1.2)
		"bed": point = Vector3(-3.6, 0.9, 2.8); position = Vector3(-1.0, 0.05, 0.3)
		"window": point = Vector3(3, 1.8, 4.7); position = Vector3(1.6, 0.05, 1.3)
	host.player.position = position
	host.player.velocity = Vector3.ZERO
	host.player.rotation = Vector3.ZERO
	host.camera.look_at(point)

func render() -> void:
	var step := steps[index]
	focus_room(step.get("focus", "door"))
	var name := "사망 시연" if route == "death" else "생존 시연"
	host.panel("%s  ·  %s" % [name, step.title], step.text)
	host.paragraph("%s   |   %d / %d 단계" % [host.game.stamp(), index + 1, steps.size()])
	if step.has("source"):
		var frame = Observation.new()
		frame.custom_minimum_size.y = 190
		frame.source = step.source
		frame.visitor = host.game.visitor
		frame.parcel = host.game.parcel
		frame.hour = fmod(host.game.clock, 24)
		host.content.add_child(frame)
	if index < steps.size() - 1:
		host.button("다음: " + step.next, advance)
		host.button("자동 진행 멈추기" if automatic else "자동 시연 · 5초마다 다음 단계", toggle_auto)
	else:
		automatic = false
		timer.stop()
		host.paragraph("실제 규칙 결과: %s · 신고 %d/2 · 식량 %d · 공복 %d · 정신력 %d" % ["생존" if host.game.won else "사망", host.game.reported.size(), host.game.food, int(host.game.hunger), int(host.game.sanity)])
		host.button("다른 경로 시연하기", func(): start("survival" if route == "death" else "death"))
		host.button("같은 경로 다시 시연", func(): start(route))
	host.button("시연 종료 / 시작 화면", func(): active = false; automatic = false; host.get_tree().reload_current_scene())
	host.update_hud()

func toggle_auto() -> void:
	automatic = not automatic
	generation += 1
	render()
	if automatic:
		timer.start()
	else:
		timer.stop()

func on_auto_timeout() -> void:
	if active and automatic and index < steps.size() - 1:
		advance()
	else:
		timer.stop()

func pause() -> void:
	automatic = false
	timer.stop()
	generation += 1
	host.panel("시연 일시정지", "‘다음’ 버튼으로 직접 진행하거나 자동 시연을 켤 수 있다.")
	host.button("시연 계속", render)
	host.button("사망 경로 처음부터", func(): start("death"))
	host.button("생존 경로 처음부터", func(): start("survival"))
	host.button("시연 종료 / 시작 화면", func(): active = false; host.get_tree().reload_current_scene())
