class_name ServerFactory
extends RefCounted
## ============================================================
##  SERVERFACTORY — configurateur de serveurs NEUFS (Data Hall)
## ============================================================
##  Le site « Neuf » du PC Pro ne vend PAS de machines pré-montées :
##  on choisit un CHÂSSIS, un CPU, de la RAM et des disques, et le
##  serveur (clients max, revenus/client, watts, chaleur) découle
##  de la config. L'achat produit un KIT livré à la livraison, à
##  assembler sur la TABLE D'ASSEMBLAGE (Data Hall) avant d'installer
##  un OS à l'établi.
##
##  Ajouter une option = copier-coller un bloc { ... } dans la liste.
##    id     : identifiant unique
##    name   : nom affiché
##    slots  : clients hébergés EN PLUS apportés par la pièce
##    watts  : consommation électrique EN PLUS (W)
##    heat   : chaleur produite EN PLUS
##    price  : coût de la pièce ($)
##    (cpu uniquement) income : $ par client et par seconde de base

const CHASSIS := [
	{
		"id": "ch_1u",
		"name": "Châssis 1U",
		"desc": "Compact et silencieux, pour commencer.",
		"slots": 2,
		"watts": 40,
		"heat": 0.5,
		"price": 450,
	},
	{
		"id": "ch_2u",
		"name": "Châssis 2U",
		"desc": "Le standard pro : place pour de gros composants.",
		"slots": 5,
		"watts": 80,
		"heat": 1.0,
		"price": 950,
	},
	{
		"id": "ch_4u",
		"name": "Châssis 4U tour",
		"desc": "Grosse bête : beaucoup de disques et de RAM.",
		"slots": 9,
		"watts": 140,
		"heat": 1.8,
		"price": 1800,
	},
]

const CPUS := [
	{
		"id": "cpu_quad",
		"name": "Quad-core 3.0 GHz",
		"desc": "Entrée de gamme, 4 cœurs.",
		"slots": 2,
		"income": 0.45,
		"watts": 60,
		"heat": 1.0,
		"price": 400,
	},
	{
		"id": "cpu_octa",
		"name": "Octa-core 3.4 GHz",
		"desc": "8 cœurs : un bon équilibre perf/prix.",
		"slots": 5,
		"income": 0.55,
		"watts": 110,
		"heat": 1.8,
		"price": 1100,
	},
	{
		"id": "cpu_hexadec",
		"name": "Hexadeca-core 3.8 GHz",
		"desc": "16 cœurs : le gros processeur du Data Hall.",
		"slots": 10,
		"income": 0.65,
		"watts": 190,
		"heat": 3.2,
		"price": 2400,
	},
]

const RAMS := [
	{
		"id": "ram_32",
		"name": "32 Go DDR5",
		"desc": "Le minimum vital.",
		"slots": 1,
		"watts": 10,
		"heat": 0.1,
		"price": 250,
	},
	{
		"id": "ram_64",
		"name": "64 Go DDR5",
		"desc": "Le standard pour les VPS.",
		"slots": 3,
		"watts": 18,
		"heat": 0.2,
		"price": 600,
	},
	{
		"id": "ram_128",
		"name": "128 Go DDR5",
		"desc": "Beaucoup de mémoire : beaucoup de clients.",
		"slots": 6,
		"watts": 34,
		"heat": 0.4,
		"price": 1400,
	},
]

const DISKS := [
	{
		"id": "disk_1t",
		"name": "1× SSD 1 To",
		"desc": "Un disque simple.",
		"slots": 1,
		"watts": 8,
		"heat": 0.1,
		"price": 200,
	},
	{
		"id": "disk_2t",
		"name": "2× SSD 2 To (RAID)",
		"desc": "Double disque, un peu plus de clients.",
		"slots": 3,
		"watts": 14,
		"heat": 0.2,
		"price": 550,
	},
	{
		"id": "disk_4t",
		"name": "4× SSD NVMe (RAID 10)",
		"desc": "Stockage massif : de la place pour tous.",
		"slots": 6,
		"watts": 26,
		"heat": 0.4,
		"price": 1300,
	},
]


