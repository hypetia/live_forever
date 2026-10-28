extends Node2D
var actors:Array[Survivor]=[]
var mode:='idle'
var clock:=1.0
func _ready() -> void:
 for id in PeopleCatalog.DATA:
  var actor:=Survivor.new();actor.person.persona=id;actor.display_name=PeopleCatalog.DATA[id]['name'];actor.tint=Color(PeopleCatalog.DATA[id]['tint']);actors.append(actor)
func _draw() -> void:
 draw_rect(Rect2(0,0,1440,900),Color('171e21'))
 draw_string(Survivor.FONT,Vector2(45,48),'人物与动作 · 引擎实时渲染',HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color('d6d0ba'))
 for i in range(actors.size()):
  var actor:Survivor=actors[i];var x:=180+(i%4)*350;var y:=290+(i/4)*275
  draw_rect(Rect2(x-150,y-215,300,255),Color('202a2c'))
  var pose:=CharacterMotion.pose(mode,clock,.6,1)
  CharacterMotion.draw(self,Vector2(x,y),actor,pose,false,Color.TRANSPARENT,Transform2D(0,Vector2(1.85,1.85),0,Vector2(x*(1-1.85),y*(1-1.85))))
  draw_set_transform( Vector2.ZERO)
  draw_string(Survivor.FONT,Vector2(x-110,y+27),actor.display_name,HORIZONTAL_ALIGNMENT_LEFT,230,19,Color('d8cfb7'))
func _exit_tree() -> void:
 for actor in actors:actor.free()
