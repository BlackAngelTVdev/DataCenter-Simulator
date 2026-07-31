class_name ShopCatalog
extends RefCounted
## ============================================================
##  CATALOGUE DE LA BOUTIQUE « Tech'Occase »
## ============================================================
##  C'est ICI qu'on ajoute facilement des machines au jeu !
##
##  ➜ Copie-colle un bloc { ... } dans la liste de ton choix,
##    change les valeurs, relance le jeu : la boutique en ligne
##    (navigateur « Renard ») se met à jour toute seule.
##
##  Champs communs :
##    id        : identifiant unique (sans espaces, ex: "server_faucon")
##    kind      : "server" | "furniture" | "upgrade" | "abo"  (ne pas toucher)
##    name      : nom affiché
##    desc      : description affichée dans la boutique
##    price     : prix en $
##    color     : couleur de l'icône / du colis
##
##  Pour les SERVEURS, en plus :
##    slots     : nombre max de clients hébergés
##    income    : $ gagnés par client et par seconde
##    watts     : consommation électrique (info)
##    heat      : chaleur produite (fait monter la température du garage)


# ------------------------------------------------------------------
#  SERVEURS — le cœur du business. Plus ils sont chers, plus ils
#  hébergent de clients et rapportent.
# ------------------------------------------------------------------
const SERVERS := [
	{
		"id": "server_panda",
		"kind": "server",
		"name": "Serveur Panda Occaz",
		"desc": "Une vieille tour d'entreprise reconditionnée. Parfaite pour commencer.",
		"specs": "Xeon E5-2620 · 32 Go RAM",
		"price": 100,
		"color": Color(0.38, 0.55, 0.85),
		"slots": 4,
		"income": 0.5,
		"watts": 150,
		"heat": 1.0,
	},
	{
		"id": "server_lynx",
		"kind": "server",
		"name": "Serveur Lynx Rack 1U",
		"desc": "Un 1U compact et silencieux, idéal en armoire.",
		"specs": "Xeon E5-2680 · 64 Go RAM",
		"price": 350,
		"color": Color(0.45, 0.75, 0.55),
		"slots": 8,
		"income": 0.6,
		"watts": 260,
		"heat": 2.0,
	},
	{
		"id": "server_mammoth",
		"kind": "server",
		"name": "Serveur Mammouth Blade",
		"desc": "Une lame ultra-dense. Attention à la chauffe !",
		"specs": "2× Xeon Gold · 128 Go RAM",
		"price": 950,
		"color": Color(0.8, 0.55, 0.3),
		"slots": 16,
		"income": 0.7,
		"watts": 500,
		"heat": 4.0,
	},
]


# ------------------------------------------------------------------
#  MOBILIER — à poser directement au sol, sans OS.
#  Exemple : l'armoire fait héberger 2x plus de clients aux serveurs.
# ------------------------------------------------------------------
const FURNITURE := [
	{
		"id": "rack_armoire",
		"kind": "furniture",
		"name": "Armoire 19\" (rack)",
		"desc": "Accueille 2 serveurs : chacun héberge le DOUBLE de clients.",
		"price": 250,
		"color": Color(0.5, 0.55, 0.65),
	},
	{
		"id": "rack_armoire_pro",
		"kind": "furniture",
		"name": "Armoire Pro Data 19\"",
		"desc": "Armoire pro : 4 serveurs + 1 slot batterie (onduleur). Chaque serveur héberge le DOUBLE de clients.",
		"price": 800,
		"color": Color(0.35, 0.6, 0.85),
		"slots": 4,
		"battery_slot": true,
	},
]


# ------------------------------------------------------------------
#  BATTERIES / ONDULEURS — se montent dans le slot batterie d'une armoire
#  Pro. Un onduleur stabilise l'alimentation : -30% de chaleur pour les
#  serveurs de l'armoire.
# ------------------------------------------------------------------
const BATTERIES := [
	{
		"id": "batterie_ups",
		"kind": "battery",
		"name": "Batterie UPS Pro",
		"desc": "Onduleur 19\" : -30% de chaleur pour les serveurs de l'armoire. Se pose contre une armoire Pro.",
		"price": 400,
		"color": Color(0.35, 0.85, 0.5),
	},
]


# ------------------------------------------------------------------
#  CLIMATISEURS — à poser où on veut au sol. Chaque clim soustrait sa
#  puissance « cooling » à la chaleur des serveurs : au-delà de 50 °C,
#  les serveurs S'ARRÊTENT (plus de revenus !). Plus on a de serveurs,
#  plus il faut de clims (ou de meilleures clims).
# ------------------------------------------------------------------
const CLIMS := [
	{
		"id": "clim_ventilo",
		"kind": "clim",
		"name": "Climatiseur Ventilo",
		"desc": "Petit split d'appoint : refroidit un peu. Idéal pour débuter.",
		"price": 150,
		"cooling": 2.0,
		"watts": 60,
		"color": Color(0.7, 0.85, 0.95),
	},
	{
		"id": "clim_split",
		"kind": "clim",
		"name": "Climatiseur Split 9000 BTU",
		"desc": "Le standard du garage : fait redescendre une grosse chauffe.",
		"price": 400,
		"cooling": 6.0,
		"watts": 180,
		"color": Color(0.45, 0.72, 0.95),
	},
	{
		"id": "clim_industriel",
		"kind": "clim",
		"name": "Centrale de froid industriel",
		"desc": "Puissance data center : gère une salle entière d'armoires.",
		"price": 1200,
		"cooling": 16.0,
		"watts": 480,
		"color": Color(0.2, 0.55, 0.9),
	},
]


