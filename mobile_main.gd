extends "res://main.gd"

var choice_scroll: ScrollContainer
var choice_touch_index = -1
var choice_touch_origin = Vector2.ZERO
var choice_dragged = false
var desktop_detail_buttons = []
var choice_info_text: Label
var choice_info_art: TextureRect
var choice_info: ConfirmationDialog
var choice_info_slot = -1
var mobile = false
var mobile_flag = false
var mobile_fit_zoom = 0.15
var mobile_zoom = 1.0
var mobile_bar: VBoxContainer
var mobile_dig: Button
var mobile_flag_button: Button
var mobile_commit: Button
var mobile_cancel: Button
var drawer: Control
var side_panel: Control
var fingers = {}
var touch_origin = Vector2.ZERO
var touch_cancelled = false
var touch_board = false

func _ready():
	super._ready()
	_build_choice_preview()
	get_window().size_changed.connect(_check_mobile)
	_check_mobile()
	if not mobile:
		for i in range(card_buttons.size()):
			var button = Button.new()
			button.text = "상세 · 레벨별 수치"
			button.custom_minimum_size.y = 44
			button.pressed.connect(_preview_choice.bind(i))
			var slot = card_buttons[i].get_parent()
			slot.add_child(button)
			slot.move_child(button,0)
			desktop_detail_buttons.append(button)

func _check_mobile():
	var browser_touch = false
	if OS.has_feature("web"):
		browser_touch = bool(JavaScriptBridge.eval("window.matchMedia('(pointer: coarse)').matches || window.innerWidth < 900"))
	if not mobile and (browser_touch or OS.has_feature("mobile") or (DisplayServer.get_name() != "headless" and get_window().size.x < 900)):
		_enable_mobile()
	if mobile:
		var window_size = get_window().size
		get_window().content_scale_size = Vector2i(520,maxi(580,roundi(520.0*window_size.y/maxi(1,window_size.x))))

func _enable_mobile():
	mobile = true
	for button in desktop_detail_buttons: button.hide()
	var body = board_scroll.get_parent().get_parent()
	var layout = body.get_parent()
	side_panel = sidebar_scroll.get_parent()
	drawer = Control.new()
	drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(drawer)
	var shade = ColorRect.new()
	shade.color = Color(0,0,0,0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer.add_child(shade)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,12)
	drawer.add_child(margin)
	var column = VBoxContainer.new()
	margin.add_child(column)
	var close = Button.new()
	close.text = "닫기 · 보드로 돌아가기"
	close.custom_minimum_size.y = 62
	close.pressed.connect(func(): drawer.hide())
	column.add_child(close)
	side_panel.reparent(column)
	side_panel.custom_minimum_size.x = 0
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer.hide()
	mobile_bar = VBoxContainer.new()
	layout.add_child(mobile_bar)
	var row = HBoxContainer.new()
	mobile_bar.add_child(row)
	mobile_dig = _touch_button(row,"⛏ 파기",func(): _set_flag_mode(false))
	mobile_flag_button = _touch_button(row,"🚩 깃발",func(): _set_flag_mode(true))
	mobile_commit = _touch_button(row,"COMMIT",_commit_flags)
	var tools = HBoxContainer.new()
	mobile_bar.add_child(tools)
	_touch_button(tools,"−",func(): _zoom_to(mobile_zoom-0.2))
	_touch_button(tools,"+",func(): _zoom_to(mobile_zoom+0.2))
	_touch_button(tools,"증강",func(): drawer.show(); move_child(drawer,get_child_count()-1))
	mobile_cancel = _touch_button(tools,"대상 취소",_cancel_target)
	for child in layout.get_children():
		if child is Label: child.hide()
	stats_label.hide()
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_label.add_theme_font_size_override("font_size",16)
	for label in [remaining_mines_label,special_mines_label,stage_label]:
		label.add_theme_font_size_override("font_size",17)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var heading = layout.get_child(0)
	heading.get_child(1).hide()
	for overlay in [choice_overlay,detail_overlay,ticket_overlay,mode_overlay]:
		_mobile_dialog(overlay)
	_set_flag_mode(false)
	_apply_tile_zoom()
	_fit_board.call_deferred()
	for button in tile_buttons: button.tooltip_text = ""
	_refresh()

