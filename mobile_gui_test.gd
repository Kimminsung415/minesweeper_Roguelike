extends "res://gui_test.gd"
func _run():
	capture_dir="C:/Users/Minsung/Documents/Codex/2026-10-28/new-chat/outputs/v1.3.1-build010-preview"
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size=Vector2i(390,844)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames()
	_expect(game.mobile,"Narrow screen activates mobile")
	await _capture("01-phone-menu.png")
	game._select_mode("easy")
	await _frames()
	await _capture("02-phone-board.png")
	var tile=game.tile_buttons[0]
	var position=tile.get_global_rect().get_center()
	var press=InputEventScreenTouch.new()
	press.index=0
	press.position=position
	press.pressed=true
	game._input(press)
	press=press.duplicate()
	press.pressed=false
	game._input(press)
	await _frames()
	_expect(game.generated and game.direct_digs==1,"Touch tap digs once")
	var target=-1
	for i in range(game.cells.size()):
		if not game.cells[i].revealed:
			target=i
			break
	game._set_flag_mode(true)
	position=game.tile_buttons[target].get_global_rect().get_center()
	press.position=position
	press.pressed=true
	game._input(press)
	press=press.duplicate()
	press.pressed=false
	game._input(press)
	_expect(game.cells[target].flagged and game.direct_digs==1,"Flag mode touch does not dig")
	game._set_flag_mode(false)
	var old_digs=game.direct_digs
	press.pressed=true
	game._input(press)
	var second=press.duplicate()
	second.index=1
	second.position+=Vector2(60,0)
	game._input(second)
	var drag=InputEventScreenDrag.new()
	drag.index=1
	drag.position=second.position+Vector2(40,0)
	game._input(drag)
	press.pressed=false
	game._input(press)
	second.pressed=false
	game._input(second)
	_expect(game.direct_digs==old_digs and game.mobile_zoom>1,"Pinch zoom never digs")
	game.owned_augments=["gamble","survey","reroll"]
	game._refresh()
	game.phase="augment"
	game.offered_augments=["beast","adaptation","relief"]
	game._refresh()
	await _capture("03-phone-choice.png")
	_expect(game.choice_cards is VBoxContainer,"Cards stack vertically")
	_expect(game.card_buttons.all(func(b):return b.get_global_rect().end.y<game.get_viewport_rect().size.y),"All choice cards fit one screen")
	_expect(game.card_descriptions.all(func(b):return b.size.y>=90),"Choice descriptions have readable height")
	game.phase="playing"
	game._refresh()
	game._show_augment_details("survey")
	await _capture("04-phone-details.png")
	game._close_augment_details()
	game.difficulty="hard"
	game.stage=10
	game._start_stage()
	await create_timer(0.3).timeout
	await _capture("05-phone-stage10.png")

	_expect(game.tile_buttons.all(func(b):return b.size.x==b.size.y),"Large board preserves square tiles")
	_expect(game.grid.size.x+24<=game.board_scroll.size.x and game.grid.size.y+24<=game.board_scroll.size.y,"Stage transition fits the entire board")
	_expect(game.tile_buttons.all(func(b):return b.tooltip_text.is_empty()),"Mobile tiles have no tooltips")
	game.stage=1
	game._start_stage()
	await create_timer(0.3).timeout
	game.generated=true
	game.money=4
	game.mine_count=2
	for i in range(game.cells.size()):
		game.cells[i].mine=i in [9,63]
		game.cells[i].adjacent=1
		game.cells[i].revealed= i==0 or (i not in [1,8,9,63])
	game.cells[9].settled=true
	game.cells[9].committed=true
	game._set_flag_mode(true)
	game._flag_mode_tap(0)
	_expect(game.cells[1].revealed and game.cells[8].revealed and game.money==0,"Flag mode number tap chords with exact total gold")
	game.cells[1].revealed=false
	game.cells[8].revealed=false
	game.money=3
	game._flag_mode_tap(0)
	_expect(not game.cells[1].revealed and not game.cells[8].revealed and game.money==3,"Flag mode chord rejects insufficient total gold")
	print("MOBILE GUI ",checks," failures ",failures)
	quit(failures)
