extends Button
class_name CardUI

@onready var color_indicator: ColorRect = $ColorIndicator
@onready var name_label: Label = $NameLabel
@onready var cost_label: Label = $CostLabel

var card_index: int = -1
var card_data = null

func _ready():
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func setup(card, index: int):
	card_data = card
	card_index = index
	
	if card_data:
		name_label.text = card_data.name
		cost_label.text = "%d" % card_data.cost
		color_indicator.color = card_data.icon_color
		
		# 根据卡牌类型设置不同颜色
		match card_data.name:
			"跳跃":
				color_indicator.color = Color(0.3, 0.8, 0.3)
			"滑铲":
				color_indicator.color = Color(0.3, 0.5, 0.9)
			"投掷":
				color_indicator.color = Color(0.9, 0.6, 0.2)

func _on_pressed():
	print(">>> 点击卡牌: ", card_index, " 名称:", card_data.name if card_data else "无")
	
	var main = get_tree().current_scene
	if main:
		var gm = main.get_node_or_null("GameManager")
		if gm and gm.has_node("CardSystem"):
			var card_system = gm.get_node("CardSystem")
			
			# 进入子弹时间
			GameManager.instance.enter_bullet_time()
			
			print(">>> _use_card 开始")
			print(">>> 准备使用卡牌: ", card_data.name if card_data else "无")
			
			var success = card_system.play_card(card_index)
			
			if success:
				print(">>> 卡牌使用成功! 退出子弹时间")
				GameManager.instance.exit_bullet_time()
				
				# 播放使用动画
				_play_use_animation()
			else:
				print(">>> 卡牌使用失败")
				GameManager.instance.exit_bullet_time()

func _play_use_animation():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func _on_mouse_entered():
	if card_data:
		# 可以在这里显示卡牌描述提示
		pass

func _on_mouse_exited():
	pass
