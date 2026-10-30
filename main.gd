extends "res://run_model.gd"
const Widgets = preload("res://classic_widgets.gd")
const Art = preload("res://augment_art.gd")
const TicketArt = preload("res://ticket_animation.gd")

var mode_overlay: Control
var stats_label: Label
var rules_label: Label
var message_label: Label
var grid: GridContainer
var tile_buttons = []
var commit_button: Button
var reward_panel: VBoxContainer
var money_reward_button: Button
var heal_reward_button: Button
var abandon_button: Button
var progress_bar: ProgressBar
var progress_label: Label
var reward_hint: Label
var stage_label: Label
var hp_label
var money_label
var face_button
var tile_styles = {}
var current_hover = -1
var choice_overlay: Control
var choice_header: Label
var choice_subtitle: Label
var choice_cards: HBoxContainer
var card_buttons = []
var card_titles = []
var card_descriptions = []
var card_art = []
var victory_panel: VBoxContainer
var victory_label: Label
var inventory_label: Label
var action_status: Label
var active_list: VBoxContainer
var active_buttons = {}
var cancel_target_button: Button
var inventory_cards: VBoxContainer
var owned_cards = {}
var detail_overlay: Control
var detail_id = ""
var detail_title: Label
var detail_art: TextureRect
var detail_description: Label
var detail_status: Label
var detail_notes: Label
var detail_scroll: ScrollContainer
var detail_upgrade_button: Button
var detail_use_button: Button
var detail_close_button: Button
var sidebar_scroll: ScrollContainer
var remaining_mines_label: Label
var special_mines_label: Label
var board_scroll: ScrollContainer
var shop_label: Label
var shop_button: Button
var shop_jump_button: Button
var shop_status: Label
var damage_flash: ColorRect
var damage_flash_remaining = 0.0
var release_info = {}
var ticket_overlay: Control
var ticket_title: Label
var ticket_subtitle: Label
var ticket_status: Label
var ticket_visual
var ticket_progress: ProgressBar
var ticket_close_button: Button
var ticket_elapsed = 0.0
var ticket_snapshot = {}
const TICKET_ANIMATION_DURATION = 2.2


func _ready():
	Engine.max_fps = 30
	OS.low_processor_usage_mode = true
	release_info = JSON.parse_string(FileAccess.get_file_as_string("res://release.json"))
	get_window().title = "Mine Ledger · v%s · build.%03d" % [release_info["version"], release_info["build"]]
	rng.randomize()
	_build_ui()
	_new_run()
	_build_mode_menu()
	_show_mode_menu()
	set_process(false)


