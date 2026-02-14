extends Area2D
class_name WrenchProjectile

@export var speed: float = 600.0
@export var max_distance: float = 400.0

var direction: Vector2 = Vector2.UP
var traveled_distance: float = 0.0
var start_position: Vector2

func _ready():
	start_position = global_position
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_create_bullet_visual()
	print("子弹发射，位置:", global_position)

func _create_bullet_visual():
	# 创建子弹精灵
	var bullet = ColorRect.new()
	bullet.color = Color(0.9, 0.7, 0.2, 1.0)
	bullet.size = Vector2(20, 30)
	bullet.position = Vector2(-10, -15)
	add_child(bullet)
	
	# 添加发光效果
	var glow = ColorRect.new()
	glow.color = Color(1.0, 0.9, 0.5, 0.5)
	glow.size = Vector2(30, 40)
	glow.position = Vector2(-15, -20)
	add_child(glow)
	move_child(glow, 0)
	
	# 添加发射粒子效果
	var particles = CPUParticles2D.new()
	particles.position = Vector2(0, 20)
	particles.amount = 15
	particles.lifetime = 0.3
	particles.explosiveness = 0.8
	particles.direction = Vector2(0, 1)
	particles.spread = 30.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.gravity = Vector2(0, 0)
	particles.color = Color(1.0, 0.8, 0.3, 0.9)
	particles.one_shot = true
	add_child(particles)
	
	# 使用定时器自动清理粒子
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): if is_instance_valid(particles): particles.queue_free())

func _physics_process(delta: float):
	var move_distance = speed * delta
	position += direction * move_distance
	traveled_distance += move_distance
	rotation += 10 * delta
	
	if traveled_distance >= max_distance:
		print("子弹超出射程，销毁")
		_create_disappear_effect()
		queue_free()

func _on_body_entered(body: Node2D):
	print("子弹碰到物体:", body.name)
	
	if body.is_in_group("breakable"):
		print("子弹击中可破坏障碍物!")
		body.break_obstacle()
		_create_hit_effect()
		queue_free()
	elif body.is_in_group("obstacles"):
		print("子弹击中其他障碍物")
		_create_hit_effect()
		queue_free()

func _on_area_entered(area: Area2D):
	print("子弹碰到Area:", area.name)
	
	var parent = area.get_parent()
	if parent and parent.is_in_group("breakable"):
		print("子弹击中可破坏障碍物(通过Area)!")
		parent.break_obstacle()
		_create_hit_effect()
		queue_free()

func _create_hit_effect():
	var effect = CPUParticles2D.new()
	effect.global_position = global_position
	effect.amount = 20
	effect.lifetime = 0.4
	effect.explosiveness = 1.0
	effect.spread = 180.0
	effect.initial_velocity_min = 100.0
	effect.initial_velocity_max = 200.0
	effect.gravity = Vector2(0, 300)
	effect.color = Color(0.9, 0.7, 0.2, 0.9)
	effect.one_shot = true
	get_parent().add_child(effect)
	
	# 使用定时器自动清理
	var timer = get_tree().create_timer(0.6)
	timer.timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())

func _create_disappear_effect():
	var effect = CPUParticles2D.new()
	effect.global_position = global_position
	effect.amount = 10
	effect.lifetime = 0.3
	effect.spread = 180.0
	effect.initial_velocity_min = 50.0
	effect.initial_velocity_max = 100.0
	effect.color = Color(0.9, 0.7, 0.2, 0.5)
	effect.one_shot = true
	get_parent().add_child(effect)
	
	# 使用定时器自动清理
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): if is_instance_valid(effect): effect.queue_free())
