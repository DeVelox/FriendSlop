extends Control
## UI controller for the host's game settings panel.
## Shows topic selection, list/pack toggles, and create/edit options.
## This scene is instanced as a popup overlay on top of the lobby.

signal settings_closed()

const PANEL_BG_COLOR: Color = Color(0.08, 0.08, 0.12, 0.95)
const SECTION_BG_COLOR: Color = Color(0.12, 0.12, 0.18, 0.9)
const ITEM_BG_COLOR: Color = Color(0.15, 0.15, 0.22, 0.9)
const ITEM_HOVER_COLOR: Color = Color(0.22, 0.22, 0.35, 1.0)
const CHECKBOX_ACTIVE_COLOR: Color = Color(0.2, 0.5, 0.3, 0.9)
const BUTTON_BG_COLOR: Color = Color(0.2, 0.2, 0.3, 0.9)
const BUTTON_HOVER_COLOR: Color = Color(0.3, 0.3, 0.5, 1.0)

var _data_manager: Node = null
var _topic_checkboxes: Dictionary = {}
var _list_toggles: Dictionary = {}
var _pack_toggles: Dictionary = {}
var _topics_container: VBoxContainer = null
var _lists_container: VBoxContainer = null
var _packs_container: VBoxContainer = null
var _create_pack_dialog: ConfirmationDialog = null
var _create_list_dialog: ConfirmationDialog = null
var _pack_name_input: LineEdit = null
var _pack_topic_option: OptionButton = null
var _pack_entries_input: TextEdit = null
var _list_name_input: LineEdit = null
var _list_topic_option: OptionButton = null
var _list_entries_input: TextEdit = null
var _dialog_topic_ids: Array[String] = []


func _ready() -> void:
	_data_manager = _find_data_manager()
	if _data_manager == null:
		push_warning("LobbySettings: GuessingDataManager not found")
		return

	_build_ui()
	_load_data()
	_refresh_display()


func _find_data_manager() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("guessing_data_manager")


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_background_input)
	add_child(bg)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -450.0
	panel.offset_top = -350.0
	panel.offset_right = 450.0
	panel.offset_bottom = 350.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_sb: StyleBoxFlat = StyleBoxFlat.new()
	panel_sb.bg_color = PANEL_BG_COLOR
	panel_sb.set_corner_radius_all(8)
	panel_sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", panel_sb)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "Game Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var scroll_vbox: VBoxContainer = VBoxContainer.new()
	scroll_vbox.name = "ScrollVBox"
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(scroll_vbox)

	_topics_container = _build_section("Topics", scroll_vbox)
	_lists_container = _build_section("Guessing Lists", scroll_vbox)
	_packs_container = _build_section("Guessing Packs", scroll_vbox)

	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var close_btn: Button = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 40)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_stylebox_override("normal", _make_stylebox(BUTTON_BG_COLOR))
	close_btn.add_theme_stylebox_override("hover", _make_stylebox(BUTTON_HOVER_COLOR))
	close_btn.pressed.connect(_on_close_pressed)
	btn_row.add_child(close_btn)

	_build_create_pack_dialog()
	_build_create_list_dialog()


func _build_section(title_text: String, parent: VBoxContainer) -> VBoxContainer:
	var section: VBoxContainer = VBoxContainer.new()
	section.name = title_text.replace(" ", "") + "Section"
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)

	var label: Label = Label.new()
	label.text = title_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	section.add_child(label)

	var container: VBoxContainer = VBoxContainer.new()
	container.name = "Items"
	container.add_theme_constant_override("separation", 2)
	section.add_child(container)

	return container


