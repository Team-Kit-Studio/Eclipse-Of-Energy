extends RefCounted
## Именованные битовые маски физических слоёв проекта.
## Соответствие слоёв задано в project.godot → [layer_names].
##
## Подключать через preload (без class_name — чтобы не зависеть от кэша
## глобальных классов редактора):
##   const Layers = preload("res://project/scripts/core/game_layers.gd")
##   var mask := Layers.WORLD | Layers.ENEMY

const WORLD := 1 << 0        # Слой 1 «world» — стены (TileMapLayer).
const PLAYER := 1 << 1       # Слой 2 «Player» — игрок.
const ITEMS := 1 << 2        # Слой 3 «items» — выпавшие предметы.
const INTERACTIVE := 1 << 3  # Слой 4 «interactive objects» — шкафы, сундуки, двери.
const BULLETS := 1 << 4      # Слой 5 «bullets» — снаряды.
const ENEMY := 1 << 5        # Слой 6 «enemy» — враги (в т.ч. НПС-враги).
const NPC := 1 << 6          # Слой 7 «NPC» — союзные НПС (пули пролетают мимо).

## Что останавливает пулю: стены и интерактивные объекты.
const BULLET_BLOCKERS := WORLD | INTERACTIVE
## Кто может получать урон: игрок (свои гранаты/мины) и враги. Союзники исключены.
const DAMAGEABLE := PLAYER | ENEMY
