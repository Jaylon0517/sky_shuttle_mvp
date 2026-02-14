extends Node2D
class_name WarningZone

# 判定区域 - 显示在障碍物下方

var zone_color: Color = Color(0, 1, 0, 0.3)
var zone_size: Vector2 = Vector2(60, 100)
var is_active: bool = false

func _ready():
	# 创建判定区域视觉效果
	var zone_rect = ColorRect.new()
	zone_rect.color = zone_color
	zone_rect.size = zone_size
	zone_rect.position = Vector2(-zone_size.x / 2, 0)
	add_child(zone_rect)
	
	# 添加边框
	var border = Panel.new()
	border.size = zone_size
	border.position = Vector2(-zone_size.x / 2, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = zone_color.lightened(0.3)
	border.add_theme_stylebox_override("panel", style)
	add_child(border)

func set_color(color: Color):
	zone_color = color
	for child in get_children():
		if child is ColorRect:
			child.color = color

func activate():
	is_active = true
	modulate = Color(1, 1, 1, 0.6)

func deactivate():
	is_active = false
	modulate = Color(1, 1, 1, 0.3)
