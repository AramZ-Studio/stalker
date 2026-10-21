extends Control

var source := "인터폰"
var visitor := ""
var parcel := false
var hour := 18.0

func _ready() -> void:
	custom_minimum_size = Vector2(0, 250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color("111c20"))
	if source == "창밖":
		draw_rect(Rect2(0, h * 0.62, w, h), Color("222b2b"))
		for i in range(7):
			var x := i * w / 7.0
			draw_rect(Rect2(x, 0, w / 7.0 - 6, h * 0.6), Color("182126"))
			for j in range(3):
				draw_rect(Rect2(x + 12, j * 45 + 12, 20, 25), Color("52594a") if (i + j) % 3 == 0 else Color("0c1216"))
		if hour >= 23.0 or hour < 1.0:
			draw_rect(Rect2(w * 0.35, h * 0.67, 150, 45), Color("080a0d"))
			draw_circle(Vector2(w * 0.35 + 25, h * 0.85), 13, Color.BLACK)
			draw_circle(Vector2(w * 0.35 + 125, h * 0.85), 13, Color.BLACK)
			draw_rect(Rect2(w * 0.35 + 120, h * 0.72, 22, 12), Color("c6c6a8"))
	else:
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.3, h * 0.2), Vector2(w * 0.3, h * 0.75), Vector2(0, h)]), PackedColorArray([Color("34403c")]))
		draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w * 0.7, h * 0.2), Vector2(w * 0.7, h * 0.75), Vector2(w, h)]), PackedColorArray([Color("26312e")]))
		draw_rect(Rect2(w * 0.3, h * 0.2, w * 0.4, h * 0.55), Color("1b2826"))
		draw_rect(Rect2(w * 0.44, h * 0.27, w * 0.12, h * 0.43), Color("0c1414"))
		if parcel:
			draw_rect(Rect2(w * 0.55, h * 0.78, 65, 35), Color("8d7752"))
			draw_line(Vector2(w * 0.55 + 32, h * 0.78), Vector2(w * 0.55 + 32, h * 0.78 + 35), Color("c6b594"), 4)
		if not visitor.is_empty():
			var x := w * 0.49
			var y := h * 0.40
			var coat := Color("111618") if visitor == "stalker" else Color("7d905e")
			draw_circle(Vector2(x, y), 22, Color("403f39"))
			draw_rect(Rect2(x - 32, y + 18, 64, 90), coat)
			draw_rect(Rect2(x - 27, y + 105, 20, 45), Color("111618"))
			draw_rect(Rect2(x + 7, y + 105, 20, 45), Color("111618"))
			if visitor == "stalker":
				draw_rect(Rect2(x - 27, y - 18, 54, 15), Color("070b0c"))
				if source == "현관 렌즈":
					draw_arc(Vector2(x + 36, y + 75), 7, 0.2, 4.4, 16, Color("aab8a9"), 3)
			else:
				draw_rect(Rect2(x - 20, y + 24, 8, 70), Color("d0cc9c"))
		if source == "현관 렌즈":
			for i in range(14):
				draw_rect(Rect2(0, i * 4, w, 2), Color(0, 0, 0, 0.28))
	for y in range(0, int(h), 4):
		draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(1, 1, w - 2, h - 2), Color("7c9588"), false, 2)
