extends HBoxContainer

signal quantity_delta_requested(item_key: String, delta: int)

var item_label: Label
var price_label: Label
var stock_label: Label
var minus_button: Button
var quantity_label: Label
var plus_button: Button

var _item_key := ""


func configure(item_key: String, item_name: String, price: int, stock: int, quantity: int, can_increase: bool) -> void:
	_bind_nodes()
	_item_key = item_key
	name = "PurchaseQuantityRow_%s" % item_key.replace(":", "_")
	set_meta("purchase_cart_item_key", item_key)
	item_label.text = item_name
	item_label.tooltip_text = item_name
	price_label.text = str(price)
	update_state(stock, quantity, can_increase)


func update_state(stock: int, quantity: int, can_increase: bool) -> void:
	_bind_nodes()
	stock_label.text = str(stock)
	minus_button.disabled = quantity <= 0
	quantity_label.text = str(quantity)
	plus_button.disabled = not can_increase


func _ready() -> void:
	_bind_nodes()
	if not minus_button.pressed.is_connected(_on_minus_pressed):
		minus_button.pressed.connect(_on_minus_pressed)
	if not plus_button.pressed.is_connected(_on_plus_pressed):
		plus_button.pressed.connect(_on_plus_pressed)


func _on_minus_pressed() -> void:
	quantity_delta_requested.emit(_item_key, -1)


func _on_plus_pressed() -> void:
	quantity_delta_requested.emit(_item_key, 1)


func tutorial_target(action: String) -> Control:
	_bind_nodes()
	match action:
		"increase":
			return plus_button
		"decrease":
			return minus_button
	return self


func _bind_nodes() -> void:
	if item_label != null:
		return
	item_label = $PurchaseItemLabel
	price_label = $PriceStat/PriceLabel
	stock_label = $StockStat/StockLabel
	minus_button = $PurchaseMinusButton
	quantity_label = $PurchaseQuantityLabel
	plus_button = $PurchasePlusButton
