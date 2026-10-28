extends 'res://tests/test_tactical_campaign.gd'
func _run() -> void:
 var ids:Array=PeopleCatalog.DATA.keys()+EnemyCatalog.TYPES.keys()
 var digests:Array=[]
 for id in ids:
  var texture:=RealismAssets.figure_texture(id);var frame:=RealismAssets.figure_frame(id)
  expect(texture!=null and frame.has_area() and Rect2(Vector2.ZERO,texture.get_size()).encloses(frame),'authored source region exists for '+id)
  var pose:=CharacterMotion.pose('idle',1,0,1);var original:=pose.duplicate(true)
  var visual:=ActorVisual.remap(pose);var vertices:=ActorVisual.deformed_vertices(id,visual)
  expect(pose==original,'render remapping cannot change action input '+id)
  expect(vertices.size()==(ActorVisual.COLUMNS+1)*(ActorVisual.ROWS+1) and Array(vertices).all(func(v):return v.is_finite() and absf(v.x)<500 and absf(v.y)<500),'bounded finite mesh '+id)
  expect(vertices==ActorVisual.deformed_vertices(id,visual),'repeated sampling is deterministic '+id)
  var moving:=ActorVisual.deformed_vertices(id,ActorVisual.remap(CharacterMotion.pose('walk',.15,0,1)))
  expect(moving!=vertices,'walking deforms texture joints rather than sliding a static picture '+id)
  for mode in ['attack','hurt','sleep','search','climb','vault','drink','cook','dead']:
   var sample:=ActorVisual.deformed_vertices(id,ActorVisual.remap(CharacterMotion.pose(mode,.4,.6,-1)))
   expect(Array(sample).all(func(v):return v.is_finite() and absf(v.x)<500 and absf(v.y)<500),'valid '+mode+' skinning '+id)
 for id in LocationCatalog.ALL_IDS:expect(RealismAssets.LOCATIONS.has(id),'unique material mapping for '+id)
 var image:=RealismAssets.neutral_props().get_image();var sampled:=0;var colored:=0
 for y in range(0,image.get_height(),17):
  for x in range(0,image.get_width(),17):
   var p:=image.get_pixel(x,y)
   if p.a>.8:
    sampled+=1
    if maxf(p.r,maxf(p.g,p.b))-minf(p.r,minf(p.g,p.b))>.01:colored+=1
 expect(sampled>500 and colored==0,'every sampled opaque pixel of empty props is neutral grey')
 expect(ActorVisual.height('conan')<ActorVisual.height('chen') and ActorVisual.scale_for('pooh').x>1,'child and plush companion retain their own proportions')
 var g:=fresh();valid(g,'new art has no new gameplay save requirement');var before:=SaveSystem.capture(g)
 for id in ids:
  for phase in range(8):ActorVisual.deformed_vertices(id,ActorVisual.remap(CharacterMotion.pose('walk',phase*.13,0,1)))
 expect(SaveSystem.capture(g)==before,'sampling every textured cast and monster cannot grant items, move actors or change combat')
 g.free();print('REALISM RESULT: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
