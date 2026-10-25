class_name ShelterNavigation
extends RefCounted
## The prototype has two walkable floors joined by one stair edge.
## We use explicit waypoints rather than let characters walk through a ceiling.

const UPPER_Y := 430.0
const LOWER_Y := 640.0
const TOP_STAIR := Vector2(690, UPPER_Y)
const BOTTOM_STAIR := Vector2(810, LOWER_Y)
var stairs_open := true


func floor_at(point: Vector2) -> int:
	return 1 if absf(point.y - UPPER_Y) < absf(point.y - LOWER_Y) else 0


func route_between(origin: Vector2, target: Vector2) -> Array[Vector2]:
	var route: Array[Vector2] = []
	var current_floor := floor_at(origin)
	var target_floor := floor_at(target)
	# A cancelled character can be halfway up the stairs. Finish the nearest
	# landing first; otherwise a new order would cut diagonally through a room.
	if not is_equal_approx(origin.y, UPPER_Y) and not is_equal_approx(origin.y, LOWER_Y):
		if not stairs_open:
			return route
		route.append(TOP_STAIR if current_floor == 1 else BOTTOM_STAIR)
	if current_floor != target_floor:
		if not stairs_open:
			return []
		route.append(TOP_STAIR if current_floor == 1 else BOTTOM_STAIR)
		route.append(BOTTOM_STAIR if current_floor == 1 else TOP_STAIR)
	route.append(target)
	return route
