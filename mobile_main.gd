extends "res://main.gd"

var mobile = false
var mobile_flag = false
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
	get_window().size_changed.connect(_check_mobile)
	_check_mobile()

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
		detail_art.custom_minimum_size = Vector2(100,100)
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
	mobile_zoom = clampf(value,0.75,2.0)
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
	if mobile: _set_flag_mode(false)

func _refresh():
	super._refresh()
	if is_instance_valid(mobile_commit):
		mobile_commit.disabled = commit_button.disabled or effect_busy
		mobile_commit.text = "COMMIT %d" % _pending_flags().size()
		mobile_cancel.disabled = targeting.is_empty()

func _show_augment_details(id: String):
	if mobile: drawer.hide()
	super._show_augment_details(id)

func _on_tile_input(event, index):
	if mobile and event is InputEventMouseButton:
		if event.device == -1: return
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and targeting.is_empty() and mobile_flag:
			if phase == "playing" and not detail_overlay.visible and not ticket_overlay.visible and not drawer.visible and not effect_busy: _toggle_flag(index)
			return
	super._on_tile_input(event,index)

func _touch_allowed() -> bool:
	return mobile and phase == "playing" and not effect_busy and not detail_overlay.visible and not ticket_overlay.visible and not drawer.visible and not mode_overlay.visible

func _input(event):
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
					elif mobile_flag: _toggle_flag(i)
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
