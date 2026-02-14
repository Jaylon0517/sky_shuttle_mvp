extends CharacterBody2D
class_name Player

@export var jump_velocity: float = -400.0
@export var gravity: float = 1200.0
@export var slide_duration: float = 1.0
@export var fixed_y_position: float = 900.0

const LANE_LEFT: float = 180.0
const LANE_CENTER: float = 360.0
const LANE_RIGHT: float = 540.0

@onready var player_rect: ColorRect = $PlayerRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox

var current_lane: int = 1
var target_x: float = LANE_CENTER
var is_jumping: bool = false
var is_sliding: bool = false
var original_collision_extents: Vector2
var last_damage_time: float = 0.0

# 当前激活的卡牌类型（用于碰撞检测）
var active_card_type: String = ""
var card_effect_timer: float = 0.0

func _ready():
	print(">>> Player._ready() 被调用")
	
	original_collision_extents = collision_shape.shape.size if collision_shape.shape is RectangleShape2D else Vector2(32, 64)
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# 延迟设置位置，确保场景加载完成
	call_deferred("_setup_position")
	
	print("Player 初始化完成")

func _setup_position():
	# 如果场景中的位置是 (0,0)，则使用默认值
	if global_position == Vector2(0, 0):
		global_position = Vector2(LANE_CENTER, fixed_y_position)
		target_x = LANE_CENTER
		current_lane = 1
		print(">>> Player 位置设置为默认: ", global_position)
	else:
		# 使用场景中的位置
		target_x = global_position.x
		match int(global_position.x):
			LANE_LEFT: current_lane = 0
			LANE_CENTER: current_lane = 1
			LANE_RIGHT: current_lane = 2
			_: current_lane = 1
		print(">>> Player 使用场景位置: ", global_position)

func _physics_process(delta: float):
	global_position.x = lerp(global_position.x, target_x, 20 * delta)
	global_position.y = fixed_y_position
	
	if is_jumping:
		velocity.y += gravity * delta
		global_position.y += velocity.y * delta
		if global_position.y >= fixed_y_position:
			global_position.y = fixed_y_position
			velocity.y = 0
			is_jumping = false
	
	# 卡牌效果计时
	if active_card_type != "":
		card_effect_timer -= delta
		if card_effect_timer <= 0:
			active_card_type = ""
			print(">>> 卡牌效果结束")
	
	if GameManager.instance.is_invincible:
		player_rect.modulate.a = 0.5 + sin(Time.get_time_dict_from_system()["second"] * 10) * 0.3
	else:
		player_rect.modulate.a = 1.0

func _on_hitbox_body_entered(body: Node2D):
	if body.is_in_group("obstacles"):
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_damage_time < 1.0:
			return
		last_damage_time = current_time
		GameManager.instance.take_damage()

# 获取当前激活的卡牌类型
func get_active_card_type() -> String:
	return active_card_type

# 设置激活的卡牌类型
func set_active_card_type(card_type: String, duration: float):
	active_card_type = card_type
	card_effect_timer = duration
	print(">>> 激活卡牌效果:", card_type, " 持续时间:", duration)

func move_left():
	if current_lane > 0:
		current_lane -= 1
		_update_target_x()

func move_right():
	if current_lane < 2:
		current_lane += 1
		_update_target_x()

func _update_target_x():
	match current_lane:
		0: target_x = LANE_LEFT
		1: target_x = LANE_CENTER
		2: target_x = LANE_RIGHT

# 卡牌效果 - 跳跃
func jump():
	if not is_jumping and not is_sliding:
		velocity.y = jump_velocity
		is_jumping = true
		
		# 激活跳跃卡牌效果（0.7秒）
		set_active_card_type("jump", 0.7)
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(player_rect, "scale", Vector2(1.4, 1.4), 0.25)
		tween.tween_interval(0.4)
		tween.tween_property(player_rect, "scale", Vector2(1.0, 1.0), 0.25)
		
		_create_jump_effect()
		return true
	return false

# 卡牌效果 - 滑铲
func slide():
	if not is_sliding and not is_jumping:
		is_sliding = true
		
		# 激活滑铲卡牌效果（1.0秒）
		set_active_card_type("slide", 1.0)
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.tween_property(player_rect, "scale", Vector2(0.6, 0.6), 0.2)
		tween.tween_interval(slide_duration - 0.4)
		tween.tween_property(player_rect, "scale", Vector2(1.0, 1.0), 0.2)
		
		if collision_shape.shape is RectangleShape2D:
			collision_shape.shape.size.y = original_collision_extents.y * 0.5
		
		await get_tree().create_timer(slide_duration).timeout
		
		is_sliding = false
		if collision_shape.shape is RectangleShape2D:
			collision_shape.shape.size.y = original_collision_extents.y
		
		return true
	return false

# 卡牌效果 - 投掷
func throw_wrench():
	# 激活投掷卡牌效果（0.5秒）
	set_active_card_type("throw", 0.5)
	
	var bullet = preload("res://scenes/wrench_projectile.tscn").instantiate()
	bullet.global_position = global_position + Vector2(0, -30)
	bullet.direction = Vector2.UP
	get_parent().add_child(bullet)
	
	var tween = create_tween()
	tween.tween_property(player_rect, "position:y", -10, 0.1)
	tween.tween_property(player_rect, "position:y", 0, 0.1)
	
	return true

func _create_jump_effect():
	var effect = CPUParticles2D.new()
	effect.global_position = global_position
	effect.amount = 10
	effect.lifetime = 0.5
	effect.direction = Vector2(0, 1)
	effect.spread = 45.0
	effect.initial_velocity_min = 50.0
	effect.initial_velocity_max = 100.0
	effect.gravity = Vector2(0, 200)
	effect.color = Color(0.5, 0.8, 1.0, 0.8)
	effect.one_shot = true
	get_parent().add_child(effect)
	
	# 使用定时器自动清理
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(func(): effect.queue_free())
