extends CanvasLayer

## In-game HUD: round timer, audience emote buttons, actor prompt display,
## audience fuzzy search guessing, winner display.

@export var font_size_timer: int = 32
@export var font_size_prompt: int = 24
@export var font_size_emote: int = 16
@export var font_size_search: int = 24
@export var font_size_results: int = 22
@export var font_size_winner: int = 36
@export var panel_bg_color: Color = Color(0.0, 0.0, 0.0, 0.7)
@export var button_bg_color: Color = Color(0.2, 0.2, 0.3, 0.9)
@export var button_hover_color: Color = Color(0.3, 0.3, 0.5, 1.0)
@export var result_bg_color: Color = Color(0.15, 0.15, 0.25, 0.95)
@export var result_hover_color: Color = Color(0.25, 0.25, 0.45, 1.0)
@export var freeze_active_color: Color = Color(0.6, 0.2, 0.2, 0.9)
@export var lock_active_color: Color = Color(0.2, 0.4, 0.6, 0.9)

@onready var timer_label: Label = $TimerLabel
@onready var prompt_label: Label = $PromptLabel
@onready var emote_panel: MarginContainer = $EmotePanel

var _round_manager: Node = null
var _current_state: int = -1
var _current_actor_peer_id: int = 0
var _start_button: Button = null
var _guess_panel: VBoxContainer = null
var _results_scroll: ScrollContainer = null
var _results_box: VBoxContainer = null
var _search_box: LineEdit = null
var _winner_label: Label = null
var _freeze_btn: Button = null
var _lock_btn: Button = null
var _speed_label: Label = null
var _speed_slider: HSlider = null
var _actor_options_panel: VBoxContainer = null
var _actor_options_buttons: Array[Button] = []
var _topic_label: Label = null

const EMOTE_KEYS: Dictionary = {
	KEY_1: "Human Armature|Punch",
	KEY_2: "Human Armature|Working",
	KEY_3: "Human Armature|Death",
	KEY_4: "Human Armature|ArmatureAction_002",
}

const EMOTE_NAMES: Dictionary = {
	"Human Armature|Punch": "Punch",
	"Human Armature|Working": "Working",
	"Human Armature|Death": "Death",
	"Human Armature|ArmatureAction_002": "Placeholder",
}


func _ready() -> void:
	await get_tree().process_frame
	_round_manager = _find_round_manager()
	if _round_manager == null:
		push_warning("GameHUD: RoundManager not found")
		return

	_round_manager.timer_updated.connect(_on_timer_updated)
	_round_manager.state_changed.connect(_on_state_changed)
	_round_manager.actor_changed.connect(_on_actor_changed)
	_round_manager.correct_answer.connect(_on_correct_answer)
	_round_manager.actor_options_received.connect(_on_actor_options_received)

	_setup_timer_label()
	_setup_prompt_label()
	_build_emote_buttons()
	_build_start_button()
	_build_guess_ui()
	_build_winner_label()
	_build_actor_options_panel()
	_build_topic_label()

	_current_state = _round_manager.current_state
	_current_actor_peer_id = _round_manager.current_actor_peer_id
	_refresh_display()


func _find_round_manager() -> Node:
	var stage: Node = get_parent()
	if stage == null:
		return null
	return stage.get_node_or_null("RoundManager")


func _setup_timer_label() -> void:
	timer_label.text = "Time: --"
	timer_label.add_theme_font_size_override("font_size", font_size_timer)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.visible = true


func _setup_prompt_label() -> void:
	prompt_label.text = ""
	prompt_label.add_theme_font_size_override("font_size", font_size_prompt)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.visible = false


