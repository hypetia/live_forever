extends SceneTree
func _initialize() -> void:call_deferred('_run')
func _run() -> void:
 var output:String=OS.get_cmdline_user_args()[0]
 var g:Node2D=load('res://scenes/campaign.tscn').instantiate();g.persistence_enabled=false;root.add_child(g);g.set_process(false)
 var records:Array=[]
 for size in [Vector2i(1024,768),Vector2i(1440,900)]:
  root.size=size
  for i in range(20):await process_frame
  var times:Array=[]
  for i in range(60):
   var start:=Time.get_ticks_usec();g.queue_redraw();await process_frame
   times.append((Time.get_ticks_usec()-start)/1000.0)
  times.sort();records.append({'resolution':[size.x,size.y],'median_ms':times[30],'p95_ms':times[57]})
 var file:=FileAccess.open(output+'/benchmark.json',FileAccess.WRITE)
 file.store_string(JSON.stringify({'renderer':'llvmpipe software; isolated probe, not Windows GPU performance','records':records},' '));file.close()
 print('ISOLATED SOFTWARE RENDER ',JSON.stringify(records));g.free();quit()
