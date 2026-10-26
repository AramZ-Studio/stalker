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

func start(seed_value: int = -1, weekly: bool = true) -> void:
	if is_instance_valid(audio):
		audio.stop_all()
		audio.queue_free()
	active = true
	death_in = -1
	host.game = State.new()
	host.game.enable_full_game(seed_value, weekly)
	host.presence.reset()
	audio = Audio.new()
	host.add_child(audio)
	host.close_panel()
	for child in host.get_children():
		if child is OmniLight3D:
			child.light_energy = 0.55
			child.shadow_enabled = true
	host.panel("OPEN UP · 문열어 / 일주일 생존", "1일차 00시부터 7일차 자정까지 살아남아야 한다.\n매일 최소 한 끼. 한 끼도 먹지 않고 자정을 넘기면 실패한다.\n\n일해서 식량과 필요한 물품을 주문하고, 방문자의 말과 소리를 비교하자.\n제보는 순찰을 강화해 이후 범인이 머무는 시간을 줄인다.\n시간은 생활 행동과 기다리기를 선택할 때만 흐른다.\n\nWASD 걷기 · Shift 달리기 · Ctrl 천천히 걷기 · E 상호작용\n현관: 1 인터폰 / 2 렌즈 / 3 듣기 / 4 대화\nE 길게 문 열기 · X 물러나기 · Tab 오늘 식사와 주문 확인")
	host.button("생활을 시작한다", host.close_panel)

func start_first_night() -> void:
	start(13, false)
	host.game.first_night = true
	host.game.deadline = 30.0
	host.game.threat_times[0] = 21.5
	host.game.purchase("meal")
	host.panel("OPEN UP · 문열어 / 첫날 밤", "18:00. 저녁은 18:45에 도착한다.\nPC에서 업무를 시작하고, 초인종이 울리면 일어나 확인하자.\n\n익숙한 얼굴도, 가려진 얼굴도 있다.\n정체를 판단할 때는 주문한 물건과 상대의 말, 발소리를 비교하자.\n\n다음 날 06:00까지 살아남기.\n관찰·이동·메뉴에서는 생활 시간이 멈춘다.")
	host.button("첫날 밤 시작", host.close_panel)

func observe(source: String) -> void:
	if host.game.ended: return
	host.presence.cancel_hold()
	holding = false
	hold_time = 0
	hold_cued = false
	current_source = source
	host.presence.begin_view(source)
	looking = true
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
	host.presence.present_snapshot(frame, source)
	host.presence.observation_choices(source)
	opening_button = host.presence.opening_button
	host.presence.say(host.game.observe(source))
	if source == "인터폰": audio.cue("hiss")

func dialogue() -> void:
	if host.game.ended: return
	host.presence.cancel_hold()
	host.presence.view = "dialogue"
	host.presence.clear_choices("문 너머로 말을 건넨다 · X 물러나기", true)
	host.presence.set_gesture("tap")
	for item in [["어떤 물건인가요?", "물품"], ["문 앞에 두고 가주세요.", "두고 가기"], ["앱에는 아직 이동 중인데요?", "배송 알림"], ["아까도 오셨죠?", "재방문"]]:
		var topic: String = item[1]
		var callback := func(): ask_topic(topic)
		host.presence.actions.append(callback)
		host.presence.choice(host.presence.rows, "%d  %s" % [host.presence.actions.size(), item[0]], callback)
	host.presence.say("스피커 너머로 낮은 잡음이 들린다.")

func ask_topic(topic: String) -> void:
	var answer: String = host.game.ask(topic)
	observe(current_source)
	host.presence.say(answer)

func listen() -> void:
	if host.game.ended: return
	host.presence.cancel_hold()
	host.presence.begin_view("듣기")
	looking = true
	host.presence.observation_choices("듣기")
	opening_button = host.presence.opening_button
	host.presence.say(host.game.listen())

func wait_at_door() -> void:
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
	if not active or not host.game.suspense: return
	if death_in > 0:
		death_in -= delta
		if death_in <= 0:
			host.presence.veil.color.a = 0
			host.ending()
	for sound in host.game.sound_events: audio.cue(sound)
	host.game.sound_events.clear()
	observation_time = observation_time + delta if looking else 0
	audio.update(delta, host.game.sanity < 25)
	if holding and looking and not host.modal.visible and host.presence.view in ["인터폰", "현관 렌즈", "듣기", "unlock"] and not host.game.ended:
		hold_time += delta
		if not hold_cued:
			audio.cue("unlock")
			hold_cued = true
			host.presence.begin_unlock()
		host.door_lock.rotation.z = minf(hold_time / 0.7, 1) * PI / 2
		host.door_handle.rotation.z = -maxf(0, minf((hold_time - 0.7) / 0.5, 1)) * 0.35
		if is_instance_valid(opening_button): opening_button.text = "E 놓으면 취소 · 잠금쇠…" if hold_time < 0.7 else "E 놓으면 취소 · 손잡이…"
		if hold_time >= 1.2: open()
	elif hold_cued:
		host.presence.cancel_hold()
	if host.game.won:
		host.camera.fov = host.preferred_fov

func open() -> void:
	holding = false
	hold_time = 0
	hold_cued = false
	looking = false
	var result: String = host.game.open_door()
	audio.cue("death" if host.game.ended else "unlock")
	host.presence.animate_open(host.game.ended, result)
	if host.game.ended: death_in = 1.8

func stop() -> void:
	active = false
	if is_instance_valid(audio): audio.stop_all()
	if is_instance_valid(host.presence): host.presence.reset()
