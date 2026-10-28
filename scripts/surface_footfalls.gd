class_name SurfaceFootfalls
extends RefCounted
## Short, bounded presentation at genuine foot contacts; no noise or damage rules.
const MAX_MARKS := 16
var marks: Array[Dictionary] = []

func clear() -> void:
	marks.clear()

func contact(at: Vector2, kind: String, quiet: bool = false) -> void:
	if marks.size() >= MAX_MARKS: marks.pop_front()
	marks.append({'at':at,'kind':kind,'age':0.0,'quiet':quiet})

func step(delta: float) -> void:
	if delta <= 0:return
	for mark in marks:mark['age']+=delta
	marks=marks.filter(func(mark):return mark['age']<.65)

static func sound(kind: String) -> String:
	return 'foot_'+kind if kind in ['water','snow','metal','glass','wood'] else 'foot_gravel'

func draw(c: CanvasItem,camera: float) -> void:
	for mark in marks:
		var p:float=float(mark['age'])/.65
		var at:Vector2=mark['at']-Vector2(camera,0)
		if at.x<0 or at.x>1070:continue
		var strength:float=(1-p)*(.45 if mark['quiet'] else .8)
		var kind:String=mark['kind']
		if kind=='water':
			var ring:=PackedVector2Array()
			for i in range(25):ring.append(at+Vector2(cos(i*TAU/24)*(4+p*15),sin(i*TAU/24)*(1+p*4)))
			c.draw_polyline(ring,Color(.55,.72,.76,strength*.6),1,true)
			for side in [-1,1]:c.draw_circle(at+Vector2(side*(3+p*8),-sin(p*PI)*8),1.2*(1-p),Color(.65,.8,.81,strength))
		elif kind in ['snow','gravel']:
			for i in range(3):
				var color:=Color(.8,.85,.82,strength*.45) if kind=='snow' else Color(.53,.51,.42,strength*.22)
				c.draw_circle(at+Vector2((i-1)*(3+p*9),-p*(4+i)),1.4+p*2,color)
		elif kind=='glass':
			for i in range(2):
				var point:=at+Vector2((i*2-1)*(3+p*4),-sin(p*PI)*2)
				c.draw_line(point,point+Vector2(2,-2),Color(.65,.78,.77,strength*.6),1,true)
		elif kind=='metal':
			c.draw_line(at+Vector2(-5,0),at+Vector2(4,0),Color(.73,.72,.63,strength*.25),1,true)
