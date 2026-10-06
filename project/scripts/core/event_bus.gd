extends Node
## Шина событий (autoload EventBus): сигналы, на которые подписываются разные системы.

## Сигнал: здоровье игрока изменилось (текущее, максимальное).
@warning_ignore("unused_signal")
signal on_player_health_updated(current: float, max: float)
