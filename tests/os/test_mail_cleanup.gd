extends Node

# Test de la MIGRATION des e-mails : les anciennes saves gardaient les e-mails
# supprimés dans received_mails + leurs ids dans deleted_mails. GameSave.
# _cleanup_mail_ghosts() doit purger les fantômes (ids rand_* de deleted_mails,
# e-mails supprimés de received_mails, mails_seen associés) sans toucher aux
# ids du pool CLIENTS (mail_*).


func _ready() -> void:
	await get_tree().process_frame
	var ok := true

	# 1. État « ancienne save » : des e-mails aléatoires supprimés (encore dans
	#    received_mails, tracés dans deleted_mails) + des clients supprimés.
	GameManager.received_mails = [
		{"id": "rand_111", "from": "A", "subject": "pub 1", "body": "b"},
		{"id": "rand_222", "from": "B", "subject": "pub 2", "body": "b"},
		{"id": "rand_333", "from": "C", "subject": "offre", "body": "b"},
	]
	GameManager.deleted_mails = {
		"rand_111": true,       # supprimé : doit disparaître du tableau
		"rand_222": true,       # supprimé : doit disparaître du tableau
		"mail_welcome": true,   # client pool : doit RESTER dans deleted_mails
	}
	GameManager.mails_seen = {
		"rand_111": true, "rand_222": true, "rand_333": true,
		"mail_welcome": true,
	}

	GameSave._cleanup_mail_ghosts()

	# received_mails : rand_111 et rand_222 supprimés → retirés.
	ok = ok and GameManager.received_mails.size() == 1
	ok = ok and str(GameManager.received_mails[0].get("id", "")) == "rand_333"
	# deleted_mails : rand_* purgés, mail_welcome conservé.
	ok = ok and not GameManager.deleted_mails.has("rand_111")
	ok = ok and not GameManager.deleted_mails.has("rand_222")
	ok = ok and GameManager.deleted_mails.has("mail_welcome")
	# mails_seen : les ids des e-mails disparus sont purgés, le reste gardé.
	ok = ok and not GameManager.mails_seen.has("rand_111")
	ok = ok and not GameManager.mails_seen.has("rand_222")
	ok = ok and GameManager.mails_seen.has("rand_333")
	ok = ok and GameManager.mails_seen.has("mail_welcome")
	print("TEST after_cleanup_received=", GameManager.received_mails.size())
	print("TEST after_cleanup_deleted=", GameManager.deleted_mails.keys())
	print("TEST after_cleanup_seen=", GameManager.mails_seen.keys())

	# 2. Idempotence : relancer le nettoyage ne casse rien.
	var before := GameManager.received_mails.size()
	GameSave._cleanup_mail_ghosts()
	ok = ok and GameManager.received_mails.size() == before

	# Nettoyage (état par défaut pour ne pas polluer les autres tests).
	GameManager.received_mails = []
	GameManager.deleted_mails = {}
	GameManager.mails_seen = {}

	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
