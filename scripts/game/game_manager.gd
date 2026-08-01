extends Node
## État global de la partie (autoload, voir project.godot).
## PAS de class_name : le nom d'autoload « GameManager » est déjà le point
## d'accès global — un class_name identique entrerait en conflit à la
## résolution statique.

const START_CASH := 300.0
const DEFAULT_ABO := "abo_1g"

## Seuil d'arrêt : au-delà, tous les serveurs s'éteignent (plus de revenus).
const CRITICAL_TEMP := 50.0
const TEMP_AMBIANT := 20.0

## Capacité du PARE-FEU Forteresse (clients protégés simultanément). Au DATA
## HALL (local 2), au-delà de cette capacité le pare-feu sature : une partie
## des clients n'est plus protégée pendant une attaque DDoS. Au garage, le
## pare-feu protège sans limite (gestion chill).
const FIREWALL_CAPACITY := 300

## Facteur de conversion chaleur/refroidissement : °C par seconde.
## Source unique : l'affichage (shop, monitor, factures) l'utilise aussi.
const HEAT_PER_SEC := 0.02

## Tarifs (factures) — électricité en $ par watt et par seconde.
const ELECTRIC_RATE := 0.00002  # 20 kW pour 1000 W ≈ 0.72 $/h
const SECONDS_PER_MONTH := 30.0 * 24.0 * 3600.0

var cash := START_CASH
var temperature := TEMP_AMBIANT
var abo_id := DEFAULT_ABO
var firewall_owned := false

## --- Incidents réseau (DDoS / coupures de courant) ---
## Événements transitoires gérés au tick par le garage : jamais sauvegardés.
## Le pare-feu bloque les DDoS ; les armoires avec onduleur (UPS) survivent
## aux coupures.
var ddos_active := false
var ddos_ticks_left := 0
var ddos_cooldown := 0
var outage_active := false
var outage_ticks_left := 0
var outage_cooldown := 0

## Refroidissement total des clims du local courant (recalculé au tick).
var cooling_total := 0.0

## Vrai quand la température dépasse CRITICAL_TEMP : serveurs à l'arrêt.
var overheated := false

## Achats UNIQUES déjà faits (id d'item : true) : abonnements achetés,
## pare-feu, locaux… On ne peut pas les racheter (boutique logique).
## Sauvegardé dans game_save.gd.
var owned := {}

## Consommation électrique totale (watts) des serveurs, recalculée au tick.
var total_watts := 0

## Nombre max d'armoires posables dans le garage (augmenté en achetant
## un « local » sur Tech'Occase — voir data/shop_catalog.gd).
var rack_limit := 3

## Nombre max de climatiseurs par local (l'électricité a des limites !).
var clim_limit := 6

## Local actuel : 0 = garage DC-1, 1 = Local 2 « Data Hall ».
var location := 0

## Le « Local 2 — Data Hall » a-t-il été acheté ? (débloque la destination en voiture)
var location_unlocked := false

## Limite d'armoires du Data Hall (local 2) : armoires obligatoires là-bas.
var rack_limit_2 := 6

## Position sauvegardée du joueur par local (téléportation + sauvegarde).
var player_pos: Dictionary = {0: Vector2.ZERO, 1: Vector2.ZERO}

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

## Travail en cours sur l'établi du GARAGE (installation d'OS ou réparation) :
## {mode: "install"/"repair", os_id, seconds_left, item_id}. Traité au tick
## par le garage (les deux locaux partagent le script) : le travail continue
## TOUT SEUL en arrière-plan, même si on change de local — le joueur peut
## vaquer à ses occupations, l'établi reste occupé (slot bloqué) pendant ce
## temps. Sauvegardé dans game_save.gd.
var bench_job := {}

## Durées du travail à l'établi du garage.
const BENCH_INSTALL_SECONDS := 2.0
const BENCH_REPAIR_SECONDS := 120.0

