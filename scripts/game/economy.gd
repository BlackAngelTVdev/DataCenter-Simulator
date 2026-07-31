class_name Economy
extends Node
## Économie de la partie : argent, revenu par seconde, dépenses et remboursements.
## Émet `money_changed` quand la partie entière de l'argent affichée change.

signal money_changed(amount: int, income: float, building_count: int)

var money := 500.0
var grid: GridSystem

var _last_money_shown := -1


func setup(grid_ref: GridSystem, starting_money: float) -> void:
	grid = grid_ref
	money = starting_money


func total_income() -> float:
	var total := 0.0
	for b: Building in grid.buildings.values():
		total += b.income
	return total


func can_afford(cost: float) -> bool:
	return money >= cost


func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	money -= cost
	_notify_change()
	return true


func refund(amount: float) -> void:
	money += amount
	_notify_change()


func tick(delta: float) -> void:
	money += total_income() * delta
	_notify_change()


func refresh() -> void:
	_notify_change()


func _notify_change() -> void:
	var shown := int(money)
	if shown == _last_money_shown:
		return
	_last_money_shown = shown
	money_changed.emit(shown, total_income(), grid.buildings.size())
