extends Node2D
class_name Obstacle

@export var damage: int = 1
@export var obstacle_type: String = "generic"
@export var warning_zone_height: float = 100.0

var has_dealt_damage: bool = false
var warning_zone_rect: ColorRect
var is_player_in_zone: bool = false
var required_card_type: String = ""
var check_timer: float = 0.0

func _ready():
	add_to_group("obstacles")
	
	if obstacle_type == "breakable":
		add_to_group("breakable")
		required_card_type = "throw"
	elif obstacle_type == "jump":
		required_card_type = "jump"
	elif obstacle_type == "slide":
		required_card_type = "slide"
	
	var area = get_node_or_null("Area2D")
	if area:
		area.body_entered.connect(_on_area_body_entered)
	
	_create_warning_zone()

func _create_warning_zone():
	var zone_color: Color
	var zone_width: float = 60.0
	var obstacle_bottom: float = 30.0  # 障碍物下边缘Y坐标（根据碰撞箱调整）
	
	match obstacle_type:
		"jump": 
			zone_color = Color(0.2, 0.7, 0.2, 0.3)
			obstacle_bottom = 30.0  # 垃圾桶碰撞箱60高，范围-30到30
		"slide": 
			zone_color = Color(0.2, 0.4, 0.9, 0.3)
			obstacle_bottom = 10.0  # 管道碰撞箱20高，范围-10到10
		"breakable": 
			zone_color = Color(0.9, 0.5, 0.1, 0.3)
			obstacle_bottom = 25.0  # 木箱碰撞箱50高，范围-25到25
		_: 
			zone_color = Color(0.5, 0.5, 0.5, 0.3)
	
	warning_zone_rect = ColorRect.new()
	warning_zone_rect.color = zone_color
	warning_zone_rect.size = Vector2(zone_width, warning_zone_height)
	# 判定区域上边缘与障碍物下边缘贴合
	warning_zone_rect.position = Vector2(-zone_width/2, obstacle_bottom)
	add_child(warning_zone_rect)
	
	var border = Panel.new()
	border.size = Vector2(zone_width, warning_zone_height)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = zone_color.lightened(0.3)
	border.add_theme_stylebox_override("panel", style)
	warning_zone_rect.add_child(border)
	
	var label = Label.new()
	match required_card_type:
		"jump": label.text = "跳"
		"slide": label.text = "铲"
		"throw": label.text = "投"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(zone_width, warning_zone_height)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	warning_zone_rect.add_child(label)
	
	# 隐藏判定区域（但仍保留碰撞检测逻辑）
	warning_zone_rect.visible = false

func _process(delta):
	check_timer += delta
	if check_timer >= 0.1:
		check_timer = 0.0
		_check_player_in_zone()

func _check_player_in_zone():
	var main = get_tree().current_scene
	if not main:
		return
	
	var player = main.get_node_or_null("Player")
	if not player:
		return
	
	var y_dist = abs(player.global_position.y - global_position.y)
	if y_dist > 400:
		if is_player_in_zone:
			is_player_in_zone = false
		return
	
	# 根据障碍物类型获取下边缘位置（根据碰撞箱调整）
	var obstacle_bottom: float = 30.0
	match obstacle_type:
		"jump": obstacle_bottom = 30.0   # 垃圾桶下边缘（碰撞箱60高）
		"slide": obstacle_bottom = 10.0  # 管道下边缘（碰撞箱20高）
		"breakable": obstacle_bottom = 25.0  # 木箱下边缘（碰撞箱50高）
	
	var player_y = player.global_position.y
	var zone_top = global_position.y + obstacle_bottom
	var zone_bottom = global_position.y + obstacle_bottom + warning_zone_height
	var same_lane = abs(player.global_position.x - global_position.x) < 100
	
	var was_in_zone = is_player_in_zone
	is_player_in_zone = player_y >= zone_top and player_y <= zone_bottom and same_lane
	
	# 判定区域逻辑（视觉已隐藏）
	if is_player_in_zone != was_in_zone:
		if is_player_in_zone:
			print("障碍物 ", name, " 玩家进入判定区域")
		else:
			print("障碍物 ", name, " 玩家离开判定区域")

func _on_area_body_entered(body: Node2D):
	var is_player = false
	
	if body.is_in_group("player"):
		is_player = true
	if body is CharacterBody2D and body.name == "Player":
		is_player = true
	if body.get_script() != null and body.get_script().resource_path.ends_with("player.gd"):
		is_player = true
	
	if body is WrenchProjectile or body.is_in_group("projectiles"):
		print("障碍物 ", name, " 被子弹击中!")
		if obstacle_type == "breakable":
			print("障碍物 ", name, " 是可破坏的，销毁!")
			break_obstacle()
		return
	
	if is_player:
		# 计算与玩家的距离
		var dist = body.global_position - global_position
		print("障碍物 ", name, " 被玩家碰到，距离: X=", dist.x, " Y=", dist.y)
		# 检查玩家是否使用了正确的卡牌无敌
		if body.has_method("get_active_card_type"):
			var active_card = body.get_active_card_type()
			if active_card == required_card_type:
				print("障碍物 ", name, " 玩家使用了正确的卡牌，不扣血")
				return
		
		if GameManager.instance.is_invincible:
			print("障碍物 ", name, " 玩家处于无敌状态，不扣血")
			return
		if GameManager.instance.current_state != GameManager.GameState.PLAYING:
			return
		
		print("障碍物 ", name, " 扣血!")
		GameManager.instance.take_damage()
		
		if obstacle_type == "breakable":
			break_obstacle()

func break_obstacle():
	_create_break_effect()
	queue_free()

func _create_break_effect():
	var effect = CPUParticles2D.new()
	effect.global_position = global_position
	effect.amount = 20
	effect.lifetime = 0.5
	effect.explosiveness = 1.0
	effect.spread = 180.0
	effect.initial_velocity_min = 50.0
	effect.initial_velocity_max = 150.0
	effect.gravity = Vector2(0, 300)
	effect.color = Color(0.6, 0.4, 0.2, 0.9)
	effect.one_shot = true
	get_parent().add_child(effect)
	
	# 使用定时器自动清理
	var timer = get_tree().create_timer(0.7)
	timer.timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