func _build_ui():
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ui_theme = Theme.new()
	var font = FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	font.variation_opentype = {"wght": 750.0}
	font.variation_embolden = 0.8
	ui_theme.default_font = font
	ui_theme.default_font_size = 18
	ui_theme.set_color("font_color", "Label", Color("#202020"))
	for state in ["normal", "hover", "disabled"]:
		ui_theme.set_stylebox(state, "Button", Widgets.bevel(false, 10))
	ui_theme.set_stylebox("pressed", "Button", Widgets.bevel(true, 10))
	ui_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	ui_theme.set_color("font_color", "Button", Color.BLACK)
	ui_theme.set_color("font_hover_color", "Button", Color.BLACK)
	ui_theme.set_color("font_pressed_color", "Button", Color.BLACK)
	ui_theme.set_color("font_focus_color", "Button", Color.BLACK)
	ui_theme.set_color("font_hover_pressed_color", "Button", Color.BLACK)
	ui_theme.set_color("font_disabled_color", "Button", Color("#777777"))
	theme = ui_theme
	tile_styles["hidden"] = Widgets.bevel(false, 0)
	tile_styles["open"] = _flat("#c0c0c0", "#909090")
	tile_styles["flag"] = tile_styles["hidden"]
	tile_styles["paid"] = tile_styles["open"]
	tile_styles["mine"] = _flat("#ff2727", "#909090")
	tile_styles["mine_end"] = tile_styles["open"]
	var background = ColorRect.new()
	background.color = Color("#a6a6a6")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Widgets.bevel(false, 16))
	margin.add_child(frame)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	frame.add_child(layout)

	var heading = HBoxContainer.new()
	layout.add_child(heading)
	_label(heading, "지뢰찾기", 25, "#111111")
	_label(heading, "v%s · build.%03d" % [release_info["version"], release_info["build"]], 13, "#555555")
	stage_label = _label(heading, "", 20, "#333333")
	stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var board_column = VBoxContainer.new()
	board_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(board_column)
	stats_label = _label(board_column, "", 17, "#333333")
	var scroll = ScrollContainer.new()
	board_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_column.add_child(scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var cabinet = PanelContainer.new()
	cabinet.add_theme_stylebox_override("panel", Widgets.bevel(false, 12))
	center.add_child(cabinet)
	var cabinet_layout = VBoxContainer.new()
	cabinet_layout.add_theme_constant_override("separation", 12)
	cabinet.add_child(cabinet_layout)

	var display_frame = PanelContainer.new()
	display_frame.add_theme_stylebox_override("panel", Widgets.bevel(true, 12))
	board_column.add_child(display_frame)
	board_column.move_child(display_frame, 1)
	var display_layout = VBoxContainer.new()
	display_layout.add_theme_constant_override("separation", 10)
	display_frame.add_child(display_layout)
	var display_row = HBoxContainer.new()
	display_row.add_theme_constant_override("separation", 16)
	display_layout.add_child(display_row)
	money_label = _counter(display_row, "GOLD")
	var smile_column = VBoxContainer.new()
	smile_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	display_row.add_child(smile_column)
	var face_center = CenterContainer.new()
	face_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	smile_column.add_child(face_center)
	face_button = Widgets.FaceButton.new()
	face_button.pressed.connect(_show_mode_menu)
	face_center.add_child(face_button)
	hp_label = _health_counter(display_row)
	var mine_row = HBoxContainer.new()
	mine_row.add_theme_constant_override("separation", 10)
	display_layout.add_child(mine_row)
	remaining_mines_label = _mine_counter(mine_row, "#172f46", "#f3f7ff")
	special_mines_label = _mine_counter(mine_row, "#49304c", "#ffe2f0")
	remaining_mines_label.tooltip_text = "전체 지뢰 중 아직 확인하지 않은 수입니다. Commit·직접 폭발·안전 굴착으로 확인하면 감소합니다. 미검증 깃발은 차감하지 않습니다."
	special_mines_label.tooltip_text = "남은 전체 지뢰에 포함된 은신지뢰 수입니다. 인접 숫자에는 집계되지 않습니다."

	var board_frame = PanelContainer.new()
	board_frame.add_theme_stylebox_override("panel", Widgets.bevel(true, 5))
	cabinet_layout.add_child(board_frame)
	grid = GridContainer.new()
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	board_frame.add_child(grid)
	progress_label = _label(board_column, "", 16, "#333333")
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 6
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _flat("#a0a0a0", "#808080"))
	progress_bar.add_theme_stylebox_override("fill", _flat("#000080", "#000080"))
	board_column.add_child(progress_bar)

	var sidebar_panel = PanelContainer.new()
	sidebar_panel.custom_minimum_size.x = 316
	sidebar_panel.add_theme_stylebox_override("panel", Widgets.bevel(true, 14))
	body.add_child(sidebar_panel)
	var side_scroll = ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_scroll = side_scroll
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_panel.add_child(side_scroll)
	var sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 0
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	side_scroll.add_child(sidebar)
	_label(sidebar, "탐색 / 정산", 20, "#111111")
	rules_label = _label(sidebar, "", 18, "#222222")
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	commit_button = Button.new()
	commit_button.custom_minimum_size.y = 50
	commit_button.pressed.connect(_commit_flags)
	sidebar.add_child(commit_button)
	_label(sidebar, "깃발은 무료입니다.\nCommit: Space / Enter", 14, "#444444")
	message_label = _label(sidebar, "", 16, "#000080")
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size.y = 76
	cancel_target_button = Button.new()
	cancel_target_button.text = "범위 선택 취소 (우클릭 / Esc)"
	cancel_target_button.pressed.connect(_cancel_target)
	sidebar.add_child(cancel_target_button)
	action_status = _label(sidebar, "", 16, "#333333")
	action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_jump_button = Button.new()
	shop_jump_button.custom_minimum_size.y = 40
	shop_jump_button.pressed.connect(_open_shop)
	sidebar.add_child(shop_jump_button)
	var shop_section = VBoxContainer.new()
	shop_section.add_theme_constant_override("separation", 8)
	_label(shop_section, "개별 증강 강화", 18, "#132e50")
	shop_label = _label(shop_section, "", 14, "#344459")
	shop_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_button = Button.new()
	shop_button.custom_minimum_size.y = 60
	shop_button.pressed.connect(_purchase_ticket)
	shop_section.add_child(shop_button)
	shop_status = _label(shop_section, "", 13, "#65417c")
	shop_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(sidebar, "보유 능력 · 클릭하여 상세보기", 17, "#111111")
	inventory_label = _label(sidebar, "", 14, "#333333")
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_cards = VBoxContainer.new()
	inventory_cards.add_theme_constant_override("separation", 8)
	sidebar.add_child(inventory_cards)
	for id in Augments.ALL:
		_create_owned_card(id)
	sidebar.add_child(shop_section)
	abandon_button = Button.new()
	abandon_button.text = "런 포기"
	abandon_button.pressed.connect(_abandon)
	sidebar.add_child(abandon_button)
	for control in sidebar.get_children():
		if control is Label or control is Button:
			control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_build_choice_overlay()
	_build_augment_details()
	_build_ticket_overlay()
	damage_flash = ColorRect.new()
	damage_flash.name = "DamageFlash"
	damage_flash.color = Color(1.0, 0.02, 0.02, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(damage_flash)

	var help_label = _label(layout, "좌클릭: 파기 / 숫자 칸 주변 파기 / 능력 대상 선택 · 우클릭: 깃발 / 대상 취소 · 스마일: 새 런\n숫자 칸 주변 파기: 지뢰 확인 완료(Commit·폭발·안전 확정) + 전체 비용 확보 · 깃발 칸 제외", 14, "#333333")
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_choice_overlay():
	choice_overlay = Control.new()
	choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(choice_overlay)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.52)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choice_overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 1080
	panel.add_theme_stylebox_override("panel", Widgets.bevel(false, 24))
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	choice_header = _label(column, "", 26, "#000080")
	choice_subtitle = _label(column, "", 16, "#222222")
	choice_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_cards = HBoxContainer.new()
	choice_cards.add_theme_constant_override("separation", 14)
	column.add_child(choice_cards)
	for i in range(3):
		var card = Button.new()
		card.custom_minimum_size = Vector2(330, 440)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_select_card.bind(i))
		choice_cards.add_child(card)
		card_buttons.append(card)
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for edge in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 20)
		card.add_child(margin)
		var content = VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_theme_constant_override("separation", 12)
		margin.add_child(content)
		var artwork = _art_view("", 160)
		artwork.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(artwork)
		card_art.append(artwork)
		var title = _label(content, "", 22, "#000080")
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_titles.append(title)
		var description = _label(content, "", 19, "#222222")
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_descriptions.append(description)
	reward_panel = VBoxContainer.new()
	reward_panel.add_theme_constant_override("separation", 8)
	column.add_child(reward_panel)
	_label(reward_panel, "추가 보상 · 골드 또는 회복", 20, "#000080")
	var reward_row = HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 14)
	reward_panel.add_child(reward_row)
	money_reward_button = Button.new()
	money_reward_button.custom_minimum_size.y = 48
	money_reward_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_reward_button.pressed.connect(_choose_reward.bind("money"))
	reward_row.add_child(money_reward_button)
	heal_reward_button = Button.new()
	heal_reward_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heal_reward_button.pressed.connect(_choose_reward.bind("heal"))
	reward_row.add_child(heal_reward_button)
	reward_hint = _label(reward_panel, "", 14, "#333333")
	victory_panel = VBoxContainer.new()
	column.add_child(victory_panel)
	victory_label = _label(victory_panel, "", 20, "#222222")
	var restart = Button.new()
	restart.text = "새로운 10스테이지 런 시작"
	restart.custom_minimum_size.y = 52
	restart.pressed.connect(_show_mode_menu)
	victory_panel.add_child(restart)