func _make_stylebox(bg_color: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb


func _load_data() -> void:
	if _data_manager == null:
		return
	_data_manager.load_all_topics()
	_data_manager.load_all_lists()
	_data_manager.load_all_packs()


func _refresh_display() -> void:
	if _data_manager == null:
		return
	_refresh_topics()
	_refresh_lists()
	_refresh_packs()


func _refresh_topics() -> void:
	for child in _topics_container.get_children():
		child.queue_free()

	var all_topics: Array[Dictionary] = _data_manager._all_topics
	_topic_checkboxes.clear()

	for topic: Dictionary in all_topics:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_topics_container.add_child(row)

		var cb: CheckBox = CheckBox.new()
		cb.text = topic.name
		cb.button_pressed = topic.id in _data_manager._enabled_topic_ids
		cb.add_theme_font_size_override("font_size", 16)
		cb.add_theme_color_override("font_color", Color.WHITE)
		cb.toggled.connect(_on_topic_toggled.bind(topic.id))
		row.add_child(cb)
		_topic_checkboxes[topic.id] = cb

		if not topic.is_default:
			var delete_btn: Button = Button.new()
			delete_btn.text = "X"
			delete_btn.custom_minimum_size = Vector2(24, 24)
			delete_btn.add_theme_font_size_override("font_size", 12)
			delete_btn.add_theme_color_override("font_color", Color.WHITE)
			delete_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.5, 0.2, 0.2, 0.8)))
			delete_btn.add_theme_stylebox_override("hover", _make_stylebox(Color(0.7, 0.2, 0.2, 1.0)))
			row.add_child(delete_btn)


func _refresh_lists() -> void:
	for child in _lists_container.get_children():
		child.queue_free()

	_list_toggles.clear()

	var all_topics: Array[Dictionary] = _data_manager._all_topics
	for topic: Dictionary in all_topics:
		if not topic.id in _data_manager._enabled_topic_ids:
			continue

		var topic_label: Label = Label.new()
		topic_label.text = topic.name
		topic_label.add_theme_font_size_override("font_size", 14)
		topic_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
		_lists_container.add_child(topic_label)

		var lists: Array[Dictionary] = _data_manager.get_lists_for_topic(topic.id)
		if lists.is_empty():
			var empty_label: Label = Label.new()
			empty_label.text = "  No lists available"
			empty_label.add_theme_font_size_override("font_size", 12)
			empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			_lists_container.add_child(empty_label)
			continue

		for list: Dictionary in lists:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_lists_container.add_child(row)

			var cb: CheckBox = CheckBox.new()
			cb.text = "%s (%d entries)" % [list.metadata.name, list.entries.size()]
			cb.button_pressed = list.metadata.id in _data_manager._enabled_list_ids
			cb.add_theme_font_size_override("font_size", 14)
			cb.add_theme_color_override("font_color", Color.WHITE)
			cb.toggled.connect(_on_list_toggled.bind(list.metadata.id))
			row.add_child(cb)
			_list_toggles[list.metadata.id] = cb

			if not list.metadata.is_default:
				var delete_btn: Button = Button.new()
				delete_btn.text = "X"
				delete_btn.custom_minimum_size = Vector2(20, 20)
				delete_btn.add_theme_font_size_override("font_size", 10)
				delete_btn.add_theme_color_override("font_color", Color.WHITE)
				delete_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.5, 0.2, 0.2, 0.8)))
				row.add_child(delete_btn)


