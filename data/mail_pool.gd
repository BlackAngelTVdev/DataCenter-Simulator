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
