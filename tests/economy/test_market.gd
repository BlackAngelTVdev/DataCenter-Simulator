extends Node

# Test du marché fluctuant (Tech'Occase) — exécuté comme SCÈNE (pas besoin du
func _ready() -> void:
	await get_tree().process_frame
	var panda := ShopCatalog.get_item("server_panda")

	# 1. Multiplicateur dans la fourchette et déterministe (2 appels identiques).
	var m1 := ShopCatalog.market_multiplier("server_panda")
	var m2 := ShopCatalog.market_multiplier("server_panda")
	var in_range: bool = m1 >= ShopCatalog.MARKET_MIN and m1 <= ShopCatalog.MARKET_MAX
	print("TEST market_multiplier=", m1, " in_range=", in_range, " deterministic=", m1 == m2)

	# 2. Le prix du jour suit le multiplicateur.
	var price := ShopCatalog.market_price(panda)
	var expected := maxi(1, int(round(float(panda.get("price", 0)) * m1)))
	print("TEST market_price=", price, " expected=", expected)

	# 3. L'achat utilise le prix du jour (sans partenariat : prix plein marché).
	var buy := ShopCatalog.buy_price(panda)
	print("TEST buy_price=", buy)

	# 4. La revente suit le prix du JOUR (pas le prix d'achat mémorisé).
	var resale := ShopCatalog.resale_value(panda)
	var expected_resale := maxi(1, int(round(float(expected) * ShopCatalog.RESALE_RATIO)))
	print("TEST resale_value=", resale, " expected=", expected_resale)

	var ok: bool = (
		in_range and m1 == m2 and price == expected
		and buy == price and resale == expected_resale
	)
	print("TEST_RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
