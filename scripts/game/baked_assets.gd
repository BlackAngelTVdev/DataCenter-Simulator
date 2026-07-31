class_name BakedAssets
## Charge les IMAGES cuites (assets/images/baked/) — le jeu n'a plus aucun
## dessin procédural : tout est rendu hors-écran une fois par le bake tool
## (tools/bake_assets.tscn) puis chargé comme Sprite2D / StyleBoxTexture.
## _cache évite de recharger les textures à chaque instance.

const DIR := "res://assets/images/baked/"

static var _cache := {}


static func tex(name: String) -> Texture2D:
	## Texture cuite par nom de fichier (sans l'extension).
	if not _cache.has(name):
		var t: Texture2D = load(DIR + name + ".png")
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


static func item_tex(item: Dictionary) -> Texture2D:
	## Petite icône « objet » (colis / contenu d'emplacement) pour un item.
	var kind := str(item.get("kind", ""))
	match kind:
		"server":
			return tex("server_" + str(item.get("id", "")))
		"furniture":
			return tex("rack_" + str(item.get("id", "")))
	return tex("block")
