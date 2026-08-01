class_name HUD
extends CanvasLayer
## HUD minimal : invite d'interaction « E — … » (bas centre) et toasts
## (haut centre). Les panneaux de stats ont été retirés à la demande :
## rien ne recouvre la vue du garage. L'argent reste visible dans la
## boutique Tech'Occase et via les toasts.

var prompt_label: Label
var prompt_panel: PanelContainer
var toast_label: Label
var toast_timer: Timer


func _ready() -> void:
	_build()
	toast_label.visible = false
	prompt_panel.visible = false


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _build() -> void:
	# --- Invite d'interaction (bas centre) ---
	prompt_panel = PanelContainer.new()
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.offset_bottom = -40.0
	prompt_panel.offset_top = -86.0
	prompt_panel.offset_left = -230.0
	prompt_panel.offset_right = 230.0
	var prompt_style := UITheme.panel(10)
	prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	prompt_label = _label(18, Color(1.0, 1.0, 1.0, 0.95))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)
	add_child(prompt_panel)

	# --- Toasts (haut centre) ---
	toast_label = _label(16, Color(1.0, 1.0, 1.0, 0.95))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_label.offset_top = 128.0
	toast_label.offset_bottom = 168.0
	toast_label.add_theme_color_override("shadow_color", Color(0, 0, 0, 0.8))
	toast_label.add_theme_constant_override("shadow_offset_x", 2)
	toast_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(toast_label)

	toast_timer = Timer.new()
	toast_timer.wait_time = 3.0
	toast_timer.one_shot = true
	toast_timer.timeout.connect(_on_toast_timeout)
	add_child(toast_timer)


func _on_toast_timeout() -> void:
	# Garde anti-crash : toast_label ne doit plus être touché s'il a été
	# libéré (queue_free d'un parent) avant la fin du timer.
	if is_instance_valid(toast_label):
		toast_label.visible = false


func show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_panel.visible = true


func hide_prompt() -> void:
	prompt_panel.visible = false


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start()