func _refresh_packs() -> void:
	for child in _packs_container.get_children():
		child.queue_free()

	_pack_toggles.clear()

	var all_topics: Array[Dictionary] = _data_manager._all_topics
	for topic: Dictionary in all_topics:
		if not topic.id in _data_manager._enabled_topic_ids:
			continue

		var topic_label: Label = Label.new()
		topic_label.text = topic.name
		topic_label.add_theme_font_size_override("font_size", 14)
		topic_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
		_packs_container.add_child(topic_label)

		var packs: Array[Dictionary] = _data_manager.get_packs_for_topic(topic.id)
		if packs.is_empty():
			var empty_label: Label = Label.new()
			empty_label.text = "  No packs available"
			empty_label.add_theme_font_size_override("font_size", 12)
			empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			_packs_container.add_child(empty_label)
			continue

		for pack: Dictionary in packs:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_packs_container.add_child(row)

			var cb: CheckBox = CheckBox.new()
			cb.text = "%s (%d entries)" % [pack.metadata.name, pack.entries.size()]
			cb.button_pressed = pack.metadata.id in _data_manager._enabled_pack_ids
			cb.add_theme_font_size_override("font_size", 14)
			cb.add_theme_color_override("font_color", Color.WHITE)
			cb.toggled.connect(_on_pack_toggled.bind(pack.metadata.id))
			row.add_child(cb)
			_pack_toggles[pack.metadata.id] = cb

			if not pack.metadata.is_default:
				var copy_btn: Button = Button.new()
				copy_btn.text = "Copy"
				copy_btn.add_theme_font_size_override("font_size", 10)
				copy_btn.add_theme_color_override("font_color", Color.WHITE)
				copy_btn.add_theme_stylebox_override("normal", _make_stylebox(BUTTON_BG_COLOR))
				row.add_child(copy_btn)

				var delete_btn: Button = Button.new()
				delete_btn.text = "X"
				delete_btn.custom_minimum_size = Vector2(20, 20)
				delete_btn.add_theme_font_size_override("font_size", 10)
				delete_btn.add_theme_color_override("font_color", Color.WHITE)
				delete_btn.add_theme_stylebox_override("normal", _make_stylebox(Color(0.5, 0.2, 0.2, 0.8)))
				row.add_child(delete_btn)

	var create_row: HBoxContainer = HBoxContainer.new()
	create_row.add_theme_constant_override("separation", 8)
	_packs_container.add_child(create_row)

	var create_btn: Button = Button.new()
	create_btn.text = "+ Create New Pack"
	create_btn.add_theme_font_size_override("font_size", 14)
	create_btn.add_theme_color_override("font_color", Color.WHITE)
	create_btn.add_theme_stylebox_override("normal", _make_stylebox(CHECKBOX_ACTIVE_COLOR))
	create_btn.add_theme_stylebox_override("hover", _make_stylebox(CHECKBOX_ACTIVE_COLOR.lightened(0.15)))
	create_btn.pressed.connect(_on_create_pack_pressed)
	create_row.add_child(create_btn)


func _on_topic_toggled(pressed: bool, topic_id: String) -> void:
	if _data_manager == null:
		return
	var enabled: Array[String] = _data_manager._enabled_topic_ids.duplicate()
	if pressed:
		if topic_id not in enabled:
			enabled.append(topic_id)
	else:
		enabled = enabled.filter(func(id: String) -> bool: return id != topic_id)
	_data_manager.set_enabled_topics(enabled)
	_refresh_lists()
	_refresh_packs()


func _on_list_toggled(pressed: bool, list_id: String) -> void:
	if _data_manager == null:
		return
	var enabled: Array[String] = _data_manager._enabled_list_ids.duplicate()
	if pressed:
		if list_id not in enabled:
			enabled.append(list_id)
	else:
		enabled = enabled.filter(func(id: String) -> bool: return id != list_id)
	_data_manager.set_enabled_lists(enabled)


func _on_pack_toggled(pressed: bool, pack_id: String) -> void:
	if _data_manager == null:
		return
	var enabled: Array[String] = _data_manager._enabled_pack_ids.duplicate()
	if pressed:
		if pack_id not in enabled:
			enabled.append(pack_id)
	else:
		enabled = enabled.filter(func(id: String) -> bool: return id != pack_id)
	_data_manager.set_enabled_packs(enabled)


func _on_create_pack_pressed() -> void:
	if _data_manager == null:
		return
	_populate_topic_options(_pack_topic_option)
	_pack_name_input.text = ""
	_pack_entries_input.text = ""
	_create_pack_dialog.popup_centered(Vector2i(500, 400))


func _on_close_pressed() -> void:
	settings_closed.emit()
	queue_free()


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		pass


func _build_create_pack_dialog() -> void:
	_create_pack_dialog = ConfirmationDialog.new()
	_create_pack_dialog.name = "CreatePackDialog"
	_create_pack_dialog.title = "Create New Pack"
	_create_pack_dialog.size = Vector2i(500, 400)
	_create_pack_dialog.confirmed.connect(_on_create_pack_confirmed)
	add_child(_create_pack_dialog)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_create_pack_dialog.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = "Pack Name:"
	vbox.add_child(name_label)

	_pack_name_input = LineEdit.new()
	_pack_name_input.placeholder_text = "Enter pack name..."
	_pack_name_input.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_pack_name_input)

	var topic_label: Label = Label.new()
	topic_label.text = "Topic:"
	vbox.add_child(topic_label)

	_pack_topic_option = OptionButton.new()
	_pack_topic_option.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_pack_topic_option)

	var entries_label: Label = Label.new()
	entries_label.text = "Entries (one per line):"
	vbox.add_child(entries_label)

	_pack_entries_input = TextEdit.new()
	_pack_entries_input.placeholder_text = "Enter words, one per line..."
	_pack_entries_input.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(_pack_entries_input)


