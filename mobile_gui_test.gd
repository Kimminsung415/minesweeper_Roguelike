extends "res://gui_test.gd"
func _run():
	capture_dir="C:/Users/Minsung/Documents/Codex/2026-10-28/new-chat/outputs/v1.3.0-build009-preview"
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
	game.phase="playing"
	game._refresh()
	game._show_augment_details("survey")
	await _capture("04-phone-details.png")
	game._close_augment_details()
	game.difficulty="hard"
	game.stage=10
	game._start_stage()
	await _capture("05-phone-stage10.png")
	_expect(game.tile_buttons.all(func(b):return b.size.x==b.size.y and b.size.x>=39),"Large board preserves touch-size square tiles")
	print("MOBILE GUI ",checks," failures ",failures)
	quit(failures)
