class_name ProxyList
extends RefCounted

# Reverse proxies installables à l'établi : la machine fait passer plus de
# monde sur le réseau (dépasse la limite de l'abonnement). Licence achat unique.
const PROXIES := [
	{
		"kind": "proxy",
		"id": "proxy_nginx",
		"name": "N'Ginx Community",
		"desc": "Reverse proxy de référence : +100 clients en ligne en même temps dans ce local.",
		"color": Color(0.25, 0.75, 0.9),
		"clients": 100,
		"heat": 0.5,
		"price": 250,
	},
	{
		"kind": "proxy",
		"id": "proxy_haproxy",
		"name": "H'Proxy Edge",
		"desc": "Load balancer professionnel : +300 clients en ligne en même temps dans ce local.",
		"color": Color(0.45, 0.85, 0.55),
		"clients": 300,
		"heat": 0.8,
		"price": 700,
	},
	{
		"kind": "proxy",
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
