class_name CombatGeometry
extends RefCounted
## A low furniture front occludes rays below its visible top, not an invisible wall.
static func obstruction(covers: Array, from: Vector2, to: Vector2, level: int) -> Dictionary:
	var nearest := 2.0
	var impact := Vector2.ZERO
	for cover in covers:
		if int(cover[2]) != level: continue
		var left := float(cover[0])
		var right := float(cover[1])
		# Two actors on the same side of a foreground prop can fight behind it.
		if from.x >= left and from.x <= right and to.x >= left and to.x <= right: continue
		var rect := Rect2(left, ExpeditionState.FLOOR_Y[level]-50, right-left, 50)
		var delta := to-from
		var enter := 0.0
		var leave := 1.0
		var valid := true
		for axis in range(2):
			if absf(delta[axis]) < 0.001:
				if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]: valid = false
			else:
				var a: float = (rect.position[axis]-from[axis])/delta[axis]
				var b: float = (rect.end[axis]-from[axis])/delta[axis]
				enter = maxf(enter,minf(a,b))
				leave = minf(leave,maxf(a,b))
		if valid and enter <= leave and enter < nearest:
			nearest = enter
			impact = from+delta*enter
	return {} if nearest > 1 else {"point":impact}