func _touch_button(parent: Node, title: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0,64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size",20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _mobile_dialog(overlay: Control):
	var center: CenterContainer
	for child in overlay.get_children():
		if child is CenterContainer: center = child
	if center == null: return
	var panel = center.get_child(0)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_right = -12
	scroll.offset_top = 12
	scroll.offset_bottom = -12
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if overlay == choice_overlay:
		choice_scroll = scroll
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
		scroll.scroll_deadzone = 12
		scroll.follow_focus = true
	overlay.add_child(scroll)
	panel.reparent(scroll)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.queue_free()
	_compact_tree(panel)
	if overlay == choice_overlay:
		var stack = VBoxContainer.new()
		var parent = choice_cards.get_parent()
		var index = choice_cards.get_index()
		parent.add_child(stack)
		parent.move_child(stack,index)
		for child in choice_cards.get_children(): child.reparent(stack)
		choice_cards.queue_free()
		choice_cards = stack
		choice_cards.add_theme_constant_override("separation",8)
		choice_header.add_theme_font_size_override("font_size",24)
		for i in range(card_buttons.size()):
			var card = card_buttons[i]
			card.custom_minimum_size.y = 178
			var margin = card.get_child(0)
			for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,10)
			var content = margin.get_child(0)
			content.add_theme_constant_override("separation",6)
			var heading = HBoxContainer.new()
			heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(heading)
			content.move_child(heading,0)
			card_art[i].reparent(heading)
			card_art[i].custom_minimum_size = Vector2(44,44)
			card_art[i].size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			card_titles[i].reparent(heading)
			card_titles[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card_titles[i].add_theme_font_size_override("font_size",20)
			card_descriptions[i].add_theme_font_size_override("font_size",18)
			card_descriptions[i].custom_minimum_size.y = 90
			card_descriptions[i].max_lines_visible = 3
			card_descriptions[i].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var tools = HBoxContainer.new()
			var slot = card.get_parent()
			slot.add_child(tools)
			slot.move_child(tools,0)
			reroll_buttons[i].reparent(tools)
			reroll_buttons[i].custom_minimum_size.y = 42
			reroll_buttons[i].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var info = Button.new()
			info.text = "상세"
			info.custom_minimum_size = Vector2(80,42)
			info.pressed.connect(_preview_choice.bind(i))
			tools.add_child(info)
	if overlay == detail_overlay:
		# Stack artwork above a readable, independently scrolling description.
		var old_row = detail_art.get_parent()
		var stack = VBoxContainer.new()
		var parent = old_row.get_parent()
		var index = old_row.get_index()
		parent.add_child(stack)
		parent.move_child(stack,index)
		detail_art.reparent(stack)
		detail_scroll.reparent(stack)
		detail_art.custom_minimum_size = Vector2(180,180)
		detail_scroll.custom_minimum_size.y = 340
		old_row.queue_free()
		detail_close_button.custom_minimum_size = Vector2(92,60)
		detail_title.add_theme_font_size_override("font_size",24)
		var old_footer = detail_use_button.get_parent()
		var footer = VBoxContainer.new()
		var footer_parent = old_footer.get_parent()
		var footer_index = old_footer.get_index()
		footer_parent.add_child(footer)
		footer_parent.move_child(footer,footer_index)
		for child in old_footer.get_children(): child.reparent(footer)
		old_footer.queue_free()

func _compact_tree(node: Node):
	if node is Control:
		node.custom_minimum_size.x = 0
	if node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if node is Button:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.custom_minimum_size.y = maxf(60,node.custom_minimum_size.y)
	for child in node.get_children(): _compact_tree(child)

func _set_flag_mode(value: bool):
	mobile_flag = value
	mobile_dig.modulate = Color.WHITE if mobile_flag else Color("#ffe08b")
	mobile_flag_button.modulate = Color("#ffe08b") if mobile_flag else Color.WHITE
	mobile_dig.text = "파기" if mobile_flag else "✓ 파기"
	mobile_flag_button.text = "✓ 깃발" if mobile_flag else "깃발"

func _zoom_to(value: float):
	if effect_busy: return
	mobile_zoom = clampf(value,mobile_fit_zoom,2.0)
	_apply_tile_zoom()

func _apply_tile_zoom():
	if not mobile: return
	var pixels = roundi(52*mobile_zoom)
	for button in tile_buttons:
		button.custom_minimum_size = Vector2(pixels,pixels)
		button.add_theme_font_size_override("font_size",roundi(28*mobile_zoom))

func _build_board_view():
	super._build_board_view()
	fingers.clear()
	touch_cancelled = true
	mobile_zoom = 1.0
	_apply_tile_zoom()
	if mobile:
		_set_flag_mode(false)
		_fit_board.call_deferred()

func _refresh():
	super._refresh()
	if is_instance_valid(mobile_commit):
		mobile_commit.disabled = commit_button.disabled or effect_busy
		mobile_commit.text = "COMMIT %d" % _pending_flags().size()
		mobile_cancel.disabled = targeting.is_empty()
		if phase == "augment":
			choice_subtitle.text = "카드를 눌러 선택 · 위아래 스크롤 가능 · 상세로 설명 확인"
			for i in range(offered_augments.size()):
				var id = offered_augments[i]
				card_titles[i].text = "[%s] %s" % [Copy.kind(id),Augments.ALL[id]["name"]]

func _show_augment_details(id: String):
	if mobile: drawer.hide()
	super._show_augment_details(id)

func _on_tile_input(event, index):
	if mobile and event is InputEventMouseButton:
		if event.device == -1: return
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and targeting.is_empty() and mobile_flag:
			if phase == "playing" and not detail_overlay.visible and not ticket_overlay.visible and not drawer.visible and not effect_busy: _flag_mode_tap(index)
			return
	super._on_tile_input(event,index)

func _touch_allowed() -> bool:
	return mobile and phase == "playing" and not effect_busy and not detail_overlay.visible and not ticket_overlay.visible and not drawer.visible and not mode_overlay.visible

func _input(event):
	if mobile and phase == "augment" and not effect_busy and not choice_info.visible:
		if event is InputEventMouseButton and event.device == -1:
			get_viewport().set_input_as_handled()
			return
		if (event is InputEventScreenTouch or event is InputEventScreenDrag) and _choice_touch(event):
			get_viewport().set_input_as_handled()
			return
	if mobile and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		if _board_touch(event):
			get_viewport().set_input_as_handled()
			return
	super._input(event)

func _board_touch(event) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _touch_allowed() or not board_scroll.get_global_rect().has_point(event.position): return false
			if fingers.is_empty():
				touch_origin = event.position
				touch_cancelled = false
				touch_board = true
			fingers[event.index] = event.position
			if fingers.size()>1: touch_cancelled = true
			return true
		if not fingers.has(event.index): return false
		fingers.erase(event.index)
		if fingers.is_empty() and touch_board and not touch_cancelled and _touch_allowed() and board_scroll.get_global_rect().has_point(event.position):
			for i in range(tile_buttons.size()):
				if tile_buttons[i].get_global_rect().has_point(event.position):
					if not targeting.is_empty(): _use_active(targeting,i)
					elif mobile_flag: _flag_mode_tap(i)
					else: _dig(i)
					break
		if fingers.is_empty(): touch_board=false
		return true
	if not fingers.has(event.index): return false
	if event.position.distance_to(touch_origin)>10: touch_cancelled=true
	if fingers.size()==2:
		var keys = fingers.keys()
		var a = fingers[keys[0]]
		var b = fingers[keys[1]]
		var before = a.distance_to(b)
		var old_center = (a+b)/2
		fingers[event.index] = event.position
		a = fingers[keys[0]]
		b = fingers[keys[1]]
		var shift = (a+b)/2-old_center
		board_scroll.scroll_horizontal -= roundi(shift.x)
		board_scroll.scroll_vertical -= roundi(shift.y)
		if before>20: _zoom_to(mobile_zoom*a.distance_to(b)/before)
	else: fingers[event.index] = event.position
	return true


func _refresh_tile(index):
	super._refresh_tile(index)
	if mobile: tile_buttons[index].tooltip_text = ""

func _flag_mode_tap(index: int):
	if cells[index]["revealed"] and not cells[index]["mine"] and cells[index]["adjacent"] > 0:
		_dig(index)
	else:
		_toggle_flag(index)

func _preview_choice(slot: int):
	if effect_busy or phase != "augment" or slot >= offered_augments.size(): return
	choice_info_slot = slot
	var id = offered_augments[slot]
	choice_info_art.texture = Art.texture_for(id)
	choice_info_text.text = Copy.details(id,int(offered_levels.get(id,1)))
	choice_info.popup_centered(Vector2i(460,660))


func _fit_board():
	if not mobile or not is_instance_valid(board_scroll): return
	await get_tree().process_frame
	await get_tree().process_frame
	var pixels = maxi(6,mini(52,floori(minf((board_scroll.size.x-36)/board_width,(board_scroll.size.y-36)/board_height))))
	mobile_fit_zoom = pixels/52.0
	mobile_zoom = mobile_fit_zoom
	_apply_tile_zoom()
	await get_tree().process_frame
	board_scroll.scroll_horizontal = 0
	board_scroll.scroll_vertical = 0


func _build_choice_preview():
	choice_info = ConfirmationDialog.new()
	choice_info.title = "증강 상세"
	choice_info.ok_button_text = "이 증강 선택"
	choice_info.cancel_button_text = "돌아가기"
	choice_info.dialog_autowrap = true
	choice_info_art = TextureRect.new()
	choice_info_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	choice_info_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	choice_info_art.custom_minimum_size = Vector2(0,180)
	choice_info_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_content = VBoxContainer.new()
	preview_content.custom_minimum_size.x = 420
	preview_content.add_theme_constant_override("separation",16)
	choice_info.add_child(preview_content)
	preview_content.add_child(choice_info_art)
	choice_info_text = Label.new()
	choice_info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_info_text.custom_minimum_size = Vector2.ZERO
	choice_info_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_info_text.add_theme_color_override("font_color",Color("#f5f5f5"))
	var preview_scroll = ScrollContainer.new()
	preview_scroll.custom_minimum_size = Vector2(420,360)
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preview_content.add_child(preview_scroll)
	preview_scroll.add_child(choice_info_text)
	choice_info.confirmed.connect(func(): _select_card(choice_info_slot))
	add_child(choice_info)



func _choice_touch(event) -> bool:
	if not is_instance_valid(choice_scroll): return false
	if event is InputEventScreenTouch:
		if event.pressed:
			if not choice_scroll.get_global_rect().has_point(event.position): return false
			if choice_touch_index != -1:
				choice_dragged = true
				return true
			choice_touch_index = event.index
			choice_touch_origin = event.position
			choice_dragged = false
			return true
		if event.index != choice_touch_index: return false
		choice_touch_index = -1
		if not choice_dragged and choice_scroll.get_global_rect().has_point(event.position):
			_choice_tap(choice_cards,event.position)
		return true
	if event.index != choice_touch_index: return false
	if event.position.distance_to(choice_touch_origin)>10: choice_dragged = true
	if choice_dragged: choice_scroll.scroll_vertical -= roundi(event.relative.y)
	return true

func _choice_tap(node: Node, position: Vector2) -> bool:
	if node is Button and node.is_visible_in_tree() and not node.disabled and node.get_global_rect().has_point(position):
		node.pressed.emit()
		return true
	for child in node.get_children():
		if _choice_tap(child,position): return true
	return false
