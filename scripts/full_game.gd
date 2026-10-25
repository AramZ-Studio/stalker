extends RefCounted

const State = preload("res://scripts/state.gd")
const Observation = preload("res://scripts/observation_3d.gd")
const Audio = preload("res://scripts/night_audio.gd")
var host: Node3D
var active := false
var looking := false
var holding := false
var hold_time := 0.0
var audio: Node
var current_source := "인터폰"
var opening_button: Button
var observation_time := 0.0
var death_in := -1.0
var hold_cued := false

func _init(owner_node: Node3D) -> void:
	host = owner_node

func start(seed_value: int = -1) -> void:
	if is_instance_valid(audio):
		audio.stop_all()
		audio.queue_free()
	active = true
	death_in = -1
	host.game = State.new()
	host.game.enable_full_game(seed_value)
	audio = Audio.new()
	host.add_child(audio)
	host.close_panel()
	for child in host.get_children():
		if child is OmniLight3D:
			child.light_energy = 0.55
			child.shadow_enabled = true
	host.panel("OPEN UP · 문열어 / 생활과 문밖", "혼자 사는 재택 개발자. 밤마다 누군가 찾아오지만 생활은 계속해야 한다.\n\nPC에서 업무 시간을 정해 돈을 벌고, 식량·음식·조사 물품·호신용품을 주문한다.\n침대에서 자고, 현관에서 산책할 수 있다. 오래 굶거나 잠·외출이 부족하면 정신력이 떨어진다.\n\n정지 화면·대화·주문 정보·소리를 비교해 문을 열지 판단하라.\n확보한 증거는 휴대폰으로 신고하면 검거 예상이 앞당겨진다.\n\n시간은 업무·수면·식사·대기·외출로 흐른다. 초인종은 하던 행동을 멈춘다.\n물품을 회수하지 않은 채 3시간이 지나면 잃을 수 있다.\n\nWASD 이동 · E 확인 · Tab 휴대폰 · J 기록 · Esc 메뉴\n남은 간편식은 1개다. 먼저 휴대폰에서 필요한 물품과 배송 시간을 확인하자.")
	host.button("생활을 시작한다", host.close_panel)

func start_first_night() -> void:
	start(13)
	host.game.first_night = true
	host.game.deadline = 30.0
	host.game.threat_times[0] = 21.5
	host.game.purchase("meal")
	host.panel("OPEN UP · 문열어 / 첫날 밤", "18:00. 저녁을 주문해 두었다. 도착 예정은 18:45.\n\nPC에서 일을 시작하고 첫 배송을 확인하자.\n이후에는 이웃의 방문과 주문하지 않은 방문이 이어진다.\n후드와 가려진 얼굴만으로 정체를 판단할 수 없다.\n물품명·대답·소리와 서로 다른 시야를 비교하자.\n\n업무·수면·식사·기다리기만 시간을 보낸다. 관찰과 메뉴에서는 멈춘다.\n목표는 다음 날 06:00까지 생활을 유지하며 살아남기.\n검거까지 버티는 전체 생존 모드는 시작 메뉴에서 별도로 선택할 수 있다.")
	host.button("첫날 밤 시작", host.close_panel)

func button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 42
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.pressed.connect(action)
	row.add_child(result)
	return result

func observe(source: String) -> void:
	if host.game.ended: return
	looking = true
	holding = false
	hold_time = 0
	current_source = source
	host.panel(source + " / " + host.game.stamp())
	looking = true
	host.modal.offset_left = -590
	host.modal.offset_right = 590
	host.modal.offset_top = -360
	host.modal.offset_bottom = 360
	var frame = Observation.new()
	frame.source = source
	frame.variant = host.game.visit_style
	frame.clue_visible = source == "현관 렌즈" and host.game.visitor == "stalker"
	frame.mail = host.game.mail_waiting
	frame.uncertain = source != "창밖"
	var visible_person: bool = host.game.camera_person() if source == "인터폰" else host.game.lens_person()
	frame.visitor = "visitor" if visible_person else ""
	frame.lurking = host.game.visitor == "stalker" and not host.game.camera_person()
	frame.parcel = host.game.parcel or host.game.visitor == "stalker" and not host.game.camera_person()
	frame.hour = 23.5 if host.game.clock - host.game.last_departure <= 1 else 18.0
	frame.custom_minimum_size.y = 330
	host.content.add_child(frame)
	host.paragraph(host.game.observe(source))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	host.content.add_child(row)
	button(row, "인터폰", func(): observe("인터폰"))
	button(row, "현관 렌즈", func(): observe("현관 렌즈"))
	button(row, "귀 기울이기", listen)
	button(row, "대화하기", dialogue)
	button(row, "3분 기다린 뒤 확인", wait_at_door)
	var second := HBoxContainer.new()
	second.add_theme_constant_override("separation", 8)
	host.content.add_child(second)
	button(second, "관찰 기록", func():
		var found: bool = host.game.collect(source)
		host.message("기록", "증거를 기록했다. 휴대폰에서 경찰에 전달할 수 있다." if found else "추가로 기록할 새로운 증거는 없다.", func(): observe(source)))
	opening_button = button(second, "꾹 눌러 문 열기", func(): pass)
	opening_button.button_down.connect(func(): holding = true; hold_cued = false)
	opening_button.button_up.connect(func(): holding = false; hold_time = 0; hold_cued = false; audio.stop_cue("unlock"))
	button(second, "휴대폰 / 주문", host.phone)
	button(second, "물러나기", host.close_panel)
	if source == "인터폰": audio.cue("hiss")

