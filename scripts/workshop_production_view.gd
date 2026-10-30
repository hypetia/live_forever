class_name WorkshopProductionView
extends RefCounted

static func controls(ui: CampaignInterface,card: Panel,kind: String) -> void:
	var mode:=OptionButton.new();mode.position=Vector2(16,121);mode.size=Vector2(136,32)
	mode.add_item("制作批数");mode.add_item("库存补到")
	mode.tooltip_text="制作批数：完成指定数量后停止。库存补到：只补充缺口；工具包和开锁器按仓库备用数量计算。"
	card.add_child(mode);ui.production_modes[kind]=mode
	var count:=SpinBox.new();count.position=Vector2(164,121);count.size=Vector2(78,32);count.min_value=1;count.max_value=20;count.value=1
	card.add_child(count);ui.production_counts[kind]=count
	for row in ui.game.production.orders:
		if row["kind"]==kind:mode.select(0 if row["mode"]=="batch" else 1);count.value=row["amount"]

static func arrange(ui: CampaignInterface,kind: String) -> void:
	if ui.game.production.plan(ui.game,kind,"batch" if ui.production_modes[kind].selected==0 else "stock",int(ui.production_counts[kind].value),ui.game.selected_id):ui.game.context_open=false;ui.close_workshop()

static func page(ui: CampaignInterface,body: Control) -> void:
	var game:=ui.game
	ui.label(body,"暂无生产计划",Vector2(16,12),Vector2(990,35),21,GameUi.SECONDARY).visible=game.production.orders.is_empty()
	var index:=0
	for row in game.production.orders:
		var card:=ui.panel(body,Vector2(0,index*132),Vector2(1055,116),GameUi.SURFACE)
		var actor:Survivor=game.production.actor_for(game,row)
		var name:String=actor.display_name if actor!=null else "未分配"
		var target:String="剩余 %d 件"%row["amount"] if row["mode"]=="batch" else "备用库存 %d / %d"%[game.production.stock(game,row["kind"]),row["amount"]]
		ui.label(card,WorkshopProduction.NAMES[row["kind"]],Vector2(18,12),Vector2(310,30),22,GameUi.ACCENT)
		ui.label(card,name+"  /  "+target,Vector2(18,55),Vector2(560,30),18)
		ui.label(card,game.production.status(game,row),Vector2(395,12),Vector2(620,30),18,GameUi.SECONDARY)
		var toggle:=ui.button(card,"继续" if row["paused"] else "暂停",Vector2(742,61),Vector2(136,36),func():game.production.toggle(game,row["kind"]);ui._create_workshop())
		toggle.disabled=game.cycle.phase!="day"
		ui.production_actions[row["kind"]]=toggle
		var cancel:=ui.button(card,"取消",Vector2(894,61),Vector2(136,36),func():game.production.remove(game,row["kind"]);ui._create_workshop())
		cancel.disabled=game.cycle.phase!="day"
		index+=1
	body.custom_minimum_size.y=maxi(140,index*132)
