class_name MailPool
extends RefCounted
## ============================================================
##  APP MAIL (BianOS) — e-mails des clients
## ============================================================
##  Les clients écrivent : « mon site rame », « je veux un serveur
##  dédié », « bravo, +1 client premium ! »… Certains e-mails
##  contiennent une OFFRE DE CONTRAT : l'accepter signe un contrat
##  (revenus GARANTIS par mois, ajoutés au tick indépendamment des
##  serveurs). C'est l'ONG de la fidélisation.
##
##  Champs :
##    id         : identifiant unique de l'e-mail
##    from       : expéditeur
##    subject    : objet
##    body       : corps du message
##    unlock     : condition d'arrivée ("always" | "clients>=N")
##    contract   : optionnel — { "id", "name", "income_per_month" }
##
##  Pour ajouter un e-mail : copie-colle un bloc { ... } dans MAILS.

const MAILS := [
	{
		"id": "mail_welcome",
		"from": "BianOS",
		"subject": "Bienvenue sur BianOS Mail",
		"body": "Bonjour,\n\nTa boîte mail est prête. Les clients te contactent ici quand quelque chose cloche… ou quand ils sont contents.\n\n— BianOS",
		"unlock": "always",
	},
	{
		"id": "mail_rame",
		"from": "Sonia (cliente)",
		"subject": "Mon site rame",
		"body": "Salut,\n\nDepuis deux jours mon site met des plombes à charger. Mes visiteurs partent avant la fin.\n\nEst-ce que tu peux jeter un œil ? J'ai pas envie de changer d'hébergeur…\n\n— Sonia",
		"unlock": "clients>=2",
	},
	{
		"id": "mail_dedie",
		"from": "Karim (développeur)",
		"subject": "Je veux un serveur dédié",
		"body": "Bonjour,\n\nJ'en ai marre des mutualisés. Je cherche une machine dédiée, toute à moi, pour mes projets clients.\n\nSi tu montes une offre dédiée, je suis preneur. On peut signer un contrat mensuel si ça te va.\n\n— Karim",
		"unlock": "clients>=4",
		"contract": {
			"id": "contract_dedie",
			"name": "Contrat serveur dédié",
			"income_per_month": 60,
		},
	},
	{
		"id": "mail_premium",
		"from": "Agence Pixel",
		"subject": "Bravo, +1 client premium !",
		"body": "Hello,\n\nOn te recommande à nos clients pro. On a envoyé un gars exigeant chez toi : il paiera bien, mais il veut de la qualité.\n\nContinue comme ça !\n\n— Agence Pixel",
		"unlock": "clients>=6",
	},
	{
		"id": "mail_entreprise",
		"from": "NovaCorp IT",
		"subject": "Besoin d'un vrai local",
		"body": "Bonjour,\n\nOn externalise notre infra. On cherche un hébergeur sérieux, avec un vrai local climatisé, pas un garage.\n\nSi tu passes au niveau supérieur, on signe un gros contrat mensuel.\n\n— NovaCorp IT",
		"unlock": "clients>=12",
		"contract": {
			"id": "contract_entreprise",
			"name": "Contrat NovaCorp",
			"income_per_month": 250,
		},
	},
	{
		"id": "mail_reco",
		"from": "M. Dupont (client fidèle)",
		"subject": "Vous êtes recommandé !",
		"body": "Bonjour,\n\nMon site tourne nickel chez vous. J'ai parlé de toi à deux copains entrepreneurs : ils devraient arriver dans les prochains jours.\n\nMerci !\n\n— Dupont",
		"unlock": "clients>=20",
	},
]


static func is_unlocked(mail: Dictionary) -> bool:
	## L'e-mail est-il arrivé dans la boîte ? ("always" ou à partir de N clients)
	var unlock := str(mail.get("unlock", "always"))
	if unlock == "always":
		return true
	if unlock.begins_with("clients>="):
		var n := int(unlock.get_slice(">=", 1))
		return GameManager.total_clients >= n
	return true


static func all_unlocked() -> Array:
	## TOUS les e-mails dont la condition est remplie (lus ou non) : la boîte
	## conserve les messages — une offre de contrat vue mais pas signée reste
	## signable plus tard.
	var out := []
	for m in MAILS:
		if is_unlocked(m):
			out.append(m)
	return out


static func available() -> Array:
	## Les e-mails NON ENCORE VUS (condition remplie) : sert au badge
	## « nouveaux » éventuel. La liste de la boîte, elle, utilise all_unlocked.
	var out := []
	for m in MAILS:
		if is_unlocked(m) and not GameManager.mails_seen.has(str(m["id"])):
			out.append(m)
	return out


static func contract_for(mail: Dictionary) -> Dictionary:
	return (mail as Dictionary).get("contract", {})


