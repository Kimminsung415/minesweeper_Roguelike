extends "res://gui_test.gd"
func _run():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	for mode in ["easy", "hard"]:
		game._select_mode(mode)
		for stage in range(1,11):
			game.stage=stage
			game._start_stage()
			await _frames()
			_expect(game.board_width == 8 + (stage-1)*(1 if mode=="easy" else 2),"Mode growth %s stage %d" % [mode,stage])
			var before=game.grid.size
			var tile=game.tile_buttons[0].size
			for i in range(game.cells.size()):
				game.cells[i].revealed=true
				game.cells[i].mine=false
				game.cells[i].adjacent=i%8+1
				game.cells[i].obscured=i%9==0
				game._refresh_tile(i)
			await _frames()
			_expect(game.grid.size==before,"Stage %d board size unchanged" % stage)
			_expect(game.tile_buttons.all(func(b):return b.size==tile and b.size.x==b.size.y),"Stage %d all numbered/question tiles square" % stage)
	print("Finished %d checks with %d failures" % [checks,failures])
	quit(failures)