func _make_stylebox(bg_color: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(8)
	return sb


func _get_local_player() -> Node:
	var game_manager: Node = get_parent()
	if game_manager == null:
		return null
	var players_node: Node3D = game_manager.get_node_or_null("Multiplayer/Players")
	if players_node == null:
		return null
	var local_id: int = multiplayer.get_unique_id()
	return players_node.get_node_or_null(str(local_id))


func _player_method(method_name: String, arg: Variant = null) -> Variant:
	var player: Node = _get_local_player()
	if player == null or not player.has_method(method_name):
		return null
	if arg != null:
		return player.call(method_name, arg)
	return player.call(method_name)


func _build_emote_buttons() -> void:
	for child in emote_panel.get_children():
		if child is VBoxContainer or child is HBoxContainer:
			for sub_child in child.get_children():
				sub_child.queue_free()
			child.queue_free()

	var outer_box: VBoxContainer = VBoxContainer.new()
	outer_box.name = "ControlsBox"
	outer_box.add_theme_constant_override("separation", 4)

	var controls_row: HBoxContainer = HBoxContainer.new()
	controls_row.name = "ControlsRow"
	controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_row.add_theme_constant_override("separation", 8)

	_freeze_btn = Button.new()
	_freeze_btn.name = "FreezeBtn"
	_freeze_btn.text = "Freeze"
	_freeze_btn.custom_minimum_size = Vector2(80, 32)
	_freeze_btn.focus_mode = Control.FOCUS_NONE
	_freeze_btn.add_theme_font_size_override("font_size", font_size_emote)
	_freeze_btn.add_theme_color_override("font_color", Color.WHITE)
	_freeze_btn.add_theme_stylebox_override("normal", _make_stylebox(button_bg_color))
	_freeze_btn.add_theme_stylebox_override("hover", _make_stylebox(button_hover_color))
	_freeze_btn.pressed.connect(_on_freeze_pressed)
	controls_row.add_child(_freeze_btn)

	_lock_btn = Button.new()
	_lock_btn.name = "LockBtn"
	_lock_btn.text = "Lock"
	_lock_btn.custom_minimum_size = Vector2(80, 32)
	_lock_btn.focus_mode = Control.FOCUS_NONE
	_lock_btn.add_theme_font_size_override("font_size", font_size_emote)
	_lock_btn.add_theme_color_override("font_color", Color.WHITE)
	_lock_btn.add_theme_stylebox_override("normal", _make_stylebox(button_bg_color))
	_lock_btn.add_theme_stylebox_override("hover", _make_stylebox(button_hover_color))
	_lock_btn.pressed.connect(_on_lock_pressed)
	controls_row.add_child(_lock_btn)

	_speed_label = Label.new()
	_speed_label.name = "SpeedLabel"
	_speed_label.text = "1.0x"
	_speed_label.add_theme_font_size_override("font_size", font_size_emote)
	_speed_label.add_theme_color_override("font_color", Color.WHITE)
	_speed_label.custom_minimum_size = Vector2(40, 0)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_row.add_child(_speed_label)

	_speed_slider = HSlider.new()
	_speed_slider.name = "SpeedSlider"
	_speed_slider.custom_minimum_size = Vector2(120, 32)
	_speed_slider.focus_mode = Control.FOCUS_NONE
	_speed_slider.min_value = 0.25
	_speed_slider.max_value = 4.0
	_speed_slider.step = 0.25
	_speed_slider.value = 1.0
	_speed_slider.tick_count = 15
	_speed_slider.ticks_on_borders = true
	_speed_slider.value_changed.connect(_on_speed_changed)
	controls_row.add_child(_speed_slider)

	outer_box.add_child(controls_row)

	var emote_row: HBoxContainer = HBoxContainer.new()
	emote_row.name = "EmoteButtons"
	emote_row.alignment = BoxContainer.ALIGNMENT_CENTER
	emote_row.add_theme_constant_override("separation", 8)

	for anim_name in EMOTE_KEYS.values():
		var btn: Button = Button.new()
		var display_name: String = EMOTE_NAMES.get(anim_name, anim_name)
		btn.text = display_name
		btn.custom_minimum_size = Vector2(100, 40)
		btn.add_theme_font_size_override("font_size", font_size_emote)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_stylebox_override("normal", _make_stylebox(button_bg_color))
		btn.add_theme_stylebox_override("hover", _make_stylebox(button_hover_color))
		btn.pressed.connect(_on_emote_button_pressed.bind(anim_name))
		emote_row.add_child(btn)

	outer_box.add_child(emote_row)
	emote_panel.add_child(outer_box)


func _build_start_button() -> void:
	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "Start Game"
	_start_button.custom_minimum_size = Vector2(200, 50)
	_start_button.set_anchors_preset(Control.PRESET_CENTER)
	_start_button.offset_left = -100.0
	_start_button.offset_top = -25.0
	_start_button.offset_right = 100.0
	_start_button.offset_bottom = 25.0
	_start_button.add_theme_font_size_override("font_size", 24)
	_start_button.add_theme_color_override("font_color", Color.WHITE)
	_start_button.add_theme_stylebox_override("normal", _make_stylebox(Color(0.15, 0.4, 0.15, 0.9)))
	_start_button.add_theme_stylebox_override("hover", _make_stylebox(Color(0.2, 0.55, 0.2, 1.0)))
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.visible = false
	add_child(_start_button)


func _refresh_display() -> void:
	var in_prep: bool = _current_state == 2
	var in_round: bool = _current_state == 3
	timer_label.visible = true
	emote_panel.visible = in_round
	prompt_label.visible = (in_prep or in_round) and _is_local_actor()
	if prompt_label.visible:
		prompt_label.text = _round_manager.current_prompt
	_start_button.visible = _current_state == 0 and multiplayer.is_server()

	if _actor_options_panel != null and _current_state != 2:
		_actor_options_panel.visible = false

	var show_guess: bool = in_round and not _is_local_actor()
	_guess_panel.visible = show_guess
	if not show_guess:
		_search_box.text = ""
		_refresh_results("")

	if _current_state != 4:
		_winner_label.visible = false
	elif _round_manager.winner_peer_id == 0:
		_winner_label.text = "Nobody guessed!"
		_winner_label.visible = true

	if _current_state in [0, 4]:
		_reset_controls()

	_update_topic_label()


func _reset_controls() -> void:
	_update_toggle_style(_freeze_btn, false, freeze_active_color)
	_update_toggle_style(_lock_btn, false, lock_active_color)
	_speed_slider.set_value_no_signal(1.0)
	_speed_label.text = "1.0x"
	_player_method("set_speed_scale", 1.0)


func _is_local_actor() -> bool:
	return multiplayer.get_unique_id() == _current_actor_peer_id


func _on_timer_updated(time_remaining: float) -> void:
	var minutes: int = int(time_remaining / 60.0)
	var seconds: int = int(time_remaining) % 60
	timer_label.text = "Time: %d:%02d" % [minutes, seconds]


func _on_state_changed(new_state: int) -> void:
	_current_state = new_state
	_refresh_display()


func _on_actor_changed(peer_id: int) -> void:
	_current_actor_peer_id = peer_id
	_refresh_display()


func _on_emote_button_pressed(anim_name: String) -> void:
	_player_method("_play_emote", anim_name)


func _on_freeze_pressed() -> void:
	var result: Variant = _player_method("toggle_freeze")
	if result is bool:
		_update_toggle_style(_freeze_btn, result, freeze_active_color)


func _on_lock_pressed() -> void:
	var result: Variant = _player_method("toggle_lock")
	if result is bool:
		_update_toggle_style(_lock_btn, result, lock_active_color)


func _on_speed_changed(value: float) -> void:
	_speed_label.text = "%.2fx" % value
	_player_method("set_speed_scale", value)


func _update_toggle_style(btn: Button, active: bool, active_color: Color) -> void:
	if active:
		btn.add_theme_stylebox_override("normal", _make_stylebox(active_color))
		btn.add_theme_stylebox_override("hover", _make_stylebox(active_color.lightened(0.15)))
	else:
		btn.add_theme_stylebox_override("normal", _make_stylebox(button_bg_color))
		btn.add_theme_stylebox_override("hover", _make_stylebox(button_hover_color))


func _on_start_pressed() -> void:
	if _round_manager == null:
		return
	_round_manager.begin_game()


func _build_guess_ui() -> void:
	_guess_panel = VBoxContainer.new()
	_guess_panel.name = "GuessPanel"
	_guess_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_guess_panel.offset_left = -200.0
	_guess_panel.offset_top = -280.0
	_guess_panel.offset_right = 200.0
	_guess_panel.offset_bottom = -85.0
	_guess_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_guess_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_guess_panel.add_theme_constant_override("separation", 4)
	_guess_panel.visible = false
	add_child(_guess_panel)

	_results_scroll = ScrollContainer.new()
	_results_scroll.name = "ResultsScroll"
	_results_scroll.custom_minimum_size = Vector2(400, 130)
	_results_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_guess_panel.add_child(_results_scroll)

	_results_box = VBoxContainer.new()
	_results_box.name = "ResultsBox"
	_results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_box.add_theme_constant_override("separation", 2)
	_results_scroll.add_child(_results_box)

	_search_box = LineEdit.new()
	_search_box.name = "SearchBox"
	_search_box.custom_minimum_size = Vector2(400, 40)
	_search_box.placeholder_text = "Guess the prompt..."
	_search_box.add_theme_font_size_override("font_size", font_size_search)
	_search_box.add_theme_color_override("font_color", Color.WHITE)
	_search_box.add_theme_color_override("font_placeholder_color", Color(0.6, 0.6, 0.6))
	_search_box.add_theme_stylebox_override("normal", _make_stylebox(Color(0.1, 0.1, 0.2, 0.9)))
	_search_box.add_theme_stylebox_override("focus", _make_stylebox(Color(0.15, 0.15, 0.3, 1.0)))
	_search_box.text_changed.connect(_on_search_text_changed)
	_search_box.gui_input.connect(_on_search_gui_input)
	_guess_panel.add_child(_search_box)


func _build_winner_label() -> void:
	_winner_label = Label.new()
	_winner_label.name = "WinnerLabel"
	_winner_label.set_anchors_preset(Control.PRESET_CENTER)
	_winner_label.offset_left = -300.0
	_winner_label.offset_top = -40.0
	_winner_label.offset_right = 300.0
	_winner_label.offset_bottom = 40.0
	_winner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_winner_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_winner_label.add_theme_font_size_override("font_size", font_size_winner)
	_winner_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_winner_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_winner_label.add_theme_constant_override("shadow_offset_x", 2)
	_winner_label.add_theme_constant_override("shadow_offset_y", 2)
	_winner_label.visible = false
	add_child(_winner_label)


func _fuzzy_search(query: String) -> Array[String]:
	if query.is_empty() or _round_manager == null:
		return []
	var lower_query: String = query.to_lower()
	var results: Array[String] = []
	var search_list: Array[String] = _get_search_list()
	for word: String in search_list:
		if _fuzzy_match(lower_query, word.to_lower()):
			results.append(word)
			if results.size() >= 5:
				break
	return results


func _get_search_list() -> Array[String]:
	var data_manager: Node = get_tree().get_first_node_in_group("guessing_data_manager")
	if data_manager == null:
		return []
	var topic_id: String = _round_manager.current_topic_id
	if topic_id.is_empty():
		return data_manager.get_word_bank()
	return data_manager.get_guessing_list_for_topic(topic_id)


func _fuzzy_match(query: String, target: String) -> bool:
	var qi: int = 0
	for ti in range(target.length()):
		if qi < query.length() and target[ti] == query[qi]:
			qi += 1
	return qi == query.length()


func _on_search_text_changed(new_text: String) -> void:
	_refresh_results(new_text)


func _refresh_results(query: String) -> void:
	for child in _results_box.get_children():
		child.queue_free()

	var matches: Array[String] = _fuzzy_search(query)
	var count: int = mini(matches.size(), 5)
	for i in count:
		var btn: Button = Button.new()
		btn.text = matches[i]
		btn.custom_minimum_size = Vector2(380, 40)
		btn.add_theme_font_size_override("font_size", font_size_results)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_stylebox_override("normal", _make_stylebox(result_bg_color))
		btn.add_theme_stylebox_override("hover", _make_stylebox(result_hover_color))
		btn.pressed.connect(_on_result_pressed.bind(matches[i]))
		_results_box.add_child(btn)

	_results_scroll.visible = matches.size() > 0


func _on_result_pressed(prompt: String) -> void:
	if _round_manager == null:
		return
	_round_manager.submit_guess.rpc(prompt)
	_search_box.text = ""
	_refresh_results("")


func _on_search_gui_input(event: InputEvent) -> void:
	if _search_box == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_search_box.release_focus()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _search_box == null or not _search_box.has_focus():
		return
	if event is InputEventMouseButton and event.pressed:
		_search_box.release_focus()


func _on_correct_answer(_peer_id: int, display_name: String) -> void:
	_winner_label.text = "%s guessed it!" % display_name
	_winner_label.visible = true


func _build_actor_options_panel() -> void:
	_actor_options_panel = VBoxContainer.new()
	_actor_options_panel.name = "ActorOptionsPanel"
	_actor_options_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_actor_options_panel.offset_top = 80.0
	_actor_options_panel.offset_left = -200.0
	_actor_options_panel.offset_right = 200.0
	_actor_options_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_actor_options_panel.add_theme_constant_override("separation", 8)
	_actor_options_panel.visible = false
	add_child(_actor_options_panel)

	var options_title_label: Label = Label.new()
	options_title_label.name = "OptionsTitleLabel"
	options_title_label.text = "Choose your word:"
	options_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options_title_label.add_theme_font_size_override("font_size", 18)
	options_title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	_actor_options_panel.add_child(options_title_label)

	for i in 3:
		var btn: Button = Button.new()
		btn.name = "Option%d" % i
		btn.text = ""
		btn.custom_minimum_size = Vector2(300, 50)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_stylebox_override("normal", _make_stylebox(button_bg_color))
		btn.add_theme_stylebox_override("hover", _make_stylebox(button_hover_color))
		btn.pressed.connect(_on_actor_option_pressed.bind(i))
		_actor_options_panel.add_child(btn)
		_actor_options_buttons.append(btn)


func _build_topic_label() -> void:
	_topic_label = Label.new()
	_topic_label.name = "TopicLabel"
	_topic_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_topic_label.offset_top = 50.0
	_topic_label.offset_left = -150.0
	_topic_label.offset_right = 150.0
	_topic_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_topic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_topic_label.add_theme_font_size_override("font_size", 20)
	_topic_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_topic_label.visible = false
	add_child(_topic_label)


func _on_actor_options_received(options: Array[String]) -> void:
	if not _is_local_actor():
		_actor_options_panel.visible = false
		return

	_actor_options_panel.visible = true
	prompt_label.visible = false

	for i in mini(options.size(), _actor_options_buttons.size()):
		_actor_options_buttons[i].text = options[i]
		_actor_options_buttons[i].visible = true

	for i in range(options.size(), _actor_options_buttons.size()):
		_actor_options_buttons[i].visible = false


func _on_actor_option_pressed(index: int) -> void:
	if _round_manager == null or index >= _actor_options_buttons.size():
		return
	var selected: String = _actor_options_buttons[index].text
	_actor_options_panel.visible = false
	_round_manager.actor_selected_prompt.rpc(selected)


func _update_topic_label() -> void:
	if _topic_label == null or _round_manager == null:
		return
	var topic_id: String = _round_manager.current_topic_id
	if topic_id.is_empty():
		_topic_label.visible = false
		return
	var data_manager: Node = get_tree().get_first_node_in_group("guessing_data_manager")
	if data_manager == null:
		_topic_label.visible = false
		return
	var topics: Array[Dictionary] = data_manager._all_topics
	for topic: Dictionary in topics:
		if topic.id == topic_id:
			_topic_label.text = "Topic: %s" % topic.name
			_topic_label.visible = true
			return
	_topic_label.visible = false
