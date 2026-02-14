extends Control

@onready var distance_label: Label = $Panel/DistanceLabel
@onready var restart_button: Button = $Panel/RestartButton

func _ready():
	visible = false
	
	# 等待视口就绪并设置全屏
	await get_tree().root.ready
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if get_viewport():
		size = get_viewport().get_visible_rect().size
	
	GameManager.instance.game_over.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart_pressed)
	print("游戏结束画面已初始化，大小：", size)

func _on_game_over(final_distance: float):
	visible = true
	distance_label.text = "最终距离: %.0f m" % (final_distance / 10.0)
	print("显示游戏结束画面")

func _on_restart_pressed():
	visible = false
	GameManager.instance.start_game()
	
	# 重置场景
	var main = get_tree().current_scene
	if main:
		var map_gen = main.get_node_or_null("MapGenerator")
		if map_gen:
			# 清除现有障碍物
			for chunk in map_gen.active_chunks:
				chunk.queue_free()
			map_gen.active_chunks.clear()
			map_gen.total_distance = 0.0
			
			# 重新生成初始地图
			for i in range(5):
				map_gen.spawn_safe_chunk(1280 - (i * map_gen.chunk_height))
		
		# 重置玩家位置
		var player = main.get_node_or_null("Player")
		if player:
			player.current_lane = 1
			player.target_x = player.LANE_CENTER
			player.global_position = Vector2(player.LANE_CENTER, player.fixed_y_position)
	
	print("游戏重新开始")
