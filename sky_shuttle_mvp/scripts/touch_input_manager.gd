extends Node
class_name TouchInputManager

# 触摸输入管理器 - 处理移动端触摸事件

var touch_positions: Dictionary = {}
var swipe_threshold: float = 50.0

func _ready():
	print("TouchInputManager 初始化")

func _input(event):
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch):
	if event.pressed:
		touch_positions[event.index] = event.position
	else:
		if event.index in touch_positions:
			touch_positions.erase(event.index)

func _handle_drag(event: InputEventScreenDrag):
	if event.index in touch_positions:
		var start_pos = touch_positions[event.index]
		var current_pos = event.position
		var delta = current_pos - start_pos
		
		# 检测滑动手势
		if delta.length() > swipe_threshold:
			if abs(delta.x) > abs(delta.y):
				# 水平滑动
				if delta.x > 0:
					_emit_swipe("right")
				else:
					_emit_swipe("left")
			
			touch_positions[event.index] = current_pos

func _emit_swipe(direction: String):
	print("Swipe detected: ", direction)
	# 可以在这里发射信号或调用玩家移动