## Le chat : la gamelle a-t-elle reçu de la nourriture ? Le chat est-il
## adopté (habitué du garage, il ne repart plus) ?
var cat_fed := false
var cat_adopted := false
## Nombre total de caresses données au chat (succès « 50 000 caresses »).
var cat_pets := 0

## Contrats clients signés via l'app Mail : {contract_id: {"name":…, "income_per_month":…}}.
## Revenus GARANTIS par mois (ajoutés au tick, indépendamment des serveurs).
var contracts := {}

## E-mails déjà reçus dans l'app Mail (id -> true) : ils ne réapparaissent pas.
var mails_seen := {}

## E-mails ALÉATOIRES (pub / offres / newsletters) reçus dans l'app Mail :
## chaque instance porte un id unique (rand_<ts>_<n>) et reste dans la boîte
## (persisté dans la sauvegarde). Les e-mails de clients, eux, restent dans
## le pool statique MailPool.MAILS et sont dédupliqués via mails_seen.
var received_mails: Array = []

## E-mails SUPPRIMÉS dans l'app Mail (id -> true) : ils ne réapparaissent
## plus (ni les e-mails de clients du pool statique, ni les e-mails
## aléatoires reçus). Persisté dans la sauvegarde.
var deleted_mails := {}

## Centre de NOTIFICATIONS (cloche du HUD, en haut à gauche) : liste de
## {text, read}. Les notifications vivent dans GameManager pour SURVIVRE aux
## téléportations entre locaux (le HUD est recréé à chaque scène). Non
## sauvegardées sur disque (transitoires de session).
var notifications: Array = []

## Statistiques recalculées par le garage à chaque tick (affichage HUD).
var total_clients := 0
var income_per_sec := 0.0
var heat_total := 0.0
var online_servers := 0
## Bande passante SUPPLÉMENTAIRE apportée par les reverse proxies EN LIGNE
## du local courant (recalculé au tick par le garage). S'ajoute à la limite
## de clients de l'abonnement : c'est comme ça qu'on dépasse 400 clients.
var proxy_boost := 0

## --- Succès / trophées ---
## Succès débloqués (id -> true). Consultables dans le panneau Succès du PC.
var achievements := {}
## Serveurs posés/montés au total (compteur du succès « Premier serveur »).
var servers_placed_total := 0
## Nombre total de chats vus (visites du chat du quartier, succès « Vu 5 chats »).
var cats_seen := 0
## Une attaque DDoS a-t-elle déjà été subie (succès « Vainqueur d'un DDoS ») ?
var ddos_survived := false

## --- Contrats d'entreprise ---
## Contrats signés (id -> true) via la page « Contrats » du navigateur Renard :
## revenus GARANTIS par mois SI les exigences sont remplies (serveurs dédiés,
## clims, armoires…), sinon pénalité. Voir data/enterprise_contracts.gd.
var enterprise_contracts := {}


func reset() -> void:
	## Nouvelle partie : on repart de zéro.
	cash = START_CASH
	temperature = TEMP_AMBIANT
	abo_id = DEFAULT_ABO
	firewall_owned = false
	ddos_active = false
	ddos_ticks_left = 0
	ddos_cooldown = 0
	outage_active = false
	outage_ticks_left = 0
	outage_cooldown = 0
	cooling_total = 0.0
	overheated = false
	owned = {DEFAULT_ABO: true}  # l'abo de base est déjà « possédé »
	rack_limit = 3
	clim_limit = 6
	location = 0
	location_unlocked = false
	rack_limit_2 = 6
	player_pos = {0: Vector2.ZERO, 1: Vector2.ZERO}
	carried = {}
	worlds = {0: {}, 1: {}}
	pending_teleport = -1
	deliveries.clear()
	bench_job = {}
	cat_fed = false
	cat_adopted = false
	cat_pets = 0
	contracts = {}
	mails_seen = {}
	received_mails = []
	deleted_mails = {}
	notifications = []
	total_clients = 0
	income_per_sec = 0.0
	heat_total = 0.0
	online_servers = 0
	total_watts = 0
	proxy_boost = 0
	achievements = {}
	servers_placed_total = 0
	cats_seen = 0
	ddos_survived = false
	enterprise_contracts = {}


