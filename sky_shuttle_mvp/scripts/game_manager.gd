extends Node
class_name GameManager

enum GameState { MENU, PLAYING, BULLET_TIME, GAME_OVER }

var current_state: GameState = GameState.MENU
var current_distance: float = 0.0
var hp: int = 3
var max_hp: int = 3
var energy: float = 5.0
var max_energy: float = 10.0
var is_invincible: bool = false

# 信号
signal hp_changed(new_hp: int, max_hp: int)
signal energy_changed(new_energy: float, max_energy: float)
signal distance_changed(current: float)
signal game_over(final_distance: float)
signal game_started
signal bullet_time_started
signal bullet_time_ended

static var instance: GameManager

func _ready():
	if instance == null:
		instance = self
		print("GameManager 初始化")
	else:
		queue_free()
		return
	
	# 初始化游戏状态
	current_state = GameState.MENU
	hp = max_hp
	energy = max_energy / 2.0
	print("游戏状态初始化完成 - HP:", hp, " Energy:", energy, " 距离:", current_distance)
	
	# 延迟自动开始游戏（等待场景完全加载）
	call_deferred("_auto_start")

func _auto_start():
	print("GameManager: 自动开始游戏")
	start_game()

func start_game():
	current_state = GameState.PLAYING
	current_distance = 0.0
	hp = max_hp
	energy = max_energy / 2.0
	is_invincible = false
	
	hp_changed.emit(hp, max_hp)
	energy_changed.emit(energy, max_energy)
	distance_changed.emit(current_distance)
	game_started.emit()
	
	print("游戏开始！")

func enter_bullet_time():
	if current_state == GameState.PLAYING:
		current_state = GameState.BULLET_TIME
		Engine.time_scale = 0.2
		bullet_time_started.emit()
		print("进入子弹时间!")

func exit_bullet_time():
	if current_state == GameState.BULLET_TIME:
		current_state = GameState.PLAYING
		Engine.time_scale = 1.0
		bullet_time_ended.emit()
		print("退出子弹时间!")

func take_damage():
	if is_invincible:
		return
	
	hp -= 1
	hp_changed.emit(hp, max_hp)
	print("受到伤害! 当前HP:", hp)
	
	if hp <= 0:
		game_over.emit(current_distance)
		trigger_game_over()
	else:
		# 短暂无敌
		is_invincible = true
		print("进入无敌状态")
		await get_tree().create_timer(1.5).timeout
		is_invincible = false
		print("无敌状态结束")

func trigger_game_over():
	current_state = GameState.GAME_OVER
	print("触发游戏结束! 最终距离:", current_distance)

func add_energy(amount: float):
	energy = clamp(energy + amount, 0.0, max_energy)
	energy_changed.emit(energy, max_energy)

func consume_energy(amount: float) -> bool:
	if energy >= amount:
		energy -= amount
		energy_changed.emit(energy, max_energy)
		return true
	return false

func _process(delta: float):
	# 能量自然恢复
	if current_state == GameState.PLAYING and energy < max_energy:
		add_energy(delta * 1.0)  # 每秒恢复1点能量
