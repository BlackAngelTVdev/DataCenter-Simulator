class_name LoadingScreen
extends CanvasLayer

# ÉCRAN DE CHARGEMENT — transitions entre les scènes
const LOAD_JOKES := [
	"Pourquoi les serveurs n'aiment pas l'hiver ? Parce qu'ils préfèrent le cloud.",
	"sudo rm -rf / : la commande qui règle tous tes problèmes… une seule fois.",
	"Il n'y a pas de bug, seulement des fonctionnalités non documentées.",
	"Un admin réseau dort la conscience tranquille : il fait des backups.",
	"Le cloud, c'est juste l'ordinateur de quelqu'un d'autre.",
	"Un ping, c'est un serveur qui dit « je suis là » en morse.",
	"Pourquoi les développeurs confondent Halloween et Noël ? Parce que OCT 31 == DEC 25.",
	"Un pare-feu, c'est comme un videur de boîte : il refuse les paquets mal habillés.",
	"Combien d'admins faut-il pour changer une ampoule ? Un, et deux pour déboguer le script.",
	"99 % de disponibilité, c'est bien… jusqu'à ce que tu sois dans les 1 %.",
	"« Ça marche sur ma machine » : le cri de guerre du développeur.",
	"Un serveur, c'est un peu comme un chat : si on le laisse tranquille, il ronronne.",
	"Proxmox, Debian, Ubuntu… des noms de distributions ou des Pokémons ?",
	"Un backup, c'est comme une assurance : on est content de l'avoir le jour du sinistre.",
	"Linux, c'est gratuit si ton temps n'a pas de valeur.",
	"Un administrateur système, c'est quelqu'un qui résout les problèmes que personne ne voit encore.",
	"Le pare-feu, c'est le videur du data center : il ne laisse entrer que les paquets attendus.",
	"« J'ai testé en prod, ça passe » — paroles de légende.",
	"Un rack sans switch, c'est une bibliothèque sans électricité.",
	"Le câble réseau est toujours trop court. C'est une loi de la physique.",
]

const BOOT_LINES := [
	"Initialisation du noyau…",
	"Montage des disques durs…",
	"Allocation de la mémoire vive…",
	"Chargement des modules…",
	"Configuration du réseau…",
	"Démarrage des services…",
	"Vérification de l'intégrité…",
	"Synchronisation des horloges…",
	"Négociation des paquets…",
	"Compilation des conteneurs…",
]

static var _path := ""
static var _title := "Chargement"

var _bg: ColorRect
var _status_label: Label
var _bar: ProgressBar
var _pct: Label
var _joke_label: Label
var _loaded := false
var _packed: PackedScene
var _elapsed := 0.0
var _shown := 0.0
var _min_time := 2.8
var _joke_timer := 0.0
var _status_timer := 0.0
var _joke_order: Array = []
var _joke_idx := 0
var _status_idx := 0


static func go_to(host: Node, scene_path: String, title := "Chargement") -> void:
	## Affiche l'écran de chargement puis charge la scène cible. Le node est
	## accroché à la scène COURANTE (passée par l'appelant) : il sera libéré
	## automatiquement par change_scene_to_packed quand elle sera remplacée.
	_path = scene_path
	_title = title
	var ls := LoadingScreen.new()
	ls.name = "LoadingScreen"
	host.add_child(ls)


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_min_time = randf_range(2.4, 3.4)
	_build()
	# Chargement RÉEL du fichier .tscn en arrière-plan (le thread remplit le
	# tableau de progression que _process interroge à chaque frame).
	ResourceLoader.load_threaded_request(_path, "", true)
	_joke_order = range(LOAD_JOKES.size())
	_joke_order.shuffle()
	_set_joke(0)
	_set_status(0)


func _input(_event: InputEvent) -> void:
	# Pendant le chargement, tout est avalé : pas de pause, pas de clic
	# parasite qui tomberait sur la scène en train de disparaître.
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_elapsed += delta

# Progression : réel (thread) plafonné à 95 % tant que le temps
	# minimum n'est pas écoulé (sinon la barre finirait avant la 1re blague).
	var real := 0.0
	if not _loaded:
		var prog: Array = []
		var status := ResourceLoader.load_threaded_get_status(_path, prog)
		if prog.size() > 0:
			real = clampf(float(prog[0]), 0.0, 1.0)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(_path)
			if res is PackedScene:
				_packed = res
			_loaded = true
	var pace := clampf(_elapsed / _min_time, 0.0, 1.0)
	var target := maxf(real, pace) * 0.98 if not _loaded else 1.0
	_shown = lerpf(_shown, target, delta * 5.0)
	_bar.value = _shown
	_pct.text = "%d %%" % roundi(_shown * 100.0)

# Statut et blague qui défilent.
	_status_timer += delta
	if _status_timer >= 0.7:
		_status_timer = 0.0
		_status_idx = (_status_idx + 1) % BOOT_LINES.size()
		_set_status(_status_idx)
	_joke_timer += delta
	if _joke_timer >= 1.8:
		_joke_timer = 0.0
		_joke_idx = (_joke_idx + 1) % _joke_order.size()
		_set_joke(_joke_idx)

# Fin : chargé + temps minimum écoulé + barre quasi pleine.
	if _loaded and _elapsed >= _min_time and _shown >= 0.99:
		_finish()
		return
# SECOURS anti-soft-lock : si le chargement threadé échoue (fichier
	# introuvable, ressource corrompue), on force quand même la transition
	# après le temps minimum + 5 s — l'écran ne doit JAMAIS rester bloqué.
	if not _loaded and _elapsed > _min_time + 5.0:
		_finish()


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.04, 0.07, 0.95)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(30.0))
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := Label.new()
	title.text = _title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	title.add_theme_color_override("shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vb.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55))
	vb.add_child(_status_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(520, 22)
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.06, 0.08, 0.12)
	track.set_corner_radius_all(11)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.25, 0.6, 0.45)
	fill.set_corner_radius_all(11)
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(_bar)

	_pct = Label.new()
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct.add_theme_font_size_override("font_size", 13)
	_pct.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vb.add_child(_pct)

	var sep := HSeparator.new()
	vb.add_child(sep)

	_joke_label = Label.new()
	_joke_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_joke_label.custom_minimum_size = Vector2(520, 0)
	_joke_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_joke_label.add_theme_font_size_override("font_size", 16)
	_joke_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.97))
	vb.add_child(_joke_label)


func _set_status(idx: int) -> void:
	if _status_label != null:
		_status_label.text = "> " + BOOT_LINES[idx]


func _set_joke(idx: int) -> void:
	if _joke_label != null:
		_joke_label.text = LOAD_JOKES[_joke_order[idx]]


func _finish() -> void:
	set_process(false)
	if _packed != null:
		get_tree().change_scene_to_packed(_packed)
	else:
		# Repli : chargement classique si le thread a échoué.
		get_tree().change_scene_to_file(_path)
	# Si le node avait été accroché à la racine (current_scene null au moment
	# du go_to), le libérer juste après le basculement de scène.
	if get_parent() == get_tree().root:
		queue_free.call_deferred()
