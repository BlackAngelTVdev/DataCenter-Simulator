class_name BakedAssets
## Charge les IMAGES cuites (assets/images/baked/) — le jeu n'a plus aucun
## dessin procédural : tout est rendu hors-écran une fois par le bake tool
## (tools/bake_assets.tscn) puis chargé comme Sprite2D / StyleBoxTexture.
## _cache évite de recharger les textures à chaque instance.

const DIR := "res://assets/images/baked/"

static var _cache := {}


## Sous-dossier de chaque image selon sa catégorie (tri des assets) :
## serveurs, racks, clims, interactables, réseaux, UI, OS, mondes…
## Le nom peut arriver avec ou sans l'extension ".png".
static func subdir_for(name: String) -> String:
	var base := name.get_basename() if name.ends_with(".png") else name
	if base.begins_with("server_"):
		return "servers/"
	if base.begins_with("rack_") or base == "battery_strip":
		return "racks/"
	if base == "switch_strip":
		return "switches/"
	if base.begins_with("clim_"):
		return "clims/"
	if base.begins_with("decor_"):
		return "decor/"
	if base.begins_with("switch_") or base == "switch_strip":
		return "switches/"
	if base.begins_with("bg_"):
		return "worlds/"
	if base.begins_with("wallpaper_") or base.begins_with("icon_"):
		return "os/"
	if base.begins_with("led_") or base in ["cable_seg", "cable_glow", "bubble_sature"]:
		return "network/"
	if base in ["bench_garage", "bench_pro", "computer", "delivery", "car", "desk", "storage", "crate", "parcel"]:
		return "interactables/"
	if base == "player":
		return "player/"
	if base in ["bar_bg", "bar_fill", "knob"]:
		return "ui/"
	return "misc/"


static func path_for(name: String) -> String:
	## Chemin res:// complet d'une texture (nom sans extension).
	return DIR + subdir_for(name) + name + ".png"


static func tex(name: String) -> Texture2D:
	## Texture cuite par nom de fichier (sans l'extension).
	if not _cache.has(name):
		var t: Texture2D = load(path_for(name))
		if t == null:
			push_warning("BakedAssets : texture introuvable -> " + name)
			t = _blank()
		_cache[name] = t
	return _cache[name]


static func _blank() -> Texture2D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.2, 0.9))
	return ImageTexture.create_from_image(img)


static func server_tex(item: Dictionary) -> Texture2D:
	var t := tex("server_" + str(item.get("id", "")))
	return t if t != null else tex("block")


static func rack_tex(item: Dictionary) -> Texture2D:
	var t := tex("rack_" + str(item.get("id", "")))
	return t if t != null else tex("block")


static func clim_tex(item: Dictionary) -> Texture2D:
	var t := tex("clim_" + str(item.get("id", "")))
	return t if t != null else tex("block")


static func decor_tex(item: Dictionary) -> Texture2D:
	var t := tex("decor_" + str(item.get("id", "")))
	return t if t != null else tex("block")


static func item_tex(item: Dictionary) -> Texture2D:
	## Petite icône « objet » (colis / contenu d'emplacement) pour un item.
	var kind := str(item.get("kind", ""))
	match kind:
		"server":
			return tex("server_" + str(item.get("id", "")))
		"furniture":
			return tex("rack_" + str(item.get("id", "")))
		"clim":
			return tex("clim_" + str(item.get("id", "")))
		"decor":
			return tex("decor_" + str(item.get("id", "")))
		"switch":
			return tex("switch_" + str(item.get("id", "")))
	return tex("block")
