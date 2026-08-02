class_name WindowDrag
extends RefCounted

# Rendre une fenêtre du faux OS (BianOS) DÉPLAÇABLE comme sur un vrai PC
var _win: Control
var _dragging := false
var _drag_offset := Vector2.ZERO
var _focus_cb: Callable  # optionnel : à appeler au clic (passer au premier plan)


static func attach(win: Control, title_bar: Control, focus_cb: Callable = Callable()) -> WindowDrag:
	var d := WindowDrag.new()
	d._win = win
	d._focus_cb = focus_cb
	# Press/relâche : uniquement sur la BARRE DE TITRE (un clic sur le corps de
	# la fenêtre ne démarre PAS un drag).
	title_bar.gui_input.connect(d._on_title_bar_input)
	# Motion : sur TOUTE la fenêtre AUSSI. En Godot, les événements de souris
	# sont livrés au contrôle SOUS le curseur (pas de capture implicite) : si
	# on écoutait le motion uniquement sur la barre, un drag rapide qui fait
	# sortir le curseur de la barre (30-34 px de haut) figerait la fenêtre.
	win.gui_input.connect(d._on_win_input)
	# Curseur « main » sur la barre de titre : le joueur comprend qu'il peut
	# saisir et déplacer la fenêtre.
	title_bar.mouse_default_cursor_shape = Control.CURSOR_DRAG
	return d


func _on_win_input(event: InputEvent) -> void:
	## Motion pendant un drag, capté où que soit le curseur dans la fenêtre
	## (le corps suit la barre de titre). Le RELÂCHEMENT aussi : en Godot le
	## clic de relâchement est livré au contrôle SOUS le curseur — si on le
	## relâchait sur le corps (drag rapide), la barre ne le verrait jamais et
	## _dragging resterait bloqué (la fenêtre « collerait » à la souris).
	if event is InputEventMouseMotion and _dragging:
		_drag_step()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_dragging = false


func _on_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = _win.get_global_mouse_position() - _win.global_position
			# Au clic, la fenêtre passe AU PREMIER PLAN (comme un vrai OS).
			if _focus_cb.is_valid():
				_focus_cb.call()
			else:
				_win.move_to_front()
		else:
			_dragging = false
		_win.get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_drag_step()


func _drag_step() -> void:
	## Une étape de déplacement pendant le drag, appelée où que soit le curseur
	## (barre de titre ou corps de la fenêtre). Garde défensive : si le
	## relâchement a eu lieu HORS de la fenêtre (aucun handler ne l'a vu), le
	## bouton n'est plus enfoncé — on débloque sans bouger (la fenêtre ne
	## « colle » jamais à la souris sans bouton appuyé).
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_dragging = false
		return
	var pos := (_win.get_global_mouse_position() - _drag_offset).floor()
	# Garde-fou : on garde au moins une partie de la fenêtre visible.
	var vp := _win.get_viewport_rect().size
	var min_keep := Vector2(80.0, 28.0)  # une tranche de la barre de titre au moins
	pos.x = clampf(pos.x, -_win.size.x + min_keep.x, vp.x - min_keep.x)
	pos.y = clampf(pos.y, 0.0, vp.y - min_keep.y)
	_win.global_position = pos
	_win.get_viewport().set_input_as_handled()