# ------------------------------------------------------------------
#  LOCAUX — augmentent la limite d'armoires du garage. Le garage de
#  départ n'accepte que 3 armoires ; chaque local acheté en ajoute
#  (rack_bonus) de plus. Copie-colle un bloc pour de nouvelles tailles.
# ------------------------------------------------------------------
const LOCALS := [
	{
		"id": "local_voisin",
		"kind": "local",
		"name": "Local voisin (expansion)",
		"desc": "Loue le garage voisin : +3 emplacements d'armoires pour développer ton infra.",
		"price": 1200,
		"rack_bonus": 3,
		"color": Color(0.7, 0.6, 0.9),
	},
	{
		"id": "local_2",
		"kind": "local",
		"name": "Local 2 — Data Hall",
		"desc": "Un vrai second local : PC Pro, établi 2 baies (installations PARALLÈLES), armoires 4 slots. La voiture peut t'y emmener (dans la rue).",
		"price": 3000,
		"unlock_location": 1,
		"color": Color(0.3, 0.7, 0.9),
	},
]


# ------------------------------------------------------------------
#  AMÉLIORATIONS — s'appliquent immédiatement à l'achat.
#  Exemple : le pare-feu booste tous les revenus.
# ------------------------------------------------------------------
const UPGRADES := [
	{
		"id": "upgrade_firewall",
		"kind": "upgrade",
		"name": "Pare-feu Forteresse",
		"desc": "Pare-feu matériel : bloque les attaques réseau (DDoS). Anticipe — elles finiront par arriver…",
		"price": 150,
		"color": Color(0.85, 0.35, 0.35),
	},
]


# ------------------------------------------------------------------
#  ABONNEMENTS — limitent le nombre de clients en ligne EN MÊME TEMPS.
#  Quand la connexion sature, il faut en acheter un meilleur.
# ------------------------------------------------------------------
const ABOS := [
	{
		"id": "abo_1g",
		"kind": "abo",
		"name": "Fibre 1 Gbit/s (incluse)",
		"desc": "Jusqu'à 8 clients en ligne en même temps.",
		"price": 0,
		"fee": 0,
		"clients": 8,
		"color": Color(0.4, 0.7, 0.4),
	},
	{
		"id": "abo_10g",
		"kind": "abo",
		"name": "Fibre 10 Gbit/s",
		"desc": "Jusqu'à 30 clients en ligne en même temps.",
		"price": 150,
		"fee": 100,
		"clients": 30,
		"color": Color(0.4, 0.8, 0.65),
	},
	{
		"id": "abo_100g",
		"kind": "abo",
		"name": "Fibre 100 Gbit/s",
		"desc": "Jusqu'à 100 clients en ligne en même temps.",
		"price": 600,
		"fee": 300,
		"clients": 100,
		"color": Color(0.35, 0.85, 0.5),
	},
	{
		"id": "abo_400g",
		"kind": "abo",
		"name": "Ligne dédiée 400 Gbit/s",
		"desc": "Jusqu'à 400 clients. C'est du sérieux.",
		"price": 1800,
		"fee": 900,
		"clients": 400,
		"color": Color(0.3, 0.9, 0.45),
	},
]


# ------------------------------------------------------------------
#  Helper : tout le catalogue mélangé, pour la boutique en ligne.
# ------------------------------------------------------------------
static func shop_items() -> Array:
	var items := []
	items.append_array(SERVERS)
	items.append_array(FURNITURE)
	items.append_array(BATTERIES)
	items.append_array(CLIMS)
	items.append_array(LOCALS)
	items.append_array(UPGRADES)
	items.append_array(ABOS)
	return items


static func get_item(id: String) -> Dictionary:
	for item in shop_items():
		if item["id"] == id:
			return item.duplicate(true)
	return {}


static func get_abo(id: String) -> Dictionary:
	for abo in ABOS:
		if abo["id"] == id:
			return abo
	return ABOS[0]


static func abo_tier(id: String) -> int:
	## Rang de l'abonnement dans ABOS (0 = plus basique, croissant) — sert à
	## interdire le downgrade (on ne « rachète » pas un abo moins bon).
	for i in range(ABOS.size()):
		if ABOS[i]["id"] == id:
			return i
	return -1


## Prix de revente d'un objet du stock, en % du prix catalogue (Tech'Occase
## rachète le matériel qu'on a déposé sur l'étagère).
const RESALE_RATIO := 0.6


static func resale_value(item: Dictionary) -> int:
	## Valeur de revente d'un objet stocké (arrondie à l'unité). Un serveur
	## avec OS installé vaut un peu plus (l'OS reste dessus).
	var base := float(item.get("price", 0))
	var ratio := RESALE_RATIO
	if str(item.get("kind", "")) == "server" and item.has("os"):
		ratio += 0.1  # +10% si prêt à brancher (OS déjà installé)
	return maxi(1, int(round(base * ratio)))
