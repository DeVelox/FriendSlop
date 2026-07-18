extends CharacterBody3D

## Player controller for charades gameplay.
## Actor: moves on stage, triggers emotes to act out words.
## Audience: seated, triggers reaction emotes.

@export var base_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_forward: String = "ui_up"
@export var input_back: String = "ui_down"
@export var input_jump: String = "ui_accept"

var is_actor: bool = false
var _playing_emote: bool = false
var _in_round: bool = false
var _can_emote: bool = false
var _anim_frozen: bool = false
var _anim_locked: bool = false
var _emote_speed: float = 1.0
@onready var _round_manager: Node = get_node_or_null("../../../RoundManager")

var synced_anim: String = "":
	set(value):
		if synced_anim == value:
			return
		synced_anim = value
		if value == "":
			return
		if anim_player == null:
			return
		if is_multiplayer_authority():
			return
		if _anim_frozen or _anim_locked:
			return
		if EMOTE_KEYS.values().has(value):
			var anim: Animation = anim_player.get_animation(value)
			if anim != null:
				anim.loop_mode = Animation.LOOP_LINEAR
		if anim_player.has_animation(value) and anim_player.current_animation != value:
			anim_player.play(value)

@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var model: Node3D = $AnimatedHuman
@onready var anim_player: AnimationPlayer = $AnimatedHuman/AnimationPlayer

const STAGE_BOUNDS_MIN: Vector3 = Vector3(-10.0, 0.0, 18.0)
const STAGE_BOUNDS_MAX: Vector3 = Vector3(10.0, 2.0, 28.0)

const AUDIENCE_BOUNDS_MIN: Vector3 = Vector3(-7.0, 0.0, 8.0)
const AUDIENCE_BOUNDS_MAX: Vector3 = Vector3(7.0, 2.0, 13.0)

const EMOTE_KEYS: Dictionary = {
	KEY_1: "Human Armature|Punch",
	KEY_2: "Human Armature|Working",
	KEY_3: "Human Armature|Death",
	KEY_4: "Human Armature|ArmatureAction_002",
}


func _enter_tree() -> void:
	set_multiplayer_authority(int(name))


func _ready() -> void:
	check_input_mappings()
	await get_tree().process_frame
	var rm: Node = _round_manager
	if rm == null:
		var parent: Node = get_parent()
		if parent != null:
			rm = parent.get_parent().get_node_or_null("RoundManager")
	if rm != null:
		rm.reset_all_animations.connect(_on_reset_all_animations)
	if is_multiplayer_authority():
		$Head/Camera3D.current = false
		if rm != null:
			rm.state_changed.connect(_on_round_state_changed)
			rm.round_started.connect(_on_round_started)
			rm.round_ended.connect(_on_round_ended)
			_in_round = (rm.current_state == 3)
			_can_emote = (rm.current_state == 3)
	else:
		set_process(false)
		set_physics_process(false)



func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if _is_gui_focused():
		return
	if not _can_emote:
		return
	if _anim_frozen or _anim_locked:
		return
	if not event is InputEventKey:
		return
	if not event.pressed:
		return
	if EMOTE_KEYS.has(event.keycode):
		_play_emote(EMOTE_KEYS[event.keycode])


func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if _is_gui_focused():
		return

	velocity += get_gravity() * _delta

	var move_dir := Vector3.ZERO

	if _in_round:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity
			_play_movement("Human Armature|Jump")

		var input_dir: Vector2 = Input.get_vector(input_left, input_right, input_forward, input_back)
		move_dir = Vector3(-input_dir.x, 0, -input_dir.y).normalized()

		if move_dir:
			velocity.x = move_dir.x * base_speed
			velocity.z = move_dir.z * base_speed
		else:
			velocity.x = move_toward(velocity.x, 0, base_speed)
			velocity.z = move_toward(velocity.z, 0, base_speed)

	move_and_slide()
	_clamp_to_stage()

	if _anim_frozen or _anim_locked:
		return

	if not _playing_emote:
		if is_on_floor():
			if move_dir.length_squared() > 0.01:
				_play_movement("Human Armature|Walk")
			else:
				_play_movement("Human Armature|Idle")


func set_role(peer_id: int) -> void:
	is_actor = (peer_id == int(name))
	model.visible = true


func _on_round_state_changed(new_state: int) -> void:
	_in_round = new_state in [2, 3]
	_can_emote = new_state == 3


func _on_round_started(_actor_peer_id: int, _prompt: String) -> void:
	_in_round = true
	_can_emote = true


func _on_round_ended() -> void:
	_in_round = false
	_can_emote = false


func _on_reset_all_animations() -> void:
	_anim_frozen = false
	_anim_locked = false
	_emote_speed = 1.0
	if anim_player != null:
		anim_player.speed_scale = 1.0
		if anim_player.has_animation("Human Armature|Idle"):
			anim_player.play("Human Armature|Idle")
	_playing_emote = false
	synced_anim = "Human Armature|Idle"


func toggle_freeze() -> bool:
	if anim_player == null:
		return false
	_anim_frozen = not _anim_frozen
	if _anim_frozen:
		anim_player.pause()
	else:
		anim_player.play()
	return _anim_frozen


func toggle_lock() -> bool:
	_anim_locked = not _anim_locked
	if _anim_locked and anim_player != null and anim_player.is_animation_active():
		_playing_emote = true
	return _anim_locked


func set_speed_scale(value: float) -> void:
	_emote_speed = value
	if anim_player != null:
		anim_player.speed_scale = value


func _play_emote(anim_name: String) -> void:
	if anim_player == null:
		return
	if _anim_frozen or _anim_locked:
		return
	if anim_player.has_animation(anim_name):
		var anim: Animation = anim_player.get_animation(anim_name)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR
		anim_player.play(anim_name)
		_playing_emote = true
		synced_anim = anim_name


func _play_movement(anim_name: String) -> void:
	if anim_player == null:
		return
	if _anim_frozen or _anim_locked:
		return
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)
			synced_anim = anim_name
		_playing_emote = false


func _clamp_to_stage() -> void:
	var bounds_min: Vector3 = AUDIENCE_BOUNDS_MIN if not is_actor else STAGE_BOUNDS_MIN
	var bounds_max: Vector3 = AUDIENCE_BOUNDS_MAX if not is_actor else STAGE_BOUNDS_MAX
	global_position.x = clampf(global_position.x, bounds_min.x, bounds_max.x)
	global_position.z = clampf(global_position.z, bounds_min.z, bounds_max.z)
	global_position.y = maxf(global_position.y, bounds_min.y)


func _is_gui_focused() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is LineEdit


func check_input_mappings() -> void:
	var actions: Array[String] = [input_left, input_right, input_forward, input_back]
	for action in actions:
		if not InputMap.has_action(action):
			push_warning("Input action not found: " + action)
