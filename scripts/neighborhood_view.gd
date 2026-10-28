class_name NeighborhoodView
extends CanvasLayer
## Contextual choices live beside physical objects; no permanent quest text over the world.
var game: Node2D
var opened := false
var paused_before := false
var selected := ""
var pending_node := ""
var confirmed := ""
var root: Control
var window: Panel
var actions: Dictionary = {}
var note: Label

func _ready() -> void:
	layer=15
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root);root.hide()
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,.55);root.add_child(shade)

func open_at(id: String) -> void:
	if not game.neighborhood.near(game,id) or game.cycle.phase!="scavenge" or game._loot_open or game.departure_dialog.visible:return
	if not opened:paused_before=game.paused
	selected=id;confirmed="";opened=true;game.paused=true;root.show();render()

func render() -> void:
	if is_instance_valid(window):window.hide();window.queue_free()
	actions.clear()
	var ui: CampaignInterface=game.interface
	var offers: Array[String]=game.neighborhood.offers(selected)
	window=ui.panel(root,Vector2(335,135),Vector2(770,210+offers.size()*83))
	ui.label(window,NeighborhoodSystem.NODES[selected]["name"],Vector2(25,18),Vector2(555,42),27,GameUi.ACCENT)
	ui.button(window,"返回 Esc",Vector2(603,19),Vector2(142,40),close)
	note=ui.label(window,game.neighborhood.summary(game.expedition.location_id),Vector2(25,68),Vector2(720,88),18,GameUi.SECONDARY)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for index in range(offers.size()):
		var id: String=offers[index]
		var spec: Dictionary=NeighborhoodSystem.ACTIONS[id]
		var issue: String=game.neighborhood.error(game,id,true)
		var b:=ui.button(window,spec["name"],Vector2(25,167+index*83),Vector2(720,46),choose.bind(id))
		b.disabled=not issue.is_empty();b.tooltip_text=spec["hint"]+("\n"+issue if not issue.is_empty() else "")
		var cost:=ShelterInventory.describe(spec["cost"]) if not spec["cost"].is_empty() else "无需原料"
		if spec.has("yield"):cost+=" → "+ShelterInventory.describe(game.neighborhood._output(game,id))
		if spec.get("permanent",false):cost+=" · 永久拆除"
		ui.label(window,cost+" · %.0f秒" % spec["seconds"],Vector2(35,215+index*83),Vector2(700,26),17,GameUi.MUTED)
		actions[id]=b

func choose(id: String) -> void:
	if NeighborhoodSystem.ACTIONS[id].get("permanent",false) and confirmed!=id:
		confirmed=id;note.text=NeighborhoodSystem.ACTIONS[id]["hint"]+"\n再次点击确认永久拆除；返回可取消。";note.modulate=GameUi.WARNING
		actions[id].text="确认："+NeighborhoodSystem.ACTIONS[id]["name"]
		return
	close()
	if game.neighborhood.start(game,id):game.expedition_view.refresh()

func close() -> void:
	if not opened:return
	dismiss_loaded();game.paused=paused_before or game.game_over
	get_viewport().set_input_as_handled()

func dismiss_loaded() -> void:
	opened=false;confirmed="";pending_node=""
	if is_instance_valid(root):root.hide()

