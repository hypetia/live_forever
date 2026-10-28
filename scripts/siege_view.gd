class_name SiegeView
extends Node2D
var game: Node2D
var hud: CanvasLayer
var toolbar: HBoxContainer
var pause_panel: Panel
var effects:=CombatEffects.new()
var previous_elapsed:=-1.0
var wave_label: Label
func _ready() -> void:
 z_index=20
 game.siege.enemy_hit.connect(func(index: int,at: Vector2,direction: float,damage: int,lethal: bool):effects.hit(index,at,direction,damage,lethal))
 hud=CanvasLayer.new();hud.layer=9;add_child(hud)
 wave_label=Label.new();wave_label.position=Vector2(390,90);wave_label.size=Vector2(700,40);wave_label.theme=GameUi.theme();wave_label.add_theme_font_size_override('font_size',24);hud.add_child(wave_label)
 toolbar=HBoxContainer.new();toolbar.position=Vector2(745,814);toolbar.add_theme_constant_override('separation',5);hud.add_child(toolbar)
 for pair in [['J 攻击',func():game.siege.attack(game,game.selected_id)],['E 门',func():game.siege.toggle(game,'gate')],['X 窗',func():game.siege.toggle(game,'window')],['V 修补',func():game.siege.start_action(game,'repair',game.selected_id)],['F 救护',func():game.siege.start_action(game,'heal',game.selected_id)],['暂停',func():game.toggle_pause()]]:
  var b:=Button.new();b.text=pair[0];b.custom_minimum_size=Vector2(108,44);b.focus_mode=Control.FOCUS_NONE;b.theme=GameUi.theme();toolbar.add_child(b);b.pressed.connect(pair[1])
 pause_panel=Panel.new();pause_panel.position=Vector2(490,230);pause_panel.size=Vector2(460,390);pause_panel.theme=GameUi.theme();pause_panel.add_theme_stylebox_override('panel',GameUi.box(GameUi.PANEL));hud.add_child(pause_panel)
 var box:=VBoxContainer.new();box.position=Vector2(25,20);box.size=Vector2(410,350);box.add_theme_constant_override('separation',16);pause_panel.add_child(box)
 var l:=Label.new();l.text='防守暂停\n守夜同伴会协战；选择人物可亲自接管。';l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(l)
 for pair in [['继续防守 · 空格',func():game.toggle_pause()],['保存 F6',func():game.save_game()],['读取存档 F9',func():game.request_load()],['退出',func():game.exit_dialog.popup_centered()]]:
  var b:=Button.new();b.text=pair[0];b.custom_minimum_size=Vector2(410,42);box.add_child(b);b.pressed.connect(pair[1])
func _process(delta: float) -> void:
 hud.visible=game.siege.active;visible=game.siege.active
 if not visible:
  effects.clear();previous_elapsed=-1;return
 if game.siege.elapsed<previous_elapsed:effects.clear()
 previous_elapsed=game.siege.elapsed
 if not game.paused:effects.step(delta*game.speed)
 pause_panel.visible=game.paused
 wave_label.text='基地防守  %d/%d  ·  弹药%d  ·  门%d%% / 窗%d%%' % [game.siege.wave,game.siege.waves(),game.expansion.ammo,roundi(game.siege.gate/game.siege.gate_max*100),roundi(game.siege.window/game.siege.window_max*100)]
 if game.siege.elapsed>=180:wave_label.text+=' · 尸群撤退中'
 queue_redraw()
func _draw() -> void:
 if not is_instance_valid(game) or not game.siege.active:return
 var s:SiegeState=game.siege
 for pair in [[Vector2(150,640),s.gate,s.gate_max,s.gate_open],[Vector2(915,430),s.window,s.window_max,s.window_open]]:
  var p:Vector2=pair[0];var open:bool=pair[3]
  draw_rect(Rect2(p+Vector2(-12,-103),Vector2(24 if not open else 7,103)),Color('765f42') if pair[1]>0 else Color('413b33'))
  draw_rect(Rect2(p+Vector2(-33,-125),Vector2(66,6)),Color('2d302d'))
  draw_rect(Rect2(p+Vector2(-33,-125),Vector2(66*float(pair[1])/float(pair[2]),6)),Color('bcaa79') if pair[1]>float(pair[2])*.3 else Color('c47e65'))
 effects.draw_marks(self,0)
 for index in range(s.enemies.size()):
  var e: Dictionary=s.enemies[index]
  if e['escaped']:continue
  var point:=Vector2(e['x'],e['y']);var visual: Dictionary=e.duplicate()
  visual['climb_target']=0 if not point.y in [430.0,640.0] else -1
  if e['mode'] in ['approach','hunt']:visual['mode']='chase'
  if e['mode']=='breach':visual['mode']='windup';visual['timer']=fposmod(s.elapsed,.8)
  effects.draw_enemy(self,visual,index,point,s.elapsed)
  if e['hp']<=0:continue
  var scale: float=EnemyCatalog.stats(e['kind'])['scale'];var width:=55*scale
  draw_rect(Rect2(point+Vector2(-width*.5,-96*scale),Vector2(width,5)),Color('272d2c'))
  draw_rect(Rect2(point+Vector2(-width*.5,-96*scale),Vector2(width*float(e['hp'])/float(EnemyCatalog.stats(e['kind'])['health']),5)),Color('d5806a'))
  if e['mode']=='windup':draw_arc(point+Vector2(0,-37),35,-PI/2,PI/2,24,Color('e1b56d'),3,true)
 effects.draw_particles(self,0)
 for id in s.participants:
  var actor:Survivor=game.survivors[id]
  if actor.health<=0:continue
  if s.actions.has(str(id)):
   var a:Dictionary=s.actions[str(id)];draw_arc(actor.position+Vector2(0,-96),17,-PI/2,-PI/2+TAU*float(a['elapsed'])/2.5,30,Color('d3bd88'),3,true)
 for mark in s.hit_marks:
  var color:=Color(.7,.12,.08,float(mark['time'])/.45) if mark['blood'] else Color(.9,.8,.6,float(mark['time'])/.45)
  var p:=Vector2(mark['x'],mark['y'])
  for n in range(5):draw_line(p,p+Vector2(cos(n*1.2)*22,sin(n*1.2)*19),color,2,true)
