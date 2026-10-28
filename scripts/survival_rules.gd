class_name SurvivalRules
extends RefCounted
## All rates use simulation seconds, shared by tasks and the displayed clock.
## Prototype: one real-time second at 1x represents two in-game minutes.

const MINUTES_PER_SECOND := 2.0
const HUNGER_RATE := 0.10
const IDLE_FATIGUE_RATE := 0.06
const WORK_FATIGUE_RATE := 0.10
const SLEEP_RECOVERY_RATE := 3.0
const MEAL_RECOVERY := 55.0


static func tick(actor: Survivor, delta: float) -> void:
	if actor.health <= 0.0:
		return
	var sleeping := actor.state == Survivor.TaskState.WORKING and not actor.orders.is_empty() and actor.orders[0] == "sleep"
	actor.hunger = clampf(actor.hunger + HUNGER_RATE * delta * actor.metabolism * CharacterAbilities.needs_multiplier(actor,"hunger"), 0.0, 100.0)
	if sleeping:
		actor.fatigue = maxf(0, actor.fatigue - SLEEP_RECOVERY_RATE * delta * CharacterAbilities.factor(actor, "sleep"))
	else:
		var rate := WORK_FATIGUE_RATE if actor.state == Survivor.TaskState.WORKING else IDLE_FATIGUE_RATE
		actor.fatigue = minf(100, actor.fatigue + rate * delta * actor.metabolism * CharacterAbilities.needs_multiplier(actor,"strain"))
	var damage := 0.0
	if actor.hunger >= 95.0:
		damage += 0.10
	if actor.fatigue >= 98.0:
		damage += 0.04
	if actor.infection > 0:
		actor.infection = minf(100, actor.infection + delta * 0.015)
	if actor.infection >= 60:
		damage += 0.05
	if damage > 0:
		actor.health = maxf(0, actor.health - damage * delta)
	elif actor.hunger < 40 and actor.fatigue < 45 and actor.injury < 20 and actor.infection < 20:
		actor.health = minf(100, actor.health + 0.03 * delta * CharacterAbilities.factor(actor, "recovery"))
		if sleeping and actor.metabolism < 1:
			actor.injury = maxf(0, actor.injury - 0.03 * delta * CharacterAbilities.factor(actor, "recovery"))


static func clock_text(seconds: float) -> String:
	var total_minutes := 480 + int(seconds * MINUTES_PER_SECOND)
	var hour := (total_minutes % 1440) / 60
	return "第 %d 天  %02d:%02d  %s" % [1 + total_minutes / 1440, hour, total_minutes % 60, "夜间" if hour < 6 or hour >= 18 else "日间"]


static func is_night(seconds: float) -> bool:
	var hour := ((480 + int(seconds * MINUTES_PER_SECOND)) % 1440) / 60
	return hour < 6 or hour >= 18