static func get_chassis(id: String) -> Dictionary:
	for c in CHASSIS:
		if c["id"] == id:
			return c
	return {}


static func get_cpu(id: String) -> Dictionary:
	for c in CPUS:
		if c["id"] == id:
			return c
	return {}


static func get_ram(id: String) -> Dictionary:
	for c in RAMS:
		if c["id"] == id:
			return c
	return {}


static func get_disk(id: String) -> Dictionary:
	for c in DISKS:
		if c["id"] == id:
			return c
	return {}


static func compute(chassis: Dictionary, cpu: Dictionary, ram: Dictionary, disk: Dictionary) -> Dictionary:
	## Specs FINALES du serveur configuré : les pièces s'additionnent.
	return {
		"slots": int(chassis.get("slots", 0)) + int(cpu.get("slots", 0)) + int(ram.get("slots", 0)) + int(disk.get("slots", 0)),
		"income": float(cpu.get("income", 0.5)),
		"watts": int(chassis.get("watts", 0)) + int(cpu.get("watts", 0)) + int(ram.get("watts", 0)) + int(disk.get("watts", 0)),
		"heat": float(chassis.get("heat", 0.0)) + float(cpu.get("heat", 0.0)) + float(ram.get("heat", 0.0)) + float(disk.get("heat", 0.0)),
		"price": int(chassis.get("price", 0)) + int(cpu.get("price", 0)) + int(ram.get("price", 0)) + int(disk.get("price", 0)),
	}


static func build_kit(chassis: Dictionary, cpu: Dictionary, ram: Dictionary, disk: Dictionary) -> Dictionary:
	## Le KIT livré à la livraison : toutes les pièces + les specs calculées.
	## Un kit n'est PAS posable au sol : il se porte jusqu'à la TABLE
	## D'ASSEMBLAGE (Data Hall) où il devient un vrai serveur.
	var spec := compute(chassis, cpu, ram, disk)
	return {
		"id": "kit_neuf",
		"kind": "kit",
		"name": "Kit serveur neuf (%s)" % str(cpu.get("name", "?")),
		"desc": "Pièces détachées neuves à assembler : %s · %s · %s · %s." % [
			chassis.get("name", "?"), cpu.get("name", "?"), ram.get("name", "?"), disk.get("name", "?"),
		],
		"specs": "À assembler sur la table d'assemblage du Data Hall.",
		"price": spec["price"],
		"color": Color(0.35, 0.8, 0.9),
		"slots": spec["slots"],
		"income": spec["income"],
		"watts": spec["watts"],
		"heat": spec["heat"],
		# Les pièces (pour l'affichage de l'assemblage)
		"chassis": chassis.duplicate(true),
		"cpu": cpu.duplicate(true),
		"ram": ram.duplicate(true),
		"disk": disk.duplicate(true),
	}


static func assemble(kit: Dictionary) -> Dictionary:
	## La table d'assemblage transforme le kit en VRAI serveur : il garde
	## les specs calculées, devient posable / montable, et attend un OS à
	## l'établi. Un serveur assemblé a un id unique (server_neuf) — sa
	## texture retombe sur le serveur générique (BakedAssets.server_tex).
	return {
		"id": "server_neuf",
		"kind": "server",
		"name": "Serveur neuf (%s)" % (kit.get("cpu", {}).get("name", "configuré") if typeof(kit.get("cpu")) == TYPE_DICTIONARY else "configuré"),
		"desc": "Serveur assemblé sur mesure dans ton Data Hall.",
		"specs": "%d clients max · %s $/s par client" % [int(kit.get("slots", 0)), kit.get("income", 0.0)],
		"price": int(kit.get("price", 0)),
		"color": Color(0.35, 0.8, 0.9),
		"slots": int(kit.get("slots", 0)),
		"income": float(kit.get("income", 0.5)),
		"watts": int(kit.get("watts", 0)),
		"heat": float(kit.get("heat", 1.0)),
	}