func _build_ticket_overlay():
	ticket_overlay = Control.new()
	ticket_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ticket_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ticket_overlay.hide()
	add_child(ticket_overlay)
	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.04, 0.08, 0.88)
	ticket_overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ticket_overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 620
	var style = _flat("#101d30", "#4a7799")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	for edge in ["left", "right", "top", "bottom"]:
		style.set("content_margin_" + edge, 28.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var caption = _label(column, "UPGRADE / 개별 증강 강화", 14, "#87afce")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticket_title = _label(column, "강화 진행 중", 31, "#eaf3ff")
	ticket_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticket_subtitle = _label(column, "", 17, "#c0d3e7")
	ticket_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticket_visual = TicketArt.new()
	ticket_visual.custom_minimum_size = Vector2(560, 260)
	ticket_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(ticket_visual)
	ticket_status = _label(column, "", 20, "#9bddff")
	ticket_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ticket_progress = ProgressBar.new()
	ticket_progress.custom_minimum_size.y = 8
	ticket_progress.show_percentage = false
	ticket_progress.max_value = 1
	ticket_progress.add_theme_stylebox_override("background", _flat("#23354a", "#23354a"))
	ticket_progress.add_theme_stylebox_override("fill", _flat("#64cfff", "#64cfff"))
	column.add_child(ticket_progress)
	ticket_close_button = Button.new()
	ticket_close_button.custom_minimum_size.y = 48
	ticket_close_button.pressed.connect(_close_ticket_result)
	column.add_child(ticket_close_button)
	var hint = _label(column, "표시된 확률로 1회 추첨 · 실패해도 골드는 소모됩니다", 14, "#92a7bf")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _flat(fill: String, border: String) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(1)
	return style


func _build_augment_details():
	detail_overlay = Control.new()
	detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_overlay.visible = false
	add_child(detail_overlay)
	var shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_on_detail_backdrop_input)
	detail_overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", Widgets.bevel(false, 24))
	center.add_child(panel)
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	panel.add_child(layout)
	var heading = HBoxContainer.new()
	layout.add_child(heading)
	detail_title = _label(heading, "", 27, "#132e50")
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_close_button = Button.new()
	detail_close_button.text = "닫기 ×"
	detail_close_button.pressed.connect(_close_augment_details)
	heading.add_child(detail_close_button)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.custom_minimum_size.y = 380
	layout.add_child(row)
	detail_art = _art_view("", 232)
	row.add_child(detail_art)
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail_scroll)
	var text_column = VBoxContainer.new()
	text_column.custom_minimum_size.x = 620
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(text_column)
	_label(text_column, "기본 효과", 16, "#526276")
	detail_description = _label(text_column, "", 21, "#182b40")
	detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(text_column, "현재 상태", 16, "#526276")
	detail_status = _label(text_column, "", 18, "#135b88")
	detail_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(text_column, "사용 방법 · 상호작용", 16, "#526276")
	detail_notes = _label(text_column, "", 17, "#344459")
	detail_notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	detail_use_button = Button.new()
	detail_use_button.custom_minimum_size.y = 50
	detail_use_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_use_button.pressed.connect(_use_detailed_active)
	footer.add_child(detail_use_button)
	detail_upgrade_button = Button.new()
	detail_upgrade_button.custom_minimum_size.y = 50
	detail_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_upgrade_button.pressed.connect(_upgrade_detailed)
	footer.add_child(detail_upgrade_button)
	var close_bottom = Button.new()
	close_bottom.text = "설명 닫기"
	close_bottom.custom_minimum_size.y = 50
	close_bottom.pressed.connect(_close_augment_details)
	footer.add_child(close_bottom)
	_label(layout, "설명을 여는 것만으로는 능력이 사용되지 않습니다. Esc 또는 바깥을 눌러 닫기", 14, "#526276")


func _show_augment_details(id: String):
	if ticket_overlay.visible:
		return
	if not _has(id) or not Augments.ALL.has(id) or phase in ["augment", "reward", "victory"]:
		return
	detail_id = id
	detail_overlay.show()
	_refresh_augment_details()
	detail_scroll.scroll_vertical = 0
	detail_close_button.grab_focus()


func _close_augment_details():
	detail_overlay.hide()
	detail_id = ""


func _on_detail_backdrop_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_augment_details()
		get_viewport().set_input_as_handled()


func _use_detailed_active():
	if detail_id.is_empty() or not _active_available(detail_id):
		return
	var id = detail_id
	_close_augment_details()
	if targeting == id:
		message = "보드에서 대상 칸을 선택하세요. 우클릭 또는 Esc로 취소."
		_refresh()
	else:
		_activate_active(id)