## ------------------------------------------------------------
##  E-MAILS ALÉATOIRES (pub / offres / newsletters / spam)
## ------------------------------------------------------------
##  Ces e-mails n'ont PAS de condition d'arrivée : ils tombent dans la boîte
##  de façon aléatoire au fil de la partie (garage_scene planifie leur
##  arrivée). Contrairement aux e-mails de clients, ils n'ont pas de contrat
##  et peuvent revenir (chaque instance reçoit un id unique).

const RANDOM_MAILS := [
	{
		"from": "Tech'Occase",
		"subject": "Promo de la semaine : -20 % sur les climatiseurs",
		"body": "Salut !\n\nCette semaine, le Brise-Fraîche à 40 $ au lieu de 50 $.\nTon local te remerciera quand la température grimpera…\n\n— L'équipe Tech'Occase",
	},
	{
		"from": "Tech'Occase",
		"subject": "Un serveur reconditionné à -35 %",
		"body": "Le Panda Pro 1U (8 slots, 100 W) est à 62 $ cette semaine !\nStock limité, comme toujours.\n\n— L'équipe Tech'Occase",
	},
	{
		"from": "Renard Web",
		"subject": "Votre navigateur a été mis à jour",
		"body": "Renard Web 12.4 est arrivé : navigation plus rapide, zéro bug (promis).\nLes cookies de votre session ont été conservés.\n\n— L'équipe Renard",
	},
	{
		"from": "BianOS",
		"subject": "Mise à jour du système",
		"body": "BianOS 3.2.1 corrige une fuite de mémoire dans l'app Mail.\nPensez à éteindre le PC pour appliquer la mise à jour.\n\n— L'équipe BianOS",
	},
	{
		"from": "FibreMax",
		"subject": "Passez à la fibre 1G pour 19 $/mois",
		"body": "Bonjour,\n\nVotre connexion actuelle fait le job, mais imaginez 400 clients en simultané…\nDécouvrez notre offre fibre 1G dans la boutique en ligne.\n\n— FibreMax",
	},
	{
		"from": "Garage-Brocante",
		"subject": "Armoires d'occasion : stock frais",
		"body": "Deux racks 12U viennent d'arriver à l'entrepôt.\nPlacez vos serveurs dans des armoires, c'est plus propre et ça double la capacité !\n\n— Garage-Brocante",
	},
	{
		"from": "Mr. Norton",
		"subject": "Votre pare-feu est-il suffisant ?",
		"body": "Bonjour, ici Mr. Norton de la sécurité réseau.\nLes attaques DDoS se multiplient. Un pare-feu Forteresse protège jusqu'à 300 clients.\nNe soyez pas la prochaine victime.\n\n— Norton Sécurité",
	},
	{
		"from": "Petit Félin",
		"subject": "Nouvelle gamme de croquettes premium",
		"body": "Votre chat (oui, on sait) mérite le meilleur.\nNourriture pour chat en vente chez Tech'Occase : 5 $ le sachet.\nLe chat du quartier appréciera.\n\n— Petit Félin",
	},
	{
		"from": "Inconnu",
		"subject": "VOTRE PRIME VOUS ATTEND",
		"body": "FÉLICITATIONS ! Vous êtes le 1 000 000e visiteur de notre site !\nCliquez sur ce lien pour récupérer votre prime de 10 000 $.\n(NB : ceci est un spam. Supprimez cet e-mail.)\n\n— Totalement pas un arnaqueur",
	},
	{
		"from": "Agence Immobilia",
		"subject": "Votre garage mérite mieux",
		"body": "Cher entrepreneur, un garage c'est bien. Un vrai Data Hall climatisé c'est mieux !\nPassez au Local 2 : 4 slots d'armoires, établi double baie, gestion réseau avancée.\n\n— Agence Immobilia",
	},
	{
		"from": "Énergie Verte",
		"subject": "Astuce électricité du mois",
		"body": "Saviez-vous que chaque watt compte ?\nÉteignez les serveurs inutiles et surveillez votre facture d'électricité sur le bureau.\n\n— Énergie Verte",
	},
	{
		"from": "Le Journal de l'Infra",
		"subject": "Comment refroidir un local sans clim ?",
		"body": "Spoiler : on ne peut pas. Au-delà de 50 °C, vos serveurs s'arrêtent.\nInstallez des climatiseurs avant qu'il ne soit trop tard.\n\n— Le Journal de l'Infra",
	},
]


static func random_mail() -> Dictionary:
	## Un e-mail aléatoire (pub / offre / newsletter / spam) avec un id UNIQUE :
	## chaque instance est distincte et peut réapparaître plus tard.
	if RANDOM_MAILS.is_empty():
		return {}
	var m: Dictionary = RANDOM_MAILS[randi() % RANDOM_MAILS.size()].duplicate(true)
	m["id"] = "rand_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	return m