func dialogue() -> void:
	var source := current_source
	host.panel("인터폰 통화", "스피커 너머로 낮은 잡음이 들린다.")
	for item in [["어떤 물건인가요?", "물품"], ["문 앞에 두고 가주세요.", "두고 가기"], ["배송 앱에는 아직 이동 중인데요?", "배송 알림"], ["아까도 오셨죠?", "재방문"]]:
		var topic: String = item[1]
		button_in_dialogue(item[0], topic)
	host.button("통화 종료", func(): observe(source))

func button_in_dialogue(text: String, topic: String) -> void:
	host.button(text, func():
		var answer: String = host.game.ask(topic)
		host.message("문 너머의 목소리", answer, func(): observe(current_source)))

func listen() -> void:
	host.panel("문에 귀를 댄다", host.game.listen())
	# Listening has no camera feed; the player must compare it with a snapshot.
	host.paragraph("문에 가린 소리만 들린다.\n시야를 확인하려면 귀를 떼어야 한다.")
	host.button("귀를 떼고 다시 확인", func(): observe(current_source))
	host.button("물러나기", host.close_panel)

func wait_at_door() -> void:
	# Explicit action advances the life clock; looking and menus stay frozen.
	var remaining: float = host.game.pending
	var kind: String = host.game.activity
	var worked: float = host.game.activity_hours
	host.game.advance(0.05)
	host.game.pending = remaining
	host.game.activity = kind
	host.game.activity_hours = worked
	if host.game.ended: host.ending()
	else: observe(current_source)

func update(delta: float) -> void:
	if not active: return
	if not host.game.suspense: return
	if death_in > 0:
		death_in -= delta
		if death_in <= 0: host.ending()
	for sound in host.game.sound_events: audio.cue(sound)
	host.game.sound_events.clear()
	observation_time = observation_time + delta if looking and host.modal.visible else 0
	audio.update(delta, host.game.sanity < 25)
	if holding and looking and host.modal.visible and not host.game.ended:
		hold_time += delta
		if not hold_cued:
			audio.cue("unlock")
			hold_cued = true
		if is_instance_valid(opening_button): opening_button.text = "잠금쇠를 돌린다… 놓으면 취소" if hold_time < 0.7 else "손잡이에 힘이 들어간다…"
		if hold_time >= 1.2: open()
	else:
		if hold_cued: audio.stop_cue("unlock")
		hold_time = 0
		hold_cued = false
		if is_instance_valid(opening_button): opening_button.text = "꾹 눌러 문 열기"
	host.camera.fov = host.preferred_fov

func open() -> void:
	holding = false
	hold_time = 0
	var result: String = host.game.open_door()
	audio.cue("death" if host.game.ended else "unlock")
	if host.game.ended:
		death_in = 1.5
		host.panel("문이 안쪽으로 밀린다.")
		var frame = Observation.new()
		frame.source = "조우"
		frame.visitor = "stalker"
		frame.custom_minimum_size.y = 380
		host.content.add_child(frame)
		host.paragraph("잠금이 풀리는 소리를 기다리고 있었다.")
	else:
		var tween := host.create_tween()
		tween.tween_property(host.entrance_hinge, "rotation:y", -0.4, 0.25)
		tween.tween_property(host.entrance_hinge, "rotation:y", 0.0, 0.4)
		host.message("현관", result, func(): observe("인터폰"))

func stop() -> void:
	active = false
	if is_instance_valid(audio): audio.stop_all()
