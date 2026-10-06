extends CharacterBody2D
## Тестовый dummy-юнит для автотеста тактических механик.
## Умеет получать урон и отбрасывание — этого достаточно для взрывов/мин.

var hp: int = 100
var knockback_applied: bool = false

func take_damage(amount: float) -> void:
	hp -= int(amount)

func apply_knockback(_direction: Vector2, _force: float, _duration: float) -> void:
	knockback_applied = true
