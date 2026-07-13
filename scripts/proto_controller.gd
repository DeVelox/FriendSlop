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
	if is_multiplayer_authority():
		$Head/Camera3D.current = false
	else:
		set_process(false)
		set_physics_process(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if not event is InputEventKey:
		return
	if not event.pressed:
		return
	if EMOTE_KEYS.has(event.keycode):
		_play_emote(EMOTE_KEYS[event.keycode])


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	velocity += get_gravity() * delta

	if Input.is_action_just_pressed(input_jump) and is_on_floor():
		velocity.y = jump_velocity
		_play_movement("Human Armature|Jump")

	if not is_actor:
		move_and_slide()
		return

	var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
	var move_dir := (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()

	if move_dir:
		velocity.x = move_dir.x * base_speed
		velocity.z = move_dir.z * base_speed
	else:
		velocity.x = move_toward(velocity.x, 0, base_speed)
		velocity.z = move_toward(velocity.z, 0, base_speed)

	move_and_slide()
	_clamp_to_stage()

	if not _playing_emote:
		if is_on_floor():
			if move_dir.length_squared() > 0.01:
				_play_movement("Human Armature|Walk")
			else:
				_play_movement("Human Armature|Idle")


func set_role(actor: bool) -> void:
	is_actor = actor
	if not is_multiplayer_authority():
		return
	model.visible = true


func _play_emote(anim_name: String) -> void:
	if anim_player == null:
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
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)
			synced_anim = anim_name
		_playing_emote = false


func _clamp_to_stage() -> void:
	global_position.x = clampf(global_position.x, STAGE_BOUNDS_MIN.x, STAGE_BOUNDS_MAX.x)
	global_position.z = clampf(global_position.z, STAGE_BOUNDS_MIN.z, STAGE_BOUNDS_MAX.z)
	global_position.y = maxf(global_position.y, STAGE_BOUNDS_MIN.y)


func look_at_camera() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var dir: Vector3 = (cam.global_position - global_position).normalized()
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		rotation.y = atan2(dir.x, dir.z)


func check_input_mappings() -> void:
	var actions: Array[String] = [input_left, input_right, input_forward, input_back]
	for action in actions:
		if not InputMap.has_action(action):
			push_warning("Input action not found: " + action)
