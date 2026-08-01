class_name ProxyList
extends RefCounted
## ============================================================
##  REVERSE PROXIES — logiciels installables à l'établi
## ============================================================
##  Un reverse proxy se pose SUR un serveur (comme un OS) : la machine ne
##  stocke plus de clients directement, mais elle FAIT PASSER plus de monde
##  sur le réseau du local courant (clients = bande passante en plus).
##  C'est LE moyen de dépasser la limite de l'abonnement (400 clients avec
##  la 400 Gbit/s) quand on tourne dans le Data Hall.
##
##  Champs :
##    id       : identifiant unique (ex: "proxy_nginx")
##    name     : nom affiché (fakes de nginx / HAProxy / Traefik)
##    desc     : description affichée dans l'UI
##    color    : couleur du logo
##    clients  : nombre de clients EN LIGNE EN PLUS quand le proxy tourne
##    heat     : chaleur produite par la machine qui exécute le proxy
##    price    : prix de la LICENCE (achat unique au shop Tech'Occase)
##
##  Copie-colle un bloc { ... } pour ajouter un nouveau proxy facilement.

const PROXIES := [
	{
		"id": "proxy_nginx",
		"name": "N'Ginx Community",
		"desc": "Reverse proxy de référence : +100 clients en ligne en même temps dans ce local.",
		"color": Color(0.25, 0.75, 0.9),
		"clients": 100,
		"heat": 0.5,
		"price": 250,
	},
	{
		"id": "proxy_haproxy",
		"name": "H'Proxy Edge",
		"desc": "Load balancer professionnel : +300 clients en ligne en même temps dans ce local.",
		"color": Color(0.45, 0.85, 0.55),
		"clients": 300,
		"heat": 0.8,
		"price": 700,
	},
	{
		"id": "proxy_traefik",
		"name": "Trafik Gate 9000",
		"desc": "Reverse proxy nouvelle génération : +700 clients en ligne en même temps dans ce local. Le must du Data Hall.",
		"color": Color(0.95, 0.55, 0.3),
		"clients": 700,
		"heat": 1.2,
		"price": 1800,
	},
]


static func get_proxy(id: String) -> Dictionary:
	## La fiche du proxy (vide si l'id ne correspond à aucun logiciel).
	for p in PROXIES:
		if p["id"] == id:
			return p
	return {}