func electric_cost_per_sec() -> float:
	## Facture d'électricité : watts consommés × tarif.
	return total_watts * ELECTRIC_RATE


func abo_fee_per_sec() -> float:
	## Mensualité de l'abonnement internet, ramenée par seconde.
	return float(ShopCatalog.get_abo(abo_id).get("fee", 0)) / SECONDS_PER_MONTH


func owns(id: String) -> bool:
	## L'item (abo, pare-feu, local…) a-t-il déjà été acheté ?
	return owned.has(id)


func mark_owned(id: String) -> void:
	## Marque un achat unique comme fait (ne pourra plus être racheté).
	owned[id] = true


func contract_income_per_sec() -> float:
	## Revenus garantis des contrats clients, ramenés par seconde.
	var total := 0.0
	for cid in contracts:
		total += float(contracts[cid].get("income_per_month", 0))
	return total / SECONDS_PER_MONTH


func accept_contract(cid: String, name: String, income_per_month: int) -> void:
	## Signe un contrat (app Mail) : revenus garantis par mois.
	contracts[cid] = {"name": name, "income_per_month": income_per_month}


func add_notification(text: String) -> void:
	## Ajoute une notification au centre de notifications (cloche du HUD).
	## Déduplication : un message identique au précédent ne repart pas deux
	## fois de suite (anti-spam des toasts répétés). La liste est plafonnée
	## à 30 entrées (les plus anciennes sortent).
	if not notifications.is_empty() and str(notifications.back().get("text", "")) == text:
		return
	notifications.append({"text": text, "read": false})
	while notifications.size() > 30:
		notifications.pop_front()


func receive_random_mail() -> void:
	## Un e-mail aléatoire (pub / offre / newsletter) tombe dans la boîte Mail.
	## Chaque instance a un id unique : rien n'est dédupliqué (contrairement
	## aux e-mails de clients) — la boîte se remplit au fil de la partie.
	var mail := MailPool.random_mail()
	if mail.is_empty():
		return  # pool vide : rien à recevoir (jamais en pratique)
	received_mails.append(mail)


func bandwidth_limit() -> int:
	## Nombre max de clients en ligne simultanément (selon l'abonnement).
	## Les REVERSE PROXIES en ligne (proxy_boost, recalculé au tick par le
	## garage) ajoutent de la bande passante PAR-DESSUS : c'est le moyen de
	## dépasser la limite de l'abonnement dans le Data Hall. Le pare-feu,
	## lui, n'augmente PAS les revenus : il bloque les attaques DDoS.
	return int(ShopCatalog.get_abo(abo_id).get("clients", 8)) + proxy_boost


func server_stopped(s: ServerUnit) -> bool:
	## Source unique de la règle « serveur arrêté » : surchauffe (tous éteints),
	## DDoS sans pare-feu (tous hors ligne), coupure de courant (seuls les
	## serveurs montés sur armoire avec onduleur UPS survivent) OU serveur
	## monté dans une armoire SANS SWITCH réseau (rien n'est branché : aucun
	## revenu). Utilisée par le garage (revenus), l'affichage des serveurs et
	## le Monitor — un seul endroit à modifier si la règle évolue.
	if not s.configured():
		return false
	if s.rack != null and not s.rack.has_switch():
		return true
	# DATA HALL : gestion réseau COMPLEXE — le switch a des PORTS limités, les
	# derniers serveurs montés au-delà de la capacité ne sont pas branchés.
	# Au GARAGE, pas de limite de ports (chill) : le switch suffit.
	if location == 1 and s.rack != null and s.rack.port_exhausted_for(s):
		return true
	if overheated:
		return true
	if ddos_active and not firewall_owned:
		return true
	if outage_active and (s.rack == null or not s.rack.has_battery()):
		return true
	return false
