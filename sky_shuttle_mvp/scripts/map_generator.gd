extends Node2D
class_name MapGenerator

@export var chunk_height: float = 400.0
@export var scroll_speed: float = 200.0

var obstacle_scenes: Dictionary = {}
var active_chunks: Array[Node2D] = []
var total_distance: float = 0.0
var safe_distance: float = 1000.0
var next_spawn_y: float = 1280.0

# 障碍物配置
const OBSTACLE_TYPES = {
	"jump": "res://scenes/obstacles/trash_can.tscn",
	"slide": "res://scenes/obstacles/pipe.tscn", 
	"breakable": "res://scenes/obstacles/wooden_box.tscn"
}

const LANE_POSITIONS = [180.0, 360.0, 540.0]

func _ready():
	print("地图生成器初始化")
	load_obstacle_scenes()
	
	# 初始生成几个空白地图块（安全区域）
	for i in range(5):
		spawn_safe_chunk(1280 - (i * chunk_height))

func _get_speed_multiplier(distance: float) -> float:
	# 多阶段速度系统（基准速度200）
	if distance < 1000.0:
		return 1.0   # 0-1000m: 200 (基准速度)
	elif distance < 5000.0:
		return 1.25  # 1000-5000m: 250 (1.25x)
	elif distance < 10000.0:
		return 1.5   # 5000-10000m: 300 (1.5x)
	elif distance < 100000.0:
		return 2.0   # 10000-100000m: 400 (2x)
	else:
		return 2.5   # 100000m以上: 500 (2.5x)

func _process(delta: float):
	if GameManager.instance.current_state != GameManager.GameState.PLAYING and GameManager.instance.current_state != GameManager.GameState.BULLET_TIME:
		return
	
	# 根据距离计算当前速度倍数
	var speed_multiplier = _get_speed_multiplier(total_distance)
	var current_speed = scroll_speed * speed_multiplier
	
	# 场景向下滚动
	var move_distance = current_speed * delta * Engine.time_scale
	total_distance += move_distance
	
	# 更新游戏距离
	GameManager.instance.current_distance = total_distance
	GameManager.instance.distance_changed.emit(total_distance)
	
	# 移动所有地图块向下
	for chunk in active_chunks:
		chunk.position.y += move_distance
	
	# 移除超出屏幕底部的地图块
	for i in range(active_chunks.size() - 1, -1, -1):
		var chunk = active_chunks[i]
		if chunk.position.y > 1500:
			chunk.queue_free()
			active_chunks.remove_at(i)
	
	# 生成新地图块
	_check_and_spawn_new_chunk()

func load_obstacle_scenes():
	for type in OBSTACLE_TYPES.keys():
		var scene = load(OBSTACLE_TYPES[type])
		if scene:
			obstacle_scenes[type] = scene
			print("加载障碍物: ", type)

func spawn_safe_chunk(y_pos: float):
	var chunk = Node2D.new()
	
	# 创建地面
	var ground = create_ground()
	chunk.add_child(ground)
	
	chunk.position = Vector2(0, y_pos)
	add_child(chunk)
	active_chunks.append(chunk)

func spawn_obstacle_chunk(y_pos: float):
	var chunk = Node2D.new()
	
	# 创建地面
	var ground = create_ground()
	chunk.add_child(ground)
	
	# 使用权重系统生成障碍物数量
	var obstacle_count = _get_weighted_obstacle_count()
	print("生成 ", obstacle_count, " 个障碍物在 Y=", y_pos)
	
	# 随机选择跑道位置
	var available_lanes = [0, 1, 2]
	available_lanes.shuffle()
	
	# 记录已生成的障碍物类型，避免3个相同
	var spawned_types: Array[String] = []
	
	for i in range(obstacle_count):
		if available_lanes.is_empty():
			break
		
		var lane_index = available_lanes.pop_back()
		var lane_x = LANE_POSITIONS[lane_index]
		
		# 随机选择障碍物类型
		var types = obstacle_scenes.keys()
		var random_type = types[randi() % types.size()]
		
		# 如果已经有2个相同类型，强制选择不同类型
		if spawned_types.size() >= 2:
			var type_count = {}
			for t in spawned_types:
				type_count[t] = type_count.get(t, 0) + 1
			
			# 如果新生成的类型会导致3个相同，则重新选择
			var attempts = 0
			while type_count.get(random_type, 0) >= 2 and attempts < 10:
				random_type = types[randi() % types.size()]
				attempts += 1
		
		spawned_types.append(random_type)
		
		var obstacle = obstacle_scenes[random_type].instantiate()
		# 根据障碍物类型调整Y位置，使底部与地面对齐（地面下边缘在Y=400）
		# 根据碰撞箱大小调整：jump=60高，slide=20高，breakable=50高
		var obstacle_y = 370
		match random_type:
			"jump": obstacle_y = 370      # 垃圾桶碰撞箱60高，底部在400
			"slide": obstacle_y = 390     # 管道碰撞箱20高，底部在400
			"breakable": obstacle_y = 375 # 木箱碰撞箱50高，底部在400
		obstacle.position = Vector2(lane_x, obstacle_y)
		chunk.add_child(obstacle)
		print("  障碍物 ", random_type, " 在跑道 ", lane_index, " (X=", lane_x, ")")
	
	chunk.position = Vector2(0, y_pos)
	add_child(chunk)
	active_chunks.append(chunk)

func _get_weighted_obstacle_count() -> int:
	var distance = total_distance
	var w1: int  # 1个障碍物权重
	var w2: int  # 2个障碍物权重
	var w3: int  # 3个障碍物权重
	
	if distance < 1000.0:
		# 0-1000m: 1=3, 2=3, 3=4
		w1 = 3; w2 = 3; w3 = 4
	elif distance < 5000.0:
		# 1000-5000m: 1=2, 2=4, 3=4
		w1 = 2; w2 = 4; w3 = 4
	elif distance < 10000.0:
		# 5000-10000m: 1=2, 2=3, 3=5
		w1 = 2; w2 = 3; w3 = 5
	elif distance < 100000.0:
		# 10000-100000m: 1=2, 2=2, 3=6
		w1 = 2; w2 = 2; w3 = 6
	else:
		# 100000m+: 1=1, 2=3, 3=6
		w1 = 1; w2 = 3; w3 = 6
	
	var total_weight = w1 + w2 + w3
	var random_value = randi() % total_weight
	
	if random_value < w1:
		return 1
	elif random_value < w1 + w2:
		return 2
	else:
		return 3

func create_ground() -> StaticBody2D:
	var ground = StaticBody2D.new()
	ground.position = Vector2(360, 350)
	ground.collision_layer = 2
	ground.collision_mask = 0
	
	var ground_rect = ColorRect.new()
	ground_rect.offset_left = -360
	ground_rect.offset_top = -50
	ground_rect.offset_right = 360
	ground_rect.offset_bottom = 50
	ground_rect.color = Color(0.15, 0.15, 0.2, 1)
	ground.add_child(ground_rect)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(800, 100)
	collision.shape = shape
	ground.add_child(collision)
	
	return ground

func _check_and_spawn_new_chunk():
	# 找到最上方的块
	var topmost_y: float = 2000
	for chunk in active_chunks:
		if chunk.position.y < topmost_y:
			topmost_y = chunk.position.y
	
	# 如果最上方的块已经进入屏幕上方，生成新块
	if topmost_y > -chunk_height:
		if total_distance < safe_distance:
			spawn_safe_chunk(topmost_y - chunk_height)
		else:
			spawn_obstacle_chunk(topmost_y - chunk_height)
