class_name SettingsManager
## Réglages persistants (user://settings.json) : plein écran, résolution, volume.

const SETTINGS_PATH := "user://settings.json"

static var data := {
	"fullscreen": false,
	"resolution_index": 1,
	"volume": 80.0,
}


static func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var dict: Dictionary = parsed
	for key in data:
		if dict.has(key):
			var value: Variant = dict[key]
			# Garde de type : ignorer les valeurs corrompues du fichier JSON.
			match key:
				"fullscreen":
					if typeof(value) == TYPE_BOOL:
						data[key] = value
				"resolution_index":
					if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
						data[key] = int(value)
				"volume":
					if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
						data[key] = float(value)


static func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
