extends Control
class_name HUD

@onready var hp_container: HBoxContainer = $TopBar/HpContainer
@onready var distance_label: Label = $TopBar/DistanceLabel
@onready var energy_bar: ProgressBar = $BottomBar/EnergyBar
@onready var deck_label: Label = $BottomBar/InfoBar/DeckContainer/DeckLabel
@onready var hand_container: HBoxContainer = $BottomBar/HandArea/HandContainer
@onready var hand_area: Panel = $BottomBar/HandArea
@onready var bullet_time_overlay: ColorRect = $BulletTimeOverlay
@onready var overheat_overlay: ColorRect = $OverheatOverlay
@onready var overheat_label: Label = $OverheatOverlay/OverheatLabel
@onready var left_button: Button = $LeftButton
@onready var right_button: Button = $RightButton

var card_ui_scene = preload("res://scenes/ui/card_ui.tscn")
var hand_area_rect: Rect2
var card_system: CardSystem = null

func _ready():
	print("HUD 初始化开始")
	
	# 等待视口就绪
	await get_tree().root.ready
	
	# 确保 HUD 全屏显示
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# 强制设置大小为视口大小
	if get_viewport():
		size = get_viewport().get_visible_rect().size
		print("HUD: 设置大小为视口大小: ", size)
	
	# 连接游戏管理器信号
	if GameManager.instance:
		GameManager.instance.hp_changed.connect(_on_hp_changed)
		GameManager.instance.energy_changed.connect(_on_energy_changed)
		GameManager.instance.distance_changed.connect(_on_distance_changed)
		GameManager.instance.bullet_time_started.connect(_on_bullet_time_started)
		GameManager.instance.bullet_time_ended.connect(_on_bullet_time_ended)
		
		_update_hp_display(GameManager.instance.hp, GameManager.instance.max_hp)
		_on_energy_changed(GameManager.instance.energy, GameManager.instance.max_energy)
		_on_distance_changed(GameManager.instance.current_distance)
		print("HUD: 游戏管理器信号已连接")
	
	# 连接移动按钮
	call_deferred("_connect_buttons")
	
	_try_connect_card_system()
	_update_hand_area_rect()
	print("HUD 初始化完成，位置：", global_position, " 大小：", size)

func _connect_buttons():
	var left_btn = get_node_or_null("LeftButton")
	var right_btn = get_node_or_null("RightButton")
	
	if left_btn:
		left_btn.pressed.connect(_on_left_button_pressed)
		print("HUD: 左按钮已连接")
	
	if right_btn:
		right_btn.pressed.connect(_on_right_button_pressed)
		print("HUD: 右按钮已连接")

func _on_left_button_pressed():
	print(">>> 左按钮按下")
	var main = get_tree().current_scene
	if main:
		var player = main.get_node_or_null("Player")
		if player:
			player.move_left()

func _on_right_button_pressed():
	print(">>> 右按钮按下")
	var main = get_tree().current_scene
	if main:
		var player = main.get_node_or_null("Player")
		if player:
			player.move_right()

func _process(_delta):
	if card_system == null:
		_try_connect_card_system()
	_update_hand_area_rect()

func _try_connect_card_system():
	if card_system != null:
		return
	
	var main = get_tree().current_scene
	if main:
		var gm = main.get_node_or_null("GameManager")
		if gm and gm.has_node("CardSystem"):
			card_system = gm.get_node("CardSystem")
			print("HUD: 找到卡牌系统")
			_connect_card_signals()

func _connect_card_signals():
	if card_system == null:
		return
	
	card_system.hand_updated.connect(_on_hand_updated)
	card_system.deck_count_changed.connect(_on_deck_count_changed)
	card_system.overheat_started.connect(_on_overheat_started)
	card_system.overheat_ended.connect(_on_overheat_ended)
	
	# 立即更新显示
	_on_deck_count_changed(card_system.deck.size())
	_on_hand_updated(card_system.hand)
	print("HUD: 卡牌系统信号已连接，牌库数量：", card_system.deck.size())

func _update_hand_area_rect():
	if hand_area:
		hand_area_rect = hand_area.get_global_rect()

func _on_hp_changed(new_hp: int, max_hp: int):
	call_deferred("_update_hp_display", new_hp, max_hp)

func _update_hp_display(new_hp: int, max_hp: int):
	if hp_container == null:
		return
	
	for child in hp_container.get_children():
		child.queue_free()
	
	for i in range(max_hp):
		var heart = Panel.new()
		heart.custom_minimum_size = Vector2(40, 40)
		var style = StyleBoxFlat.new()
		if i < new_hp:
			style.bg_color = Color(1, 0.2, 0.2)
		else:
			style.bg_color = Color(0.3, 0.3, 0.3)
		style.corner_radius_top_left = 20
		style.corner_radius_top_right = 20
		style.corner_radius_bottom_left = 20
		style.corner_radius_bottom_right = 20
		heart.add_theme_stylebox_override("panel", style)
		hp_container.add_child(heart)

func _on_energy_changed(new_energy: float, max_energy: float):
	if energy_bar:
		energy_bar.max_value = max_energy
		energy_bar.value = new_energy

func _on_distance_changed(current: float):
	if distance_label:
		distance_label.text = "距离: %.0f m" % (current / 10.0)

func _on_hand_updated(hand: Array):
	if hand_container == null:
		return
	
	for child in hand_container.get_children():
		child.queue_free()
	
	for i in range(hand.size()):
		var card_data = hand[i]
		var card_ui = card_ui_scene.instantiate()
		hand_container.add_child(card_ui)
		card_ui.setup(card_data, i)

func _on_deck_count_changed(count: int):
	print("HUD: 牌库数量更新为: ", count)
	if deck_label:
		deck_label.text = str(count)

func _on_bullet_time_started():
	bullet_time_overlay.visible = true
	var tween = create_tween()
	tween.tween_property(bullet_time_overlay, "modulate:a", 0.6, 0.2)

func _on_bullet_time_ended():
	var tween = create_tween()
	tween.tween_property(bullet_time_overlay, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): bullet_time_overlay.visible = false)

func _on_overheat_started():
	overheat_overlay.visible = true
	overheat_label.visible = true
	var tween = create_tween()
	tween.tween_property(overheat_overlay, "modulate:a", 0.85, 0.3)

func _on_overheat_ended():
	overheat_label.visible = false
	var tween = create_tween()
	tween.tween_property(overheat_overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): overheat_overlay.visible = false)
