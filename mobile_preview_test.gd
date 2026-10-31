extends "res://mobile_gui_test.gd"
func _capture(filename: String):
	await super._capture(filename)
	if filename=="03-phone-choice.png":
		game._preview_choice(0)
		await _frames()
		_expect(game.choice_info.visible,"Choice detail popup opens")
		_expect(game.choice_info.size.x<=game.get_viewport_rect().size.x,"Choice detail popup fits phone width")
		_expect(game.choice_info_art.texture!=null and game.choice_info_art.size.y>=180,"Choice preview has large artwork")
		root.get_texture().get_image().save_png("C:/Users/Minsung/Documents/Codex/2026-10-28/new-chat/outputs/augment-detail-large.png")
		game.choice_info.hide()
