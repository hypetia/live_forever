class_name ArchiveFixture
extends RefCounted
## Historical regressions isolate their original systems and economy. New
## feature suites and actual campaign journeys instantiate the normal game.
static func campaign(game: Node2D) -> void:
 if not game.has_method('chronicle_snapshot'):return
 var error:=SaveSystem.apply_state(game,game._initial_state)
 assert(error.is_empty(),error)
 game.chronicle.manual_defense=false
 game.neighborhood.enabled=false;game.neighborhood.sync(game)
 for field: ExpeditionState in game.regions.values():field.interior.enabled=false
