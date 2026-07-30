class_name ChallengeBoardExpansionPanel
extends PanelContainer

signal product_selected(product_id: String)
signal rotate_requested
signal close_requested

const UiStyle = preload("res://scripts/challenge/ui/challenge_ui_style.gd")

var _products: Array[Dictionary] = []
var _tickets := 0
var _selected_product_id := ""
var _rotation := 0


func _ready() -> void:
	for button in _product_buttons():
		UiStyle.apply_secondary(button)
		button.pressed.connect(_on_product_pressed.bind(button))
	UiStyle.apply_secondary($Content/Actions/RotateButton)
	UiStyle.apply_secondary($Content/Actions/CloseButton)
	$Content/Actions/RotateButton.pressed.connect(
		func() -> void:
			_rotation = posmod(_rotation + 90, 360)
			_refresh_selection()
			rotate_requested.emit()
	)
	$Content/Actions/CloseButton.pressed.connect(func() -> void: close_requested.emit())


func bind(products: Array, tickets: int) -> void:
	_products.clear()
	for value in products:
		if value is Dictionary:
			_products.append((value as Dictionary).duplicate(true))
	_tickets = tickets
	$Content/TicketLabel.text = "持有扩建券：%d 张" % _tickets
	var buttons := _product_buttons()
	for index in buttons.size():
		var button := buttons[index]
		if index >= _products.size():
			button.hide()
			continue
		var product: Dictionary = _products[index]
		var price := int(product.get("price", 0))
		button.show()
		button.set_meta("product_id", String(product.get("id", "")))
		button.text = "%s\n%d 张扩建券" % [
			String(product.get("display_name", "")),
			price
		]
		button.disabled = price > _tickets
	if _selected_product_id.is_empty() or _product_by_id(_selected_product_id).is_empty():
		for product in _products:
			if int(product.get("price", 0)) <= _tickets:
				select_product(String(product.get("id", "")))
				return
		_selected_product_id = ""
	_refresh_selection()


func select_product(product_id: String) -> void:
	if _product_by_id(product_id).is_empty():
		return
	_selected_product_id = product_id
	_rotation = 0
	_refresh_selection()
	product_selected.emit(product_id)


func selected_product_id() -> String:
	return _selected_product_id


func rotation() -> int:
	return _rotation


func _on_product_pressed(button: Button) -> void:
	select_product(String(button.get_meta("product_id", "")))


func _refresh_selection() -> void:
	var product := _product_by_id(_selected_product_id)
	if product.is_empty():
		$Content/SelectedLabel.text = "扩建券不足，先击败精英或最终 Boss。"
	else:
		$Content/SelectedLabel.text = "已选：%s · 旋转 %d°\n在左侧棋盘点击绿色预览位置后才会扣券。" % [
			String(product.get("display_name", "")),
			_rotation
		]
	for button in _product_buttons():
		button.button_pressed = String(button.get_meta("product_id", "")) == _selected_product_id


func _product_by_id(product_id: String) -> Dictionary:
	for product in _products:
		if String(product.get("id", "")) == product_id:
			return product
	return {}


func _product_buttons() -> Array[Button]:
	return [
		$Content/ProductGrid/Product0,
		$Content/ProductGrid/Product1,
		$Content/ProductGrid/Product2,
		$Content/ProductGrid/Product3,
		$Content/ProductGrid/Product4,
		$Content/ProductGrid/Product5
	]