func draw_field(canvas: Node2D,camera: float) -> void:
	var system: NeighborhoodSystem=game.neighborhood
	var f: ExpeditionState=game.expedition
	if not system.enabled:return
	for id in NeighborhoodSystem.NODES:
		var n: Dictionary=NeighborhoodSystem.NODES[id]
		if n["map"]!=f.location_id or not system.node_visible(game,id):continue
		var p:=NeighborhoodSystem.point(id)-Vector2(camera,0)
		if p.x< -50 or p.x>1110:continue
		var visible_here:=f.interior.visible(f,float(n["x"]),int(n["floor"]))
		var near:=system.near(game,id)
		var color:=InteractionFeedback.READY if near else InteractionFeedback.DISTANT
		var stripped: bool=(id in ["generator","coldstore"] and system.clinic["mode"]=="stripped") or (id in ["pump","valve"] and system.water["mode"]=="stripped")
		var running: bool=(id in ["generator","coldstore"] and system.clinic["mode"]=="running") or (id in ["pump","valve"] and system.water["mode"]=="running")
		var metal:=Color("3f5757") if running else Color("55554d")
		if stripped:metal=Color("303b3c");color=InteractionFeedback.EMPTY_EDGE
		if id=='patient':
			RealismAssets.prop(canvas,0,Rect2(p-Vector2(62,77),Vector2(124,77)),Color(.81,.84,.78))
			_draw_patient(canvas,p,false)
		else:
			var index:=12 if id=='pump' else 5 if id=='coldstore' else 13
			var size:=Vector2(60,78) if id=='coldstore' else Vector2(80,68)
			RealismAssets.prop(canvas,index,Rect2(p-Vector2(size.x*.5,size.y),size),Color(.87,.94,.86) if running else Color(.76,.79,.72),stripped)
			if near and visible_here:canvas.draw_rect(Rect2(p-Vector2(size.x*.5,size.y),size).grow(2),color,false,1.2)
			if id=='generator' and running and system.clinic['fuel']>0 and system.clinic['cold']>0:
				canvas.draw_circle(p+Vector2(17,-38),3,Color('b8c98e'))
			elif id=='pump' and running:
				canvas.draw_line(p+Vector2(30,-18),p+Vector2(90,-18),Color('639ba9'),4,true)
				canvas.draw_circle(p+Vector2(33+fposmod(f.elapsed*22,53),-18),2,Color('b6d3c8'))
			elif id=='valve':
				for j in range(3):canvas.draw_circle(p+Vector2(-18+j*18,-40),2,Color('92bda3') if system.water['connected'] else Color('676b5c'))
				if system.water['leak'] in [1,2]:canvas.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-59),p+Vector2(-8,-45),p+Vector2(8,-45)]),GameUi.WARNING)
		if not visible_here:continue
		var marker:=p+Vector2(0,-91)
		canvas.draw_circle(marker,13,Color("15292c"))
		canvas.draw_arc(marker,14,0,TAU,24,color,2 if near else 1,true)
		if id in ["coldstore","patient"]:
			canvas.draw_line(marker+Vector2(-6,0),marker+Vector2(6,0),color,3,true);canvas.draw_line(marker+Vector2(0,-6),marker+Vector2(0,6),color,3,true)
		elif id=="pump":canvas.draw_colored_polygon(PackedVector2Array([marker+Vector2(0,-7),marker+Vector2(-5,2),marker+Vector2(0,7),marker+Vector2(5,2)]),color)
		else:
			canvas.draw_line(marker+Vector2(-6,6),marker+Vector2(5,-6),color,3,true);canvas.draw_line(marker+Vector2(-1,-7),marker+Vector2(7,0),color,3,true)
		if not system.work.is_empty() and NeighborhoodSystem.ACTIONS[system.work["id"]]["node"]==id:
			canvas.draw_arc(marker,19,-PI/2,-PI/2+TAU*float(system.work["elapsed"])/float(NeighborhoodSystem.ACTIONS[system.work["id"]]["seconds"]),32,InteractionFeedback.READY,3,true)
	if f.carrying_person:_draw_patient(canvas,Vector2(f.player_x-camera-f.facing*18,f.player_y-24),true)

func _draw_patient(canvas: Node2D,point: Vector2,carried: bool) -> void:
	var f:ExpeditionState=game.expedition
	var pose:=ActorVisual.remap(CharacterMotion.pose('patient' if carried else 'sleep',f.elapsed,.5,-f.facing if carried else 1.0))
	if carried:
		pose['hip']=Vector2(0,-24);pose['shoulder']=Vector2(f.facing*5,-51);pose['head']=Vector2(f.facing*10,-69)
		pose['knee_l']=Vector2(-f.facing*19,-5);pose['knee_r']=Vector2(-f.facing*12,-8)
		pose['left']=Vector2(-f.facing*9,2);pose['right']=Vector2(-f.facing*4,0)
	var base:=Transform2D(0,game.world_scale(),0,game.world_offset()+(canvas.combat_effects.shake() if 'combat_effects' in canvas else Vector2.ZERO))
	canvas.draw_set_transform_matrix(base*Transform2D(float(pose['rotation']),Vector2.ONE,0,point+pose['root']))
	ActorVisual.draw(canvas,game.neighborhood.rescue['id'],pose,Color(.85,.87,.80),'rescued')
	canvas.draw_set_transform_matrix(base)
