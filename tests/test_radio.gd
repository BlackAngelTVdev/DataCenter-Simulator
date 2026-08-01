extends Node
## Test de la radio du garage — exécuté comme SCÈNE (garage = racine,
## Test = enfant). Vérifie que la radio charge les sons du dossier
## assets/radio-garage/ et s'allume/s'éteint avec le bouton E.

func _ready() -> void:
	await get_tree().process_frame
	var garage := get_parent() as GarageScene
	if garage == null or garage.radio_unit == null:
		print("TEST_RESULT=FAIL (pas de radio dans le garage)")
		get_tree().quit(1)
		return
	var radio := garage.radio_unit

	# 1. La radio a chargé les sons du dossier (au moins 1 piste).
	var track_count := radio._tracks.size()
	print("TEST track_count=", track_count)
	var load_ok: bool = track_count >= 1

	# 2. Toggle : allume (on = true) puis éteint (on = false).
	radio.toggle()
	var on1 := radio.on
	radio.toggle()
	var off1 := radio.on
	print("TEST on_after_toggle=", on1, " off_after_toggle=", off1)
	var toggle_ok: bool = on1 and not off1

	var ok: bool = load_ok and toggle_ok
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