func _refresh_augment_details():
	if detail_id.is_empty() or not is_instance_valid(detail_overlay):
		return
	if not _has(detail_id) or phase in ["augment", "reward", "victory"]:
		_close_augment_details()
		return
	var item = Augments.ALL[detail_id]
	detail_title.text = "%s · %s" % [item["name"], Augments.kind_label(item["kind"])] + (" · Lv.%d / 4" % _level(detail_id) if Upgrades.DATA.has(detail_id) else "")
	detail_art.texture = Art.texture_for(detail_id)
	detail_description.text = item["description"]
	var status = "스테이지 %d / 10\n" % stage
	if item["kind"] == Augments.ACTIVE:
		status += "이번 스테이지 남은 사용: %d / 1회" % (0 if detail_id in used_actives else 1)
		if phase != "playing":
			status += "\n런이 종료되어 사용할 수 없습니다."
		elif not generated:
			status += "\n첫 유효한 직접 파기로 보드를 생성한 뒤 사용 가능합니다."
		elif detail_id in used_actives:
			status += "\n다음 스테이지에서 다시 사용할 수 있습니다."
		elif detail_id == "blood_trade" and hp < 3:
			status += "\n현재 HP가 부족합니다. HP 3 이상에서 사용할 수 있습니다."
		else:
			status += "\n사용 가능 · 골드 소모 없음"
	else:
		status += "자동 적용 중 · 별도의 사용 버튼이 없는 효과입니다." if phase == "playing" else "런 종료 · 마지막 보유 효과 기록입니다."
	match detail_id:
		"domain", "scanner", "safe_dig":
			var side = _active_radius(detail_id) * 2 + 1
			status += "\n현재 범위 %d×%d · 영역 확장 Lv.%d" % [side, side, expansion_level]
			if detail_id == "scanner" and not scan_result.is_empty():
				status += "\n마지막 스캔 당시 미확정 지뢰: %d개" % scan_result["count"]
		"vitality": status += "\n현재 최대 HP %d · 이번 스테이지 추가 최대 HP +%d" % [max_hp, vitality_bonus]
		"transfusion": status += "\n현재 회복량 +%d HP · 현재 HP %d / %d" % [_heal_amount(3), hp, max_hp]
		"blood_trade": status += "\nHP 2 지불 → +%d골드 · 현재 HP %d" % [dig_cost * 6, hp]
		"insurance": status += "\n다음 수동 Commit 보호: %s" % ("준비" if insurance_ready else "없음")
		"heart": status += "\n현재 최대 HP %d (강화 심장 +3 포함)" % max_hp
		"medic": status += "\n클리어 회복 +%d HP" % _heal_amount(1)
		"reserve": status += "\n이번 스테이지 시작 보장액 %d골드 · 시작 시에만 적용" % (dig_cost * 3)
		"healing_loss": status += "\n긴급 수혈 +%d / 보상 회복 +%d HP" % [_heal_amount(3), _heal_amount(HEAL_REWARD)]
		"settlement_fee": status += "\n정답이 있는 Commit마다 최대 %d골드 차감" % dig_cost
		"revival": status += "\n런 전체 부활권: %s" % ("이미 소모됨" if revival_used else "1회 남음")
		"echo": status += "\n이번 스테이지 추가 공개: %d / 4회 사용" % echo_uses
		"frugal": status += "\n처음 3회 중 남은 무료 직접 파기: %d회" % maxi(0, 3 - direct_digs)
		"regeneration", "unstable_ground": status += "\n직접 파기 %d회 · 다음 6회 주기까지 %d회" % [direct_digs, 6 - direct_digs % 6]
		"shock": status += "\n첫 직접 지뢰 피해: %s" % ("이미 발생함" if shock_triggered else "아직 발생하지 않음")
		"dividend": status += "\n첫 직접 지뢰 폭발: %s" % ("이미 발생함" if first_explosion else "아직 발생하지 않음")
		"shield": status += "\n다음 직접 파기 방폭: %s" % ("준비됨" if shield_ready else "준비되지 않음")
		"acceleration": status += "\n대기 중인 무료 직접 파기: %d회" % accelerated_digs
		"weakness": status += "\n현재 HP: %d / %d" % [hp, max_hp]
		"grant": status += "\n현재 지급액: %d골드 (파기 %d × 4)" % [dig_cost * 4, dig_cost]
		"armor", "high_explosive": status += "\n현재 직접 지뢰 피해: %d HP · 오답 Commit: %d HP / 개" % [_mine_damage(), _wrong_flag_damage()]
		"salvage": status += "\n현재 잔해 회수 수입: %d골드 / 지뢰" % floori(mine_reward * 0.5)
		"artisan", "reward_cut": status += "\n현재 지뢰 1개분 정산 보상: %d골드" % mine_reward
		"dig_tax": status += "\n현재 기본 파기 비용: %d골드 (무료 효과는 별도)" % dig_cost
		"interference": status += "\n현재 미검증 깃발: %d개" % _pending_flags().size()
		"stealth": status += "\n이 스테이지 은신지뢰: %d개" % stealth_count
	if Upgrades.DATA.has(detail_id):
		status = "현재 Lv.%d: %s" % [_level(detail_id), Upgrades.describe(detail_id, _level(detail_id))]
		status += "\n다음 Lv.%d: %s" % [_level(detail_id)+1, Upgrades.describe(detail_id, _level(detail_id)+1)] if _level(detail_id)<4 else "\n최대 레벨"
		status += "\n현재 HP %d/%d" % [hp,max_hp]
		if item["kind"] == Augments.ACTIVE:
			status += " · " + ("이번 스테이지 사용 완료" if detail_id in used_actives else "1회 사용 가능 (첫 파기 후)")
		if detail_id == "revival":
			status += " · 부활권 " + ("소모됨 · 강화해도 재충전 없음" if revival_used else "1회 남음")
	detail_upgrade_button.visible = Upgrades.DATA.has(detail_id)
	detail_upgrade_button.disabled = not _can_upgrade(detail_id)
	detail_upgrade_button.text = "최대 레벨" if _level(detail_id)>=4 else "강화 · %d골드 · %d%%" % [_ticket_cost_for(detail_id), [30,20,10][_level(detail_id)-1]]
	detail_status.text = status
	var notes = "보유 효과는 런 종료까지 유지되며, 같은 효과는 중복 획득하지 않습니다."
	if item["kind"] == Augments.ACTIVE:
		notes = "각 능력은 스테이지당 1회, 골드 소모 없이 사용합니다.\n"
		notes += "아래 ‘대상 선택’을 누른 뒤 보드의 칸을 좌클릭하세요. 우클릭 또는 Esc로 취소하며 취소 시 횟수를 소모하지 않습니다." if item.get("target", false) else "아래 ‘능력 사용’을 누르면 즉시 발동합니다. 적용할 대상이 없으면 사용 횟수를 보존합니다."
		notes += "\n액티브 공개는 직접 파기 횟수에 포함되지 않습니다."
	elif item["kind"] == Augments.PASSIVE:
		notes += "\n직접 파기·Commit 등 설명에 적힌 조건을 만족하면 자동 발동합니다."
	else:
		notes += "\n해제 버튼은 없으며, 다음 스테이지에도 계속 적용됩니다."
	var extra = {
		"domain": "범위 밖 연쇄 공개는 없습니다. 자동 정산에도 신관 피해와 정산 장인 보상이 적용됩니다.",
		"hound": "은신지뢰도 탐지합니다. 자동 정산이므로 불안정한 신관 피해가 발생할 수 있습니다.",
		"scanner": "위치나 안전 칸을 공개하지 않습니다. 파란 범위의 개수는 스캔 당시 값이며 이후 정산으로 자동 갱신되지 않습니다.",
		"safe_dig": "지뢰는 보상·피해·신관 부작용 없이 확인합니다. 확인한 지뢰는 숫자 칸 주변 파기 조건에도 포함됩니다.",
		"shield": "안전 칸을 파도 다음 유효한 직접 파기 1회에 소모됩니다. 불안정 지반 피해는 막지 않습니다.",
		"revival": "스테이지가 바뀌어도 소모 기록은 유지됩니다. 치명적 피해 → 부활 → 생존 시 회복 순서로 처리됩니다.",
		"shock": "치명적 피해는 단독으로 막지 못합니다. 부활권으로 살아난 경우에는 회복이 이어질 수 있습니다.",
		"echo": "추가 공개는 또 다른 공명이나 연쇄 공개를 일으키지 않습니다. 주변 일괄 파기 중에도 직접 파기마다 적용됩니다.",
		"acceleration": "알뜰 굴착과 겹치는 파기는 두 효과의 횟수에 함께 포함됩니다. 무료 파기도 지반·재생 주기에는 포함됩니다.",
		"stealth": "숫자에 집계되지 않습니다. 빈칸 연쇄 공개는 건너뛰지만 직접 파기와 숫자 칸 주변 파기로는 폭발할 수 있습니다.",
		"instrument": "? 타일은 숫자 칸 주변 파기를 사용할 수 없습니다. 실제 인접 수와 스캐너의 계산은 유지됩니다.",
		"fuse": "방폭복·방폭 태세로 막을 수 없는 Commit 부작용입니다. 정답 보상은 정상 지급하고, 치명적 피해에는 부활권을 적용합니다.",
	}
	if extra.has(detail_id):
		notes += "\n\n" + extra[detail_id]
	detail_notes.text = notes
	detail_use_button.visible = item["kind"] == Augments.ACTIVE
	detail_use_button.disabled = not _active_available(detail_id)
	detail_use_button.text = "대상 선택 · 무료 사용" if item.get("target", false) else "능력 사용 · 무료"
	if phase != "playing":
		detail_use_button.text = "런 종료 · 사용 불가"
	elif detail_id in used_actives:
		detail_use_button.text = "이번 스테이지 사용 완료"
	elif detail_id == "blood_trade" and hp < 3:
		detail_use_button.text = "HP 3 이상 필요"
	elif not generated:
		detail_use_button.text = "첫 파기 후 사용 가능"


