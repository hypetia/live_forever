class_name InteractionFeedback
extends RefCounted
## Model-driven visual states. Empty means no ordinary supplies, independent of quest markers.
const EMPTY_BODY := Color("454545")
const EMPTY_EDGE := Color("646464")
const READY := Color("e1c08a")
const DISTANT := Color("a2aaa6")

static func pending_action(game: Node2D, index: int) -> bool:
	var field: ExpeditionState = game.expedition
	if game.director.status == "active" and game.director.trip_progress == 0:
		var mission: Dictionary = CampaignDirector.CONTRACTS[game.director.contract]
		if mission["type"] == "survey" and mission["map"] == field.location_id and mission["site"] == index: return true
	for id in GearCatalog.PARTS:
		var part: Dictionary = GearCatalog.PARTS[id]
		if part["map"] == field.location_id and part["site"] == index and not game.expansion.collected.has(id) and not game.expansion.carried.has(id): return true
	for id in ResidenceSystem.HOMES:
		var home: Dictionary = ResidenceSystem.HOMES[id]
		if id == "shelter" or home["map"] != field.location_id or home["site"] != index: continue
		if not game.residence.cleared.has(id) and game.residence.carried != id and (not game.residence.surveyed.has(id) or game.residence.prepared.has(id)): return true
	return false

static func site(game: Node2D, index: int, hovered: bool = false) -> Dictionary:
	var field: ExpeditionState = game.expedition
	var supplied := field.site_has_supplies(index)
	var accent := Color(str(field.area()["accent"]))
	var target: bool = game.interface.has_move_target and game.interface.target_site == index
	var progress := field.search_progress / field.search_duration if field.search_index == index and field.search_duration > 0 else 0.0
	return {"supplied": supplied, "near": field.site_in_range(index), "hovered": hovered, "target": target,
		"pending": pending_action(game,index), "progress": progress,
		"body": accent.darkened(0.2) if supplied else EMPTY_BODY,
		"edge": accent if supplied else EMPTY_EDGE}

static func route(game: Node2D, destination: Vector2) -> PackedVector2Array:
	var field: ExpeditionState = game.expedition
	var points := PackedVector2Array([Vector2(field.player_x,field.player_y)])
	if field.climb_target != -1:
		points.append(Vector2(field.player_x,ExpeditionState.FLOOR_Y[field.climb_target]))
		if destination.y != ExpeditionState.FLOOR_Y[field.climb_target]:
			var ladder := field.route_ladder(field.player_x,destination.x)
			points.append(Vector2(ladder,ExpeditionState.FLOOR_Y[field.climb_target]))
			points.append(Vector2(ladder,destination.y))
	elif absf(field.player_y-destination.y) > 1:
		var ladder := field.route_ladder(field.player_x,destination.x)
		points.append(Vector2(ladder,field.player_y));points.append(Vector2(ladder,destination.y))
	points.append(destination)
	return points