func _build_create_list_dialog() -> void:
	_create_list_dialog = ConfirmationDialog.new()
	_create_list_dialog.name = "CreateListDialog"
	_create_list_dialog.title = "Create New List"
	_create_list_dialog.size = Vector2i(500, 400)
	_create_list_dialog.confirmed.connect(_on_create_list_confirmed)
	add_child(_create_list_dialog)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_create_list_dialog.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = "List Name:"
	vbox.add_child(name_label)

	_list_name_input = LineEdit.new()
	_list_name_input.placeholder_text = "Enter list name..."
	_list_name_input.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_list_name_input)

	var topic_label: Label = Label.new()
	topic_label.text = "Topic:"
	vbox.add_child(topic_label)

	_list_topic_option = OptionButton.new()
	_list_topic_option.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(_list_topic_option)

	var entries_label: Label = Label.new()
	entries_label.text = "Entries (one per line):"
	vbox.add_child(entries_label)

	_list_entries_input = TextEdit.new()
	_list_entries_input.placeholder_text = "Enter words, one per line..."
	_list_entries_input.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(_list_entries_input)


func _populate_topic_options(option_button: OptionButton) -> void:
	option_button.clear()
	_dialog_topic_ids.clear()
	for topic: Dictionary in _data_manager._all_topics:
		_dialog_topic_ids.append(topic.id)
		option_button.add_item(topic.name)
	if option_button.item_count > 0:
		option_button.select(0)


func _get_selected_topic_id(option_button: OptionButton) -> String:
	var idx: int = option_button.get_selected()
	if idx < 0 or idx >= _dialog_topic_ids.size():
		return ""
	return _dialog_topic_ids[idx]


func _on_create_pack_confirmed() -> void:
	if _data_manager == null:
		return
	var pack_name: String = _pack_name_input.text.strip_edges()
	if pack_name.is_empty():
		push_warning("LobbySettings: Pack name cannot be empty")
		return
	var topic_id: String = _get_selected_topic_id(_pack_topic_option)
	if topic_id.is_empty():
		push_warning("LobbySettings: No topic selected")
		return
	var raw_entries: String = _pack_entries_input.text
	var entries: Array[String] = []
	for line: String in raw_entries.split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty():
			entries.append(trimmed)
	if entries.is_empty():
		push_warning("LobbySettings: Pack must have at least one entry")
		return
	_data_manager.create_custom_pack(pack_name, topic_id, entries)
	_data_manager.load_all_packs()
	_refresh_packs()
	_pack_name_input.text = ""
	_pack_entries_input.text = ""


func _on_create_list_confirmed() -> void:
	if _data_manager == null:
		return
	var list_name: String = _list_name_input.text.strip_edges()
	if list_name.is_empty():
		push_warning("LobbySettings: List name cannot be empty")
		return
	var topic_id: String = _get_selected_topic_id(_list_topic_option)
	if topic_id.is_empty():
		push_warning("LobbySettings: No topic selected")
		return
	var raw_entries: String = _list_entries_input.text
	var entries: Array[String] = []
	for line: String in raw_entries.split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty():
			entries.append(trimmed)
	if entries.is_empty():
		push_warning("LobbySettings: List must have at least one entry")
		return
	_data_manager.create_custom_list(list_name, topic_id, entries)
	_data_manager.load_all_lists()
	_refresh_lists()
	_list_name_input.text = ""
	_list_entries_input.text = ""


func get_current_settings() -> Dictionary:
	return {
		"enabled_topics": _data_manager._enabled_topic_ids.duplicate() if _data_manager else [],
		"enabled_lists": _data_manager._enabled_list_ids.duplicate() if _data_manager else [],
		"enabled_packs": _data_manager._enabled_pack_ids.duplicate() if _data_manager else []
	}