func _label(parent: Node, value: String, font_size: int, color: String) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(color))
	parent.add_child(label)
	return label


func _counter(parent: Node, caption: String):
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	var caption_row = HBoxContainer.new()
	caption_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(caption_row)
	var coin = Widgets.CoinIcon.new()
	coin.name = "GoldCoin"
	caption_row.add_child(coin)
	_label(caption_row, caption, 14, "#222222")
	var bezel = PanelContainer.new()
	bezel.add_theme_stylebox_override("panel", Widgets.bevel(true, 3))
	column.add_child(bezel)
	var display = Widgets.LedDisplay.new()
	bezel.add_child(display)
	return display


func _health_counter(parent: Node):
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	var caption = _label(column, "HP", 14, "#222222")
	caption.custom_minimum_size.y = 24
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bezel = PanelContainer.new()
	bezel.add_theme_stylebox_override("panel", Widgets.bevel(true, 3))
	column.add_child(bezel)
	var gauge = Widgets.HealthGauge.new()
	bezel.add_child(gauge)
	return gauge


func _mine_counter(parent: Node, background: String, foreground: String) -> Label:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = _flat(background, "#808080")
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var label = _label(panel, "", 23, foreground)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _art_view(id: String, pixels: int) -> TextureRect:
	var art = TextureRect.new()
	art.custom_minimum_size = Vector2(pixels, pixels)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not id.is_empty():
		art.texture = Art.texture_for(id)
	return art


func _ability_card_style(kind: String) -> StyleBoxFlat:
	var palette = {"active": ["#e4ecf7", "#6689b5"], "passive": ["#e4efe8", "#679882"], "debuff": ["#f4e6e9", "#b47b88"]}[kind]
	var style = _flat(palette[0], palette[1])
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _create_owned_card(id: String):
	var item = Augments.ALL[id]
	var is_active = item["kind"] == Augments.ACTIVE
	var card = Button.new()
	card.pressed.connect(_show_augment_details.bind(id))
	for state in ["normal", "hover", "pressed", "disabled"]:
		card.add_theme_stylebox_override(state, _ability_card_style(item["kind"]))
	if is_active:
		active_buttons[id] = card
	card.custom_minimum_size = Vector2(0, 90)
	card.tooltip_text = "%s [%s]\n%s" % [item["name"], Augments.kind_label(item["kind"]), item["description"]]
	inventory_cards.add_child(card)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 9)
	card.add_child(margin)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var icon = _art_view(id, 56)
	row.add_child(icon)
	var column = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var title = _label(column, item["name"], 17, "#1c2934")
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status = _label(column, Augments.kind_label(item["kind"]), 13, "#48627c")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var summary = _label(column, item["description"], 13, "#48525c")
	summary.clip_text = true
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owned_cards[id] = {"root": card, "icon": icon, "status": status, "title": title}


func _build_board_view():
	if is_instance_valid(ticket_overlay):
		ticket_overlay.hide()
		ticket_snapshot.clear()
	if is_instance_valid(sidebar_scroll):
		sidebar_scroll.scroll_vertical = 0
	damage_flash_remaining = 0.0
	if is_instance_valid(damage_flash):
		damage_flash.color.a = 0.0
	if is_instance_valid(detail_overlay):
		_close_augment_details()
	current_hover = -1
	tile_buttons.clear()
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	grid.columns = board_width
	var number_font = FontVariation.new()
	number_font.base_font = load("res://assets/fonts/NotoSansKR.ttf")
	number_font.variation_embolden = 1.0
	for i in range(cells.size()):
		var button = Widgets.TileButton.new()
		var tile_size = 44 if board_width <= 12 else (28 if board_width >= 26 else 30)
		button.custom_minimum_size = Vector2(tile_size, tile_size)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_size_override("font_size", 28 if board_width <= 12 else 22)
		button.add_theme_font_override("font", number_font)
		var mark = Widgets.TileMark.new()
		mark.name = "Mark"
		button.add_child(mark)
		button.gui_input.connect(_on_tile_input.bind(i))
		button.mouse_entered.connect(_on_tile_hover.bind(i))
		grid.add_child(button)
		tile_buttons.append(button)


