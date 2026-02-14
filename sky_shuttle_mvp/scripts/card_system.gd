extends Node
class_name CardSystem

# 卡牌类型
enum CardType { JUMP, SLIDE, THROW }

# 卡牌数据
class CardData:
	var type: CardType
	var name: String
	var cost: int
	var description: String
	var icon_color: Color
	
	func _init(t: CardType, n: String, c: int, d: String, col: Color):
		type = t
		name = n
		cost = c
		description = d
		icon_color = col

# 固定卡组配置 - 增加能量消耗，权重：跳跃4，滑铲4，投掷2
const DECK_CONFIG = {
	CardType.JUMP: { "count": 4, "cost": 2, "name": "跳跃", "desc": "向上跳跃，越过地面障碍", "color": Color(0.3, 0.8, 0.3) },
	CardType.SLIDE: { "count": 4, "cost": 2, "name": "滑铲", "desc": "伏地滑行，穿过空中障碍", "color": Color(0.3, 0.5, 0.9) },
	CardType.THROW: { "count": 2, "cost": 1, "name": "投掷", "desc": "发射扳手，击碎木箱", "color": Color(0.9, 0.6, 0.2) }
}

# 牌组状态
var deck: Array[CardData] = []  # 牌库
var hand: Array[CardData] = []  # 手牌（固定3张）
var discard: Array[CardData] = []  # 弃牌堆

# 冷却状态
var is_overheated: bool = false
var overheat_duration: float = 1.0

# 信号
signal hand_updated(hand: Array)
signal deck_count_changed(count: int)
signal discard_count_changed(count: int)
signal overheat_started
signal overheat_ended
signal card_played(card: CardData)

func _ready():
	print("CardSystem 初始化开始")
	_initialize_deck()
	_draw_initial_hand()
	print("CardSystem 初始化完成，手牌数:", hand.size())

# 初始化固定卡组
func _initialize_deck():
	deck.clear()
	
	for card_type in DECK_CONFIG.keys():
		var config = DECK_CONFIG[card_type]
		for i in range(config["count"]):
			var card = CardData.new(
				card_type,
				config["name"],
				config["cost"],
				config["desc"],
				config["color"]
			)
			deck.append(card)
	
	# 初始洗牌
	_shuffle_deck()
	deck_count_changed.emit(deck.size())
	print("牌库初始化完成，共", deck.size(), "张卡牌")

# 洗牌
func _shuffle_deck():
	var n = deck.size()
	for i in range(n - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = deck[i]
		deck[i] = deck[j]
		deck[j] = temp

# 抽初始手牌（3张）
func _draw_initial_hand():
	hand.clear()
	for i in range(3):
		_draw_card()
	hand_updated.emit(hand)

# 抽一张牌
func _draw_card():
	if deck.is_empty():
		print("CardSystem: 牌库空了，无法抽牌")
		return
	
	var card = deck.pop_back()
	hand.append(card)
	deck_count_changed.emit(deck.size())

# 打出卡牌
func play_card(hand_index: int) -> bool:
	if is_overheated:
		print("CardSystem: 正在冷却中，无法使用卡牌")
		return false
	
	if hand_index < 0 or hand_index >= hand.size():
		print("CardSystem: 无效的手牌索引:", hand_index)
		return false
	
	var card = hand[hand_index]
	print("CardSystem: 准备打出卡牌:", card.name, " 费用:", card.cost)
	
	# 检查能量
	if not GameManager.instance.consume_energy(card.cost):
		print("CardSystem: 能量不足，无法使用")
		return false
	
	# 执行卡牌效果
	if _execute_card_effect(card):
		# 卡牌效果成功，移到弃牌堆
		hand.remove_at(hand_index)
		discard.append(card)
		print("CardSystem: 卡牌已移动到弃牌堆")
		
		# 检查是否需要洗牌
		if deck.is_empty() and not hand.is_empty():
			_start_overheat()
		else:
			_draw_card()
		
		hand_updated.emit(hand)
		card_played.emit(card)
		return true
	else:
		# 卡牌效果失败（如不在判定区域），能量已消耗但卡牌仍丢弃
		print("CardSystem: 卡牌效果执行失败")
		hand.remove_at(hand_index)
		discard.append(card)
		discard_count_changed.emit(discard.size())
		
		if deck.is_empty():
			_start_overheat()
		else:
			_draw_card()
		
		hand_updated.emit(hand)
		return true

# 执行卡牌效果
func _execute_card_effect(card: CardData) -> bool:
	print("CardSystem: execute_card_effect，卡牌类型:", card.type)
	
	# 通过路径查找玩家
	var main = get_tree().current_scene
	var player = null
	if main:
		player = main.get_node_or_null("Player")
	
	if not player:
		print("CardSystem: 错误 - 找不到玩家!")
		return false
	
	print("CardSystem: 找到玩家，执行动作")
	match card.type:
		CardType.JUMP:
			print("CardSystem: 执行跳跃")
			player.jump()
		CardType.SLIDE:
			print("CardSystem: 执行滑铲")
			player.slide()
		CardType.THROW:
			print("CardSystem: 执行投掷")
			player.throw_wrench()
	
	return true

# 开始过热（牌库空了）
func _start_overheat():
	if is_overheated:
		return
	
	is_overheated = true
	print("CardSystem: 牌库空了，开始过热")
	overheat_started.emit()
	
	# 等待冷却时间
	await get_tree().create_timer(overheat_duration).timeout
	
	# 弃牌堆洗回牌库
	deck = discard.duplicate()
	discard.clear()
	_shuffle_deck()
	
	deck_count_changed.emit(deck.size())
	print("CardSystem: 重洗完成，牌库数量：", deck.size())
	
	# 补充手牌
	while hand.size() < 3 and not deck.is_empty():
		_draw_card()
	
	hand_updated.emit(hand)
	
	is_overheated = false
	print("CardSystem: 过热结束，牌库已重洗")
	overheat_ended.emit()

# 获取卡牌能量消耗
func get_card_cost(hand_index: int) -> int:
	if hand_index >= 0 and hand_index < hand.size():
		return hand[hand_index].cost
	return 999

# 获取手牌
func get_hand() -> Array:
	return hand
