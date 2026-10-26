extends "res://tests/test_campaign.gd"

func joined(report: Array[String]) -> String:
	return "\n".join(report)

func _run() -> void:
	var game := campaign()
	game.end_day()
	game.cycle.roles.assign(["guard","floor","scavenge"])
	game.residence.security = {"gate":2,"mesh":1,"alarm":1,"stakes":1}
	game.residence.condition = 80
	game.survivors[0].health = 72
	game.survivors[0].fatigue = 84
	var rows := DefenseAssessment.components(game,true)
	var forecast := DefenseAssessment.total(rows)
	game.survivors[0].fatigue = minf(100,game.survivors[0].fatigue+28)
	expect(is_equal_approx(forecast,game.raid_defense()),"guard fatigue cap is identical in planning and resolution")
	var result := 0.0
	for row in rows: result += float(row["value"])
	expect(is_equal_approx(result,forecast),"visible component values sum to the actual defense")
	var condition: float = game.residence.condition
	var snapshot := SaveSystem.capture(game)
	game.security_view.toggle()
	expect(game.security_view.opened and game.paused,"inspection pauses the actual game")
	expect(SaveSystem.capture(game) == snapshot,"inspecting defenses never mutates simulation or resources")
	game.security_view.close()
	expect(game.paused,"closing during planning keeps the planning pause")
	game.residence.condition = 0
	expect(DefenseAssessment.total(DefenseAssessment.components(game)) < forecast,"worn facilities lose their actual contribution")
	game.residence.condition = condition
	game.cycle.roles.assign(["floor","floor","scavenge"])
	var without_guard := DefenseAssessment.total(DefenseAssessment.components(game))
	game.residence.security["alarm"] = 0
	expect(is_equal_approx(without_guard,game.raid_defense()),"alarm gives no bonus with nobody guarding")
	game.residence.security["alarm"] = 1
	game.cycle.roles[0] = "guard"
	var with_alarm: float = game.raid_defense()
	game.residence.security["alarm"] = 0
	expect(with_alarm > game.raid_defense(),"alarm visibly multiplies an actual guard")
	# Force deterministic raid/no-raid fixtures; all outcomes still use real settlement code.
	game.cycle.night_day = 4
	game.cycle.seed = (100-(4*7919)%100)%100
	game.residence.security = {"gate":2,"mesh":2,"alarm":1,"stakes":1}
	game.cycle.builds.append({"type":"barricade","slot":0,"state":"complete"})
	var report: Array[String] = []
	var stock: Dictionary = game.inventory.snapshot()
	var health: float = game.survivors[0].health
	condition = game.residence.condition
	game._resolve_raid(report)
	expect(joined(report).contains("成功阻挡") and joined(report).contains("抵挡贡献"),"successful raid records actual contributions and outcome")
	expect(game.inventory.snapshot() == stock and game.survivors[0].health == health,"successful defense prevents both theft and injury")
	expect(game.residence.condition < condition and joined(report).contains("耐久"),"a blocked raid still records facility wear")
	game.cycle.seed = (99+100-(4*7919)%100)%100
	report.clear(); condition = game.residence.condition
	game._resolve_raid(report)
	expect(joined(report).contains("没有尸群袭击") and game.residence.condition == condition,"no raid causes neither fabricated wear nor loot loss")
	game.cycle.seed = (100-(4*7919)%100)%100
	game.cycle.builds.clear()
	game.cycle.roles.assign(["floor","floor","scavenge"])
	game.residence.security = {"gate":0,"mesh":1,"alarm":0,"stakes":0}
	game.residence.condition = 100
	game.survivors[0].armor_item = {"kind":"vest","durability":20}
	report.clear(); stock = game.inventory.snapshot(); health = game.survivors[0].health
	var scout: float = game.survivors[2].health
	game._resolve_raid(report)
	expect(joined(report).contains("防守缺口") and joined(report).contains("护甲减免") and joined(report).contains("防护网再减免"),"breach report explains deficit and actual armor/window mitigation")
	expect(game.survivors[0].health < health and game.survivors[2].health == scout,"raid hurts a home resident, never the absent scout")
	expect(game.inventory.amount("raw_food") == stock["raw_food"]-2 and game.inventory.amount("water") == stock["water"]-2,"reported breached supplies are actually removed once")
	expect(game.survivors[0].armor_item["durability"] == 16,"reported armor wear is real")
	game.residence.convoy = "row"
	var escort := DefenseAssessment.total(DefenseAssessment.components(game))
	game.residence.security["gate"] = 2
	expect(is_equal_approx(escort,DefenseAssessment.total(DefenseAssessment.components(game))),"convoy assessment excludes fixed home defenses")
	report.clear(); game._resolve_raid(report)
	expect(joined(report).contains("路线威胁") and joined(report).contains("营地设施不参与"),"convoy report distinguishes escort from home guards")
	game.free()
	# Real dawn report round trip and no double raid after reload.
	game = campaign()
	game.end_day()
	game.cycle.roles.assign(["guard","floor","floor"])
	game.start_expedition()
	expect(game.cycle.phase == "dawn","stay-home night resolves through the real dawn transition")
	var saved := SaveSystem.capture(game)
	var history: Array[String] = game.cycle.report.duplicate()
	expect(history.any(func(line): return line.begins_with("【安防】")),"dawn saves an inspectable historical defense record")
	expect(SaveSystem.apply_state(game,saved).is_empty() and game.cycle.report == history,"dawn defense records survive save and load")
	game._settle_night([])
	expect(SaveSystem.capture(game) == saved,"reopening a report cannot settle damage or wear twice")
	game.begin_day()
	game.security_view.toggle()
	expect(game.paused,"opening inspection during day pauses movement")
	game.security_view.close()
	expect(not game.paused,"closing inspection restores the prior daytime pause")
	game.security_view.toggle()
	saved = SaveSystem.capture(game)
	saved["paused"] = false
	expect(SaveSystem.apply_state(game,saved).is_empty() and not game.security_view.opened and not game.paused,"load dismisses transient inspection and respects loaded pause state")
	game.free()
	print("SECURITY RESULT: %d checks, %d failures" % [checks,failures])
	await create_timer(0.12).timeout
	quit(1 if failures else 0)
