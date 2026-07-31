extends Node
## État global de la partie (autoload, voir project.godot).
## PAS de class_name : le nom d'autoload « GameManager » est déjà le point
## d'accès global — un class_name identique entrerait en conflit à la
## résolution statique.

const START_CASH := 300.0
const DEFAULT_ABO := "abo_1g"

## Tarifs (factures) — électricité en $ par watt et par seconde.
const ELECTRIC_RATE := 0.00002  # 20 kW pour 1000 W ≈ 0.72 $/h
const SECONDS_PER_MONTH := 30.0 * 24.0 * 3600.0

var cash := START_CASH
var temperature := 20.0
var abo_id := DEFAULT_ABO
var firewall_owned := false

## Consommation électrique totale (watts) des serveurs, recalculée au tick.
var total_watts := 0

## Nombre max d'armoires posables dans le garage (augmenté en achetant
## un « local » sur Tech'Occase — voir data/shop_catalog.gd).
var rack_limit := 3

## Local actuel : 0 = garage DC-1, 1 = Local 2 « Data Hall ».
var location := 0

## Le « Local 2 — Data Hall » a-t-il été acheté ? (débloque la destination en voiture)
var location_unlocked := false

## Limite d'armoires du Data Hall (local 2) : armoires obligatoires là-bas.
var rack_limit_2 := 6

## Position sauvegardée du joueur par local (téléportation + sauvegarde).
var player_pos: Dictionary = {0: Vector2.ZERO, 1: Vector2.ZERO}

## Timestamp de la dernière téléportation (revenus « pendant l'absence »).
## Jamais sauvegardé : ne sert que pour le rattrapage au changement de scène.
var last_switch_ts := 0.0

## Objet dans les mains du joueur (état GLOBAL — il voyage avec lui en
## voiture, contrairement au monde placé qui est par local).
var carried: Dictionary = {}

## Mondes PLACÉS par local (jamais écrits sur disque directement) : chaque
## local a SON propre monde {racks, servers, bench, storage}. C'est ce qui
## fait que le garage et le Data Hall sont DEUX endroits distincts.
## {0: garage DC-1, 1: Local 2 « Data Hall »}.
var worlds: Dictionary = {0: {}, 1: {}}

## Destination d'une téléportation en cours (-1 = aucune).
var pending_teleport := -1

## Colis achetés sur Tech'Occase, en attente de ramassage à la livraison.
var deliveries: Array = []

## Statistiques recalculées par le garage à chaque tick (affichage HUD).
var total_clients := 0
var income_per_sec := 0.0
var heat_total := 0.0
var online_servers := 0


func reset() -> void:
	## Nouvelle partie : on repart de zéro.
	cash = START_CASH
	temperature = 20.0
	abo_id = DEFAULT_ABO
	firewall_owned = false
	rack_limit = 3
	location = 0
	location_unlocked = false
	rack_limit_2 = 6
	player_pos = {0: Vector2.ZERO, 1: Vector2.ZERO}
	last_switch_ts = 0.0
	carried = {}
	worlds = {0: {}, 1: {}}
	pending_teleport = -1
	deliveries.clear()
	total_clients = 0
	income_per_sec = 0.0
	heat_total = 0.0
	online_servers = 0
	total_watts = 0


func electric_cost_per_sec() -> float:
	## Facture d'électricité : watts consommés × tarif.
	return total_watts * ELECTRIC_RATE


func abo_fee_per_sec() -> float:
	## Mensualité de l'abonnement internet, ramenée par seconde.
	return float(ShopCatalog.get_abo(abo_id).get("fee", 0)) / SECONDS_PER_MONTH


func bandwidth_limit() -> int:
	## Nombre max de clients en ligne simultanément (selon l'abonnement).
	return int(ShopCatalog.get_abo(abo_id).get("clients", 8))	# (Le pare-feu n'augmente PAS les revenus : il ne sert qu'à bloquer
	# les attaques réseau — une mécanique à venir.)