func _on_tile_input(event, index):
	if phase != "playing" or detail_overlay.visible or ticket_overlay.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if targeting.is_empty():
				_dig(index)
			else:
				_use_active(targeting, index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			if targeting.is_empty():
				_toggle_flag(index)
			else:
				_cancel_target()


func _on_tile_hover(index):
	current_hover = index
	if not targeting.is_empty():
		for i in range(cells.size()):
			_refresh_tile(i)


func _input(event):
	if phase == "menu":
		return
	if is_instance_valid(ticket_overlay) and ticket_overlay.visible and event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo and ticket_pending.is_empty() and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_close_ticket_result()
		return
	if event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and not detail_overlay.visible:
		# Handle before focused buttons: Enter must not dig a tile or restart the run.
		get_viewport().set_input_as_handled()
		if not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and phase == "playing" and targeting.is_empty() and not commit_button.disabled:
			_commit_flags()
		return
	if not is_instance_valid(detail_overlay) or not detail_overlay.visible or not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		_close_augment_details()
		get_viewport().set_input_as_handled()
		return
	var focus = get_viewport().gui_get_focus_owner()
	if event.keycode == KEY_TAB:
		var controls = [detail_close_button]
		if detail_use_button.visible and not detail_use_button.disabled:
			controls.append(detail_use_button)
		if detail_upgrade_button.visible and not detail_upgrade_button.disabled:
			controls.append(detail_upgrade_button)
		var next = posmod(controls.find(focus) + (-1 if event.shift_pressed else 1), controls.size())
		controls[next].grab_focus()
		get_viewport().set_input_as_handled()
	elif focus == null or not detail_overlay.is_ancestor_of(focus):
		detail_close_button.grab_focus()
		get_viewport().set_input_as_handled()


func _on_damage(_amount: int):
	if is_instance_valid(damage_flash):
		set_process(true)
		damage_flash_remaining = 0.35
		damage_flash.color.a = 0.28


func _process(delta: float):
	if damage_flash_remaining > 0.0:
		damage_flash_remaining = maxf(0.0, damage_flash_remaining - delta)
		damage_flash.color.a = 0.28 * damage_flash_remaining / 0.35
	if is_instance_valid(ticket_overlay) and ticket_overlay.visible and not ticket_pending.is_empty():
		ticket_elapsed += delta
		ticket_visual.elapsed = ticket_elapsed
		if not ticket_pending.is_empty():
			var progress = minf(ticket_elapsed / TICKET_ANIMATION_DURATION, 1.0)
			ticket_visual.progress = progress
			ticket_progress.value = progress
			ticket_status.text = "마력 응축 중…" if progress < 0.55 else ("공명 확인 중…" if progress < 0.88 else "결과 판정…")
			if progress >= 1.0:
				_reveal_ticket_result()
		ticket_visual.queue_redraw()
	if damage_flash_remaining <= 0.0 and ticket_pending.is_empty():
		set_process(false)


func _upgrade_detailed():
	upgrade_target = detail_id
	_purchase_ticket()


func _purchase_ticket():
	if ticket_overlay.visible or not _begin_upgrade_ticket():
		return
	_close_augment_details()
	ticket_snapshot = ticket_pending.duplicate()
	ticket_elapsed = 0.0
	ticket_visual.elapsed = 0.0
	ticket_visual.progress = 0.0
	ticket_visual.result = "pending"
	ticket_progress.value = 0.0
	ticket_title.text = "강화 진행 중"
	ticket_title.add_theme_color_override("font_color", Color("#eaf3ff"))
	ticket_subtitle.text = "Lv.%d → Lv.%d · 성공률 %s%% · %d골드 사용" % [int(ticket_snapshot["level"]), int(ticket_snapshot["level"]) + 1, _ticket_chance_label(), ticket_snapshot["cost"]]
	ticket_status.text = "마력 응축 중…"
	ticket_close_button.text = "강화 진행 중…"
	ticket_close_button.disabled = true
	ticket_overlay.show()
	set_process(true)
	var focus = get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()


func _reveal_ticket_result():
	if ticket_pending.is_empty():
		return
	var success = ticket_pending["success"]
	_resolve_upgrade_ticket()
	ticket_visual.result = "success" if success else "failure"
	ticket_title.text = "%s 강화 성공!" % Augments.ALL[ticket_snapshot["id"]]["name"] if success else "강화 실패"
	ticket_title.add_theme_color_override("font_color", Color("#ffd478" if success else "#eaa4b3"))
	ticket_status.text = Upgrades.describe(ticket_snapshot["id"], _level(ticket_snapshot["id"])) if success else "레벨은 유지됩니다 · 사용한 골드는 소모되었습니다"
	ticket_close_button.text = "확인 · Enter / Space"
	ticket_close_button.disabled = false
	ticket_close_button.grab_focus()


func _close_ticket_result():
	if not ticket_pending.is_empty():
		return
	ticket_overlay.hide()
	ticket_snapshot.clear()
	if shop_button.is_visible_in_tree() and not shop_button.disabled:
		shop_button.grab_focus()


func _open_shop():
	sidebar_scroll.ensure_control_visible(inventory_cards)


func _ticket_chance_label() -> String:
	var percent = _ticket_chance() * 100
	return "<0.001" if percent < 0.001 else String.num(percent, 3).trim_suffix(".0")


func _unhandled_key_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not targeting.is_empty():
		_cancel_target()
		get_viewport().set_input_as_handled()


func _activate_active(id: String):
	if ticket_overlay.visible or not _active_available(id):
		return
	if Augments.ALL[id].get("target", false):
		if targeting == id:
			_cancel_target()
			return
		targeting = id
		message = "%s: 보드에서 대상 칸을 선택하세요.\n우클릭 또는 Esc로 취소 (횟수 보존)." % Augments.ALL[id]["name"]
		_refresh()
	else:
		_use_active(id)


func _cancel_target():
	targeting = ""
	current_hover = -1
	message = "대상 선택을 취소했습니다. 능력 사용 횟수는 유지됩니다."
	_refresh()


func _select_card(index: int):
	if phase == "augment" and index < offered_augments.size():
		_choose_augment(offered_augments[index])


func _refresh():
	if not is_instance_valid(grid):
		return
	var safe_opened = 0
	var paid = 0
	var confirmed = 0
	var confirmed_special = 0
	for cell in cells:
		if cell["revealed"] and not cell["mine"]:
			safe_opened += 1
		if cell.get("committed", false):
			paid += 1
		if cell["mine"] and (cell["settled"] or cell["revealed"]):
			confirmed += 1
			if cell.get("stealth", false):
				confirmed_special += 1
	stage_label.text = ("이지 · " if difficulty == "easy" else "하드 · ") + "STAGE %02d / 10" % stage
	hp_label.maximum = max_hp
	hp_label.value = hp
	money_label.value = money
	face_button.mood = "reward" if phase in ["augment", "reward", "victory"] else phase
	stats_label.text = "%d×%d · 지뢰는 확인하면 남은 수에서 차감됩니다" % [board_width, board_height]
	remaining_mines_label.text = "남은 지뢰  %03d / %03d" % [maxi(0, mine_count - confirmed), mine_count]
	special_mines_label.text = "특수 · 은신  %02d / %02d" % [maxi(0, stealth_count - confirmed_special), stealth_count]
	progress_label.text = "클리어 목표: 지뢰 Commit %d / %d · 안전 칸 %d / %d 공개" % [paid, mine_count, safe_opened, cells.size() - mine_count]
	progress_bar.max_value = mine_count
	progress_bar.value = paid
	rules_label.text = "파기 비용       %d골드 (현재 %d)\n정답 정산       +%d골드\n지뢰 폭발       -%d HP\n오답 정산       -%d HP / 개" % [dig_cost, _effective_dig_cost(), mine_reward, _mine_damage(), _wrong_flag_damage()]
	shop_label.text = "보유 증강 카드 → 상세창에서 강화\nLv.1 → 2: 30% / Lv.2 → 3: 20% / Lv.3 → 4: 10%\n가격: 파기 비용 × 6 / 12 / 24"
	shop_jump_button.text = "증강 카드에서 개별 강화 · 최대 Lv.4"
	shop_button.visible = false
	shop_status.text = shop_result

	var pending = _pending_flags().size()
	commit_button.text = "COMMIT · 대상 %d개\nSpace / Enter" % pending
	commit_button.disabled = phase != "playing" or not generated or pending == 0 or not _communication_allows_commit()
	commit_button.tooltip_text = "통신 장애: 3개 이상 필요. 남은 미공개·미정산 칸이 3개 미만이면 예외." if _has("interference") else "미검증 깃발 일괄 정산"
	abandon_button.disabled = phase != "playing"
	message_label.text = message
	cancel_target_button.visible = not targeting.is_empty()
	var active_count = 0
	for id in active_buttons:
		var button = active_buttons[id]
		button.visible = _has(id)
		button.disabled = false
		button.text = ""
		owned_cards[id]["status"].text = "액티브 · " + ("사용 완료 · 상세보기" if id in used_actives else ("대상 선택 중 · 상세보기" if id == targeting else ("상세보기 · 1회 남음" if generated else "상세보기 · 첫 파기 후")))
		if _has(id):
			active_count += 1
	action_status.text = "액티브는 첫 파기 후 사용 가능" if not generated else "직접 %d회 · 무료 %d회 · 공명 %d/4\n방폭 태세 %s" % [direct_digs, accelerated_digs, echo_uses, "준비" if shield_ready else "없음"]
	if active_count == 0:
		action_status.text += "\n획득한 액티브 없음"
	if not scan_result.is_empty():
		var center = scan_result["center"]
		action_status.text += "\n스캔 당시 (%d,%d): %d개" % [center % board_width + 1, int(center / board_width) + 1, scan_result["count"]]
	var buff_count = 0
	var debuff_count = 0
	for id in owned_cards:
		owned_cards[id]["title"].text = Augments.ALL[id]["name"] + (" · Lv.%d/4" % _level(id) if Upgrades.DATA.has(id) else "")
		owned_cards[id]["root"].tooltip_text = "%s · Lv.%d / 4\n%s" % [Augments.ALL[id]["name"], _level(id), Upgrades.describe(id,_level(id))]
		owned_cards[id]["root"].visible = _has(id)
		if id == "revival":
			owned_cards[id]["status"].text = "패시브 · " + ("소모됨" if revival_used else "부활 1회 남음")
	for id in owned_augments:
		var item = Augments.ALL[id]
		if item["kind"] == Augments.DEBUFF:
			debuff_count += 1
		else:
			buff_count += 1
	inventory_label.text = "버프 %d/5 · 디버프 %d/4" % [buff_count, debuff_count] + ("\n아직 획득한 능력이 없습니다." if owned_augments.is_empty() else "")
	choice_overlay.visible = phase in ["augment", "reward", "victory"]
	choice_cards.visible = phase == "augment"
	reward_panel.visible = phase == "reward"
	victory_panel.visible = phase == "victory"
	if phase == "augment":
		var kind_name = "버프" if stage % 2 == 1 else "디버프"
		choice_header.text = "STAGE %02d 클리어 · %s 선택" % [stage, kind_name]
		choice_subtitle.text = "%d개 중 반드시 1개 선택 · 다음 스테이지부터 런 종료까지 적용 · 중복 획득 없음\n선택 후 골드 / HP 회복 보상도 별도로 받습니다." % offered_augments.size()
		for i in range(3):
			card_buttons[i].visible = i < offered_augments.size()
			if i < offered_augments.size():
				var item = Augments.ALL[offered_augments[i]]
				card_art[i].texture = Art.texture_for(offered_augments[i])
				card_titles[i].text = "[%s]\n%s" % [Augments.kind_label(item["kind"]), item["name"]]
				card_descriptions[i].text = item["description"]
	elif phase == "reward":
		choice_header.text = "%s 선택 완료" % Augments.ALL[pending_augment]["name"]
		choice_subtitle.text = "효과는 다음 스테이지부터 적용됩니다. 골드 또는 회복 보상을 하나 선택하세요."
	elif phase == "victory":
		choice_header.text = "10스테이지 최종 승리!"
		choice_subtitle.text = "모든 지뢰를 Commit하고 마지막 탐색을 마쳤습니다."
		victory_label.text = "최종 HP %d/%d · 골드 %d\n획득 버프 %d개 · 디버프 %d개\n10스테이지 뒤에는 추가 증강이나 보상 선택이 없습니다." % [hp, max_hp, money, buff_count, debuff_count]
	var next_rules = _rules_for(stage + 1, true)
	var next_max_hp = next_rules["max_hp"]
	money_reward_button.text = "골드 +%d → %d" % [_cash_reward(), money + _cash_reward()]
	heal_reward_button.text = "HP 회복 → %d / %d" % [mini(next_max_hp, mini(max_hp, hp + _heal_amount(HEAL_REWARD)) + (3 if pending_augment == "heart" else 0)), next_max_hp]
	reward_hint.text = "다음 %d스테이지 · %d×%d · 지뢰 %d개 (은신 %d) · 파기 %d골드" % [stage + 1, next_rules["width"], next_rules["height"], next_rules["mines"], next_rules["stealth"], next_rules["dig_cost"]]
	if money < next_rules["dig_cost"] and not _has("frugal") and pending_augment != "frugal" and not _has("reserve") and pending_augment != "reserve":
		reward_hint.text += "\n주의: 회복 선택 시 첫 파기 골드 부족으로 파산합니다."
	reward_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(cells.size()):
		_refresh_tile(i)
	_refresh_augment_details()


func _refresh_tile(index):
	var cell = cells[index]
	var button = tile_buttons[index]
	button.number_text = ""
	button.modulate = Color.WHITE
	if not scan_result.is_empty() and index in scan_result["indices"]:
		button.modulate = Color("#c3d8ff")
	if not targeting.is_empty() and current_hover >= 0:
		var radius = _active_radius(targeting)
		if index in _area(current_hover, radius):
			button.modulate = Color("#ffe083")
	var style_key = "hidden"
	var ink = Color.BLACK
	var mark = ""
	if cell["revealed"]:
		if cell["mine"]:
			mark = "mine"
			style_key = "mine"
		else:
			button.number_text = str(cell["adjacent"]) if cell["adjacent"] > 0 else ""
			if cell.get("obscured", false):
				button.number_text = "?"
			style_key = "open"
			var colors = ["#c0c0c0", "#0000ff", "#008000", "#ff0000", "#000080", "#800000", "#008080", "#000000", "#808080"]
			ink = Color(colors[cell["adjacent"]])
			if cell.get("obscured", false):
				ink = Color("#555555")
	elif cell["settled"]:
		mark = "paid"
		style_key = "paid"
	elif phase == "gameover" and cell["mine"]:
		mark = "mine"
		style_key = "mine_end"
	elif cell["flagged"]:
		mark = "flag"
		style_key = "flag"
	button.number_color = ink
	button.queue_redraw()
	button.get_node("Mark").mark = mark
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, tile_styles[style_key])
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.tooltip_text = "(%d, %d)" % [index % board_width + 1, int(index / board_width) + 1]
	if cell.get("committed", false):
		button.tooltip_text += "\nCommit 완료: 주변 파기 조건에 포함 (은신지뢰는 숫자에서 제외)."
	elif cell["settled"] and not cell["revealed"]:
		button.tooltip_text += "\n안전 굴착으로 확인한 지뢰: 주변 파기 조건에 포함. 추가 정산 보상 없음."
	elif cell["revealed"] and cell["mine"]:
		button.tooltip_text += "\n직접 폭발해 확인한 지뢰: 주변 파기 조건에 포함. 추가 피해·보상 없음."
	# 공개된 칸도 숫자가 읽기 쉽게 disabled 대신 입력 단계에서 차단한다.
	var chord = _chord_info(index)
	if cell["revealed"] and not cell["mine"] and cell["adjacent"] > 0:
		button.tooltip_text += "\n숫자 칸 클릭: 주변 미공개 칸 일괄 파기"
		if chord["eligible"]:
			button.tooltip_text += "\n대상 %d칸 · 필요 골드 최대 %d / 보유 %d" % [chord["targets"].size(), chord["cost"], money]
		elif not chord["reason"].is_empty():
			button.tooltip_text += "\n" + chord["reason"]
		if _has("stealth"):
			button.tooltip_text += "\n은신지뢰는 숫자에 포함되지 않으며 주변 파기로도 폭발할 수 있습니다."
	var clickable = not cell["revealed"] and not cell["settled"] or (chord["eligible"] and money >= chord["cost"])
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if phase == "playing" and clickable else Control.CURSOR_ARROW


func _build_mode_menu():
	mode_overlay = Control.new()
	mode_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(mode_overlay)
	var shade = ColorRect.new()
	shade.color = Color(0.08, 0.08, 0.08, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_overlay.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Widgets.bevel(false, 28))
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	_label(column, "지뢰찾기 · 난이도 선택", 32, "#202020")
	_label(column, "두 모드 모두 8×8 시작 · 10스테이지 도전", 20, "#404040")
	for mode in ["easy", "hard"]:
		var button = Button.new()
		button.text = "이지 모드 · 매 스테이지 +1×1 · 최종 17×17" if mode == "easy" else "하드 모드 · 매 스테이지 +2×2 · 최종 26×26"
		button.custom_minimum_size = Vector2(590, 68)
		button.pressed.connect(_select_mode.bind(mode))
		column.add_child(button)

func _show_mode_menu():
	if not is_instance_valid(mode_overlay):
		return
	if not ticket_pending.is_empty():
		return
	_close_augment_details()
	phase = "menu"
	mode_overlay.show()

func _select_mode(mode: String):
	difficulty = mode
	mode_overlay.hide()
	_new_run()
