extends SceneTree
func _initialize():
	var failures=0
	for level in range(1,5):
		var g=load("res://run_model.gd").new()
		g.owned_augments=["beast"]
		g.augment_levels.beast=level
		g._start_stage()
		g.generated=true
		g.money=0
		g.mine_count=1
		for i in range(g.cells.size()):
			g.cells[i].mine=i==63
			g.cells[i].flagged=i==63
			g.cells[i].adjacent=1
		g._use_active("beast")
		var opened=g.cells.filter(func(c):return c.revealed).size()
		var expected=10*g.dig_cost*[10,20,40,80][level-1]
		if opened!=10 or g.money!=expected or g.direct_digs!=0:
			failures+=1
			push_error("Beast level "+str(level))
		print("Beast Lv.",level," opened=",opened," gold=",g.money," expected=",expected)
		g.free()
	print("Beast failures ",failures)
	quit(failures)
